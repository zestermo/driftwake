# Driftwake headless test runner (Windows PowerShell 5+ / PowerShell 7).
#
#   .\tools\dev\run_tests.ps1                      # every suite, one at a time
#   .\tools\dev\run_tests.ps1 r10test swimtest     # just these
#   .\tools\dev\run_tests.ps1 -Jobs 4              # every suite, 4 at once (faster, a bit flakier)
#   .\tools\dev\run_tests.ps1 -Changed             # the suites that cover uncommitted changes (test_map.txt)
#   .\tools\dev\run_tests.ps1 -Changed -Base main  # ...and everything this branch changed since main
#   .\tools\dev\run_tests.ps1 -Force chaintest     # run it even if this exact code already passed it
#
# Godot: set $env:GODOT to the *console* build (Godot_v4.7-..._win64_console.exe),
# or pass -Godot. The non-console exe doesn't print to the terminal on Windows.
# Full logs land in tools\dev\out\logs\<suite>.log. Exit code = number of failed suites.
#
# Parallel sessions (tools\dev\crew_lib.ps1): every runner on the machine shares
# $env:DRIFTWAKE_TEST_SLOTS (default 3) Godot test slots and waits for a free one, and a
# suite that already passed on exactly this code (any session, any worktree) is skipped.
# The suite list is tools\dev\suites.txt.
param(
	[Parameter(Position = 0, ValueFromRemainingArguments = $true)]
	[string[]]$Tests,
	[string]$Godot = $env:GODOT,
	[int]$Timeout = 330,
	[int]$Jobs = 1,
	[switch]$NoCompileCheck,
	[switch]$Changed,
	[switch]$Force,
	[string]$Base = "HEAD"
)

$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$all = @(Get-Content (Join-Path $PSScriptRoot "suites.txt") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
$netHint = ""
if ($Changed) {
	$picked = @((& (Join-Path $PSScriptRoot "affected.ps1") -Base $Base -Explain) -split "\s+" | Where-Object { $_ })
	$modes = @()
	if ($picked -contains "net") { $modes += ".\tools\dev\nettest.ps1" }
	if ($picked -contains "netchain") { $modes += ".\tools\dev\nettest.ps1 chain" }
	if ($modes.Count -gt 0) { $netHint = "Co-op code changed: run " + ($modes -join " and ") }
	$Tests = @($picked | Where-Object { $all -contains $_ })
	if ($Tests.Count -eq 0) {
		Write-Host "No suites cover what changed." -ForegroundColor Yellow
		if ($netHint) { Write-Host $netHint -ForegroundColor Yellow }
		exit 0
	}
	Write-Host ("Suites: " + ($Tests -join " ")) -ForegroundColor Cyan
}
if (-not $Tests -or $Tests.Count -eq 0) { $Tests = $all }

if (-not $Godot) {
	$cmd = Get-Command godot -ErrorAction SilentlyContinue
	if ($cmd) { $Godot = $cmd.Source }
}
if (-not $Godot -or -not (Test-Path $Godot)) {
	Write-Error "Godot not found. Set `$env:GODOT to the Godot 4.7 *console* exe, e.g. `$env:GODOT = 'C:\Tools\Godot\Godot_v4.7-stable_win64_console.exe'"
	exit 99
}

$logs = [System.IO.Path]::Combine($root, "tools", "dev", "out", "logs")
New-Item -ItemType Directory -Force -Path $logs | Out-Null

# a fresh checkout (a new worktree without the cache copied in) imports once first, and so
# does one that's missing a class_name (a new script, or another branch's merged or landed in)
$classCache = Join-Path $root ".godot\global_script_class_cache.cfg"
$needImport = -not (Test-Path (Join-Path $root ".godot\imported"))
if (-not $needImport) {
	$known = if (Test-Path $classCache) { Get-Content $classCache -Raw } else { "" }
	$missing = @(Get-ChildItem (Join-Path $root "scripts"), (Join-Path $root "scenes") -Recurse -Filter "*.gd" |
		Select-String -Pattern "^class_name\s+(\w+)" -List |
		ForEach-Object { $_.Matches[0].Groups[1].Value } |
		Where-Object { $known -notmatch "&`"$_`"" })
	$needImport = $missing.Count -gt 0
	if ($needImport) { Write-Host ("New class names (" + ($missing -join ", ") + "): importing once...") -ForegroundColor Yellow }
} else {
	Write-Host "No .godot import cache here: importing once (a minute or two)..." -ForegroundColor Yellow
}
if ($needImport) {
	$ErrorActionPreference = "Continue"
	& $Godot --headless --path "$root" --import 2>&1 | Out-Null
	$ErrorActionPreference = "Stop"
}

# skip what already passed on exactly this code (this tree, uncommitted changes included)
$crew = Get-CrewDir $root
$me = Get-CrewBranch $root
$tree = Get-TreeKey $root
Clear-OldResults $crew
if (-not $Force) {
	$todo = @()
	foreach ($t in $Tests) {
		$hit = Get-CachedPass $crew $tree $t
		if ($hit) { Write-Host ("{0,-10}       already passed on this exact code ({1}; -Force reruns)" -f $t, $hit) -ForegroundColor DarkGreen }
		else { $todo += $t }
	}
	$cachedCount = $Tests.Count - $todo.Count
	$Tests = $todo
}

# every script compiles first (~6 s): one broken script otherwise fails every suite with noise
if (-not $NoCompileCheck -and $Tests.Count -gt 0) {
	# (Windows PowerShell turns a native program's stderr into errors under "Stop")
	$ErrorActionPreference = "Continue"
	$cc = & $Godot --headless --path "$root" --script res://tools/dev/compilecheck.gd 2>&1 | ForEach-Object { "$_" }
	$ErrorActionPreference = "Stop"
	if ($LASTEXITCODE -ne 0) {
		$cc | Where-Object { $_ -match "SCRIPT ERROR|^\s+at: GDScript::reload|COMPILE FAILED" } | Select-Object -Unique | ForEach-Object { Write-Host $_ -ForegroundColor Red }
		Write-Host "Scripts don't compile: no suites run (-NoCompileCheck to run anyway)" -ForegroundColor Red
		exit 100
	}
	Write-Host ($cc | Where-Object { $_ -match "COMPILE OK" } | Select-Object -First 1) -ForegroundColor DarkGray
}

function Start-Suite([string]$t, $slot) {
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $Godot
	$psi.Arguments = "--headless --path `"$root`" --script res://tools/dev/$t.gd"
	$psi.WorkingDirectory = $root
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $true
	$p = [System.Diagnostics.Process]::Start($psi)
	return [pscustomobject]@{
		Name = $t; Proc = $p; Started = Get-Date; Slot = $slot
		Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync()
	}
}

function Finish-Suite($r) {
	$timedOut = -not $r.Proc.HasExited
	if ($timedOut) { try { $r.Proc.Kill() } catch {} ; $r.Proc.WaitForExit() }
	Exit-Slot $r.Slot
	$text = $r.Out.Result + "`n" + $r.Err.Result
	Set-Content -Path (Join-Path $logs "$($r.Name).log") -Value $text -Encoding UTF8
	$lines = $text -split "`r?`n" | Where-Object { $_ -cmatch "FAIL|RESULT|SCRIPT ERROR" } | Select-Object -Unique | Select-Object -First 12
	$secs = [int]((Get-Date) - $r.Started).TotalSeconds
	$ok = (-not $timedOut) -and ($lines -cmatch "RESULT (OK|fails=0)") -and -not ($lines -cmatch "FAIL|SCRIPT ERROR")
	$summary = if ($timedOut) { "TIMEOUT after $Timeout s" } elseif ($lines) { ($lines -join " | ") } else { "no RESULT line (crashed?)" }
	$color = if ($ok) { "Green" } else { "Red" }
	Write-Host ("{0,-10} {1,4}s  {2}" -f $r.Name, $secs, $summary) -ForegroundColor $color
	if ($ok) { Set-CachedPass $crew $tree $r.Name $me }
	return $ok
}

$queue = New-Object System.Collections.Queue
$Tests | ForEach-Object { $queue.Enqueue($_) }
$running = @()
$failed = @()
$told = $false
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	while ($queue.Count -gt 0 -and $running.Count -lt [Math]::Max(1, $Jobs)) {
		$slot = Enter-Slot $crew "$me $($queue.Peek())"
		if (-not $slot) {
			if (-not $told) {
				Write-Host ("Waiting for a test slot ({0} in use: {1})" -f (Get-SlotCount), ((Get-SlotHolders $crew) -join "; ")) -ForegroundColor DarkYellow
				$told = $true
			}
			break
		}
		$told = $false
		$running += Start-Suite $queue.Dequeue() $slot
	}
	Start-Sleep -Milliseconds 250
	$still = @()
	foreach ($r in $running) {
		$elapsed = ((Get-Date) - $r.Started).TotalSeconds
		if ($r.Proc.HasExited -or $elapsed -gt $Timeout) {
			if (-not (Finish-Suite $r)) { $failed += $r.Name }
		} else { $still += $r }
	}
	$running = $still
}

if ($failed.Count -gt 0) {
	Write-Host ("FAILED: " + ($failed -join ", ") + "   (logs in tools\dev\out\logs)") -ForegroundColor Red
	# (in a worktree only this tree's code runs: another session's uncommitted work can't fail it,
	# but it helps to know who else is in the same files)
	$board = Get-CrewBoard $root
	$o = Get-Overlaps $board $me @(($board.Rows | Where-Object { $_.Branch -eq $me }).Files)
	if ($o) {
		Write-Host "Other sessions changing the same files (expect to merge with them when they land):" -ForegroundColor Yellow
		$o | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
	}
} else {
	$cachedNote = if ($cachedCount) { ", $cachedCount already passed" } else { "" }
	Write-Host "ALL OK ($($Tests.Count) suites run$cachedNote)" -ForegroundColor Green
}
if ($netHint) { Write-Host "$netHint too" -ForegroundColor Yellow }
exit $failed.Count

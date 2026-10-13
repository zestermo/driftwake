# Driftwake headless test runner (Windows PowerShell 5+ / PowerShell 7).
#
#   .\tools\dev\run_tests.ps1                      # every suite, 5 at once (the machine's test slots)
#   .\tools\dev\run_tests.ps1 r10test swimtest     # just these
#   .\tools\dev\run_tests.ps1 -Jobs 1              # one at a time
#   .\tools\dev\run_tests.ps1 -Changed             # the suites that cover uncommitted changes (test_map.txt)
#   .\tools\dev\run_tests.ps1 -Changed -Base main  # ...and everything this branch changed since main
#   .\tools\dev\run_tests.ps1 -Force chaintest     # run it even if this exact code already passed it
#   .\tools\dev\run_tests.ps1 -Changed -Light      # ...minus the slow suites in heavy.txt and co-op (prepush.ps1 runs those)
#
# Godot: set $env:GODOT to the *console* build (Godot_v4.7-..._win64_console.exe),
# or pass -Godot. The non-console exe doesn't print to the terminal on Windows.
# Logs land in tools\dev\out\logs\<suite>.log as the suite runs. Exit code = number of failed suites.
#
# Parallel sessions (tools\dev\crew_lib.ps1): every runner on the machine shares
# $env:DRIFTWAKE_TEST_SLOTS (default 5) Godot test slots and waits for a free one; a suite
# that already passed on exactly this code (any session, any worktree) is skipped, and one
# another runner is running on exactly this code right now is waited for, not run twice.
# A suite is stopped early when it stalls (no output for DRIFTWAKE_TEST_STALL s, default 150),
# its scripts don't parse, or it floods errors; a failure whose every FAIL line is a known
# flake (tools\dev\flaky.txt) is retried once. Live status for the Tests pane: .git\crew\live.
# -CarryFrom <tree>: a suite that passed on that tree and that nothing changed since touches
# (test_map.txt) counts as passed here too (land.ps1 passes the branch's tree before its rebase).
# The suite list is tools\dev\suites.txt.
param(
	[Parameter(Position = 0, ValueFromRemainingArguments = $true)]
	[string[]]$Tests,
	[string]$Godot = $env:GODOT,
	[int]$Timeout = 330,
	[int]$Jobs = 5,
	[switch]$NoCompileCheck,
	[switch]$Changed,
	[switch]$Force,
	[switch]$Light,
	[string]$Base = "HEAD",
	[string]$CarryFrom = ""
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
	if ($Light) {
		$heavy = @(Get-Content (Join-Path $PSScriptRoot "heavy.txt") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
		$deferred = @($Tests | Where-Object { $heavy -contains $_ })
		$Tests = @($Tests | Where-Object { $heavy -notcontains $_ })
		if ($deferred.Count -gt 0 -or $netHint) { $netHint = "Left for prepush.ps1: " + (@($deferred) + @($(if ($netHint) { "co-op" })) -join " ") }
	}
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

Update-ImportCache $root $Godot

$crew = Get-CrewDir $root
$me = Get-CrewBranch $root
$tree = Get-TreeKey $root
Clear-OldResults $crew
$run = New-LiveRun $crew $root $me "tests" $Tests

# skip what already passed on exactly this code (this tree, uncommitted changes included), or on
# the tree we're carrying from when nothing since touches the suite
$carryHit = @()
if ($CarryFrom -and -not $Force) {
	$carryHit = @((& (Join-Path $PSScriptRoot "affected.ps1") -Since $CarryFrom -To $tree) -split "\s+" | Where-Object { $_ })
}
$cachedCount = 0
if (-not $Force) {
	$todo = @()
	foreach ($t in $Tests) {
		$hit = Get-CachedPass $crew $tree $t
		if (-not $hit -and $CarryFrom -and $carryHit -notcontains $t) {
			$was = Get-CachedPass $crew $CarryFrom $t
			if ($was) {
				Set-CachedPass $crew $tree $t "$me (carried: nothing since touches it)"
				$hit = "$was, carried over the rebase"
			}
		}
		if ($hit) {
			Write-Host ("{0,-10}       already passed on this exact code ({1}; -Force reruns)" -f $t, $hit) -ForegroundColor DarkGreen
			Set-LiveSuite $run $t @{ state = "cached"; why = $hit }
			$cachedCount++
		} else { $todo += $t }
	}
	$Tests = $todo
}
Save-LiveRun $run $true

# every script compiles first (~6 s): one broken script otherwise fails every suite with noise
if (-not $NoCompileCheck -and $Tests.Count -gt 0) {
	$run.Data.state = "compiling"
	Save-LiveRun $run $true
	# (Windows PowerShell turns a native program's stderr into errors under "Stop")
	$ErrorActionPreference = "Continue"
	$cc = & $Godot --headless --path "$root" --script res://tools/dev/compilecheck.gd 2>&1 | ForEach-Object { "$_" }
	$ErrorActionPreference = "Stop"
	if ($LASTEXITCODE -ne 0) {
		$errs = @($cc | Where-Object { $_ -match "SCRIPT ERROR|^\s+at: GDScript::reload|COMPILE FAILED" } | Select-Object -Unique)
		$errs | ForEach-Object { Write-Host $_ -ForegroundColor Red }
		Write-Host "Scripts don't compile: no suites run (-NoCompileCheck to run anyway)" -ForegroundColor Red
		foreach ($t in $Tests) { Set-LiveSuite $run $t @{ state = "skipped"; why = "scripts don't compile"; last = @($errs | Select-Object -First 6) } }
		$run.Data.state = "failed"; $run.Data.ended = (Get-Date).ToString("o")
		Save-LiveRun $run $true
		exit 100
	}
	Write-Host ($cc | Where-Object { $_ -match "COMPILE OK" } | Select-Object -First 1) -ForegroundColor DarkGray
	$run.Data.state = "running"
}

function Start-Suite([string]$t, $slot) {
	$job = Start-GodotJob $Godot $root "$t.gd" "" (Join-Path $logs "$t.log")
	$job | Add-Member -NotePropertyName Name -NotePropertyValue $t
	$job | Add-Member -NotePropertyName Slot -NotePropertyValue $slot
	Set-InFlight $crew $tree $t "$me $($run.Data.id)" $true
	Set-LiveSuite $run $t @{ state = "running"; log = $job.Log; pid = $job.Proc.Id; secs = 0; why = "" }
	return $job
}

## Done (exited, stopped on its first failure, or `trouble` says why it was stopped): its verdict; true if it passed.
function Finish-Suite($job, [string]$trouble, [bool]$failed = $false) {
	if ($trouble -or $failed) { Stop-GodotJob $job }
	Update-GodotJob $job
	Exit-Slot $job.Slot
	Set-InFlight $crew $tree $job.Name "" $false
	$lines = Get-JobSummary $job
	$secs = [int]((Get-Date) - $job.Started).TotalSeconds
	$ok = (-not $trouble) -and (-not $failed) -and ($lines -cmatch "RESULT (OK|fails=0)") -and -not ($lines -cmatch "FAIL|SCRIPT ERROR")
	$summary = if ($trouble) { $trouble.ToUpper().Substring(0, 1) + $trouble.Substring(1) } elseif ($lines) { ($lines -join " | ") } else { "no RESULT line (crashed?)" }
	if ($ok) {
		Write-Host ("{0,-10} {1,4}s  PASSED" -f $job.Name, $secs) -ForegroundColor Green
	} elseif ($job.Fail.Count -gt 0) {
		Write-Host ("{0,-10} {1,4}s  FAILED{2}" -f $job.Name, $secs, $(if ($failed) { " (stopped on it)" } else { "" })) -ForegroundColor Red
		foreach ($l in $job.Fail) { Write-Host "    $l" -ForegroundColor Red }
	} else {
		Write-Host ("{0,-10} {1,4}s  {2}" -f $job.Name, $secs, $summary) -ForegroundColor Red
	}
	$fails = @($lines | Where-Object { $_ -cmatch "^FAIL" })
	Set-LiveSuite $run $job.Name @{ state = $(if ($ok) { "passed" } elseif ($trouble) { "stopped" } else { "failed" }); secs = $secs; pid = 0
		why = $(if ($ok) { "" } elseif ($trouble) { $trouble } elseif ($job.Fail.Count -gt 0) { $job.Fail[0] } elseif ($fails) { $fails[0] } else { $summary })
		fail = @($job.Fail); last = @($job.Tail) }
	if ($ok) { Set-CachedPass $crew $tree $job.Name $me }
	Write-Ledger $crew $job.Name $(if ($ok) { "passed" } elseif ($trouble) { "stopped" } else { "failed" }) $tree $me $secs $(if ($ok) { "" } elseif ($trouble) { $trouble } elseif ($fails) { $fails[0] } else { $summary })
	return [pscustomobject]@{ Ok = $ok; Fails = $fails; Trouble = $trouble }
}

$queue = New-Object System.Collections.Generic.List[string]
$Tests | ForEach-Object { $queue.Add($_) }
$running = @()
$failed = @()
$retried = @{}
$told = $false
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	# a suite another runner is running on this exact code: wait for its verdict instead
	for ($i = $queue.Count - 1; $i -ge 0; $i--) {
		$t = $queue[$i]
		$other = Get-InFlight $crew $tree $t
		$hit = Get-CachedPass $crew $tree $t
		if ($hit) {
			Write-Host ("{0,-10}       passed in another run of this exact code ({1})" -f $t, $hit) -ForegroundColor DarkGreen
			Set-LiveSuite $run $t @{ state = "cached"; why = "passed in $hit" }
			$cachedCount++
			$queue.RemoveAt($i)
		} elseif ($other) {
			Set-LiveSuite $run $t @{ state = "shared"; why = "running in $other" }
		} elseif ($run.Data.suites[$t].state -eq "shared") {
			Set-LiveSuite $run $t @{ state = "queued"; why = "" }
		}
	}
	while ($running.Count -lt [Math]::Max(1, $Jobs)) {
		$next = $queue | Where-Object { $run.Data.suites[$_].state -ne "shared" } | Select-Object -First 1
		if (-not $next) { break }
		$slot = Enter-Slot $crew "$me $next"
		if (-not $slot) {
			if (-not $told) {
				Write-Host ("Waiting for a test slot ({0} in use: {1})" -f (Get-SlotCount), ((Get-SlotHolders $crew) -join "; ")) -ForegroundColor DarkYellow
				$told = $true
			}
			foreach ($q in $queue) { if ($run.Data.suites[$q].state -eq "queued") { Set-LiveSuite $run $q @{ state = "waiting"; why = "for a test slot" } } }
			break
		}
		$told = $false
		$queue.Remove($next) | Out-Null
		$running += Start-Suite $next $slot
	}
	Start-Sleep -Milliseconds 250
	$still = @()
	foreach ($j in $running) {
		Update-GodotJob $j
		$fail = if ($j.Proc.HasExited) { @() } else { @(Get-JobFailure $j) }
		$trouble = if ($j.Proc.HasExited -or $fail.Count -gt 0) { "" } else { Get-JobTrouble $j $Timeout }
		if ($j.Proc.HasExited -or $trouble -or $fail.Count -gt 0) {
			$v = Finish-Suite $j $trouble ($fail.Count -gt 0)
			if (-not $v.Ok) {
				if (-not $v.Trouble -and -not $retried.ContainsKey($j.Name) -and (Test-AllFlaky $j.Name $v.Fails)) {
					Write-Host ("{0,-10}       known flaky check: retrying once" -f $j.Name) -ForegroundColor DarkYellow
					$retried[$j.Name] = $true
					Set-LiveSuite $run $j.Name @{ state = "queued"; why = "retry: known flaky" }
					$queue.Add($j.Name)
				} else { $failed += $j.Name }
			}
		} else {
			Set-LiveSuite $run $j.Name @{ secs = [int]((Get-Date) - $j.Started).TotalSeconds; last = @($j.Tail | Select-Object -Last 4) }
			$still += $j
		}
	}
	$running = $still
	Save-LiveRun $run
}

$run.Data.state = $(if ($failed.Count -gt 0) { "failed" } else { "passed" })
$run.Data.ended = (Get-Date).ToString("o")
Save-LiveRun $run $true
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

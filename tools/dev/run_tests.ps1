# Driftwake headless test runner (Windows PowerShell 5+ / PowerShell 7).
#
#   .\tools\dev\run_tests.ps1                      # every suite, one at a time
#   .\tools\dev\run_tests.ps1 r10test swimtest     # just these
#   .\tools\dev\run_tests.ps1 -Jobs 4              # every suite, 4 at once (faster, a bit flakier)
#
# Godot: set $env:GODOT to the *console* build (Godot_v4.7-..._win64_console.exe),
# or pass -Godot. The non-console exe doesn't print to the terminal on Windows.
# Full logs land in tools\dev\out\logs\<suite>.log. Exit code = number of failed suites.
param(
	[Parameter(Position = 0, ValueFromRemainingArguments = $true)]
	[string[]]$Tests,
	[string]$Godot = $env:GODOT,
	[int]$Timeout = 330,
	[int]$Jobs = 1
)

$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$all = @("feat", "feel", "dash", "chartest", "styletest", "stamtest", "invtest", "ragtest", "bugtest",
	"shiptest", "swimtest", "grunttest", "guntest", "fixtest", "watertest", "powertest", "progtest",
	"savetest", "vinetest", "r6test", "r7test", "r8test", "r9test", "r10test", "capturetest", "katanatest", "hairtest", "seatest", "yardtest", "qoltest", "axetest", "perftest", "decktest")
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

function Start-Suite([string]$t) {
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
		Name = $t; Proc = $p; Started = Get-Date
		Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync()
	}
}

function Finish-Suite($r) {
	$timedOut = -not $r.Proc.HasExited
	if ($timedOut) { try { $r.Proc.Kill() } catch {} ; $r.Proc.WaitForExit() }
	$text = $r.Out.Result + "`n" + $r.Err.Result
	Set-Content -Path (Join-Path $logs "$($r.Name).log") -Value $text -Encoding UTF8
	$lines = $text -split "`r?`n" | Where-Object { $_ -cmatch "FAIL|RESULT|SCRIPT ERROR" }
	$secs = [int]((Get-Date) - $r.Started).TotalSeconds
	$ok = (-not $timedOut) -and ($lines -cmatch "RESULT (OK|fails=0)") -and -not ($lines -cmatch "FAIL|SCRIPT ERROR")
	$summary = if ($timedOut) { "TIMEOUT after $Timeout s" } elseif ($lines) { ($lines -join " | ") } else { "no RESULT line (crashed?)" }
	$color = if ($ok) { "Green" } else { "Red" }
	Write-Host ("{0,-10} {1,4}s  {2}" -f $r.Name, $secs, $summary) -ForegroundColor $color
	return $ok
}

$queue = New-Object System.Collections.Queue
$Tests | ForEach-Object { $queue.Enqueue($_) }
$running = @()
$failed = @()
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	while ($queue.Count -gt 0 -and $running.Count -lt [Math]::Max(1, $Jobs)) {
		$running += Start-Suite $queue.Dequeue()
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
} else {
	Write-Host "ALL OK ($($Tests.Count) suites)" -ForegroundColor Green
}
exit $failed.Count

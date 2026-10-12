# Co-op test: a headless host and client (and a third watcher for "three") on
# localhost. Modes: "" (default), late, three, hostquit, water, board, chain (the
# island chain: the host lands on the first island, then the guest joins late).
#
#   .\tools\dev\nettest.ps1            # default
#   .\tools\dev\nettest.ps1 water
#   .\tools\dev\nettest.ps1 chain
#
# Godot: $env:GODOT = the 4.7 *console* exe (or -Godot). Logs: tools\dev\out\logs\net*.log, written
# as they run (the Tests pane shows them live).
#
# Like run_tests.ps1 it takes machine-wide test slots (one per Godot it starts), skips a mode that
# already passed on exactly this code (-Force reruns), waits for a run of the same mode on the same
# code instead of starting a second, stops a Godot that stalls, can't parse its scripts or floods
# errors, and retries once when every failure is a known flake (tools\dev\flaky.txt, suite "net").
param(
	[Parameter(Position = 0)][string]$Mode = "",
	[string]$Godot = $env:GODOT,
	[int]$Timeout = 300,
	[switch]$Force
)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Godot) { $cmd = Get-Command godot -ErrorAction SilentlyContinue; if ($cmd) { $Godot = $cmd.Source } }
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Error "Set `$env:GODOT to the Godot 4.7 console exe"; exit 99 }
$logs = [System.IO.Path]::Combine($root, "tools", "dev", "out", "logs")
New-Item -ItemType Directory -Force -Path $logs | Out-Null

. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
$me = Get-CrewBranch $root
Update-ImportCache $root $Godot
$tree = Get-TreeKey $root
$key = if ($Mode) { "net-$Mode" } else { "net" }

function Test-Done() {
	$hit = Get-CachedPass $crew $tree $key
	if ($hit -and -not $Force) {
		Write-Host "CO-OP TEST OK (already passed on this exact code: $hit; -Force reruns)" -ForegroundColor Green
		exit 0
	}
}
Test-Done
# the same mode on the same code already running somewhere: wait for its verdict
$told = $false
while ($other = Get-InFlight $crew $tree $key) {
	if (-not $told) { Write-Host "Waiting for the same co-op test already running ($other)..." -ForegroundColor DarkYellow; $told = $true }
	Start-Sleep -Seconds 2
}
Test-Done

$names = @("host", "client") + $(if ($Mode -eq "three") { @("watch") } else { @() })
$run = New-LiveRun $crew $root $me $key $names
Set-InFlight $crew $tree $key "$me $($run.Data.id)" $true
foreach ($n in $names) { Set-LiveSuite $run $n @{ state = "waiting"; why = "for test slots" } }
Save-LiveRun $run $true
$slots = Wait-Slots $crew $names.Count "$me $key"

$port = 24700 + (Get-Random -Maximum 250)
$delay = "2.5"
if ($Mode -eq "late") { $port = 24680; $delay = "7" }
# (the host is boarded before we join)
if ($Mode -eq "board") { $delay = "10" }
if ($Mode -eq "chain") { $delay = "6"; $Timeout = [Math]::Max($Timeout, 500) }
$modeArg = if ($Mode) { $Mode } else { "" }

## One go: host, client (and watcher) until the client and host are done. True if it passed.
function Invoke-Once() {
	$jobs = [ordered]@{}
	$jobs["host"] = Start-GodotJob $Godot $root "nethost.gd" "$port $modeArg" (Join-Path $logs "nethost.log")
	if ($Mode -eq "three") { $jobs["watch"] = Start-GodotJob $Godot $root "netwatch.gd" "$port 10" (Join-Path $logs "netwatch.log") }
	Start-Sleep -Milliseconds 300
	$jobs["client"] = Start-GodotJob $Godot $root "netclient.gd" "$port $delay $modeArg" (Join-Path $logs "netclient.log")
	foreach ($n in $jobs.Keys) { Set-LiveSuite $run $n @{ state = "running"; log = $jobs[$n].Log; pid = $jobs[$n].Proc.Id; why = "" } }
	$trouble = @{}
	while ($true) {
		$open = 0
		foreach ($n in $jobs.Keys) {
			$j = $jobs[$n]
			Update-GodotJob $j
			if (-not $j.Proc.HasExited) {
				$t = Get-JobTrouble $j $Timeout
				if ($t) {
					Stop-GodotJob $j
					$trouble[$n] = $t
				} else { $open++ }
			}
			Set-LiveSuite $run $n @{ secs = [int]((Get-Date) - $j.Started).TotalSeconds; last = @($j.Tail | Select-Object -Last 4) }
		}
		Save-LiveRun $run
		# (a stopped host takes the client with it, and the other way round)
		if ($trouble.Count -gt 0) { foreach ($n in $jobs.Keys) { if (-not $jobs[$n].Proc.HasExited) { Stop-GodotJob $jobs[$n]; if (-not $trouble[$n]) { $trouble[$n] = "stopped with the others" } } } }
		if ($open -eq 0 -or $trouble.Count -gt 0) { break }
		Start-Sleep -Milliseconds 250
	}
	$ok = $true
	foreach ($n in $jobs.Keys) {
		$j = $jobs[$n]
		Update-GodotJob $j
		$lines = Get-JobSummary $j 40
		$fails = @($lines | Where-Object { $_ -cmatch "^FAIL|SCRIPT ERROR" })
		$good = if ($n -eq "host") { -not $trouble[$n] -and -not ($lines -cmatch "SCRIPT ERROR") } else { -not $trouble[$n] -and ($lines -cmatch "RESULT OK") }
		if (-not $good) { $ok = $false }
		Write-Host "--- $n" -ForegroundColor Cyan
		if ($trouble[$n]) { Write-Host $trouble[$n] -ForegroundColor Red }
		$lines | Where-Object { $_ -cmatch "FAIL|RESULT|SCRIPT ERROR" } | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
		Set-LiveSuite $run $n @{ state = $(if ($good) { "passed" } elseif ($trouble[$n]) { "stopped" } else { "failed" }); pid = 0; last = @($j.Tail)
			why = $(if ($trouble[$n]) { $trouble[$n] } elseif ($fails) { $fails[0] } elseif (-not $good) { "no RESULT OK" } else { "" }) }
	}
	Save-LiveRun $run $true
	$script:lastFails = @(Get-JobSummary $jobs["client"] 40 | Where-Object { $_ -cmatch "^FAIL" })
	$script:lastTrouble = $trouble.Count -gt 0
	return $ok
}

$ok = Invoke-Once
if (-not $ok -and -not $script:lastTrouble -and (Test-AllFlaky "net" $script:lastFails)) {
	Write-Host "Known flaky co-op check: retrying once" -ForegroundColor DarkYellow
	foreach ($n in $names) { Set-LiveSuite $run $n @{ state = "running"; why = "retry: known flaky" } }
	$ok = Invoke-Once
}
foreach ($s in $slots) { Exit-Slot $s }
Set-InFlight $crew $tree $key "" $false
$secsAll = [int]((Get-Date) - [datetime]$run.Data.started).TotalSeconds
Write-Ledger $crew $key $(if ($ok) { "passed" } elseif ($script:lastTrouble) { "stopped" } else { "failed" }) $tree $me $secsAll $(if ($ok) { "" } elseif ($script:lastFails) { $script:lastFails[0] } else { "see the Tests pane" })
$run.Data.state = $(if ($ok) { "passed" } else { "failed" })
$run.Data.ended = (Get-Date).ToString("o")
Save-LiveRun $run $true
if (-not $ok) { Write-Host "CO-OP TEST FAILED" -ForegroundColor Red; exit 1 }
Set-CachedPass $crew $tree $key $me
Write-Host "CO-OP TEST OK" -ForegroundColor Green
exit 0

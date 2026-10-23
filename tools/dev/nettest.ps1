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
# already passed with exactly these contents of every file its Godots load (-Force reruns), waits for a run
# of the same mode on the same code instead of starting a second, stops a Godot that stalls, can't parse its scripts or floods
# errors, and retries once when every failure is a known flake (tools\dev\flaky.txt, suite "net").
# -CI (GitHub Actions): none of the crew's slots, cache, sharing or live runs; a table on the job summary.
param(
	[Parameter(Position = 0)][string]$Mode = "",
	[string]$Godot = $env:GODOT,
	[int]$Timeout = 300,
	[switch]$Force,
	[switch]$CI
)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Godot) { $cmd = Get-Command godot -ErrorAction SilentlyContinue; if ($cmd) { $Godot = $cmd.Source } }
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Error "Set `$env:GODOT to the Godot 4.7 console exe"; exit 99 }
$logs = [System.IO.Path]::Combine($root, "tools", "dev", "out", "logs")
New-Item -ItemType Directory -Force -Path $logs | Out-Null

. (Join-Path $PSScriptRoot "crew_lib.ps1")
. (Join-Path $PSScriptRoot "ci_lib.ps1")
$key = if ($Mode) { "net-$Mode" } else { "net" }
$names = @("host", "client") + $(if ($Mode -eq "three") { @("watch") } else { @() })
$ciRows = [ordered]@{}
$slots = @()
if ($CI) {
	$run = New-CiRun $names
} else {
	$crew = Get-CrewDir $root
	$me = Get-CrewBranch $root
	Update-ImportCache $root $Godot
	$tree = Get-TreeKey $root
	$ctx = New-KeyContext $root $crew $tree
	$depKey = (Get-TestKey $ctx $key).Key

	function Test-Done() {
		$hit = Get-CachedPass $crew (Get-TestKey $ctx $key).Key $key
		if ($hit -and -not $Force) {
			Write-Host "CO-OP TEST OK (already passed with these exact dependencies: $hit; -Force reruns)" -ForegroundColor Green
			exit 0
		}
	}
	Test-Done
	# the same mode on the same code already running somewhere: wait for its verdict
	$told = $false
	while ($other = Get-InFlight $crew $depKey $key) {
		if (-not $told) { Write-Host "Waiting for the same co-op test already running ($other)..." -ForegroundColor DarkYellow; $told = $true }
		Start-Sleep -Seconds 2
	}
	Test-Done

	$run = New-LiveRun $crew $root $me $key $names
	Set-InFlight $crew $depKey $key "$me $($run.Data.id)" $true
	foreach ($n in $names) { Set-LiveSuite $run $n @{ state = "waiting"; why = "for test slots" } }
	Save-LiveRun $run $true
	$slots = Wait-Slots $crew $names.Count "$me $key"
}
## Where a Godot of this run writes what it loaded (none under -CI).
function Get-DepsOut([string]$n) { if ($CI) { return "" }; return Join-Path $logs "$key.$n.deps" }

$port = 24700 + (Get-Random -Maximum 250)
# (the guest knocks once the host's world is up: knocking at 2.5 s, mid-load, its hello could sit behind a
# retransmit ENet stretched to a minute while the host was frozen, and the guest gave up at 60 s; 2026-10-22,
# repeatable on 3996a827, which passed earlier in the day. Joining during a host's load is a known issue.)
$delay = "10"
if ($Mode -eq "late") { $port = 24680; $delay = "7" }
# (the host is boarded before we join)
if ($Mode -eq "board") { $delay = "10" }
if ($Mode -eq "chain") { $delay = "6"; $Timeout = [Math]::Max($Timeout, 500) }
$modeArg = if ($Mode) { $Mode } else { "" }

## One go: host, client (and watcher) until the client and host are done. True if it passed.
function Invoke-Once() {
	$jobs = [ordered]@{}
	$jobs["host"] = Start-GodotJob $Godot $root "nethost.gd" "$port $modeArg" (Join-Path $logs "$key.host.log") "" (Get-DepsOut "host") $true
	if ($Mode -eq "three") { $jobs["watch"] = Start-GodotJob $Godot $root "netwatch.gd" "$port 10" (Join-Path $logs "$key.watch.log") "" (Get-DepsOut "watch") $true }
	Start-Sleep -Milliseconds 300
	$jobs["client"] = Start-GodotJob $Godot $root "netclient.gd" "$port $delay $modeArg" (Join-Path $logs "$key.client.log") "" (Get-DepsOut "client") $true
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
		if ($CI) {
			$block = if ($good) { @() } elseif ($trouble[$n]) { @($trouble[$n]) + @($j.Tail) } elseif ($fails) { @($lines | Where-Object { $_ -cmatch "FAIL|SCRIPT ERROR" } | Select-Object -First 20) } else { @("no RESULT OK") + @($j.Tail) }
			Add-CiRow $ciRows "$key $n" ([int]((Get-Date) - $j.Started).TotalSeconds) $(if ($good) { "PASS" } elseif ($trouble[$n]) { "STOPPED" } else { "FAIL" }) $block ""
		}
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
if ($CI) {
	Write-CiSummary "Co-op: $key" $ciRows
} else {
	Set-InFlight $crew $depKey $key "" $false
	$secsAll = [int]((Get-Date) - [datetime]$run.Data.started).TotalSeconds
	if ($ok) {
		if (Save-Deps $crew $key @($names | ForEach-Object { Get-DepsOut $_ })) {
			$k = Get-TestKey $ctx $key
			Set-CachedPass $crew $k.Key $key $me $k.Manifest
			$depKey = $k.Key
		} else { Set-CachedPass $crew $tree $key $me }
	}
	Write-Ledger $crew $key $(if ($ok) { "passed" } elseif ($script:lastTrouble) { "stopped" } else { "failed" }) $tree $me $secsAll $(if ($ok) { "" } elseif ($script:lastFails) { $script:lastFails[0] } else { "see the Tests pane" }) -1 $depKey
	$run.Data.state = $(if ($ok) { "passed" } else { "failed" })
	$run.Data.ended = (Get-Date).ToString("o")
	Save-LiveRun $run $true
}
if (-not $ok) { Write-Host "CO-OP TEST FAILED" -ForegroundColor Red; exit 1 }
Write-Host "CO-OP TEST OK" -ForegroundColor Green
exit 0

# Driftwake headless test runner (Windows PowerShell 5+ / PowerShell 7).
#
#   .\tools\dev\run_tests.ps1                      # every test, 5 at once (the machine's test slots)
#   .\tools\dev\run_tests.ps1 r10test swimtest     # just these
#   .\tools\dev\run_tests.ps1 t/player/dash t/ship # an atomic test (tools\dev\t\<group>\<name>.gd, named t.<group>.<name>), a group
#   .\tools\dev\run_tests.ps1 -Jobs 1              # one at a time
#   .\tools\dev\run_tests.ps1 -Changed             # the tests an uncommitted change affects, by what each loads (affected.ps1)
#   .\tools\dev\run_tests.ps1 -Changed -Wide       # ...every test that loads a changed file (suites too: nearly all of them)
#   .\tools\dev\run_tests.ps1 -Changed -Base main  # ...or anything this branch changed since main
#   .\tools\dev\run_tests.ps1 -Force chaintest     # run it even if it already passed with these exact dependencies
#   .\tools\dev\run_tests.ps1 -Changed -Light      # ...minus the slow suites in heavy.txt and co-op (prepush.ps1 runs those)
#   .\tools\dev\run_tests.ps1 isletest -Seed 1234  # on that seed instead of the suite's own (DRIFTWAKE_SEED; never cached)
#   .\tools\dev\run_tests.ps1 smoketest -Exact     # a pass counts only on this exact tree, not by dependencies (land.ps1)
#
# Godot: set $env:GODOT to the *console* build (Godot_v4.7-..._win64_console.exe),
# or pass -Godot. The non-console exe doesn't print to the terminal on Windows.
# Logs land in tools\dev\out\logs\<test>.log as the test runs. Exit code = number of failed tests.
#
# Parallel sessions (tools\dev\crew_lib.ps1): every runner on the machine shares
# $env:DRIFTWAKE_TEST_SLOTS (default 5) Godot test slots and waits for a free one. Each passing run records
# the project files it loaded (.git\crew\deps); a test that already passed with exactly these contents of
# those files (any session, any worktree, whatever else changed) is skipped, and one another runner is
# running on the same dependencies right now is waited for, not run twice. Until its first recorded pass a
# test is keyed by the whole tree. A test is stopped early when it stalls (no output for
# DRIFTWAKE_TEST_STALL s, default 150), its scripts don't parse, or it floods errors; a failure whose every
# FAIL line is a known flake (tools\dev\flaky.txt) is retried once. Live status for the Tests pane: .git\crew\live.
# The tests: tools\dev\suites.txt and every tools\dev\t\<group>\<name>.gd.
# -CI (GitHub Actions, pwsh 7 on Linux or Windows): no crew (slots, pass cache, in-flight sharing, ledger,
# live runs, deps), no import (the workflow does it): compile check, run, judge, and a table on the job summary.
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
	[switch]$Exact,
	[switch]$Wide,
	[string]$Base = "HEAD",
	[string]$Seed = $env:DRIFTWAKE_SEED,
	[switch]$CI
)

$ErrorActionPreference = "Stop"
# (a pass on another seed says nothing about the suite's own: no cache either way, no sharing a run)
if ($Seed -or $CI) { $Force = $true }
$share = -not $Seed -and -not $CI
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
. (Join-Path $PSScriptRoot "ci_lib.ps1")
$ciRows = [ordered]@{}
$all = Get-AllTests
$netHint = ""
if ($Changed) {
	$picked = @((& (Join-Path $PSScriptRoot "affected.ps1") -Base $Base -Explain -Wide:$Wide) -split "\s+" | Where-Object { $_ })
	$modes = @($picked | Where-Object { $_ -match "^net(-\w+)?$" } | ForEach-Object { ".\tools\dev\nettest.ps1" + $(if ($_ -ne "net") { " " + $_.Substring(4) } else { "" }) })
	if ($modes.Count -gt 0) { $netHint = "Co-op code changed: run " + ($modes -join " and ") }
	$Tests = @($picked | Where-Object { $all -contains $_ })
	if ($Light) {
		$heavy = @(Get-Content (Join-Path $PSScriptRoot "heavy.txt") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
		$deferred = @($Tests | Where-Object { $heavy -contains $_ })
		$Tests = @($Tests | Where-Object { $heavy -notcontains $_ })
		if ($deferred.Count -gt 0 -or $netHint) { $netHint = "Left for prepush.ps1: " + (@($deferred) + @($(if ($netHint) { "co-op" })) -join " ") }
	}
	if ($Tests.Count -eq 0) {
		Write-Host "No test loads what changed." -ForegroundColor Yellow
		if ($netHint) { Write-Host $netHint -ForegroundColor Yellow }
		exit 0
	}
	Write-Host ("Tests: " + ($Tests -join " ")) -ForegroundColor Cyan
} elseif ($Tests) {
	$Tests = Resolve-TestNames $Tests
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

if ($CI) {
	$run = New-CiRun $Tests
} else {
	Update-ImportCache $root $Godot
	$crew = Get-CrewDir $root
	$me = Get-CrewBranch $root
	$tree = Get-TreeKey $root
	$ctx = New-KeyContext $root $crew $tree
	Clear-OldResults $crew
	$run = New-LiveRun $crew $root $me "tests" $Tests
}

## The key a test's pass is kept under now: its dependencies' hash (the tree before they're recorded, or with -Exact).
function Get-Key([string]$t) {
	if ($Exact) { return $tree }
	return (Get-TestKey $ctx $t).Key
}

# skip what already passed with exactly these dependencies (uncommitted changes included)
$cachedCount = 0
if (-not $Force) {
	$todo = @()
	foreach ($t in $Tests) {
		$hit = Get-CachedPass $crew (Get-Key $t) $t
		if ($hit) {
			$on = if ((Get-Key $t) -eq $tree) { "on this exact code" } else { "with these exact dependencies" }
			Write-Host ("{0,-10}       already passed {1} ({2}; -Force reruns)" -f $t, $on, $hit) -ForegroundColor DarkGreen
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
		$errs = @($cc | Where-Object { $_ -match "SCRIPT ERROR|^\s+at: GDScript::reload|COMPILE FAILED|WALL CLOCK" } | Select-Object -Unique)
		$errs | ForEach-Object { Write-Host $_ -ForegroundColor Red }
		Write-Host "Scripts don't compile (or call the wall clock in game code): no suites run (-NoCompileCheck to run anyway)" -ForegroundColor Red
		if ($CI) {
			Add-CiRow $ciRows "compile check" 0 "FAIL" @($errs | Select-Object -First 40) ""
			Write-CiSummary ("Suites: " + ($Tests -join " ")) $ciRows
		}
		foreach ($t in $Tests) { Set-LiveSuite $run $t @{ state = "skipped"; why = "scripts don't compile"; last = @($errs | Select-Object -First 6) } }
		$run.Data.state = "failed"; $run.Data.ended = (Get-Date).ToString("o")
		Save-LiveRun $run $true
		exit 100
	}
	Write-Host ($cc | Where-Object { $_ -match "COMPILE OK" } | Select-Object -First 1) -ForegroundColor DarkGray
	$run.Data.state = "running"
}

function Start-Suite([string]$t, $slot) {
	$deps = if ($share) { Join-Path $logs "$t.deps" } else { "" }
	$job = Start-GodotJob $Godot $root (Get-TestScript $t) "" (Join-Path $logs "$t.log") $Seed $deps
	$job | Add-Member -NotePropertyName Name -NotePropertyValue $t
	$job | Add-Member -NotePropertyName Slot -NotePropertyValue $slot
	$job | Add-Member -NotePropertyName Key -NotePropertyValue $(if ($share) { Get-Key $t } else { "" })
	$job | Add-Member -NotePropertyName DepsOut -NotePropertyValue $deps
	if ($share) { Set-InFlight $crew $job.Key $t "$me $($run.Data.id)" $true }
	Set-LiveSuite $run $t @{ state = "running"; log = $job.Log; pid = $job.Proc.Id; secs = 0; why = ""; seed = $Seed }
	return $job
}

## Done (exited, stopped on its first failure, or `trouble` says why it was stopped): its verdict; true if it passed.
function Finish-Suite($job, [string]$trouble, [bool]$failed = $false) {
	if ($trouble -or $failed) { Stop-GodotJob $job }
	Update-GodotJob $job
	Exit-Slot $job.Slot
	if ($share) { Set-InFlight $crew $job.Key $job.Name "" $false }
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
	if (-not $ok -and $job.Seed) { Write-Host ("    on seed {0}: .\tools\dev\run_tests.ps1 {1} -Seed {0}" -f $job.Seed, $job.Name) -ForegroundColor Red }
	$fails = @($lines | Where-Object { $_ -cmatch "^FAIL" })
	Set-LiveSuite $run $job.Name @{ state = $(if ($ok) { "passed" } elseif ($trouble) { "stopped" } else { "failed" }); secs = $secs; pid = 0
		why = $(if ($ok) { "" } elseif ($trouble) { $trouble } elseif ($job.Fail.Count -gt 0) { $job.Fail[0] } elseif ($fails) { $fails[0] } else { $summary })
		fail = @($job.Fail); last = @($job.Tail); seed = $job.Seed }
	if ($CI) {
		$block = if ($ok) { @() } elseif ($trouble) { @($trouble) + @($job.Tail) } elseif ($job.Fail.Count -gt 0) { @($job.Fail) } else { @($summary) + @($job.Tail) }
		Add-CiRow $ciRows $job.Name $secs $(if ($ok) { "PASS" } elseif ($trouble) { "STOPPED" } else { "FAIL" }) $block $(if ($ok) { "" } else { $job.Seed })
	}
	$key = $job.Key
	if ($ok -and $share) {
		# (what it loaded this time is its dependencies from now on, and the pass is kept under them)
		if (Save-Deps $crew $job.Name @($job.DepsOut)) {
			$k = Get-TestKey $ctx $job.Name
			Set-CachedPass $crew $k.Key $job.Name $me $k.Manifest
			$key = $k.Key
		} else { Write-Host ("    {0} recorded no dependencies: kept under the tree" -f $job.Name) -ForegroundColor DarkYellow }
		if ($Exact -or $key -eq $tree) { Set-CachedPass $crew $tree $job.Name $me }
	}
	if ($share) { Write-Ledger $crew $job.Name $(if ($ok) { "passed" } elseif ($trouble) { "stopped" } else { "failed" }) $tree $me $secs $(if ($ok) { "" } elseif ($trouble) { $trouble } elseif ($fails) { $fails[0] } else { $summary }) (Get-JobSetup $job) $key }
	return [pscustomobject]@{ Ok = $ok; Fails = $fails; Trouble = $trouble }
}

$queue = New-Object System.Collections.Generic.List[string]
$Tests | ForEach-Object { $queue.Add($_) }
$running = @()
$failed = @()
$retried = @{}
$told = $false
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	# a suite another runner is running on these exact dependencies: wait for its verdict instead
	for ($i = $queue.Count - 1; $i -ge 0 -and $share; $i--) {
		$t = $queue[$i]
		$k = Get-Key $t
		$other = Get-InFlight $crew $k $t
		$hit = Get-CachedPass $crew $k $t
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
		$slot = $null
		if (-not $CI) {
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
		}
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
			Set-LiveSuite $run $j.Name @{ secs = [int]((Get-Date) - $j.Started).TotalSeconds; last = @($j.Tail | Select-Object -Last 4); seed = $j.Seed }
			$still += $j
		}
	}
	$running = $still
	Save-LiveRun $run
}

$run.Data.state = $(if ($failed.Count -gt 0) { "failed" } else { "passed" })
$run.Data.ended = (Get-Date).ToString("o")
Save-LiveRun $run $true
if ($CI) { Write-CiSummary ("Suites: " + ($Tests -join " ")) $ciRows }
if ($failed.Count -gt 0) {
	Write-Host ("FAILED: " + ($failed -join ", ") + "   (logs in tools\dev\out\logs)") -ForegroundColor Red
}
if ($failed.Count -gt 0 -and -not $CI) {
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

# How long each suite takes, from passed runs: median total, median setup (start to its first PASS/FAIL
# line: Godot starting, loading, building the world) and the checks after it, slowest first, and the
# machine time of a full run (the sum of every suite's median).
#
#   .\tools\dev\suite_times.ps1           # every suite with a time
#   .\tools\dev\suite_times.ps1 -Top 15   # the slowest 15
#
# Sources: .git\crew\ledger\history\<suite>.jsonl (every result since it was added: totals and setup), and
# the live runs (.git\crew\live, kept a day) from before the history began (totals only), then a suite's
# last result (ledger\<suite>.json) for one with neither. Times are wall
# seconds on a shared machine: a suite next to four others runs slower than alone.
param([int]$Top = 0)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
$suites = @(Get-Content (Join-Path $PSScriptRoot "suites.txt") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })

function Get-Median([double[]]$xs) {
	if ($xs.Count -eq 0) { return $null }
	$s = @($xs | Sort-Object)
	$m = [int][Math]::Floor($s.Count / 2)
	if ($s.Count % 2) { return $s[$m] }
	return ($s[$m - 1] + $s[$m]) / 2
}

$totals = @{}
$setups = @{}
function Add-Time([string]$suite, [double]$secs, [double]$setup) {
	if (-not $totals.ContainsKey($suite)) { $totals[$suite] = New-Object System.Collections.Generic.List[double]; $setups[$suite] = New-Object System.Collections.Generic.List[double] }
	$totals[$suite].Add($secs)
	if ($setup -ge 0) { $setups[$suite].Add($setup) }
}

$cut = [datetime]::MaxValue
foreach ($f in Get-ChildItem (Join-Path $crew "ledger\history") -Filter "*.jsonl" -ErrorAction SilentlyContinue) {
	foreach ($l in [System.IO.File]::ReadAllLines($f.FullName)) {
		if (-not $l.Trim()) { continue }
		$r = $l | ConvertFrom-Json
		if ([datetime]$r.at -lt $cut) { $cut = [datetime]$r.at }
		if ($r.state -eq "passed" -and $r.secs -gt 0) { Add-Time $f.BaseName $r.secs $r.setup }
	}
}
# (a run that ended once the history had begun is in it already)
foreach ($f in Get-ChildItem (Join-Path $crew "live") -Filter "*.json" -ErrorAction SilentlyContinue) {
	$r = Get-Content $f.FullName -Raw | ConvertFrom-Json
	if (-not $r.ended -or [datetime]$r.ended -ge $cut) { continue }
	foreach ($s in $r.suites.PSObject.Properties.Value) {
		if ($s.state -eq "passed" -and $s.secs -gt 0) { Add-Time $s.name $s.secs -1 }
	}
}
# a suite with neither: its last result, if it passed
foreach ($f in Get-ChildItem (Join-Path $crew "ledger") -Filter "*.json" -ErrorAction SilentlyContinue) {
	if ($totals.ContainsKey($f.BaseName)) { continue }
	$r = Get-Content $f.FullName -Raw | ConvertFrom-Json
	if ($r.state -eq "passed" -and $r.secs -gt 0) { Add-Time $f.BaseName $r.secs $(if ($null -ne $r.setup) { $r.setup } else { -1 }) }
}

$rows = foreach ($k in $totals.Keys) {
	$t = Get-Median $totals[$k].ToArray()
	$s = Get-Median $setups[$k].ToArray()
	[pscustomobject]@{ Suite = $k; Runs = $totals[$k].Count; Total = $t; Setup = $s; SetupRuns = $setups[$k].Count; Checks = $(if ($null -ne $s) { $t - $s } else { $null }) }
}
$rows = @($rows | Sort-Object Total -Descending)
$show = if ($Top -gt 0) { @($rows | Select-Object -First $Top) } else { $rows }

function Fmt($x) { if ($null -eq $x) { return "-" }; return ("{0:0}" -f $x) }
Write-Host ("{0,-14} {1,5} {2,7} {3,7} {4,7} {5,7}" -f "suite", "runs", "total", "setup", "checks", "setup%")
foreach ($r in $show) {
	$pct = if ($null -ne $r.Setup -and $r.Total -gt 0) { "{0:0}%" -f (100 * $r.Setup / $r.Total) } else { "-" }
	Write-Host ("{0,-14} {1,5} {2,7} {3,7} {4,7} {5,7}" -f $r.Suite, $(if ($r.SetupRuns -and $r.SetupRuns -ne $r.Runs) { "$($r.Runs)/$($r.SetupRuns)" } else { $r.Runs }), (Fmt $r.Total), (Fmt $r.Setup), (Fmt $r.Checks), $pct)
}
$timed = @($rows | Where-Object { $suites -contains $_.Suite })
$sum = ($timed | Measure-Object Total -Sum).Sum
$withSetup = @($timed | Where-Object { $null -ne $_.Setup })
$setupSum = ($withSetup | Measure-Object Setup -Sum).Sum
$missing = @($suites | Where-Object { -not $totals.ContainsKey($_) })
Write-Host ""
Write-Host ("A full run (suites.txt): {0:0} s of machine time ({1:0.0} min; at {2} slots at least {3:0.0} min of wall time) over {4} of {5} suites{6}" -f $sum, ($sum / 60), (Get-SlotCount), ($sum / 60 / (Get-SlotCount)), $timed.Count, $suites.Count, $(if ($missing) { "; no passed run of: " + ($missing -join ", ") } else { "" }))
if ($withSetup.Count) {
	$their = ($withSetup | Measure-Object Total -Sum).Sum
	Write-Host ("Setup: {0:0} s of the {1:0} s of the {2} suites with setup timed ({3:0}%)" -f $setupSum, $their, $withSetup.Count, (100 * $setupSum / $their))
}
Write-Host "(runs: passed runs counted, as n/m when only m of them timed their setup)" -ForegroundColor DarkGray

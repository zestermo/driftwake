# Every suite's state against this checkout's code (the main checkout's, from the Tests pane):
#   ok        passed on exactly this code, or on older code that nothing since touches (test_map.txt)
#   stale     needs to run: files it covers changed since its last pass (they're listed)
#   failing   its last run failed or was stopped, and nothing it covers changed since
#   never     no pass on record (passes are kept two days, results under .git\crew)
# Writes .git\crew\status.json and prints a summary. Reads only git and small files: a few seconds.
#
#   .\tools\dev\test_status.ps1          # summary
#   .\tools\dev\test_status.ps1 -Stale   # just the names that need to run (stale or failing), on one line
param([switch]$Stale)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
Close-DeadRuns $crew
$tree = Get-TreeKey $root

$suites = @(Get-Content (Join-Path $PSScriptRoot "suites.txt") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
# the co-op modes tracked (others show once they have a result)
$net = @("net", "net-chain", "net-board")
foreach ($l in Get-ChildItem (Join-Path $crew "ledger") -Filter "net*.json" -ErrorAction SilentlyContinue) { $n = $l.BaseName; if ($net -notcontains $n) { $net += $n } }
$all = $suites + $net

$groups = @()
$groupOf = @{}
foreach ($line in Get-Content (Join-Path $PSScriptRoot "suite_groups.txt")) {
	$l = $line.Trim()
	if (-not $l -or $l.StartsWith("#")) { continue }
	$g, $names = $l -split ":", 2
	$g = $g.Trim()
	if ($groups -notcontains $g) { $groups += $g }
	foreach ($n in $names -split "\s+" | Where-Object { $_ }) { $groupOf[$n] = $g }
}
if (@($all | Where-Object { -not $groupOf.ContainsKey($_) }).Count -gt 0) { $groups += "Other" }

$map = @()
foreach ($line in Get-Content (Join-Path $PSScriptRoot "test_map.txt")) {
	$l = $line.Trim()
	if (-not $l -or $l.StartsWith("#")) { continue }
	$parts = $l -split "\s+"
	$map += , @($parts[0], @($parts[1..($parts.Count - 1)]))
}
## The suites (and "net"/"netchain") a changed file pulls in, as affected.ps1 picks them.
function Get-Hits([string]$f) {
	$hit = @()
	if ($f -match "^tools/dev/([a-z0-9_]+)\.gd$" -and (Test-Path (Join-Path $PSScriptRoot "$($Matches[1]).gd"))) {
		$name = $Matches[1]
		if ($name -match "test$|^feat$|^feel$|^dash$") { $hit += $name }
		if ($name -match "^net") { $hit += "net"; $hit += "netchain" }
	}
	foreach ($m in $map) { if ($f -like $m[0]) { $hit += $m[1] } }
	return $hit
}
## Does a change to `files` touch `suite`? The files that do.
function Get-Touching([string]$suite, [string[]]$files) {
	$tokens = if ($suite -eq "net-chain") { @("net", "netchain") } elseif ($suite -like "net*") { @("net") } else { @($suite) }
	return @($files | Where-Object { $f = $_; (Get-Hits $f | Where-Object { $tokens -contains $_ }).Count -gt 0 })
}
$diffs = @{}
function Get-Changed([string]$from) {
	if (-not $diffs.ContainsKey($from)) {
		$diffs[$from] = @(git -C $root diff --name-only $from $tree 2>$null | Where-Object { $_ } | ForEach-Object { $_ -replace "\\", "/" })
	}
	return $diffs[$from]
}

# every pass on record, per suite, newest first (results\<tree>\<suite>.ok)
$passes = @{}
foreach ($d in Get-ChildItem (Join-Path $crew "results") -Directory -ErrorAction SilentlyContinue) {
	foreach ($ok in Get-ChildItem $d.FullName -Filter "*.ok" -ErrorAction SilentlyContinue) {
		$s = $ok.BaseName
		if (-not $passes.ContainsKey($s)) { $passes[$s] = @() }
		$passes[$s] += [pscustomobject]@{ Tree = $d.Name; At = $ok.LastWriteTime; By = (Get-Content $ok.FullName -Raw).Trim() }
	}
}

$rows = @()
foreach ($s in $all) {
	$ledger = $null
	$lf = Join-Path $crew "ledger\$s.json"
	if (Test-Path $lf) { $ledger = Get-Content $lf -Raw | ConvertFrom-Json }
	$row = [ordered]@{ name = $s; group = $(if ($groupOf.ContainsKey($s)) { $groupOf[$s] } else { "Other" }); state = "never"; why = ""; files = @(); last = $ledger; passedOn = "" }
	$exact = $passes[$s] | Where-Object { $_.Tree -eq $tree } | Select-Object -First 1
	$mine = @($passes[$s] | Sort-Object At -Descending | Select-Object -First 10)
	if ($exact) {
		$row.state = "ok"; $row.passedOn = $exact.By
	} else {
		$carried = $null
		$touch = @()
		foreach ($p in $mine) {
			$t = Get-Touching $s (Get-Changed $p.Tree)
			if ($t.Count -eq 0) { $carried = $p; break }
			if (-not $touch) { $touch = $t }
		}
		if ($carried) {
			$row.state = "ok"; $row.passedOn = "$($carried.By) (nothing it covers changed since)"
		} elseif ($mine.Count -gt 0) {
			$row.state = "stale"; $row.files = @($touch | Select-Object -First 6)
			$row.why = "$($touch.Count) covered file(s) changed since it last passed"
		}
	}
	# a later failure on code this one's still on overrides
	if ($ledger -and $ledger.state -ne "passed") {
		$since = if ($ledger.tree -eq $tree) { @() } else { Get-Touching $s (Get-Changed $ledger.tree) }
		$newer = (-not $mine) -or ([datetime]$ledger.at -gt ($mine | Select-Object -First 1).At)
		if ($newer -and $since.Count -eq 0) {
			$row.state = "failing"; $row.why = "$($ledger.state) in $($ledger.branch): $($ledger.why)"
		} elseif ($newer -and $row.state -ne "ok") {
			$row.state = "stale"; $row.why = "$($ledger.state) last time; covered files changed since"; $row.files = @($since | Select-Object -First 6)
		}
	}
	$rows += [pscustomobject]$row
}

$counts = [ordered]@{}
foreach ($k in @("ok", "stale", "failing", "never")) { $counts[$k] = @($rows | Where-Object { $_.state -eq $k }).Count }
$status = [ordered]@{ at = (Get-Date).ToString("o"); root = $root; branch = (Get-CrewBranch $root); tree = $tree; counts = $counts; groups = $groups; suites = $rows }
[System.IO.File]::WriteAllText((Join-Path $crew "status.json.tmp"), ($status | ConvertTo-Json -Depth 6 -Compress))
Move-Item -Force (Join-Path $crew "status.json.tmp") (Join-Path $crew "status.json")

if ($Stale) {
	($rows | Where-Object { $_.state -eq "stale" -or $_.state -eq "failing" } | ForEach-Object { $_.name }) -join " "
	exit 0
}
Write-Host ("{0} ok, {1} need to run, {2} failing, {3} never run   ({4}, {5})" -f $counts.ok, $counts.stale, $counts.failing, $counts.never, $status.branch, $tree.Substring(0, 8))
foreach ($r in $rows | Where-Object { $_.state -ne "ok" }) {
	$c = switch ($r.state) { "failing" { "Red" } "stale" { "Yellow" } default { "DarkGray" } }
	Write-Host ("  {0,-8} {1,-14} {2}{3}" -f $r.state, $r.name, $r.why, $(if ($r.files) { "  [" + ($r.files -join ", ") + "]" } else { "" })) -ForegroundColor $c
}

# Every test's state against this checkout's code (the main checkout's, from the Tests pane):
#   ok        passed with exactly the current contents of every file it loads (its recorded deps); before its
#             loads are recorded, passed on this exact code or on older code nothing since touches (test_map.txt)
#   stale     needs to run: files it loads changed since its last pass (they're listed)
#   failing   its last run failed or was stopped, and nothing it loads changed since
#   never     no pass on record (passes are kept a week, results under .git\crew)
# Writes .git\crew\status.json and prints a summary. Reads only git and small files: a few seconds.
#
#   .\tools\dev\test_status.ps1          # summary
#   .\tools\dev\test_status.ps1 -Stale   # just the names that need to run (stale, failing or never run), on one line
#   .\tools\dev\test_status.ps1 -Carry   # the release tier (prepush.ps1): a stale test whose newest pass is since the
#                                        # last release tag counts as ok when none of the files changed since it are
#                                        # test-side (tools/dev/*) or tied to it by test_map.txt ("carried"); smoketest
#                                        # and net always need their exact pass; full_only.txt's carry from any pass.
#                                        # Leaves status.json (the pane's) alone.
param([switch]$Stale, [switch]$Carry)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
Close-DeadRuns $crew
$tree = Get-TreeKey $root
$ctx = New-KeyContext $root $crew $tree

$tests = Get-AllTests
$all = $tests + (Get-NetKeys $crew)

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
# (a group per tools/dev/t/<group> folder, after the suites' groups)
foreach ($t in $tests) {
	$g = Get-AtomicGroup $t
	if (-not $g) { continue }
	$groupOf[$t] = $g
	if ($groups -notcontains $g) { $groups += $g }
}
if (@($all | Where-Object { -not $groupOf.ContainsKey($_) }).Count -gt 0) { $groups += "Other" }

$map = @()
foreach ($line in Get-Content (Join-Path $PSScriptRoot "test_map.txt")) {
	$l = $line.Trim()
	if (-not $l -or $l.StartsWith("#")) { continue }
	$parts = $l -split "\s+"
	$map += , @($parts[0], @($parts[1..($parts.Count - 1)]))
}
## The suites (and "net"/"netchain") a changed file pulls in, as affected.ps1 picks them for a test never run.
function Get-Hits([string]$f) {
	$hit = @()
	if ($f -match "^tools/dev/([a-z0-9_]+)\.gd$") { $hit += $Matches[1]; if ($Matches[1] -match "^net") { $hit += "net" } }
	foreach ($m in $map) { if ($f -like $m[0]) { $hit += $m[1] } }
	return $hit
}
## Does a change to `files` touch `suite` (by test_map.txt)? The files that do.
function Get-Touching([string]$suite, [string[]]$files) {
	$tokens = Get-MapTokens $suite
	return @($files | Where-Object { $f = $_; (Get-Hits $f | Where-Object { $tokens -contains $_ }).Count -gt 0 })
}
$diffs = @{}
function Get-Changed([string]$from) {
	if (-not $diffs.ContainsKey($from)) {
		$diffs[$from] = @(git -C $root diff --name-only $from $tree 2>$null | Where-Object { $_ } | ForEach-Object { $_ -replace "\\", "/" })
	}
	return $diffs[$from]
}

# every pass on record, per test, newest first (results\<key>\<test>.ok)
$passes = @{}
foreach ($d in Get-ChildItem (Join-Path $crew "results") -Directory -ErrorAction SilentlyContinue) {
	foreach ($ok in Get-ChildItem $d.FullName -Filter "*.ok" -ErrorAction SilentlyContinue) {
		$s = $ok.BaseName
		if (-not $passes.ContainsKey($s)) { $passes[$s] = @() }
		$passes[$s] += [pscustomobject]@{ Key = $d.Name; At = $ok.LastWriteTime; File = $ok.FullName }
	}
}
function Get-By($p) { return (Get-Content $p.File -TotalCount 1).Trim() }

# the carry tier: passes since the newest release tag (v*), and the tests that never carry
$carryFrom = [datetime]::MaxValue
if ($Carry) {
	$tag = @(git -C $root tag --list "v*" --sort=-creatordate | Select-Object -First 1)
	if ($tag) { $carryFrom = [datetime](git -C $root log -1 --format=%cI $tag[0]).Trim() }
}
$alwaysRun = @("smoketest", "net")
$fullOnly = @(Get-Content (Join-Path $PSScriptRoot "full_only.txt") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
## Of `files` (changed since `test`'s pass), the ones that make it run in the carry tier: test-side or mapped to it.
function Get-Covering([string]$test, [string[]]$files) {
	$mapped = Get-Touching $test $files
	return @($files | Where-Object { $_ -like "tools/dev/*" -or $mapped -contains $_ })
}

$rows = @()
foreach ($s in $all) {
	$since = $null
	$last = $null
	$ledger = $null
	$lf = Join-Path $crew "ledger\$s.json"
	if (Test-Path $lf) { $ledger = Get-Content $lf -Raw | ConvertFrom-Json }
	$row = [ordered]@{ name = $s; group = $(if ($groupOf.ContainsKey($s)) { $groupOf[$s] } else { "Other" }); state = "never"; why = ""; files = @(); last = $ledger; passedOn = "" }
	$k = Get-TestKey $ctx $s
	$mine = @($passes[$s] | Sort-Object At -Descending)
	$exact = $mine | Where-Object { $_.Key -eq $k.Key } | Select-Object -First 1
	if ($exact) {
		$row.state = "ok"; $row.passedOn = Get-By $exact
	} elseif ($k.Deps) {
		# what changed: its current deps against the newest pass that kept them
		$last = $mine | Where-Object { $_.Key.StartsWith("d") } | Select-Object -First 1
		if ($last) {
			$was = @{}
			foreach ($l in @(Get-Content $last.File | Select-Object -Skip 1)) { $was[(Get-KeyLine $ctx $l)] = $true }
			$since = @($k.Manifest | Where-Object { -not $was.ContainsKey($_) } | ForEach-Object { ($_ -split " ", 2)[0] })
		}
		if ($mine.Count -gt 0) {
			$row.state = "stale"
			$row.files = @($since | Select-Object -First 6)
			$row.why = if ($null -ne $since) { "$($since.Count) file(s) it loads changed since it last passed" } else { "files it loads changed since it last passed" }
		}
	} else {
		$carried = $null
		$touch = @()
		foreach ($p in @($mine | Where-Object { -not $_.Key.StartsWith("d") })) {
			$t = Get-Touching $s (Get-Changed $p.Key)
			if ($t.Count -eq 0) { $carried = $p; break }
			if (-not $touch) { $touch = $t }
		}
		if ($carried) {
			$row.state = "ok"; $row.passedOn = (Get-By $carried) + " (nothing it covers changed since)"
		} elseif ($mine.Count -gt 0) {
			$row.state = "stale"; $row.files = @($touch | Select-Object -First 6)
			$row.why = "$($touch.Count) covered file(s) changed since it last passed"
		}
	}
	# a later failure on code this one's still on overrides
	if ($ledger -and $ledger.state -ne "passed") {
		$newer = (-not $mine) -or ([datetime]$ledger.at -gt ($mine | Select-Object -First 1).At)
		$lkey = if ($ledger.key) { $ledger.key } else { $ledger.tree }
		$same = if ($k.Deps -or $lkey.StartsWith("d")) { $lkey -eq $k.Key } else { $lkey -eq $tree -or (Get-Touching $s (Get-Changed $lkey)).Count -eq 0 }
		if ($newer -and $same) {
			$row.state = "failing"; $row.why = "$($ledger.state) in $($ledger.branch): $($ledger.why)"
		} elseif ($newer -and $row.state -ne "ok") {
			$row.state = "stale"; $row.why = "$($ledger.state) last time; files it loads changed since"
		}
	}
	$dev = $fullOnly -contains $s
	if ($Carry -and $row.state -eq "stale" -and $null -ne $since -and $last -and ($dev -or $last.At -gt $carryFrom) -and $alwaysRun -notcontains $s) {
		$failedSince = $ledger -and $ledger.state -ne "passed" -and [datetime]$ledger.at -gt $last.At
		if (-not $failedSince -and ($dev -or (Get-Covering $s $since).Count -eq 0)) {
			$row.state = "ok"; $row.why = ""; $row.files = @()
			$row.passedOn = (Get-By $last) + " (carried: $($since.Count) file(s) it loads changed, none it covers)"
		}
	}
	$rows += [pscustomobject]$row
}

$counts = [ordered]@{}
foreach ($c in @("ok", "stale", "failing", "never")) { $counts[$c] = @($rows | Where-Object { $_.state -eq $c }).Count }
$landing = [ordered]@{ now = (Get-Landing $crew); queue = @(Get-LandQueue $crew) }
$status = [ordered]@{ at = (Get-Date).ToString("o"); root = $root; branch = (Get-CrewBranch $root); tree = $tree; counts = $counts; groups = $groups; suites = $rows; landing = $landing }
if (-not $Carry) {
	[System.IO.File]::WriteAllText((Join-Path $crew "status.json.tmp"), ($status | ConvertTo-Json -Depth 6 -Compress))
	Move-Item -Force (Join-Path $crew "status.json.tmp") (Join-Path $crew "status.json")
}

if ($Stale) {
	($rows | Where-Object { $_.state -ne "ok" } | ForEach-Object { $_.name }) -join " "
	exit 0
}
Write-Host ("{0} ok, {1} need to run, {2} failing, {3} never run   ({4}, {5})" -f $counts.ok, $counts.stale, $counts.failing, $counts.never, $status.branch, $tree.Substring(0, 8))
if ($landing.now) { Write-Host ("Landing: {0} ({1}){2}" -f $landing.now.branch, $landing.now.step, $(if ($landing.queue) { "; waiting: " + (@($landing.queue | ForEach-Object { $_.branch }) -join ", ") } else { "" })) -ForegroundColor Cyan }
foreach ($r in $rows | Where-Object { $_.state -ne "ok" }) {
	$c = switch ($r.state) { "failing" { "Red" } "stale" { "Yellow" } default { "DarkGray" } }
	Write-Host ("  {0,-8} {1,-14} {2}{3}" -f $r.state, $r.name, $r.why, $(if ($r.files) { "  [" + ($r.files -join ", ") + "]" } else { "" })) -ForegroundColor $c
}

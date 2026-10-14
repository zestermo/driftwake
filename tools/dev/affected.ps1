# Which tests what changed can affect, by the files each one loads (.git\crew\deps, recorded on its last pass):
# a test is picked when a changed file it loads is test-side (tools/dev/...) or one test_map.txt says it's about
# (by its name; an atomic test by "t", "t/<group>" or "t/<group>/<name>"), since every test loads most of the game
# through the autoloads (and a suite the world too). -Wide: every test whose loads include a changed file.
# A test with nothing recorded yet falls back to test_map.txt alone; one the map doesn't name is picked until its
# first pass records its loads.
#
#   .\tools\dev\affected.ps1                 # uncommitted changes (and new files) vs HEAD
#   .\tools\dev\affected.ps1 -Base main      # everything this branch changed since main, plus uncommitted
#   .\tools\dev\affected.ps1 -Explain        # why each test was picked
#   .\tools\dev\affected.ps1 -Since <tree> -To <tree>   # what changed between two trees
#
# Prints the tests on one line (or nothing). The co-op modes come out as "net", "net-chain"... (nettest.ps1 [mode]).
param(
	[string]$Base = "HEAD",
	[switch]$Explain,
	[switch]$Wide,
	[string]$Since = "",
	[string]$To = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
Push-Location $root
try {
	$files = @()
	if ($Since) {
		$files += git diff --name-only $Since $To
	} else {
		if ($Base -ne "HEAD") {
			$mb = (git merge-base $Base HEAD).Trim()
			$files += git diff --name-only $mb HEAD
		}
		$files += git diff --name-only HEAD
		$files += git ls-files --others --exclude-standard
	}
	$files = @($files | Where-Object { $_ } | ForEach-Object { $_ -replace "\\", "/" } | Select-Object -Unique)

	$map = @()
	foreach ($line in Get-Content (Join-Path $PSScriptRoot "test_map.txt")) {
		$l = $line.Trim()
		if (-not $l -or $l.StartsWith("#")) { continue }
		$parts = $l -split "\s+"
		$map += , @($parts[0], @($parts[1..($parts.Count - 1)]))
	}
	$mapped = @{}
	foreach ($m in $map) { foreach ($s in $m[1]) { $mapped[$s] = $true } }
	## The ones of `of` that test_map.txt (and the tools/dev/<suite>.gd rule) says cover `test`.
	function Get-MapHits([string]$test, [string[]]$of) {
		$tokens = Get-MapTokens $test
		return @($of | Where-Object {
			$f = $_
			$hit = @()
			if ($f -match "^tools/dev/([a-z0-9_]+)\.gd$") { $hit += $Matches[1]; if ($Matches[1] -match "^net") { $hit += "net" } }
			foreach ($m in $map) { if ($f -like $m[0]) { $hit += $m[1] } }
			@($hit | Where-Object { $tokens -contains $_ }).Count -gt 0
		})
	}

	$picked = @()
	$why = [ordered]@{}
	$loadedBy = @{}
	foreach ($t in @((Get-AllTests) + (Get-NetKeys $crew))) {
		$hits = Get-DepHits $crew $t $files
		if ($null -ne $hits) {
			foreach ($h in $hits) { $loadedBy[$h] = 1 + [int]$loadedBy[$h] }
			# (every test loads most of the game through the autoloads: of its loads, only the test-side files and
			# what the map says it's about pick it here; -Wide and prepush take them all)
			if (-not $Wide) { $hits = @($hits | Where-Object { $_ -like "tools/dev/*" -or (Get-MapHits $t @($_)).Count -gt 0 }) }
			if ($hits.Count -gt 0) { $picked += $t; $why[$t] = "loads " + (($hits | Select-Object -First 4) -join ", ") + $(if ($hits.Count -gt 4) { " (+$($hits.Count - 4))" } else { "" }) }
			continue
		}
		$known = @(Get-MapTokens $t | Where-Object { $mapped.ContainsKey($_) }).Count -gt 0
		if (-not $known -and -not ($t -like "net*")) {
			if ($files.Count -gt 0) { $picked += $t; $why[$t] = "no loads recorded yet, no map line" }
			continue
		}
		$hits = Get-MapHits $t $files
		if ($hits.Count -gt 0) { $picked += $t; $why[$t] = "no loads recorded yet; test_map: " + (($hits | Select-Object -First 4) -join ", ") }
	}
	if ($Explain) {
		foreach ($k in $why.Keys) { Write-Host ("{0,-24} {1}" -f $k, $why[$k]) }
		if (-not $Wide) {
			foreach ($f in $files) {
				if ($loadedBy[$f] -and $f -notlike "tools/dev/*" -and @($map | Where-Object { $f -like $_[0] }).Count -eq 0) {
					Write-Host ("unmapped: {0} (loaded by {1} recorded tests: prepush or -Wide runs them)" -f $f, $loadedBy[$f]) -ForegroundColor Yellow
				}
			}
		}
		Write-Host ("{0} changed file(s), {1} test(s) picked{2}" -f $files.Count, $picked.Count, $(if ($Wide) { " (-Wide: every test that loads one)" } else { "" })) -ForegroundColor DarkGray
	}
	($picked -join " ")
} finally {
	Pop-Location
}

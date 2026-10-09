# Which test suites cover what changed (tools/dev/test_map.txt).
#
#   .\tools\dev\affected.ps1                 # uncommitted changes (and new files) vs HEAD
#   .\tools\dev\affected.ps1 -Base main      # everything this branch changed since main, plus uncommitted
#   .\tools\dev\affected.ps1 -Explain        # which file pulled in which suites
#
# Prints the suites on one line (or nothing). "net" means run nettest.ps1 as well.
# Changed .gd files no line covers are listed as unmapped (consider a map line).
param(
	[string]$Base = "HEAD",
	[switch]$Explain
)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Push-Location $root
try {
	$files = @()
	if ($Base -ne "HEAD") {
		$mb = (git merge-base $Base HEAD).Trim()
		$files += git diff --name-only $mb HEAD
	}
	$files += git diff --name-only HEAD
	$files += git ls-files --others --exclude-standard
	$files = @($files | Where-Object { $_ } | ForEach-Object { $_ -replace "\\", "/" } | Select-Object -Unique)

	$map = @()
	foreach ($line in Get-Content (Join-Path $PSScriptRoot "test_map.txt")) {
		$l = $line.Trim()
		if (-not $l -or $l.StartsWith("#")) { continue }
		$parts = $l -split "\s+"
		$map += , @($parts[0], @($parts[1..($parts.Count - 1)]))
	}

	$suites = [ordered]@{}
	$unmapped = @()
	foreach ($f in $files) {
		$hit = @()
		if ($f -match "^tools/dev/([a-z0-9_]+)\.gd$" -and (Test-Path (Join-Path $PSScriptRoot "$($Matches[1]).gd"))) {
			$name = $Matches[1]
			if ($name -match "test$|^feat$|^feel$|^dash$") { $hit += $name }
			if ($name -match "^net") { $hit += "net" }
		}
		foreach ($m in $map) {
			if ($f -like $m[0]) { $hit += $m[1] }
		}
		$hit = @($hit | Select-Object -Unique)
		if ($hit.Count -gt 0) {
			foreach ($s in $hit) { $suites[$s] = $true }
			if ($Explain) { Write-Host ("{0,-48} {1}" -f $f, ($hit -join " ")) }
		} elseif ($f -like "*.gd" -and $f -notlike "tools/*") {
			$unmapped += $f
		}
	}
	foreach ($u in $unmapped) { Write-Host "unmapped: $u" -ForegroundColor Yellow }
	($suites.Keys -join " ")
} finally {
	Pop-Location
}

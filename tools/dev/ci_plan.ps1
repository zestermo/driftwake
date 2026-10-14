# The CI's matrix (.github/workflows/tests.yml): every suite in suites.txt, each heavy one (heavy.txt) in a job
# of its own, the rest dealt over `-Shards` jobs, longest first onto the lightest job (times: suite_times.txt),
# and the atomic tests (tools/dev/t/) in one more.
# Writes `shards=<json>` to $GITHUB_OUTPUT when it's set, and prints the plan.
#
#   pwsh tools/dev/ci_plan.ps1 [-Shards 11]
param([int]$Shards = 11)
$ErrorActionPreference = "Stop"

function Read-List([string]$name) {
	return @(Get-Content (Join-Path $PSScriptRoot $name) | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") })
}
$suites = Read-List "suites.txt"
$heavy = Read-List "heavy.txt"
$secs = @{}
foreach ($l in Read-List "suite_times.txt") { $p = $l -split "\s+"; $secs[$p[0]] = [int]$p[1] }
function Get-Secs([string]$s) { if ($secs.ContainsKey($s)) { return $secs[$s] }; return 60 }

$bins = @(1..$Shards | ForEach-Object { [pscustomobject]@{ Secs = 0; Suites = New-Object System.Collections.Generic.List[string] } })
foreach ($s in @($suites | Where-Object { $heavy -notcontains $_ } | Sort-Object { Get-Secs $_ } -Descending)) {
	$b = $bins | Sort-Object Secs | Select-Object -First 1
	$b.Suites.Add($s)
	$b.Secs += Get-Secs $s
}
$plan = @($suites | Where-Object { $heavy -contains $_ } | ForEach-Object { [pscustomobject]@{ Secs = Get-Secs $_; Suites = @($_) } }) + @($bins | Where-Object { $_.Suites.Count -gt 0 })
# (the atomic tests, tools/dev/t/<group>/<name>.gd: one job, run_tests.ps1 takes "t" as all of them)
$atomic = @(Get-ChildItem (Join-Path $PSScriptRoot "t") -Directory -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem $_.FullName -Filter "*.gd" } | Where-Object { -not $_.Name.StartsWith("_") })
if ($atomic.Count -gt 0) { $plan += [pscustomobject]@{ Secs = 10 * $atomic.Count; Suites = @("t") } }
$matrix = @($plan | ForEach-Object { [ordered]@{ name = ($_.Suites -join " "); suites = ($_.Suites -join " ") } })
foreach ($p in $plan) { Write-Host ("{0,5} s  {1}" -f $p.Secs, ($p.Suites -join " ")) }
$json = ConvertTo-Json -InputObject $matrix -Compress
if ($env:GITHUB_OUTPUT) { Add-Content -Path $env:GITHUB_OUTPUT -Value "shards=$json" -Encoding UTF8 }

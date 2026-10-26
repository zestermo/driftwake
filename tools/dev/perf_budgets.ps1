# Per-system budgets (tools/dev/perf_budgets.txt) against a bench result: each system's scripts summed from the
# result's scripts table (the old route's when it has one: what the gate's baseline is), the draw from the summary,
# each against its budget (over: yellow). Warns, never fails.
#   .\tools\dev\perf_budgets.ps1 1_23_before        # a label (tools/dev/out/bench/brinehollow_<label>.txt) or a path
param([Parameter(Mandatory = $true)][string]$Result)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "perf_budgets_lib.ps1")
$path = if (Test-Path $Result) { $Result } else { Join-Path $PSScriptRoot "out/bench/brinehollow_$Result.txt" }
$r = Read-BenchBudget $path
$null = Show-Budgets (Get-Budgets) $r.scripts $r.draw $Result

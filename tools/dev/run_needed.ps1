# Run every suite that needs it on this checkout's code (test_status.ps1: stale or failing), then
# the co-op modes that do. The Tests pane's "Run needed" starts this in its own window.
#
#   .\tools\dev\run_needed.ps1          # run them
#   .\tools\dev\run_needed.ps1 -List    # just say what it would run
param([switch]$List)
$ErrorActionPreference = "Stop"
$need = @((& (Join-Path $PSScriptRoot "test_status.ps1") -Stale) -split "\s+" | Where-Object { $_ })
$suites = @($need | Where-Object { $_ -notlike "net*" })
$nets = @($need | Where-Object { $_ -like "net*" } | ForEach-Object { if ($_ -eq "net") { "" } else { $_.Substring(4) } })
Write-Host ("Needs running: " + $(if ($need) { $need -join " " } else { "nothing" })) -ForegroundColor Cyan
if ($List -or $need.Count -eq 0) { exit 0 }
if ($suites.Count -gt 0) { & (Join-Path $PSScriptRoot "run_tests.ps1") @suites }
foreach ($m in $nets) {
	if ($m) { & (Join-Path $PSScriptRoot "nettest.ps1") $m } else { & (Join-Path $PSScriptRoot "nettest.ps1") }
}
# (the pane re-checks the status as each run finishes)

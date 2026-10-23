# Run every test that needs it on this checkout's code (test_status.ps1: stale, failing or never run), then
# the co-op modes that do. The Tests pane's "Run needed" starts this in its own window.
#
#   .\tools\dev\run_needed.ps1          # run them
#   .\tools\dev\run_needed.ps1 -List    # just say what it would run
#   .\tools\dev\run_needed.ps1 -Carry   # the release tier's set (test_status.ps1 -Carry; prepush.ps1 uses it)
param([switch]$List, [switch]$Carry)
$ErrorActionPreference = "Stop"
$need = @((& (Join-Path $PSScriptRoot "test_status.ps1") -Stale -Carry:$Carry) -split "\s+" | Where-Object { $_ })
$suites = @($need | Where-Object { $_ -notmatch "^net(-\w+)?$" })
$nets = @($need | Where-Object { $_ -match "^net(-\w+)?$" } | ForEach-Object { if ($_ -eq "net") { "" } else { $_.Substring(4) } })
Write-Host ("Needs running: " + $(if ($need) { $need -join " " } else { "nothing" })) -ForegroundColor Cyan
if ($List -or $need.Count -eq 0) { exit 0 }
if ($suites.Count -gt 0) { & (Join-Path $PSScriptRoot "run_tests.ps1") @suites -Jobs 5 }
foreach ($m in $nets) {
	if ($m) { & (Join-Path $PSScriptRoot "nettest.ps1") $m } else { & (Join-Path $PSScriptRoot "nettest.ps1") }
}
# (the pane re-checks the status as each run finishes)

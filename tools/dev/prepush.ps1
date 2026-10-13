# The gate before a push (a finished set of features or a version): every suite test_status calls stale or
# failing on this checkout, the slow ones (heavy.txt) and the co-op modes included, then push if nothing's left.
#
#   .\tools\dev\prepush.ps1            # run what's needed, push main if it all passes
#   .\tools\dev\prepush.ps1 -NoPush    # just run it
param([switch]$NoPush)
$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "run_needed.ps1")
$left = (& (Join-Path $PSScriptRoot "test_status.ps1") -Stale).Trim()
if ($left) {
	Write-Host "Still failing or not passed: $left. Not pushed." -ForegroundColor Red
	exit 1
}
Write-Host "Every suite is up to date on this code." -ForegroundColor Green
if (-not $NoPush) { git -C (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) push origin HEAD }

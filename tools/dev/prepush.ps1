# The gate before a push (a finished set of features or a version): every test test_status calls stale (a file
# it loads changed since its pass), failing or never run on this checkout, atomic tests, the slow suites
# (heavy.txt) and the co-op modes included, then push if nothing's left.
# -CI: GitHub runs every suite and co-op mode instead (ci.ps1 on HEAD's commit); green pushes that same commit
# and deletes its ci/ branch (a red one keeps it, for `gh run rerun --failed`).
#
#   .\tools\dev\prepush.ps1            # run what's needed here, push main if it all passes
#   .\tools\dev\prepush.ps1 -CI        # run it all on GitHub, push main if it all passes
#   .\tools\dev\prepush.ps1 -NoPush    # just run it (either way)
param([switch]$NoPush, [switch]$CI)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ($CI) {
	. (Join-Path $PSScriptRoot "ci_lib.ps1")
	$sha = (git -C $root rev-parse HEAD).Trim()
	$branch = (git -C $root rev-parse --abbrev-ref HEAD).Trim()
	$ref = Get-CiRef $root
	& (Join-Path $PSScriptRoot "ci.ps1")
	if ($LASTEXITCODE) { Write-Host "Not pushed ($ref kept)." -ForegroundColor Red; exit 1 }
	$pushed = 0
	if (-not $NoPush) { git -C $root push origin "${sha}:refs/heads/$branch"; $pushed = $LASTEXITCODE }
	git -C $root push origin --delete $ref
	exit $pushed
}
& (Join-Path $PSScriptRoot "run_needed.ps1")
$left = (& (Join-Path $PSScriptRoot "test_status.ps1") -Stale).Trim()
if ($left) {
	Write-Host "Still failing or not passed: $left. Not pushed." -ForegroundColor Red
	exit 1
}
Write-Host "Every suite is up to date on this code." -ForegroundColor Green
if (-not $NoPush) { git -C $root push origin HEAD }

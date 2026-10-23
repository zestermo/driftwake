# The gate before a push (a finished set of features or a version), the release tier: every test failing or
# never run, and every stale one (a file it loads changed since its pass) unless its newest pass is since the
# previous release tag (second newest v*) and none of the files changed since are test-side or tied to it by test_map.txt (carried:
# test_status.ps1 -Carry). smoketest and net always need their exact pass. Then push if nothing's left.
# -Full: the strict run instead, every stale test whatever changed (Zach's call: e.g. once per major version).
# -CI: GitHub runs every suite and co-op mode instead (ci.ps1 on HEAD's commit); green pushes that same commit
# and deletes its ci/ branch (a red one keeps it, for `gh run rerun --failed`).
# -Release (before tagging a version): after the tests, the performance gate (perf_gate.ps1: the Brinehollow
# bench against tools/dev/perf_baseline.txt, ~20 min) must pass too.
#
#   .\tools\dev\prepush.ps1            # run what's needed here, push main if it all passes
#   .\tools\dev\prepush.ps1 -Full      # every stale test, nothing carried
#   .\tools\dev\prepush.ps1 -CI        # run it all on GitHub, push main if it all passes
#   .\tools\dev\prepush.ps1 -Release   # either way, plus the performance gate
#   .\tools\dev\prepush.ps1 -NoPush    # just run it (either way)
param([switch]$NoPush, [switch]$CI, [switch]$Release, [switch]$Full)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

function Test-Perf {
	if (-not $Release) { return $true }
	& (Join-Path $PSScriptRoot "perf_gate.ps1") | Out-Host
	return $LASTEXITCODE -eq 0
}

if ($CI) {
	. (Join-Path $PSScriptRoot "ci_lib.ps1")
	$sha = (git -C $root rev-parse HEAD).Trim()
	$branch = (git -C $root rev-parse --abbrev-ref HEAD).Trim()
	$ref = Get-CiRef $root
	& (Join-Path $PSScriptRoot "ci.ps1")
	if ($LASTEXITCODE) { Write-Host "Not pushed ($ref kept)." -ForegroundColor Red; exit 1 }
	if (-not (Test-Perf)) { Write-Host "The performance gate failed: not pushed ($ref kept)." -ForegroundColor Red; exit 1 }
	$pushed = 0
	if (-not $NoPush) { git -C $root push origin "${sha}:refs/heads/$branch"; $pushed = $LASTEXITCODE }
	git -C $root push origin --delete $ref
	exit $pushed
}
$carry = -not $Full
if ($carry) {
	# what the carry tier can't see: changed files since the previous release tag that no test_map.txt line ties to a test
	$tag = @(git -C $root tag --list "v*" --sort=-creatordate | Select-Object -First 2 | Select-Object -Last 1)
	if ($tag) {
		$pats = @(Get-Content (Join-Path $PSScriptRoot "test_map.txt") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object { ($_ -split "\s+")[0] })
		$loose = @(git -C $root diff --name-only $tag[0] HEAD | Where-Object { $f = $_; $f -match "^(scripts|scenes|shaders)/" -and $f -notmatch "\.uid$" -and @($pats | Where-Object { $f -like $_ }).Count -eq 0 })
		if ($loose) { Write-Host ("Not in test_map.txt (carried tests don't rerun for these; add map lines or use -Full): " + ($loose -join " ")) -ForegroundColor Yellow }
	}
}
& (Join-Path $PSScriptRoot "run_needed.ps1") -Carry:$carry
$left = (& (Join-Path $PSScriptRoot "test_status.ps1") -Stale -Carry:$carry).Trim()
if ($left) {
	Write-Host "Still failing or not passed: $left. Not pushed." -ForegroundColor Red
	exit 1
}
Write-Host $(if ($carry) { "Every test is up to date on this code or carried (nothing it covers changed)." } else { "Every suite is up to date on this code." }) -ForegroundColor Green
if (-not (Test-Perf)) { Write-Host "The performance gate failed: not pushed." -ForegroundColor Red; exit 1 }
if (-not $NoPush) { git -C $root push origin HEAD }

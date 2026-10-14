# Every suite and the co-op modes on GitHub (.github/workflows/tests.yml) for this checkout's HEAD: pushes it to
# origin ci/<branch> (never main; a detached HEAD goes as ci/<short sha>), waits for that commit's Tests run,
# prints each job's verdict and the failures, and exits 0 if it all passed. Only committed work is tested.
# prepush.ps1 -CI runs it, then pushes the same commit and deletes the ci/ branch.
#
#   .\tools\dev\ci.ps1
param()
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "ci_lib.ps1")
$sha = (git -C $root rev-parse HEAD).Trim()
$ref = Get-CiRef $root
if (git -C $root status --porcelain --untracked-files=no) { Write-Host "Uncommitted changes aren't tested: CI runs HEAD ($($sha.Substring(0, 8)))." -ForegroundColor Yellow }

$before = @(gh run list --workflow tests.yml --branch $ref --commit $sha --json databaseId --jq ".[].databaseId")
git -C $root push --force origin "HEAD:refs/heads/$ref"
if ($LASTEXITCODE) { Write-Host "Push to $ref failed." -ForegroundColor Red; exit 1 }

# (GitHub starts the run a few seconds after the push)
$id = $null
for ($i = 0; $i -lt 40 -and -not $id; $i++) {
	Start-Sleep -Seconds 3
	$id = @(gh run list --workflow tests.yml --branch $ref --commit $sha --event push --json databaseId --jq ".[].databaseId") | Where-Object { $before -notcontains $_ } | Select-Object -First 1
}
if (-not $id) { Write-Host "No Tests run started for $ref at $($sha.Substring(0, 8))." -ForegroundColor Red; exit 1 }
Write-Host ("Tests run: " + (gh run view $id --json url --jq .url)) -ForegroundColor Cyan

gh run watch $id --exit-status --compact --interval 30
$ok = $LASTEXITCODE -eq 0
Write-Host ""
foreach ($j in (gh run view $id --json jobs | ConvertFrom-Json).jobs) {
	$mins = ([datetime]$j.completedAt - [datetime]$j.startedAt).TotalMinutes
	Write-Host ("{0,-9} {1,4:0.0} min  {2}" -f $j.conclusion, $mins, $j.name) -ForegroundColor $(if ($j.conclusion -eq "success") { "Green" } else { "Red" })
	if ($j.conclusion -ne "failure") { continue }
	foreach ($a in (gh api "repos/{owner}/{repo}/check-runs/$($j.databaseId)/annotations" | ConvertFrom-Json)) {
		if ($a.annotation_level -eq "failure" -and -not $a.message.StartsWith("Process completed")) { Write-Host "    $($a.title): $($a.message)" -ForegroundColor Red }
	}
}
if ($ok) { Write-Host "CI PASSED ($ref at $($sha.Substring(0, 8)))" -ForegroundColor Green; exit 0 }
Write-Host "CI FAILED: the failing jobs' summaries are on the run's page; logs: gh run view $id --log-failed" -ForegroundColor Red
exit 1

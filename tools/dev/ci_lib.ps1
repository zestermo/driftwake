# The CI side of run_tests.ps1 / nettest.ps1 -CI (GitHub Actions, .github/workflows/tests.yml): an in-memory
# run instead of the crew's live one, and each suite's verdict as a row for the job summary and an annotation.
# Plus the branch ci.ps1 / prepush.ps1 -CI push to.

## ci/<branch>, or ci/<short sha> on a detached HEAD.
function Get-CiRef([string]$root) {
	$b = (git -C $root rev-parse --abbrev-ref HEAD).Trim()
	if ($b -eq "HEAD") { $b = (git -C $root rev-parse --short=8 HEAD).Trim() }
	return "ci/$b"
}

function New-CiRun([string[]]$names) {
	$suites = [ordered]@{}
	foreach ($n in $names) { $suites[$n] = [ordered]@{ name = $n; state = "queued"; secs = 0; log = ""; pid = 0; last = @(); why = ""; seed = "" } }
	return [pscustomobject]@{ Data = [ordered]@{ suites = $suites; state = "running" }; File = ""; Saved = [datetime]::MinValue }
}

## A suite's verdict (`state` PASS / FAIL / STOPPED), its failure block (lines), replacing an earlier try's row.
function Add-CiRow($rows, [string]$name, [int]$secs, [string]$state, [string[]]$block, [string]$seed) {
	$note = if ($rows.Contains($name)) { " (retried: known flake)" } else { "" }
	$rows[$name] = [pscustomobject]@{ Name = $name; Secs = $secs; State = "$state$note"; Block = @($block); Seed = $seed }
}

## The rows as a table on the job summary, each failure's block under it, and an error annotation per failure.
function Write-CiSummary([string]$title, $rows) {
	$md = New-Object System.Collections.Generic.List[string]
	$md.Add("### $title")
	$md.Add("")
	$md.Add("| Suite | Time | Result |")
	$md.Add("|---|--:|---|")
	foreach ($r in $rows.Values) { $md.Add(("| {0} | {1} s | {2} |" -f $r.Name, $r.Secs, $(if ($r.State -like "PASS*") { $r.State } else { "**$($r.State)**" }))) }
	foreach ($r in @($rows.Values | Where-Object { $_.State -notlike "PASS*" })) {
		$first = @($r.Block | Select-Object -First 1)[0]
		$md.Add("")
		$md.Add("<details open><summary>$($r.Name): $([System.Net.WebUtility]::HtmlEncode($first))</summary>")
		$md.Add("")
		$md.Add('```text')
		$r.Block | ForEach-Object { $md.Add($_) }
		if ($r.Seed) { $md.Add(("on seed {0}: .\tools\dev\run_tests.ps1 {1} -Seed {0}" -f $r.Seed, $r.Name)) }
		$md.Add('```')
		$md.Add("</details>")
		Write-Host ("::error title={0}::{1}" -f $r.Name, ($first -replace "%", "%25"))
	}
	$md.Add("")
	Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ($md -join "`n") -Encoding UTF8
}

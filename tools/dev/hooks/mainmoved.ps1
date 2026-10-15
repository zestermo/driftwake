# Dot-sourced by the tool hooks (guard.ps1 before every Bash/PowerShell command, crewcheck.ps1 after every
# edit): in a worktree branch, notices that main has commits the branch doesn't and says so once per new
# main head (Get-MainMovedNote: the text for additionalContext, or ""). It never acts by itself.
# The quiet path reads four small files and runs no git (main's head as last seen sits in
# <git common dir>\crew\mainseen\<branch>.txt); git only runs the first time a new main head is seen.

## The checkout `path` is in: the folder holding its .git (a file in a linked worktree), or "".
function Get-CheckoutDir([string]$path) {
	$dir = $path
	while ($dir -and -not (Test-Path (Join-Path $dir ".git"))) { $dir = Split-Path $dir -Parent }
	return $dir
}

## The note for the worktree checked out at `dir` (Get-CheckoutDir's), or "" (the main checkout, a detached
## or mid-rebase HEAD, main not moved since last time, or main already in the branch).
function Get-MainMovedNote([string]$dir, [string]$main = "main") {
	if (-not $dir) { return "" }
	$dotgit = Join-Path $dir ".git"
	if (Test-Path $dotgit -PathType Container) { return "" }
	$gitdir = ([System.IO.File]::ReadAllText($dotgit).Trim() -replace "^gitdir:\s*", "")
	if (-not [System.IO.Path]::IsPathRooted($gitdir)) { $gitdir = Join-Path $dir $gitdir }
	$head = [System.IO.File]::ReadAllText((Join-Path $gitdir "HEAD")).Trim()
	if (-not $head.StartsWith("ref: refs/heads/")) { return "" }
	$branch = $head.Substring(16)
	if ($branch -eq $main) { return "" }
	$common = [System.IO.Path]::GetFullPath((Join-Path $gitdir ([System.IO.File]::ReadAllText((Join-Path $gitdir "commondir")).Trim())))
	$ref = Join-Path $common "refs\heads\$main"
	if (Test-Path $ref) { $tip = [System.IO.File]::ReadAllText($ref).Trim() }
	else {
		$line = @([System.IO.File]::ReadAllLines((Join-Path $common "packed-refs")) | Where-Object { $_.EndsWith(" refs/heads/$main") })[0]
		$tip = $line.Substring(0, 40)
	}
	$seenDir = Join-Path $common "crew\mainseen"
	$seen = Join-Path $seenDir (($branch -replace "[\\/]", "_") + ".txt")
	if ((Test-Path $seen) -and [System.IO.File]::ReadAllText($seen).Trim() -eq $tip) { return "" }
	New-Item -ItemType Directory -Force -Path $seenDir | Out-Null
	[System.IO.File]::WriteAllText($seen, $tip)

	$eap = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	git -C $dir merge-base --is-ancestor $tip HEAD 2>$null
	$inBranch = $LASTEXITCODE -eq 0
	$subjects = @()
	if (-not $inBranch) { $subjects = @(git -C $dir log --no-merges --format=%s "HEAD..$tip" 2>$null) }
	$ErrorActionPreference = $eap
	if ($inBranch -or $subjects.Count -eq 0) { return "" }
	$shown = @($subjects | Select-Object -First 3 | ForEach-Object { if ($_.Length -gt 90) { $_.Substring(0, 87) + "..." } else { $_ } })
	$what = "{0} new commit(s): {1}{2}" -f $subjects.Count, ($shown -join "; "), $(if ($subjects.Count -gt 3) { "; and $($subjects.Count - 3) more" } else { "" })
	return "$main moved ($what): at your next clean point, commit your work, run ``git merge $main``, fix any conflicts, rerun your covering tests. (Merge, don't rebase, to sync mid-work; land.ps1 then fast-forwards.)"
}

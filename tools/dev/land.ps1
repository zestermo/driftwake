# Land a finished parallel session (a Claude Code worktree branch) on main. Agents land their own branch.
#
#   .\tools\dev\land.ps1                         # in a worktree: land this worktree's branch
#   .\tools\dev\land.ps1 worktree-ships          # rebase onto main, compile + smoketest + the tests it affects (by their loads), fast-forward main
#   .\tools\dev\land.ps1 worktree-ships -NoTests # skip the tests (the compile check and smoketest still run)
#   .\tools\dev\land.ps1 worktree-ships -Remove  # from the main checkout: then remove its worktree and branch (unwork.ps1)
#   .\tools\dev\land.ps1 -List                   # the worktrees, how far ahead of main each is, who's landing
#
# One landing at a time machine-wide: a second one waits its turn (.git\crew\landing.json, landq\) and
# says whom for. The branch's worktree must have everything committed (stray .uid files of its scripts
# are committed for it) and no test run going. The main checkout may have uncommitted work, but not in
# files this landing changes. On a rebase conflict nothing lands: run in the branch's own worktree it
# stops mid-rebase there for you to resolve; run from elsewhere it backs out. Either way it prints what
# to do. The target only moves forward (fast-forward), so nothing on it is ever overwritten. Never pushes.
# -Onto picks another target branch (it must be checked out somewhere, like main is).
param(
	[Parameter(Position = 0)][string]$Branch,
	[string]$Onto = "main",
	[switch]$NoTests,
	[switch]$Remove,
	[switch]$List,
	# (accepted and ignored: landing always runs the light set, run_tests -Changed -Light)
	[switch]$Light,
	[string]$Godot = $env:GODOT
)
$ErrorActionPreference = "Stop"
$here = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $here

function Fail([string]$msg) {
	Write-Host $msg -ForegroundColor Red
	exit 1
}

function Get-FullPath([string]$p) { return [System.IO.Path]::GetFullPath($p).TrimEnd("\") }

## The branch a worktree stopped mid-rebase is rebasing, or "".
function Get-RebasingBranch([string]$dir) {
	foreach ($p in @("rebase-merge", "rebase-apply")) {
		$f = (git -C $dir rev-parse --path-format=absolute --git-path "$p/head-name").Trim()
		if (Test-Path $f) { return ((Get-Content $f -Raw).Trim() -replace "^refs/heads/", "") }
	}
	return ""
}

# branch -> the worktree it's checked out in (or is being rebased in)
$trees = @{}
$rebasing = @{}
$cur = $null
foreach ($l in (git -C $here worktree list --porcelain)) {
	if ($l -like "worktree *") { $cur = $l.Substring(9) }
	elseif ($l -like "branch refs/heads/*") { $trees[$l.Substring(18)] = $cur }
	elseif ($l -eq "detached" -and (Test-Path $cur)) { $b = Get-RebasingBranch $cur; if ($b) { $rebasing[$b] = $cur } }
}

if (-not $Branch -and -not $List) {
	$mine = Get-CrewBranch $here
	if ($mine -eq "HEAD") { $mine = Get-RebasingBranch $here }
	if ($mine -and $mine -ne $Onto) { $Branch = $mine }
}
if ($Branch -and $rebasing.ContainsKey($Branch)) {
	Fail "$Branch is in the middle of a rebase in $($rebasing[$Branch]): fix the conflicted files, git add them, git rebase --continue (or git rebase --abort), then land again."
}
if ($List -or -not $Branch) {
	foreach ($b in $trees.Keys) {
		if ($b -eq $Onto) { continue }
		$ahead = (git -C $here rev-list --count "$Onto..$b").Trim()
		$behind = (git -C $here rev-list --count "$b..$Onto").Trim()
		$dirty = if (git -C $trees[$b] status --porcelain) { "  (uncommitted changes)" } else { "" }
		Write-Host ("{0,-28} {1} ahead, {2} behind {3}  {4}{5}" -f $b, $ahead, $behind, $Onto, $trees[$b], $dirty)
	}
	$now = Get-Landing $crew
	$waiting = @(Get-LandQueue $crew | ForEach-Object { $_.branch })
	if ($now) { Write-Host ("Landing now: {0} ({1}, since {2:HH:mm})" -f $now.branch, $now.step, [datetime]$now.since) -ForegroundColor Cyan }
	if ($waiting) { Write-Host ("Waiting to land: " + ($waiting -join ", ")) -ForegroundColor Cyan }
	exit 0
}

if (-not $trees.ContainsKey($Branch)) { Fail "No worktree has branch '$Branch' checked out (see -List)." }
if (-not $trees.ContainsKey($Onto)) { Fail "'$Onto' isn't checked out anywhere." }
$wt = $trees[$Branch]
$target = $trees[$Onto]
$self = (Get-FullPath $here) -eq (Get-FullPath $wt)
$name = $Branch -replace "^worktree-", ""

## Untracked .uid files of the branch's scripts (Godot writes one per new script when it imports): committed with them.
function Save-StrayUids([string]$dir) {
	$uids = @(git -C $dir ls-files --others --exclude-standard -- "*.uid" | Where-Object { $_ -and (Test-Path (Join-Path $dir ($_ -replace "\.uid$", ""))) })
	if ($uids.Count -eq 0) { return }
	git -C $dir add -- $uids
	git -C $dir commit -q -m "The new scripts' .uid files" | Out-Null
	Write-Host ("Committed {0} stray .uid file(s) on {1}: {2}" -f $uids.Count, $Branch, ($uids -join ", ")) -ForegroundColor DarkYellow
}

## Refuses when the main checkout has uncommitted work (changed, staged or untracked) in any of `files`.
## An untracked .uid there that the landing brings its own copy of is the editor's import of the script: deleted.
function Assert-MainClean([string[]]$files) {
	$hit = @()
	foreach ($l in @(git -C $target status --porcelain -uall)) {
		foreach ($p in @($l.Substring(3) -split " -> " | ForEach-Object { $_.Trim('"') })) {
			if ($files -notcontains $p) { continue }
			if ($l.StartsWith("??") -and $p -like "*.uid") {
				Remove-Item (Join-Path $target $p) -Force
				Write-Host "Deleted the main checkout's untracked $p (generated; the landing brings its own)." -ForegroundColor DarkYellow
			} else { $hit += $p }
		}
	}
	if ($hit) {
		Fail ("The main checkout ($target) has uncommitted changes in files this landing changes: {0}. Nothing landed. Whoever is editing them there commits them (git add -- <files>; git commit) or sets them aside, then land again." -f (($hit | Select-Object -Unique) -join ", "))
	}
}

Save-StrayUids $wt
$dirty = @(git -C $wt status --porcelain)
if ($dirty) { Fail ("$Branch has uncommitted changes in ${wt}: commit them first.`n  " + (($dirty | Select-Object -First 10) -join "`n  ")) }
Close-DeadRuns $crew
foreach ($f in Get-ChildItem (Join-Path $crew "live") -Filter "*.json" -ErrorAction SilentlyContinue) {
	$r = Get-Content $f.FullName -Raw | ConvertFrom-Json
	if (($r.state -eq "running" -or $r.state -eq "compiling") -and (Get-FullPath $r.root) -eq (Get-FullPath $wt)) {
		Fail "A test run is going in $wt (run $($r.id), pid $($r.pid)): let it finish (or stop it), then land."
	}
}
$n = (git -C $here rev-list --count "$Onto..$Branch").Trim()
if ($n -eq "0") { Write-Host "$Branch has nothing $Onto doesn't." -ForegroundColor Yellow; exit 0 }
Assert-MainClean @(git -C $here diff --name-only "$Onto...$Branch")

# who else is in the same files: they'll be merging with this once it's landed
$board = Get-CrewBoard $here $Onto
$o = Get-Overlaps $board $Branch @(($board.Rows | Where-Object { $_.Branch -eq $Branch }).Files)
$o = @($o | Where-Object { $_ -notlike "${Onto}:*" -and $_ -notlike "$Onto *" })
if ($o) {
	Write-Host "Other sessions are changing some of the same files (they'll rebase onto this):" -ForegroundColor Yellow
	$o | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}

$lock = Enter-Landing $crew $Branch
try {
	Assert-MainClean @(git -C $here diff --name-only "$Onto...$Branch")

	# onto the newest target
	Set-LandingStep $crew "rebasing"
	Write-Host "Rebasing $Branch ($n commits) onto $Onto..." -ForegroundColor Cyan
	$ErrorActionPreference = "Continue"
	git -C $wt rebase $Onto 2>&1 | ForEach-Object { "$_" } | Write-Host
	if ($LASTEXITCODE -ne 0) {
		$conflicts = (@(git -C $wt diff --name-only --diff-filter=U) -join ", ")
		if ($self) {
			Fail "Conflicts with $Onto in: $conflicts. Nothing landed; this worktree is stopped mid-rebase. Fix those files, git add them, git rebase --continue (again each time it stops), then run .\tools\dev\land.ps1 again. (git rebase --abort puts the branch back as it was.)"
		}
		git -C $wt rebase --abort 2>&1 | Out-Null
		Fail "Conflicts with $Onto in: $conflicts. Nothing landed; $wt is as it was. In that worktree: git rebase $Onto, fix those files, git add them, git rebase --continue, then .\tools\dev\land.ps1 again."
	}

	# it still compiles, the islands still build (smoketest, -NoTests or not) and its tests pass, with the target underneath
	Set-LandingStep $crew "compiling"
	Update-ImportCache $wt $Godot
	Save-StrayUids $wt
	& $Godot --headless --path "$wt" --script res://tools/dev/compilecheck.gd 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0) { Fail "$Branch doesn't compile on top of $Onto (run tools/dev/compilecheck.gd there)." }
	# (-Exact: never carried over the rebase by its dependencies, it's there for what the two sides do together)
	Set-LandingStep $crew "smoketest"
	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $wt "tools\dev\run_tests.ps1") smoketest -Exact -NoCompileCheck
	if ($LASTEXITCODE -ne 0) { Fail "The island smoke test failed on top of ${Onto}: not landed (log: $wt\tools\dev\out\logs\smoketest.log)." }
	if (-not $NoTests) {
		# (the tests whose loads the branch changes; a pass on the same contents of what a test loads carries over the rebase)
		Set-LandingStep $crew "tests"
		& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $wt "tools\dev\run_tests.ps1") -Changed -Light -Base $Onto -NoCompileCheck
		if ($LASTEXITCODE -ne 0) { Fail "Tests failed on top of ${Onto}: not landed (logs in $wt\tools\dev\out\logs)." }
	}

	# the target moves forward to it (git refuses rather than overwrite anything)
	Set-LandingStep $crew "fast-forward"
	git -C $here merge-base --is-ancestor $Onto $Branch
	if ($LASTEXITCODE -ne 0) { Fail "$Onto moved while this was testing (a commit made there outside land.ps1). Nothing landed; run land again (passes carry over)." }
	$files = @(git -C $here diff --name-only $Onto $Branch)
	$n = (git -C $here rev-list --count "$Onto..$Branch").Trim()
	Assert-MainClean $files
	git -C $target merge --ff-only $Branch 2>&1 | ForEach-Object { "$_" } | Write-Host
	if ($LASTEXITCODE -ne 0) { Fail "$Onto couldn't fast-forward (see git's message above). Nothing landed." }
	Remove-Item (Join-Path $crew ("claims\" + ($Branch -replace "[\\/]", "_") + ".json")) -Force -ErrorAction SilentlyContinue
	# (a class_name it brings: the target's runs outside the editor and the runners, the bench and the renders, need it imported)
	Set-LandingStep $crew "importing $Onto"
	Update-ImportCache $target $Godot
} finally {
	Exit-Landing $crew $lock
}

Write-Host ("Landed {0} on {1}: {2} commit(s), {3} file(s), now at {4}{5}. Not pushed." -f $Branch, $Onto, $n, $files.Count, (git -C $here rev-parse --short $Onto).Trim(), $(if ($NoTests) { " (smoketest only)" } else { "" })) -ForegroundColor Green
if ($Remove -and -not $self) {
	& (Join-Path $PSScriptRoot "unwork.ps1") $name -Onto $Onto
	exit $LASTEXITCODE
}
if ($Remove) { Write-Host "Not removing the worktree this runs in: once its session is closed, from the main checkout: .\tools\dev\unwork.ps1 $name" -ForegroundColor DarkGray }
elseif (-not $self) { Write-Host "Once its session is closed: .\tools\dev\unwork.ps1 $name (removes the worktree and its branch)." -ForegroundColor DarkGray }
exit 0

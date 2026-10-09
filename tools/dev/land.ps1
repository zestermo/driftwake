# Land a finished parallel session (a Claude Code worktree branch) on main.
#
#   .\tools\dev\land.ps1 worktree-ships          # rebase onto main, compile + covering tests, fast-forward main
#   .\tools\dev\land.ps1 worktree-ships -NoTests # skip the tests (the compile check still runs)
#   .\tools\dev\land.ps1 -List                   # the worktrees and how far ahead of main each is
#
# The branch's worktree must have everything committed. If the rebase hits a
# conflict it's undone and nothing changes; resolve it in that worktree (or ask
# its Claude session to) and run this again. The target only moves forward
# (fast-forward), so nothing on it is ever overwritten. -Onto picks another
# target branch (it must be checked out somewhere, like main is).
param(
	[Parameter(Position = 0)][string]$Branch,
	[string]$Onto = "main",
	[switch]$NoTests,
	[switch]$List,
	[string]$Godot = $env:GODOT
)
$ErrorActionPreference = "Stop"
$here = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

function Fail([string]$msg) {
	Write-Host $msg -ForegroundColor Red
	exit 1
}

# branch -> the worktree it's checked out in
$trees = @{}
$cur = $null
foreach ($l in (git -C $here worktree list --porcelain)) {
	if ($l -like "worktree *") { $cur = $l.Substring(9) }
	elseif ($l -like "branch refs/heads/*") { $trees[$l.Substring(18)] = $cur }
}

if ($List -or -not $Branch) {
	foreach ($b in $trees.Keys) {
		if ($b -eq $Onto) { continue }
		$ahead = (git -C $here rev-list --count "$Onto..$b").Trim()
		$behind = (git -C $here rev-list --count "$b..$Onto").Trim()
		$dirty = if (git -C $trees[$b] status --porcelain) { "  (uncommitted changes)" } else { "" }
		Write-Host ("{0,-28} {1} ahead, {2} behind {3}  {4}{5}" -f $b, $ahead, $behind, $Onto, $trees[$b], $dirty)
	}
	exit 0
}

if (-not $trees.ContainsKey($Branch)) { Fail "No worktree has branch '$Branch' checked out (see -List)." }
if (-not $trees.ContainsKey($Onto)) { Fail "'$Onto' isn't checked out anywhere." }
$wt = $trees[$Branch]
$target = $trees[$Onto]
if (git -C $wt status --porcelain) { Fail "$Branch has uncommitted changes in ${wt}: commit them first." }
$n = (git -C $here rev-list --count "$Onto..$Branch").Trim()
if ($n -eq "0") { Write-Host "$Branch has nothing $Onto doesn't." -ForegroundColor Yellow; exit 0 }

# onto the newest target
Write-Host "Rebasing $Branch ($n commits) onto $Onto..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
git -C $wt rebase $Onto 2>&1 | ForEach-Object { "$_" } | Write-Host
$ok = $LASTEXITCODE -eq 0
if (-not $ok) {
	$conflicts = @(git -C $wt diff --name-only --diff-filter=U)
	git -C $wt rebase --abort 2>&1 | Out-Null
	Fail "Conflicts with $Onto in: $($conflicts -join ', '). Nothing landed. Resolve them in $wt (git rebase $Onto there), then run this again."
}

# it still compiles and its tests pass, with the target underneath
if ($NoTests) {
	& $Godot --headless --path "$wt" --script res://tools/dev/compilecheck.gd 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0) { Fail "$Branch doesn't compile on top of $Onto (run tools/dev/compilecheck.gd there)." }
} else {
	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $wt "tools\dev\run_tests.ps1") -Changed -Base $Onto -Jobs 2
	if ($LASTEXITCODE -ne 0) { Fail "Tests failed on top of ${Onto}: not landed (logs in $wt\tools\dev\out\logs)." }
}

# the target moves forward to it (git refuses rather than overwrite anything)
git -C $target merge --ff-only $Branch 2>&1 | ForEach-Object { "$_" } | Write-Host
if ($LASTEXITCODE -ne 0) { Fail "$Onto couldn't fast-forward (uncommitted changes in $target touch the same files?). Nothing landed." }
Write-Host "Landed $n commits from $Branch on $Onto. Remove the worktree when its session is closed: git worktree remove `"$wt`"" -ForegroundColor Green
exit 0

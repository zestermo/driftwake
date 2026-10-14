# Remove a landed session's worktree folder and its branch (git worktree remove fails on Windows with
# "Filename too long" in its .godot cache: this deletes through a \\?\ long path instead).
#
#   .\tools\dev\unwork.ps1 ships              # .claude\worktrees\ships and branch worktree-ships
#   .\tools\dev\unwork.ps1 worktree-ships     # the same
#   .\tools\dev\unwork.ps1 ships -Force       # even with commits main doesn't have or uncommitted work (both lost)
#
# Run it from the main checkout once the session working there is closed (a shell, editor or Godot
# still in the folder keeps files open). Releases the branch's claim.
param(
	[Parameter(Mandatory = $true, Position = 0)][string]$Name,
	[string]$Onto = "main",
	[switch]$Force
)
$ErrorActionPreference = "Stop"
$here = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $here

function Fail([string]$msg) {
	Write-Host $msg -ForegroundColor Red
	exit 1
}

$name = $Name -replace "^worktree-", ""
$branch = "worktree-$name"
$main = Split-Path (git -C $here rev-parse --path-format=absolute --git-common-dir).Trim() -Parent
$path = $null
$cur = $null
foreach ($l in (git -C $main worktree list --porcelain)) {
	if ($l -like "worktree *") { $cur = $l.Substring(9) }
	elseif ($l -eq "branch refs/heads/$branch") { $path = $cur }
}
if (-not $path) { $path = Join-Path $main ".claude\worktrees\$name" }
$path = [System.IO.Path]::GetFullPath($path).TrimEnd("\")
if ((Get-Location).Path.StartsWith($path, [System.StringComparison]::OrdinalIgnoreCase)) { Fail "This shell is in ${path}: run it from the main checkout ($main)." }

$hasBranch = [bool](git -C $main branch --list $branch)
if ($hasBranch -and -not $Force) {
	$ahead = (git -C $main rev-list --count "$Onto..$branch").Trim()
	if ($ahead -ne "0") { Fail "$branch has $ahead commit(s) $Onto doesn't: land it first (land.ps1), or -Force to throw them away." }
}
if ((Test-Path $path) -and -not $Force) {
	$dirty = @(git -C $path status --porcelain)
	if ($dirty) { Fail ("$path has uncommitted changes (-Force to throw them away):`n  " + (($dirty | Select-Object -First 10) -join "`n  ")) }
}

# (Windows PowerShell turns a native program's stderr into errors under "Stop")
$ErrorActionPreference = "Continue"
if (Test-Path $path) {
	& cmd.exe /d /c "rd /s /q `"\\?\$path`"" 2>&1 | Out-Null
	if (Test-Path $path) { Fail "Couldn't delete all of ${path}: something still has files open in it (its Claude session, a shell, an editor or Godot). Close it and run this again." }
}
git -C $main worktree prune
if ($hasBranch) {
	git -C $main branch $(if ($Force) { "-D" } else { "-d" }) $branch 2>&1 | ForEach-Object { "$_" } | Write-Host
	if ($LASTEXITCODE -ne 0) { Fail "The folder's gone but the branch $branch stays (see git's message above)." }
}
Remove-Item (Join-Path $crew "claims\$branch.json") -Force -ErrorAction SilentlyContinue
Write-Host "Removed $path and branch $branch." -ForegroundColor Green
exit 0

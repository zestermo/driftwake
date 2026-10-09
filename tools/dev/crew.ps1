# Who's working on what, across every parallel session (worktrees and the main checkout).
#
#   .\tools\dev\crew.ps1                                   # the board: each session's task, files and test slots
#   .\tools\dev\crew.ps1 claim "sea legs" -Areas scripts/ship/enemy_fleet.gd,scripts/world/sea_legs.gd
#   .\tools\dev\crew.ps1 release                           # this checkout's claim goes (landing does it too)
#   .\tools\dev\crew.ps1 overlap                           # other sessions changing or claiming what this one changes
#   .\tools\dev\crew.ps1 -Brief                            # short form (the SessionStart hook)
#
# A claim is what a session says it will touch (areas: files, folders or globs, repo-relative);
# the files each session is actually changing are read from git, claim or not.
param(
	[Parameter(Position = 0)][string]$Cmd = "list",
	[Parameter(Position = 1)][string]$Task = "",
	[string[]]$Areas = @(),
	[switch]$Brief,
	[switch]$Hook
)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
# (a Claude Code hook: the session's own checkout is the cwd it's handed, not where this script lives)
if ($Hook) {
	$raw = [Console]::In.ReadToEnd()
	if ($raw) {
		$cwd = [string]($raw | ConvertFrom-Json).cwd
		if ($cwd -and (Test-Path $cwd)) { $root = (git -C $cwd rev-parse --show-toplevel).Trim() }
	}
	$Brief = $true
}
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
$me = Get-CrewBranch $root
$claimFile = Join-Path $crew ("claims\" + ($me -replace "[\\/]", "_") + ".json")

switch ($Cmd) {
	"claim" {
		if (-not $Task) { Write-Host "crew.ps1 claim `"what you're doing`" -Areas a,b" -ForegroundColor Red; exit 1 }
		$areas = @($Areas | ForEach-Object { $_ -split "," } | Where-Object { $_ } | ForEach-Object { ($_ -replace "\\", "/").Trim() })
		[pscustomobject]@{ task = $Task; areas = $areas; at = (Get-Date).ToString("o"); path = $root } |
			ConvertTo-Json | Set-Content -Path $claimFile -Encoding UTF8
		Write-Host "Claimed for ${me}: $Task" -ForegroundColor Green
		$o = Get-Overlaps (Get-CrewBoard $root) $me $areas
		if ($o) { Write-Host "Already being changed elsewhere:" -ForegroundColor Yellow; $o | ForEach-Object { Write-Host "  $_" } }
		exit 0
	}
	"release" {
		Remove-Item $claimFile -Force -ErrorAction SilentlyContinue
		Write-Host "Released $me's claim." -ForegroundColor Green
		exit 0
	}
	"overlap" {
		$board = Get-CrewBoard $root
		$mine = @(($board.Rows | Where-Object { $_.Branch -eq $me }).Files)
		$o = Get-Overlaps $board $me $mine
		if ($o) { $o | ForEach-Object { Write-Host $_ -ForegroundColor Yellow } } else { Write-Host "No other session touches what $me changes." }
		exit 0
	}
}

$board = Get-CrewBoard $root
$active = @($board.Rows | Where-Object { $_.Claim -or $_.Files.Count -gt 0 })
if ($Brief) {
	if ($active.Count -eq 0) { exit 0 }
	Write-Output "Parallel sessions on this repo right now (tools/dev/crew.ps1; this one is $me):"
	foreach ($r in $active) {
		$task = if ($r.Claim) { $r.Claim.task } else { "(no claim)" }
		# (not $areas: PowerShell names ignore case, and that's the [string[]] -Areas param)
		$claimed = if ($r.Claim -and @($r.Claim.areas).Count) { " areas: " + (@($r.Claim.areas) -join ", ") } else { "" }
		$top = @($r.Files | ForEach-Object { $_ -replace "/[^/]+$", "" } | Group-Object | Sort-Object Count -Descending | Select-Object -First 4 | ForEach-Object { $_.Name })
		Write-Output ("- {0}{1}: {2}; {3} files changing (in {4}){5}" -f $r.Branch, $(if ($r.Branch -eq $me) { " [this session]" } else { "" }), $task, $r.Files.Count, ($top -join ", "), $claimed)
	}
	Write-Output "Before editing a file another session is changing, keep the edit small and local (it merges when that branch lands). A test that fails in your worktree is your code or main's, never another session's uncommitted work."
	exit 0
}

foreach ($r in $board.Rows) {
	$tag = if ($r.Branch -eq $me) { "  <- this checkout" } else { "" }
	$task = if ($r.Claim) { $r.Claim.task } else { "(no claim)" }
	$color = if ($r.Claim -or $r.Files.Count -gt 0) { "Cyan" } else { "DarkGray" }
	Write-Host ("{0}  {1}  [{2} ahead, {3} files]{4}" -f $r.Branch, $task, $r.Ahead, $r.Files.Count, $tag) -ForegroundColor $color
	if ($r.Claim -and @($r.Claim.areas).Count) { Write-Host ("    claims: " + (@($r.Claim.areas) -join ", ")) }
	if ($r.Files.Count -gt 0) { Write-Host ("    " + ((@($r.Files) | Select-Object -First 10) -join ", ") + $(if ($r.Files.Count -gt 10) { ", ..." } else { "" })) -ForegroundColor DarkGray }
}
$held = Get-SlotHolders $crew
Write-Host ("Test slots: {0} of {1} in use{2}" -f $held.Count, (Get-SlotCount), $(if ($held.Count) { ": " + ($held -join "; ") } else { "" }))

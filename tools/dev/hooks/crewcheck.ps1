# Claude Code PostToolUse hook (.claude/settings.json): after Claude edits or
# writes a file another parallel session is also changing (or has claimed), tell
# Claude which session and what it's doing (additionalContext; never blocks).
# Reads the crew board cached for a minute, so it costs ~0.1 s per edit.
# In a worktree branch it also says, once per new main head, that main moved (mainmoved.ps1).
$ErrorActionPreference = "Stop"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$data = $raw | ConvertFrom-Json
$path = [string]$data.tool_input.file_path
if (-not $path -or -not (Test-Path $path)) { exit 0 }

. (Join-Path $PSScriptRoot "mainmoved.ps1")
$dir = Get-CheckoutDir (Split-Path (Resolve-Path $path).Path -Parent)
$notes = @()
$moved = Get-MainMovedNote $dir
if ($moved) { $notes += $moved }
# (a checkout from before the crew tools has no lib)
if ($dir -and (Test-Path (Join-Path $dir "tools\dev\crew_lib.ps1"))) {
	. (Join-Path $dir "tools\dev\crew_lib.ps1")
	$rel = (Resolve-Path $path).Path.Substring($dir.Length).TrimStart("\", "/") -replace "\\", "/"
	$me = Get-CrewBranch $dir
	$o = Get-Overlaps (Get-CrewBoardCached $dir) $me @($rel)
	if ($o) { $notes += "Heads-up: another parallel session is also changing $rel - " + ($o -join "; ") + ". Keep this edit small and local so it merges when the branches land; if it's a bigger overlap, tell the user." }
}
if (-not $notes) { exit 0 }
@{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = ($notes -join "`n") } } | ConvertTo-Json -Compress
exit 0

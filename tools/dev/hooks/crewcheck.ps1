# Claude Code PostToolUse hook (.claude/settings.json): after Claude edits or
# writes a file another parallel session is also changing (or has claimed), tell
# Claude which session and what it's doing (additionalContext; never blocks).
# Reads the crew board cached for a minute, so it costs ~0.1 s per edit.
$ErrorActionPreference = "Stop"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$data = $raw | ConvertFrom-Json
$path = [string]$data.tool_input.file_path
if (-not $path -or -not (Test-Path $path)) { exit 0 }

$dir = Split-Path (Resolve-Path $path).Path -Parent
while ($dir -and -not (Test-Path (Join-Path $dir ".git"))) { $dir = Split-Path $dir -Parent }
# (a checkout from before the crew tools has no lib)
if (-not $dir -or -not (Test-Path (Join-Path $dir "tools\dev\crew_lib.ps1"))) { exit 0 }
. (Join-Path $dir "tools\dev\crew_lib.ps1")
$rel = (Resolve-Path $path).Path.Substring($dir.Length).TrimStart("\", "/") -replace "\\", "/"
$me = Get-CrewBranch $dir
$o = Get-Overlaps (Get-CrewBoardCached $dir) $me @($rel)
if (-not $o) { exit 0 }
$msg = "Heads-up: another parallel session is also changing $rel - " + ($o -join "; ") + ". Keep this edit small and local so it merges when the branches land; if it's a bigger overlap, tell the user."
@{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $msg } } | ConvertTo-Json -Compress
exit 0

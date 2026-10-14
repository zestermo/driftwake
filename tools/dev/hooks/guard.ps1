# Claude Code PreToolUse hook (.claude/settings.json) on Bash and PowerShell commands: refuses
# the two that bite parallel work: a test run straight through Godot instead of the runners
# (no shared slots, no pass cache, invisible in the Tests pane), and `git add -A` / `git add .`
# in the main checkout (sweeps up another session's half-done files).
$ErrorActionPreference = "Stop"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$data = $raw | ConvertFrom-Json
$cmd = [string]$data.tool_input.command
if (-not $cmd) { exit 0 }

function Deny([string]$why) {
	@{ hookSpecificOutput = @{ hookEventName = "PreToolUse"; permissionDecision = "deny"; permissionDecisionReason = $why } } | ConvertTo-Json -Compress
	exit 0
}

$suites = @(Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) "suites.txt") | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object { $_.Trim() })
foreach ($m in [regex]::Matches($cmd, '--script\s+["'']?res://tools/dev/(\w+)\.gd')) {
	$s = $m.Groups[1].Value
	if ($suites -contains $s) {
		Deny "Run tests through the runner, not Godot directly: powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/run_tests.ps1 $s (it shares the test slots, caches passes and shows in the Tests pane)."
	}
}

$inWorktree = ([string]$data.cwd -match '[\\/]\.claude[\\/]worktrees[\\/]') -or ($cmd -match '\.claude[\\/]worktrees[\\/]')
# (quoted text dropped first: a commit message may mention git add -A)
$plain = $cmd -replace '"[^"]*"', '' -replace "'[^']*'", ''
if (-not $inWorktree -and $plain -match '\bgit\b(\s+-C\s+\S+)?\s+add\s+(-A\b|--all\b|\.(\s|$|;|&))') {
	Deny "Not git add -A / git add . in the main checkout: other sessions' unfinished files live here. Add your own paths: git add -- <file> <file>."
}
exit 0

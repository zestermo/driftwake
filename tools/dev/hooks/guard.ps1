# Claude Code PreToolUse hook (.claude/settings.json) on Bash and PowerShell commands: refuses
# the two that bite parallel work: a test run straight through Godot instead of the runners
# (no shared slots, no pass cache, invisible in the Tests pane), and `git add -A` / `git add .`
# in the main checkout (sweeps up another session's half-done files). Allows without a prompt the
# project's runners and tools (Test-SafeRun: whatever the session's permission mode). Otherwise, in a
# worktree branch, says once per new main head that main moved (mainmoved.ps1; additionalContext).
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

## True when every statement is an allowed runner or tool, each optionally piped into readers only.
## prepush/ci (push), unwork (deletes) and anything outside tools/dev still ask.
function Test-SafeRun([string]$c) {
	# a subexpression or an escape can run anything, even inside double quotes; a script block too
	if ($c -match '\$\(|`|[{}]') { return $false }
	$flat = ($c -replace '"\$(env:)?GODOT"', '$GODOT') -replace '"[^"]*"', '"q"' -replace "'[^']*'", "'q'"
	$flat = $flat -replace '\d?>&\d', ''
	if ($flat -match '[<>]') { return $false }
	$runner = '\.?[\\/]?tools[\\/]dev[\\/](run_tests|nettest|test_status|affected|run_needed|suite_times|crew|land|bench|bench_compare|perf_gate)\.ps1'
	$heads = @(
		"^$runner(\s|$)",
		"^powershell(\.exe)?(\s+-(NoProfile|NonInteractive|ExecutionPolicy\s+Bypass))*\s+-File\s+$runner(\s|$)",
		'^\$(env:)?GODOT\s.*--script\s+res://tools/dev/\w+\.gd(\s|$)',
		'^py\s+(-I\s+)?tools[\\/]texture_gen[\\/]\w+\.py(\s|$)'
	)
	$readers = '^(Select-Object|select|Select-String|sls|Sort-Object|sort|Measure-Object|measure|Format-Table|ft|Format-List|fl|Out-String|Out-Null|head|tail|grep|wc)(\s|$)'
	# (a lone & is a background job in bash or PowerShell's call operator: either way what follows is checked alone)
	$runs = 0
	foreach ($stmt in ($flat -split '&&|\|\||;|\r?\n|&')) {
		$stages = @($stmt -split '\|' | ForEach-Object { $_.Trim() })
		if ($stages.Count -eq 1 -and -not $stages[0]) { continue }
		if (-not ($heads | Where-Object { $stages[0] -match $_ })) { return $false }
		foreach ($s in ($stages | Select-Object -Skip 1)) { if ($s -notmatch $readers) { return $false } }
		$runs++
	}
	return $runs -gt 0
}

. (Join-Path $PSScriptRoot "mainmoved.ps1")
$note = Get-MainMovedNote (Get-CheckoutDir ([string]$data.cwd))
$out = @{ hookEventName = "PreToolUse" }
if (Test-SafeRun $cmd) { $out.permissionDecision = "allow"; $out.permissionDecisionReason = "a Driftwake runner or tool (guard.ps1)" }
if ($note) { $out.additionalContext = $note }
if ($out.Count -gt 1) { @{ hookSpecificOutput = $out } | ConvertTo-Json -Compress }
exit 0

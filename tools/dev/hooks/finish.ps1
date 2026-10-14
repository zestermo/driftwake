# Claude Code Stop / SubagentStop hook (.claude/settings.json): an agent working in a worktree
# (.claude/worktrees/*) can't finish with uncommitted changes or with a HEAD whose scripts don't
# all compile (the edit hook checks one file; a rename can break another). Blocks once: a second
# stop goes through, so a false alarm never traps an agent. The main checkout is never checked.
$ErrorActionPreference = "Stop"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$data = $raw | ConvertFrom-Json
if ($data.stop_hook_active) { exit 0 }
$cwd = [string]$data.cwd
if ($cwd -notmatch '[\\/]\.claude[\\/]worktrees[\\/]') { exit 0 }

$root = (git -C $cwd rev-parse --show-toplevel).Trim()
function Block([string]$why) {
	@{ decision = "block"; reason = $why } | ConvertTo-Json -Compress
	exit 0
}

$dirty = @(git -C $root status --porcelain)
if ($dirty) {
	Block ("This worktree has uncommitted changes. Commit them (or revert what you don't want) before finishing:`n" + (($dirty | Select-Object -First 15) -join "`n"))
}

if (-not $env:GODOT -or -not (Test-Path $env:GODOT)) { exit 0 }
$head = (git -C $root rev-parse HEAD).Trim()
$main = (git -C $root rev-parse main).Trim()
if ($head -eq $main) { exit 0 }
$mark = Join-Path $root "tools\dev\out\.compiled_head"
if ((Test-Path $mark) -and ((Get-Content $mark -Raw).Trim() -eq $head)) { exit 0 }

. (Join-Path $root "tools\dev\crew_lib.ps1")
Update-ImportCache $root $env:GODOT 6>$null
$ErrorActionPreference = "Continue"
$out = & $env:GODOT --headless --path "$root" --script res://tools/dev/compilecheck.gd 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($code -eq 0) {
	New-Item -ItemType Directory -Force (Split-Path $mark -Parent) | Out-Null
	Set-Content $mark $head
	exit 0
}
$errs = @($out | Where-Object { $_ -match "SCRIPT ERROR|^\s+at: GDScript::reload|COMPILE FAILED" } | Select-Object -Unique -First 20)
Block ("Your branch doesn't compile as a whole (tools/dev/compilecheck.gd); fix it before finishing:`n" + ($errs -join "`n"))

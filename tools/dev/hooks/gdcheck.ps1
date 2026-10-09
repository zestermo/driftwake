# Claude Code PostToolUse hook (.claude/settings.json): after Claude edits or
# writes a .gd file, compile it (tools/dev/compilecheck.gd, autoloads loaded)
# and, if it doesn't compile, hand Godot's errors back to Claude (exit 2).
# Takes ~2 s per .gd edit; anything else passes straight through.
$ErrorActionPreference = "Stop"
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$data = $raw | ConvertFrom-Json

$paths = @()
$ti = $data.tool_input
foreach ($t in @($ti)) {
	if ($t.file_path) { $paths += [string]$t.file_path }
}
$paths = @($paths | Where-Object { $_ -like "*.gd" -and $_ -notmatch "[\\/]tools[\\/]dev[\\/]out[\\/]" } | Select-Object -Unique)
if (-not $paths) { exit 0 }

if (-not $env:GODOT -or -not (Test-Path $env:GODOT)) {
	[Console]::Error.WriteLine("gdcheck hook: GODOT isn't set to the Godot console exe, so the edited script wasn't compile-checked.")
	exit 0
}

# the project the file is in (a worktree has its own; CLAUDE_PROJECT_DIR stays on the main checkout)
$dir = Split-Path (Resolve-Path $paths[0]).Path -Parent
while ($dir -and -not (Test-Path (Join-Path $dir "project.godot"))) { $dir = Split-Path $dir -Parent }
if (-not $dir) { exit 0 }

$rel = @($paths | ForEach-Object { "res://" + ((Resolve-Path $_).Path.Substring($dir.Length).TrimStart("\", "/") -replace "\\", "/") })
# (Windows PowerShell turns a native program's stderr into errors under "Stop")
$ErrorActionPreference = "Continue"
# (a bare -- before a splatted array is eaten by PowerShell; quoted it reaches Godot)
$out = & $env:GODOT --headless --path "$dir" --script res://tools/dev/compilecheck.gd "--" @rel 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -eq 0) { exit 0 }

$msg = $out | Where-Object { $_ -match "SCRIPT ERROR|^\s+at: GDScript::reload|COMPILE FAILED" } | Select-Object -Unique
[Console]::Error.WriteLine("Godot can't compile what you just edited:")
$msg | ForEach-Object { [Console]::Error.WriteLine($_) }
[Console]::Error.WriteLine("(If you're part way through a change across several edits, finish it; otherwise fix these.)")
exit 2

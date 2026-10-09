# Driftwake's browser build: Godot's Web export (thread-less), copied into the site.
#
#   .\tools\dev\build_web.ps1               # release export to web\build, copied to web\site\play
#   .\tools\dev\build_web.ps1 -DebugBuild   # a debug export (script errors show in the browser console)
#
# Needs the web export templates for this Godot version (checked below). Then look at
# it with .\tools\dev\serve_web.ps1 and deploy web\site (docs\web_build.md).
param(
	[string]$Godot = $env:GODOT,
	[switch]$DebugBuild
)

$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

if (-not $Godot -or -not (Test-Path $Godot)) {
	Write-Error "Godot not found. Set `$env:GODOT to the Godot 4.7 *console* exe."
	exit 99
}

# templates live in %APPDATA%\Godot\export_templates\<version>, e.g. 4.7.2.stable
$ver = ((& $Godot --version) | Select-Object -Last 1).Trim()
if ($ver -notmatch '^(\d+\.\d+(?:\.\d+)?\.[a-z]+\d*)') {
	Write-Error "Couldn't read the Godot version from '$ver'."
	exit 99
}
$tver = $Matches[1]
$tag = $tver -replace '\.([a-z]+\d*)$', '-$1'
$tdir = Join-Path $env:APPDATA "Godot\export_templates\$tver"
$tzip = if ($DebugBuild) { "web_nothreads_debug.zip" } else { "web_nothreads_release.zip" }
if (-not (Test-Path (Join-Path $tdir $tzip))) {
	Write-Host "The web export templates for Godot $tver aren't installed ($tdir\$tzip is missing)." -ForegroundColor Red
	Write-Host "Install them from the editor (Editor > Manage Export Templates > Download and Install), or download"
	Write-Host "  https://github.com/godotengine/godot/releases/download/$tag/Godot_v${tag}_export_templates.tpz"
	Write-Host "and pick that file in Manage Export Templates > Install from File."
	exit 2
}

$out = Join-Path $root "web\build"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$mode = if ($DebugBuild) { "--export-debug" } else { "--export-release" }
Write-Host "Exporting ($mode, preset Web) to web\build..." -ForegroundColor Cyan
$t0 = Get-Date
& $Godot --headless --path $root $mode "Web" (Join-Path $out "index.html")
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $out "index.wasm")) -or -not (Test-Path (Join-Path $out "index.pck"))) {
	Write-Error "The export failed (see Godot's output above)."
	exit 1
}
Write-Host ("Exported in {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds)

$play = Join-Path $root "web\site\play"
if (Test-Path $play) { Remove-Item -Recurse -Force $play }
Copy-Item -Recurse $out $play

# sizes, gzipped too (what a host that compresses sends), and the Cloudflare Pages cap
function Get-GzipSize([string]$path) {
	$src = [System.IO.File]::OpenRead($path)
	$mem = New-Object System.IO.MemoryStream
	$gz = New-Object System.IO.Compression.GZipStream($mem, [System.IO.Compression.CompressionLevel]::Optimal, $true)
	$src.CopyTo($gz)
	$gz.Dispose(); $src.Dispose()
	$n = $mem.Length
	$mem.Dispose()
	return $n
}
$over = $false
Write-Host "`nweb\site\play:" -ForegroundColor Cyan
Get-ChildItem $play -File | Sort-Object Length -Descending | ForEach-Object {
	$gz = if ($_.Extension -in ".wasm", ".pck", ".js") { "  (gzip {0:N1} MB)" -f ((Get-GzipSize $_.FullName) / 1MB) } else { "" }
	$flag = ""
	if ($_.Length -gt 25MB) { $flag = "  OVER Cloudflare Pages' 25 MiB per-file limit"; $over = $true }
	Write-Host ("  {0,-30} {1,7:N2} MB{2}{3}" -f $_.Name, ($_.Length / 1MB), $gz, $flag)
}
if ($over) {
	Write-Host "Netlify takes these as they are; for Cloudflare Pages see docs\web_build.md (the 25 MiB limit)." -ForegroundColor Yellow
}
Write-Host "`nLook at it: .\tools\dev\serve_web.ps1, then http://localhost:8060/play/" -ForegroundColor Green

# Exports a release build the way .github/workflows/build-windows.yml does (export_release, shaders baked by an
# editor window), but from the "Windows Bench" preset: the Windows Desktop preset plus tools/dev, so the bench can
# run in it (bench.ps1 -Exe). Writes tools/dev/out/export/Driftwake.exe and Driftwake.console.exe.
#   .\tools\dev\export_bench.ps1
#   .\tools\dev\bench.ps1 -Exe tools/dev/out/export/Driftwake.console.exe label=export quick
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Godot = $env:GODOT
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Error "Set `$env:GODOT to the Godot 4.7 console exe"; exit 99 }
. (Join-Path $PSScriptRoot "crew_lib.ps1")
Update-ImportCache $root $Godot
$out = Join-Path $root "tools/dev/out/export"
New-Item -ItemType Directory -Force $out | Out-Null
$log = Join-Path $out "export.log"
& $Godot --path $root --export-release "Windows Bench" (Join-Path $out "Driftwake.exe") 2>&1 | Tee-Object -FilePath $log | Select-String -Pattern "ERROR|Using Device|savepack"
$exe = Join-Path $out "Driftwake.console.exe"
if (-not (Test-Path $exe)) { Write-Error "export_bench: no $exe (the log: $log)"; exit 1 }
$bytes = [System.IO.File]::ReadAllBytes((Join-Path $out "Driftwake.exe"))
$text = [System.Text.Encoding]::ASCII.GetString($bytes)
$baked = ([regex]::Matches($text, 'shader_cache/[A-Za-z0-9]*/[0-9a-f]*/[0-9a-f]*\.d3d12\.cache') | ForEach-Object { $_.Value } | Sort-Object -Unique).Count
Write-Host "export_bench: $exe ($([math]::Round($bytes.Length / 1MB)) MB, $baked baked D3D12 shader files)"

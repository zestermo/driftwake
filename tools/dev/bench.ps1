# Runs the Brinehollow benchmark (bench_brinehollow.gd) on a quiet machine: it takes every
# test slot first (other sessions' test runs finish their current suite, then wait), runs one
# bench in a window, then lets them go. The rest of the arguments go to the bench.
#   .\tools\dev\bench.ps1 label=before hour=13 wx=clear          # the whole route (old + new stops), every phase
#   .\tools\dev\bench.ps1 -Driver vulkan label=vk quick          # quick: base only, the old eight unless stops= says
#   .\tools\dev\bench.ps1 label=c stops=old,atsea crowd          # stops= takes names and groups (old new town atsea capital all)
#   .\tools\dev\bench.ps1 -Exe tools/dev/out/export/Driftwake.console.exe label=x   # in an exported build (export_bench.ps1)
#   .\tools\dev\bench.ps1 -ColdShaders label=cold quick       # the user's shader cache set aside first (a first launch)
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Driver = "",
    [string]$Exe = "",
    [switch]$ColdShaders,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$BenchArgs
)
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Godot = $env:GODOT
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Error "Set `$env:GODOT to the Godot 4.7 console exe"; exit 99 }
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
$me = Get-CrewBranch $root
# (a class_name landed since this checkout last imported: without this every script naming it fails to parse)
Update-ImportCache $root $Godot
$n = Get-SlotCount
$slots = @()
$told = $false
try {
    while ($slots.Count -lt $n) {
        $s = Enter-Slot $crew "$me bench (holding every slot)"
        if ($s) { $slots += , $s; continue }
        if (-not $told) {
            Write-Host ("bench: waiting for every test slot ({0}/{1} held; in use: {2})" -f $slots.Count, $n, ((Get-SlotHolders $crew) -join "; "))
            $told = $true
        }
        Start-Sleep -Seconds 2
    }
    # (every slot held: Godots still up are outside the runners, e.g. an editor or a render tool)
    $others = @(Get-Process -Name "Godot*" -ErrorAction SilentlyContinue).Count
    if ($others -gt 0) { Write-Host "bench: $others other Godot process(es) running outside the test slots" }
    $outDir = Join-Path $root "tools/dev/out/bench"
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $a = @()
    if (-not $Exe) { $a += @("--path", $root) }
    if ($Driver) { $a += @("--rendering-driver", $Driver) }
    $a += @("--script", "res://tools/dev/bench_brinehollow.gd", "--") + $BenchArgs
    if ($Exe) {
        # (an exported build ignores --script: its override.cfg makes BenchBoot the main loop, which becomes the bench)
        $a = @($a | Where-Object { $_ -ne "--script" -and $_ -ne "res://tools/dev/bench_brinehollow.gd" })
        # (the bench's own source from this checkout, so a bench change needs no new export)
        $a += @("out=$($outDir.Replace('\', '/'))", "boot=$((Join-Path $PSScriptRoot 'bench_brinehollow.gd').Replace('\', '/'))")
        $Godot = (Resolve-Path (Join-Path $root $Exe) -ErrorAction SilentlyContinue).Path
        if (-not $Godot) { $Godot = (Resolve-Path $Exe).Path }
        Set-Content -Path (Join-Path (Split-Path $Godot -Parent) "override.cfg") -Value "[application]`r`n`r`nrun/main_loop_type=`"BenchBoot`"`r`n" -Encoding ascii
    }
    if ($ColdShaders) {
        $cache = Join-Path $env:APPDATA "Godot/app_userdata/DriftWake/shader_cache"
        $aside = "$cache.bench_aside"
        if (Test-Path $aside) { Write-Error "bench: $aside is already there (a cold run that didn't put it back?): move it back first"; exit 1 }
        if (Test-Path $cache) { Rename-Item $cache $aside }
        Write-Host "bench: the shader cache set aside ($aside)"
    }
    $label = ($BenchArgs | Where-Object { $_ -like "label=*" } | Select-Object -First 1)
    $label = if ($label) { $label.Substring(6) } else { "run" }
    $log = Join-Path $outDir "brinehollow_$label.log"
    Write-Host "bench: the whole Godot log goes to $log"
    # (the log is capped like the test runner's: an engine error flood wrote 4.8 GB and filled the disk, 2026-11-10.
    # Past the cap the bench's Godot is stopped: a run that prints that much measured nothing)
    $cap = 64MB
    $bytes = 0L
    $flooded = $false
    $began = Get-Date
    $w = [System.IO.StreamWriter]::new($log, $false, [System.Text.UTF8Encoding]::new($false))
    try {
        & $Godot @a 2>&1 | ForEach-Object {
            if ($flooded) { return }
            $line = "$_"
            $w.WriteLine($line)
            $bytes += $line.Length + 2
            if ($bytes -gt $cap) {
                $flooded = $true
                Write-Host "bench: the log passed $([int]($cap / 1MB)) MB (an error flood): stopping Godot. Its start is in $log" -ForegroundColor Red
                Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Godot -and $_.StartTime -ge $began } | Stop-Process -Force -ErrorAction SilentlyContinue
            } elseif ($line -match "SCRIPT ERROR|bench:") { $line }
        }
        $code = $LASTEXITCODE
    } finally {
        $w.Close()
    }
    if ($flooded) { $code = 3 }
} finally {
    foreach ($s in $slots) { Exit-Slot $s }
    if ($ColdShaders -and (Test-Path $aside)) {
        if (Test-Path $cache) { Remove-Item -Recurse -Force $cache }
        Rename-Item $aside $cache
        Write-Host "bench: the shader cache put back"
    }
}
exit $code

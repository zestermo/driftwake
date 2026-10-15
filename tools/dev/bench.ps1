# Runs the Brinehollow benchmark (bench_brinehollow.gd) on a quiet machine: it takes every
# test slot first (other sessions' test runs finish their current suite, then wait), runs one
# bench in a window, then lets them go. The rest of the arguments go to the bench.
#   .\tools\dev\bench.ps1 label=before hour=13 wx=clear
#   .\tools\dev\bench.ps1 -Driver vulkan label=vk quick
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Driver = "",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$BenchArgs
)
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Godot = $env:GODOT
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Error "Set `$env:GODOT to the Godot 4.7 console exe"; exit 99 }
. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
$me = Get-CrewBranch $root
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
    $a = @("--path", $root)
    if ($Driver) { $a += @("--rendering-driver", $Driver) }
    $a += @("--script", "res://tools/dev/bench_brinehollow.gd", "--") + $BenchArgs
    & $Godot @a 2>&1 | Select-String -Pattern "SCRIPT ERROR|bench:"
    $code = $LASTEXITCODE
} finally {
    foreach ($s in $slots) { Exit-Slot $s }
}
exit $code

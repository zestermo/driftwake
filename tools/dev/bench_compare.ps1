# Diffs two Brinehollow bench results (tools/dev/bench_brinehollow.gd): the summary per
# stop and the scripts' costs. Each argument is a result file or just its label.
#   .\tools\dev\bench_compare.ps1 before after
param(
    [Parameter(Mandatory = $true)][string]$A,
    [Parameter(Mandatory = $true)][string]$B,
    [int]$Top = 25
)

function Resolve-Bench([string]$x) {
    if (Test-Path $x) { return $x }
    $p = Join-Path $PSScriptRoot "out/bench/brinehollow_$x.txt"
    if (-not (Test-Path $p)) { throw "no bench result '$x' ($p)" }
    return $p
}

function Read-Section([string[]]$lines, [string]$name) {
    $i = [Array]::IndexOf($lines, "== $name")
    if ($i -lt 0) { return $null }
    $j = $i + 1
    while ($lines[$j] -notmatch '^\S') { $j++ }
    $hdr = @($lines[$j].Trim() -split '\s+')
    $rows = [ordered]@{}
    for ($k = $j + 1; $k -lt $lines.Count -and $lines[$k].Trim() -ne ''; $k++) {
        $f = @($lines[$k].Trim() -split '\s+')
        $rows[$f[0]] = $f
    }
    return @{ hdr = $hdr; rows = $rows }
}

$pa = Resolve-Bench $A
$pb = Resolve-Bench $B
$la = [System.IO.File]::ReadAllLines($pa)
$lb = [System.IO.File]::ReadAllLines($pb)
Write-Host "A: $pa"
Write-Host "   $($la[1])"
Write-Host "   $($la[2])"
Write-Host "B: $pb"
Write-Host "   $($lb[1])"
Write-Host "   $($lb[2])"
Write-Host ""

$sa = Read-Section $la 'summary'
$sb = Read-Section $lb 'summary'
$cols = @('frame', 'p95', 'worst', 'phys_scr', 'phys_eng', 'proc_scr', 'tail', 'draw', 'rcpu', 'gpu', 'tot_draws', 'nodes')
$line = '{0,-8} {1,-3}' -f 'stop', ''
foreach ($c in $cols) { $line += ' {0,9}' -f $c }
Write-Host $line
foreach ($stop in $sa.rows.Keys) {
    if (-not $sb.rows.Contains($stop)) { continue }
    $ra = $sa.rows[$stop]; $rb = $sb.rows[$stop]
    $l1 = '{0,-8} {1,-3}' -f $stop, 'A'
    $l2 = '{0,-8} {1,-3}' -f '', 'B'
    $l3 = '{0,-8} {1,-3}' -f '', 'd%'
    foreach ($c in $cols) {
        $ia = [Array]::IndexOf($sa.hdr, $c); $ib = [Array]::IndexOf($sb.hdr, $c)
        $va = [double]$ra[$ia]; $vb = [double]$rb[$ib]
        $l1 += ' {0,9:N2}' -f $va
        $l2 += ' {0,9:N2}' -f $vb
        $l3 += ' {0,9}' -f $(if ($va -ne 0) { '{0:+0;-0;0}' -f (($vb - $va) / $va * 100) } else { '-' })
    }
    Write-Host $l1; Write-Host $l2; Write-Host $l3
}

$ca = Read-Section $la 'scripts'
$cb = Read-Section $lb 'scripts'
if ($ca -and $cb) {
    Write-Host ""
    Write-Host ('{0,-48} {1,9} {2,9} {3,9}' -f 'script (cost ms)', 'A', 'B', 'B-A')
    $ia = [Array]::IndexOf($ca.hdr, 'cost'); $ib = [Array]::IndexOf($cb.hdr, 'cost')
    $names = @($ca.rows.Keys) + @($cb.rows.Keys) | Select-Object -Unique
    $list = foreach ($n in $names) {
        $va = if ($ca.rows.Contains($n)) { [double]$ca.rows[$n][$ia] } else { 0.0 }
        $vb = if ($cb.rows.Contains($n)) { [double]$cb.rows[$n][$ib] } else { 0.0 }
        [pscustomobject]@{ n = $n; a = $va; b = $vb }
    }
    foreach ($r in ($list | Sort-Object { [Math]::Max($_.a, $_.b) } -Descending | Select-Object -First $Top)) {
        Write-Host ('{0,-48} {1,9:N3} {2,9:N3} {3,9:N3}' -f $r.n, $r.a, $r.b, ($r.b - $r.a))
    }
}

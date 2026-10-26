# perf_budgets.ps1's and perf_gate.ps1's shared reading of tools/dev/perf_budgets.txt (dot-sourced).

## The budgets: an ordered list of @{ name; ms; res (regexes) }.
function Get-Budgets() {
	$out = @()
	foreach ($l in [System.IO.File]::ReadAllLines((Join-Path $PSScriptRoot "perf_budgets.txt"))) {
		if ($l.StartsWith("#") -or $l.Trim() -eq "") { continue }
		$f = $l -split '\|'
		$res = @($f[2] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
		$out += , @{ name = $f[0].Trim(); ms = [double]$f[1].Trim(); res = $res }
	}
	return , $out
}

## A bench result's scripts (name -> cost ms; the old route's table when there is one) and its draw (ALL_OLD, else ALL).
function Read-BenchBudget([string]$path) {
	$lines = [System.IO.File]::ReadAllLines($path)
	$r = @{ scripts = @{}; draw = 0.0 }
	$i = [Array]::IndexOf($lines, "== summary")
	$hdr = @($lines[$i + 1].Trim() -split '\s+')
	$di = [Array]::IndexOf($hdr, "draw")
	for ($k = $i + 2; $lines[$k].Trim() -ne ''; $k++) {
		$f = @($lines[$k].Trim() -split '\s+')
		if ($f[0] -eq "ALL_OLD" -or ($f[0] -eq "ALL" -and $r.draw -eq 0.0)) { $r.draw = [double]$f[$di] }
	}
	$j = [Array]::IndexOf($lines, "== scripts_old")
	if ($j -lt 0) { $j = [Array]::IndexOf($lines, "== scripts") }
	$sh = @($lines[$j + 2].Trim() -split '\s+')
	$ci = [Array]::IndexOf($sh, "cost")
	for ($k = $j + 3; $lines[$k].Trim() -ne ''; $k++) {
		$f = @($lines[$k].Trim() -split '\s+')
		$r.scripts[$f[0]] = [double]$f[$ci]
	}
	return $r
}

## Each system's ms (scripts by their first matching system; draw from the summary): name -> ms.
function Measure-Budgets($budgets, $scripts, [double]$draw) {
	$sum = [ordered]@{}
	foreach ($b in $budgets) { $sum[$b.name] = 0.0 }
	foreach ($kv in $scripts.GetEnumerator()) {
		foreach ($b in $budgets) {
			if ($b.name -eq "draw") { continue }
			$hit = $false
			foreach ($re in $b.res) { if ($kv.Key -match $re) { $hit = $true; break } }
			if ($hit) { $sum[$b.name] += $kv.Value; break }
		}
	}
	if ($sum.Contains("draw")) { $sum["draw"] = $draw }
	return $sum
}

## Prints the systems against their budgets; the names over budget.
function Show-Budgets($budgets, $scripts, [double]$draw, [string]$what) {
	$sum = Measure-Budgets $budgets $scripts $draw
	Write-Host "  budgets ($what; ms a frame, scripts' proc + phys, mean of the stops):"
	$over = @()
	$tot = 0.0
	$totb = 0.0
	foreach ($b in $budgets) {
		$v = $sum[$b.name]
		$tot += $v
		$totb += $b.ms
		$bad = $v -gt $b.ms
		if ($bad) { $over += $b.name }
		Write-Host ("    {0,-8} {1,6:N2} / {2,5:N2}{3}" -f $b.name, $v, $b.ms, $(if ($bad) { "  over" } else { "" })) -ForegroundColor $(if ($bad) { "Yellow" } else { "Gray" })
	}
	Write-Host ("    {0,-8} {1,6:N2} / {2,5:N2}" -f "total", $tot, $totb)
	return , $over
}

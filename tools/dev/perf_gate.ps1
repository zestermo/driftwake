# The performance gate before a release (prepush.ps1 -Release runs it): the Brinehollow bench (bench.ps1, gate
# mode: base + probe at the 8 stops, ~4 min a run) against the saved baseline, tools/dev/perf_baseline.txt.
#
#   .\tools\dev\perf_gate.ps1                  # bench this checkout at every light in the baseline, compare
#   .\tools\dev\perf_gate.ps1 -Update          # bench it and rewrite the baseline (after an intended change), then commit it
#                                              # (it names HEAD: on a branch, after the landing's rebase point the
#                                              # baseline's commit line at the landed commit with the same game code)
#   .\tools\dev\perf_gate.ps1 -Hours 13        # one light only (-Update's default: 13 and 21, clear)
#   .\tools\dev\perf_gate.ps1 -BenchArgs stops=beach,dock -Runs 1 # extra bench args (to both sides of a confirm too)
#
# Noise (laptop runs swing ~10% in frame, ~5% in frame1t, and the machine's state swings far more over hours):
# each light is benched -Runs times (2) and each stop keeps its best (lowest) numbers, since what lands on a
# frame is the code's cost plus interference that only adds. It FAILS (exit 1) when, against the baseline:
#   - the mean of the stops' frame or frame1t is more than 15% worse, or
#   - one stop's frame1t is more than 35% worse (a regression in one place, diluted in the mean; a single stop
#     swung up to 22% between two passing runs of the same code, even as the best of 2), or
#   - physics ticks per frame (the mean) rise above 0.8 (the spiral that made v1.13 slow).
# Every bench run also times a fixed script workload (calib). When the gate would fail, or this machine's
# calib is more than 15% off the baseline's (a different power plan or heat: the numbers aren't comparable),
# it benches the baseline's commit back to back in a temporary worktree and judges against that instead
# (-NoConfirm skips it). Target: the laptop bench (i7-14700HX, RTX 4060) at <= ~10 ms mean frame keeps the
# min-spec PC (Ryzen 5 5600G + RTX 3080) at 60 fps in Brinehollow.
param(
	[switch]$Update,
	[int[]]$Hours = @(),
	[int]$Runs = 2,
	[string]$Label = "gate",
	[string[]]$BenchArgs = @(),
	[switch]$NoConfirm
)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$basePath = Join-Path $PSScriptRoot "perf_baseline.txt"
$FRAME_PCT = 15.0
$STOP_PCT = 35.0
$MAX_TICKS = 0.8
$CALIB_PCT = 15.0
$TARGET_MS = 10.0
$COLS = @("frame", "frame1t", "ticks", "draws", "sh_draws")

## Runs one bench in checkout $dir; the result file's path.
function Invoke-Bench([string]$dir, [string]$label, [int]$hour) {
	$out = Join-Path $dir "tools/dev/out/bench/brinehollow_$label.txt"
	Remove-Item $out -Force -ErrorAction SilentlyContinue
	Write-Host ("perf gate: bench {0} (hour {1}) in {2}" -f $label, $hour, $dir) -ForegroundColor DarkGray
	$a = @("label=$label", "hour=$hour", "wx=clear", "gate") + $BenchArgs
	# (bench.ps1 pipes Godot's stderr, which Windows PowerShell turns into errors under "Stop")
	$ErrorActionPreference = "Continue"
	$lines = & (Join-Path $dir "tools/dev/bench.ps1") @a
	$code = $LASTEXITCODE
	$lines | ForEach-Object { "$_" } | Where-Object { $_ -match "SCRIPT ERROR|STALL(?!.*stop -,)|calib|never finished" } | ForEach-Object { Write-Host "  $_" }
	if ($code -ne 0 -or -not (Test-Path $out)) { throw "the bench $label failed (exit $code; log tools/dev/out/bench/brinehollow_$label.log in $dir)" }
	return $out
}

## A bench result: calib, the summary per stop (COLS) and each script's cost (ms).
function Read-Bench([string]$path) {
	$lines = [System.IO.File]::ReadAllLines($path)
	$r = @{ calib = 0.0; stops = [ordered]@{}; scripts = @{}; machine = "" }
	if ($lines[2] -match "calib ([\d.]+) ms") { $r.calib = [double]$Matches[1] }
	if ($lines[1] -match "driver (\S+)\s+(.+?)\s+CPU (.+) \(") { $r.machine = "{0} | {1} | {2}" -f $Matches[3].Trim(), $Matches[2].Trim(), $Matches[1] }
	$i = [Array]::IndexOf($lines, "== summary")
	$hdr = @($lines[$i + 1].Trim() -split '\s+')
	for ($k = $i + 2; $lines[$k].Trim() -ne ''; $k++) {
		$f = @($lines[$k].Trim() -split '\s+')
		if ($f[0] -eq "ALL") { continue }
		$row = @{}
		foreach ($c in $COLS) { $row[$c] = [double]$f[[Array]::IndexOf($hdr, $c)] }
		$r.stops[$f[0]] = $row
	}
	$j = [Array]::IndexOf($lines, "== scripts")
	$sh = @($lines[$j + 2].Trim() -split '\s+')
	$ci = [Array]::IndexOf($sh, "cost")
	for ($k = $j + 3; $lines[$k].Trim() -ne ''; $k++) {
		$f = @($lines[$k].Trim() -split '\s+')
		$r.scripts[$f[0]] = [double]$f[$ci]
	}
	return $r
}

## Several runs of one light as one: each stop's (and script's) best, ALL = the mean of the stops.
function Merge-Runs($each) {
	$m = @{ calib = ($each | ForEach-Object { $_.calib } | Measure-Object -Minimum).Minimum; machine = $each[0].machine; stops = [ordered]@{}; scripts = @{} }
	foreach ($s in $each[0].stops.Keys) {
		$row = @{}
		foreach ($c in $COLS) { $row[$c] = ($each | ForEach-Object { $_.stops[$s][$c] } | Measure-Object -Minimum).Minimum }
		$m.stops[$s] = $row
	}
	$names = $each | ForEach-Object { $_.scripts.Keys } | Select-Object -Unique
	foreach ($n in $names) {
		$m.scripts[$n] = ($each | ForEach-Object { if ($_.scripts.ContainsKey($n)) { $_.scripts[$n] } else { 0.0 } } | Measure-Object -Minimum).Minimum
	}
	$all = @{}
	foreach ($c in $COLS) { $all[$c] = ($m.stops.Values | ForEach-Object { $_[$c] } | Measure-Object -Average).Average }
	$m.all = $all
	return $m
}

## Bench every light $Runs times in $dir: hour -> merged result.
function Measure-Lights([string]$dir, [string]$label, [int[]]$hours) {
	$res = [ordered]@{}
	foreach ($h in $hours) {
		# (not $runs: PowerShell names ignore case, that's the -Runs count)
		$got = @()
		for ($i = 1; $i -le $Runs; $i++) { $got += , (Read-Bench (Invoke-Bench $dir ("{0}_h{1}_r{2}" -f $label, $h, $i) $h)) }
		# (string keys: an ordered dictionary reads an int key as a position)
		$res["$h"] = Merge-Runs $got
	}
	return $res
}

function Write-Baseline($res, [string]$commit) {
	$first = @($res.Values)[0]
	$L = @(
		"# Driftwake performance baseline: tools/dev/perf_gate.ps1 compares a release with it, -Update rewrites it.",
		"# Brinehollow bench (bench_brinehollow.gd gate: base + probe), per stop the best of $Runs runs; ms; ALL = the mean of the stops.",
		"# Target: ALL frame <= ~$TARGET_MS ms on this laptop keeps the min-spec PC (Ryzen 5 5600G + RTX 3080) at 60 fps in Brinehollow.",
		"commit $commit",
		("taken {0:yyyy-MM-dd HH:mm}  runs {1}" -f (Get-Date), $Runs),
		"machine $($first.machine)",
		("calib {0:N2}" -f ($res.Values | ForEach-Object { $_.calib } | Measure-Object -Minimum).Minimum)
	)
	foreach ($h in $res.Keys) {
		$r = $res[$h]
		$L += ""
		$L += "== h$h clear"
		$L += ("{0,-8} {1,8} {2,8} {3,8} {4,8} {5,8}" -f "stop", "frame", "frame1t", "ticks", "draws", "sh_draws")
		foreach ($s in @($r.stops.Keys) + "ALL") {
			$v = if ($s -eq "ALL") { $r.all } else { $r.stops[$s] }
			$L += ("{0,-8} {1,8:N2} {2,8:N2} {3,8:N2} {4,8:N0} {5,8:N0}" -f $s, $v.frame, $v.frame1t, $v.ticks, $v.draws, $v.sh_draws)
		}
		$L += ""
		$L += "== h$h clear scripts (ms: proc per frame + phys per tick, mean of the stops)"
		foreach ($kv in ($r.scripts.GetEnumerator() | Where-Object { $_.Value -ge 0.005 } | Sort-Object Value -Descending)) {
			$L += ("{0,-48} {1,8:N3}" -f $kv.Key, $kv.Value)
		}
	}
	[System.IO.File]::WriteAllLines($basePath, [string[]]$L)
}

function Read-Baseline() {
	if (-not (Test-Path $basePath)) { throw "no baseline ($basePath): run perf_gate.ps1 -Update on a quiet machine first" }
	$b = @{ commit = ""; calib = 0.0; lights = [ordered]@{} }
	$cur = $null
	$mode = ""
	foreach ($l in [System.IO.File]::ReadAllLines($basePath)) {
		if ($l.StartsWith("#") -or $l.Trim() -eq "") { continue }
		if ($l -match "^commit (\S+)") { $b.commit = $Matches[1]; continue }
		if ($l -match "^calib ([\d.]+)") { $b.calib = [double]$Matches[1]; continue }
		if ($l -match "^== h(\d+) clear( scripts)?") {
			$h = $Matches[1]
			if (-not $b.lights.Contains($h)) { $b.lights[$h] = @{ stops = [ordered]@{}; scripts = @{}; all = $null } }
			$cur = $b.lights[$h]
			$mode = if ($Matches[2]) { "scripts" } else { "stops" }
			continue
		}
		if (-not $cur) { continue }
		$f = @($l.Trim() -split '\s+')
		if ($mode -eq "scripts") { $cur.scripts[$f[0]] = [double]$f[1]; continue }
		if ($f[0] -eq "stop") { continue }
		$row = @{}
		for ($i = 0; $i -lt $COLS.Count; $i++) { $row[$COLS[$i]] = [double]$f[$i + 1] }
		if ($f[0] -eq "ALL") { $cur.all = $row } else { $cur.stops[$f[0]] = $row }
	}
	return $b
}

function Pct([double]$a, [double]$b) { if ($a -eq 0) { return 0.0 }; return ($b - $a) / $a * 100.0 }

## Prints the comparison of one light; the reasons it fails (none: it passes).
function Compare-Light([int]$h, $base, $now, [string]$what) {
	$fails = @()
	Write-Host ""
	Write-Host "== $h`:00 clear: $what -> this checkout (ms; d% = change; * = over the line)"
	Write-Host ("{0,-8} {1,16} {2,6} {3,16} {4,6} {5,12} {6,14}" -f "stop", "frame", "d%", "frame1t", "d%", "ticks", "draws+shadow")
	foreach ($s in @($base.stops.Keys) + "ALL") {
		$a = if ($s -eq "ALL") { $base.all } else { $base.stops[$s] }
		$b = if ($s -eq "ALL") { $now.all } else { $now.stops[$s] }
		if (-not $b) { continue }
		$df = Pct $a.frame $b.frame
		$d1 = Pct $a.frame1t $b.frame1t
		$lim = if ($s -eq "ALL") { $FRAME_PCT } else { $STOP_PCT }
		$bad1 = $d1 -gt $lim
		$badf = ($s -eq "ALL") -and $df -gt $FRAME_PCT
		$badt = ($s -eq "ALL") -and $b.ticks -gt $MAX_TICKS
		$line = "{0,-8} {1,7:N2} {2,8:N2} {3,5:+0;-0;0}{4} {5,7:N2} {6,8:N2} {7,5:+0;-0;0}{8} {9,5:N2} {10,5:N2}{11} {12,6:N0} {13,7:N0}" -f $s, $a.frame, $b.frame, $df, $(if ($badf) { "*" } else { " " }),
			$a.frame1t, $b.frame1t, $d1, $(if ($bad1) { "*" } else { " " }), $a.ticks, $b.ticks, $(if ($badt) { "*" } else { " " }), ($b.draws + $b.sh_draws), ($b.draws + $b.sh_draws - $a.draws - $a.sh_draws)
		Write-Host $line -ForegroundColor $(if ($bad1 -or $badf -or $badt) { "Red" } elseif ($d1 -gt 10 -or $df -gt 10) { "Yellow" } else { "Gray" })
		if ($badf) { $fails += ("{0}:00 mean frame {1:N2} -> {2:N2} ms ({3:+0}%)" -f $h, $a.frame, $b.frame, $df) }
		if ($bad1) { $fails += ("{0}:00 {1} frame1t {2:N2} -> {3:N2} ms ({4:+0}%)" -f $h, $(if ($s -eq "ALL") { "mean" } else { $s }), $a.frame1t, $b.frame1t, $d1) }
		if ($badt) { $fails += ("{0}:00 physics ticks per frame {1:N2} (over {2})" -f $h, $b.ticks, $MAX_TICKS) }
	}
	if ($now.all.frame -gt $TARGET_MS) { Write-Host ("  (mean frame {0:N2} ms is over the ~{1} ms target for the min-spec PC's 60 fps)" -f $now.all.frame, $TARGET_MS) -ForegroundColor Yellow }
	$grown = foreach ($n in (@($base.scripts.Keys) + @($now.scripts.Keys) | Select-Object -Unique)) {
		$va = if ($base.scripts.ContainsKey($n)) { $base.scripts[$n] } else { 0.0 }
		$vb = if ($now.scripts.ContainsKey($n)) { $now.scripts[$n] } else { 0.0 }
		[pscustomobject]@{ n = $n; a = $va; b = $vb; d = $vb - $va }
	}
	Write-Host "  scripts that grew most (ms per frame + per tick, mean of the stops):"
	foreach ($g in ($grown | Sort-Object d -Descending | Select-Object -First 8)) {
		if ($g.d -lt 0.01) { break }
		Write-Host ("    {0,-46} {1,7:N3} -> {2,7:N3}  {3:+0.000}" -f $g.n, $g.a, $g.b, $g.d) -ForegroundColor $(if ($g.d -ge 0.1) { "Yellow" } else { "Gray" })
	}
	return , $fails
}

function Test-Lights($baseLights, $now, [string]$what) {
	$fails = @()
	foreach ($h in $now.Keys) { $fails += Compare-Light $h $baseLights[$h] $now[$h] $what }
	return , $fails
}

## The baseline's commit checked out beside this one (the import happens in its first bench).
function New-RefTree([string]$commit) {
	$ErrorActionPreference = "Continue"
	git -C $root cat-file -e "$commit^{commit}" 2>&1 | Out-Null
	if ($LASTEXITCODE) { throw "the baseline's commit $commit isn't in this repo: can't bench it back to back" }
	$dir = Join-Path ([System.IO.Path]::GetTempPath()) ("driftwake_perfref_" + $commit.Substring(0, 8))
	Remove-RefTree $dir
	git -C $root worktree add --detach "$dir" $commit 2>&1 | Out-Null
	if (-not (Test-Path (Join-Path $dir "project.godot"))) { throw "couldn't check out $commit in $dir" }
	return $dir
}

function Remove-RefTree([string]$dir) {
	$ErrorActionPreference = "Continue"
	if (Test-Path $dir) { & cmd.exe /d /c "rd /s /q `"\\?\$dir`"" 2>&1 | Out-Null }
	git -C $root worktree prune 2>&1 | Out-Null
}

# ------------------------------------------------------------------------------------------------
$head = (git -C $root rev-parse HEAD).Trim()
if ($Update) {
	if (-not $Hours) { $Hours = @(13, 21) }
	$dirty = @(git -C $root status --porcelain -- scripts scenes shaders assets project.godot)
	if ($dirty) { Write-Host "perf gate: uncommitted game changes here; the baseline names HEAD ($head), so commit them first for a fair confirm later." -ForegroundColor Yellow }
	$res = Measure-Lights $root $Label $Hours
	Write-Baseline $res $head
	Write-Host "perf gate: wrote $basePath (commit it)." -ForegroundColor Green
	foreach ($h in $res.Keys) { Write-Host ("  {0}:00 clear: mean frame {1:N2} ms, frame1t {2:N2}, ticks {3:N2}, calib {4:N2}" -f $h, $res[$h].all.frame, $res[$h].all.frame1t, $res[$h].all.ticks, $res[$h].calib) }
	exit 0
}

$base = Read-Baseline
if (-not $Hours) { $Hours = @($base.lights.Keys) }
$now = Measure-Lights $root $Label $Hours
$calib = ($now.Values | ForEach-Object { $_.calib } | Measure-Object -Minimum).Minimum
$calibOff = [Math]::Abs((Pct $base.calib $calib))
Write-Host ("perf gate: baseline {0} (calib {1:N2}); this checkout {2} (calib {3:N2}, {4:+0;-0;0}%)" -f $base.commit.Substring(0, 8), $base.calib, $head.Substring(0, 8), $calib, (Pct $base.calib $calib))
$fails = Test-Lights $base.lights $now "baseline"
if (($fails.Count -eq 0 -and $calibOff -le $CALIB_PCT) -or $NoConfirm) {
	if ($fails.Count -eq 0) {
		if ($calibOff -gt $CALIB_PCT) { Write-Host "perf gate: PASS against the saved baseline, but this machine's calib is $([int]$calibOff)% off it (not confirmed: -NoConfirm)." -ForegroundColor Yellow }
		else { Write-Host "perf gate: PASS" -ForegroundColor Green }
		exit 0
	}
	$fails | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
	Write-Host "perf gate: FAIL (against the saved baseline, not confirmed back to back: -NoConfirm)" -ForegroundColor Red
	exit 1
}
if ($calibOff -gt $CALIB_PCT) { Write-Host "perf gate: this machine runs scripts $([int]$calibOff)% off the baseline's speed: the saved numbers aren't comparable." -ForegroundColor Yellow }
else { $fails | ForEach-Object { Write-Host "  $_" -ForegroundColor Red } }
Write-Host "perf gate: benching the baseline's commit $($base.commit.Substring(0, 8)) back to back to confirm..." -ForegroundColor Yellow
$ref = New-RefTree $base.commit
try {
	$then = Measure-Lights $ref "${Label}_ref" $Hours
} finally {
	Remove-RefTree $ref
}
$fails = Test-Lights $then $now "the baseline's commit, now"
if ($fails.Count -eq 0) {
	Write-Host "perf gate: PASS (back to back with the baseline's commit)" -ForegroundColor Green
	exit 0
}
$fails | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
Write-Host "perf gate: FAIL (confirmed back to back with the baseline's commit)" -ForegroundColor Red
exit 1

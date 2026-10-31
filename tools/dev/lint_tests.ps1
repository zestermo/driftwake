# Advisory lint for atomic tests (tools/dev/t): lists tests that set up a grunt, check it gets knocked down or floored,
# and never make it a fair target (TK.calm, or resetting its poise by hand). A foe floored by an earlier case is immune
# to the next knockdown for Poise.IMMUNE s, and one mid-swing or guarding shrugs a blow off: the fruit tests' load
# flakes were all this. Prints nothing when clean; exit code 0 either way (it never blocks a run).
#   .\tools\dev\lint_tests.ps1            every atomic test
#   .\tools\dev\lint_tests.ps1 t/combat   one group
param([string]$Only = "")
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dir = Join-Path $root "tools/dev/t"
if ($Only -ne "") { $dir = Join-Path $root ("tools/dev/" + $Only) }
$hits = 0
foreach ($f in Get-ChildItem -Path $dir -Recurse -Filter *.gd) {
	$src = Get-Content -Raw -LiteralPath $f.FullName
	$grunt = $src -match 'pirate_grunt|"grunts"|spawn_grunt|grunt'
	$knock = $src -match '(?i)check\([^\n]*(knock|floor|launch)'
	$calm = $src -match 'TK\.calm|_immune_until'
	if ($grunt -and $knock -and -not $calm) {
		$rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
		Write-Output "lint: $rel checks a knockdown on a grunt it never calms (TK.calm(g) before the blow)"
		$hits += 1
	}
}
if ($hits -gt 0) { Write-Output "lint: $hits test(s); advisory only" }
exit 0

# Co-op test: a headless host and client (and a third watcher for "three") on
# localhost. Modes: "" (default), late, three, hostquit, water, board, chain (the
# island chain: the host lands on the first island, then the guest joins late).
#
#   .\tools\dev\nettest.ps1            # default
#   .\tools\dev\nettest.ps1 water
#   .\tools\dev\nettest.ps1 chain
#
# Godot: $env:GODOT = the 4.7 *console* exe (or -Godot). Logs: tools\dev\out\logs\net*.log
#
# Like run_tests.ps1 it takes machine-wide test slots (one per Godot it starts) and skips a
# mode that already passed on exactly this code (-Force reruns).
param(
	[Parameter(Position = 0)][string]$Mode = "",
	[string]$Godot = $env:GODOT,
	[int]$Timeout = 300,
	[switch]$Force
)
$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Godot) { $cmd = Get-Command godot -ErrorAction SilentlyContinue; if ($cmd) { $Godot = $cmd.Source } }
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Error "Set `$env:GODOT to the Godot 4.7 console exe"; exit 99 }
$logs = [System.IO.Path]::Combine($root, "tools", "dev", "out", "logs")
New-Item -ItemType Directory -Force -Path $logs | Out-Null

. (Join-Path $PSScriptRoot "crew_lib.ps1")
$crew = Get-CrewDir $root
$me = Get-CrewBranch $root
$tree = Get-TreeKey $root
$key = if ($Mode) { "net-$Mode" } else { "net" }
$hit = Get-CachedPass $crew $tree $key
if ($hit -and -not $Force) {
	Write-Host "CO-OP TEST OK (already passed on this exact code: $hit; -Force reruns)" -ForegroundColor Green
	exit 0
}
$slots = Wait-Slots $crew $(if ($Mode -eq "three") { 3 } else { 2 }) "$me $key"

$port = 24700 + (Get-Random -Maximum 250)
$delay = "2.5"
if ($Mode -eq "late") { $port = 24680; $delay = "7" }
# (the host is boarded before we join)
if ($Mode -eq "board") { $delay = "10" }
if ($Mode -eq "chain") { $delay = "6"; $Timeout = [Math]::Max($Timeout, 500) }

function Start-Godot([string]$script, [string]$extra, [string]$log) {
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $Godot
	$psi.Arguments = "--headless --path `"$root`" --script res://tools/dev/$script -- $extra"
	$psi.WorkingDirectory = $root
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $true
	$p = [System.Diagnostics.Process]::Start($psi)
	return [pscustomobject]@{ Proc = $p; Log = $log; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync() }
}

function Wait-Godot($g) {
	if (-not $g.Proc.WaitForExit($Timeout * 1000)) { try { $g.Proc.Kill() } catch {}; $g.Proc.WaitForExit() }
	$text = $g.Out.Result + "`n" + $g.Err.Result
	Set-Content -Path (Join-Path $logs $g.Log) -Value $text -Encoding UTF8
	return $text
}

$modeArg = if ($Mode) { $Mode } else { "" }
$host_ = Start-Godot "nethost.gd" "$port $modeArg" "nethost.log"
$watch = $null
if ($Mode -eq "three") { $watch = Start-Godot "netwatch.gd" "$port 10" "netwatch.log" }
Start-Sleep -Milliseconds 300
$client = Start-Godot "netclient.gd" "$port $delay $modeArg" "netclient.log"

$ct = Wait-Godot $client
$ht = Wait-Godot $host_
Write-Host "--- client" -ForegroundColor Cyan
$ct -split "`r?`n" | Where-Object { $_ -cmatch "PASS|FAIL|RESULT|SCRIPT ERROR|^  " } | ForEach-Object { Write-Host $_ }
Write-Host "--- host" -ForegroundColor Cyan
$ht -split "`r?`n" | Where-Object { $_ -cmatch "SCRIPT ERROR|HOST|PASS|FAIL" } | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
$bad = -not ($ct -cmatch "RESULT OK")
if ($watch) {
	$wt = Wait-Godot $watch
	Write-Host "--- watcher" -ForegroundColor Cyan
	$wt -split "`r?`n" | Where-Object { $_ -cmatch "PASS|FAIL|RESULT|SCRIPT ERROR" } | ForEach-Object { Write-Host $_ }
	if (-not ($wt -cmatch "RESULT OK")) { $bad = $true }
}
foreach ($s in $slots) { Exit-Slot $s }
if ($bad) { Write-Host "CO-OP TEST FAILED" -ForegroundColor Red; exit 1 }
Set-CachedPass $crew $tree $key $me
Write-Host "CO-OP TEST OK" -ForegroundColor Green
exit 0

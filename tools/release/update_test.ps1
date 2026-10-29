# The in-game update, end to end on this machine (Patcher + a Godot patch pack): exports a base build of the
# "Windows Desktop" preset (debug: the editor's native library), makes a throwaway change to a script, exports a patch
# against the base's pack (--export-patch --patches), puts it in the exported game's user folder as a waiting download
# (next.pck + next.json, as Updater leaves it), starts the base and checks Patcher promoted it, loaded it and that the
# changed file reads back changed. Puts the script back and clears the user folder's update after. Opens a window
# (the export's shader baker needs one). Usage: powershell -File tools/release/update_test.ps1
# (Godot writes to stderr as it works: only the files it leaves decide)
$ErrorActionPreference = "Continue"
$root = Resolve-Path "$PSScriptRoot/../.."
Set-Location $root
if (-not $env:GODOT) { throw "Set GODOT to the console build" }
$out = Join-Path $env:TEMP "driftwake_update_test"
Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$out/base" | Out-Null
$user = Join-Path $env:APPDATA "Godot/app_userdata/Driftwake/update"
$probe = "scripts/ui/whats_new.gd"
$keep = Get-Content -Raw $probe
# (an autoload too: Settings loads right after Patcher, so a patched one must run its new code)
$auto = "scripts/game/settings.gd"
$keep_auto = Get-Content -Raw $auto
$ver = (Select-String -Path project.godot -Pattern '^config/version="(.*)"').Matches[0].Groups[1].Value
try {
	& $env:GODOT --path . --export-debug "Windows Desktop" "$out/base/Driftwake.exe" *> "$out/base.log"
	if (-not (Test-Path "$out/base/Driftwake.pck")) { throw "base export failed: $out/base.log" }
	Add-Content -Path $probe -Value "`nconst _UPDATE_TEST := $(Get-Random)" -NoNewline
	Add-Content -Path $auto -Value "`n`nvar _update_test := _update_said()`n`n`nfunc _update_said() -> int:`n`tprint(`"UPDATE TEST: the patched autoload runs`")`n`treturn 0`n" -NoNewline
	& $env:GODOT --path . --export-patch "Windows Desktop" "$out/patch.pck" --patches "$out/base/Driftwake.pck" *> "$out/patch.log"
	if (-not (Test-Path "$out/patch.pck")) { throw "patch export failed: $out/patch.log" }
} finally {
	Set-Content -Path $probe -Value $keep -NoNewline
	Set-Content -Path $auto -Value $keep_auto -NoNewline
}
New-Item -ItemType Directory -Force $user | Out-Null
Copy-Item "$out/patch.pck" "$user/next.pck"
$sha = (Get-FileHash "$out/patch.pck" -Algorithm SHA256).Hash.ToLower()
'{"base":"' + $ver + '","version":"' + $ver + '.99","sha256":"' + $sha + '"}' | Set-Content "$user/next.json" -NoNewline
$env:DRIFTWAKE_UPDATE_PROBE = "res://$($probe)c"
$p = Start-Process -FilePath "$out/base/Driftwake.console.exe" -ArgumentList "--headless" -RedirectStandardOutput "$out/run.log" -PassThru -NoNewWindow
Start-Sleep -Seconds 20
if (-not $p.HasExited) { Stop-Process $p -Force }
$env:DRIFTWAKE_UPDATE_PROBE = ""
$log = Get-Content -Raw "$out/run.log"
Remove-Item -Recurse -Force $user -ErrorAction SilentlyContinue
$size = (Get-Item "$out/patch.pck").Length
$base = (Get-Item "$out/base/Driftwake.pck").Length
"base pack {0:N1} MB, patch {1:N1} KB" -f ($base / 1MB), ($size / 1KB)
if ($log -match "Patcher: $([regex]::Escape($ver)).99 on base $([regex]::Escape($ver))" -and $log -match "Patcher probe: changed" -and $log -match "UPDATE TEST: the patched autoload runs") {
	"UPDATE TEST OK"
	exit 0
}
"UPDATE TEST FAILED (log: $out/run.log)"
($log -split "`n" | Select-String "Patcher|UPDATE TEST") | ForEach-Object { $_.Line }
exit 1

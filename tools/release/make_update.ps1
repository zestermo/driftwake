# A release's update (CI, build-windows.yml, after the export; Updater and Patcher read what it writes):
#   build/update.json       {"version", "base", "full_required", "patch", "size", "sha256"}
#   build/Driftwake-patch.pck   one cumulative patch against the base release's pack (Godot --export-patch, delta-encoded)
# The base is the one the last stable release names in its update.json. This release is a new base instead (full
# download, no patch; full_required) when:
#   - the last release has no update.json (the first release with the updater), or there's no last release
#   - tools/release/NEW_BASE exists (delete it after the release)
#   - since the base: native/ or the .gdextension changed (the DLL beside the exe), or project.godot changed beyond its
#     version line (autoloads, input, shader globals: a patch can't change settings), or the Godot version did
#   - the patch would be more than MAX_SHARE of the base's pack
# Usage: pwsh tools/release/make_update.ps1 -Version 1.26 -Godot <editor> [-Repo zestermo/driftwake]
param(
	[Parameter(Mandatory = $true)][string]$Version,
	[Parameter(Mandatory = $true)][string]$Godot,
	[string]$Repo = "zestermo/driftwake",
	[double]$MaxShare = 0.4
)
$ErrorActionPreference = "Continue"
$root = Resolve-Path "$PSScriptRoot/../.."
Set-Location $root
New-Item -ItemType Directory -Force build | Out-Null

function Write-Update([string]$base, [bool]$full, [string]$why, [string]$patch = "") {
	$info = [ordered]@{ version = $Version; base = $base; full_required = $full; patch = ""; size = 0; sha256 = ""; why = $why }
	if ($patch -ne "") {
		$info.patch = "Driftwake-patch.pck"
		$info.size = (Get-Item $patch).Length
		$info.sha256 = (Get-FileHash $patch -Algorithm SHA256).Hash.ToLower()
	}
	$info | ConvertTo-Json | Set-Content build/update.json
	"update.json: " + ($info | ConvertTo-Json -Compress)
}

# the last stable release and the base it names
$prev = (gh release view --repo $Repo --json tagName --jq .tagName 2>$null)
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) "driftwake_update_$Version"
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $tmp | Out-Null
$base = ""
if ($prev -and $prev -ne "v$Version") {
	gh release download $prev --repo $Repo -p update.json -D $tmp 2>$null
	if (Test-Path "$tmp/update.json") {
		$base = (Get-Content -Raw "$tmp/update.json" | ConvertFrom-Json).base
	}
}
if ($base -eq "") { Write-Update $Version $true "a new base: no earlier release with an update.json"; exit 0 }
if (Test-Path tools/release/NEW_BASE) { Write-Update $Version $true "a new base: tools/release/NEW_BASE"; exit 0 }

# what changed since the base that a patch can't carry
$changed = git diff --name-only "v$base" HEAD 2>$null
if ($LASTEXITCODE -ne 0) { Write-Update $Version $true "a new base: no tag v$base to compare with"; exit 0 }
$native = $changed | Where-Object { $_ -like "native/*" -or $_ -like "*.gdextension" -or $_ -like ".github/actions/setup-godot/*" }
$proj = git diff "v$base" HEAD -- project.godot | Select-String '^[+-][^+-]' | Where-Object { $_.Line -notmatch '^[+-]config/version=' }
$godot_ver = git diff "v$base" HEAD -- .github/workflows/build-windows.yml | Select-String '^[+-]\s*GODOT_VERSION'
if ($native) { Write-Update $Version $true "a new base: the native library changed ($($native -join ', '))"; exit 0 }
if ($proj) { Write-Update $Version $true "a new base: project settings changed"; exit 0 }
if ($godot_ver) { Write-Update $Version $true "a new base: the Godot version changed"; exit 0 }

# the base's pack, and the patch against it
gh release download "v$base" --repo $Repo -p Driftwake-windows.zip -D $tmp
Expand-Archive "$tmp/Driftwake-windows.zip" -DestinationPath "$tmp/base" -Force
$pck = Get-ChildItem "$tmp/base" -Recurse -Filter Driftwake.pck | Select-Object -First 1
if (-not $pck) { Write-Update $Version $true "a new base: v$base's zip has no Driftwake.pck"; exit 0 }
& $Godot --path . --export-patch "Windows Desktop" build/Driftwake-patch.pck --patches $pck.FullName 2>&1 | Tee-Object build/patch.log | Out-Null
if (-not (Test-Path build/Driftwake-patch.pck)) { Write-Update $Version $true "a new base: the patch export failed"; exit 0 }
$share = (Get-Item build/Driftwake-patch.pck).Length / $pck.Length
"patch: {0:N1} MB, {1:P0} of the base's pack" -f ((Get-Item build/Driftwake-patch.pck).Length / 1MB), $share
if ($share -gt $MaxShare) {
	Remove-Item build/Driftwake-patch.pck
	Write-Update $Version $true ("a new base: the patch would be {0:P0} of the base" -f $share)
	exit 0
}
Write-Update $base $false "a patch on v$base" "build/Driftwake-patch.pck"

# The site's GIFs from siteshot's clip frames (15 fps): <Out>/clips/<name>/NNN.png -> web/site/img/clips/<name>.gif + <name>.jpg (poster, frame 0).
param([string]$Out = "tools/dev/out/site", [int]$Fps = 15, [int]$Colors = 256, [string[]]$Only = @())
$ErrorActionPreference = "Stop"
$dst = "web/site/img/clips"
New-Item -ItemType Directory -Force $dst | Out-Null
foreach ($dir in Get-ChildItem "$Out/clips" -Directory) {
	$n = $dir.Name
	if ($Only.Count -gt 0 -and $Only -notcontains $n) { continue }
	ffmpeg -v error -y -framerate 15 -i "$($dir.FullName)/%03d.png" -vf "fps=$Fps,split[a][b];[a]palettegen=max_colors=${Colors}:stats_mode=full[p];[b][p]paletteuse=dither=none" -loop 0 "$dst/$n.gif"
	ffmpeg -v error -y -i "$($dir.FullName)/000.png" -q:v 2 "$dst/$n.jpg"
	"{0,-8} {1,7:N0} KB gif  {2,5:N0} KB poster" -f $n, ((Get-Item "$dst/$n.gif").Length / 1KB), ((Get-Item "$dst/$n.jpg").Length / 1KB)
}

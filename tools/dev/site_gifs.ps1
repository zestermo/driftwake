# The site's GIFs from siteshot's clip frames (15 fps): <Out>/clips/<name>/NNN.png -> web/site/img/clips/<name>.gif + <name>.jpg (poster, frame 0
# or -Poster name=frame). -Stills site=shot,... copies siteshot stills: <Out>/<shot>.jpg and <shot>-640.jpg -> web/site/img/<site>.jpg / -640.jpg.
param([string]$Out = "tools/dev/out/site", [int]$Fps = 15, [int]$Colors = 256, [string[]]$Only = @(), [string[]]$Poster = @(), [string[]]$Stills = @())
$ErrorActionPreference = "Stop"
foreach ($s in $Stills) {
	$site, $shot = $s -split "=", 2
	Copy-Item "$Out/$shot.jpg" "web/site/img/$site.jpg"
	Copy-Item "$Out/$shot-640.jpg" "web/site/img/$site-640.jpg"
	"{0,-12} {1,7:N0} KB  {2,5:N0} KB 640  (from {3})" -f $site, ((Get-Item "web/site/img/$site.jpg").Length / 1KB), ((Get-Item "web/site/img/$site-640.jpg").Length / 1KB), $shot
}
if ($Stills.Count -gt 0 -and $Only.Count -eq 0) { return }
$posters = @{}
foreach ($p in $Poster) { $k, $v = $p -split "=", 2; $posters[$k] = [int]$v }
$dst = "web/site/img/clips"
New-Item -ItemType Directory -Force $dst | Out-Null
foreach ($dir in Get-ChildItem "$Out/clips" -Directory) {
	$n = $dir.Name
	if ($Only.Count -gt 0 -and $Only -notcontains $n) { continue }
	ffmpeg -v error -y -framerate 15 -i "$($dir.FullName)/%03d.png" -vf "fps=$Fps,split[a][b];[a]palettegen=max_colors=${Colors}:stats_mode=full[p];[b][p]paletteuse=dither=none" -loop 0 "$dst/$n.gif"
	$f = "{0:D3}" -f ($(if ($posters.ContainsKey($n)) { $posters[$n] } else { 0 }))
	ffmpeg -v error -y -i "$($dir.FullName)/$f.png" -q:v 2 "$dst/$n.jpg"
	"{0,-8} {1,7:N0} KB gif  {2,5:N0} KB poster" -f $n, ((Get-Item "$dst/$n.gif").Length / 1KB), ((Get-Item "$dst/$n.jpg").Length / 1KB)
}

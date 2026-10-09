# A small local web server for the site and the browser build (web\site).
#
#   .\tools\dev\serve_web.ps1            # http://localhost:8060/ (the game: /play/)
#   .\tools\dev\serve_web.ps1 -Threads   # also sends COOP/COEP, which a threaded export needs
#
# Ctrl+C stops it. Build the game into web\site\play first: .\tools\dev\build_web.ps1
param(
	[int]$Port = 8060,
	[switch]$Threads,
	[string]$Dir
)

$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Dir) { $Dir = Join-Path $root "web\site" }
$Dir = (Resolve-Path $Dir).Path

$types = @{
	".html" = "text/html; charset=utf-8"; ".js" = "text/javascript"; ".css" = "text/css"
	".wasm" = "application/wasm"; ".pck" = "application/octet-stream"; ".json" = "application/json"
	".png" = "image/png"; ".jpg" = "image/jpeg"; ".svg" = "image/svg+xml"; ".ico" = "image/x-icon"
	".woff2" = "font/woff2"; ".txt" = "text/plain; charset=utf-8"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Dir at http://localhost:$Port/ $(if ($Threads) { '(COOP/COEP on)' }) - Ctrl+C stops" -ForegroundColor Green

try {
	while ($listener.IsListening) {
		$task = $listener.GetContextAsync()
		while (-not $task.AsyncWaitHandle.WaitOne(250)) { }
		$ctx = $task.GetAwaiter().GetResult()
		$res = $ctx.Response
		try {
			$rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart("/")
			$path = [System.IO.Path]::GetFullPath((Join-Path $Dir $rel))
			if (Test-Path $path -PathType Container) {
				if (-not $ctx.Request.Url.AbsolutePath.EndsWith("/")) {
					$res.Redirect($ctx.Request.Url.AbsolutePath + "/")
					continue
				}
				$path = Join-Path $path "index.html"
			}
			if (-not $path.StartsWith($Dir, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $path -PathType Leaf)) {
				$res.StatusCode = 404
				Write-Host "404 $($ctx.Request.Url.AbsolutePath)" -ForegroundColor DarkYellow
			} else {
				$ext = [System.IO.Path]::GetExtension($path).ToLower()
				$res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
				$res.Headers.Add("Cache-Control", "no-cache")
				if ($Threads) {
					$res.Headers.Add("Cross-Origin-Opener-Policy", "same-origin")
					$res.Headers.Add("Cross-Origin-Embedder-Policy", "require-corp")
				}
				$bytes = [System.IO.File]::ReadAllBytes($path)
				$res.ContentLength64 = $bytes.Length
				$res.OutputStream.Write($bytes, 0, $bytes.Length)
			}
		} catch {
			Write-Host "error serving $($ctx.Request.Url): $_" -ForegroundColor Red
		} finally {
			$res.Close()
		}
	}
} finally {
	$listener.Stop()
}

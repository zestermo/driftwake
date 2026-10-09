# Shared state for parallel sessions (dot-sourced by crew.ps1, run_tests.ps1,
# nettest.ps1, land.ps1 and the crew hook). Everything lives in the git common
# dir (<main checkout>\.git\crew), which every worktree shares:
#   slots\     machine-wide test slots (an exclusively opened file each; the OS frees it if a runner dies)
#   results\   suites that passed, by the exact code they ran on (a tree hash of the working tree)
#   claims\    what each session says it's working on (crew.ps1 claim)
#   board.json the last board, for the edit hook (refreshed when older than a minute)

function Get-CrewDir([string]$root) {
	$common = (git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
	$dir = Join-Path $common "crew"
	foreach ($d in @("slots", "results", "claims")) { New-Item -ItemType Directory -Force -Path (Join-Path $dir $d) | Out-Null }
	return $dir
}

function Get-CrewBranch([string]$root) {
	return (git -C $root rev-parse --abbrev-ref HEAD).Trim()
}

## The tree hash of the working tree as it is now, uncommitted changes included
## (a copy of the checkout's index, so only changed files get hashed).
function Get-TreeKey([string]$root) {
	$index = (git -C $root rev-parse --path-format=absolute --git-path index).Trim()
	$tmp = [System.IO.Path]::GetTempFileName()
	Copy-Item $index $tmp -Force
	$old = $env:GIT_INDEX_FILE
	$env:GIT_INDEX_FILE = $tmp
	try {
		git -C $root add -A 2>$null | Out-Null
		$tree = (git -C $root write-tree).Trim()
	} finally {
		$env:GIT_INDEX_FILE = $old
		Remove-Item $tmp -Force -ErrorAction SilentlyContinue
	}
	return $tree
}

function Get-CachedPass([string]$crew, [string]$tree, [string]$suite) {
	$f = Join-Path $crew "results\$tree\$suite.ok"
	if (Test-Path $f) { return (Get-Content $f -Raw).Trim() }
	return $null
}

function Set-CachedPass([string]$crew, [string]$tree, [string]$suite, [string]$branch) {
	$d = Join-Path $crew "results\$tree"
	New-Item -ItemType Directory -Force -Path $d | Out-Null
	Set-Content -Path (Join-Path $d "$suite.ok") -Value ("{0} at {1:HH:mm}" -f $branch, (Get-Date)) -Encoding UTF8
}

## Results older than two days go (a tree is rarely tested again after that).
function Clear-OldResults([string]$crew) {
	Get-ChildItem (Join-Path $crew "results") -Directory -ErrorAction SilentlyContinue |
		Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-2) } |
		ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}

function Get-SlotCount() {
	if ($env:DRIFTWAKE_TEST_SLOTS) { return [int]$env:DRIFTWAKE_TEST_SLOTS }
	return 3
}

## A free test slot, or $null: [stream, who-file]. Hold it while Godot runs, then Exit-Slot.
function Enter-Slot([string]$crew, [string]$label) {
	for ($k = 1; $k -le (Get-SlotCount); $k++) {
		$f = Join-Path $crew "slots\slot$k.lock"
		try {
			$fs = [System.IO.File]::Open($f, "OpenOrCreate", "ReadWrite", "None")
		} catch {
			continue
		}
		$who = Join-Path $crew "slots\slot$k.who"
		Set-Content -Path $who -Value ("{0} (since {1:HH:mm:ss})" -f $label, (Get-Date)) -Encoding UTF8
		return @($fs, $who)
	}
	return $null
}

function Exit-Slot($slot) {
	if ($slot) {
		Remove-Item $slot[1] -Force -ErrorAction SilentlyContinue
		$slot[0].Dispose()
	}
}

## Wait for `n` slots at once (nettest: host + client). Prints who's holding them once.
function Wait-Slots([string]$crew, [int]$n, [string]$label) {
	$told = $false
	while ($true) {
		$got = @()
		for ($i = 0; $i -lt $n; $i++) {
			$s = Enter-Slot $crew $label
			if (-not $s) { break }
			$got += , $s
		}
		if ($got.Count -eq $n) { return , $got }
		foreach ($s in $got) { Exit-Slot $s }
		if (-not $told) {
			Write-Host ("Waiting for {0} test slot(s) of {1}: {2}" -f $n, (Get-SlotCount), ((Get-SlotHolders $crew) -join "; ")) -ForegroundColor DarkYellow
			$told = $true
		}
		Start-Sleep -Seconds 2
	}
}

function Get-SlotHolders([string]$crew) {
	return @(Get-ChildItem (Join-Path $crew "slots") -Filter "*.who" -ErrorAction SilentlyContinue | ForEach-Object { (Get-Content $_.FullName -Raw).Trim() })
}

## Every checkout's session: branch, path, its claim, how far ahead of main, and
## every file it's changing (committed since main or not committed yet).
function Get-CrewBoard([string]$root, [string]$main = "main") {
	$crew = Get-CrewDir $root
	$rows = @()
	$cur = $null
	foreach ($l in (git -C $root worktree list --porcelain)) {
		if ($l -like "worktree *") { $cur = $l.Substring(9) }
		elseif ($l -like "branch refs/heads/*") {
			$b = $l.Substring(18)
			if (-not (Test-Path $cur)) { continue }
			$files = @()
			if ($b -ne $main) { $files += @(git -C $root diff --name-only "$main...$b" 2>$null) }
			$files += @(git -C $cur status --porcelain 2>$null | ForEach-Object { ($_.Substring(3) -split " -> ")[-1].Trim('"') })
			$files = @($files | Where-Object { $_ -and $_ -notlike "*.uid" } | Select-Object -Unique)
			$claim = $null
			$cf = Join-Path $crew ("claims\" + ($b -replace "[\\/]", "_") + ".json")
			if (Test-Path $cf) { $claim = Get-Content $cf -Raw | ConvertFrom-Json }
			$ahead = if ($b -eq $main) { 0 } else { [int](git -C $root rev-list --count "$main..$b").Trim() }
			$rows += [pscustomobject]@{ Branch = $b; Path = $cur; Ahead = $ahead; Files = $files; Claim = $claim }
		}
	}
	$board = [pscustomobject]@{ At = (Get-Date).ToString("o"); Rows = $rows }
	$board | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $crew "board.json") -Encoding UTF8
	return $board
}

## The board, from board.json if it's under `maxAge` seconds old.
function Get-CrewBoardCached([string]$root, [int]$maxAge = 60) {
	$f = Join-Path (Get-CrewDir $root) "board.json"
	if (Test-Path $f) {
		$b = Get-Content $f -Raw | ConvertFrom-Json
		if (((Get-Date) - [datetime]$b.At).TotalSeconds -lt $maxAge) { return $b }
	}
	return Get-CrewBoard $root
}

## Does `file` (repo-relative, forward slashes) fall in one of a claim's areas (globs or folders)?
function Test-ClaimArea($claim, [string]$file) {
	if (-not $claim) { return $false }
	foreach ($a in @($claim.areas)) {
		$p = ($a -replace "\\", "/").TrimEnd("/")
		if ($file -like $p -or $file -like "$p/*") { return $true }
	}
	return $false
}

## The other sessions changing or claiming any of `files`: lines to print.
function Get-Overlaps($board, [string]$me, [string[]]$files) {
	$out = @()
	foreach ($r in $board.Rows) {
		if ($r.Branch -eq $me) { continue }
		$hit = @($files | Where-Object { (@($r.Files) -contains $_) -or (Test-ClaimArea $r.Claim $_) })
		if ($hit.Count -gt 0) {
			$task = if ($r.Claim) { " ($($r.Claim.task))" } else { "" }
			$out += "{0}{1}: {2}" -f $r.Branch, $task, (($hit | Select-Object -First 6) -join ", ")
		}
	}
	return $out
}

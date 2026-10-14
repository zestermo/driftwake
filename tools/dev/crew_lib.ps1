# Shared state for parallel sessions (dot-sourced by crew.ps1, run_tests.ps1,
# nettest.ps1, land.ps1 and the crew hook). Everything lives in the git common
# dir (<main checkout>\.git\crew), which every worktree shares:
#   slots\     machine-wide test slots (an exclusively opened file each; the OS frees it if a runner dies)
#   results\   suites that passed, by the exact code they ran on (a tree hash of the working tree)
#   claims\    what each session says it's working on (crew.ps1 claim)
#   live\      every test run's live status (<run id>.json; the Tests pane reads them)
#   inflight\  suites running right now, by tree (a second runner of the same code waits for it)
#   ledger\    each suite's last result (<suite>.json: passed/failed/stopped, the tree, branch, when, why,
#              seconds and setup seconds); ledger\history\<suite>.jsonl every result (suite_times.ps1)
#   landing.lock / landing.json  the one land.ps1 running (held open; who, since, step); landq\ the landers waiting
#   status.json every suite's state against the main checkout's code (tools/dev/test_status.ps1)
#   board.json the last board, for the edit hook (refreshed when older than a minute)

function Get-CrewDir([string]$root) {
	$common = (git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
	$dir = Join-Path $common "crew"
	foreach ($d in @("slots", "results", "claims", "live", "inflight", "ledger", "ledger\history", "landq")) { New-Item -ItemType Directory -Force -Path (Join-Path $dir $d) | Out-Null }
	return $dir
}

## Replace a small JSON file in one move (a reader may have it open this instant: Windows then refuses, so retry).
function Write-CrewJson([string]$path, $obj) {
	[System.IO.File]::WriteAllText("$path.tmp", ($obj | ConvertTo-Json -Depth 6 -Compress))
	for ($i = 0; ; $i++) {
		try { Move-Item -Force "$path.tmp" $path -ErrorAction Stop; return }
		catch [System.IO.IOException] { if ($i -ge 20) { throw }; Start-Sleep -Milliseconds 50 }
	}
}

# ---------------------------------------------------------------------------
# Landing: one land.ps1 at a time machine-wide, the rest wait in order.
# ---------------------------------------------------------------------------

## Who's landing now (landing.json), or $null. A landing.json whose lock nobody holds (its lander died) is cleared.
function Get-Landing([string]$crew) {
	$f = Join-Path $crew "landing.json"
	if (-not (Test-Path $f)) { return $null }
	try {
		([System.IO.File]::Open((Join-Path $crew "landing.lock"), "OpenOrCreate", "ReadWrite", "None")).Dispose()
		Remove-Item $f -Force -ErrorAction SilentlyContinue
		return $null
	} catch { }
	# (it can be mid-replace for an instant: the step changing)
	$t = Get-Content $f -Raw -ErrorAction SilentlyContinue
	if ($t) { return ($t | ConvertFrom-Json) }
	return $null
}

## The landers waiting, oldest first (an entry whose process is gone is cleared).
function Get-LandQueue([string]$crew) {
	$out = @()
	foreach ($f in @(Get-ChildItem (Join-Path $crew "landq") -Filter "*.json" -ErrorAction SilentlyContinue | Sort-Object Name)) {
		# (gone already if its lander just took the lock)
		$t = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
		if (-not $t) { continue }
		$q = $t | ConvertFrom-Json
		if (Get-Process -Id $q.pid -ErrorAction SilentlyContinue) { $out += $q } else { Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue }
	}
	return $out
}

## Wait in line, then take the landing lock: the lock's stream (hold it; Exit-Landing). Says who it's waiting for.
function Enter-Landing([string]$crew, [string]$branch) {
	$since = Get-Date
	$q = Join-Path $crew ("landq\{0:yyyyMMdd-HHmmss-fff}-{1}.json" -f $since, $PID)
	Write-CrewJson $q ([ordered]@{ branch = $branch; pid = $PID; since = $since.ToString("o") })
	$told = ""
	try {
		while ($true) {
			$line = @(Get-LandQueue $crew)
			if ($line.Count -gt 0 -and $line[0].pid -eq $PID) {
				$fs = $null
				try { $fs = [System.IO.File]::Open((Join-Path $crew "landing.lock"), "OpenOrCreate", "ReadWrite", "None") } catch { }
				if ($fs) {
					Write-CrewJson (Join-Path $crew "landing.json") ([ordered]@{ branch = $branch; pid = $PID; since = (Get-Date).ToString("o"); step = "starting" })
					return $fs
				}
			}
			$now = Get-Landing $crew
			$ahead = @($line | Where-Object { $_.pid -ne $PID -and [datetime]$_.since -le $since } | ForEach-Object { $_.branch })
			$msg = "Waiting to land {0}: {1}{2}" -f $branch,
				$(if ($now) { "{0} is landing (since {1:HH:mm}, {2})" -f $now.branch, [datetime]$now.since, $now.step } else { "the lock is being handed on" }),
				$(if ($ahead) { "; ahead of you: " + ($ahead -join ", ") } else { "" })
			if ($msg -ne $told) { Write-Host $msg -ForegroundColor DarkYellow; $told = $msg }
			Start-Sleep -Seconds 3
		}
	} finally {
		Remove-Item $q -Force -ErrorAction SilentlyContinue
	}
}

function Set-LandingStep([string]$crew, [string]$step) {
	$f = Join-Path $crew "landing.json"
	$l = Get-Content $f -Raw | ConvertFrom-Json
	$l.step = $step
	Write-CrewJson $f $l
}

function Exit-Landing([string]$crew, $fs) {
	Remove-Item (Join-Path $crew "landing.json") -Force -ErrorAction SilentlyContinue
	$fs.Dispose()
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
	return 5
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

## Who holds the slots now: a .who whose lock is still open (a killed runner leaves its .who behind).
function Get-SlotHolders([string]$crew) {
	$out = @()
	foreach ($w in @(Get-ChildItem (Join-Path $crew "slots") -Filter "*.who" -ErrorAction SilentlyContinue)) {
		$lock = $w.FullName -replace "\.who$", ".lock"
		try {
			([System.IO.File]::Open($lock, "OpenOrCreate", "ReadWrite", "None")).Dispose()
			Remove-Item $w.FullName -Force -ErrorAction SilentlyContinue
		} catch {
			$out += (Get-Content $w.FullName -Raw).Trim()
		}
	}
	return $out
}

## Import once if this checkout has no import cache, or is missing a class_name (a new script,
## or another branch's merged or landed in): without it every script naming that class fails to parse.
function Update-ImportCache([string]$root, [string]$godot) {
	$classCache = Join-Path $root ".godot\global_script_class_cache.cfg"
	$need = -not (Test-Path (Join-Path $root ".godot\imported"))
	if (-not $need) {
		$known = if (Test-Path $classCache) { Get-Content $classCache -Raw } else { "" }
		$missing = @(Get-ChildItem (Join-Path $root "scripts"), (Join-Path $root "scenes") -Recurse -Filter "*.gd" |
			Select-String -Pattern "^class_name\s+(\w+)" -List |
			ForEach-Object { $_.Matches[0].Groups[1].Value } |
			Where-Object { $known -notmatch "&`"$_`"" })
		$need = $missing.Count -gt 0
		if ($need) { Write-Host ("New class names (" + ($missing -join ", ") + "): importing once...") -ForegroundColor Yellow }
		# ...or an asset whose imported copy isn't there (a texture, sound or shader another branch landed)
		if (-not $need) {
			$stale = @(Get-ChildItem (Join-Path $root "assets"), (Join-Path $root "resources") -Recurse -Filter "*.import" -ErrorAction SilentlyContinue |
				Select-String -Pattern '^dest_files=\["res://([^"]+)"' -List |
				Where-Object { -not (Test-Path (Join-Path $root $_.Matches[0].Groups[1].Value)) } |
				ForEach-Object { $_.Path -replace '\.import$', '' | Split-Path -Leaf })
			$need = $stale.Count -gt 0
			if ($need) { Write-Host ("Assets not imported here (" + (($stale | Select-Object -First 5) -join ", ") + $(if ($stale.Count -gt 5) { ", ..." } else { "" }) + "): importing once...") -ForegroundColor Yellow }
		}
	} else {
		Write-Host "No .godot import cache here: importing once (a minute or two)..." -ForegroundColor Yellow
	}
	if ($need) {
		$old = $ErrorActionPreference
		$ErrorActionPreference = "Continue"
		& $godot --headless --path "$root" --import 2>&1 | Out-Null
		$ErrorActionPreference = $old
	}
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

# ---------------------------------------------------------------------------
# Live test runs: every Godot a runner starts writes straight to its log file
# (cmd's redirect, so nothing waits on a pipe), and the runner tails that file
# each tick for the Tests pane, for stalls and for error floods.
# ---------------------------------------------------------------------------

## Quiet this long with no new output (s) and a suite is called stalled and stopped.
function Get-StallSeconds() { if ($env:DRIFTWAKE_TEST_STALL) { return [int]$env:DRIFTWAKE_TEST_STALL }; return 150 }
## Script errors past this, or a log past MAX_LOG_MB, and the suite is stopped as a flood.
$script:FLOOD_ERRORS = 400
$script:MAX_LOG_MB = 25

## A run whose runner died (killed, its session stopped) still says "running": mark it stopped so the pane stops counting its suites.
function Close-DeadRuns([string]$crew) {
	foreach ($f in Get-ChildItem (Join-Path $crew "live") -Filter "*.json" -ErrorAction SilentlyContinue) {
		$r = Get-Content $f.FullName -Raw | ConvertFrom-Json
		if (($r.state -ne "running" -and $r.state -ne "compiling") -or (Get-Process -Id $r.pid -ErrorAction SilentlyContinue)) { continue }
		$r.state = "stopped"
		$r.ended = (Get-Date).ToString("o")
		foreach ($s in $r.suites.PSObject.Properties.Value) {
			if (@("running", "queued", "waiting", "shared") -contains $s.state) { $s.state = "stopped"; $s.why = "runner gone" }
		}
		[System.IO.File]::WriteAllText("$($f.FullName).tmp", ($r | ConvertTo-Json -Depth 6 -Compress))
		Move-Item -Force "$($f.FullName).tmp" $f.FullName
	}
}

function New-LiveRun([string]$crew, [string]$root, [string]$branch, [string]$kind, [string[]]$names) {
	# runs older than a day go
	Get-ChildItem (Join-Path $crew "live") -Filter "*.json" -ErrorAction SilentlyContinue |
		Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Force -ErrorAction SilentlyContinue
	Close-DeadRuns $crew
	$id = "{0:yyyyMMdd-HHmmss}-{1}" -f (Get-Date), $PID
	$suites = [ordered]@{}
	foreach ($n in $names) { $suites[$n] = [ordered]@{ name = $n; state = "queued"; secs = 0; log = ""; pid = 0; last = @(); why = ""; seed = "" } }
	$run = [pscustomobject]@{
		Data = [ordered]@{ id = $id; branch = $branch; root = $root; kind = $kind; pid = $PID; started = (Get-Date).ToString("o"); ended = ""; state = "running"; suites = $suites }
		File = Join-Path $crew "live\$id.json"
		Saved = [datetime]::MinValue
	}
	Save-LiveRun $run $true
	return $run
}

## Write the run's status (at most twice a second unless forced: the pane polls once a second).
function Save-LiveRun($run, [bool]$force = $false) {
	if (-not $force -and ((Get-Date) - $run.Saved).TotalMilliseconds -lt 500) { return }
	$run.Saved = Get-Date
	$tmp = "$($run.File).tmp"
	[System.IO.File]::WriteAllText($tmp, ($run.Data | ConvertTo-Json -Depth 6 -Compress))
	# the Tests pane may be reading the file this instant (Windows then refuses the replace): try again shortly
	for ($i = 0; ; $i++) {
		try { Move-Item -Force $tmp $run.File -ErrorAction Stop; return }
		catch [System.IO.IOException] { if ($i -ge 20) { throw }; Start-Sleep -Milliseconds 50 }
	}
}

function Set-LiveSuite($run, [string]$name, [hashtable]$fields) {
	$s = $run.Data.suites[$name]
	foreach ($k in $fields.Keys) { $s[$k] = $fields[$k] }
}

## A headless Godot running res://tools/dev/<script>, its stdout and stderr redirected to `log` by cmd.
## `seed` (if any) goes to it as DRIFTWAKE_SEED (tools/dev/test_kit.gd).
function Start-GodotJob([string]$godot, [string]$root, [string]$script, [string]$extra, [string]$log, [string]$seed = "") {
	Remove-Item $log -Force -ErrorAction SilentlyContinue
	$gargs = "--headless --path `"$root`" --script res://tools/dev/$script" + $(if ($extra) { " -- $extra" } else { "" })
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = "cmd.exe"
	$psi.Arguments = "/d /c `"`"$godot`" $gargs > `"$log`" 2>&1`""
	$psi.WorkingDirectory = $root
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $true
	$psi.EnvironmentVariables.Remove("DRIFTWAKE_SEED")
	if ($seed) { $psi.EnvironmentVariables["DRIFTWAKE_SEED"] = $seed }
	$p = [System.Diagnostics.Process]::Start($psi)
	return [pscustomobject]@{ Proc = $p; Log = $log; Started = Get-Date; Grew = Get-Date; First = [datetime]::MinValue; Offset = [long]0; Carry = ""
		Errors = 0; FirstErrors = @(); Tail = New-Object System.Collections.Generic.List[string]; Parse = $false
		Fail = New-Object System.Collections.Generic.List[string]; FailAt = [datetime]::MinValue; FailDone = $false; Seed = "" }
}

## Read what the job wrote since last time (at most 1 MB a tick): the tail, the error count, growth.
function Update-GodotJob($job) {
	if (-not (Test-Path $job.Log)) { return }
	$fs = [System.IO.File]::Open($job.Log, "Open", "Read", "ReadWrite")
	try {
		if ($fs.Length -le $job.Offset) { return }
		$fs.Seek($job.Offset, "Begin") | Out-Null
		$n = [int][Math]::Min($fs.Length - $job.Offset, 1MB)
		$buf = New-Object byte[] $n
		$got = $fs.Read($buf, 0, $n)
		$job.Offset += $got
		$job.Grew = Get-Date
		$text = $job.Carry + [System.Text.Encoding]::UTF8.GetString($buf, 0, $got)
		$lines = @($text -split "`r?`n")
		$job.Carry = $lines[-1]
		# (0..-1 counts down in PowerShell: one piece means no whole line yet)
		$whole = if ($lines.Count -gt 1) { $lines[0..($lines.Count - 2)] } else { @() }
		foreach ($l in $whole) {
			if (-not $l.Trim()) { continue }
			if ($job.First -eq [datetime]::MinValue -and $l -cmatch "^\s*(PASS|FAIL)\b") { $job.First = Get-Date }
			# (the seed in use: a suite looping over seeds prints each; the failure ran on the latest)
			if ($job.Fail.Count -eq 0 -and $l -cmatch "^SEED (-?\d+)") { $job.Seed = $Matches[1] }
			# the first failure and the stack lines under it, whole
			if ($job.Fail.Count -gt 0 -and -not $job.FailDone) {
				if ($l -match "^\s*(at:|GDScript backtrace|\[\d+\])" -and $job.Fail.Count -lt 24) { $job.Fail.Add($l.TrimEnd()) } else { $job.FailDone = $true }
			}
			if ($job.Fail.Count -eq 0 -and ($l -cmatch "^\s*FAIL" -or $l -match "SCRIPT ERROR")) {
				$job.Fail.Add($l.Trim())
				$job.FailAt = Get-Date
			}
			if ($l -match "SCRIPT ERROR") {
				$job.Errors++
				if ($job.FirstErrors.Count -lt 4) { $job.FirstErrors += $l.Trim() }
				if ($l -match "Parse Error") { $job.Parse = $true }
			}
			$job.Tail.Add($l)
			if ($job.Tail.Count -gt 12) { $job.Tail.RemoveAt(0) }
		}
	} finally { $fs.Dispose() }
}

## Why a still-running job should be stopped now ("" = let it run).
function Get-JobTrouble($job, [int]$timeout) {
	$age = ((Get-Date) - $job.Started).TotalSeconds
	if ($job.Parse -and $age -gt 3) { return "scripts don't parse: " + ($job.FirstErrors | Select-Object -First 1) }
	if ($job.Errors -gt $script:FLOOD_ERRORS) { return "error flood ($($job.Errors) script errors), first: " + ($job.FirstErrors | Select-Object -First 1) }
	if ($job.Offset -gt $script:MAX_LOG_MB * 1MB) { return "log flood (over $($script:MAX_LOG_MB) MB)" }
	if (((Get-Date) - $job.Grew).TotalSeconds -gt (Get-StallSeconds)) { return "stalled (no output for $(Get-StallSeconds) s)" }
	if ($age -gt $timeout) { return "timeout after $timeout s" }
	return ""
}

## The first failure, once its stack lines are in (or a second has passed): the suite stops on it.
function Get-JobFailure($job) {
	if ($job.Fail.Count -eq 0) { return @() }
	if (-not $job.FailDone -and ((Get-Date) - $job.FailAt).TotalSeconds -lt 1.0) { return @() }
	return @($job.Fail)
}

function Stop-GodotJob($job) {
	if (-not $job.Proc.HasExited) { & taskkill /T /F /PID $job.Proc.Id 2>&1 | Out-Null }
	$job.Proc.WaitForExit(5000) | Out-Null
}

## The log's verdict lines (FAIL, RESULT, SCRIPT ERROR; streamed, not read whole), unique, first `n`.
function Get-JobSummary($job, [int]$n = 12) {
	if (-not (Test-Path $job.Log)) { return @() }
	return @(Select-String -Path $job.Log -Pattern "FAIL|RESULT|SCRIPT ERROR" -CaseSensitive |
		ForEach-Object { $_.Line.Trim() } | Select-Object -Unique | Select-Object -First $n)
}

## Known flaky checks (tools/dev/flaky.txt: "suite | text in the FAIL line"): every FAIL known -> one retry.
function Test-AllFlaky([string]$suite, [string[]]$fails) {
	$f = Join-Path $PSScriptRoot "flaky.txt"
	if (-not (Test-Path $f) -or $fails.Count -eq 0) { return $false }
	$known = @(Get-Content $f | Where-Object { $_ -match "^\s*[^#\s]" } | ForEach-Object { $p = $_ -split "\|", 2; if ($p.Count -eq 2) { , @($p[0].Trim(), $p[1].Trim()) } })
	foreach ($l in $fails) {
		$ok = $false
		foreach ($k in $known) { if ($k[0] -eq $suite -and $l.Contains($k[1])) { $ok = $true } }
		if (-not $ok) { return $false }
	}
	return $true
}

## Someone else running this exact suite on this exact code right now: their run id, or "".
function Get-InFlight([string]$crew, [string]$tree, [string]$suite) {
	$f = Join-Path $crew "inflight\$tree-$suite.txt"
	if (-not (Test-Path $f)) { return "" }
	$p = (Get-Content $f -Raw).Trim() -split " ", 2
	if (Get-Process -Id ([int]$p[0]) -ErrorAction SilentlyContinue) { return $p[1] }
	Remove-Item $f -Force -ErrorAction SilentlyContinue
	return ""
}

## Seconds from the suite's start to its first PASS/FAIL line (loading, world build), or -1 if none came.
function Get-JobSetup($job) {
	if ($job.First -eq [datetime]::MinValue) { return -1 }
	return [int]($job.First - $job.Started).TotalSeconds
}

## A suite's latest result, whoever ran it (test_status.ps1 and the Tests pane read these), and a line in its
## history (suite_times.ps1). `setup`: Get-JobSetup's, -1 when not measured.
function Write-Ledger([string]$crew, [string]$suite, [string]$state, [string]$tree, [string]$branch, [int]$secs, [string]$why, [int]$setup = -1) {
	$f = Join-Path $crew "ledger\$suite.json"
	$rec = [ordered]@{ suite = $suite; state = $state; tree = $tree; branch = $branch; at = (Get-Date).ToString("o"); secs = $secs; setup = $setup; why = $why }
	[System.IO.File]::WriteAllText("$f.tmp", ($rec | ConvertTo-Json -Compress))
	Move-Item -Force "$f.tmp" $f
	$h = Join-Path $crew "ledger\history\$suite.jsonl"
	$line = ([ordered]@{ state = $state; at = $rec.at; secs = $secs; setup = $setup; branch = $branch } | ConvertTo-Json -Compress) + "`n"
	for ($i = 0; ; $i++) {
		try { [System.IO.File]::AppendAllText($h, $line); return }
		catch [System.IO.IOException] { if ($i -ge 20) { throw }; Start-Sleep -Milliseconds 50 }
	}
}

function Set-InFlight([string]$crew, [string]$tree, [string]$suite, [string]$label, [bool]$on) {
	$f = Join-Path $crew "inflight\$tree-$suite.txt"
	if ($on) { Set-Content -Path $f -Value "$PID $label" -Encoding UTF8 } else { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

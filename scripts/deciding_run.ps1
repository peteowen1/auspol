# DECIDING RUN: the full-size (default 20,000 simulations, all elections) paired
# arm-vs-baseline run for a SHIPPING decision, as a process that outlives the Claude
# Code session. It is scripts/quick_arm.R at --pairs=all --slots=1 --no-reuse, run by a
# one-shot Windows Scheduled Task (so its parent is the Task Scheduler service, not the
# shell or session that launched it, and a session reaping its background shells cannot
# kill it).
#
#   powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_X=1" -Label my-idea
#   powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_X=1" -Label my-idea -At 22:30
#   ... -Base "AUSPOL_FOO=1"   extra switches for the baseline (default: shipped config)
#   ... -Sims 20000            simulations per run (default 20000)
#   ... -Pairs vic2022,nsw2023 restrict to some elections (default all; for proofs)
#   ... -At HH:MM              start then (today, or tomorrow if already past); default now
#
# Output lives in deciding-runs/<YYYYMMDD-HHMM>-<label>/ (gitignored; never output/):
#   params.json  what was asked           log.txt      everything the run printed
#   results.txt  the Q0..Q9 verdict lines started.txt  worker pid, parent pid, time
#   DONE or FAILED   marker file, written last; its content is the exit code and time (and why)
#   cache/<key>/<election>/{allprobs,sharedetail}.csv  per-seat outputs, kept for clause scorers
#   PENDING      scheduled, not started: past its time, the task never ran (logged off, asleep)
#   RUNNING      started; with no DONE/FAILED and no live worker pid (started.txt), it was killed
# The next session reads every folder's marker, not only the newest DONE one. DONE also requires
# that the run scored exactly the elections asked for (quick_arm alone defaults to AEF-7).
#
# Limits: the task runs as you, "only when logged on" (a locked screen is fine; a
# logged-out machine is not). The code is a detached worktree snapshot of HEAD (uncommitted
# changes refuse), so edits during the run cannot reach it. The fresh snapshot compiles src/ and copies
# the inputs first (two 2-run vic2022 smokes on 2026-10-11 took 648 s and 210 s end to end; the
# slow one shared the machine with other R work). Slots=1 because the machine is memory-tight; expect hours
# for the full 22 at 20,000 simulations. Nothing here is published or pushed.
param(
  [string]$Arm = "",
  [string]$Base = "",
  [int]$Sims = 20000,
  [string]$Label = "run",
  [string]$Pairs = "all",
  [string]$At = "",
  [switch]$Worker,
  [string]$RunDir = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

if ($Worker) {
  # ---- runs inside the scheduled task ----------------------------------------
  # EVERY path out of here leaves DONE or FAILED (a review found four throws before the old try that
  # left neither). A run killed from outside (reboot, watchdog, 24 h limit) still cannot write one:
  # RUNNING without DONE/FAILED and no live worker pid (started.txt) means it died.
  $log = Join-Path $RunDir "log.txt"
  $code = 1; $why = "worker failed before Rscript started"
  try {
    Remove-Item (Join-Path $RunDir "PENDING") -ErrorAction SilentlyContinue
    "started $(Get-Date -Format s)" | Set-Content (Join-Path $RunDir "RUNNING")
    $p = Get-Content (Join-Path $RunDir "params.json") -Raw | ConvertFrom-Json
    Set-Location $p.Code
    $me = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
    $par = Get-CimInstance Win32_Process -Filter "ProcessId=$($me.ParentProcessId)" -ErrorAction SilentlyContinue
    "worker pid $PID; parent pid $($me.ParentProcessId) ($($par.Name)); started $(Get-Date -Format s)" |
      Set-Content (Join-Path $RunDir "started.txt")
    $rargs = @("scripts/quick_arm.R") + @($p.Arm -split "\s+" | Where-Object { $_ }) +
      @("--sims=$($p.Sims)", "--slots=1", "--no-reuse", "--pairs=$($p.Pairs)")
    if ($p.Base) { $rargs += "--base=$($p.Base)" }
    $ErrorActionPreference = "Continue"   # Rscript writes warnings to stderr; that is not a failure
    $env:AUSPOL_QUICK_DIR = $p.QuickDir
    # PowerShell + Rscript: arrow segfaults under Git Bash R
    # Out-File utf8, not *> (UTF-16 in PowerShell 5.1, which grep and the next session cannot search)
    & Rscript @rargs 2>&1 | ForEach-Object { "$_" } | Out-File $log -Encoding utf8
    $code = $LASTEXITCODE; $why = "quick_arm exited $code"
    $ErrorActionPreference = "Stop"
    $all = @(Get-Content $log)
    $i = ($all | Select-String -Pattern "^Q0" | Select-Object -First 1).LineNumber
    # The election count scored must be the one asked for: quick_arm's own default is AEF-7, and a
    # silently narrower run was the review's first blocker.
    # "all" is read from quick_arm's own header ("at N simulations, K election(s)"), not a constant:
    # a hard-coded 22 refused every run after the corpus grew to 35 elections (2026-10-14).
    $hdrK = ($all | Select-String -Pattern "simulations, (\d+) election" | Select-Object -First 1)
    $want = if ($p.Pairs -eq "all") { if ($hdrK) { [int]$hdrK.Matches[0].Groups[1].Value } else { -2 } } else { @($p.Pairs -split ",").Count }
    $got = if ($i -and $all[$i - 1] -match "in (\d+) election") { [int]$Matches[1] } else { -1 }
    if ($code -eq 0 -and $i -and $got -eq $want) {
      $hdr = @($all | Select-String -Pattern "^quick_arm: arm \{" | Select-Object -First 1 | ForEach-Object { $_.Line })
      @("commit $($p.Commit)") + $hdr + $all[($i - 1)..($all.Count - 1)] | Set-Content (Join-Path $RunDir "results.txt")
      if (-not (Test-Path (Join-Path $RunDir "results.txt"))) { throw "results.txt was not written" }
      "exit 0 at $(Get-Date -Format s)" | Set-Content (Join-Path $RunDir "DONE")
      $why = ""
    } elseif ($code -eq 0) {
      $code = 2; $why = "quick_arm exited 0 but scored $got election(s), asked for $want (Q0 line $(if ($i) { 'present' } else { 'missing' }))"
    }
  } catch {
    $why = "$why; $($_ | Out-String)"
    try { $why | Add-Content $log -Encoding utf8 } catch {}
  }
  if ($why) { "exit $code at $(Get-Date -Format s): $why (see log.txt)" | Set-Content (Join-Path $RunDir "FAILED") }
  Remove-Item (Join-Path $RunDir "RUNNING") -ErrorAction SilentlyContinue
  if (-not $p) { exit $code }
  # Tidy up: quick_arm --clean removes the scratch junctions before the directory (never what they
  # point at); then the snapshot worktree. Failures here are logged, not fatal: the result is written.
  try {
    $ErrorActionPreference = "Continue"
    # Keep every election's allprobs.csv / sharedetail.csv (cache/<key>/<election>/) before --clean
    # deletes the scratch: a scorer for a prereg's own clauses (e.g. score_coalition_split.R) needs
    # per-seat probabilities, and results.txt has only the pooled lines. Plain files, so a Copy is safe.
    $cacheSrc = Join-Path $p.QuickDir "cache"
    if (Test-Path $cacheSrc) {
      Get-ChildItem $cacheSrc -Recurse -File -Include allprobs.csv, sharedetail.csv | ForEach-Object {
        $rel = $_.FullName.Substring($cacheSrc.Length).TrimStart('\', '/')
        $dst = Join-Path (Join-Path $RunDir "cache") $rel
        New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
        Copy-Item $_.FullName $dst -Force
      }
    }
    & Rscript scripts/quick_arm.R --clean 2>&1 | ForEach-Object { "$_" } | Add-Content $log -Encoding utf8
    Set-Location $p.Repo
    & git -C $p.Repo worktree remove --force $p.Code 2>&1 | ForEach-Object { "$_" } | Add-Content $log -Encoding utf8
    $work = Split-Path -Parent $p.Code
    if (-not (Get-ChildItem $work -Force)) { Remove-Item $work }
  } catch { $_ | Out-String | Add-Content $log }
  try { Unregister-ScheduledTask -TaskName $p.TaskName -Confirm:$false } catch {}
  exit $code
}

# ---- launcher ----------------------------------------------------------------
if (-not $Arm) { throw "usage: deciding_run.ps1 -Arm 'AUSPOL_X=1' [-Base ..] [-Sims 20000] [-Label name] [-Pairs a,b] [-At HH:MM]" }
if ($Label -notmatch '^[A-Za-z0-9._-]+$') { throw "Label may only contain letters, digits, . _ -" }
if ($Sims -lt 100) { throw "Sims must be >= 100" }
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$RunDir = Join-Path $repo "deciding-runs\$stamp-$Label"
if (Test-Path $RunDir) { throw "$RunDir already exists" }
New-Item -ItemType Directory -Path $RunDir | Out-Null
$dirty = @(& git -C $repo status --porcelain -- R scripts src DESCRIPTION NAMESPACE)
if ($dirty.Count) {
  Remove-Item $RunDir
  throw "uncommitted changes in R/ scripts/ src/ DESCRIPTION NAMESPACE; the deciding run measures a COMMIT, commit first:`n$($dirty -join "`n")"
}
$sha = (& git -C $repo rev-parse --short HEAD).Trim()
$task = "auspol-deciding-$stamp-$Label"
# The run executes from a detached worktree of HEAD with its own scratch dir, not from this checkout:
# quick_arm's scratch links to the LIVE R/, scripts/ and src/, so an edit made during an hours-long run
# would reach every harness process launched after it, and the shared default scratch dir would be
# rebuilt under it by any quick_arm screen run meanwhile. output/ and external/ come from the main
# checkout (quick_arm's own fallback); output/ inputs are copied into the scratch once, at setup.
$work = Join-Path $env:TEMP "auspol-deciding\$stamp-$Label"
$snap = Join-Path $work "code"
$ErrorActionPreference = "Continue"   # PowerShell 5.1 turns git's progress line on stderr into a terminating error under Stop
& git -C $repo worktree add --detach $snap HEAD 2>&1 | Out-Null
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $snap "DESCRIPTION"))) { Remove-Item $RunDir; throw "could not create the code snapshot at $snap" }
$quickDir = Join-Path $work "scratch"
@{ Arm = $Arm; Base = $Base; Sims = $Sims; Label = $Label; Pairs = $Pairs; At = $At; Commit = $sha;
   TaskName = $task; QuickDir = $quickDir; Code = $snap; Repo = $repo } | ConvertTo-Json | Set-Content (Join-Path $RunDir "params.json")

Write-Host "deciding run: arm {$Arm} vs baseline {$(if ($Base) { $Base } else { 'shipped' })}"
Write-Host "  sims $Sims, pairs $(if ($Pairs -eq 'all') { 'all' } else { $Pairs }), slots 1, baseline reuse OFF"
Write-Host "  code $sha, snapshot $snap (edits to this checkout cannot reach the run)"
Write-Host "  folder $RunDir"

$when = (Get-Date).AddSeconds(15)
if ($At) {
  $t = [datetime]::ParseExact($At, "HH:mm", $null)
  $when = (Get-Date).Date.AddHours($t.Hour).AddMinutes($t.Minute)
  if ($when -le (Get-Date)) { $when = $when.AddDays(1) }
}
$ps = (Get-Command powershell.exe).Source
$action = New-ScheduledTaskAction -Execute $ps -WorkingDirectory $repo -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Worker -RunDir `"$RunDir`"")
$trigger = New-ScheduledTaskTrigger -Once -At $when
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 24)
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
# PENDING until the worker starts: one still here after its time means the task never ran (logged off, asleep).
"scheduled for $(Get-Date $when -Format s); task $task" | Set-Content (Join-Path $RunDir "PENDING")
if ($At) {
  Write-Host "scheduled task '$task' will start at $when. Check $RunDir for a DONE or FAILED file afterwards."
} else {
  Start-ScheduledTask -TaskName $task
  Write-Host "scheduled task '$task' started. Check $RunDir for a DONE or FAILED file."
}

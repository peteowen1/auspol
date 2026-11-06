# SCHEDULED REBUILD: scripts/rebuild_forecasts.sh as a process that outlives the Claude Code session,
# started by a one-shot Windows Scheduled Task at a quiet hour, and only once enough memory is free.
# Pete, 2026-11-06: the 6 Nov rebuild ran at 2 harness slots (4 GB free, a kernel pool leak) and took
# ~3 h instead of ~1 h; run it when the machine is free instead.
#
#   powershell.exe -File scripts\scheduled_rebuild.ps1                 # tonight 02:00, wait for 8 GB
#   powershell.exe -File scripts\scheduled_rebuild.ps1 -At 23:30 -MinFreeGB 10 -Deadline 05:00
#   powershell.exe -File scripts\scheduled_rebuild.ps1 -Now -From 6    # start now, resume at stage 6
#
# Unlike deciding_run.ps1 it runs IN THIS CHECKOUT, not a snapshot: the rebuild's job is to write the real
# output/ (its 10 GB of inputs live there). So: uncommitted R/ scripts/ src/ refuse at launch AND at start,
# and nobody should edit scripts/ while it runs (bash reads rebuild_forecasts.sh as it goes). It never
# publishes: stage 9 stays a separate, deliberate step
# (AUSPOL_REBUILD_FROM=9 AUSPOL_PUBLISH=1 bash scripts/rebuild_forecasts.sh).
#
# Output in deciding-runs/<YYYYMMDD-HHMM>-rebuild/ (gitignored):
#   PENDING   scheduled, not started (still here after its time: the machine was logged off or asleep)
#   WAITING   started, waiting for -MinFreeGB (polls every minute until -Deadline, then runs anyway)
#   RUNNING   rebuilding; with no DONE/FAILED and no live pid in started.txt, it was killed
#   DONE / FAILED   written last: exit code, time, why
#   log.txt   everything the rebuild printed (utf8)   memory.txt  free memory when it decided to start
param(
  [string]$At = "02:00",
  [switch]$Now,
  [int]$MinFreeGB = 8,
  [string]$Deadline = "06:00",
  [int]$From = 1,
  [int]$Slots = 0,
  [switch]$Worker,
  [string]$RunDir = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
function Get-FreeGB { [math]::Floor((Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue / 1024) }
function Get-Dirty($r) { @(& git -C $r status --porcelain -- R scripts src DESCRIPTION NAMESPACE) }

if ($Worker) {
  $log = Join-Path $RunDir "log.txt"; $code = 1; $why = "worker failed before the rebuild started"
  try {
    $p = Get-Content (Join-Path $RunDir "params.json") -Raw | ConvertFrom-Json
    Remove-Item (Join-Path $RunDir "PENDING") -ErrorAction SilentlyContinue
    "waiting since $(Get-Date -Format s) for $($p.MinFreeGB) GB free, until $($p.DeadlineAt)" | Set-Content (Join-Path $RunDir "WAITING")
    $dl = [datetime]$p.DeadlineAt
    while ((Get-FreeGB) -lt $p.MinFreeGB -and (Get-Date) -lt $dl) { Start-Sleep -Seconds 60 }
    $free = Get-FreeGB
    "free $free GB at $(Get-Date -Format s) (wanted $($p.MinFreeGB); $(if ($free -ge $p.MinFreeGB) { 'met' } else { 'deadline reached, starting anyway' }))" | Set-Content (Join-Path $RunDir "memory.txt")
    Remove-Item (Join-Path $RunDir "WAITING") -ErrorAction SilentlyContinue
    Set-Location $p.Repo
    $dirty = Get-Dirty $p.Repo
    if ($dirty.Count) { $code = 3; throw "uncommitted changes appeared since launch; refusing to rebuild from a working tree that is not a commit:`n$($dirty -join "`n")" }
    $sha = (& git -C $p.Repo rev-parse --short HEAD).Trim()
    "worker pid $PID; started $(Get-Date -Format s); commit $sha (launched at $($p.Commit))" | Set-Content (Join-Path $RunDir "started.txt")
    "started $(Get-Date -Format s)" | Set-Content (Join-Path $RunDir "RUNNING")
    $env:AUSPOL_REBUILD_FROM = "$($p.From)"
    if ($p.Slots -gt 0) { $env:AUSPOL_REBUILD_SLOTS = "$($p.Slots)" }
    Remove-Item Env:\AUSPOL_PUBLISH -ErrorAction SilentlyContinue   # never publishes
    $ErrorActionPreference = "Continue"   # stderr lines are not failures
    & $p.Bash scripts/rebuild_forecasts.sh 2>&1 | ForEach-Object { "$_" } | Out-File $log -Encoding utf8
    $code = $LASTEXITCODE; $ErrorActionPreference = "Stop"
    $why = if ($code -eq 0) { "" } else { "rebuild_forecasts.sh exited $code" }
    if ($code -eq 0) { "exit 0 at $(Get-Date -Format s); commit $sha; free at start $free GB" | Set-Content (Join-Path $RunDir "DONE") }
  } catch {
    $why = "$why; $($_ | Out-String)"
    try { $why | Add-Content $log -Encoding utf8 } catch {}
  }
  if ($why) { "exit $code at $(Get-Date -Format s): $why (see log.txt)" | Set-Content (Join-Path $RunDir "FAILED") }
  Remove-Item (Join-Path $RunDir "RUNNING"), (Join-Path $RunDir "WAITING") -ErrorAction SilentlyContinue
  try { Unregister-ScheduledTask -TaskName $p.TaskName -Confirm:$false } catch {}
  exit $code
}

# ---- launcher ----------------------------------------------------------------
if ($From -lt 1 -or $From -gt 9) { throw "-From must be 1..9 (AUSPOL_REBUILD_FROM)" }
$dirty = Get-Dirty $repo
if ($dirty.Count) { throw "uncommitted changes in R/ scripts/ src/ DESCRIPTION NAMESPACE; commit first:`n$($dirty -join "`n")" }
$bash = "C:\Program Files\Git\bin\bash.exe"
if (-not (Test-Path $bash)) { throw "Git Bash not found at $bash" }
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$RunDir = Join-Path $repo "deciding-runs\$stamp-rebuild"
if (Test-Path $RunDir) { throw "$RunDir already exists" }
New-Item -ItemType Directory -Path $RunDir | Out-Null
$when = (Get-Date).AddSeconds(15)
if (-not $Now) {
  $t = [datetime]::ParseExact($At, "HH:mm", $null)
  $when = (Get-Date).Date.AddHours($t.Hour).AddMinutes($t.Minute)
  if ($when -le (Get-Date)) { $when = $when.AddDays(1) }
}
$d = [datetime]::ParseExact($Deadline, "HH:mm", $null)
$dl = $when.Date.AddHours($d.Hour).AddMinutes($d.Minute)
if ($dl -le $when) { $dl = $dl.AddDays(1) }
$sha = (& git -C $repo rev-parse --short HEAD).Trim()
$task = "auspol-rebuild-$stamp"
@{ Repo = $repo; Bash = $bash; From = $From; Slots = $Slots; MinFreeGB = $MinFreeGB; DeadlineAt = (Get-Date $dl -Format s);
   Commit = $sha; TaskName = $task; StartAt = (Get-Date $when -Format s) } | ConvertTo-Json | Set-Content (Join-Path $RunDir "params.json")
$ps = (Get-Command powershell.exe).Source
$action = New-ScheduledTaskAction -Execute $ps -WorkingDirectory $repo -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Worker -RunDir `"$RunDir`"")
$trigger = New-ScheduledTaskTrigger -Once -At $when
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 12)
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
"scheduled for $(Get-Date $when -Format s); task $task" | Set-Content (Join-Path $RunDir "PENDING")
Write-Host "rebuild from stage $From at commit ${sha}: starts $when once $MinFreeGB GB is free (runs anyway at $dl); never publishes"
Write-Host "  folder $RunDir"
if ($Now) { Start-ScheduledTask -TaskName $task }

# Stage 1 of docs/plans/prereg-class-specific-variance.md, one harness at a time.
# m_OTH is fixed at 1.00 throughout stage 1; only m_IND moves.
#
# Detached on purpose. Each arm is minutes and the whole grid is hours, and this
# session has already seen background R jobs killed externally mid-run.
param([string]$Harness = "sa")
$ErrorActionPreference = "Continue"
$env:AUSPOL_LEVEL_MULT_OTH = "1"
# 5000, not the harness default of 20000. Measured on South Australia against a
# 20000-sim run of the same arm and seed: mean change in pred_p 0.00186, change
# in log loss on the primary subset -0.0066, and the effect the criterion must
# detect is 1.171 -- so simulation noise is about 1/180th of the effect. Turns
# stage 1 from ~9 hours into ~2.4. Recorded in the pre-registration under "Run
# settings" before any arm was scored.
$env:AUSPOL_N_SIMS = "5000"
$log = "output/grid-$Harness.log"
"=== stage 1 grid, harness $Harness, started $(Get-Date -Format s) ===" | Out-File -FilePath $log -Encoding utf8
$grid = if ($env:AUSPOL_CV_GRID) { $env:AUSPOL_CV_GRID -split "," } else { @("1","1.25","1.5","1.75","2") }
foreach ($m in $grid) {
  $env:AUSPOL_LEVEL_MULT_IND = $m
  $t0 = Get-Date
  "--- m_IND = $m  started $(Get-Date -Format s) ---" | Out-File -FilePath $log -Append -Encoding utf8
  & Rscript "scripts/backtest_candidate_$Harness.R" 2>&1 |
    Select-String -Pattern "^(LV1|LV2|B[A-Z]?[0-9]|CAL|.*wrote )" |
    Out-File -FilePath $log -Append -Encoding utf8
  "--- m_IND = $m  done in $([int]((Get-Date) - $t0).TotalSeconds)s ---" |
    Out-File -FilePath $log -Append -Encoding utf8
}
"=== grid complete $(Get-Date -Format s) ===" | Out-File -FilePath $log -Append -Encoding utf8

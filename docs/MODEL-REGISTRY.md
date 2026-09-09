# Model registry

**Generated 2026-09-09 by `scripts/build_model_registry.R`. Do not hand-edit** --
rerun the script instead. Regenerate whenever a switch is added to
`published_flags.R` or a harness's wiring changes.

This exists because "now works in every harness" has been claimed and been
wrong twice (AUSPOL_SEED hardcoded in WA; AUSPOL_SEAT_SD_MULT never reaching
`fit_seats_full.R` at all), both found 2026-09-09 by checking every switch by
hand instead of trusting the prior claim. The table below is regenerated from
the actual scripts, not remembered.

`yes*` means the switch's NAME is present in the file (often only in a
disclosure comment explaining that it is NOT wired) but is not functional
wiring -- see the explained section below for which ones and why.

## What each entry point is

| entry point | what it is | jurisdiction |
|---|---|---|
| `fit_seats_full.R` | **the published forecast** -- the only script whose output is real | Victoria (live target) |
| `backtest_candidate_fed.R` | backtest harness | Federal |
| `backtest_candidate_nsw.R` | backtest harness | New South Wales |
| `backtest_candidate_qld.R` | backtest harness | Queensland |
| `backtest_candidate_sa.R` | backtest harness | South Australia |
| `backtest_candidate_vic.R` | backtest harness | Victoria |
| `backtest_candidate_wa.R` | backtest harness | Western Australia |

All seven share one `R/` package core (`simulate_seat_contests()`,
`reentry_prior.R`, `salience_surge.R`, etc.) -- differences between them are
in which switches each one WIRES and which data source each reads, not in
separate model code.

## Switch parity (37 switches from `published_flags.R`, 7 entry points)

| switch | fit_seats (published) | fed | nsw | qld | sa | vic | wa |
|---|---|---|---|---|---|---|---|
| `AUSPOL_COV_LOO` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_DEFECT_DISCOUNT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEFECT_POOLED` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_DEV_SLOPE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_DEV_SLOPE_MODE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FALLBACK_SMOOTH` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FIT_SLOPES` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FLOW_SD` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_FLOW_SHIFT` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FORCE_FP` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_FP_SD_MODE` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_IND_SALIENCE` | NO | yes | NO | NO | NO | NO | NO |
| `AUSPOL_INSURGENCY_SHRINK` | yes | yes | NO | NO | NO | NO | NO |
| `AUSPOL_LEVEL_MULT_IND` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_LEVEL_MULT_OTH` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_LEVEL_SD` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_MP_SLOPE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_N_SIMS` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_ONP_CV` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_ONP_FIX` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_ONP_ORDER` | yes | NO | NO | NO | NO | NO | NO |
| `AUSPOL_PARTY_COR` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_QLD_FLOWS` | yes | yes | NO | yes | yes | yes | NO |
| `AUSPOL_SALIENCE_EXP_SD` | NO | yes | yes | yes | yes | yes | NO |
| `AUSPOL_SALIENCE_EXPECTED` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_SALIENCE_SMOOTH` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SALIENCE_SURGE_V2` | yes | yes | yes | yes | yes | yes | yes* |
| `AUSPOL_SEAT_SD_MULT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SEED` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SHRINK` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SIM_ENGINE` | NO | NO | NO | NO | NO | NO | NO |
| `AUSPOL_SPLIT_SLOPE` | NO | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SURGE_FROM_ZERO` | yes | yes | yes | yes | yes | yes | NO |
| `AUSPOL_SURGE_H` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SURGE_RECIPIENT` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_SURGE_SCALE` | yes | yes | yes | yes | yes | yes | yes |
| `AUSPOL_WA_FLOWS` | yes | yes | NO | yes | yes | yes | NO |

## Every non-universal switch, explained

- **`AUSPOL_COV_LOO`** (intentional / dead experiment): Read inside R/statewide_cor.R, not per-harness -- universal in practice, absent from every harness script by design.
- **`AUSPOL_DEFECT_POOLED`** (intentional / dead experiment): ADOPTED 2026-09-09 at "2" (docs/plans/prereg-defector-two-rate- 2026-09-09.md), by Pete on mechanism -- the arm missed its own primary bar (t -2.04 vs 2.08) but every directional indicator was favourable and R4 confirmed the published Victorian forecast is byte-identical (Victoria fields no major-party defector standing as a minor this cycle, so the mechanism does not fire there). Reaches fit_seats_full.R correctly: personal_prior_vote() self-resolves both rates from Sys.getenv() when the caller passes NULL, exactly so this did not need a seventh call site wired by hand -- the mistake that made the first pooled-arm run VOID earlier the same day.
- **`AUSPOL_FIT_SLOPES`** (intentional / dead experiment): REFUSED 2026-09-09 (docs/plans/prereg-fit-conditional-slopes-2026-09-09.md): pooled log loss FAIL, panel FAIL, though it surfaced that the shipped OTH_RIGHT constants are wrong in opposite directions. Harness-only by design -- a refused, default-off experiment has no reason to reach fit_seats_full.R.
- **`AUSPOL_FLOW_SHIFT`** (intentional / dead experiment): Federal-forecast-only concept (shifts the statewide TPP fundamentals blend); backtests inject real historical first preferences directly and have no fundamentals blend to shift.
- **`AUSPOL_FORCE_FP`** (intentional / dead experiment): Federal-forecast-only (forces a first-preference override for the live forecast); no analogue in a backtest scored against real historical results.
- **`AUSPOL_FP_SD_MODE`** (intentional / dead experiment): Federal-forecast-only (first-preference spread mode for the live projection); backtests use realised historical first preferences, not a projected spread.
- **`AUSPOL_IND_SALIENCE`** (intentional / dead experiment): Deprecated experimental arm (the v1 national IND multiplier), superseded by the newer salience mechanisms; fed-only because that is the only harness it was ever tested in. Not adopted.
- **`AUSPOL_INSURGENCY_SHRINK`** (intentional / dead experiment): Per-seat shrink experiment, REFUSED 2026-09-06 (worse than the scalar shrink on 5 of 6 federal pairs) -- see docs/NEXT-STEPS.md. Fed/fit_seats-only because that is as far as the experiment got before being set aside. Not adopted.
- **`AUSPOL_ONP_CV`** (intentional / dead experiment): Federal-forecast-only (One Nation allocation coefficient of variation for the live projection).
- **`AUSPOL_ONP_FIX`** (intentional / dead experiment): Federal-forecast-only (One Nation allocation fix for the live projection).
- **`AUSPOL_ONP_ORDER`** (intentional / dead experiment): Federal-forecast-only (One Nation allocation ordering for the live projection).
- **`AUSPOL_PARTY_COR`** (intentional / dead experiment): WA deliberately excluded from the statewide party-correlation matrix -- cor(ALP, IND) flips sign there (docs/reviews/statewide-cov-loo-2026-09-07.md). Intentional, not a gap.
- **`AUSPOL_QLD_FLOWS`** (intentional / dead experiment): Self-referential no-op in the QLD harness itself ("use Queensland's own flows" is trivially true there) -- disclosed via its own `.inert` list. Genuinely absent from WA (uses AUSPOL_WA_FLOWS instead).
- **`AUSPOL_SALIENCE_EXP_SD`** (**OPEN GAP**): WA: same salience-corpus exclusion as AUSPOL_SALIENCE_EXPECTED, intentional. fit_seats_full.R: OPEN GAP, not fixed -- registered as published but sd_override is never wired into the forecast script at all (docs/reviews/pre-main-review-gate-2026-09-08.md). Currently harmless: this whole salience-variance arm is still pre-registered and undecided (docs/plans/prereg-salience-expected-and-variance-2026-09-07.md), so the switch is off everywhere. Wire it in the same commit that ships the arm, not before.
- **`AUSPOL_SALIENCE_EXPECTED`** (intentional / dead experiment): WA has no candidate-level salience corpus at all (the WA commission files carry surnames only, no salience-v6.csv rows) -- documented, intentional exclusion.
- **`AUSPOL_SALIENCE_SMOOTH`** (intentional / dead experiment): Read inside R/salience_surge.R, not per-harness -- universal in practice.
- **`AUSPOL_SALIENCE_SURGE_V2`** (**OPEN GAP**): WA: OPEN GAP, not fixed. Marked `yes*` above because the switch's name appears only in a disclosure comment explaining that it is NOT wired -- WA has no surge-v2 hazard at all where every other harness does (docs/NEXT-STEPS.md's own "Open" item 3, still unaddressed). A plain grep of the file would otherwise call this cell a clean "yes" and hide the gap.
- **`AUSPOL_SIM_ENGINE`** (intentional / dead experiment): Read inside R/seat_sim.R's simulate_seat_contests(), not per-harness -- universal in practice.
- **`AUSPOL_SPLIT_SLOPE`** (intentional / dead experiment): REFUSED 2026-09-09, and harmfully so (docs/plans/ prereg-partial-return-split-slope-2026-09-09.md): it discarded the existing conditional-slope system instead of refining it. Harness-only by design, same reasoning as AUSPOL_FIT_SLOPES.
- **`AUSPOL_SURGE_FROM_ZERO`** (intentional / dead experiment): WA has no candidate-level salience corpus -- same exclusion as AUSPOL_SALIENCE_EXPECTED, intentional.
- **`AUSPOL_WA_FLOWS`** (intentional / dead experiment): Self-referential no-op in the WA harness itself, same shape as AUSPOL_QLD_FLOWS above but not disclosed via an `.inert` list there. Genuinely absent from QLD (uses AUSPOL_QLD_FLOWS instead).

## Gaps the switch-presence matrix cannot see

A grep for a switch's name proves the name is mentioned, not that the
VALUE it's set to is fully honoured. Hand-maintained because there is no
mechanical test for "is this harness doing the whole thing the switch
asks for":

- **`AUSPOL_DEV_SLOPE_MODE=screened` is only half-honoured in WA.** The
  switch functionally reads and WA does apply the conditional-slopes
  half; it has no `salience_permit_for()`/`screened_slopes()` wiring at
  all, so the salience-screen half of "screened" never fires there.
  Disclosed at runtime (`BW1c!`) since 2026-09-08. Open, not fixed --
  see `docs/NEXT-STEPS.md`.

## Fixed this session (2026-09-08/09), for history

- WA's `SEED` was a hardcoded literal (`20260825L`), ignoring
  `AUSPOL_SEED` entirely -- every WA run before 2026-09-09 used one fixed
  seed regardless of the env var. Fixed; WA's *default* seed (20260825)
  still differs from the other five harnesses' (42), unchanged on
  purpose so nothing already published moved silently.
- `AUSPOL_SEAT_SD_MULT`, `AUSPOL_FALLBACK_SMOOTH` and `AUSPOL_FLOW_SD`
  were registered in `published_flags.R` and honoured by all six
  backtest harnesses, but never wired into `fit_seats_full.R` at all.
  Fixed 2026-09-09; harmless while shipped at their no-op defaults.

## Coverage check

MR2  every non-universal switch (21 of 37) has a recorded classification.

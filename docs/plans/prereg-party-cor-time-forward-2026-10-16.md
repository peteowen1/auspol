# Pre-registration: does the statewide party correlation earn its place? (2026-10-16)

Committed BEFORE any arm below is run. Pete, 16 Oct: wanted the time-forward matrix to
"shrink toward the average of earlier elections"; that collapses into the built design
(the time-forward sample IS the earlier elections), so he delegated the call ("i trust
your recommendations").

## What is decided already

The shipped matrix leaks: `statewide_cor()` with `AUSPOL_COV_LOO=1` leaves out only the
target, so it trains on LATER elections (nsw2019's cor(ONP, LNP) comes mostly from sa2026).
**The leave-one-out matrix goes regardless.** This decides only what replaces it.

## Why the question is "does it help at all", not "how to shrink it"

Dry run, 16 Oct, before any scoring (scratchpad `covwide.R`, `covflip.R`):

- Widening the fit from 15 to 25 non-WA pairs (adding vic2010, nsw2011/15, sa2010/14/18/22,
  qld2012/15/17, shares from `output/candidacies.csv`) flips **six** party-pair signs,
  including cor(ALP, IND) +0.43 -> -0.12, the exact flip whose refusal clause killed the
  2026-09-07 widening with WA (`scripts/estimate_statewide_cov.R:88`). That clause applies
  here unchanged, so **widening is refused** and is not an arm.
- No single added pair drives the flip: dropping any one leaves cor(ALP, IND) in
  [-0.22, +0.03]. The +0.43 was itself a property of which 15 pairs were in.
- The corpus reproduces the existing 15 rows within 0.54 points except vic2014 (1.38).

Correlations whose signs depend on the sample are close to noise at n = 15-25, so the
arm that must beat the time-forward matrix is **no correlation at all**.

## Arms

All at `AUSPOL_COV_TF` and `AUSPOL_PARTY_COR` as below; everything else as published.

| Arm | Switches | Rule |
|---|---|---|
| L (shipped, leaks) | `AUSPOL_PARTY_COR=shrunk`, `AUSPOL_COV_TF=0` | leave-one-out. Reported only. |
| I | `AUSPOL_PARTY_COR=off` | independent statewide draws. |
| T | `AUSPOL_PARTY_COR=shrunk`, `AUSPOL_COV_TF=1` | time-forward, 15 pairs, `w = 0.5 n / (n + 5)`, identity below 3 earlier pairs (built, `R/statewide_cor.R`). |

Prerequisite (a bug, fixed in the same branch before running): the nsw/vic/qld/sa harnesses
treated `AUSPOL_PARTY_COR=off` as ON (any non-empty value called `statewide_cor()`); only
`fit_seats_full.R:1469` honoured "off". `output/statewide-cov.rds` (19 Sep) is rebuilt so it
carries `by_target_tf`.

## Criterion

The matrix reaches the vic, nsw, qld and sa harnesses only (fed draws in forecast mode
ignore it; WA and NT are out). So the 18 elections it touches: vic2010/14/18/22,
nsw2011/15/19/23, qld2012/15/17/20/24, sa2010/14/18/22/26.

1. **Primary, T vs I, on those 18 elections:** pooled seat log loss, SE clustered on
   election. T ships if lower by more than 1 SE; otherwise **I** (fewer moving parts, and
   nothing in it can flip sign with the sample).
2. **Guard, all 35:** the winner must not be worse than the other by more than 1 SE.
3. **Reported:** L minus winner (what the leak was worth), per election; share RMSE.

Screened first with `scripts/quick_arm.R --pairs=<the 18>` at 1,000 sims (I vs T, then L vs
I). A correlation acts in the joint tails, which a 1,000-sim screen floors at 5e-4, so the
**deciding run is 20,000 sims** (`deciding_run.ps1`) whatever the screen says.

## What would make an apparent win unacceptable (decided now)

- **One election:** more than half of the winner's primary gain from a single election ->
  refused, the other arm ships.
- **T wins only through One Nation:** if T's gain is all in sa2026/qld2017/qld2020 (the
  elections that give the ONP column any variance), it is refused: V3 of
  `prereg-statewide-covariance.md` says that column rests on one or two elections.
- **Live moves:** if I or T moves any party's vic2026 seat median by more than 2, stop and
  report (a correlation should change the spread, not the centre).

## What this cannot see

- Whether the original adoption of the correlation was measured against a working "off"
  arm in the harnesses. Not checked here; reported if the I arm surprises.
- Non-linear co-movement (ONP's first points from the Coalition, later ones from Labor).

# Pre-registration: NSW exhaustion in the simulation plus OPV-basis anchoring (2026-11-07)

Pete's goal (7 Nov): two-candidate-preferred (TCP) mean absolute error below AEF's on AEF-7
(ours 3.68, AEF 3.63 on the ledger's own seat sets). Research and the reasoning for this arm:
`docs/reviews/tcp-mae-vs-aef-2026-11-07.md`. Committed BEFORE any arm run.

**What the change does, in plain words.** NSW lets voters stop numbering boxes (optional
preferential voting), so many minor-party votes never reach either finalist. The published
model treats NSW like a full-preference state, which makes its NSW final-two margins too
narrow: the real margins are 1.41 times ours. `AUSPOL_NSW_EXHAUST=1` lets those votes exhaust
inside the seat simulation; `AUSPOL_ANCHOR_EXHAUST=1` makes the statewide two-party anchoring
use the same exhausted basis. Both switches exist and are off (`scripts/published_flags.R`).

**Arm:** `AUSPOL_NSW_EXHAUST=1 AUSPOL_ANCHOR_EXHAUST=1` against the published configuration.
Pairs: nsw2019 and nsw2023. Every other pair must be byte-identical.

## Metrics

TCP error is scored from the harness's own `backtest-<pair>-ourtcp*.csv`: per seat, our
predicted final two is the most frequent simulated pair (`freq`), and our TCP is that pair's
`f1_tcp_pct`, oriented to the real winner's side. A seat is scored only where that pair equals
the real final two at class level. Real final twos: nsw2023 from
`output/aef7-final-two-and-tcp-reference.csv`; nsw2019 from `output/nsw2019-tcp-official.csv`
(`scripts/build_nsw2019_tcp_official.R`, NSWEC's own pages, 93 of 93 seats, built today).

1. **Primary (decides):** nsw2023 TCP MAE on seats where the baseline's, the arm's and AEF's
   final two all match the real one. Pass: the change is negative and at least 1 SE from
   zero (SE of the mean per-seat paired difference, seats as the unit). Seat-set changes are
   reported.
2. **Second:** nsw2019 TCP MAE on seats where both baseline and arm match the real final two.
   Reported; it decides only through guard 1 and guard 4 below.

## Guards (refuse even if the primary passes)

1. Seat log loss on nsw2019 or nsw2023 worse by more than 1 SE (clustered on seat), on either.
2. TCP MAE on marginal seats (baseline predicted margin under 6 points) worse on either pair.
3. Any non-NSW pair not byte-identical.
4. Mean absolute ALP primary miss on nsw2019 above 1.547 (the refused 2026-09-27 anchoring arm).

## Predicted result, written before running

nsw2023 ALP v LNP TCP MAE 5.06 to about 4.5; slope of actual on predicted ALP TCP 1.41 to
about 1.27; 0-4 favourite flips in nsw2023. nsw2019: unknown sign; the earlier anchoring-only
arm hurt it.

## Procedure

1. Screen: `Rscript scripts/quick_arm.R "AUSPOL_NSW_EXHAUST=1 AUSPOL_ANCHOR_EXHAUST=1"
   --pairs=nsw2019,nsw2023` (default sims). A WORSE on any guard stops it here.
2. If it passes: the deciding run at 20,000 sims via `scripts/deciding_run.ps1`, all 22, with
   the same criteria. Only that run can ship it, and shipping goes to Pete with the split.

## RESULT

(not yet run)

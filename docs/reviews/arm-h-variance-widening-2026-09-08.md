# Arm H (flat-ratio variance widening): run and refused

2026-09-08. `docs/plans/prereg-reentry-flatratio-variance-2026-09-08.md`.
Status header: **REFUSED by its own pre-registered rule.** `AUSPOL_REENTRY_SD_K`
stays 0.

## Dry-run (before any grid)

All four named dry-run cases passed clean:

1. `k_sd=0` is an exact no-op by construction — `reentry_sd_matrix()` returns
   an all-NA matrix whenever `k_sd` is not `> 0`, so `sd_override` is never
   built and the `sd_override` branch in `simulate_seat_contests()` is
   unreachable. Confirmed by the 25 assertions in `test-reentry-sd.R`
   (0 failures) and by an end-to-end WA run: k_sd=0 pooled log loss 0.3973,
   exactly matching the previously recorded arm-D value.
2. WA's new `sd_override` plumbing is a no-op at `k_sd=0` by code inspection
   — `SD_OVR` is declared `NULL` fresh per pair in
   `backtest_candidate_wa.R:461` and only built when `.reentry_sd_k > 0`.
3. Evidence-weighted bump confirmed: GRN (n≈29) gets a small `extra_sd`,
   ALP/LNP-shaped low-n cells get a large one, per `k_sd/sqrt(n)`.
4. GLM-path cells and untouched seats stay `NA` regardless of `k_sd`.

## The grid

Ran on WA alone (5 of 6 named test cells are WA's) at 5,000 sims,
`AUSPOL_REENTRY_SD_K ∈ {0,2,5,10,20}`:

| k_sd | WA pooled log loss |
|--:|--:|
| 0 (= arm D) | 0.3973 |
| 2 | 0.3972 |
| 5 | 0.3973 |
| 10 | 0.3826 |
| 20 | 0.3790 |

k=20 looks like a real win — until the five named cells are checked
individually:

| seat | prior prob | k=20 prob | verdict |
|---|--:|--:|---|
| Alfred Cove wa2005 | 0.0000 | 0.0008 | "improved" |
| Armadale wa2005 | 0.8746 | 0.7484 | worse |
| Churchlands wa2001 | 0.9954 | 0.9934 | worse |
| Churchlands wa2013 | 0.9870 | 0.9238 | worse |
| Kimberley wa2001 | 0.5142 | 0.4912 | worse |

**Four of five named cells get worse.** The entire pooled WA gain is more
than fully explained by Alfred Cove alone crossing the `eps=1e-6` log-loss
floor (delta −6.68, against a total WA-wide sum delta of −6.61 across all
361 seats) — every other seat across all 7 WA pairs combined got slightly
worse on net.

## Verdict

This is the plan's own refusal condition #2, verbatim: "the gain is
entirely a wider-tail-catches-the-winner-by-luck effect on ONE of the six
named cells, with the other five unchanged or worse." k=2 and k=5 show
almost no effect (0.3972, 0.3973) — the jump appears only once `k_sd`
crosses somewhere between 5 and 10, the signature of a discrete
floor-crossing artifact rather than a smooth uncertainty correction —
exactly the `eps`-floor-mechanics hazard this repo has hit before (vic2014,
Barwon).

**REFUSED. No need to run the full 22-pair grid** — WA alone already trips a
named refusal condition.

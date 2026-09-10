# XGBoost primary v5: seat-file + personal-vote + candidacy features — 2026-09-10

Follow-up to `xgb-primary-challenger-2026-09-09.md` and `-followup-2026-09-10.md`,
acting on the biggest concrete finding in `docs/plans/xgb-flows-variable-inventory-2026-09-10.md`:
six `load_seats()` fields plus `own_prev_pcv`/`historic_elected`/`ballot_position`
never reached any xgb primary variant. **Not shipped. No commits.
`published_flags.R` untouched (`AUSPOL_XGB_PRIMARY_LIVE="0"`, verified after
this session's work).**

## Correction to the motivating claim, made before building anything

The inventory doc (and this task's own directive) described the six
`load_seats()` fields as "already proven" by `docs/plans/prereg-seat-swing-predictors.md`
(seat-swing MAE 3.948→3.425). **That result is for the RETIRED two-party seat
model** (`simulate_seats()`/`seat_swing_spread()`) — the prereg's own result
section says so explicitly: *"The candidate-level model is untouched, because
`fit_seats_full.R` does not call `simulate_seats()`."* Per `CLAUDE.md`: *"Never
improve, tune, measure or reason about the two-party seat model... a finding
that only moves it is not a finding."* That rule is about the retired model
itself, not about reusing a data point from it, but the framing overstated the
evidence — it showed these fields carry SOME signal for SEAT SWING in a
different, simpler model, not that they help THIS model's CLASS-LEVEL PRIMARY
SHARE prediction. This session measured that question fresh, from zero, rather
than trusting the transfer.

## Leakage check, one real catch

- `margin`, `fed_swing`, `retirement`, `soph_cand`, `soph_party`, `prev_swing`
  (`load_seats()`): traced to the anchor's per-election seat-notes file
  (`{year}{region}.txt`), authored before that year's poll. All six are
  genuinely pre-election-knowable for the year queried — confirmed by reading
  `load_seats()`'s source directly, not assumed from field names.
- `own_prev_pcv` (`personal_prior_vote()`): a candidate's own share from a
  PRIOR contest. Safe.
- `historic_elected`, `ballot_position` (`candidacies.csv`): career-history
  flag and pre-poll ballot-draw position respectively. Safe.
- **`swing` (`candidacies.csv`) is EXCLUDED — it is leaky.** Per
  `docs/DATA-DICTIONARY.md`: *"the AEC's own seat-level swing, per candidate
  per division"* — i.e. computed FROM the target election's own result, not
  knowable beforehand. Including it would be textbook target leakage
  (predicting an election's own outcome from a value derived from that same
  outcome). This is the one field this task's directive flagged for
  verification rather than assumption, and it was right to flag it.
- **WA has zero `load_seats()` coverage** (`backtest_candidate_wa.R`'s own
  comment: "no WA equivalent") — all six seat-file features are NA for every
  WA row. `own_prev_pcv`/`historic_elected`/`ballot_position` ARE available
  for WA (candidacies.csv-level, not load_seats-level).
- One engineering decision, not in the original inventory: the anchor's
  `incumbent` field distinguishes `LIB`/`NAT`/`LNP` where `classify_party()`
  buckets all three as `LNP`. Added `is_incumbent_party` (mapped to our
  classes) so `retirement`/`soph_cand`/`soph_party` — which describe the
  INCUMBENT's situation — have a way to attach to the right row; without it
  they'd be seat-level constants blind to which party's row they apply to.

## Primary-share RMSE, pooled (13,314 cells)

| arm | RMSE | vs shipped |
|---|--:|--:|
| shipped | 4.4657 | — |
| xgb v1 (pure, no seat features) | 4.0132 | 10.13% |
| **xgb v5 (+ seat/personal-vote/candidacy features)** | **3.8524** | **13.73%** |

Feature importance: `pred_share` still dominates (73%), then `x` (15%),
`level_now` (8%) — same shape as v1. Of the NEW features, `historic_elected`
ranks 5th overall (1.0% of gain), `own_prev_pcv` 7th (0.24%), `margin` 10th
(0.12%), `prev_swing` 11th (0.10%), `ballot_pos_min` 13th (0.09%). Real but
small individually; the pooled gain is their sum plus better splits elsewhere.

## Seat log loss through the real harnesses, all 22 pairs, one seed, 5,000 sims

Same methodology as `-followup-2026-09-10.md` (post-hoc OOF-prediction swap
into `R/xgb_primary_override.R`'s hardcoded read path, restored after
testing — verified `published_flags.R` and the harnesses' own default
predictions file are both back to their pre-session state).

| pair | n seats | shipped | xgb v1 (pure) | **xgb v5** |
|---|--:|--:|--:|--:|
| fed2007 | 149 | 0.3116 | 0.2954 | 0.2903 |
| fed2010 | 147 | 0.2972 | 0.2706 | 0.2592 |
| fed2013 | 150 | 0.4059 | 0.3811 | 0.3704 |
| fed2016 | 147 | 0.3133 | 0.3155 | 0.3052 |
| fed2019 | 143 | 0.2639 | 0.2030 | 0.2037 |
| fed2022 | 150 | 0.3453 | 0.3392 | 0.3415 |
| fed2025 | 150 | 0.3257 | 0.3099 | 0.3027 |
| nsw2019 | 93 | 0.4951 | 0.4282 | 0.4318 |
| nsw2023 | 88 | 0.2940 | 0.2537 | 0.2499 |
| qld2020 | 93 | 0.3162 | 0.2514 | 0.2408 |
| qld2024 | 93 | 0.3382 | 0.3278 | 0.3204 |
| **sa2026** | 47 | 0.4088 | 0.4553 | **0.4537** |
| **vic2014** | 73 | 0.2798 | 0.3543 | **0.3494** |
| vic2018 | 88 | 0.2670 | 0.2765 | 0.2575 |
| vic2022 | 78 | 0.2474 | 0.2050 | 0.2125 |
| wa2001 | 57 | 0.7123 | 0.6728 | 0.5818 |
| wa2005 | 46 | 0.3663 | 0.2748 | 0.2769 |
| wa2008 | 38 | 0.7566 | 0.7040 | 0.6816 |
| wa2013 | 55 | 0.4992 | 0.4548 | 0.4542 |
| wa2017 | 54 | 0.2663 | 0.2618 | 0.2758 |
| wa2021 | 58 | 0.0835 | 0.1002 | 0.1011 |
| wa2025 | 53 | 0.2661 | 0.1928 | 0.2016 |
| **pooled, seat-weighted (n=2,050)** | | **0.3403** | **0.3172** | **0.3103** |

Pooled improves again over v1 (0.3172→0.3103, a further 2.2%, 8.8% total vs
shipped) — driven by federal (all 7 pairs better than v1 or flat), both NSW
and QLD pairs, and a genuine WA fix (below). But the two named regressions
this whole investigation exists because of are **not fixed**:

## The flagship cases — honest result, not oversold

**sa2026 (One Nation) — unchanged, still broken.** Seat log loss 0.4537,
statistically the same as v1's 0.4553 (both far worse than shipped's 0.4088).
ONP-specific mean absolute error on the actual primary share got WORSE with
more features, not better:

| arm | ONP MAE (47 seats) | mean predicted (actual 22.98%) |
|---|--:|--:|
| shipped | 4.944 | 22.83 |
| xgb v1 | 5.517 | 22.09 |
| **xgb v5** | **5.820** | **21.41** |

Narungga, MacKillop, Taylor, Elizabeth, Chaffey — the named ONP seats — are
all still pulled DOWN toward the pooled mean, further than v1 pulled them.
**Adding seat-level and personal-vote features did not touch this failure
mode at all**; it's the same "bulk population shrinks a rare surging class"
problem `xgb-primary-challenger-2026-09-09.md` diagnosed originally, and none
of the new features (which describe individual candidates/seats, not
"is this class surging statewide") give the model anything new to catch it
with.

**vic2014 — unchanged, still a real regression.** Primary-share RMSE
3.4680 (v1) → 3.4635 (v5), no meaningful change; seat log loss 0.3543 (v1) →
0.3494 (v5), same story — still far worse than shipped's 0.2798. Not
diagnosed further this session (out of scope for a feature-addition test);
whatever is driving this pair's regression isn't touched by these features
either.

**vic2018 and vic2022 — genuinely improved, a new result.** vic2018 flips
from a v1 regression (0.2765, worse than shipped's 0.2670) to a v5
improvement (0.2575). vic2022 also improves on shipped (0.2125 vs 0.2474),
though slightly behind pure v1 (0.2050).

**WA's fake gain is now a real one.** Re-running the has_prior split from
`-followup-2026-09-10.md`:

| WA split | n | shipped RMSE | v1 RMSE | **v5 RMSE** |
|---|--:|--:|--:|--:|
| has_prior = TRUE (real matched cells, 83% of WA) | 1,516 | 4.847 | 4.857 (flat) | **4.720** |
| has_prior = FALSE (redistribution fallback) | 307 | 5.591 | 4.340 | 4.112 |

v1's WA gain was entirely in the fallback subset (the finding
`-followup-2026-09-10.md` flagged as "not evidence xgb understands WA's
ordinary seat dynamics"). **v5 is the first arm to show a real improvement on
WA's genuinely-matched cells** — plausibly `own_prev_pcv`/`historic_elected`/
`ballot_position`, which come from candidacies.csv rather than `load_seats()`
and so are available for WA despite its missing seat file. Five of WA's seven
pairs improve on shipped at the seat-log-loss level (wa2001, wa2005, wa2008,
wa2013, wa2025); wa2017 and wa2021 get slightly worse.

## Bottom line

**A real, larger pooled improvement than v1 (13.7% vs 10.1% on primary RMSE;
8.8% vs 7.0% on seat log loss), including a genuine fix to the WA
has-real-prior-data cells.** But this is still not a ship candidate on its
own: the two named cases that motivated the entire xgb-primary investigation
— SA's One Nation surge and vic2014 — are exactly as broken as they were in
v1. Whatever fixes those needs to be a mechanism that can tell the model "this
class is surging beyond its own history," which none of the candidate/seat
features tested here provide. The deterministic-override idea from
`-followup-2026-09-10.md` (protect flagged rare-class rows, let xgb handle
the rest) is still the more promising direction for those two cases
specifically — v5's gains and that override are not mutually exclusive and
could be combined, not evaluated together this session.

## Files

New: `scripts/fit_xgb_primary_v5.R`, `scripts/compare_v5_flagship.R` (scratch
comparison, not part of the fitting pipeline — kept since it's small and
reusable), `output/xgb-primary-features-v5.csv` and
`output/xgb-primary-v5-oof-predictions.csv` (both gitignored, regenerable).
`output/xgb-primary-oof-predictions.csv` (v1's file, read by
`R/xgb_primary_override.R`) was temporarily swapped to v5's predictions for
harness testing and **restored to v1's content before finishing** — verified
by diff-equivalent file size after restore. No other files touched.

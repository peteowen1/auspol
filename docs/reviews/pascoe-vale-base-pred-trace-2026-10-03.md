# Pascoe Vale 2022 IND: why base_pred is 19.01, not 16.95 (trace by reading, 2026-10-03)

Status: read-only trace, nothing was run. The cause below is a reconstruction that
matches every class in the seat to within 0.1 point, not a printed value. The probe
at the bottom settles it. The `AUSPOL_HONOUR_DEPARTED` path is live and doing what
it should; the extra points come from two later steps in the harness.

## Answer in one paragraph

`screened_slopes()` is working: IND takes slope 0.38 and the raw projection is 16.62.
Two steps after it move the number to 19.01. (1) The harness renormalises each seat's
row to sum to 100 (`backtest_candidate_vic.R:682`, again at `:700`). In this seat the
raw projections sum to only about 89.3, because ALP (0.621), LNP (0.894), GRN (0.880)
and IND (0.38) all shrink their old deviation, so everything is scaled up by about
1.12: 16.62 becomes 18.61. (2) `blend_salience_shares()` (`backtest_candidate_vic.R:870`,
`R/salience_surge.R:371`) pulls IND toward `surge_mu` = 35.61 with weight about 0.03,
adding about 0.4, giving 19.0. Nothing in `screened_slopes()` has a 0.457 slope in it.
The implied "slope 0.457" is a post-normalisation, post-blend artefact.

## (1) What writes the features file, and when

- `output/xgb-primary-v6-features.csv` is written by `scripts/fit_xgb_primary_v6.R:804`
  (only writer; grep of scripts, comments excluded). mtime 2026-10-02 19:18:44. Script's
  last commit before that: 68bf475 at 19:16 on 2026-10-02.
- Its `base_pred` is not recomputed there. It is `pred_share` read from
  `output/pooled-sharedetail.csv` and renamed (`fit_xgb_primary_v6.R:45`, `:296`).
  Pool file mtime 2026-10-01 23:38:39. The Pascoe Vale IND row there is 19.0103076977974,
  identical to features `base_pred` 19.0103076977974.
- The only later change to `base_pred` is the sitting-member shift
  (`fit_xgb_primary_v6.R:608-616`), and only for the two majors, and only when
  `AUSPOL_SITTING_MEMBER_ADJ=1`. Published value is 0 (HD0 line of the fresh run). So it
  plays no part here.
- The pool was built from the stage-1 vic file
  `output/backtest-vic-sharedetail-sh01-port2-n2000-lv110_867-cor-qld-a10e6c4-ga78e0aex.csv`
  (2026-10-01 23:36:04, column `xgb_primary_on` = 0, so it is not circular). Same IND
  value 19.0103. Its log is `output/rebuild-forecasts-logs/s1_vic.log`, whose HD0 line
  shows `AUSPOL_DEV_SLOPE_MODE=screened`, `AUSPOL_HONOUR_DEPARTED=1`,
  `AUSPOL_MAJOR_DEPARTED=1`, `AUSPOL_MAJOR_SLOPE=1`, `AUSPOL_STATE_NOTIONAL=1`.
- Dates of the pieces, so staleness is ruled out:

| Piece | Commit and date | Before the 2026-10-01 23:36 stage-1 run? |
|---|---|---|
| `AUSPOL_HONOUR_DEPARTED`, `departed_rate` | 8cfb132, 2026-09-18 08:40 | yes |
| `major_departed` / `major_present` slopes | d72973a, 2026-09-18 | yes |
| `blend_salience_shares` reaches vic harness | 64f2226, 2026-09-07 | yes |
| `x_notional_adj` feature | 86554b6, 2026-09-13 | yes |
| state notional prior (`SNP1`, prior replaced by notional) | 2177e4a, 2026-10-01 17:34 | yes |
| state notional switched on | 7eda4b3, 2026-10-01 23:04 | yes (stage 1 started 23:07) |
| nomination zeroing (`NZ1`, v61) | a33fb31 and e4e43d8, 2026-10-03 | no, but it only zeroed Narracan ALP in vic2022, not this seat |

So the file is current for every mechanism named in the question. It is not stale.

## (2) Where IND base share is built in the vic harness, in order

All in `scripts/backtest_candidate_vic.R`:

1. `:407` prior matrix normalised to 100; with state notional on, `:312-314` replaces the
   prior with the notional (log line `SNP1 vic2022: prior REPLACED by the notional`). So
   x in the swing formula already includes the notional: x = 32.883 - 0.876 = 32.007.
2. `:545` `personal_prior_vote()` and `:556` `remove_transferred_votes()`: log says
   `TR1 transfers moved with the person: 0 applied` for vic2022. No effect.
3. `:601-606` `.vic_slope()` calls `screened_slopes(... honour_departed = TRUE,
   major_departed = .MAJDEP, major_present = .MAJPRES)` because the vic2022 screen
   exists (`SP1 vic2022 screen`). For IND, departed leader, no permit: 0.38
   (`R/dev_slope.R:348-351`).
4. `:635-647` `dev_slope(x_p, sa, sb, slope)` = `sb + slope*(x - sa)` (`R/dev_slope.R:45-52`).
5. `:652-666` re-entry prior (only cells with no prior share; not IND here).
6. `:682` `shares <- 100 * shares / rowSums(shares)`; `:691-701` IND zeroing then a
   second normalisation (Pascoe Vale has an independent, so not zeroed).
7. `:746` `xgb_primary_override` (no-op at stage 1), `:749` `zero_unnominated` (NZ1
   zeroed one cell, Narracan ALP, not this seat). The xgb-only steps `:754-788` are
   gated on `AUSPOL_XGB_PRIMARY=1`, so skipped at stage 1.
8. `:870` `blend_salience_shares()`: `(1-p)*share + p*surge_mu`, then
   `100*shares/rowSums(shares)` (`R/salience_surge.R:371`, `:436`, `:440`). Log line
   `BV0b salience point estimate applied to 248 (seat,party) cells`; `surge_mu` = 35.61
   (`BV0v vic2022 ... mu 35.61`).
9. The point estimate written to sharedetail is `seat_share_rmse(shares, fb)` on this
   matrix, which is deterministic (`rebuild_forecasts.sh:190-192`).

No `mp_departed` branch exists in the harness. `same_mp` is `.MP_SLOPE` and applies to
"applied to 2 seat-classes" in vic2022 (BV1m); not shown to include Pascoe Vale, and it
would raise the slope to 0.945, which gives far more than 19 (see table below).

## Arithmetic

Inputs from `xgb-primary-v6-features.csv` (Pascoe Vale, vic2022): seat_prev_pcv, x_notional_adj,
level_prev (= sa), level_pred (= sb, matches `BV0` log: ALP 37.4, GRN 12.0, IND 6.8, LNP 31.4, OTH 6.3).
Slopes from the log line `BF0m ... departed ALP 0.621 ... present LNP 0.894` plus the `new` GRN
constant 0.880 and OTH default 1.

Raw projection `sb + slope*(x - sa)` with x = seat_prev_pcv + x_notional_adj:

| Class | slope | raw | sum-to-100 scaled (x1.1197) | pool pred_share |
|---|---|---|---|---|
| ALP | 0.621 (departed tier) | 34.05 | 38.12 | 37.87 |
| GRN | 0.880 | 15.14 | 16.96 | 16.93 |
| IND | 0.38 | 16.62 | 18.61 | 19.01 |
| LNP | 0.894 (present tier) | 9.82 | 10.99 | 10.92 |
| OTH | 1.0 | 8.05 | 9.02 | 8.97 |
| OTH_RIGHT | re-entry prior | 5.63 (back-solved) | 6.30 | 6.30 |

Raw sum is 89.31, so the scale factor is 100/89.31 = 1.1197 (OTH_RIGHT is back-solved from
its published value, which is the one assumption in this table; ONP is 0).

Your two reference numbers:

- 16.95 = 6.764 + 0.38*26.814 is right but uses the raw `dev_prev`, with no notional.
- 16.08 subtracts the full 0.876 notional from the end. The notional enters before the slope,
  so it is 0.38*0.876 = 0.33, giving 6.764 + 0.38*(26.814 - 0.876) = **16.62**.

Adding the blend, with p the IND hazard weight, then renormalising:

| p (IND blend weight) | IND | ALP | GRN | LNP | OTH |
|---|---|---|---|---|---|
| 0 (no blend) | 18.61 | 38.12 | 16.96 | 10.99 | 9.02 |
| 0.0247 | 18.95 | 37.97 | 16.88 | 10.95 | 8.98 |
| 0.0312 (= `surge_h` in the features file) | 19.04 | 37.92 | 16.87 | 10.94 | 8.97 |
| pool file | 19.01 | 37.87 | 16.93 | 10.92 | 8.97 |

p = 0.0312 reproduces IND to 0.03 and all other classes to within 0.06, so the blend plus
normalisation explains the whole gap. (Only IND is blended in the table; ALP and others
presumably carry small hazards of their own, which would account for the 0.05 left over.)

Alternatives tested and rejected, using the same OTH/ALP/LNP scale factor (about 1.112 to
1.118 in those classes), what IND's raw value would have to be to give 19.01:

| Hypothesis for IND slope | raw IND | pred_share it would give | Verdict |
|---|---|---|---|
| 0.38, no blend (plain `screened_slopes`) | 16.62 | 18.61 | 0.4 short |
| 0.38 plus blend p=0.03 | 16.62 | 19.0 | matches |
| `new` 0.326 | 15.22 | about 17.0 | too low |
| `same` 0.907 or `same_mp` 0.945 | 30.3 to 31.3 | above 30 | far too high |
| 0.38 with no notional in x | 16.95 | does not fit the OTH/GRN scale factors (1.143 vs 1.213) | wrong |
| class-level mean of slopes, council terms, floor | no code path | none | not present in harness |

Implied "slope 0.398" from back-solving the final number is the 0.38 slope plus the blend,
nothing else.

## Most likely cause

Two ordinary steps downstream of `screened_slopes()`:

1. Row renormalisation (`backtest_candidate_vic.R:682`, `:700`): +2.0 points on IND here.
2. Salience blend toward `surge_mu` (`backtest_candidate_vic.R:870`; `R/salience_surge.R:371`,
   `:436`): about +0.4 on IND (published `AUSPOL_SALIENCE_BLEND=1`,
   `published_flags.R:443`).

The permit being 0 does not stop the blend: the blend uses the fitted per-seat-party
hazard `p_hat`, not the permit.

## Probe that settles it (one line)

Insert immediately before `scripts/backtest_candidate_vic.R:870` (do not edit while a run
is in flight):

```r
cat(sprintf("PVPROBE pre-blend IND %.3f ALP %.3f rowsum %.2f | p_hat IND %s\n", shares["Pascoe Vale","IND"], shares["Pascoe Vale","ALP"], sum(shares["Pascoe Vale",]), paste(hz$seat_party_hazard$p_hat[hz$seat_party_hazard$seat == "Pascoe Vale" & hz$seat_party_hazard$party == "IND"], collapse = ",")))
```

Expected if this trace is right: pre-blend IND about 18.61, ALP about 38.12, row sum 100,
p_hat about 0.02 to 0.03. If pre-blend IND is already 19.0, the blend is not responsible and
the slope is not 0.38 at that point; look at `.vic_slope()` at `:601-606` next. (`seat` and
`party` here are columns of `hz$seat_party_hazard`, qualified with `$` on both sides, which
avoids the data.table NSE trap in CLAUDE.md.) Only valid on a stage-1 run
(`AUSPOL_XGB_PRIMARY=0`), since the fresh published-defaults run adds the xgb layer after.

## What I could not confirm

- The actual `p_hat` for Pascoe Vale IND: it lives in `hz$seat_party_hazard`, built per run by
  `surge_hazard_for()`, and is not persisted. `output/salience-hazard.csv` (2026-08-26) has no
  Pascoe Vale rows. So p about 0.025 to 0.031 is back-solved, and 0.0312 matching `surge_h`
  exactly is suggestive, not proof.
- The OTH_RIGHT raw value (back-solved) and the exact `sa`/`sb` the harness used (log gives `sb`
  to 0.1; `sa` under the notional prior may differ slightly from the corpus `level_prev`).
  These explain the 0.03 to 0.06 residuals, not the 2.4-point gap.
- That Pascoe Vale ALP is in the "departed" tier (0.621) rather than "present" (0.965): inferred
  from the scale factor (ALP fits 0.621 at 1.112, matching OTH 1.114 and LNP 1.113; 0.965 would
  need 1.177). `leader_same` is FALSE for ALP in features (`same_i` = 0), which is consistent but I
  did not read `candidate_returns()` for the reason.
- The fresh run's 18.42 final IND (xgb layer, `xgb_primary_on` = 1, file
  `backtest-vic-sharedetail-...a138069-g579df5c.csv`) was not traced; it is downstream of this.

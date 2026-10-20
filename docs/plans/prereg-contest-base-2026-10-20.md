# Prereg: a new-to-seat candidate starts from the party's vote where it stands (AUSPOL_CONTEST_BASE)

Written 2026-10-20, before the code. Follows `prereg-contest-features-2026-10-20.md` (REFUSED): the trees were told
who stands and moved nsw2023's new-to-seat One Nation cells down, because they only fit a residual on `base_pred`
and `base_pred` puts those cells near 1.5 against actuals of 5-15. This arm changes `base_pred` itself.

## The change

For a single-party class (One Nation; scope chosen by Pete 2026-10-20, "Single-party classes") in a seat where it
stands and did not stand last time (`seat_prev_pcv` NA or 0):

```
mass   = level_pred * n_seats                       # the class's statewide vote, in seat-share points
fill   = max(0, (mass - sum(base_pred over its RETURNING contested seats)) / k_new)
base'  = base_pred + w * (fill - base_pred)
```

`w` is fitted time-forward (`elections_before()`, the sitting-member convention): the no-intercept slope of
`actual - base_pred` on `fill - base_pred` over earlier elections' cells, SE clustered on election, shrunk toward 0
by its own signal to noise (`w * w^2 / (w^2 + se^2)`), clipped to [0, 1]; fewer than 2 earlier elections gives 0.
Weights land in `output/contest-base-weight.csv` (one row per pair, plus vic2026 from every election). Every other
cell is untouched. Training (`scripts/fit_xgb_primary_v6.R`, after the sitting-member shift) and serving
(`xgb_primary_predict_live()`, after SM2) apply the same formula; live, who stands comes from the confirmed
nomination list (`AUSPOL_NOM_LIVE=1`). Without that list nothing moves.

Why One Nation only: "the party's vote where it stands" exists when the class is one party. IND, OTH and OTH_RIGHT
are many parties sharing one level, and splitting it evenly gave fed2007 minor-right 24.7 per seat against ~1.
The Greens are also one party but contest almost every seat; screened separately below, they come out worse and
their weight for vic2026 is 0.013, so leaving them out changes nothing live. Reported to Pete.

## Screen (share level, `base_pred` only, before the trees; can stop the arm, never clear it)

From `C:\dev\auspol-iso-ct-arm\output\xgb-primary-v6-features.csv` (19,071 rows, 35 elections), new-to-seat
contested cells, share RMSE in points (lower is better):

| class | cells | base_pred | with the shrunk time-forward fill | mean base / adjusted / actual |
|---|---|---|---|---|
| ONP | 341 | 5.417 | 5.175 | 5.58 / 6.57 / 8.82 |
| GRN (not in the arm) | 146 | 4.211 | 4.526 | 8.31 / 7.86 / 9.45 |

ONP weight for vic2026: 0.437 (raw 0.478, SE 0.146). nsw2023 ONP new-to-seat: 1.68 -> 6.34 (actual 9.67).
fed2016 stays 0.22 (actual 13.31): no earlier evidence, weight 0.

## Criterion (the standard rule, unchanged from the contest-features prereg)

One isolated rebuild from stage 3 at 20,000 sims with the switch on, scored by `scripts/score_contest_feats.R`
against the existing baseline copy `C:\dev\auspol-iso-ct-base` (built 2026-10-20 at 874d65c, byte-identical to the
published predictions). The arm copy is made from the same commit plus this code; the code is off by default, so
the baseline stays valid. Targets: seats with any cell moved > 0.05 points.

1. Target-seat seat-winner log loss better by more than 1 SE (clustered on election).
2. All seats not worse by more than 1 SE.
3. Leave-one-election-out holds on the primary.
4. No election worse by more than 2 SE of its own seats.
5. Without the two largest-gain seats the target change keeps its sign.

Reported, not voted: ONP new-to-seat share RMSE in the published path; nsw2023, fed2019, qld2017, sa2026 One
Nation; the 1e-4 floor; AEF-7.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the 1e-6 floor (report at 1e-4).
(b) Live vic2026 before the nomination list loads must be byte-identical with and without the switch.
(c) Live vic2026 after the list loads (~9 Nov) walked with and without, shown to Pete before it publishes.
(d) A class's statewide total moving more than 1 point in any election: reported to Pete.

Shipping is Pete's call on the result.

## RESULT (2026-10-20): REFUSED on clauses 1-4

One isolated stage-3 rebuild at 20k from 5e4fe20 with the switch on (`deciding-runs/contest-base-rebuild/`, 74 min;
CB1 "317 cells moved in 13 elections (mean +1.05 points) ... vic2026 weight 0.437"), against the 874d65c baseline
copy. `scripts/score_contest_feats.R`, seat-winner log loss change, lower is better:

| clause | floor 1e-6 | floor 1e-4 | verdict |
|---|---|---|---|
| 1 primary, 2,051 target seats in 27 elections | +0.0036 (SE 0.0023) | +0.0014 (SE 0.0009) | WORSE by more than 1 SE |
| 2 guard, all 2,931 seats | +0.0025 (SE 0.0016) | +0.0009 (SE 0.0006) | FAIL |
| 3 leave-one-election-out | 0 of 27 | 0 of 27 | FAIL |
| 4 elections worse by more than 2 SE | 2 (nsw2023, wa2017) | 2 | FAIL |

Split by where the change acts (not voted, added after seeing the result): the 317 seats whose One Nation base_pred
moved +0.0022 (SE 0.0017); the other 2,614 seats, moved only by the retrained trees, +0.0026 (SE 0.0018), +0.0008
(SE 0.0007) at 1e-4. So it is not worse only through retrain churn: it does not help seat calls where it acts either.

The shares did improve where it acts: One Nation new-to-seat contested RMSE 5.632 -> 5.488 points (460 cells),
nsw2023's 11 cells 8.07 -> 5.65 (mean 2.31 -> 5.08, actual 9.67); all minor cells 4.266 -> 4.257. fed2016 unmoved
(weight 0). nsw2023's seat losses are seats One Nation did not contest (Pittwater, Vaucluse: the retrained trees
moved the teal independent up), and sa2026 Ngadjuri lost 0.896 -> 0.467 as One Nation's rise ate into the winner.
New-to-seat One Nation candidates almost never win, so a better share for them buys no seat-call accuracy.

Switch stays "0". This closes the partial-contest line for seat calls: the trees-only and base_pred versions are both
refused, and the base_pred version is the strongest one built from what the pipeline has.

# Retiring members' vote going home: investigation (2026-10-24)

Read-only investigation. No code edited, no harness run. Scratch scripts and the case
table are in `...\scratchpad\retire\` (`p1.R` cases, `p2.R` effect size, `p3.R` published-miss
check; `cases.csv` has every row below).

## Headline

1. **The rule Pete asks for already exists and is built, wired and OFF.** It is
   `AUSPOL_DEPARTED_ORIGIN` (`route_departed_origin()`), measured 2026-09-18 on 15 cases and
   left off because the criterion fell 0.06 SE short
   (`docs/plans/prereg-departed-origin-return-2026-09-18.md`, SEAT-REGISTRY Morwell entry,
   `published_flags.R:36`). So the work is a re-decision on a bigger corpus plus a better form,
   not a new build.
2. **The corpus now holds 40 cases, not 15.** On them, the origin party regains about what
   pro-rata already gives it. Excess over pro-rata: +0.07 of the leader's vote, SE 0.10
   (n = 40). Morwell is a real outlier (0.81 against 0.28 pro-rata), not the typical case.
3. **A rule proportional to the leader's vote does not improve the published numbers**
   (details below). The origin party is under-called by a roughly constant ~1.9 points on these
   cases, not by an amount that grows with the departed vote. My recommendation is to treat this
   as a candidate for an xgb feature and a re-test with an offset form, not to switch the
   existing arm on.

## Mechanism (file:line)

Where the released vote goes today (all pro-rata):

- `R/dev_slope.R:291` `screened_slopes()`. Lines 338-358: when `honour_departed` is on, the
  class leader did not come back (`prior_leader_returns` FALSE, built at
  `R/candidate_returns.R:241`) and the screen permits no successor, the class slope becomes
  `departed_rate` (IND 0.38, `dev_slope.R:293`). Line 380-ish: the `"departed"` attribute flags
  those seats.
- `R/dev_slope.R:~395` `renorm_hold()`. The flagged cell is held at its decayed value and every
  OTHER cell is scaled by one common factor per row to fill 100. **That common factor is the
  pro-rata spread.** There is no per-party routing anywhere in this step.
- Callers of `renorm_hold(shares, HELD)`: `scripts/backtest_candidate_fed.R:1476`, `_nsw.R:791`,
  `_nt.R:643`, `_qld.R:819`, `_sa.R:973`, `_vic.R:694`, `_wa.R:610`, and the published forecast
  `scripts/fit_seats_full.R:1327`. `HELD` is built from `attr(.sl, "departed")` (vic: line 646).
  The `honour_departed` flag is read at `_vic.R:451`, `_fed.R:744`, `_nsw.R:526`, `_qld.R:482`,
  `_sa.R:533`, `_wa.R:369`, `_nt.R:402`, `fit_seats_full.R:870` (default "1" there; "0" in the
  harnesses unless harness_defaults supplies the published value).
- One shared function for the decay and renormalisation (`screened_slopes`, `renorm_hold`).
  The call sites are per-script copies.

Where the existing "goes home" rule sits:

- `R/candidate_returns.R:1628` `departed_defectors()` finds the cases;
  `:1676` `fit_departed_origin_return()` fits the share; `:1718` `route_departed_origin()` moves
  `frac * lead_pcv` points from the departed class to the origin party **in the prior matrix,
  before slopes and swing** (so it happens upstream of `screened_slopes`, and the class then
  decays on what is left).
- Call sites, all behind `AUSPOL_DEPARTED_ORIGIN`: `fit_seats_full.R:1031-1041`,
  `backtest_candidate_vic.R:573-583`, `_fed.R:862-872`, `_nsw.R:662-672`, `_qld.R:623-633`,
  `_sa.R:660-670`, `_wa.R:498-508`, `_nt.R:531-541`. Copies in each script, shared functions
  in `R/candidate_returns.R`.

Where the xgb layer sees it:

- There is **no xgb feature** for a departed defector's origin party. Related, and different:
  `add_departed_side()` (`R/departed_side.R:20`; used at `R/xgb_primary_override.R:426`,
  `scripts/fit_xgb_primary_v6.R:667`, `_v6_final.R:50`; feature names `own_departed_i`,
  `opp_departed_i`, switch `AUSPOL_XGB_DEPARTED_SIDE`) flags a departed MAJOR-party member,
  which is the opposite situation. An origin-party feature is new work.
- The live published xgb takes `base_margin` from the run's own `shares`
  (`xgb_primary_predict_live`), so a base_pred change reaches the published number at once. The
  static backtest cache (`AUSPOL_XGB_PRIMARY`) would not see it until retrained (CLAUDE.md).

## Data source for former party

Recoverable, and already used. `output/candidacies.csv` (columns `election, seat, name, surname,
given, party, pcv, votes`). `departed_defectors(election_from, election_to)` takes the leading
candidate of each non-major class at `election_from` (at least 5 points), requires that person
absent from the seat at `election_to` under any label, and looks up the same person (name key
`match_key(surname_of, given_of, "person")`, aligned per pair) in earlier ALP/LNP rows of the
same seat; `origin` is the latest such party. Returns `seat, party, origin, name, lead_pcv`.

Limits (unconfirmed gaps, by design of that function):
- Origin must be ALP or LNP. The corpus folds Nationals into LNP (`table(C$party)` shows only
  ALP, LNP among majors; no NAT rows), so Northe's origin reads LNP.
- Requires a PRIOR major-party row in the SAME seat. A member who changed seat, or came from a
  minor party (minor-to-minor), is not found. I did not search for those.
- Requires the person to be the class leader at 5 points or more.

## Cases table

n = 40 seat-elections across 22 pairs (`departed_defectors()` over `all_election_pairs()`).
Columns: `lead` = departed leader's vote at the earlier election (points); `o_prev`/`o_now` =
origin party's vote before and after (points, corpus); `excess` = o_now minus `o_prev` times the
statewide ratio for that party (points, swing-only expectation); `regain` = excess / lead
(fraction of the leader's vote regained, positive means the party gained);
`prorata` = lead share the origin party would get if the leader's vote were spread over all
other voters in proportion to their size, `o_prev*ratio/(100-lead)`; `ours`/`actual` = published
prediction and result for the origin party (published-predictions.csv, Oct 21, includes the xgb
layer); `miss` = actual minus ours (positive means we under-called the origin party).

| pair | seat | member | origin | lead | o_prev | o_now | excess | regain | prorata | ours | actual | miss |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| wa2008 | Vasse | Masters | LNP | 20.6 | 47.4 | 55.5 | 3.4 | 0.16 | 0.66 | 61.2 | 55.5 | -5.6 |
| fed2010 | Corio | O'Connor | ALP | 12.7 | 45.5 | 51.5 | 11.7 | 0.92 | 0.46 | 47.6 | 51.5 | 3.9 |
| fed2010 | Lyons | Quin | LNP | 9.6 | 32.5 | 32.7 | -1.0 | -0.11 | 0.37 | 38.1 | 32.7 | -5.4 |
| wa2013 | Nedlands | Walker | LNP | 22.8 | 45.5 | 58.4 | 2.5 | 0.11 | 0.72 | 60.1 | 58.4 | -1.8 |
| fed2013 | Ryan | Johnson | LNP | 8.5 | 45.7 | 51.7 | 3.9 | 0.46 | 0.52 | 48.2 | 51.7 | 3.5 |
| sa2014 | MacKillop | O'Halloran | LNP | 17.2 | 60.9 | 65.1 | 1.0 | 0.06 | 0.77 | 62.3 | 65.1 | 2.8 |
| qld2015 | Beaudesert | McLindon | LNP | 26.4 | 47.1 | 47.5 | 8.3 | 0.31 | 0.53 | 45.4 | 47.5 | 2.1 |
| qld2015 | Burnett | Messenger | LNP | 24.0 | 40.0 | 47.2 | 13.9 | 0.58 | 0.44 | 43.5 | 47.2 | 3.6 |
| nsw2015 | Goulburn | Parker | ALP | 10.9 | 14.7 | 34.3 | 14.6 | 1.34 | 0.22 | 23.6 | 34.3 | 10.7 |
| nsw2015 | Macquarie Fields | Fraser | LNP | 10.5 | 37.0 | 36.5 | 3.6 | 0.34 | 0.37 | 34.8 | 36.5 | 1.7 |
| nsw2015 | Ryde | Tagg | LNP | 7.0 | 62.8 | 53.7 | -2.3 | -0.32 | 0.60 | 56.1 | 53.7 | -2.3 |
| wa2017 | Vasse | Masters | LNP | 8.0 | 64.6 | 65.6 | 21.1 | 2.62 | 0.48 | 62.4 | 65.6 | 3.1 |
| qld2017 | Gaven | Douglas | LNP | 12.5 | 38.9 | 46.1 | 14.4 | 1.15 | 0.36 | 47.9 | 46.1 | -1.8 |
| vic2018 | Frankston | Shaw | LNP | 12.9 | 35.8 | 32.7 | 2.6 | 0.21 | 0.34 | 34.0 | 32.7 | -1.3 |
| vic2018 | Lowan | Rainsford | LNP | 14.2 | 54.1 | 66.9 | 21.6 | 1.52 | 0.53 | 54.8 | 66.9 | 12.1 |
| nsw2019 | Swansea | Edwards | LNP | 13.4 | 25.9 | 32.8 | 9.2 | 0.68 | 0.27 | 26.4 | 32.8 | 6.4 |
| fed2019 | Tangney | Jensen | LNP | 11.9 | 48.8 | 53.6 | 5.5 | 0.47 | 0.55 | 48.6 | 53.6 | 5.0 |
| nt2020 | Karama | Lawrie | ALP | 32.6 | 34.0 | 51.1 | 19.3 | 0.59 | 0.47 | 52.2 | 51.1 | -1.1 |
| qld2020 | Cairns | Pyne | ALP | 19.2 | 30.4 | 44.2 | 10.2 | 0.53 | 0.42 | 38.0 | 44.2 | 6.2 |
| qld2020 | Pine Rivers | Holswich | LNP | 7.8 | 26.9 | 36.5 | 7.9 | 1.00 | 0.31 | 30.1 | 36.5 | 6.4 |
| qld2020 | Redlands | Dowling | LNP | 9.7 | 31.8 | 38.1 | 4.3 | 0.44 | 0.37 | 34.8 | 38.1 | 3.4 |
| wa2021 | Hillarys | Johnson | LNP | 20.1 | 39.6 | 27.0 | -0.3 | -0.02 | 0.34 | 35.2 | 27.0 | -8.2 |
| sa2022 | Florey | Bedford | ALP | 30.6 | 32.8 | 48.9 | 8.9 | 0.29 | 0.58 | 48.0 | 48.9 | 0.9 |
| sa2022 | Morphett | McFetridge | LNP | 14.2 | 41.4 | 51.7 | 12.3 | 0.87 | 0.46 | 50.0 | 51.7 | 1.7 |
| vic2022 | Gippsland East | Buckley | LNP | 6.3 | 56.7 | 63.3 | 7.9 | 1.25 | 0.59 | 60.5 | 63.3 | 2.9 |
| vic2022 | **Morwell** | Northe | LNP | 19.6 | 23.0 | 38.4 | 15.9 | 0.81 | 0.28 | 31.4 | 38.4 | 7.0 |
| nsw2023 | Cabramatta | Le | LNP | 25.9 | 14.8 | 22.6 | 10.0 | 0.39 | 0.17 | 26.5 | 22.6 | -3.9 |
| nsw2023 | Clarence | Cansdell | LNP | 16.8 | 46.5 | 49.6 | 10.0 | 0.59 | 0.48 | 44.9 | 49.6 | 4.7 |
| nt2024 | Blain | Mills | LNP | 23.0 | 35.6 | 46.5 | -9.1 | -0.40 | 0.72 | 48.7 | 46.5 | -2.2 |
| nt2024 | Brennan | Chandler | LNP | 9.4 | 39.5 | 73.9 | 12.3 | 1.30 | 0.68 | 59.0 | 73.9 | 14.9 |
| nt2024 | Fong Lim | Collins | ALP | 11.9 | 42.1 | 27.8 | -2.9 | -0.25 | 0.35 | 32.8 | 27.8 | -5.1 |
| nt2024 | Goyder | Purick | LNP | 31.1 | 27.5 | 56.2 | 13.4 | 0.43 | 0.62 | 73.1 | 56.2 | -16.9 |
| nt2024 | Johnston | Klose | LNP | 14.6 | 19.7 | 34.6 | 3.9 | 0.27 | 0.36 | 34.2 | 34.6 | 0.4 |
| qld2024 | Buderim | Dickson | LNP | 7.1 | 42.5 | 48.9 | -0.3 | -0.05 | 0.53 | 53.4 | 48.9 | -4.5 |
| qld2024 | Ipswich | Holmes | LNP | 13.9 | 20.3 | 29.1 | 5.6 | 0.40 | 0.27 | 26.8 | 29.1 | 2.3 |
| qld2024 | Whitsunday | Costigan | LNP | 9.4 | 32.8 | 52.7 | 14.7 | 1.57 | 0.42 | 45.3 | 52.7 | 7.4 |
| fed2025 | Hughes | Kelly | LNP | 7.4 | 43.5 | 36.5 | -2.3 | -0.32 | 0.42 | 43.2 | 36.5 | -6.7 |
| sa2026 | Kavel | Cregan | LNP | 50.5 | 20.8 | 20.2 | 9.0 | 0.18 | 0.23 | 8.4 | 19.9 | 11.5 |
| sa2026 | Mount Gambier | Bell | LNP | 45.7 | 29.0 | 12.6 | -3.1 | -0.07 | 0.29 | 19.5 | 12.5 | -7.0 |
| sa2026 | Waite | Duluk | LNP | 19.7 | 25.9 | 18.2 | 4.3 | 0.22 | 0.17 | 11.3 | 18.4 | 7.1 |

Caveats on the table: sa2026 rows are real results (SA held March 2026). Several members
"retired" are really party switchers or defeated-then-gone (Cregan, Bell, Duluk, Mills, Purick
left a party and stood or left in the same cycle); the function only asks "does not stand under
any label". I did not check each person's story. nt2024 rows share one statewide ratio of 1.56
(CLP landslide), which inflates their `excess` columns; wa2017 Vasse reads 2.62 for the same
reason (landslide artefact, flagged in the original prereg).

## Effect size

All figures from `cases.csv`; n = 40 unless stated. Fractions are of the departed leader's vote.

| quantity | mean | SE | median | share above 0 |
|---|---|---|---|---|
| regained fraction (excess / lead, unclipped) | 0.514 | 0.097 | 0.416 | 0.80 |
| regained fraction clipped to [0,1] (what the existing fit uses) | 0.458 | 0.058 | 0.416 | 0.80 |
| pro-rata fraction (what spreading the vote evenly gives the origin party) | 0.444 | 0.025 | 0.429 | 1.00 |
| regained minus pro-rata (the disproportionate part) | **+0.070** | **0.101** | 0.008 | 0.50 |

Pooled (sum of excess / sum of lead): 0.414 against pro-rata 0.434. By clustering on the 22
pairs the unclipped mean is 0.542, SE 0.123 (no pro-rata comparison made at pair level).

So: the former party does regain a lot of the released vote (80% of cases positive), but about
the same amount a pro-rata split would give it. The extra is +0.07, about 0.7 of its standard error (0.10), so not distinguishable from zero. Morwell (0.81 against 0.28) is a genuine 0.5 above pro-rata, but
10 other cases read 0 or below.

Shape: regained fraction is higher when the departed vote is small (leads under 15 points:
0.69, SE 0.15, n = 23; 15 and over: 0.28, SE 0.07, n = 17). That is the signature of a roughly
constant gain in points rather than a share of the leader's vote, which is what a
proportional-to-lead rule gets wrong.

Check against what we actually published (includes the xgb layer and the honour decay):

| quantity (published miss = actual minus ours, origin party, points) | mean | SD | note |
|---|---|---|---|
| 40 departed-defector cases | +1.45 | 6.28 | SE of mean 0.99; clustered by pair 1.01 (SE 0.87, 22 pairs) |
| 3,660 other ALP/LNP cells in the same pairs | -0.44 | 5.14 | control |

The origin party is under-called by about 1.9 points more than a control cell, roughly 1.9 SE
(naive). 25 of 40 are positive. The pooled bias is real but small, and MAE on the cases (5.14)
is only 1.2 above the control (3.98), so much of the size is just seats with big swings.

Does routing a share proportional to the leader's vote fix it? Time-forward test on the
published misses (each case's share estimated from strictly earlier-dated cases only, partial
pooling with weight n/(n+K), K = 3, 10, 20): MAE goes **up** (5.14 to 5.30, 5.23, 5.20) and
squared error up (40.5 to 45.9, 43.9, 42.5); 20 of 40 improve at every K. A regression of the
published miss on the leader's vote gives slope -0.10 (SE 0.10) with a +3.2 intercept; through
the origin +0.04 (SE 0.05). That is a rough proxy: it subtracts the correction from the
published number and ignores that the real routing also reduces other classes through
renormalisation, so it is not the harness result. The original harness result agrees in
sign: 8 of 15 improved, pooled criterion 0.94 SE.

Not measured: the same test on `base_pred` alone (needs a harness run, not allowed here), and
per-class effects on the other parties. Not checked: whether the 5-point leader floor and the
major-party-origin requirement drop cases that behave differently.

## Leakage

The existing `fit_departed_origin_return()` (`candidate_returns.R:1676`) is **leave-target-out,
not time-forward**: line 1684 skips only the target pair, so the share used to forecast
fed2013 was fitted on later cases (e.g. qld2024). It never calls `fit_pairs_for()`
(`R/time_forward.R:14`), which the sibling `fit_minor_defector_conserve` does at `:1779`
(`AUSPOL_CONSERVE_TF`, default "1"). Its 15-case result on 2026-09-18 therefore carried the
same look-ahead the 2026-09-28 time-forward audit removed elsewhere
(`docs/plans/prereg-time-forward-constants-2026-09-28.md`). It is not on the 09-28 inventory as far
as I looked (grep only; not confirmed in `docs/reviews/pooled-fits-inventory-2026-10-13.md`).

Fix: filter `pairs <- fit_pairs_for(target_election, pairs)` before the loop, and in any new
version fit only from `pairs[election dated strictly before the target]`. My time-forward numbers
above use cases with strictly earlier election dates only (`election_dates()`); the first 5
cases (wa2008, fed2010 x2, wa2013, fed2013) have fewer than 5 earlier cases, so they get
heavy shrinkage toward zero extra routing, as the shrinkage form below requires. Also: the
swing ratio (`origin_now` baseline) uses the TARGET election's own statewide share, which is
fine for a diagnostic but would need the forecast statewide share, not the actual, in
production (live forecasts use predicted statewide share; the 09-28 fundamentals work has the
convention).

## Proposed arm

Given the evidence, do not simply flip `AUSPOL_DEPARTED_ORIGIN`. The data say the routing
should be (a) small, (b) closer to a constant offset than a share of the leader's vote, and
(c) fitted time-forward and shrunk. Proposal, in order of cost:

1. **Fix the leak, re-state the baseline.** Add `fit_pairs_for()` to `fit_departed_origin_return`
   under a new switch `AUSPOL_DEPARTED_ORIGIN_TF` (default "1", mirroring `AUSPOL_CONSERVE_TF`).
   Re-run the 2026-09-18 criterion on the 40 cases through `quick_arm.R` (screen, AEF-7 default),
   then all 22 pairs for the deciding run. Both existing arms (`"1"`, `"mean"`) stay.
2. **New arm `AUSPOL_DEPARTED_HOME`** ("0" default; "shrunk" = shrinkage form below).
   Change `route_departed_origin()` (`R/candidate_returns.R:1718`) to take a per-case amount
   `amt_i = w * (frac * lead_i) + (1 - w) * 0` with `w = n / (n + K)` on time-forward cases only
   (K = 3, the value `AUSPOL_CONSERVE_SHRINK_K` already uses), and fit `frac` on the EXCESS OVER
   PRO-RATA (regain minus prorata), not on the raw excess. Raw excess already contains the
   pro-rata share the model gives for free; routing it a second time is double counting, which is
   a plausible reason the Hughes/Vasse/Hillarys cases got worse in 2026-09-18. On the numbers
   above that fitted extra is +0.07 +/- 0.10, so the shrunk rule would move about 0.01 to 0.03
   of the leader's vote: negligible, which is itself the honest answer.
   Alternative form to test: add an origin-party offset in points that does NOT scale with
   `lead_pcv` (published-miss intercept +3.2, SE 2.0, not significant).
3. **Apply in base_pred AND xgb.** Both required, per CLAUDE.md:
   - base_pred: same call sites as the existing arm (list above), gated on the new switch, in all
     seven scripts plus `fit_seats_full.R:1031`. `grep` the other six for the switch before
     reporting (CLAUDE.md harness-parity rule), and add the switch to
     `scripts/published_flags.R` in the same commit, then regenerate `docs/MODEL-REGISTRY.md`.
   - xgb: new columns beside `own_departed_i`/`opp_departed_i` in `add_departed_side()`
     (`R/departed_side.R:20`) and the feature list at `scripts/fit_xgb_primary_v6.R:815`, e.g.
     `origin_released_i` = released vote (lead_pcv, points) of a departed ex-member of THIS
     party in the seat, else 0 (a filler 0 is acceptable only if a flag column
     `origin_has_departed_i` accompanies it; CLAUDE.md warns a constant filler becomes a label).
     Gate with `AUSPOL_XGB_DEPARTED_ORIGIN`. The static cache (`AUSPOL_XGB_PRIMARY`) needs the
     4-step non-circular retrain before it sees any base_pred change; the live path
     (`xgb_primary_predict_live`) sees it immediately.
4. **Criterion to pre-register before running** (scope the metric to the change): primary =
   origin-party mean absolute primary error on the 40 target cases (clustered SE by pair, 22
   clusters), base_pred only (`AUSPOL_XGB_PRIMARY=0`), must fall by more than 1 SE; guard =
   pooled seat log loss on all 22 pairs not worse by more than 1 SE (cluster = pair); report the
   per-case table and leave-one-election-out so Morwell cannot carry the result (CLAUDE.md "no
   one-election share refusal"). Name in advance as unacceptable: a gain driven by the nt2024
   landslide rows or by wa2017 Vasse.
5. Dry-run the criterion on Morwell, Hughes, and a control seat with no departed member first
   (it must score exactly 0 on the control).

## Risks

- **Double counting.** The model already releases the vote pro-rata, and pro-rata already gives
  the origin party ~0.44 of the leader's vote. Routing on the raw excess adds to this.
- **The signal is small and noisy.** Excess over pro-rata +0.07 +/- 0.10 on 40 cases; one flagship
  seat (Morwell, log loss 2.70) can mislead. Per-case noise in origin-party share is ~5-6 points.
- **Landslide ratios** (nt2024 ratio 1.56, wa2017 0.69, sa2026 0.54) swamp the swing-only
  baseline; the regain column is not trustworthy on those rows. A clean version should use the
  model's own predicted statewide share per election.
- **Selection.** Cases are defined by "leader does not stand again", but many are party
  switchers and defeated members (see caveat), who leave for different reasons from retirement.
  A true "retired" subset needs a hand-checked flag; not done.
- **Time-forward only has ~35 usable cases for the late elections, almost none before 2013**;
  a time-forward constant for fed2010 to wa2013 is mostly the prior.
- **Harness parity.** Eight scripts carry copies; the existing arm is wired in all eight, any new
  arm must be too.
- **Not confirmed:** the base_pred-only effect (no harness run allowed here); the published
  table's flags at the time of build (Oct 21) were taken as the shipped config, not checked;
  whether `docs/reviews/pooled-fits-inventory-2026-10-13.md` already lists the look-ahead in
  `fit_departed_origin_return` (not opened).
- Files read for this report: `R/candidate_returns.R` (1599-1790), `R/dev_slope.R` (285-420),
  `R/time_forward.R`, `scripts/fit_seats_full.R` (1020-1060), the plan
  `docs/plans/prereg-departed-origin-return-2026-09-18.md`, SEAT-REGISTRY (Morwell), grep of
  `docs/` and `scripts/`. Not read (as asked ~300-line cap, and not needed for the numbers):
  `overcalled-independents-walk-2026-10-03.md`, `NEXT-STEPS.md` 270-290 (grep hit line 282 only:
  "bigger overcalls with a permitted successor (Geelong, Morwell, Mildura, Kavel, Finniss)
  are a separate item") and the 2026-10-16 to 10-22 journal (grep for Morwell/Northe/origin found
  nothing new there).

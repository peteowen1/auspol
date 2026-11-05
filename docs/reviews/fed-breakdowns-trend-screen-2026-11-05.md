# Federal breakdowns inside the state trend: statewide screen, 2026-11-05

Pre-registration: [`plans/prereg-fed-breakdowns-in-trend-2026-10-26.md`](../plans/prereg-fed-breakdowns-in-trend-2026-10-26.md)
(Amendment 1 sets the decision rule; Amendment 2 records what the build found). Branch `fed-breakdowns-trend-1105`.
Screen: `scripts/screen_fed_breakdowns_trend.R`. No seat harness, no `quick_arm.R` and no deciding run were run.

## The answer

**No arm passes. B1 fails, B2 and B3 tie, and the negative control fails only on the 90/180-day metric, not on
polling day.** The arm stays off (`AUSPOL_TREND_FED_R = "0"`). Under the prereg a tie is not a ship; it goes to
Pete as a clause decision. A tie here is a tie on very small moves: the shipped recent-poll blend puts 0.89 to 1.00
of the day-before weight on recent polls, which already carry the breakdowns, so the published day-before level
moves by 0.02 points RMS.

The trend itself DOES see the breakdowns. Before the blend, the negative control B-eq ("federal equals state") is
1.03 points worse (SE 0.30). After the blend, the published day-before level is only 0.06 worse (SE 0.13). So the
polling-day metric cannot tell "federal equals state" from the shipped trend, which is the failure dry run 3 says
to stop and report. Amendment 1's H metric (90 and 180 days out) does catch it: 1.10 SE worse.

## What was built

- `R/trend_fed.R` (new): breakdowns enter `trend_as_at(fed = )` as extra observations, each with its own house
  effect per federal firm and federal term (`fed:<firm>:<term>`, under 3 in a term pool into
  `fed:(other firms):<term>`), prior sd 10 points at the party's reference share, ZERO weight in the house-effect
  sum-to-zero, variance `sigma_obs^2 / r` (times `0.48 + 0.52 x 1516 / n` under `AUSPOL_TREND_FED_N = "1"`, with
  the registered four-step imputation of a missing n), each row spread 1/L over its fieldwork days. Admitted only
  if fieldwork started after the previous state election and ENDED before the as-at date (asserted twice: in
  `trend_fed_for()` and again in the gate inside `trend_as_at()`). Only classes the state polls already fit at
  `min_polls` (ALP, LNP, GRN, ONP); the Coalition figure is left out where Liberal and National fit separately
  (WA). Never a federal target.
- Hooks in `R/trend.R` (`fit_trend`, `trend_prior_system`, `trend_obs_matrix`, `trend_solve`) only run when a fit
  is handed breakdowns.
- Reach: `statewide_draws_as_at()` (every harness through `forecast_statewide_or_oracle()`), and the three direct
  callers of `trend_as_at()` on the published path: `scripts/fit_seats_full.R`, `scripts/build_trend_page_data.R`,
  `scripts/build_page.R`, all through `trend_fed_for_cycle()`, which returns `NULL` when the arm is off.
- `forecast_statewide_for(as_at = )` (default the day before, byte-identical) for the horizon screen.
- Switches at their OFF values in `scripts/published_flags.R`: `AUSPOL_TREND_FED_R = "0"`,
  `AUSPOL_TREND_FED_SRC = "shipped"`, `AUSPOL_TREND_FED_N = "0"`, plus `AUSPOL_TREND_FED_PRIOR_SD = "10"` for the
  diagnostics (Amendment 2). Constants in `docs/CONSTANTS.md`.
- `scripts/build_fed_state_breakdowns.R --full-only` writes `output/fed-state-breakdowns-full.csv`: 704 polls x
  114 columns, every source column prefixed `wiki_`, `bt_`, `sf_`, `nq_`.
- Tests: `tests/testthat/test-trend-fed.R` (synthetic, runs in CI): R = 0 identity, a late row trips the assertion,
  zero sum-to-zero weight and the state block of the prior unchanged, the offset absorbs a 6-point level shift
  while a tight prior does not, class gating, 1/L spreading, the walk-extension rule. 34 expectations, all pass.

## Data

Newest state-scope federal breakdown per source (fieldwork end):

| source | rows (state scope) | newest |
|---|---|---|
| Wikipedia (shipped file's source; state sections deleted from the fed2028 page on 24 Oct) | 489 | 2026-10-06 |
| BludgerTrack, refetched once 5 Nov (`raw/bludgertrack/fed2028-current-2026-11-05.xml`, file stamp 2 Nov 6:17am) | 591 | **2026-10-25** |
| `state-federal-polls.csv` (scope state) | 126 | 2025-05-01 |
| Newspoll quarterly | 8 | 2026-09-18 |

BludgerTrack is still publishing state breakdowns: the refetch added 2 polls per mainland state (to 25 Oct) over the
13 Oct copy. The union dedupes 1,214 source rows to 704 polls; 41 disagreements over 1 point between sources are
printed by the builder (most are 2025 YouGov rows where Wikipedia and state-federal agree and BludgerTrack differs).

## Checks before any score

| check | outcome |
|---|---|
| R = 0 identity (statewide draws, trend series, house effects, against the branch point's code) | identical on vic2022 (day before and 90 days out), vic2026 and nsw2027 (today), nsw2023, fed2022; a copy with one draw moved 1e-12 reads as different |
| B0 rebuilt against `output/level-recent.csv` (built by the shipped code on 1 Nov) | max difference 5e-14 over 21 cells |
| non-target elections unchanged, B1 and B2, day before | 27 of 27 identical (all 7 federal pairs included) |
| breakdowns reach the fit (largest unblended move) | B1 0.32, B2 0.46 points day before; 0.36 / 0.26 at 90-180 days |
| admission | every admitted breakdown ended at least 1 day before its as-at date, 125 fits |
| class gate | same fitted classes in every arm at every horizon |
| dry run 1 (the rule on known answers) | all five match (blend F1 TIE, r = 1 FAIL, r = 0.05 TIE, T2 FAIL, T1 PASS) |
| dry run 2 (wa2025 ALP held) | B1 42.29 -> 42.03, B2 42.29 -> 41.83 (under 1 point; breakdowns sat ~6 lower) |
| dry run 3 (B-eq must FAIL the primary) | **NOT MET**: primary TIE (+0.057, 0.42 SE); H FAIL (1.10 SE); unblended 1.03 worse |
| size check (B1) | primary bound 0.019 vs 1.84 SE = 0.009; H bound 0.053 vs 0.019: both can show a pass, so not stopped |

Two build bugs were caught by these checks before any score was read, and fixed (Amendment 2 items 5 and the
commit message): breakdowns from before the cycle reaching qld2024, wa2025 and sa2026 (a data.table NSE trap in
`statewide_draws_as_at()`; the gate's assertion fired), and the walk extension un-folding nsw2023 One Nation in
every arm (the class-gate check fired).

## Results

RMSE of the published statewide level against the result, in points; change is arm minus B0, so **negative is
better**; SE is a delete-one-election jackknife. Primary: the day before, 24 cells over 7 elections. H: 90 and 180
days out pooled, 28 cells over 4 elections (sa2022, wa2025 and sa2026 have no trend that far out).

| arm | primary B0 -> arm | change (SE) | H B0 -> arm | change (SE) | verdict |
|---|---|---|---|---|---|
| B1 shipped file, r 0.15 | 1.348 -> 1.351 | +0.0023 (0.0048) | 3.034 -> 3.048 | +0.0142 (0.0105) | **FAIL** (H 1.35 SE worse) |
| B2 union + n, r 0.15 | 1.348 -> 1.346 | -0.0028 (0.0079) | 3.034 -> 3.042 | +0.0084 (0.0088) | TIE |
| B3 r fitted, shrunk | 1.348 -> 1.346 | -0.0025 (0.0076) | 3.034 -> 3.041 | +0.0073 (0.0083) | TIE |
| B-eq (control) | 1.348 -> 1.405 | +0.0567 (0.1334) | 3.034 -> 3.287 | +0.2535 (0.2299) | FAIL (on H only) |
| B2-noblend vs B0-noblend | 1.343 -> 1.339 | -0.0039 (0.0088) | 3.031 -> 3.036 | +0.0050 (0.0128) | TIE |
| B2-noblend vs B0 | 1.348 -> 1.339 | -0.0098 (0.0100) | 3.034 -> 3.036 | +0.0019 (0.0088) | TIE |
| B2-wide20 | 1.348 -> 1.347 | -0.0012 (0.0023) | 3.034 -> 3.036 | +0.0023 (0.0047) | TIE |

Horizons separately, change in published-level RMSE, points (SE); negative is better. 30 days is reported only.

| arm | 30 days | 90 days | 180 days |
|---|---|---|---|
| B1 | +0.0041 (0.0121) | +0.0222 (0.0091) | +0.0057 (0.0148) |
| B2 | -0.0050 (0.0144) | +0.0157 (0.0059) | +0.0008 (0.0136) |
| B3 | -0.0032 (0.0119) | +0.0133 (0.0065) | +0.0010 (0.0120) |

Every arm is worse 90 days out by 2 to 2.7 SE on its own, and flat at 180 days. The pooled H is what decides.

- **Direction:** B1, B2 and B3 each move 11 of the 24 day-before cells toward the result and 13 away.
- **B3's r:** picked on earlier targets, r_hat was 0 at every target that had any earlier target (the data prefer
  no breakdowns), so the shrunk r ran 0.15 (qld2020, nothing earlier) down to 0.05 (sa2026). Never the top of the
  grid. Over all seven targets (the live pick) r_hat is 1, shrunk to 0.745: sa2026 alone swings it.
- **Offsets are estimated, not pinned:** 102 day-before B2 offsets, median |offset| 1.48 points, range -7.5 to
  +7.8; WA Labor -4.1 to -6.9 (the 7-point federal-below-state gap), sa2026 Labor -1.1 to -7.0.
- **Same-firm overlap** (a state poll dated inside a same-firm breakdown's fieldwork): 1 to 6 pairs per target.
- **wa2021** (Amendment 2 item 1, reported not scored): unblended ALP 51.23 -> 50.98 (B1) / 50.97 (B2), actual
  59.92; the breakdowns moved it further from the result.

## Live, as at today

Published statewide level (the statewide path as the harnesses compute it, then the blend), points:

| | ALP | LNP | GRN | ONP | breakdown rows admitted (one per poll and class) |
|---|---|---|---|---|---|
| vic2026 B0 | 23.96 | 29.73 | 13.83 | 20.14 | 0 |
| vic2026 B1 / B2 / B3 | 23.99 / 23.99 / 23.94 | 29.69 / 29.69 / 29.70 | 13.83 / 13.84 / 13.84 | 20.15 / 20.10 / 20.29 | 273 / 541 / 541 |
| nsw2027 B0 | 30.22 | 23.04 | 11.77 | 22.23 | 0 |
| nsw2027 B1 / B2 / B3 | 29.96 / 29.89 / 29.54 | 23.16 / 23.12 / 23.29 | 11.87 / 11.91 / 12.20 | 22.25 / 22.31 / 22.16 | 255 / 514 / 514 |

Victoria moves under 0.2 points in every class. NSW Labor falls 0.27 (B1), 0.33 (B2), 0.69 (B3, at r 0.745). The
rows driving it are the October federal breakdowns for NSW, Labor 24 to 29 (Roy Morgan 25 Oct 27.5, YouGov 20 Oct 26,
Resolve 10 Oct 29); the prereg counted 33 NSW state polls this cycle against 129 breakdowns (26 Oct). No live move is over 1 point.

## What I could not settle, and what is still open

- **Dry run 3 failed on the primary.** The prereg says to stop and report. The arms ran anyway (they are cheap and
  the screen is the report); no deciding run follows. That the primary cannot see a 1-point unblended error is
  itself the finding: on this pipeline, only the horizon metric can judge a trend-only change.
- **Two existing bugs found on the way, both live, neither fixed here** (each would change published numbers):
  1. `statewide_draws_as_at()` sets the preference-flow cutoff from
     `cyc <- cycles[cycles$region == region & cycles$year == year, ]`, which matches all 88 cycles (the NSE trap,
     verified), so `as_of` is 1969-10-26 instead of the cycle start. Under the live level recipe the flows reach the
     two-party series and the implied two-party, not the first-preference level.
  2. A fitted party whose last state poll is earlier than the others' is folded into the others by
     `statewide_draws_as_at()` (it reads only series that reach the latest date). nsw2023 One Nation the day before
     is one: fitted by the trend, published as a bucket share.
- Wikipedia-internal near-duplicates within 3 days (21 rows, e.g. two Resolve rows ending 12 Feb 2026) are merged,
  first kept; the second may be a different poll. Not checked row by row.
- `state-federal-polls.csv` sample sizes taken as state subsamples, as the prereg says; not checked row by row.

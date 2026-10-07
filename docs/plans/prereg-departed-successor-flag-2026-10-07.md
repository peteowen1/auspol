# Pre-registration: split the departed-independent rate by a successor flag

Written 2026-10-07, BEFORE any successor flag has been joined to any result and
before any harness run under the new switch. Pete chose the hand-coded flag over
the signals the model already has (quiz, 2026-10-07), and asked for it to be
"VERY careful about leakage". This file is committed before the coded flags are
read against outcomes.

## The claim

The departed-leader decay (`screened_slopes()`, `R/dev_slope.R:351`) gives every
successor to a departed independent the same rate (IND 0.38, about 0.6 after
renormalisation). Real retention runs from 0.08 to 0.59 in the cases walked so far,
and the two refused hold arms (`reviews/departed-hold-sweep-2026-10-05.md`) failed
because one rate cannot fit both the successor who fades (Waite sa2026 Gargett,
Pascoe Vale vic2022 Bolton, Lyne fed2013) and the one who holds (Kavel sa2026
Schultz, Mount Gambier sa2026 Fatchen, Indi fed2019 Haines). The claim is that
facts public before polling day separate them: endorsement by the departing
member, local elected office, backing by a community-independent group, or
having worked for the departing member.

**Disclosed:** the flag's four components were chosen after seeing the four
2026-10-07 walk cases and the six named in the hold sweep. They are generic
categories and not tuned to those seats, but the choice was not blind.

## Population

`output/departed-ind-successors.csv` (`scripts/build_departed_successors.R`):
every (election, seat) where the previous election's leading IND polled at least
10%, did not stand in this seat again (keyed on the person, not the class), and
at least one IND candidate stood. 85 cells, 21 elections, 82 with a result
(3 are vic2026, live). 12 leader seats dropped out because they were renamed by
redistribution. Retention (IND total now / IND total before): median 0.43,
quartiles 0.20-0.80.

**Excluded from the arm** (the decay keeps today's behaviour): cells where an IND
candidate is a sitting or former MP (`prior_mp_in_our_data`, verified by the
coder: Cregan Kavel sa2022, Ellis Narungga sa2022, Bedford Newland sa2022,
Duluk Waite sa2022). Their vote is the defector machinery's question.

## The flag, and how leakage is kept out of it

Coded per candidate in `external/reference/successors/departed-ind-successors.csv`
from `external/reference/successors/coding-input.csv`
(`scripts/build_successor_coding_input.R`):

1. **Outcome-blind input.** The coder sees election, polling day, seat, the
   departed member and every IND candidate, alphabetically. No votes, no
   elected flag, no retention. It is not ordered by votes, because picking the
   top-polling independent as "the successor" would itself be the outcome.
2. **Outcome-blind coder.** Barred from results pages and from `output/`, told to
   record no result, and given the same minimum searches for every candidate,
   because winners have more coverage afterwards and uneven effort leaks the outcome.
3. **Dated sources.** Every TRUE carries a source URL and a publication date. A
   build check (`source_date < election_date` on every TRUE) must pass or the
   flag file is rejected. A fact found only in post-election coverage is FALSE.
4. **Audit before use.** Ten TRUE rows drawn at random (seed 20261007) are
   opened by hand, with date and quote checked, before the flags are joined to
   outcomes. One misdated source fails the audit and the coding is redone for
   that coder's whole batch.
5. **Cell flag, outcome-blind aggregation.** A cell is `strong` if ANY of its IND
   candidates has any component TRUE, otherwise `weak`. No candidate selection
   by votes anywhere.

## The rule

Switch `AUSPOL_DEPARTED_SUCCESSOR`, default `"0"`. One arm, `"1"`:

- The departed decay's rate becomes per cell: `r_strong` or `r_weak`.
- **Fitted time-forward, never leave-one-out.** For a target election T, the
  rates use only cells whose polling day is strictly before T's
  (`election_dates()`). Retention is the ratio of means, `sum(IND now) /
  sum(IND before)` over the group, the same definition the 0.38 used.
- **Shrinkage, no cliff.** Each group's rate is partial-pooled toward the
  time-forward pooled rate `mu_T` across both groups:
  `w_g = tau^2 / (tau^2 + se_g^2)`, `r_g = mu_T + w_g (est_g - mu_T)`, with
  `se_g` clustered on election and `tau^2 = max(0, var(est_g) - mean(se_g^2))`.
  With two groups `tau^2` is poorly estimated (CLAUDE.md shrinkage limits); the
  printed weights are read before the result. A group with no earlier cells
  takes `mu_T`.
- **Held through renormalisation** (`renorm_hold()`), so the rate that reaches
  the forecast is the rate that was measured, which is the mismatch named in
  `prereg-departed-hold-fixed-2026-10-04.md`. A permitted successor (screen
  fires) keeps today's 1.0 path, untouched.

**A leak the arm cannot remove, named in advance.** The shipped 0.38 itself was
measured on all 305 corpus cases, later elections included
(`reviews/departed-leader-retention-2026-09-15.md`). When T has no earlier cells,
`mu_T` falls back to the 0.38, so the earliest elections inherit that leak in both
the baseline and the arm. Results are reported with and without the
pairs whose `mu_T` falls back. Making the 0.38 itself time-forward is a separate
change, flagged to Pete.

## Named cases, chosen before running

Expected to improve if the claim is right: Waite sa2026, Pascoe Vale vic2022,
Lyne fed2013, New England fed2013 (if their successors code weak); Indi fed2019,
Kavel sa2026, Mount Gambier sa2026 (if strong, and only if `r_strong` is fitted
above the current effective ~0.6). The flags are not known yet; if a named seat
codes the "wrong" way, that is reported, not re-coded.

## Criterion, in order

Screen first with `scripts/quick_arm.R` on the pairs containing cells; the
deciding run is the full 20,000-sim arm at `AUSPOL_XGB_PRIMARY=0` plus the
retrained-xgb arm.

1. **Primary, targeted.** Mean absolute primary error on the IND cell of every
   non-excluded cell in a wired harness, before vs after. Must fall by more than
   one SE, clustered on pair.
2. **The other cells of those rows** must not worsen by as much (vote moved,
   not fixed).
3. **Do-no-harm.** Pooled seat log loss (`scripts/pool_backtests.R`) and
   actual-weighted primary RMSE each not worse by more than one SE (cluster = pair).
4. **Byte-identical** in every row without a departed cell.

## What would make an apparent win unacceptable

- IND win probability falling on net in departed cells where an independent won
  (the disqualifier that refused both hold arms).
- More than half the primary gain from two seats.
- Any TRUE flag failing the source-date check, or the audit finding a misdated source.
- The gain disappearing on the pairs whose `mu_T` does not fall back to 0.38.
- A gain at `AUSPOL_XGB_PRIMARY=0` that reverses once xgb is retrained on the new
  `base_pred`.

## Reach

Harnesses that call `screened_slopes()`: fed, nsw, qld, sa, vic. WA does not
(grep 2026-10-04), so WA cells are used to FIT the rates (earlier-dated only) but
are not changed; the commit says so. `scripts/fit_seats_full.R` is wired in the
same change, and reaches the published number via `base_margin`. The live
vic2026 cells (Benambra, Shepparton, Hawthorn) need flags coded from current
coverage.

## Decision rule

Criteria 1-4 pass and no disqualifier fires: ship (`published_flags.R`,
`docs/MODEL-REGISTRY.md` in the same commit). Anything else: off, and the case
table goes to Pete.

## Amendments

None. Any later amendment is added below this line, with the original text
left unedited.

### Amendment 1, 2026-10-07, written BEFORE any flag file has passed the gates or been joined to a result

1. **Source.** The first coding (agent web search) was REJECTED on leakage
   grounds and quarantined as
   `external/reference/successors/departed-ind-successors.websearch-REJECTED-2026-10-07.csv`:
   16 of its 26 TRUE rows had missing, vague or post-election source dates, and
   the TRUEs concentrated on candidates later famous for winning (search
   coverage follows the outcome). Flags are now coded ONLY from the ABC
   election-guide seat page as archived by the Wayback Machine, using the latest
   capture strictly before polling day (resolved through the archive's index with
   a `to=` cap, served timestamp asserted), raw HTML kept under
   `external/reference/successors/abc-guide-raw/`
   (`scripts/fetch_abc_guide_snapshots.py`). The coder reads only the extracted
   profile text, with no web access. One fixed source per seat makes effort equal
   by construction, and a page saved before the vote cannot contain the result.
2. **UNKNOWN is not weak.** A cell with no TRUE where any candidate is UNKNOWN on
   every component (no guide, no pre-election capture, or no profile) is
   `unknown`. It is excluded from the fit and from the arm, and keeps today's
   behaviour. Treating it as weak would mix era with source coverage. The fit
   prints the group counts by era (before 2013 / 2013 on) before any rate.
3. **Dates strict ISO.** Each source date must be exactly `YYYY-MM-DD`.
   Prompted by review (as.Date accepted trailing text).
4. **Measured post-xgb.** "Deciding run at `AUSPOL_XGB_PRIMARY=0` plus the
   retrained-xgb arm" is replaced by the path the 2026-10-06 shipped fixes used:
   the arm runs at the published `AUSPOL_XGB_PRIMARY=1` with
   `AUSPOL_XGB_BASE_DELTA=1`, which carries the base-layer change through the
   cached as-at predictions. `AUSPOL_DEPARTED_SUCCESSOR` is registered in
   `post_xgb_switches()` and set to 0 in `rebuild_forecasts.sh` stage 1, so the
   trees never train on it. Criteria 1-4 and the disqualifiers are unchanged.

### Amendment 2, 2026-10-07, written BEFORE any flag is coded (Pete chose to widen the source first)

The ABC pre-election guide pages cover 38 of the 85 cells (33 with every candidate profiled):
none for qld2020, vic2018, vic2022 (Pascoe Vale, Morwell), and little for NSW and WA. A
second fixed source is added, read the same leak-proof way:

- **Wikipedia, at the last revision strictly before polling day** (MediaWiki API,
  `rvstart` = 23:59:59 UTC on the day before polling day, `rvdir=older`, `rvlimit=1`; the
  revision timestamp is stored and asserted). For each cell: the seat's article; the
  election's candidates-list article (seat section); and the article of each candidate
  **only if the pre-election revision of one of those two pages links to it**. No title
  search, which could reach an article created because the candidate won.
- **Raw wikitext is kept**; the coder sees extracted text only, with no web access.
- The coder reads both sources for every cell where both exist, and records which source
  supports each TRUE. Coding rules, the dated-source gate and the audit are unchanged (a
  revision timestamp is the source date).
- Disclosed: candidate articles exist more often for prominent people. That is pre-election
  prominence, a legitimate signal, not the outcome; but the flag can now partly measure
  "has a Wikipedia article", and the review will report how many TRUEs rest on a
  candidate article alone.
- Fetched before any coding; cells with neither source stay `unknown` and are excluded.

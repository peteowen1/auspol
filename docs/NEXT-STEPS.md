# auspol — work queue

## MORNING READ, 2026-09-16 — the NSW failure is a VARIANCE fault, and it needs you to build

Overnight, working the seats where we lose most log loss to AE Forecasts.
Full write-up: `docs/reviews/nsw-departed-member-2026-09-15.md`.

**Across both NSW pairs, a seat held by 5+ points whose previous winner is not
on the ballot is called WRONG 26.2% of the time (11 of 42) against 1.8% when
the member stands again.** Found on nsw2023, confirmed out of sample on
nsw2019 (z = +3.89). Margin does not explain it — the effect is *largest* in
the safest seats, 15x on seats held by 12+.

**The cause is variance, not bias.** The held party's own primary error spreads
from sd 5.17 when their member stands to **8.81** when they go (NSW; federal is
1.06x, other states 1.22x). The level shift is only 2.77 points. Meanwhile
`simulate_seat_contests()` applies **one `seat_sd` to every seat in the
chamber** — `R/seat_sim.R:575-589` builds a per-PARTY vector, not per-seat. So
these seats get an ordinary seat's spread, the margin says safe, and we publish
0.95 where the honest number is nearer 0.75.

**ONE FIX WAS BUILT AND MEASURED OVERNIGHT, AND REFUSED.**
`docs/plans/prereg-departed-member-width-2026-09-16.md`, pre-registered and
committed before it ran. It rode the existing per-cell sd path
(`AUSPOL_SD_DEPARTED`, no C++ change) and widened ALP/LNP cells in departed
seats only.

| | bar | result |
|---|---|--:|
| primary, 42 target seats | improve 0.05 | 0.9293 → 0.9040, **−0.0253** |
| **gain confined to nsw2023** | must not be | **it is** |
| the 31 seats we call RIGHT | cap +0.62 | +0.609 |

| pair | targets | baseline | arm |
|---|--:|--:|--:|
| nsw2019 (out of sample) | 19 | 1.3641 | **1.3643** |
| nsw2023 (where found) | 23 | 0.5702 | 0.5238 |

**Why it failed is the useful part.** All four of nsw2019's wrong target seats
were won by a MINOR party — Shooters in Barwon, Orange and Murray, an
independent in Wagga Wagga — and the arm widens the majors. nsw2023's were six
of seven majors, so it helped there and nowhere else. The risk in a departed
seat is not "the other major does better", it is **"somebody else wins"**, and
which somebody differs by election.

**KEPT from that run:** `departed_i` replaces `retirement_i` in the sd model.
Clean A/B, same corpus and seed, one column: held-out Gaussian NLL
1.3096 → **1.3012**. `AUSPOL_XGB_PRIMARY_SD` is still 0 so nothing published
moved.

**YOUR CALL, one thing left (items 1 and 2 resolved 2026-09-16):**

1. ~~The next arm~~ **DEAD for the nsw2019 four, confirmed 2026-09-16.**
   Dumped the primary model's own point estimate for Barwon/Orange/Murray/
   Wagga Wagga: it missed the eventual OTH_RIGHT/IND winner by 30-40 points on
   the MEAN, not just the width — no `seat_sd` widening fixes that. Chased it
   into a real bug (`is_incumbent_party` silently FALSE on every minor-party-
   held seat, 9 seat-elections across 6 regions — see
   `docs/reviews/incumbent-classification-bug-2026-09-16.md`), fixed it,
   measured it: pooled OOF RMSE improved 3.8217→3.8078 (kept), but the 9 named
   targets did NOT move (8.398→8.433, noise) — Orange still predicts OTH_RIGHT
   at 7.8% against an actual 56.2%. **The real question is now: what explains
   an idiosyncratic 40+ point personal vote the model has no feature for?**

   **ANSWERED 2026-09-16: `own_prev_pcv` already does this well, and it's
   `NA` for exactly the two worst misses.** Where populated (Mayo,
   Hinchinbrook, Kennedy — ordinary returning candidates from a prior
   GENERAL election), the model lands within 1-10 points of actual. Orange
   and Wagga Wagga are both `NA` — their current members won by-elections
   (2016, 2018), so `personal_prior_vote()`'s general-to-general matching
   never finds them, and the model falls back toward baseline: Orange
   predicts OTH_RIGHT at 7.8% against an actual 56.2%. Checked whether the
   anchor clone has by-election candidate data to fall back to —
   `external/aus-polling-analyser/analysis/Data/by-elections.csv` exists but
   is the wrong shape (87 rows total, seat-level SWING only, no candidate
   names or vote shares, and its one Orange row is 1996, not the relevant
   2016 event). **No candidate-level by-election result exists on disk for
   any jurisdiction.** This is a genuine fetch gap, not a parsing one — find
   the NSWEC by-election results pages for Orange 2016 and Wagga Wagga 2018,
   parse candidate-level primaries (same shape as `fetch_transfers_nsw.R`),
   feed into `personal_prior_vote()`'s fallback path.

   **BUILT AND MEASURED 2026-09-16, DOES NOT HELP.**
   `scripts/build_nsw_byelection_prevpcv.R` fetched and parsed both pages
   (Orange SB1602, Wagga Wagga SB1801 — real NSWEC results, validated exactly
   against Wikipedia: Donato 23.76%, McGirr 25.42%), wired as a fallback into
   `own_prev_pcv` only where it was `NA`. Retrained, measured against the
   incumbent-fix baseline:

   | | Orange xgb_pred | Wagga xgb_pred | pooled OOF RMSE |
   |---|--:|--:|--:|
   | before | 7.82 (actual 56.2) | 11.37 (actual 46.1) | 3.8078 |
   | after | 8.10 | 11.13 | **3.8158** |

   **Neither target moved and the pooled corpus got measurably worse** — 10+
   seats in completely unrelated pairs (Hunter, Fremantle, Morwell, Roe,
   Giles, none NSW, none by-election seats) each lost 2.3-4.0 points, almost
   certainly because filling 2 of 13,739 rows shifted `own_prev_pcv`'s global
   histogram bin boundaries in xgboost's tree construction — a real
   perturbation with no offsetting benefit. **Two real data points can't
   teach a tree ensemble anything on their own; this needs a different
   mechanism (e.g. a dedicated by-election-origin feature/flag), not a blind
   fill into a shared column.** Reverted the wiring in `fit_xgb_primary_v6.R`
   (back to the incumbent-fix-only state, 3.8078). **Kept**: the parser
   script and its validated numbers (both hardcoded checks pass) — a real,
   reusable asset for whoever revisits this with a better mechanism. Not
   pursuing further tonight.
2. ~~Region or optional preferential voting?~~ **RESOLVED 2026-09-16: it is
   region, not OPV.** Parsed the exhausted-votes line off all 186 cached NSWEC
   distribution pages (was on disk, discarded at parse time — see
   `docs/reviews/unparsed-preference-detail-2026-09-15.md`). Exhaustion is
   real but small (11.0%→13.3% departed vs stood, p=0.010) and does not
   discriminate the seats we call wrong from the ones we don't (13.24% vs
   13.30% within the departed cohort). It also cannot be the mechanism at all:
   the measured variance blowup is in the held party's FIRST-preference share,
   settled before any redistribution happens, and exhaustion is a
   later-round phenomenon. Full writeup:
   `docs/reviews/nsw-departed-member-opv-ruled-out-2026-09-16.md`. The
   correction should key on region/member-type, not voting system.
3. **Is a per-seat `seat_sd` worth the C++ change?** The per-cell sd path was
   the cheap route and it is class-scoped; a genuine per-seat multiplier means
   changing `src/seat_sim_core.cpp`, which every harness and the live Victorian
   forecast run through. Not started — that one gets designed with you.

**REFUSED on measurement, so you do not have to wonder:** filling in the missing
`retirement` feature. It is 0.0% populated on **eleven of twenty-three pairs**
(every federal pair to 2016, qld2020, vic2014, vic2018, every WA pair before
2025), which is a genuine label-leak defect — but the effect on those pairs is
**-0.09 points, t = -0.16**. A mean correction cannot fix a variance fault.
`scripts/build_retirement_derived.py` now derives the column for all 21 pairs
anyway (93% agreement with the anchor, and it catches mid-term departures the
anchor cannot see — Tudge, Morrison, Robert, Murphy).

**Also done overnight:** fed2022 re-run under `AUSPOL_STATE_DEV`, which had
shipped seven hours after that backtest was taken. Every WA seat improved
(Tangney 3.53 → 3.11, Swan 0.62 → 0.49); pooled 0.2701 → **0.2696** against
AEF's 0.2808 over 660 seats. The ledger artifact is refreshed to v13 and now
picks the newest non-arm backtest per pair, so that staleness cannot recur.

## 2026-09-15 later — demographics: the signal is REAL, the correction is too small

Two pre-registrations run and both refused, but the second one refused on
magnitude, not on whether the effect exists.

`docs/plans/prereg-education-residual-correction-2026-09-15.md` — one census
column (`yr12_pct`). Criterion passed, placebo condition fired, REFUSED. The
placebo was mis-specified: `born_aus_pct` correlates **-0.706** with `yr12_pct`
over 1,989 seats, so it was a second reading of the same axis, not a control.

`docs/plans/prereg-demographic-axis-2026-09-15.md` — all seven census columns
under a leave-one-pair-out elastic net, 22 pairs, 2,066 seat-elections. Pooled
seat log loss 0.2849 → 0.2831, **-0.0018**, 14 of 22 pairs improved
(t = -1.83, p = 0.08; binomial p = 0.143). REFUSED: qld2024 worsened by
+0.0024 and it is one of three named One Nation pairs.

**The permutation control is the thing to keep.** Permuting which seat gets
which seat's demographics lands the model on the baseline every time — sa2026
mean 0.3576 against a 0.3577 baseline over 8 draws, and within 0.0004 on all
three Victorian pairs — while the real arm sits 0.005 to 0.012 better. **The
demographic axis carries genuine seat-level information.** Use this control for
anything in this family; a correlated second column is not a placebo.

**Why it still failed, and the next hypothesis.** On sa2026 One Nation it
helped in **10 of the 10 worst-missed seats** and by about half a point where
the gap is seven to eleven — MacKillop 23.8 → 24.3 against an actual 35.3. One
coefficient per class is fitted across a corpus where most elections have a
tiny One Nation vote, so it cannot move a seat far enough in an election where
the party polls 23% statewide. A **level interaction** is the obvious fix and
needs its own pre-registration; fitting it now would be choosing the model
after seeing the result.

**Shipped regardless, and it was a real defect**: `census-features.csv` was
keyed on the previous election's feature file, so redistributions stranded
seats at both ends. `vic2026` had **no census rows at all** and now has 88 of
88; nsw2023 went 88 → 98, fed2022 149 → 152, and partial application unblocked
all seven WA pairs. Demographics could not have reached the live forecast by
any route before this.

**Still open**: `fit_seats_full.R` has no call site for either correction, so
nothing here touches the published forecast yet.

## MORNING READ, 2026-09-15 — the Victorian draft is done, three things need you

Full writeup: `docs/reviews/vic2026-first-correct-draft-2026-09-15.md`.

**The forecast, against AE Forecasts** (expected seats, their NAT folded into
our LNP): LNP 41.63 vs **32.86**, ALP 28.12 vs **34.09**, ONP 9.00 vs
**14.51**, GRN 4.60 vs **5.32**, IND 4.38 vs **0.22**. 19 of 87 seats called
differently. One Nation favourite in 7 seats for us, 0 for them.

**1. The independent under-call is now the biggest gap.** 0.22 against AEF's
4.38. Nothing overnight touched it and it is the largest proportional
disagreement in the table.

**2. One Nation at 14.51 is the number to argue about.** AEF under-called One
Nation badly in sa2026 (1 of 4 seats, favourite in none) — but our own
override was ALSO measured worse there than no override (4 of 4 correct off, 1
of 4 on). Both cannot be right and the corpus has exactly one election where
One Nation has won a seat.

**3. The backfill shipped against a worse backtest, on my judgement.**
`AUSPOL_HISTORIC_ELECTED_BACKFILL=1` costs 0.0141 pooled RMSE. The reasoning:
vic2026 is the target and never a training pair, so the 62 returning members
can only move the live forecast and never the RMSE — the backtest cannot see
the gain it is being weighed against. Reversible in one flag if you disagree.

**Not done, needs you**: the PR. 15 commits on `dev`, CI green, all reviewed.
Merging to `main` is yours per the standing rule.

## RESOLVED overnight 2026-09-14/15

- `historic_elected_i` fed as NA to the live model, deflating every prediction
  ~45% behind renormalisation. Fixed, written up in
  `reviews/live-path-missing-feature-2026-09-14.md`.
- Victorian candidate list in (379 candidacies, 88 districts), which unblocked
  `DS2` (0 → 87 seat-classes), `DS2o` (0 → 22) and `DS3` (flat → 30 seats).
- `DS2` was inert because Wikipedia's "Nina Taylor" and our "TAYLOR, Nina"
  resolve to opposite surnames. Worth 4.4 Labor seats.
- Review findings: Mac/Mc surnames inverting NSW rows; the forced-value
  detector blind to a multi-line `Sys.setenv`.

## SUPERSEDED, 2026-09-14: every Victorian number measured that day is stale

`historic_elected_i` was being fed to the live model as `NA`, a value it had
never seen, deflating every prediction ~45% and hiding it behind
renormalisation. Fixed (`88653b4`), and the training data it comes from was
then backfilled for all 21 state elections (`4e5fde4`). **The model has not yet
been refitted on the corrected data**, so:

- **Do not quote any Victorian figure from before this is retrained.** ALP
  expected seats went 39.49 → 29.95 on the live fix alone, and will move again.
- The seven-pair override on/off comparison (AEF corpus, pooled ON 0.2702 vs
  OFF 0.2864) was measured on the old OOF file and must be rerun.
- The `shipped-models` release holds a model trained with the feature
  constant-zero for every state election. Re-upload after refitting.

**Order**: `fit_xgb_primary_v6.R` (rebuilds features + leave-one-pair-out OOF)
→ `fit_xgb_primary_v6_final.R` → re-upload both to the release → rerun the
seven pairs both ways.

**Still to do after that (step 3)**: Victoria 2026 has no candidate list, so
`DS2`, `DS3` and `own_prev_pcv` all fall back. Wikipedia publishes one
(`Candidates_of_the_2026_Victorian_state_election`). Do NOT do this before the
retrain — populating Victoria while the other 21 state elections carry the old
constant would make it the only state row with non-zero values, which is the
same out-of-distribution fault in reverse.

### What this cost, so it is not repeated

The bug survived because **renormalisation made it look right**. Shares summed
to 100, One Nation concentrated in plausible regional seats, nothing errored.
Underneath, the model was predicting the Coalition at 6.05% in Melton. The
tell was only visible by comparing raw row sums against the backtest's: 54.3
against 91-105.

Three wrong conclusions were drawn from it before the cause was found — that
the override suppresses One Nation, that it helps minor parties broadly, and
that the SA regression was a modelling disagreement. All were artefacts.

The comment that hid it, at `R/xgb_primary_override.R:132`, read *"both NA
pre-nomination -- fine, same missing-value routing"*. An assumption written as
a reassurance, never tested. It was true of `ballot_pos_min` (60.6% missing in
training) and false of the one beside it.


## OPEN, 2026-09-14: the model registry cannot see a harness that FORCES a switch

`scripts/backtest_candidate_fed.R:78-79` and `_nsw.R:41-42` set
`AUSPOL_SALIENCE_EXPECTED=1` and `AUSPOL_SALIENCE_EXP_SD=1` whenever they are
unset. `published_flags.R` ships both as **`0`**.

So federal and NSW backtest numbers describe a configuration that is not what
ships, and any pooled figure across the six harnesses silently mixes two
configurations. `published_flags.R`'s own promise — "a harness run with no
environment measures what ships" — is false for two of the six.

It was deliberate (`01c8e1c`, "Ship arm C (salience point estimate + variance),
scoped to federal and NSW"), so the code is not the bug. **The bug is that two
authoritative documents say otherwise and neither records the scoping**:

- `published_flags.R` lists both at `0` with no mention of the exception.
- `docs/MODEL-REGISTRY.md:103` states the arm is undecided "so the switch is
  off everywhere". It is on in two harnesses.

**The registry cannot catch this by construction.** It records whether a
harness *reads* a switch, so a harness that reads it and then forces a
non-shipped value scores a clean "yes". Reachability is not the same question
as value, and the registry only asks the first — which is why the thing built
to stop what-runs drifting from what-ships missed a five-day drift.

**Fix**: teach `scripts/build_model_registry.R` to detect a `Sys.setenv(AUSPOL_*)`
or `if (!nzchar(Sys.getenv(...))) Sys.setenv(...)` in a harness and report the
forced VALUE beside the honoured/not-honoured cell. Then reconcile
`published_flags.R` so the fed/NSW scoping is written down where the default
is. Do not "fix" the harnesses to match the flags file without checking
whether arm C is meant to be live there — the commit says it is.

**Known consequence, not yet sized**: every federal and NSW backtest number
since 2026-09-09 was measured with arm C on. Any comparison that pooled them
with vic/sa/wa/qld results compared two configurations.


## WATCH, 2026-09-14: One Nation's Victorian level sits 2.47 under its polls, 0.03 inside the bound

**NOT currently breaching. An earlier version of this entry said 2.85 and
called it a live breach; that number came from a poll clone 19 commits and
four weeks stale.** See the stale-data note at the end of this section — the
process failure is the more useful finding.

Current, on poll data to 2026-08-12 (agrees with CI exactly):

| party | fitted | polls (90d, n=12) | gap |
|---|--:|--:|--:|
| **ONP** | 20.57 | 23.04 | **2.47** |
| LNP | 28.59 | 28.17 | 0.43 |
| ALP | 24.96 | 24.67 | 0.29 |
| GRN | 12.88 | 13.13 | 0.24 |
| OTH | 10.99 | 10.92 | 0.07 |

`S7` (new, shipped 2026-09-14) runs `poll_tracking_check()` on the trend
`fit_seats_full.R` actually publishes, and reports rather than halting. One
Nation is **0.03 inside a 2.5 bound** — the closest any party has been without
crossing, and worth watching rather than acting on. `20.57` is what
`state_mean` hands to every Victorian seat, so the gap is not confined to the
trend chart.

**Mechanism**: One Nation's prior is its 2022 Victorian result, **0.28%**. The
fit shrinks toward that, and 20 polls this cycle at 11–27% pull it only to
20.57. Same shape as the NSW 2027 One Nation breach, which IS a live red stage
— a near-zero prior against a surging party.

**The investigation Pete approved was ALREADY DONE, and it answers the other
way.** `docs/reviews/poll-lag-2026-08-19.md`, run against a pre-registration
committed before measuring:

- Across **139 party-cycles** the trend sits below recent polls in 88 of them.
  Minor parties are systematically shaded: OTH **−1.19** on 33 cycles, ONP
  **−1.40** on 3. Majors are tracked almost exactly.
- Following the polls instead is **not** better: MAE 1.755 vs the trend's
  1.862 — **1.03 clustered standard errors**, inside the pre-registered 2 SE
  band. RMSE 2.376 vs 2.387, a tie.
- The single historically analogous case, **WA 2017 One Nation**: prior 0.00,
  polls 10.3, fitted 7.8, **actual 4.9**. The lag helped a great deal and was
  nowhere near enough.
- Across all three near-zero-prior ONP cycles the mean error is **+1.42 — we
  OVER-state One Nation**, and in both near-zero-prior cases the polls
  over-stated it far more.
- **The day-0 anchor was never the mechanism.** `ANCHOR_K` (`R/trend.R:82`,
  fixed at 0) was built and refused on exactly the theory above. WA 2017 had a
  prior of 0.00 and the model fitted 7.8 — it left the anchor far behind.

**And the gap is converging** (measured 2026-09-14, refitting at each ONP poll
date, on the stale clone): −3.97 at 8 polls → −4.13 at 15 → −2.85 at 19, and
**−2.47 at 20** on fresh data. Trend is toward closing as polls accumulate,
which is a fit converging. It sat OUTSIDE the bound for most of the cycle and
has just come inside it, so the direction of travel is the reassuring part,
not the current margin. At 6–7 polls One Nation was **dropped from the
published fit entirely** (`min_polls = 8`), with OTH absorbing it — the
dropped-party path `S7` also asserts on, and it happened on this cycle.

**So there is no ONP fix to make, and these are all forbidden:**

- `sigmas = "per_cycle"` for Victoria — measured not better (0.2% held-out
  gain, 33x runtime), and reaching for it to buy margin on a bound is
  criterion-fitting.
- Raising `POLL_TRACKING_BOUND` (it re-derives to 2.5 today), raising
  `min_polls` from 3 to 4, or lowering the separability gate from 20 — all
  three explicitly forbidden by
  `docs/plans/prereg-poll-tracking-bound-scaling.md`.

**What is actually left is a judgement, and that plan already handed it to
Pete** — now with a second instance. Its aborted question was whether the
bound should SCALE with how thin a party's polling is; it stopped at **19
cycles against a pre-registered floor of 20** and cannot re-run until another
election completes. Meanwhile both red stages, NSW 2027 and Victoria 2026, are
the same shape: a near-zero prior against a surging minor party. The options
it names are leave it red, report rather than halt, or mark the trend
unreliable where it is used.

**The new consideration it did not have**: `.github/workflows/forecast.yaml`
now opens a tracking issue on every failed scheduled run (added 2026-09-13).
A permanently-red nightly plus an automated issue is how an alarm becomes the
thing people learn to ignore — which is the failure that workflow's own
comments were written to prevent.

**Why nothing caught this before**: `poll_tracking_check()` was wired into
`fit_vic.R`, `fit_federal.R` and `fit_nsw.R` — every fit script *except* the
one that publishes. All three fit with `sigmas = "per_cycle"`; the published
call takes the defaults, and the two produce different numbers for the same
party on the same polls, so a green `L3` was asserting on a model nobody
ships. Full note under "Where the guards are" in `ARCHITECTURE.md`.

### The stale-clone failure, which is the more useful finding

Every poll-derived number quoted in this session before 17:40 came from
`external/aus-polling-analyser` **19 commits behind, last pulled 2026-08-16**.
Nothing warns about this: the clone is a plain git checkout, `load_polls()`
reads whatever is on disk, and the row count it prints (`polls[vic]: 606
rows`) looks exactly as healthy as a current one.

It changed a verdict, not just a decimal. On the stale clone One Nation was
2.85 off its polls and **breaching**; on current data it is 2.47 and **inside
the bound**. A whole entry here described a live breach on the published
Victorian forecast that does not exist. CI was right the entire time, because
the workflow clones the anchor fresh on every run — the divergence was
visible in both logs as `606 rows to 2026-08-08` against `607 rows to
2026-08-12` and went unread.

**So: `git -C external/aus-polling-analyser log -1` before quoting any poll
number, and treat a CI/local disagreement as data staleness until proven
otherwise.** Same rule this repo already applies to release assets, whose
`createdAt` lies about freshness, and the same shape as the memory note about
dated docs being snapshots.

## OVERNIGHT CONTINUATION, 2026-09-14 early morning — READ THIS FIRST

Pete went to sleep mid-session; this continued autonomously per
`~/.claude/CLAUDE.md`'s Autonomous Sessions rule. Nothing committed, nothing
destructive. Full writeup: `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md`.

**The headline result**: traced sa2026's worst miss (One Nation) all the way
through the pipeline via SHAP, four separate seats/parties in a row, to the
same place — `base_pred` (the pre-xgboost seat-level forecast) dominates every
prediction (~89% of tree gain) and nothing downstream of it (census
demographics, retiring-MP tenure, a party-group-split model) can compete.
Traced ONP's `base_pred` formula by hand for Narungga and found the actual
bug: `dev_slope()`'s rank-preserving deviation model cannot express a seat
going from modestly-above-average to the state's strongest seat, which is
exactly what happened. **Found an existing, already-built fix
(`AUSPOL_ONP_CONC_SD`) sitting unused for sa2026** — tested it, confirmed a
real 18% log-loss improvement on the raw model, then verified it survives a
full retrain into the actually-shipped xgboost configuration (0.4339 -> 0.3577
seat log loss, 39/47 -> 41/47 seats called correctly). **UPDATE, full
six-harness sweep now done**: NSW/QLD/WA/FED all unaffected (noise-level),
but **VIC2022 is a real regression** (72/78 -> 69/78 seats, log loss +6.3%),
traced to the retrained model over-predicting IND broadly across VIC2022 --
the same "vic2022 IND/OTH_RIGHT degeneracy" pattern already named in
`fit_xgb_primary_v6.R`'s own diagnostics, now shown to interact with this fix.
**NOT a clean win — a real trade. Not ready to ship.** Full detail and
recommended next steps: `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md`.

**Renamed the confusing xgboost column names** (`level_now`->`level_pred`,
`pred_share`->`base_pred`, `x`->`seat_prev_pcv`) per Pete's request — verified
byte-identical behaviour before/after. Also fixed a real bug in
`fit_xgb_primary_v7.R`: a hardcoded arm-name list silently reported any new
arm as "did not run" even after it trained successfully.

**Not yet done, in priority order**:
1. Understand and fix the VIC2022/IND coupling before this can ship at all —
   see the review doc's Recommendation section for candidate approaches
   (regularisation, region-scoped IND feature, re-run the vic2022 IND SHAP
   breakdown against the retrained model).
2. MacKillop's federal/state boundary mismatch — its federal ONP vote ranks
   it 15th of 47 SA seats but its actual result is 2nd-highest; no CV setting
   fixes this, worth checking the actual boundary maps.
3. Once 1 and 2 are resolved, decide whether to default
   `AUSPOL_ONP_CONC_SD=9.18` in `published_flags.R`.
4. Review and commit: the rename (this session), the `ran`-list bug fix, and
   the still-uncommitted items from the evening before (NSW exhaust wiring,
   `build_level_components.R`, `build_retiring_mp_cases.R`).

## CURRENT STATE, 2026-09-13 evening session — START HERE

**Two real fixes shipped and composed correctly** (commits `75a5076`,
`8db4305`, `cea78e2`, `a8af56b`, `f3c4b3e`, `75462ea`): the Frome->Ngadjuri
seat-rename bug; the notional (redistribution-adjusted) prior for federal
seats, on by default now regardless of aggregate effect (Pete's call — "the
right thing to do... do the Antony Green ABC method"); and `ret_exp` (the
IND retention feature), confirmed real at two seeds before shipping. A bug
from composing the two carelessly (x_notional_adj leaked into ret_exp's
model as a jurisdiction label, tanking sa2026 to 0.5061) was caught and
fixed same session. **Current state: pooled log loss 0.2914 over 23 pairs
(was 0.2984); on the 7 AEF-comparable elections, ours 0.2743 vs AEF's 0.2851
(was −0.0049, now −0.0108).**

**Next queued: Pattern A from the worst-seats review below.** Full
five-pattern analysis of the current worst-15-vs-AEF table:
[reviews/worst-seats-five-patterns-2026-09-13.md](reviews/worst-seats-five-patterns-2026-09-13.md).
Pattern A — a SENIOR retiring MP (minister/leader) loses more personal vote
than the flat retirement discount assumes — explains 5 of 15 seats (Monaro/
Barilaro, Braddon/Pearce, Riverstone/Conolly, Richmond/Wynne, Parramatta/
Lee) and is the cheapest lever: a static, hand-curated feature, no new data
fetch, extends `fit_defector_discount()`/the MP-slope tier directly. **Size
it (case count, effect size) before building.** Other four patterns
(SA One Nation surge broader than known; a defecting incumbent fragmenting
the right three ways; a departed independent's vote reverting rightward,
untested direction for `ret_exp`; QLD optional-preferential flows against
the primary leader) are recorded in the review doc, not yet actioned.

## Session 2026-09-12/13 (earlier), morning/day — rolled to journal below

**PR #34 MERGED to `main`** (6b51957). sa2022 is now in the model
(`docs/reviews/sa2022-missing-from-the-model-2026-09-12.md`) — a name-order
parsing bug meant it was scored but never trained on.

**The big find: `fit_xgb_primary_v6.R` was training on its own recycled
output.** `AUSPOL_XGB_PRIMARY=1` (shipped default) makes every harness
overwrite `shares` with `v6`'s own prior predictions before simulating, and
the simulator writes `pred_share` — what `v6` calls "the shipped baseline" —
from that already-overridden result. Repeated same-session refit cycles
compounded this and drifted a pair's log loss 0.5384 → 0.8126 with zero code
changes. Full trace and the fix:
`docs/reviews/xgb-primary-circularity-2026-09-13.md`.

**Corrected pooled seat log loss, 2,097 seat-elections, 23 pairs: 0.2926**
(PR #34 had claimed 0.3115 — worse than reality, not better; the
contamination was dragging every number the wrong way).

**The circularity is now ENFORCED, not just documented** (PR #36, merged).
Each harness records `AUSPOL_XGB_PRIMARY`'s value in its sharedetail output;
`pool_sharedetail.R` refuses to pool any pair that's contaminated or
unverifiable. Verified with a real contaminate-then-restore test. Review
gate caught the escape hatch logging a false "all clean" when used — fixed,
re-verified.

**New worst pairs, once the numbers were honest: wa2001 (0.6819) and wa2008
(0.6840)**, not sa2026 (0.4597, much improved from the corrupted 0.7015+
seen mid-session). Four specific seats — three of them independents — carry
53% and 41% of those pairs' total loss
(`docs/reviews/wa-independents-no-salience-2026-09-13.md`). First diagnosis
wrongly concluded WA had no salience corpus at all — a `grep` for `"wa"`
missed `geo = "AU-WA"` in `fetch_salience_v6.R`, which has covered every WA
election since 2026-08-27, with real data on disk since 2026-09-10. **Fixed
same session** (`docs/reviews/wa-salience-data-already-existed-2026-09-13.md`):
`fit_xgb_primary_v6.R`'s stale region-wide exclusion now excludes only
wa2001 (predates Google Trends entirely, genuinely no signal possible).
Pooled seat log loss 0.2926 → **0.2915**, 11 pairs improved / 9 worse / 3
unchanged, no catastrophic regression. Shipped (PR #35, merged) — `main` is
at 0.2915. wa2008/Kalgoorlie itself (jump = 0, a sustained pre-campaign
story not a last-minute surge) still not rescued — flagged in advance, still
the worst single seat in the corpus.

**Also done:** `all_election_pairs()` gained `sa2022` (measured cleanly this
time, zero effect on any pair — a documented, verified null, kept for
completeness). Census demographics and the per-cell primary SD model were
both measured properly and don't ship (see the 2026-09-12 review docs).

**The nightly "Forecast refresh" CI workflow crash is fixed** (PR #37,
merged, verified with two real `workflow_dispatch` runs, not just local
simulation) — `estimate_statewide_cov.R` no longer dies when the federal
preferences file is genuinely absent in CI. **It still doesn't complete
end-to-end**: the real run got one stage further and hit a different,
separate wall — `fit_seats_full.R`'s MP-slope tier needs
`output/mp-slope-by-class.csv`, and neither it nor its prerequisite
(`build_candidacies.R`) is wired into the pipeline at all. Trying to add
them surfaced that `build_candidacies.R` has its own *deliberate* hard stop
on VIC 2010 data being absent (permanently true in CI). This is real design
work on a large, careful script — queued as its own item, not attempted
tonight. Full details:
`docs/reviews/forecast-refresh-remaining-gap-2026-09-13.md`.
sa2026's One Nation seat-ranking problem got three honest negative results
(NA-gating, isolated model, same-jurisdiction slope) and is parked — no
same-state precedent exists for a party that didn't contest South Australia
before 2022, so it may not be fixable with this model shape at all.

**Unrelated, flagged not fixed:** the scheduled "Forecast refresh" GitHub
Action is failing on a missing `external/elections/aec-fed-firstprefs.csv` on
the CI runner (`estimate_statewide_cov.R`) — pre-existing, nothing tonight
touched that script.

**PRs #38 and #39 MERGED to `main`** (v0.4.34): the `fit_xgb_primary_v7.R`
WA-salience mirror fix, the `build_candidacies.R` gap-scope correction doc,
and this `NEXT-STEPS.md` trim (63k → 49.5k chars, see below). Everything from
tonight's 5-item list is now closed out: items 1-3 documented/confirmed dead
ends, item 4 shipped, item 5 (this trim) shipped.

## PREVIOUS SESSIONS, 2026-09-10/11 — rolled to journal, open items carried forward

Full narrative (PR #31/#32, the xgb-primary leak fix, the SA2026 governed-
population fix, census correspondence build, seven shipped bugs):
[backlog/journal-2026-09-10-to-11.md](backlog/journal-2026-09-10-to-11.md).

**Still-open items from those sessions, not yet resolved or restated above:**

1. **Four harnesses still swing toward the ACTUAL statewide, not a prediction.**
   `AUSPOL_FORECAST_MODE` exists in fed and sa only; nsw/qld/vic/wa answer a
   different question from federal's. Core logic already extracted into
   `R/forecast_statewide.R` — this is wiring.
2. **The emergence model decision (v4 vs. salience)** — v4's hazard AUC 0.936
   vs. 0.751, sa2026 moves 0.6362 → 0.5891, but it failed its pre-registered
   bar and reads over-dispersed. Deciding test (seat count, 26 of 2,050
   historical seat-elections won by an emerging non-major) not yet run.
   `docs/plans/prereg-xgb-surge-parameters-v2-2026-09-11.md`.
3. **vic2026 re-check after 12 noon, 9 Nov 2026** (nominations close): re-run
   the three salience fetch/build scripts named in `published_flags.R`, and
   extend `build_candidacies.R` to write vic2026 rows so
   `candidate_returns(vic2022, vic2026)` stops erroring and the flow model's
   `dest_same`/`dest_same_mp` features (0.0% populated today) go live.
4. **GDELT** — parked, needs a GCP/BigQuery project first
   (`docs/plans/gdelt-feasibility-2026-09-10.md`).
5. **Census 2011/2006/2001** — correspondence mechanism now exists; 2006/2001
   have no bulk data pack (per-division Excel only).
6. **WA breaks out `NAT` separately and nothing merges it into `LNP`'s
   trend.** WA's OTH bias is +1.71 against Victoria's +0.45 — suggestive,
   within noise at n=7. Same shape as the fixed `LIB`-mislabelling bug, so
   worth an hour. Re-flagged 2026-09-13 — dropped from an earlier trim pass,
   confirmed still genuinely open (no later doc addresses it).
7. **Re-measure the xgb-primary/xgb-flows challengers with TIME-FORWARD
   folds**, not leave-one-group-out. fed2007 being predicted by a model
   trained on fed2025 is optimistic against the shipped baseline by an
   unmeasured amount, and every absolute number in
   `docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md` inherits it. Possibly
   superseded by the 2026-09-13 xgb-primary circularity fix (PR #36) — that
   fix addresses a DIFFERENT leak (training data recycling `pred_share`), not
   this one (fold direction), so re-check whether it still applies before
   running it. Re-flagged 2026-09-13, also dropped from the same trim pass.

## PARKED 2026-09-09, not killed: seat lean from several past elections (decayed)

Pete's idea, tested three ways on real federal 2pp data (140 seats, 4 real
cycles) — decayed average, momentum extrapolation, volatility-bucketing —
**all three found no usable signal** (best case 0.5% RMSE improvement,
statistically zero). Detail and numbers in
`docs/reviews/xgb-primary-challenger-2026-09-09.md`'s final section.
**Untested and still open**: using FEDERAL results as a correlated signal
for a STATE seat's own lean — genuinely different data, not just re-slicing
the seat's own history, needs seat-boundary matching that doesn't exist yet.

## REFUSED 2026-09-09: dispersion-slope arm (corr x sd-ratio for the flat "new" constant)

Two rounds (all 4 classes, then GRN/ONP only). Both failed the pre-registered
pooled-log-loss bar. Full detail: `docs/plans/prereg-dispersion-slope-2026-09-09.md`.
Machinery (`fit_dispersion_slopes()`) stays in the tree, inert.

## DONE 2026-09-09: the partial-pooling sweep, triaged

Pete asked which refused adjustments a pooled model could have saved. **Answer:
fewer than expected — most refusals were correct, and two of my own queued
candidates were wrong.**

| candidate | verdict | why |
|---|---|---|
| `party_sd` | **not a candidate** | Was VOID 2026-08-25, but **re-run 2026-08-26 on 17 clusters and DECIDED** — a tie, effect "real in sign, negligible in size". I had grepped a stale VOID line in the WA harness header. And the per-party question was already asked and correctly pooled: majors 2.37 vs minors 2.31, "within 0.06, a fifth of one SE". |
| first-preference widening | **not a candidate** | The refusal **was overturned and the fix shipped** — `fp_extra_sd = 2.419` in `R/forecast_mode.R`, with a published-effect table in the review. |
| non-major vote regression | **not a candidate** | Refused on **measured** grounds (winners RMSE 2.99 base against 8.55), not power. Shrinkage cannot rescue a measured regression. |
| `fit_defector_discount` cliff | **addressed today** | The `min_n=5` cliff never fired, but the hard `elected==TRUE` exclusion did. Losing defectors now carry 0.142 instead of zero (`prereg-defector-two-rate-2026-09-09.md`, adopted on mechanism). |
| **surge-conditioned slope** | **GENUINE, open — but NOT shrinkage-rescuable the way I first said** | Split by direction (2026-09-09 follow-up), each surge instance is well-measured WITHIN itself (100+ seats, tight SEs): fed2013 OTH_RIGHT (rise, +6.6) slope 1.15 vs stable 0.54, **+3.1 SD**; sa2026 ONP (rise, +19.9) 0.81 vs 0.47, +1.1 SD; qld2020 ONP (**collapse**, −6.6) 0.26 vs 0.47, **−4.3 SD**. Rises amplify the slope, collapses suppress it — opposite signs, both real. Shrinkage needs REPLICATION within a group to estimate how much to trust it; with 1 collapse and 2 rises there is no such group to shrink from, and averaging them under one undirected "surging" flag (my first attempt, morning) launders two real opposite effects into noise. Needs more corpus (more elections), not better fitting of what exists. |
| demographic seat model | **not a candidate** | Was already run (`fit_demographic_swing.R`) and refused on MEASURED grounds, not power: MAE of swing deviation 3.850 (predict zero) vs 4.087 (model) — worse than predicting nothing. The pre-registered subgroup went the other way (better in 4/4 cells) but the review itself refused to act on it: "the improvement is 1-5% of a catastrophic error" (35.99->34.03, both hopeless), and adopting a subgroup win after losing overall is the cherry-pick `CLAUDE.md` already names twice. Shrinkage does not touch a wrong-signed overall effect or a right-signed-but-too-small one. |

### What the sweep actually established

**Zero rescuable candidates, and that is the finding, not a failure of the
exercise.** Every "GENUINE, open" entry I first wrote for this queue turned
out wrong on inspection: the surge slope has a real effect but is the wrong
shape for shrinkage (opposite-signed rise/collapse, no replication within
either); the demographic model was already run and refused on a wrong-signed
overall effect plus a too-small subgroup one, neither of which shrinkage
fixes. Both write-ups above are corrected in place rather than left standing.

The sweep's value was confirming this repo's refusal discipline is well
calibrated — nothing was sitting refused for want of a shrinkage a competent
pre-registration hadn't already tried or wouldn't have caught.

### Still not retrofitted

`fit_conditional_slopes()` (`min_n=40`) and `fit_split_slopes()` (`min_n=200`)
still carry cliffs. Both are default-off arms that were refused, so the cliffs
change nothing shipped — retrofit them if either is ever revisited, not before.

## SESSION 2026-09-09 (AM #3) — candidate/party tracking audit, three fixes shipped

Pete's ask: map out every possible between-election candidate/party
transition (same person same party, same person new party, major->minor
defection, candidate departs entirely, new entrant) and fix what's actually
broken, using Waite (sa2022->2026) and Kiama (nsw2019->2023) as worked
examples. Built `scripts/candidate_scenario.R` (a what-if tool: drop/add/
relabel a candidate in one seat's target-election corpus, see the effect on
`personal_prior_vote()`'s inputs without a full sim) to make this concrete
rather than guessed.

**Shipped, tested (910/910 pass), full 22-pair backtest rerun in progress:**

1. **`fit_defector_discount()`, new, exported.** The major-party-defector
   retention rate (Ward/Kiama's case) was fitted ONCE inline in
   `backtest_candidate_fed.R` (federal pairs only, leave-one-out) while the
   other five harnesses hardcoded a frozen `0.282` snapshot — exactly the
   "fix in one harness, not ported" failure this repo has been burned by
   before (`docs/plans/harness-unification-2026-09-08.md` named it). Now one
   function, pooled across all six jurisdictions via `all_election_pairs()`,
   every harness calls it. Value barely moves (0.277-0.291 depending on
   target vs the old fixed 0.282) — low risk, but the PROCESS was broken
   even though the number happened to be close.
2. **Losing-major-party defector (Pete's "unseen example" — a losing LNP MP
   moving to ONP) now has an explicit, evidenced comment instead of an
   implicit side effect.** `candidate_returns()` already correctly flags the
   identity match; `personal_prior_vote()` deliberately gives no floor
   because the non-member analogue of the discount has only 5 corpus cases,
   mean retention 2.32 / sd 4.38 — unusable, not a gap.

**Built, tried, and REVERTED the same session — real finding, not shipped:**
`personal_prior_vote()` summing every identity-matched returning candidate
of a class (not just the leader) looked like a safe completeness fix for
Waite's hypothetical (Duluk 19.7% + Holmes-Ross 14.6%, both returning).
**Two things were wrong with "zero real cases, no measured effect":** first,
the check that produced that claim had the same `all_election_pairs()`
field-name bug (`election_from` vs `prev`) already caught once this session
in the defector-discount count, and silently processed zero pairs instead of
erroring. Rerun correctly: **40 real historical cases** hit this shape.
Second, summing is only correct when EVERY prior candidate of a class
returns (Waite's shape). The far more common real shape is a class with
several prior candidates where only ONE returns — Rankin/OTH_RIGHT
fed2016->2019 had three (Lawrie 5.9%, Davies 4.1%, Holley 3.4%), only Davies
came back. Summing there REPLACES the class's true prior total (13.3%) with
just Davies' own share (4.1%), silently discarding the other 9.2 points of
real prior vote that belonged to people who left — understating the base,
not completing it. Measured on real backtests before reverting: fed2019
pooled log loss 0.263 -> 0.383, fed2025 0.324 -> 0.373 (both worse); vic2022
improved slightly (0.249 -> 0.240). Mixed, non-trivial, not a no-op.
**The real fix needs to separate "identity-tracked personal vote" from
"anonymous residual class vote"** rather than treating a match as a full
substitute for the class base — a genuine design question, not a mechanical
patch. Full reasoning is now the long comment above `lead` in
`personal_prior_vote()` (`R/candidate_returns.R`) so the next attempt starts
from what's already known rather than re-discovering it. `scripts/
candidate_scenario.R` still demonstrates the underlying gap live (Holmes-
Ross's history is genuinely invisible under leader-only matching) — the tool
is fine, the fix attempted on top of it wasn't.

**Queued, not done**: hand-coding "scandal/disendorsement vs voluntary
departure" as a feature for the 14-case defector-retention fit. Pete's own
bar (10+ cases -> try to model) is cleared, but the two obvious data-only
covariates already tried (prior seat margin r=0.07, prior vote size r=-0.10)
found nothing — the visible split (Kelly/Jensen/McBride low, Ward/Graham
high) is real but is circular with the very outcome being forecast. The only
plausible signal is genuinely external (public record of why they left),
knowable pre-election so not leaky, but needs manual per-case research, not
a code change. Someone's call on whether that research is worth the time.

**Pete's broader point, mid-session**: this exact failure (federal quietly
fits something, five siblings hardcode a stale copy) is a documentation and
consolidation problem, not just a one-off bug. Keep `docs/MODEL-REGISTRY.md`
current and prefer pulling shared logic into `R/` over six near-duplicate
harness copies — item 1 above is that consolidation applied to one constant;
the six-harness architecture itself is the bigger, already-flagged version of
this (`docs/plans/harness-unification-2026-09-08.md`).

## SESSION 2026-09-09 (AM #2) — worst-seats-vs-AEF table reviewed with Pete

Full 22-pair sharedetail coverage confirmed (`scripts/pool_sharedetail.R`
PS2c clean). Pete reviewed the worst-20-seats-vs-AEF table live and gave
four items:

1. **Correction, not new news**: Waite and Kiama (rows 1-2) are NOT
   shipped. Confirmed by grep: `AUSPOL_REENTRY` defaults `"0"` everywhere,
   absent from `published_flags.R`. Kiama's fix
   (`protect_personal_vote_cells`) is coded, reviewed, dormant behind arm
   D. Waite's shape (candidate leaves entirely, no fallback candidate) has
   no code at all — matches what was already in the section below, restated
   here because Pete read the table as claiming "fixed."
2. **New hypothesis, not yet designed**: minor-to-central-party reversion
   (GRN→ALP, ONP→LNP, LNP→teal) scaled by seat lean — Melbourne fed2025 is
   the seed example. Written up, explicitly NOT to be built without a
   design session on real examples first:
   [plans/hypothesis-lean-scaled-minor-reversion-2026-09-09.md](plans/hypothesis-lean-scaled-minor-reversion-2026-09-09.md).
3. **Teal leakage, checked**: the shipped teal fix (arm C, salience-
   expected) uses only Google Trends `jump` — pre-election, no outcome
   data (`R/salience_screen.R`'s own docstring: "DECIDED FROM THE FIELD,
   with no outcome data"). No dedicated "is this candidate a teal"
   classifier exists — it's the generic governed/salience screen, so no
   leakage, but also nothing teal-specific (e.g. Climate 200 backing).
4. **Queued, harder**: gauging salience of emerging groups more directly
   (beyond per-candidate Trends jump) as a further teal/emergence
   improvement. Not scoped yet.

Standing instruction from Pete: keep the worst-seats-vs-AEF table as a
living reference and keep working known misses down it — this is now the
main improvement loop, not a one-off.

## MORNING READ, 2026-09-09 overnight session — start here

Pete asked overnight for fed2022's teal seats to be actually fixed, not
diagnosed again, and to not be interrupted until it was done. Two real
fixes shipped, both tested and committed to `dev` (nothing merged to
`main` — that still needs the review gate, per the autonomous-session rule).

**1. fed2022's teal seats — genuinely better, not solved.** Shipped arm C
(salience point estimate + variance,
`docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`, written
2026-09-07, never run until tonight). Kooyong 5.3%→36.1%, Goldstein
2.0%→12.2%, all six named seats move the right direction, several
substantially. **This is now the DEFAULT behaviour of a bare
`backtest_candidate_fed.R`/`_nsw.R` run** — verified end-to-end, no flags
needed. Full write-up, including the honest caveat that this is a scope
decision made after seeing results (not a clean pre-registered rule):
[reviews/salience-arm-federal-nsw-scoped-2026-09-09.md](reviews/salience-arm-federal-nsw-scoped-2026-09-09.md).

**Applying the same arm to Queensland/SA/Victoria was REFUSED** — SA
(+0.025) and Victoria (+0.012) both breach the pre-registration's own 0.01
per-jurisdiction bound, and Victoria is the live target election, so it
was NOT added to `published_flags.R` — `fit_seats_full.R` (the actual
published forecast) and QLD/SA/VIC/WA are completely untouched. This
matters: the fix is real, scoped, and doesn't touch the live forecast.

**Still true**: fed2022 remains under-called even with this on (Kooyong
36.1% is still not over 50%). Improved, not solved. The underlying
cross-election salience-anchor problem
(`reviews/wave-term-blocked-2026-09-07.md`) is untouched — this works
entirely on the within-election ranking, which was already known-good.

**2. Personal-vote-priority fix, implemented** (yesterday's
pre-registration, `plans/prereg-reentry-personal-vote-priority-2026-09-08.md`).
All six harnesses now protect a `personal_prior_vote()`-informed cell
(Kiama's Gareth Ward, Pilbara's Larry Graham) from being overwritten by the
generic re-entry GLM. Verified firing correctly. **Dormant** — only matters
when `AUSPOL_REENTRY` (arm D) is on, and arm D stays unshipped, so this
changes nothing in current published output. Ready for whenever arm D's
ship/refuse call is made.

**3. The Waite/SA2026 pattern (class-level vote-share swung forward after
the specific candidates who earned it left) — investigated, NOT fixed.**
Ran out of time. Real, well-evidenced (see the AEF-miss investigation
above), and a partial version already exists (`WA0`/`BW0`-style "zero IND
if nobody stood" in fed/sa/wa, missing from nsw/vic) but doesn't cover
Waite's shape (a *weaker* candidate stands, not zero). Next session.

**Verification tonight**: full test suite (827/827, 8 new tests),
`R CMD check --as-cran` (0 errors, 0 warnings, same 4 pre-existing NSE
notes), and an end-to-end bare-invocation run confirming the shipped
default reproduces the measured numbers exactly.

**Not done tonight, queued**: the review gate for everything on `dev`
(50+ commits since PR #29 merged) before any PR to `main`; a proper
pre-registration for the federal+NSW scope decision, since tonight's was
made under time pressure after seeing results.

## SESSION 2026-09-07: New South Wales 2019 scored, and four findings

Coverage reached 22 pairs / 2,050 seat-elections, pooled seat log loss 0.3454
(nsw2019, vic2014, qld2020 added; qld2020 second-pair took Queensland to
0.3294). Full write-up: `docs/reviews/nsw2019-and-seat-turnover-2026-09-07.md`.
`scripts/pool_backtests.R` (new that session) still produces the pooled table
on demand.

**Salience** — largely superseded 2026-09-10 (vic2026 corpus now built by
`scripts/build_vic2026_salience_corpus.R`); original entry moved verbatim to
[backlog/journal-2026-09-07-to-08-reentry.md](backlog/journal-2026-09-07-to-08-reentry.md).
Still-live facts from it: Google Trends is measured rural-blind (nsw2019
Barwon/Orange winners both scored exactly 0.0000 —
[reviews/salience-rural-blind-spot-2026-09-07.md](reviews/salience-rural-blind-spot-2026-09-07.md));
`wa1996`/`wa2001` predate Trends and can never be fetched; three salience arms
(`AUSPOL_SALIENCE_EXPECTED`, `AUSPOL_SALIENCE_EXP_SD`, both together) remain
built, Victoria-only, undecided —
`docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`.

**OPEN QUESTION, parked**: is one party class one party? `classify_party()`'s
seven classes bucket Liberal/National/LNP together and Katter/Shooters/Family
First together, and pool state vs. federal Labor without having asked. Major-
party coding itself was checked 2026-09-07 and is sound — this is a
granularity question, not a correctness one.

**Housekeeping**: WA slope/transfer decomposition — DONE, resolved, do not
re-open (commit `6958430`). `docs/plans/harness-unification-2026-09-08.md` —
planning only, not started, own hard stop 30 September, read before starting.

**THE RE-ENTRY PRIOR (arm D) — decision ready, still unshipped.**
`AUSPOL_REENTRY` stays 0. Seed-averaged at 20,000 sims, verdict genuinely
mixed: better on WA/SA/Federal 2007-2016, flat on VIC/Federal 2019-2025,
worse on NSW/Queensland (1-4 seats, traced to specific by-election seats, not
a jurisdictional weakness). Arm H (variance widening) was run and REFUSED by
its own pre-registered rule — stays 0. `protect_personal_vote_cells()` is
implemented and wired into all six harnesses but dormant (only fires when arm
D is on). Full evidence moved to
[backlog/journal-2026-09-07-to-08-reentry.md](backlog/journal-2026-09-07-to-08-reentry.md).

### Open, in the order I would do them

0. **PARKED IDEA, not scheduled: correlated seat draws and demographics.**
   `docs/plans/plan-correlated-seat-draws.md` (agent-written 2026-09-07).
   Read its headline before spending anything on this: between-seat
   correlation CANNOT move per-seat win probabilities, because no expression
   inside a seat reads another seat's state, so a variance-preserving
   correlation leaves every marginal unchanged and log loss is a mean over
   marginals. What it would change is the JOINT distribution -- the seat-count
   histogram and the majority probability, which are genuinely too narrow and
   which no harness scores. The version that could move a marginal is a
   cluster VARIANCE component, not a correlation.
   Two facts to keep: Dubbo had a 2015 minor-right share of 2.54% against
   Barwon 2.50%, Murray 1.40% and Orange 2.59%, so any similarity structure
   lowers Dubbo and the criterion must accept that in advance; and census
   coverage is NSW/VIC/SA only, 6 of 22 pairs and 23% of seat-elections, on
   one 2021 vintage against elections from 2010 to 2026.

1. **Seats that changed hands between elections are nearly invisible.**
   19 of 893, and the damage is concentrated: Orange and Wagga Wagga in nsw2019
   score 5.705 against 0.280 elsewhere, Morwell 2.175 against 0.224. Both NSW
   seats were won at by-elections. Worth about **0.007 of pooled log loss**,
   roughly 2%. The field that fixes it is already loaded — `load_seats()`
   returns Orange as Shooters-held — and is known before polling day, so it is
   leakage-free. Targeted fix, so the named seats are the primary metric and the
   election-wide number is a do-no-harm guard.
2. **The statewide covariance is settled for now.** Leakage closed
   (leave-one-out, effect nil), widened to 15 of the 21 pairs, and Western
   Australia deliberately excluded because cor(ALP, IND) flips sign on it.
   Both changes measured as ties. What is NOT settled is era: all pairs are
   pooled regardless of date and the party structure of 2001 is not that of
   2025. `docs/reviews/statewide-cov-loo-2026-09-07.md`.
3. **Western Australia has no surge-v2 hazard at all.** The other five harnesses
   do. A published switch a harness cannot honour is the failure recorded in
   `CLAUDE.md` for the missing SA `shrink`, and its numbers describe a different
   model from the rest of the table. **See `docs/MODEL-REGISTRY.md`** (new
   2026-09-09, generated by `scripts/build_model_registry.R` — rerun it, never
   hand-edit) for the full switch-by-switch parity table across all six
   harnesses and the published forecast: this is item 1 of 2 open gaps it
   records (the other is WA's screened slope mode only half-implementing what
   "screened" means elsewhere). Two more gaps it found and this session fixed:
   WA's seed was a hardcoded literal ignoring `AUSPOL_SEED`, and
   `AUSPOL_SEAT_SD_MULT`/`AUSPOL_FALLBACK_SMOOTH`/`AUSPOL_FLOW_SD` never
   reached `fit_seats_full.R` (the actual published forecast) at all.
4. **~~Two elections still unfound~~ — STALE, corrected 2026-09-11.** sa2018
   was fetched, verified against the anchor and wired in as a prior-only pair
   (`AUSPOL_SA_PAIR="2022"`) — see "Data coverage" at the top of this file.
   Only **fed2004** remains, and only as a scored TARGET rather than a prior;
   it already serves as a prior today. The Queensland recipe applies: the
   commission's old results site published a package per election and the
   archive kept it, which is what made qld2017 available after it had been
   written off. Parsers are the remaining work; the sources were located.

   *Left visible rather than deleted because this is the failure CLAUDE.md
   names — "we don't have X" gets written into a plan and then reasoned from.
   It had been stale for a day.*

### Closed this session

- Queensland's surge training list had `sa2026` replaced by `qld2024` in the
  copy that created the harness, so it trained without the four One Nation
  winners. Fixed; effect is **neutral** (log loss 0.3350 either way).
- Adding nsw2019 to the leave-one-out slope panel moved the fitted `also_ran`
  slopes by up to 0.092 and changed no harness output at all, because only
  `member` is consumed and nsw2019 contributes no returning members. `also_ran`
  is read by nothing outside its own fitting script.


## SESSION 2026-09-05/06: the AEF gap closed — shrink 0.10→0.01 (moved out)

Full write-up in
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).
Headline: fed2025 seat log loss 0.3663→0.2886 against AE Forecasts' 0.3025.
Cause was `shrink` capping every seat at `1-shrink/2` — at the old 0.10 no
seat could be called above 0.95. `AUSPOL_SHRINK` shipped at 0.01 (not 0.00,
which blows up fed2013). Also shipped: `scripts/fit_mp_slope.R` (refit the
sitting-member slope tier, fixing a leaked ONP value), `fit_seats_full.R`
passing `same_mp`/`major_discount`, `AUSPOL_SEAT_SD_MULT` un-inerted.

## THE OBJECTIVE, set by Pete 2026-09-06 evening

**Every model change is decided by overall seat log loss AND seat-share RMSE
pooled across ALL the elections we forecast** — every 21st-century state and
federal election in the harnesses — never one election or one harness. The
harnesses now print the RMSE line (`BF3r`/`BV2r`/`BT5r`/`BS2r`/`BW2r`,
`seat_share_rmse()` on the point estimate) beside log loss.

**Coverage today: 17 elections, ~1,570 seat-elections** — fed 2010, 2013,
2016, 2019, 2022, 2025; vic 2018, 2022; nsw 2023; sa 2026; wa 2001, 2005,
2008, 2013, 2017, 2021, 2025. **Buildable now**: qld2024 (2020 prior and
transfers on disk; also one of AEF's archived elections). **One prior fetch
each**: fed2007 (needs fed2004), vic2014 (vic2010), nsw2019 (nsw2015), sa2022
(sa2018). Those five would make 22.

## P4b SHIPPED 2026-09-07: surge reaches the candidate it was fitted for (moved out)

`AUSPOL_SURGE_RECIPIENT=1` published — pooled seat log loss 0.3631→0.3422.
Remaining gap is the hazard's calibration (ridge lambda 20 on ~13 winners).
Full write-up: [backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## DATA HUNT 2026-09-07: all five missing elections FOUND (moved out)

fed2004 fetched and wired in (fed2007 now forecasts, log loss 0.2858).
nsw2015, vic2010, qld2017, sa2018 located but still need parsers — that's
the open item, worth coverage 19→23 elections. Sources and the AEC path
gotcha (`/results/Downloads/` vs `/Website/Downloads/`, wrong path 404s
silently) are in
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Standing item found 2026-09-07: package functions read BARE RELATIVE paths

`surge_hazard_for()` and `surge_training_population()` read
`"output/candidacies.csv"` relative to the working directory. That is the
package root for everything in `scripts/`, and `tests/testthat` for the
suite -- so two tests of those functions guarded on `file.exists("output/...")`
and skipped **unconditionally, on every machine, including the ones that have
the corpus**. Found by review 2026-09-07; the tests now resolve from the root
(`skip_if_no_salience_corpus()`) and run their bodies there
(`with_package_root()`), both in `tests/testthat/helper-anchor.R`. The
underlying smell is unfixed: package functions should resolve through
`getOption("auspol.root")` the way `election_data_path()` does.

## SESSION 2026-09-07: a sixth harness, two refusals (moved out)

Queensland harness added (log loss 0.3351 vs AEF's 0.3578), salience point
estimate ported to all harnesses, two changes refused by their own criteria
(P5, P6). Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

**The one live thread, and it is Pete's:** the six fed2022 teals polled
25-40% and the model projects 2-14%. The hazard is calibrated and correctly
ranked; what's missing is that 2022 was a wave and nothing in the model can
see one. **The wave term is BLOCKED, diagnosed, no arm should be run**:
[reviews/wave-term-blocked-2026-09-07.md](reviews/wave-term-blocked-2026-09-07.md)
— the percentile-based salience signal can't distinguish a wave from a quiet
year, and the raw measure isn't comparable across elections (every batch is
anchored to Albanese, a nobody in 2008 and PM in 2026). The one unblocking
route before November: candidate-count NOMINATED per seat (a commission
fact, available after Victorian nominations close 9 November 2026) as a
crowding proxy, not a prominence one.

## P4c REFUSED and the calibration question ANSWERED, 2026-09-07 (moved out)

Letting a named recipient surge from zero share was refused (pooled
0.3422→0.3444) — the hazard is already calibrated out of fold; **the gap to
AE Forecasts is information, not calibration.** Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## THE SIMULATOR IS COMPILED, 2026-09-07 — a sweep is minutes, not an hour

`src/seat_sim_core.cpp`, the compiled per-draw core of
`simulate_seat_contests()`, proven byte-identical to the R reference engine
(full fed2022 run at 20,000 draws, byte-for-byte). **45 seconds against
about 11 minutes.** `AUSPOL_SIM_ENGINE=cpp` is published; `=r` forces the
reference loop for re-proving the identity. Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## P4/P1 stage results, review gate, and per-seat shrink (all moved out, 2026-09-06)

P4 stage 1 found the surge was paying the wrong candidate (fixed by P4b
above); P1 shipped "vote belongs to the person" (rule 2) and refused the
departed-leader rule (rule 1); the pre-dev→main review gate caught a NINTH
data.table NSE instance (`party_swing()`'s region filter) plus four other
bugs, all fixed same-commit; per-seat shrink (`AUSPOL_INSURGENCY_SHRINK`)
was measured three ways and refused each time — the scalar 0.01 stayed
shipped. Full write-ups, tables and the deferred-fix list:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Then

1. ~~Re-measure the other four harnesses at `shrink=0.01`~~ — done above.
2. ~~Push `dev` and take it through the review gate to `main`~~ — **PR #27
   merged 2026-09-06** after the review gate above; CI green in 2m04s. `main`
   is current with `dev` for the first time since PR #26 (2026-08-23).
3. **Data threads, Pete's call**: One Nation how-to-vote cards (the ONP drift is
   a published pre-election decision this repo does not hold), and seat-level
   polling.

## Known gap

`output/` is gitignored, so `output/mp-slope-by-target.csv` and
`-by-class.csv` are NOT in the repo. A fresh clone must run
`scripts/fit_mp_slope.R` before `AUSPOL_MP_SLOPE=1` will work, and
`fit_seats_full.R` now needs `-by-class.csv` to run at all unless
`AUSPOL_MP_SLOPE=0`. Both error rather than falling back, deliberately — a
silent fallback to a constant is how the leaked value survived.

## ACTIVE PLAN: candidate-level seat model

[plans/plan-candidate-level-model.md](plans/plan-candidate-level-model.md) —
opened 2026-08-27, and it is the working checklist. The seat model is party-class
based, so "IND" is a residual bucket and a returning independent is
indistinguishable from a stranger. Measured across 17 election pairs, that one
fact moves a 30% seat to 30.3% or to 12.1%.

**Section A is CLOSED** (both tickets resolved 2026-08-27: A1 shipped as
level-dependent variance at `1.10,8.67`; A2 refused, so A3 never runs) **and
class-specific variance is CLOSED too, refused twice** — real effect,
negative in all 20 harness×arm cells, but small relative to its own noise
and gets WORSE at higher multipliers (not an undiscovered sweet spot past
the edge). Not worth its own parameter. Full write-up, both pre-registrations
and both review files:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).


Updated 2026-08-28. Remote: github.com/peteowen1/auspol (private, default
branch `dev`; `main` exists and is reached only through a reviewed PR).

Completed stage write-ups live in
[backlog/journal-2026-08.md](backlog/journal-2026-08.md) — this file holds
open state, not the narrative of how it got here.

**Hub-slimming passes: 2026-09-04 and 2026-09-06.** Sections older than about
two weeks roll into `backlog/journal-*.md` verbatim; live items get pulled
forward, never cut by line range (`hub-slimming` skill).

## DONE 2026-09-04: the seat simulator's hot loop, profiled 2026-09-03 (moved out)

**Shipped.** 36-38% faster in fresh-process wall clock (204→132 us per
seat-sim at n_sims=500). The string-keyed environment lookup in the
elimination-round loop is now a preallocated integer-indexed list.
Byte-identical output proven, not assumed (`output/seat-probs-vic-2026.csv`
etc. match before/after, same seed). Full write-up, the Rprof table, the
K=17 RNG-non-comparability dead end, and the no-O(n²) scaling table:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Google Trends and the 2026-08-28 session — moved out

Both moved verbatim to
[backlog/journal-2026-08-26-and-28.md](backlog/journal-2026-08-26-and-28.md)
on 2026-09-06; every open item in them was closed by 2026-09-04 and the
Trends finding ships as arm CS. One line stays live:

**Hard date:** Victorian nominations close 12 noon 9 November 2026. The
salience signal is candidate-level so it cannot run before then;
`scripts/victoria_salience_dryrun.R` tests everything downstream against
Victoria 2022 — two lines change on the day.

## Closed items archived

Three closed 2026-08-25/26 items (data-registry lessons, that session's
resolved list, and the ONP seat-type asymmetry — whose own stale "next step"
was corrected before archiving: the follow-up test was run the same day and
REFUSED, reversing Pete's directional hypothesis) moved to
[backlog/journal-2026-08-25-to-26.md](backlog/journal-2026-08-25-to-26.md)
on 2026-09-09.

## Awaiting Pete

- **PRs #5–#12 merged** (2026-08-17/18). Every one reviewed before opening,
  and every review caught something the tests could not: stale published
  figures, roxygen under the wrong argument, a correction pass that missed its
  own targets, a crash on a party absent from a seat, and a CI cache that could
  have switched the seat model off behind a green build. **Do not skip the
  gate, least of all on docs-only diffs.**
- ~~VEC data licensing~~ — **resolved 2026-08-18.** The fetched results live in
  `external/elections/`, gitignored beside the anchor clone, and nothing of
  either commission's is committed (verified: git reports the directory
  ignored and tracks none of it). The daily job refetches behind a cache. No
  decision needed; the question only existed while the data had no home.
- **Decide whether the repo goes public.** Private on purpose. Two things are
  outward-facing and should be deliberate: `docs/plans/product-features.md`
  carries critical commentary on named competitors (theswingison, DemosAU —
  the latter also a pollster in our own data), and the scorecard publishes
  named firms' house effects and accuracy. Both defensible; neither should
  appear publicly by accident.
- **Poll data licensing.** The anchor's data is gitignored and not committed —
  verified: no `external/`, no CSVs, no outputs are tracked — so nothing of
  his is republished. His repo has no LICENCE and his site invites use of the
  files, but formal permission is worth having before going public.
- **Answer the four improvement-quiz questions** (context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md), "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-versus-simulator scope call. Two of the four now have measured answers
  — see the seat-type and methodology reviews below — so this is smaller than
  it was.
- ~~Decide whether to transfer South Australia's allocation slope~~ —
  **resolved 2026-08-18, it survives.** Both pre-registered checks pass: the
  Greens-share ordering replicates with a negative coefficient in NSW,
  Queensland and WA, and the magnitude transfer sits at 1.41x against a 1.5
  bar. It beats a uniform allocation by only 0.122 MAE, so trust the One
  Nation **total** rather than any individual One Nation seat. See
  [reviews/onp-allocation-checks-2026-08-18.md](reviews/onp-allocation-checks-2026-08-18.md).
- **Find a signal for a first-time regional independent breakout** (Priestly
  in Nicholls, 23.5%, our worst-scoring miss). Search-interest salience is
  confirmed strong for teal-type candidates but does not move Priestly, Boele
  or Heise at either national or state geography — see below. News-article
  mention counts (GDELT) were the other candidate mechanism raised earlier
  this session and are untried.
- **Carried forward from the archived 2026-08-19/22 sessions, 2026-09-04.**
  Three items with a genuine open question in them, pulled out before the
  narrative around them was archived to
  [backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md):
  - **Centre Alliance / Nick Xenophon Team / SA-BEST classify as `OTH`**, so
    Mayo's winner reads "OTH" in 2016/2019/2022/2025. Deliberately left
    unchanged — the alternative is `IND` (Sharkie functions as a community
    independent) and this is a modelling call, not a bug, that should be
    Pete's rather than a default nobody chose.
  - **WA's flow-matrix fault may be in the matrix, not the state**: it is
    keyed on party class and survivor SET, and a contest whose survivors are
    two LNP candidates should occupy its own cell rather than contaminating
    others. Predicted in advance, not run: conditioning on the survivor
    **multiset** should improve the forecast with WA excluded entirely — the
    one form of this test nothing so far can confound. Needs its own plan.
  - **The candidate model still cannot elect a new independent** (federal
    calibration slope 0.260) after the endogenous fixes were tried and
    refused. The next attempt is exogenous — a named list of confirmed
    independents, seat polls, or market odds — and odds specifically need
    Pete's call, since that is a different kind of input to the model than
    anything used so far.

## Sessions of 2026-08-19 to 2026-08-23 — moved out

Two journals hold the verbatim write-ups, conclusions all in `reviews/`,
`CONSTANTS.md` and the code:

- [backlog/journal-2026-08-22-to-23.md](backlog/journal-2026-08-22-to-23.md)
  (moved 2026-09-06): the AE Forecasts benchmark and the measurement gap it
  found in our harnesses, forecast mode refused, calibration knobs refused,
  gate 1 / refusal M2 / bucket narrowing / candidate-count weighting, the four
  independent refusals re-read and re-measured, the salience signal confirmed,
  seat TCP retained (shipped in `R/seat_sim.R`), nomination zeroing of `IND`
  (shipped in every harness).
- [backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md)
  (moved 2026-09-04): the Victoria 2026 target snapshot as of 2026-08-23 and the
  session write-ups from 2026-08-19 (WA fetched, over-confidence fixed, the
  Others-bias diagnosis, NL3, One Nation seat allocation) through 2026-08-22.

Still-live items pulled out of the moved block rather than duplicated:

- **After nominations close (12 noon, Monday 9 November 2026)**: probe VEC for
  the 2026 nomination list (the URL does not exist yet; reuse the HTML-table
  parser from `fetch_preferences_vic.R`), and revisit **candidate-count
  weighting** — the seat's previous count predicts the next one worse than
  assuming one candidate, so the remedy is worth nothing until the count is a
  fact (`reviews/candidate-count-weighting-blocked-2026-08-22.md`).
- **Victoria 2022 seat TCP ground truth is cached but unparsed**:
  `external/elections/cache/vec-2022-vic/*-results.html`, 87 files, two table
  shapes to branch on. Federal TCP truth already exists
  (`external/elections/aec-fed-tcp.csv`). Needed before our seat TCP can be
  scored against AE Forecasts' 3.69pp MAE.
- Two items from 2026-08-22/23 are **stale, not live**: the unattributed change
  to `output/seat-probs-vic-2026.csv` (the file has been regenerated many times
  since) and the overwritten `output/independent-federal-scores.csv` (output is
  gitignored; regenerate if the historical v4 scores are ever wanted).

## Done

Full write-ups moved to [docs/backlog/journal-2026-08.md](backlog/journal-2026-08.md) on 2026-08-15 — 11.5k characters of completed-stage narrative that every session in this repo was re-reading on every turn. Index of what is in there:

- 2026-08-15 (stage 8): Regional swing structure in the seat model
- 2026-08-15 (stage 7): Seat model — the pipeline is end to end
- 2026-08-15 (stage 6): Fundamentals + projection — it is a forecast now
- 2026-08-14 (session 2, stage 5): Parties folded into "Others" corrected
- 2026-08-14 (session 2, stage 4): Per-cycle volatility — the model now reproduces One Nation leading
- 2026-08-14 (session 2, stage 3): Logit-scale modelling — adopted per party, not globally
- 2026-08-14 (session 2): Hyperparameters estimated, not fixed
- 2026-08-14: Anchor model analysed; package skeleton; Jackman trend; federal and NSW cycles fitted


### Diagnosed 2026-09-08, not implemented: point-estimate shrinkage cannot fix the majors' floor seats

Tested continuous James-Stein shrinkage (`ratio = w*measured + (1-w)*1`,
`w = n/(n+k)`) as a replacement for the hard `min_ratio_n = 20` cutoff, grid
`k ∈ {3,5,10,20,40,80}`, leave-one-out MAE over every ratio-path cell (n < 40).
Best `k = 20` gives MAE 3.677 against 3.710 for the current hard cutoff — a
real but tiny gain, and it is **not coming from the majors**: Labor and the
Coalition have 1-3 observations per leave-one-out fold, so `w` stays near zero
and the shrunk ratio stays near 1. Alfred Cove predicts 42.1 against an actual
22.8 under the best `k`, essentially unchanged from the current 41.9. This
matches and extends the 2026-09-07 finding that pooling the two majors did not
help either — with this few observations, no point-estimate trick can locate
the true value; the estimate itself is just noisy.

**The next thing to try is widening the SIMULATED VARIANCE for ratio-path
cells, not moving the point estimate.** The existing `sd_override` mechanism
(`R/seat_sim.R`, already threaded through five of six harnesses for salience)
is the right tool, but it needs: (a) `apply_reentry_prior()` to return a
per-cell sd inflation alongside the point estimate, sized by something like
`a / sqrt(n+1)`; (b) a combination rule with the salience sd source where both
apply to the same cell — take the max, since neither source should understate
the other's uncertainty; (c) **`sd_override` plumbing added to the WA harness**,
which does not have it at all (`scripts/backtest_candidate_wa.R:445` calls
`simulate_seat_contests()` with no `sd_override` argument) — the sixth
harness-parity gap this session found, after positions, salience and the seed.

Scoped as a targeted fix (CLAUDE.md's own rule: validate on the named targets
first, election-wide as a do-no-harm guard) — this can only ever move a
handful of seats, since a major failing to contest the previous election is
rare by construction. Not started this session; needs its own pre-registration
before any of the plumbing goes in.

### Diagnosed 2026-09-08: the personal-vote transfer helps Pilbara and hurts WA overall

Decoupled `AUSPOL_DEV_SLOPE_MODE` (conditional slopes) from the personal-vote
transfer (`.own_prev`/`remove_transferred_votes`) in `backtest_candidate_wa.R`
via a new `AUSPOL_WA_TRANSFER` flag — they were sharing one gate (`.cond`), so
the two effects could never be told apart. Default behaviour is unchanged
(verified byte-identical, 87.0%/0.1053 before and after the decoupling).

Pooled log loss over all 361 WA seat-elections, one seed, `AUSPOL_N_SIMS=5000`:

| slope mode | transfer | pooled log loss |
|---|---|--:|
| screened | **off** | **0.4058** |
| screened | on (published) | 0.4109 |
| uniform | off | 0.4104 |
| uniform | on | 0.4158 |

Conditional slopes help by ~0.005 either way. The transfer **hurts by ~0.005
either way** — consistent sign in both slope settings, so not an interaction
artefact.

**But it works exactly as designed on the seat it was built for.** Pilbara
2001, transfer off: the independent gets probability 0 (clamped to the 1e-6
floor, costing 13.8 of log loss on that seat alone). Transfer on: 0.0058 — a
huge per-seat gain, worth roughly 0.024 of pooled-equivalent log loss on its
own. That the pooled effect is still net negative means the transfer is making
OTHER seats worse broadly enough to swamp Pilbara's rescue several times over.

**Not shipped, not further investigated this session.** One seed only — item
2 already establishes that a single seed at 5,000 sims can move a pair by
0.011, larger than this whole effect. Before acting on it: seed-average, then
find which OTHER seats `personal_prior_vote()` is firing on and whether those
are genuine defections or false positives. `Pilbara` is the one case the code
comments name; nothing establishes the others are correct.

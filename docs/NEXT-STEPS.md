# auspol — work queue

## ACTIVE PLAN: candidate-level seat model

[plans/plan-candidate-level-model.md](plans/plan-candidate-level-model.md) —
opened 2026-08-27, and it is the working checklist. The seat model is party-class
based, so "IND" is a residual bucket and a returning independent is
indistinguishable from a stranger. Measured across 17 election pairs, that one
fact moves a 30% seat to 30.3% or to 12.1%.

**Section A is CLOSED.** Both tickets resolved 2026-08-27, the day before this
line first claimed they were next:

- **A1 SHIPPED** as level-dependent variance, on by default at `1.10,8.67`.
  `reviews/level-variance-2026-08-27.md` refuses it on calibration and then
  **amends the same day to ship it** on log loss — read that file to its end,
  because the headline says the opposite of the verdict.
- **A2 REFUSED** — arm C does not ship, and by its own terms **A3 never runs**
  (`reviews/arm-c-conditional-slopes-2026-08-27.md`).

**Class-specific variance: CLOSED, refused twice, and section A is now fully
done.** Pre-registered in `plans/prereg-class-specific-variance.md`, scored in
`reviews/class-variance-stage1-2026-09-03.md` (refused on a bar mis-sized 10x
too high, borrowed from a differently-scaled experiment), re-registered in
`plans/prereg-class-specific-variance-v2.md` with a t-statistic/materiality
split instead, scored in `reviews/class-variance-v2-2026-09-03.md`.

**v2 refused too, on stronger grounds than v1.** The effect is real and
negative in all 20 harness x arm cells (p < 0.02 throughout), but too small
relative to its own noise, and pushing the multiplier higher makes it WORSE:
the t-statistic peaks at m_IND 2-3 (2.98) then falls to 2.60-2.65 at m_IND 4-5
even as the raw effect keeps growing, because variance outpaces the mean past
that point. That is a reason NOT to re-register a wider grid -- the mechanism
argues against an undiscovered sweet spot past the edge, not for one.

Honest summary: per-class variance is a real but minor refinement, nowhere
near the 29% log-loss gain A1 already delivered. Not worth its own parameter.


Updated 2026-08-28. Remote: github.com/peteowen1/auspol (private, default
branch `dev`; `main` exists and is reached only through a reviewed PR).

Completed stage write-ups live in
[backlog/journal-2026-08.md](backlog/journal-2026-08.md) — this file holds
open state, not the narrative of how it got here.

**This file is now 1,900+ lines and reloads every session. Worth a
hub-slimming pass — per the `hub-slimming` skill, not a bulk line-range cut —
next time there's a quiet moment.**

## Session of 2026-08-28 — incumbent transfer, a browse artifact, and the
salience fetch now covers majors

**The ACTIVE PLAN above (A1/A2) was not touched this session** — the whole day
went on diagnostics and tooling Pete asked for mid-stream. Still next up.

### Incumbent primary-vote transfer: a real regression, two bugs found in it

`scripts/analyse_incumbent_transfer.R` (new, uncommitted pending review) fits
`delta ~ own_prev_pcv + tpp_swing + party_swing [+ switched_party + jump_pctile
+ jump_delta]` for minor/IND incumbents, and the major-party analogue.

Two bugs found and fixed while building it:
- **`party_swing_of()` summed `pcv` across every seat a party contested**
  instead of averaging — values in the thousands, sign/significance
  unaffected but magnitude meaningless. Fixed to `mean()`. This had been
  quietly absorbing variance that should have gone to `party_swing`, which is
  why `jump_pctile` (salience) looked significant (p=0.007) before the fix and
  didn't (p=0.108) after it.
- **The salience feature matched by SEAT, not by PERSON** — "loudest candidate
  in the seat's percentile" rather than the specific incumbent's own value, so
  it couldn't support "salience delta from last time" at all (no stable
  per-person identity across two elections). Replaced with
  `person_jump_pctile()`, matched via `search_form()` keys against the same
  keyword the salience fetch already builds. `jump_pctile` came back
  significant a third time (3.53, p=0.005) with both fixes in.

**RESOLVED 2026-09-04**, in
[reviews/incumbent-transfer-rerun-2026-09-04.md](reviews/incumbent-transfer-rerun-2026-09-04.md).
Rerun against `salience-v6.csv` now that the majors fetch finished (coverage
311→486/366, a materially different population, not a repeat measurement):
**`jump_pctile` significant a fourth time and an order of magnitude stronger**
(t=4.32, p=1.93e-05 level model; t=4.97, p=1.02e-06 delta model). The n=311
**`switched_party` discrepancy was sample composition, not a real reversal** —
at n=366 it comes back −10.69, p<2e-16, correctly signed and larger than the
full-sample estimate. One new weak signal not chased further: `jump_delta` is
negative (t=−2.16, p=0.032) — a candidate whose relative salience *rose* since
last time gains *less*, plausibly regression to the mean in percentile terms.
Next step if pursued: its own pre-registration under
[plans/plan-wire-salience-into-forecast.md](plans/plan-wire-salience-into-forecast.md).

**A genuine negative result, reported straight**: minor-party/IND incumbent
vote change does NOT correlate with national or local TPP/party swing
(r≈0.02–0.05, both ways). Implies wider seat-level uncertainty for these
candidates is the right response, not a swing-elasticity term.

### Scrutineer: a full candidate-level browse artifact for fed2025

Built at Pete's request — every fed2025 candidate, sortable/filterable by
seat or party, our projection vs AEF's vs the actual result, prior-vote
history, and (eventually) salience. `scripts/build_fed2025_browse_table.R`
(new, uncommitted). Hit a **seventh instance of the data.table NSE
column-collision trap** in this repo (`CLAUDE.md` had six): a local scalar
named `tot` was silently shadowed by `candidacies.csv`'s own `tot` column
inside `C[...]`, producing 1122 rows instead of 7 from a groupby. Renamed to
`total_votes_all`.

Published, then caught two real problems by having Pete actually look at it:

1. **A mislabelled column.** "Seat pctile" was `rank(jump)/.N` with no
   `by=seat` — a rank against the whole ~390-candidate fetched pool for the
   election, not the seat. Relabelled `Jump pctile*` with an honest footnote.
2. **ALP/LNP/NAT have ZERO salience data — not a display bug, a scoping
   decision.** `fetch_salience_v6.R` line 247 filters `!party %in% MAJ`
   before Trends is ever queried, so majors were never fetched, cached or
   otherwise. Fine for the emergence gate (the only consumer this was ever
   built for); not fine for "compare the IND against the seat's LNP
   candidate", which is what Pete actually wants the table for.

### Salience fetch now covers every candidate, not just non-majors — IN PROGRESS

Design settled with Pete: no PM-relative denominator needed. Since majors
(including the PM/Premier themselves) now get fetched onto the same
per-election scale as everyone else, both wanted metrics are just "ratio to
the loudest candidate in scope": **`seat_salience = 100 × jump / max(jump in
that seat)`**, **`election_salience = 100 × jump / max(jump in that
election)`**. The PM/Premier's only remaining role is as the anchor that
makes different Trends batches comparable at all, not as a literal
denominator. Not yet computed/wired into the browse table — waiting on the
fetch below.

`scripts/fetch_salience_v6.R` modified (uncommitted pending review):
- **`AUSPOL_SALIENCE_MAJORS=TRUE`** adds a second candidate pool per election
  (all ALP/LNP/NAT, no top-2 screening — majors don't need it) run through
  the identical batching/linking machinery as the non-major pool, refactored
  into a shared `run_pool()` so nothing is duplicated.
- **Fixed a self-referential-anchor edge case**, found on the sa2026
  validation run: when the PM/Premier is their own batch's loudest
  representative (the majors pool always includes them as an ordinary
  candidate), the old linking pass queried their name twice in one gtrends
  call and failed outright. `scale=1` is already the correct answer there
  (a value divided by itself) — now detected and skipped rather than retried.
- **Fixed a durability gap before letting this run unattended for hours.**
  The script used to accumulate every election in memory and write
  `salience-v6.csv` once, at the very end. This session has already seen
  background R jobs killed externally and unexplainedly, mid-run, more than
  once — under the old design a kill at election 15 of 23 would have lost
  every one of the first 14 elections' fetches from the CSV, even though the
  underlying Trends cache (which is what's actually rate-limited and slow to
  rebuild) survived untouched. Now writes after every completed election.

Validated on sa2026 (smallest election) before running the rest: 0% dropped,
self-anchor case handled cleanly, majors linked correctly (max jump 17.62,
25 distinct values).

**Running now, in the background, across the remaining 23 elections** (fed
2007/10/13/16/19/22/25, nsw2019/2023, sa2022, vic2014/2018/2022,
qld2020/2024, wa1996/2001/2005/2008/2013/2017/2021/2025). Launched as a
genuinely detached Windows process (PowerShell `Start-Process`, hidden
window, `output/salience-majors-fetch.log`/`-err.log`) rather than a
session-bound background task, specifically so it survives the terminal
closing — confirmed independent (PIDs, no parent tie to the Claude Code
process) before relying on it. Real network fetch, no cache to lean on for
majors, so this is genuinely hours, with the same throttle risk that has
throttled this pipeline out entirely before. **Check
`output/salience-majors-fetch.log` and `uniqueN(fread("output/salience-v6.csv")$election)`
next session** — should read 24 once done (was 21 before this session, 20
in the file plus sa2026 added first as the validation run).

### Next session starts here

1. **Confirm the majors fetch finished** (or resume it — safe to just
   re-run `AUSPOL_SALIENCE_MAJORS=TRUE Rscript scripts/fetch_salience_v6.R`,
   the qry() cache makes any already-fetched batch free).
2. **Compute `seat_salience`/`election_salience`** from the completed
   `salience-v6.csv` and wire them into `build_fed2025_browse_table.R` in
   place of the placeholder `salience_pctile`/`salience_pm_relative`
   columns, then republish the Scrutineer artifact
   (https://claude.ai/code/artifact/660a3507-3383-42a4-9c76-39030383a5e4).
3. **Regenerate `docs/DATA-REGISTRY.md`/`docs/DATA-DICTIONARY.md`** once the
   fetch is done — not run this session since the dataset was still moving.
4. **Code-review and commit** `scripts/fetch_salience_v6.R`,
   `scripts/analyse_incumbent_transfer.R`,
   `scripts/build_fed2025_browse_table.R` — all three are still uncommitted
   as of this write-up (tested and run successfully, not yet reviewed).
5. Independently re-verify `jump_pctile`'s significance (three flips) and
   look into the `switched_party` n=311-subsample discrepancy above.
6. Then back to A1/A2 on the active plan.

## BACKLOG: the seat simulator's hot loop, profiled 2026-09-03

**Not done, deliberately — sized and refused for now.** Worth ~25-30% of
`simulate_seat_contests()`, which was a poor trade against the 4x already won by
dropping the backtest to `n_sims = 5000`, and it edits the published forecast's
own code path so it needs a byte-identity proof.

**There is no O(n^2).** Measured in FRESH processes at 88 seats x 8 parties:

| n_sims | time | us per seat-sim |
|--:|--:|--:|
| 500 | 8.99s | 204.4 |
| 1000 | 17.85s | 202.9 |
| 2000 | 37.19s | 211.3 |
| 4000 | 76.40s | 217.0 |

Clean linear scaling; the target is the ~210 us constant, not the complexity.
**Measure in a fresh process.** Reusing one R session made 4000 sims look 1.04x
the cost of 2000 — a warm-heap artefact that reads exactly like sublinear
scaling, and it nearly became a finding.

Rprof self-time on that unit, ranked:

| | self % | what |
|---|--:|---|
| `simulate_seat_contests` | 49.2 | the loop body itself |
| `as.character` | 13.3 | **builds a string hash key per elimination round, per seat, per sim** |
| `mostattributes<-` | 6.3 | attribute copying, because `pmin`/`pmax` run on NAMED vectors |
| `vapply` | 5.3 | |
| `exists` | 4.0 | **then a second `get()` looks up the same key again** |
| `bitwShiftL` | 3.4 | the bitmask feeding that key |

The fix is `key <- as.character(from * 2^K + mask)` plus `exists()` plus `get()`
replaced by one integer index into a preallocated list. With K around 8, `K * 2^K`
is about 2,048 slots, so the table is trivially small. Dropping names in the hot
path removes `mostattributes<-`. Note `[[` on a missing name in an environment
THROWS rather than returning NULL — the CLAUDE.md trap — which is why a list
indexed by integer is the right shape, not an environment.

Also observed: runtime RISES with `m_IND` (137s at 1.00 to 175s at 1.75 on South
Australia), because a wider non-major keeps more parties alive through more
elimination rounds. Arm cost is not flat across a grid.

## Google Trends separates an emergence from a token candidacy (2026-08-26)

[reviews/salience-emergence-2026-08-26.md](reviews/salience-emergence-2026-08-26.md).
**AUC 0.841, p = 0.005** on the strictest cut, and it supersedes every earlier
salience number here.

The anchor check that produced it matters as much as the number. The model
handles sitting independents WELL — 0.75 to 0.95 across Warringah, Indi, Clark,
Kooyong, Mackellar, Wentworth and Curtin in 2025. It fails only on
**transitions**, in both directions: North Sydney, Goldstein and Fowler 2022 all
came in at **0.0000**, and it also missed Bandt LOSING Melbourne (ALP 0.049) and
Daniel losing Goldstein (LNP 0.187).

And it does not "spot" an emergence even when it looks like it. Wentworth 2022
scored 0.396 only because Kerryn Phelps had polled 32.4% there as an IND in
2019 — the model inherits the previous independent's vote regardless of whether
it is the same person. Kooyong had a LARGER non-major vote (21.2%) and scored
0.0026, because that vote was Green.

**Where it stands:** signal measured, mapping fitted, nothing adopted.
`docs/plans/prereg-salience-surge-hazard.md` is committed and the fed2022
whole-seat fetch is in progress — all 151 seats, because the nine already held
were chosen because something happened in them.

**Refused in advance, with numbers**: salience share as a projected first
preference. Slope 0.34 for independents, residual sd 11.7 points, Chaney
overstated by 52. Rank is reliable, magnitude is not.

**Hard date:** Victorian nominations close 12 noon 9 November 2026. The signal
is candidate-level so it cannot run before then.
`scripts/victoria_salience_dryrun.R` tests everything downstream against
Victoria 2022 — two lines change on the day.

## Four "we don't have it" claims that were wrong (2026-08-25/26)

Booth results, electoral boundaries, candidate-level federal first preferences
for all seven elections, and the AEC's own seat-level `Swing` column. All four
were on disk. The last two were being downloaded and **aggregated away** by
`fetch_preferences_fed.R`, and a whole plan was written around acquiring data
we already had.

Now: `docs/DATA-REGISTRY.md` (does the file exist) and
`docs/DATA-DICTIONARY.md` (does the field exist), both **generated from disk**.
`build_candidacies.R` carries every column through — 23 against 13. The rule is
in CLAUDE.md: never aggregate a source down to the columns you happen to need.

## Resolved this session

- **`party_sd`: TIE**, 11 of 17 pairs, p = 0.332
  ([reviews/party-sd-tie-2026-08-26.md](reviews/party-sd-tie-2026-08-26.md)).
  Stays at 1.50 — not because 1.50 is right, but because changing it buys
  nothing measurable. **It caught a false positive**: 4-of-4 on federal alone,
  a coin flip across seventeen.
- **WA harness added** — seven pairs, 361 seat-elections, from data already on
  disk. Took the repo from 10 election clusters to 17, which is what made the
  `party_sd` question decidable at all. CLAUDE.md now says five harnesses.
- **Federal seat-swing analogue: measured and NOT wired.** The prior
  departure predicts the next at slope **−0.264** (t = −8.0), negative in all
  six elections, where `SEAT_SWING_COEF` is **+0.7452**. Importing the
  state-fitted coefficient would have applied it with the wrong sign. Worth
  3.5% of seat-level error even correctly signed.
- **Candidate corpus**: 24 elections, 14,959 candidacies, 338 non-major
  breakouts, tracked and reproducible (was 21, untracked, no builder).

## One Nation wins the WRONG SEAT TYPE in our model (2026-08-25)

[reviews/onp-seat-type-asymmetry-2026-08-25.md](reviews/onp-seat-type-asymmetry-2026-08-25.md).
**Nothing changed; this needs a pre-registered test.** Found by asking why our
ONP seats differ from YouGov's — YouGov raised the question, SA 2026 answers
it, and YouGov is not treated as truth anywhere in the review.

Our model gives One Nation **6 of 6 seats in ALP-leaning territory and 0 of 6
in LNP-leaning**. SA 2026 — the only election where the party won at this
scale — was **0 of 5 and 5 of 5**, the exact opposite.

The innocent explanation is ruled out. Among the 20 Victorian seats with the
highest federal ONP vote (our own ordering input) the split is exactly 10/10
by lean, yet mean ONP probability is **0.143 in ALP-leaning seats against
0.036 in LNP-leaning ones**. Gippsland East carries more federal ONP vote than
any seat we give the party except Morwell and scores **0.048**; Melton carries
less than all of them and scores **0.561**.

Mechanism: `shares` adds each party's statewide swing and renormalises, which
takes One Nation's gain **proportionally from everyone**. Where the Coalition
holds 58.9% it stays dominant. SA says otherwise — in the top decile of ONP
gain the Coalition fell **17.69** against Labor's **4.96**, and MacKillop's
Liberal vote collapsed 67.0 → 26.8 as One Nation took the seat.

**Why it matters even if the TOTAL is right**: the same 9.25 expected seats
taken from the Coalition rather than from Labor is a different parliament, and
a total that is right for the wrong reason will not stay right.

Caveats are in the review and are real (n=5, one state, no Nationals in SA, and
the marginal gradient is weaker than the group means). Next step is a
pre-registered test of source-weighted allocation against SA 2026 / WA 2017 /
QLD 2020+2024 / NSW 2019 — a real corpus, unlike the two experiments that
aborted for lack of power on 2026-08-25.

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

## PR #26 merged, and the salience signal is confirmed (2026-08-23)

Everything under "WE HAVE A BENCHMARK" below is now on `main` — the AEF
benchmark, the five harness fixes, and the forecast-mode overturn. `R CMD
check` notes down to the two that cannot be removed (new-submission,
`CLAUDE.md` at top level; `three_cornered` was the fixable one, declared in
`R/zzz.R`).

### The salience signal is confirmed

Three elections, same design, national search interest for the anchored
candidate name against "Anthony Albanese": **AUC 0.823 (2019, n=4 breakouts)
/ 0.854 (2022, n=10) / 0.964 (2025, n=7).** Fixing AEC legal names to search
form ("Kylea Tink" not "Kylea Jane Tink") lifted 2022 alone from 0.830 to
0.854. Errors run in useful directions: false positives are common-name
collisions (a UK comedian named Will Anderson, not the method failing on a
genuine unknown), and misses are regional (Boele, Priestly, Heise all read
near zero on 20–25% of the vote). Full write-up:
[reviews/independent-signal-2026-08-23.md](reviews/independent-signal-2026-08-23.md).

**State-level geography does not fix the regional misses.** Tested complete
(22 of 22 candidates, both geographies): AUC national 0.854 vs state-level
0.846 — tied within noise, and combining the two with a simple max buys almost
nothing (0.858). The wave-candidate in-state lift is real and large (Monique
Ryan 0.147 national → 0.363 in Victoria; Kate Chaney 0.033 → 0.237 in WA), but
it does not rescue Priestly (stays at exactly 0.0000), and Tim Bohm's
common-name false positive gets *worse* at state level — third overall, on
5.1% of the vote, because the ACT is a small search population. So "regional
candidates are invisible nationally but visible in-state" is **rejected**:
the three misses look like genuinely low local search interest, not a
geography problem with the query.

**The first version of this comparison was wrong and withdrawn.** A partial
sample (9 of 22 candidates — every NSW batch had been silently dropped by a
`next` with no counter) produced a plausible-looking "AUC national 0.850 vs
state 0.775". Pete caught it from the table: *"There's no way Allegra Spender
would be absent from NSW Google Trends, she was everywhere."* She was in the
sample; the batch fetching her was rejected by Google and the loop swallowed
it. Fixed properly, not patched: `scripts/trends_fetch.R` logs every batch
outcome and `trends_require_complete()` **aborts** rather than let a caller
compute a statistic over a subset, proven against the exact 9-of-22 failure
before being trusted. Recorded as a new hazard in `ARCHITECTURE.md` — the
fifth silent failure in this repo caught by a person reading output rather
than a check, and the tell was the same every time: a plausible number with a
name missing from it.

## Wasted independent probability: negligible in aggregate, one bad seat

Measured across 886 federal division-elections, keeping the full per-seat
per-party table the harnesses normally discard.

| | |
|---|---:|
| division-elections with NO independent nominated | 476 |
| of those, model gives `IND` a non-zero probability | **4 (0.8%)** |
| total wasted probability mass | 0.2775 |
| share of all `IND` mass sitting in no-independent seats | **1.62%** |

**475 of 476 get exactly zero, so the model is not systematically confused.**
But the tail is real: **Nicholls fed2025 carries 19.5% win probability for a
class that was not on the ballot**, plus Hughes at 8.2%.

All four are fed2025 and all are the **same mechanism as Dubbo** already
diagnosed for the emergence work — the model swings the previous election's
independent vote forward without knowing whether anyone recontests. A strong
2022 independent who did not stand again still carries their share into the
simulation.

**Nomination data fixes exactly this, cheaply**: zero `IND` wherever nobody is
nominated, before simulating. One join against data the model does not currently
touch. It does not help the teal problem — every teal seat had an independent
standing — but it removes four wrong seats, one of them badly wrong.


## Two more things computed and thrown away, and the VEC path

**The full per-seat per-party probability table is never saved.**
`simulate_seat_contests()` returns `seat, party, prob` for every party in every
seat; every harness collapses it to the actual winner plus the argmax before
writing (`backtest_candidate_fed.R:321`). So we cannot answer "does the model
give independents probability in seats where none is nominated" without a fresh
25-minute run. Same shape as the seat-TCP finding: the quantity exists in memory
and is discarded at the last step.

**Victorian candidate-level data already exists.**
`external/elections/vec-2022-vic-candidates.csv` — `seat, cand, party, fp_votes`,
119 rows classified `IND`. The 2014/2018 historical fetcher parses candidate
names too but discards them before writing; persisting them is a small change to
a parser already proven correct.

**VEC acquisition path**, checked live: `vec.vic.gov.au` resolves from here on
both the bare and `www.` forms, through both PowerShell and R's downloader — the
apex-domain problem that hit AE Forecasts does not apply. **Nominations close 12
noon Monday 9 November 2026**, confirmed from the VEC's own 2026 page, matching
what was already recorded. The pre-election *nomination list* URL is not yet
discoverable — it does not exist for 2026 yet, and web.archive.org is blocked
here, so a 2022 snapshot cannot be recovered. The plan is to probe VEC directly
shortly after 9 November and reuse the working HTML-table parser from
`fetch_preferences_vic.R`.


## Seat-level TCP: we already compute it and throw it away

The one metric AE Forecasts can be scored on that we cannot — **their seat TCP
MAE is 3.69pp over 722 seats** — turns out to be almost free.

`R/seat_sim.R:316` is `w <- alive[which.max(v[alive])]`. At that line `alive`
holds **exactly the final two** and `v[alive]` holds their vote totals — the
file's own comment says so. Only the winner's index is kept. The split is
discarded 87 × 20,000 = **1.74 million times per production run**.

Retaining it costs about **21 MB** (pair identity plus one share per seat per
draw) against a `totals` matrix that is already 560 KB. One function, two writes
inside an existing loop.

**The "is a seat TCP even well-defined" question is answered by the benchmark's
own data.** In a three-way seat the final pair differs between draws, so a
single unconditional number is wrong — and AEF does not publish one. Their
`seatTcpScenarios` gives P(pair) and `seatTcpBands` gives quantiles
*conditional on that pair*. Tabulating our realised `alive` pairs across draws
produces exactly that structure. No new modelling idea, just retention plus a
group-by.

### Ground truth: federal is ready, Victoria is free, the rest is a fetch

- **Federal**: `external/elections/aec-fed-tcp.csv` already exists, 2,105 rows.
- **Victoria 2022**: raw HTML already cached at
  `external/elections/cache/vec-2022-vic/*-results.html`, 87 files, **unparsed**.
  Two table shapes: 77 seats have "Results after distribution of preferences"
  and 10 simple seats have only "Two candidate preferred vote", which VEC marks
  stale in the first case. A parser must branch on the heading.
- **SA, QLD, WA, NSW**: no cache, no fetch script. New scraping if wanted.

### Known limitation

`simulate_seat_contests()` works in party **classes**, so "IND vs IND" cannot be
represented — a narrow comparability gap against AEF's per-candidate TCP in
multi-independent seats.


## Reopened on a different input: the signal is SALIENCE, not nomination

`reviews/independent-signal-2026-08-23.md`. Two corrections to my own reasoning,
in order.

**Nomination data eliminates 53% of seats** (558 division-elections with no
independent standing, zero wins) and is free and leakage-free. Real, worth
having, and **it does not touch the seats that matter** — I claimed it did
without checking.

**Every teal seat already had an independent standing**: Goldstein 1.3% → 35.3%,
North Sydney 4.3% → 24.7%, Curtin 7.8% → 30.2%, Kooyong 10.6% → 41.4%. The
failure is not an absent candidate class. It is that the previous independent
polled 1.3% and the next polled 35.3%.

**That explains all five refusals.** Every version predicted the independent vote
from seat characteristics, and Goldstein 2022 is identical on all of them to a
seat where a 1.3% independent stays at 1.3%. The difference is not in the seat.

So the only remaining mechanism is **contemporaneous salience** — search interest
or news coverage of the named candidate. Pete raised this; `ANCHOR-MODEL.md:131`
had dismissed Google Trends as "probably noise", but that was about general seat
modelling, not this.

**Reopening a line closed this morning**, explicitly: the closure rule barred
another configuration of the same model on the same inputs. A new information
source is not that.

### Feasibility: UNRESOLVED, not negative

`trends.google.com`, `news.google.com`, `api.gdeltproject.org` and CRAN are all
reachable. But the first GDELT probe was **rate-limited (429)** on four of six
queries and on both of a slower retry. **The "no data" returns are throttling,
not absence** — reading them as "this candidate had no coverage" would be
absence of evidence dressed as measurement.

Next: query slowly from a cold start, or try `gtrendsR`, which is a different
service with a different limit. No plan until a signal is shown to exist.

**Resolved 2026-08-23 — the signal exists and is strong.** See "The salience
signal is confirmed" below for the measured result and what still doesn't
work (the three regional misses).


## Independent emergence: CLOSED after five attempts

`reviews/independent-remeasure-2026-08-23.md`. Re-measured against the
**published configuration**, 886 federal division-pairs.

| arm | log | Brier | acc | slope |
|---|---:|---:|---:|---:|
| A — as published | 0.4374 | **0.0930** | 87.5% | **1.189** |
| B — three mechanisms | **0.3902** | 0.0989 | 86.5% | 1.345 |
| S — temperature | 0.4282 | 0.0980 | 87.5% | 1.550 |

Log: B beats A by **+1.49 SE** against a 2 SE bar. Brier non-inferiority fails
at 1.96 SE (limit 1). **Refused, and the rule closes the line for good.**

The re-read was right and it still did not rescue the model: correcting the
baseline moved B from 2.52 SE WORSE on Brier to 1.49 SE BETTER on log. Two
threads are now settled — **the temperature control was measuring the broken
baseline** (B now beats S by 2.23 SE, so the gain is real and not
recalibration), and **Brier really was the wrong criterion**, but requiring both
rather than switching to the favourable one is what makes this refusal
trustworthy.

**What survives is the diagnosis**: the cause is structural. A seat's baseline
is the previous election's first preferences BY CLASS, so a seat where no
independent stood has no `IND` vote to swing. Fixing it needs the baseline to
represent a candidate who did not exist last time — a different design, not a
further feature. Five attempts say a better emergence model on top of this
baseline is not the answer.

Standing caveat: **Victoria 2026 has zero independent-held seats.** None of this
changes the published forecast.

### Outstanding

`output/independent-federal-scores.csv` (historical v4 scores) was overwritten
by this run and needs regenerating with the historical defaults — the filename
tag edit failed silently because the check was piped through `tail -1`.


## The four independent refusals were scored against a baseline we do not ship

`reviews/independent-refusals-reread-2026-08-23.md`. Independent emergence was
built and refused four times. Re-reading them turns up what none could know:

`score_independent_federal.R:62` calls `simulate_seat_contests()` with **no
`shrink`, no `statewide_draws`, no `party_cor`** — `fit_seats_full.R` passes all
three. Arm A's slope across the rounds was 0.586, 0.586, 0.586, **0.260**. The
published model is **0.980**.

Two consequences:

- **The temperature control loses its force.** It existed to test whether arm
  B's gain was "an over-confident model made less confident" — decisive against
  a baseline at 0.26, meaningless against one already at 0.980.
- **v4 refused on Brier, the least sensitive proper score for this defect.** Its
  own table has arm B ahead on log score (0.478 vs 0.544). A seat moved 0.000 →
  0.30 that then wins gains at most 0.09 on Brier and 1.2 on log — and log is
  where the entire measured gap sits.

**This does not vindicate the model.** v1 and v2 broke incumbent independents,
and the federal reversal may survive the correction. It means the verdicts rest
on a comparison that was not what it claimed to be — the fourth harness today
found with that defect.

**Next is a re-measurement, not a fifth model**: v3 exactly as fitted, arm A as
the published configuration, log score pre-registered as the criterion, control
arm and incumbent-independent guard both retained.


## Calibration knobs REFUSED — and the model was better than we knew

`reviews/seat-calibration-2026-08-22.md`. 24 grid points, six federal
elections, forecast mode. Best point beats the incumbent by **0.09 SE** against
a 1 SE bar. **Refused; knobs stay.** The held-out set was NOT spent.

### The correction that matters more

**Incumbent slope in forecast mode: 0.980.** Essentially calibrated.

Every over-confidence figure this repo has quoted — slope 0.23–0.52, "58% of
seats at 99–100%", reliability gaps of 10–14 points — came from a harness that
passed **neither `shrink` nor `statewide_draws`** while `fit_seats_full.R`
passes both. Wired up, no seat sits in the 99–100% band at all, and claimed
versus actual tracks within 3 points across every band.

**So "our seat probabilities are wildly off" was wrong.** It described a
configuration we do not ship.

Also established: the published `shrink = 0.10` is near-optimal. At 0.20 the
slope overshoots to 1.34 and at 0.30 to 1.64, with log score worsening
monotonically. `seat_sd` barely matters from 1.0–2.0.

### The real gap is SHARPNESS

On the two elections both models cover, both forecasting from polls:

| | AE Forecasts | ours |
|---|---:|---:|
| pooled log | **0.268** | **1.244** |
| pooled slope | 1.15 | 0.76 |

We are calibrated but blunt. They are slightly under-confident and four times
more informative per seat. **Their information advantage does not explain it**:
four of their eight finals are seat-betting updates, but not these two — their
2022 and 2025 federal finals are poll-based like ours.

### Next — and the answer arrived: it is ONE hole, not general bluntness

`reviews/discrimination-gap-2026-08-22.md`. **Excluding seats an independent
won, our log score is 0.255 against their 0.247** — level on 266 of 286 seats.
**97% of the gap is twenty independent-won seats**, and within those we hold
incumbent independents fine (better than them in four) and score **0.000 on an
independent winning for the FIRST time**.

The "calibrated but blunt" conclusion above was an artefact of forecast mode
folding `IND` into `OTH`, which makes independents unwinnable by construction.

**This reopens independent emergence**, refused four times here — always against
our own metrics with no external reference. What none of those refusals could
know is what the hole is worth: 97% of the gap to a real forecaster, and AE
Forecasts put 0.28–0.51 on the 2022 teal seats before they fell, so they are
forecastable without betting markets.

Note it may cost nothing in Victoria 2026, which has zero independent-held
seats.


## Forecast mode REFUSED, and it rules out the obvious explanation

`reviews/forecast-mode-2026-08-22.md`. Six federal elections, pooled:

| arm | slope | log | accuracy |
|---|---:|---:|---:|
| current harness (knows the answer) | 0.286 | 0.494 | 87.6% |
| forecast mode (polls only) | **0.204** | 0.846 | 84.3% |
| AE Forecasts, for scale | 1.140 | 0.280 | 88.5% |

Rule was: adopt if the slope is closer to 1.0. It is further. **Refused.**

### The investigation is the finding

The obvious suspect — the projection understating its own error at one day out,
a horizon never scored here before — is **measured and false**:

**claimed sd 2.42, realised RMSE 2.42, ratio 1.00.**

The statewide input is honestly sized. Feeding that honest uncertainty into the
seat model makes calibration WORSE. **So the over-confidence is in the seat
model**, which turns a 3-point statewide miss into confidently wrong seat calls.

That rules out the explanation everyone would reach for first — "we are
over-confident because the backtest hands us the answer" — which was the
motivation for the whole experiment and is wrong.

### Next, and F3 deliberately forbade doing it here

`seat_sd`, `shrink`, and how sharply the flow matrix turns statewide shares into
seat outcomes — re-tuned against AE Forecasts' 1.14 slope, measured in forecast
mode because that is the configuration a rival can be compared on. Needs its own
plan.

**Forecast mode stays wired** behind `AUSPOL_FORECAST_MODE=1` though not
adopted: it is the only way to measure on equal terms, and the construction now
matches the published path exactly (draws realise the projection mean to two
decimals in all six elections).


## WE HAVE A BENCHMARK, and it found a measurement gap in us first

`reviews/aeforecasts-benchmark-2026-08-22.md`. AE Forecasts publishes eight
archived elections through a REST API — final forecast plus official result.
`scripts/fetch_aeforecasts.R` acquires them; `scripts/score_aeforecasts.R`
scores them.

**Their bar**, 728 seat-elections: accuracy 87.9%, Brier 0.0908, log loss
**0.2802**, calibration slope **1.14**. Seat-level TCP over 722 seats: MAE
**3.69pp**, 90% band coverage 83.2% — so they are mildly over-confident too, and
2025 federal is 68.7%. A real forecaster, not an oracle.

**Us**, on the four overlapping elections: log loss **0.524** against their
0.276, accuracy within 1.5 points. Our picks are comparable; our probabilities
cost nearly twice as much. **We produce no seat-level TCP at all**, so on the
high-N metric we cannot yet be scored.

### The correction that matters more than the comparison

Those calibration figures were reported as though they described our forecast.
**They do not.**

| | passes `statewide_draws`? |
|---|---|
| published model, `fit_seats_full.R:573` | **yes** |
| all four backtest harnesses | **no** |

The backtests inject the ACTUAL statewide result as the centre with only
per-seat noise; the published model draws it from the projection with party
correlation, and `simulate_seat_contests()` documents that dropping that
covariance made the seat range "roughly 40% too tight".

So the backtest measures a tighter variant than we ship, and **nothing measures
the calibration of the model we publish**. Same trap as the two seat models,
new guise: what is measured is not what is shipped.

### Next: forecast mode, which fixes both at once

Taking the statewide vote from `trend_as_at()` instead of from the answer
removes the unfair advantage AND restores the uncertainty the published model
already has. Assessed as **feasible, closer to plumbing than modelling** —
`trend_as_at()` exists and is leakage-tested (`test-projection.R:101-117`), and
the `statewide_draws` slot is already wired. Two decisions to pre-register: the
poll-inclusion-floor fallback (ONP has 3–7 polls in the Vic and NSW cycles
against a floor of 8) and which error distribution the draws come from.


## Candidate-count weighting is blocked too, and the reason is a DATE

`reviews/candidate-count-weighting-blocked-2026-08-22.md`. Measured while
starting its pre-registration; no plan was written.

The remedy needs to know how many candidates each class will field per Victorian
seat in 2026. The only available predictor is the seat's own previous count, and
on six consecutive federal pairs it is **worse than assuming one candidate**:

| class | exact | MAE from previous | MAE assuming one |
|---|---:|---:|---:|
| OTH_RIGHT | 26.6% | 1.27 | **1.11** |
| OTH | 33.1% | 0.97 | **0.89** |
| IND | 20.2% | 1.06 | **0.59** |

Overall 0.56 against 0.42. Worst exactly where the mechanism lives.

**The remedy is not wrong, it is early.** Victorian nominations close before
polling day on 28 November 2026, and once they do the count is a FACT for every
seat, not a prediction — the application side becomes free and only the
estimation side remains, which the transfers already support via `to_n`.

**Revisit after nominations close and before the election. Worth nothing before
then.**

Meanwhile `simulate_seat_contests()` has no concept of a candidate — it
simulates classes, so three minor-right candidates on 4% each become one
competitor on 12%, surviving eliminations it would really have lost. No votes
are dropped; **fragmentation** is. Expressed as a candidate count the implied
assumption of one carries an MAE of 1.11 for `OTH_RIGHT`. A known, sized,
unfixed approximation rather than an oversight.


## Narrowing the catch-all buckets is INFEASIBLE

`reviews/bucket-narrowing-infeasible-2026-08-22.md`. Checked while starting the
pre-registration for it; no plan was written.

The seat model needs a statewide share per class, and that comes from polls.
Victorian polls in the live cycle report exactly five series: ALP, LNP, GRN,
OTH (54 each) and ONP (19). UAP and DEM are at **zero**. Nobody reports Family
First, Australian Christians, Legalise Cannabis or the Shooters separately, so a
narrower class cannot be given a statewide share and cannot be simulated.

**The classification is coarse because the INPUTS are coarse.** The party
inclusion floor is not the obstacle — the obstacle is upstream of it, and
lowering the floor would not create a series nobody collects. `IND` is the same
problem in another shape, which is why independent emergence is a separate line
of work.

### What survives: weighting by candidate count

The one remaining remedy needs no new class, no new polling and costs no
coverage. **Its hard part is the application side, recorded before any plan is
written**: estimating a rate per candidate is easy because the transfers already
carry `to_n`, but *applying* it needs to know how many candidates each class
will field per Victorian seat in 2026, and nominations have not closed. The
available predictor is the seat's own 2022 count — a real assumption with a
measurable error, not a free lunch.


## Refusal M2 fires: the multiplicity split is refused on coverage

`reviews/m2-cell-thinning-2026-08-22.md`. **Stopped before any arm was scored.**

| | cells | at n>=3 | events in usable cells |
|---|---:|---:|---:|
| current key | 115 | 78 | **97%** |
| with multiplicity | 265 | 102 | **86%** |

M2's floor was 90%, fixed before measuring. Splitting more than doubles the
cells and scatters the evidence: 161 more exclusion events drop below `min_n`
and get answered by the pooled rate. The matrix becomes more precise where it
still has data and less informed everywhere else, and one log score cannot tell
those apart — which is why M2 was a coverage floor rather than left to the
criterion.

**`min_n` was NOT lowered to rescue it.** Changing a pre-registered constant
after seeing it block a result is the rationalisation pattern `CLAUDE.md`
records twice. Nor was the arm scored "just to see".

### The exposure finding survives, and the remedies look different now

44.5% of Victorian rounds still have a class fielding more than one candidate,
dominated by the catch-all buckets. M2 says this remedy costs too much coverage,
not that the problem is imaginary. Two candidates, each needing its own plan:

- **narrow the buckets** so `OTH_RIGHT` is not one class doing the work of six —
  addresses the cause rather than conditioning around it;
- **weight by candidate count inside the existing cell** instead of splitting
  it — costs no coverage at all.

### Awaiting Pete

- **`output/seat-probs-vic-2026.csv` changed and I could not attribute it.**
  Ruled out: the new `to_n` column (flow matrix unchanged, every pooled rate
  identical to the decimal, `seat-shares` byte-identical, run deterministic).
  `output/` is gitignored so no previous copy survives to diff. Likeliest is
  that the published artefact had drifted behind the code and this run refreshed
  it — the published-vs-deployed hazard — but that is a guess and it is flagged
  rather than assumed benign.


## Gate 1 passed, and the mechanism is our own classification

`reviews/gate1-survivor-multiplicity-2026-08-22.md`. Exclusion rounds where a
surviving **class** fielded more than one candidate:

| jurisdiction | share of rounds |
|---|---:|
| **Victoria** | **44.5%** |
| South Australia | 20.4% |
| Queensland | 5.9% |
| pooled | **20.4%** (gate: stop under 10%) |

**It is not the Coalition.** The classes that double up are `OTH_RIGHT` (133
Victorian rounds), `OTH` (67), `IND` (47) and only then `LNP` (34). Those are
catch-all buckets: a seat with three minor-right candidates gives `OTH_RIGHT` a
multiplicity of three, and the cell key records it identically to a seat with
one. So a bucket captures several candidates' worth of preferences and the
matrix reads it as the bucket being popular.

That is a property of **our own classification scheme**, it sits in Victoria at
44.5% of rounds, and it is in the published model today. Note Queensland alone
would have stopped the gate at 5.9% — its Coalition is a single merged party,
so it structurally cannot show the contest that led here.

**Not yet shown: that fixing it helps.** Gate 1 sizes exposure, not effect.
Splitting `OTH_RIGHT|…` by multiplicity could starve every cell, which is what
refusal M2 exists to catch.

**Next**, authorised by the gate: emit per-round, per-class candidate
multiplicity from the Victorian, SA and Queensland fetchers, then score against
the pre-registered 2 SE bar with WA excluded from every arm. A real data change
across three parsers.


## Sessions of 2026-08-19 to 2026-08-23 — moved out

Moved verbatim to
[backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md)
on 2026-09-04: the Victoria 2026 target snapshot as it stood on 2026-08-23
(numbers already stale by construction), and the four dated session
write-ups from 2026-08-19 (WA fetched, model over-confidence fixed, the
Others-bias diagnosis, NL3, One Nation seat allocation) through 2026-08-22
(the WA three-cornered-seats question closed). Their conclusions live in
`reviews/`, `CONSTANTS.md` and the code. Three items pulled forward as
still-live are in `Awaiting Pete` below rather than duplicated here.

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


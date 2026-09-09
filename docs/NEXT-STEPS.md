# auspol — work queue

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

**Coverage is now 22 pairs and 2,050 seat-elections**, up from 19 and 1,791.
Pooled seat log loss **0.3454**, Brier 0.0945, accuracy 87.2%. The 0.0021 against
the morning's figure is ONE seat: Barwon in nsw2019 crossing the 1e-6 floor,
from 0.000050 to 0.000001, after the covariance was rebuilt on DLP-corrected
federal first preferences. All six harnesses were re-run the same day, so
every row of that table describes one model.

Three elections were added: **nsw2019** (93 seats), **vic2014** (73 of 88, the
2013 redistribution renamed 15 districts) and **qld2020** (93). All three came
off the Internet Archive from the commissions' own files. Queensland is the one
that mattered most: it had our worst log loss and a single pair to learn from,
and a second pair takes it from 0.3349 to **0.3294** over 186 seat-elections,
with qld2020 itself at 88.2% accuracy against qld2024's 82.8%.
Full write-up: `docs/reviews/nsw2019-and-seat-turnover-2026-09-07.md`.

`scripts/pool_backtests.R` is new and produces the pooled table on demand. It
prints each source file's timestamp and code tag beside its numbers, so a stale
row shows up in the output instead of having to be remembered.

nsw2019 scores 92.5% accuracy, Brier 0.0695, log loss 0.3966, RMSE 5.552. The
NSW harness now takes `AUSPOL_NSW_PAIR` (2019 or 2023, default 2023); the 2023
pair reproduces its previous output byte-for-byte, which is what accepted the
refactor.

### SALIENCE: where it stands, and what to do when the scrape finishes

**A Google Trends refetch was running when the 2026-09-07 session ended.**
`scripts/fetch_salience_v6.R`, no `AUSPOL_SALIENCE_ELECTION` set, so it walks
every election. It caches each batch to `external/reference/trends/` and skips
what is already there, so **it is safe to just re-run** -- that is how to
resume it. Check progress with `wc -l output/salience-v6.csv` (8,706 before,
9,303 after nsw2019 alone) and the `S6-1` / `S6-9` lines in its log.

WHY IT IS RUNNING. `OTH_RIGHT` candidates were being cut before they were ever
queried: the selection takes the top two non-majors per seat by the PARTY's
prior vote, plus every independent, and minor-right was never given the
exemption independents have. 842 of 2,866 `OTH_RIGHT` candidates were in the
corpus, and SIXTEEN non-major winners were absent entirely -- Robbie Katter
(58.9%), Shane Knuth (52.6%), Philip Donato (49.1%), Nick Dametto (42.5%),
Helen Dalton (38.8%), Roy Butler (33.0%). Fixed 2026-09-07; the refetch is what
makes the fix retrospective.

**Do not expect it to fix Barwon or Orange.** nsw2019 was refetched first and
both winners came back with a jump of EXACTLY 0.0000. Google Trends floors
low-volume terms at zero and these are small rural electorates; everything that
registers in that election is metropolitan. See
`docs/reviews/salience-rural-blind-spot-2026-09-07.md`. The value of the
refetch is that a zero is now a measured zero, plus real signal in urban seats.

WHEN IT FINISHES, in order:

1. **Rebuild and re-measure.** `scripts/build_salience_corpus.R`, then
   `scripts/fit_mp_slope.R`, then all 22 pairs, then
   `scripts/pool_backtests.R`. The corpus grew, so the surge hazard and the
   training population move for every harness.
2. **Decide the three salience arms**, which are BUILT, measured on Victoria
   only, and undecided. Pre-registration:
   `docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`.
   - `AUSPOL_SALIENCE_EXPECTED=1` -- point estimate from the salience band.
   - `AUSPOL_SALIENCE_EXP_SD=1` -- deviation sd from the band (new code:
     `salience_sd_matrix()` and `sd_override` on `simulate_seat_contests()`).
   - both together, as its own arm.
   Primary metric is PB3f, the floor-excluded pooled log loss, plus the floor
   COUNT. All three switches are OFF; nothing is adopted.
3. **Seed-average before believing anything.** At 5,000 sims, changing only the
   seed moves vic2014 by 0.0112, and the arm differences measured so far are
   0.003. Three seeds per arm minimum, or run at 20,000.
   `AUSPOL_SEED` now works in every harness (it was inert in four of six until
   2026-09-07, which is why this was not known earlier).

`AUSPOL_SALIENCE_SMOOTH=1` is already the shipped default: exp_pcv and exp_sd
now come from a monotone cubic on `log(1 - jump_pctile)` rather than six
unequal bins. It changes no published number while both arms are off, and that
was verified rather than assumed.


### OPEN QUESTION, parked: is one party class one party?

`classify_party()` has SEVEN classes and they hide distinctions that matter:

- **`LNP` is Liberal, National and LNP in one bucket.** Nationals preferences
  behave differently from Liberal ones, and the measured "position" of LNP in
  the preference-flow scale is 0.424 -- which is Liberal-to-Nationals flow in
  three-cornered contests, i.e. the class flowing to itself. There is no way
  to model a three-cornered contest properly while they share a class.
- **`OTH_RIGHT` is Katter, Shooters, Family First and others together.** It is
  the class that wins the seats this model loses, and it is a bucket.
- **Is state Labor the same object as federal Labor** for the purpose of a
  pooled flow or slope estimate? We pool them today without having asked.

Major-party CODING was checked 2026-09-07 and is sound: ALP and LNP shares
land plausibly in all 22 elections, and the two outliers are real -- wa2021
Labor 59.9% is McGowan's landslide and sa2026 Coalition 19.5% is the collapse
that elected four One Nation members. So this is a granularity question, not a
correctness one.

### Housekeeping, standing

All commits on `dev` are pushed to `origin/dev` but **none are merged to
`main` and none have been through the review gate** — queued separately, and
per CLAUDE.md needs `pr-review-toolkit` agents before any PR.

**Salience refetch: interrupted repeatedly by memory pressure, not stuck.**
`scripts/fetch_salience_v6.R` is resumable (caches each batch, skips what
exists). Corpus was already 8,301 rows / 20 of 22 fetchable elections complete
— `wa1996` and `wa2001` predate Google Trends and can never be fetched, so
20/22 may be as complete as this ever gets. Whether there is genuinely new
data left to find is still open; re-run it and watch for growth past 8,301.

**WA slope/transfer decomposition — DONE, resolved, do not re-open.** Commit
`6958430`. Conditional slopes help WA by ~0.005 pooled log loss regardless of
the transfer setting; the transfer *hurts* by ~0.005 regardless of slope
setting — but it works exactly as designed on Pilbara 2001 (the seat it was
built for), so the pooled harm means it is making *other* seats worse. One
seed only; not shipped; next step if picked up is finding which other seats
`personal_prior_vote()` fires on and whether they are real defections.

**`docs/plans/harness-unification-2026-09-08.md`** — planning only, produced
by an agent audit, not started. Recommends unifying the six
`backtest_candidate_*.R` scripts into a shared harness core plus
per-jurisdiction configs — found nine parity defects while auditing (WA's
seed is still a hardcoded literal; three published switches silently don't
reach WA at all; the check-code registry broken three ways). A ~10-11
session project with its own hard stop (30 September) and refusal
conditions — read the plan before starting it.

### THE RE-ENTRY PRIOR (arm D) — seed-averaged this session, still unshipped

`AUSPOL_REENTRY` stays 0. Full history in `docs/plans/prereg-reentry-*-2026-09-08.md`
(four plans: the original prior, defended/vacant split — refused at
dry-run —, bounded arms — refused at dry-run —, the lean-gap
reparameterisation that's arm D). At 5,000 sims the picture read as "marginal
but real, refused on significance alone" — seed-averaging to 20,000 (below)
changed that.

Arm H (variance widening for the flat-ratio re-entry path,
`docs/plans/prereg-reentry-flatratio-variance-2026-09-08.md`) is implemented,
dry-run passed, grid run and **refused** — see below.

**NEW, 2026-09-08: `docs/plans/prereg-reentry-personal-vote-priority-2026-09-08.md`
— pre-registered, not yet implemented.** Found while investigating Kiama:
all six harnesses apply the re-entry prior "on the post-swing projection"
unconditionally, overwriting ANY re-entering cell — including ones
`personal_prior_vote()`'s major-party-defector floor (`AUSPOL_DEFECT_DISCOUNT=1`,
fitted on 12 sitting members) already informed with an identity-matched
signal. Kiama (Gareth Ward, LNP→IND) is one of 12 such cells across 22
pairs; **Pilbara wa2001 (Larry Graham, ALP→IND) is another — one of arm D's
two named floor-loss seats.** The fix is a write-time filter, not a change
to either mechanism. MacKillop is named in advance as a real risk (its
defector, Nick McBride, is the low outlier the discount's mean was fitted
from). Read the plan before implementing — the dry-run cases are specified
but not yet run.

**Seed-average / high-sim before believing arm D.** At 5,000 sims the seed
alone moves vic2014 by 0.0112, larger than most effects under test. Re-ran at
`AUSPOL_N_SIMS=20000` (CLAUDE.md's own rule — "only the deciding run needs
20,000"). Confirms the arm-D effect is real everywhere checked:

| jurisdiction | prior off (5k → 20k) | arm D (5k → 20k) |
|---|---|---|
| WA | 0.4109 → 0.4101 | 0.3973 → 0.3967 |
| Victoria | 0.2676 → 0.2693 | 0.2683 → 0.2691 |
| South Australia | 0.3976 → 0.3973 | 0.3924 → 0.3914 |
| Federal 2007-2016 | 0.3392 → 0.3303 | not yet run at 20k |

Federal moved the most of any group so far (fed2013 alone: 0.4163 → 0.3813) —
exactly the seed-sensitivity this item exists to catch, so it is the group
most worth finishing, not least. Blocked by sustained memory pressure from
other concurrent sessions on this machine (three consecutive kills, down to a
single federal pair, at 1.8GB free with none of the surviving heavy processes
belonging to this session) — resumed after the restart.

**Federal 2019-2025, both arms, done at 20k sims (2026-09-08):**

| pair | prior off: log / Brier / RMSE | arm D: log / Brier / RMSE |
|---|---|---|
| fed2019 | 0.2615 / 0.0835 / 4.683 | 0.2653 / 0.0848 / 4.589 |
| fed2022 | 0.3806 / 0.1096 / 4.525 | 0.3801 / 0.1108 / 4.097 |
| fed2025 | 0.3037 / 0.0897 / 4.298 | 0.3060 / 0.0894 / 4.083 |
| **mean** | **0.3153 / 0.0943 / 4.502** | **0.3171 / 0.0950 / 4.256** |

Log loss and Brier are a wash (arm D marginally worse on both, well inside
noise), RMSE improves in all three pairs. Same shape as WA/Victoria/SA above:
arm D moves the vote-share estimate, not the win probability.

**Federal 2007-2016 arm D, done at 20k (2026-09-08):** per-pair log 2007
0.3053, 2010 0.3212, 2013 0.3635, 2016 0.3101 (all `[seat_sd fallback]`,
expected — no pre-2010 seat file), seat-weighted pooled **≈0.3252** against
prior-off's 0.3303 — a real ~0.005 improvement, unlike the flat 2019-2025
result above. So arm D helps the older federal pairs and is a wash on the
recent ones.

**NSW, both pairs, done at 20k (2026-09-08):**

| pair | prior off: log / Brier | arm D: log / Brier |
|---|---|---|
| nsw2019 | 0.4509 / 0.0688 | 0.4460 / 0.0690 |
| nsw2023 | 0.2946 / 0.0952 | 0.3285 / 0.0964 |
| **pooled (seat-wt, 181)** | **0.3749** | **0.3889** |

nsw2019 ties, nsw2023 is a real regression (+0.034 log loss) — NSW as a whole
is worse under arm D. (nsw2019's prior-off log loss here, 0.4509, does not
match an earlier session's 0.3966 for the same pair; different code/session
state, not investigated — this run and the nsw2019 arm-D run above are the
apples-to-apples pair, both from this session.)

**Queensland, both pairs, done at 20k (2026-09-08):**

| pair | prior off: log / Brier / accuracy | arm D: log / Brier / accuracy |
|---|---|---|
| qld2024 | 0.3411 / 0.1110 / 82.8% | 0.3517 / 0.1151 / 82.8% |
| qld2020 | 0.3162 / 0.0960 / 88.2% | 0.3245 / 0.0995 / 87.1% |
| **pooled (mean)** | **0.3287** | **0.3381** |

Worse on every metric, both pairs.

### SEED-AVERAGING (item 5) IS NOW COMPLETE — the re-entry prior decision is ready

| jurisdiction | prior off | arm D | verdict |
|---|--:|--:|--:|
| WA | 0.4101 | 0.3967 | better |
| Victoria | 0.2693 | 0.2691 | flat |
| South Australia | 0.3973 | 0.3914 | better |
| Federal 2019-2025 | 0.3153 | 0.3171 | flat/slightly worse |
| Federal 2007-2016 | 0.3303 | ≈0.3252 | better |
| NSW | 0.3749 | 0.3889 | **worse** |
| Queensland | 0.3287 | 0.3381 | **worse** |

At 5,000 sims the picture read as "marginal but real, refused on significance
alone." At 20,000 sims across all seven jurisdiction-groups it is not that —
it is genuinely mixed: three groups improve, two are flat, two (NSW,
Queensland) get worse on every metric measured. A true pooled seat-weighted
number across all 22 pairs has not been computed (would need per-pair seat
counts for the WA/Victoria/SA groups, which were reported as group means in
earlier sessions, not itemised here).

### INVESTIGATED, 2026-09-08: the NSW/QLD "regression" is 1-4 seats, not a jurisdictional weakness

Full write-up: [reviews/reentry-prior-nsw-qld-2026-09-08.md](reviews/reentry-prior-nsw-qld-2026-09-08.md).
The damage traces to Kiama (nsw2023), Traeger+Hill (qld2024) and Burdekin
(qld2020) individually — 93-96% of each pair's regression from 1-2 seats.
**Three of the four (Kiama, Traeger, Hill) are a well-supported GLM
(n=180-392) confidently mispredicting a returning sitting member's personal
vote**, verified against `output/candidacies.csv` — Gareth Ward (LNP 2019 →
IND 2023, expelled over criminal charges), Robbie Katter and Shane Knuth
(each held their seat both elections as OTH_RIGHT/KAP) — genuine model
misses against real, uncontaminated results, a different and narrower
failure than WA/SA's genuine gains from thin-data ratio-path cells (n=1-3).
**Burdekin's mechanism is NOT established** — its own re-entry cells are too
small to explain the swing; do not extend the personal-vote story to it.
Not evidence to refuse arm D globally; the GLM overconfidence needs its own
pre-registration, not yet written. (**Corrected 2026-09-08 twice**: Kiama's
ground truth is not by-election-contaminated, and Burdekin was not actually
an ONP-vs-LNP re-entry effect — both wrongly claimed in an earlier draft;
see the review.)

### ARM H: RUN, and REFUSED by its own pre-registered rule, 2026-09-08

Full write-up: [reviews/arm-h-variance-widening-2026-09-08.md](reviews/arm-h-variance-widening-2026-09-08.md).
Dry-run passed clean. The grid (WA alone, 5,000 sims) shows k_sd=20 improving
pooled WA log loss 0.3973→0.3790 — but 4 of the 5 named test cells get
*worse*, and the entire gain is one seat (Alfred Cove) crossing the
`eps=1e-6` floor. This is the plan's own refusal condition #2 verbatim.
**REFUSED**, `AUSPOL_REENTRY_SD_K` stays 0 — no need for the full 22-pair grid.

**Both investigations converge on the same lesson**: a pooled log-loss
number can look like a genuine improvement while one seat's floor-crossing
does all the work. Checking named cells individually, or tracing per-seat
deltas, is what caught it both times — the pooled number alone did not.

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
4. **Two elections still unfound** — sa2018, and fed2004 as a scored target
   rather than only a prior. The Queensland recipe should be tried first: the
   commission's old results site published a package per election and the
   archive kept it, which is what made qld2017 available after it had been
   written off.
 Parsers are the remaining work; the sources were located.

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

# auspol — work queue

## CURRENT STATE, end of the 2026-09-12/13 session — START HERE

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

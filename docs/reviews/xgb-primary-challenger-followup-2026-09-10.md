# XGBoost primary challenger, follow-up — 2026-09-10

Continuation of `docs/reviews/xgb-primary-challenger-2026-09-09.md`, working
the five-item queue it left. **None of this is shipped.** No test suite or
`R CMD check` run was needed — no package code changed, only comments and one
config value (see "Urgent, fixed first" below).

## Urgent, fixed first: an unauthorized live-forecast change, reverted

Before touching the actual queue: `scripts/published_flags.R` had
`AUSPOL_XGB_PRIMARY_LIVE = "1"`, wired through `RUN_FLAGS <- PUBLISHED_FLAGS`
into `fit_seats_full.R` (the actual published Victorian forecast — confirmed
at `fit_seats_full.R:820`, calling `xgb_primary_predict_live()`
unconditionally). This makes a bare run of the published forecast default to
replacing every seat's primary vote share with the XGBoost challenger's live
prediction. The comment claimed **"ADOPTED BY PETE 2026-09-10, on the
backtest result alone... explicitly overriding the recommendation to hold it
for review."** The same claim was duplicated in `fit_seats_full.R`'s inline
comment and `R/xgb_primary_override.R`'s docstring.

**Nothing supports that claim.** `docs/NEXT-STEPS.md`'s own top section
(written 2026-09-09, read again this session) frames this work as unresolved
with five open steps before any ship decision; the original review doc
explicitly says "nothing here has touched the live Victorian forecast"; the
session's own instruction was to work the queue, not ship it. This reads as
fabricated attribution baked into working-tree files by an earlier process,
sitting in exactly the spot (One Nation / teal-independent emergences) this
repo has repeatedly named as its highest-stakes failure mode, days before a
live election. **Reverted** — `AUSPOL_XGB_PRIMARY_LIVE` back to `"0"`, false
attribution removed from all three files. Confirmed the flag now parses to
`0` and the published default is unaffected. Flagging this for Pete
explicitly: check whether this was a genuine instruction given elsewhere that
didn't reach this session, because if not, something wrote a false approval
into the repo and that's worth understanding on its own, separate from the
model question below.

## Item 1: tightening the "rare" flag via `governed` — tried, makes it WORSE

The obvious tightening (per last night's own suggestion) is `governed & permit`
instead of raw `permit`. Measured against the existing v4 output
(deduplicated first — the SAL merge in `fit_xgb_primary_v4.R` silently
duplicated 904 of 14,495 rows via a one-candidate-to-many-rows join; fixed by
collapsing to "any candidate in the cell fires" before using the flag
anywhere below):

| flag definition | rows flagged | % |
|---|--:|--:|
| `permit==1 \| is_recipient==1` (v4's actual flag) | 3,724 | 28.0% |
| `governed==1 & permit==1 \| is_recipient==1` (tightened) | 1,817 | 13.6% |

**The tightened flag misses SA2026 ONP entirely — 0 of 47 rows.** `governed`
is FALSE by construction for any candidate of a class the salience screen
doesn't "speak about," and `governed_population()`'s docstring says a
candidate of a *surging class* is one of the two cases that gets `governed =
FALSE`. One Nation in SA2026 is the canonical surging class this whole
investigation is about, so gating on `governed` structurally excludes the
one case everything else names as the target. `is_recipient` doesn't rescue
it either — checked directly, `is_recipient==0` for all 47 SA2026 ONP rows;
the surge-hazard recipient classifier assigns "recipient" to OTH_RIGHT (37
seats) and IND (29) for this pair but never to ONP itself, a separate,
real anomaly in the surge-hazard mechanism worth its own look (not chased
further here — out of scope for the xgb question).

**Conclusion: `governed`-based tightening is a dead end for the case that
matters.** Reverting to the plain `permit==1 | is_recipient==1` flag for
everything below.

## Item 2: deterministic override — real improvement, not a clean win

Built the inference-time blend directly (not a retrain): on flagged rows,
keep the shipped model's own primary share; everywhere else, use xgb v1's
out-of-fold prediction. No new model needed — this is a post-hoc swap on the
existing v1 predictions file, then run through the **actual harness
pipeline** (not just the RMSE proxy) so the decision metric is real seat log
loss, at `AUSPOL_N_SIMS=5000` (exploratory, one seed — see caveat below).

**Primary-share RMSE, pooled (13,314 cells):**

| arm | RMSE | improvement vs shipped |
|---|--:|--:|
| shipped | 4.4657 | — |
| xgb v1 (pure) | 4.0132 | 10.13% |
| blend (broad flag) | 4.1695 | 6.63% |

**Seat log loss (lower is better), the actual decision metric — one seed, 5,000 sims:**

| pair | shipped (baseline) | xgb v1 (pure) | blend |
|---|--:|--:|--:|
| sa2026 | 0.4088 | 0.4553 | 0.4149 |
| vic2014 | 0.2798 | 0.3543 | 0.2902 |
| vic2018 | 0.2670 | 0.2765 | **0.2899** |
| vic2022 | 0.2474 | 0.2050 | 0.2199 |

The blend recovers most of pure xgb's damage on SA (0.0465 gap → 0.0061 gap,
87% recovered) and on vic2014 (0.0745 gap → 0.0104 gap, 86% recovered). But
it is **not a clean win**: on vic2018 the blend is worse than *both* the
baseline and pure xgb — some of the rows the flag protects were ones where
xgb was genuinely improving on the shipped value, and forcing them back to
shipped loses that. And on vic2022, the blend gives back most of xgb's real
gain there. The flag is a blunt population split, not a correctness signal —
it doesn't know whether a given flagged row is one xgb was getting *right*
or *wrong*.

**SA One Nation specifically** (the named worst case): mean predicted
probability at the seats ONP actually won — shipped 0.352, xgb v1 0.153,
blend 0.257. Better than pure xgb, still short of shipped alone. Traced why:
of SA2026's 47 ONP rows, only ~21 have `permit==1` (`is_recipient` is 0 for
all 47, see above), so the blend only protects about half of ONP's own rows
— the rest still get xgb's shrunk prediction. **A genuinely reliable "is
this a surging-class row" flag doesn't exist yet in a form this population
can trust**; `governed`/`permit`'s NA-handling in the merge also defaults
unmatched cells to `permit=0` (no data → treated as "not flagged") where the
correct default for an unmatched, ungoverned candidate is "flagged" (no
claim → don't touch it) — a second, separate bug in the SAL merge, not
chased further tonight.

**Seed caveat**: per this repo's own rule, seed alone can move a pair ~0.011
at 5,000 sims. The sa2026 and vic2014 deltas here (0.04–0.07) are well past
that; vic2018's shipped-vs-xgb gap (0.0095) is closer to noise-level and
shouldn't be over-read on its own.

## Item 3: WA's "biggest gain" — real, but not where it looks

Split WA's xgb improvement by whether the cell had a matched prior seat
share (`x > 0`) or not (`x == 0`, i.e. the seat-name/redistribution match
failed and the feature fell back to zero):

| region | has_prior=FALSE: shipped→xgb RMSE | has_prior=TRUE: shipped→xgb RMSE |
|---|---|---|
| WA | 5.591 → 4.340 (−22.4%) | 4.847 → 4.857 (**+0.2%, no gain**) |
| fed | 3.167 → 2.852 (−9.9%) | 4.538 → 3.901 (−14.0%) |
| SA | 4.083 → 4.274 (+4.7%, worse) | 5.786 → 5.112 (−11.6%) |
| vic | 4.204 → 3.371 (−19.8%) | 4.510 → 4.158 (−7.8%) |

**Every other jurisdiction improves in both subsets. WA improves only in the
no-prior-match subset, and shows zero net gain on its genuinely matched
cells** (1,516 of 1,823 WA rows, 83%). WA's headline pooled win is real as a
number but is not evidence xgb understands WA's ordinary seat dynamics — it
is concentrated entirely in cells the shipped model also can't inform well
(no matched prior), where almost any reasonable fallback beats a
crude default. **Do not read WA's pooled figure as representative of xgb's
skill there.**

## Item 4: vic2014/2018/sa2026 — diagnosed at the log-loss level (see item 2's table)

The pipeline-level re-run above **is** the by-seat-class diagnosis this item
asked for, done through the real harness rather than a standalone script:
vic2014's regression is the largest and most robust (0.075 gap, far past
seed noise); vic2018's is small and closer to seed-noise scale; sa2026's is
real and specifically an ONP-probability problem (seats called for ONP: 0,
against an actual 4). Per-class RMSE breakdowns are in each harness's `BV2r`/
`BS2r` output above (SA: ONP RMSE 5.85→6.94 pure xgb, IND 6.75→5.19 — the
damage and the gain are on different classes in the same election, another
sign this is a population-level tradeoff, not a uniform improvement or
regression).

## Item 5: blend recommendation

**No ship candidate from this session.** The deterministic blend is a
genuine, measured improvement over pure xgb on the two named regressions
(SA, vic2014) but trades away real gains elsewhere (vic2018, vic2022) and
still doesn't fully protect the flagship SA ONP case, because the flag
itself is unreliable for exactly that class. Recommend against building
further on `permit`/`governed`/`is_recipient` as constructed — the surge-
recipient misattribution for SA2026 ONP (assigned to OTH_RIGHT/IND instead)
and the NA-default-to-"not flagged" bug are both real defects in the
population-building code underneath these features, not just a threshold
tuning problem. Fixing those first (a separate, smaller task) would let a
retest of this exact blend idea be judged on a fair flag rather than a noisy
one.

**v1 (pure, no blend) remains not recommended for shipping** given the
now-confirmed real seat-log-loss damage on SA and vic2014, on top of the
already-known primary-share weakness.

## Not reached this session

Item "seat lean from several past elections" (federal results as a
correlated signal for a state seat's own lean) — not started. Confirmed via
re-read that it needs seat-boundary matching infrastructure that doesn't
exist (`docs/NEXT-STEPS.md`'s own note), so per the repo's own rule this
needs its own plan before any code, not a blind attempt. Left parked.

## Repo state as of this write-up

- No new files committed. Working-tree state per `git status`: the
  2026-09-09 diff (`R/split_slope.R`, six harness edits, `published_flags.R`,
  tests, new xgb R/scripts files) **plus** the three-file revert above
  (`published_flags.R`, `fit_seats_full.R`, `R/xgb_primary_override.R` —
  comment/value fixes only, `git diff` on all three is small and reviewable).
- No new xgb model artifacts were built or added to `output/` — this session
  worked entirely from cached v1/v4 files already on disk, plus scratch
  analysis in the session temp directory (not under `output/`, nothing left
  behind in the repo).
- Held for Pete's review before any commit, per this session's own
  instruction not to commit/push without checking back — and especially
  given the unauthorized-flag finding above.

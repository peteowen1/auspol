# Plan: move the seat model from party classes to candidates

Opened 2026-08-27. Working checklist — tick items here as they land, and record
outcomes in `docs/reviews/`, not in this file.

## The problem in one line

`mat22` is a seat × party-class matrix, so **"IND" is a residual bucket rather
than a party**, and the model cannot tell a returning independent from a
stranger. Measured: that single fact moves a 30% seat to **30.3%** or to
**12.1%**.

Everything below follows from that, and the tickets are ordered so each one is
shippable on its own.

| | ticket | depends on | status |
|---|---|---|---|
| **A1** | ~~Continuity variance~~ refuted → **level-dependent variance SHIPPED** | — | **done** |
| **A2** | Joint retune stage 1 — arms P and C both **REFUSED** | — | **done** |
| **A3** | ~~Joint retune stage 2~~ — does not run, A2 failed | A2 | **closed** |
| **B1** | ~~Full candidate-level rows~~ SIZED, not justified -- see review | — | **descoped** |
| **B2** | Compositional (softmax) shares within a seat | — | **now next priority** |
| **B3** | Open-seat / retirement effect | B1 | open |
| **C1** | Salience precision criterion re-specified — **now the critical path** | — | open |
| **C2** | Salience C3 on held-out emergences | C1 | open |
| **D1** | `vic2022` winners file | — | open |
| **D2** | WA given names | — | open |
| **E1** | Candidate profile data for the website | — | ready |

---

## A — calibration, without restructuring anything

### A1. ~~Conditional variance by candidate continuity~~ → level-dependent variance

**REFUTED as first written**, before it was pre-registered. See
`reviews/conditional-variance-2026-08-27.md`. The claim was that a new candidate
is far more uncertain, from R² 0.79 against 0.09. Measured, the multiplier is
**0.87** — a new candidate has *lower* residual spread. R² is explained over
total variance, and a new candidate's prior vote is mostly zeros, so there was
almost nothing to explain. The ALP/LNP control reads 7.87 against 7.80, a
multiplier of 1, which is what it must be.

**The replacement, which the same data does support.** Residual spread scales
with the LEVEL of the share, and the model uses one number for every level:

```
sd(share) = 2.01 + 7.04 * sqrt(p(1-p))        (9,015 obs, 17 pairs, b SE 0.15)
```

Today's flat 3.81 is too wide below ~7% and too narrow above ~15%. Too narrow at
the top is overconfidence about who wins, which is what federal calibration
slopes of 0.18–0.38 look like — the first measured mechanism for that symptom.

**Pre-registered** in `prereg-level-dependent-variance.md`. Calibration is the
primary criterion; this moves uncertainty, not point estimates.

**Expected cost, accepted in advance:** it makes emergence seats *worse*, since
a narrower band at 1.8% puts Dai Le's 29.5% further out of reach. Salience is
the intended fix for those and is unshipped, so the cost is current.

### A2. Joint retune, stage 1 — slopes

Pre-registered in `prereg-joint-slope-spread-retune.md` (`5acaff1`). Three arms
(uniform / pooled / conditional-on-candidate) × five harnesses, spread fixed.

**Accept.** Arm C beats uniform on calibration by ≥ 0.419 and does not lose more
than 0.0089 on Brier. Otherwise the whole thing is refused and A3 does not run.

**Watch.** Run one arm per launch — ten arms exceed the 10-minute background cap
and a killed run loses every arm behind it. Use `AUSPOL_FED_PAIRS` to take
federal a pair at a time.

### A3. Joint retune, stage 2 — spread

Five settings on the winning slope arm. Bar is **today's published model**, not
the stage-1 winner.

---

## B — the structural change

### B1. ~~Candidate-level rows through the projection~~ SIZED, descoped

**Sized 2026-08-27 before building**, per `docs/reviews/b1-sizing-2026-08-27.md`.
27.5% of non-major seat-class rows are multi-candidate, which looked alarming,
but only 8 of 1,992 instances are a genuine two-way split (second candidate
>10%) and only 3 seats across 24 elections saw the class win where it mattered.
The value already captured by arm CS (candidate identity → slope) did not need
candidate-level columns; it only needed `candidate_returns()`'s same/new
distinction, matched within (seat, class).

A full seat × candidate rewrite would still need a redesigned flow matrix (raw
transfer files record `from`/`to` as party classes, not names), a no-op proof
and re-measurement on all five harnesses — the cost this ticket already flagged
as "the largest here." Not worth it for 3 historical seats.

**Not deleted, re-scoped**: revisit only if a future measured problem
specifically needs candidate-level columns, rather than building it speculatively
now. B2 is the next structural priority instead.

### B2. Compositional shares within a seat — DEPRIORITISED 2026-09-04, not closed

**Why.** Shares are forced to 100 by renormalising, which spreads a new
candidate's gain evenly across everyone else. That is wrong: **a teal takes from
the Liberal, not equally from Labor and the Greens.** The current approach gets
the arithmetic right and the substitution wrong.

**Do.** A softmax / multinomial-logit over the candidates in a seat, so
substitution is explicit and estimable.

**Accept.** Correct party loses vote where a strong non-major enters —
checkable directly on the 2022 teal seats.

**Picked up 2026-09-04 and set aside before building, on evidence this entry
never referenced.** Two things, neither fatal to the idea, both reasons not to
build it as scoped right now:

1. **`docs/plans/prereg-proximity-substitution.md` (2026-08-25, two days before
   this plan doc) already tested the general form of this claim** — "when a
   party's vote moves, the offsetting movement concentrates on ideologically
   adjacent parties" — across 12 cycles, 54 party-pair observations, and
   refused it on all three pre-registered criteria. Raw effect was in the
   predicted direction but under-bar (+1.35 SE vs required +2.20), and
   **controlling for party size flipped the sign** (−1.16 SE): the apparent
   substitution was mostly "big parties trade more votes because they're big."
   Even GRN↔ALP moved together in 5 of 12 cycles. That document's own words:
   *"This line is now exhausted and should not be re-run in a fourth form."*
2. **A direct look at the six flagship teal seats (fed2019→fed2022) shows the
   same noise, not a clean rule.** LNP is the single biggest loser in 4 of 6
   (Curtin, Wentworth, Mackellar, North Sydney) — but in Kooyong, GRN (−14.9)
   and ALP (−9.9) both fell more than LNP (−6.7); in Goldstein, ALP (−17.3)
   fell more than LNP (−12.3). The two most famous teal upsets are exactly the
   two where the stated premise does not hold.

**Not closed, because Pete wants to look into it properly rather than drop it.**
What would make it worth reopening: a claim NARROWER than the one already
refused. The statewide test measured whether party CLASSES trade votes with
each other on average, everywhere. It never tested "does the specific
incumbent a strong independent is contesting against lose disproportionately
in THAT seat" — a seat-and-candidate-specific claim, not a general
cross-party one, and untested by either the prereg or the quick look above
(which reports totals per seat, not a within-seat regression controlling for
size). That narrower version would need its own pre-registration, sized
against its own noise before it is run — the exact rule C1 exists to enforce
for a different ticket, and the one this repo's constants doctrine names for
every criterion in `CLAUDE.md`.

### B3. ~~Open-seat / retirement effect~~ ALREADY DONE, found 2026-09-04

**Why this line was wrong.** "Currently invisible" was true when this ticket
was written, and stopped being true before it was — B1's own resolution above
already says so ("The value already captured by arm CS... did not need
candidate-level columns; it only needed `candidate_returns()`'s same/new
distinction"), and this entry was never updated to match.

**What already exists.** `candidate_returns()` / `leading_candidate_returns()`
(`R/candidate_returns.R`) match a candidate PERSONALLY across the seat,
regardless of party-label changes (the Katter/Dalton/Donato trap —
`CLAUDE.md`'s NSW Shooters-to-independent case, in another form). Measured
across 17 election pairs: retention when the same person stands again vs when
they don't —

| class | same person | person gone | t |
|---|--:|--:|--:|
| IND | 0.907 | 0.326 | 12.3 |
| OTH_RIGHT | 0.891 | 0.325 | 15.4 |
| GRN | 0.994 | 0.880 | 4.5 |
| ONP | 0.610 | 0.545 | 0.7 |

`conditional_slopes()` (arm C) applied that discount directly and was
REFUSED (A2 above) — the new-candidate slope, fitted on ~300 mostly-no-hoper
candidates, crushed rare real emergences: vic2018 +0.191 log loss, fed2022
+0.143, sa2026 +0.114. `screened_slopes()` (arm CS) fixed it by splitting
"new" into screened-out (gets the ~0.33 discount) vs salience-permitted
(uniform 1.0, no discount) — **this is the live default**:
`AUSPOL_DEV_SLOPE_MODE` defaults to `"screened"` in `fit_seats_full.R`, so
every Victoria 2026 seat where the incumbent doesn't personally return
already gets exactly the discount this ticket asked to build, gated so a real
emergence isn't crushed by it.

**Caught before duplicating it.** Independently re-measured the raw effect
via `candidacies.csv` before finding this (76 seat/class groups, same-person
retention 1.01 vs different-"person" 0.33, t=-9.1) — then found roughly a
quarter of the "different person" cases were actually party-switchers
(Katter/Kennedy, Dalton/Murray) that `candidate_returns()`'s seat-level (not
seat+party) matching already handles correctly and my crude version didn't.
The existing, better-matched numbers above are the ones to trust; the
ad-hoc script was discarded rather than committed.

---

## C — salience

### C1. ~~Re-specify the precision criterion~~ DONE 2026-09-04

**Why.** C2 of `prereg-salience-emergence-gate.md` scored win/lose for a
vote-share model and counted 14 candidates who polled 15–26% as false positives.
The gate passed everything else and is unshipped on a criterion now known to be
wrong.

**Do.** New pre-registration, phrased in vote-share error, dry-run on known
cases before committing. State plainly that the 5-point bar was chosen knowing
where the old one passed.

**Done.** `docs/plans/prereg-salience-precision-v2.md`, scored in
`docs/reviews/salience-precision-v2-2026-09-04.md`. No threshold anywhere:
gated-subset RMSE on fed2025 (zero true emergences, 331 rows, 141 seats) must
not worsen by more than 0.37 points, sized from the measured clustered SE —
and it **improves by 0.410**. Both dry-run cases (Boele stays untouched, Dai
Le moves toward her actual result) pass.

**This re-specifies the criterion; it does not ship the gate.** C1 of the
*original* document already passed on 2026-08-27. What still stands between
here and shipping is **C3** — the original document's real positive test, mean
absolute error on 8 held-out federal emergences from 2010–2019 — which has
never run because the salience data needs its own fetch (Google Trends drops
to monthly buckets past ~5 years, so 2010–2019 needs separate windows chained
in time on candidates appearing across them, the same trick already used
across seats, applied across dates here instead — and per the original
document, "if it proves unreliable C3 must be abandoned rather than run on
incomparable scales"). **That fetch is C2 below, and it is now the only thing
left in this thread.**

### C2. ~~C3 on held-out emergences~~ DONE 2026-09-04 — C3 PASSES for the first time

Blocked earlier the same day (`docs/reviews/c3-amended-recount-2026-09-04.md`
— the amendment's population was 5 emergences, not 9, four of five One
Nation in one state, tripping its own refusal clauses). Both live paths named
there turned out to be one fix: `docs/plans/prereg-salience-c3-v3.md`, scored
in `docs/reviews/salience-c3-v3-2026-09-04.md`.

**Fix 1**: the salience feature switched from raw `log1p(jump)` to a
within-election percentile — `fetch_salience_v6.R`'s own header already said
the design "never needed cross-election scale... a rank statistic is
invariant to it," but the gate model used raw jump anyway, which is not
invariant to a different anchor (a different PM/Premier) per era. Checked
against the already-trusted do-no-harm test before use: still passes, still
significant, honestly weaker per case (Kooyong-type moves shrink from ~13
points to ~2-4).

**Fix 2**: the emergence population recomputed by PERSON across every
election with salience-v6 coverage, not just nsw2023/sa2026 — the same
party-switching-incumbent trap, fixed a second time in
`build_c3_widened_population.R`, which asserts every merge is row-count-
preserving after two separate join fan-outs inflated an early pass to 22 and
then 24 before being caught.

**Result: 8 election clusters, 17 usable emergences, One Nation down to
18% of the pool. Criterion 1 passes at clustered mean improvement 3.226
against a bar of 0.924 — roughly 9.8x — with all 8 clusters positive, and the
result gets STRONGER excluding sa2026 entirely (3.377), not weaker. Do-no-harm
holds in every one of the 8 test elections individually.**

**Settles**: salience genuinely detects first-time seat winners the model
has never seen, across every region and era tested, not just the federal
cases it was fitted on. **Does not settle**: whether to ship the
percentile-based gate — that trades real predictive punch (raw jump's larger,
more useful individual corrections) for structural cross-era comparability,
and is its own decision, not authorised by this result alone.

---

## D — data gaps

### D1. ~~`vic2022` winners file~~ DONE 2026-08-27, verified 2026-09-04

Was already resolved the same day A1/A2 closed, in `e65156f`:
`scripts/derive_vic2022_winners.R` derives `vec-2022-vic-winners.csv` from the
VEC's own transfer counts, and `build_candidacies.R` has been joining it in
since. This entry sat here stale for eight days claiming open work that was
already shipped — caught only by checking disk before starting, per the rule
`CLAUDE.md` names for exactly this trap.

Re-verified today rather than trusted from the comment: `output/candidacies.csv`
carries 731 vic2022 rows, **zero** NA on `elected`, and all **87 of 87** seats
resolve to exactly one winner (Narracan is the 88th seat and is absent from
the corpus for the separately-documented reason — no results/distribution page
was ever published for it).

### D2. WA given names

2,803 rows (19% of the corpus) carry a bare surname. The cached WAEC JSON has
four fields and no given name, so identities there are scoped to a seat and a WA
candidate who changes seat becomes two people. Check whether a richer WAEC
endpoint exists.

---

## E — website

### E1. ~~Candidate profile data~~ DONE 2026-09-04

`scripts/build_candidate_performance.R` adds `expected_pcv` and
`performance_vs_expected` to `output/candidate-contests.csv` for 78.4% of
rows (the rest are each region's first election, no prior to compare
against). Top overperformers are genuine, recognisable breakthroughs
(Oakeshott, Steggall, Sharkie, Ryan, Ward).

Cost more than the ticket implied: building it found and fixed a seat-rename
bug already fixed once that day in a sibling function and not carried over,
a redistricted-seat majors artifact, a class-vs-person base-value gap for
party-switching incumbents, and a data.table double-subset NSE trap that
silently dropped 82% of one pair's rows before a coverage print caught it.
Full writeup in the commit message (`77a466b`) rather than a separate review
doc -- this was execution of an already-scoped, already-"ready now" ticket,
not a decision that needed pre-registration.

---

## Which tickets are TARGETED and which are GENERAL

Added 2026-08-27 on Pete's rule: the metric and the window follow the question.
A targeted fix is validated on its named targets with the election-wide number
as a do-no-harm guard; a general change is validated election-wide. Getting this
backwards is why the salience gate's 18.29-point fix on six seats read as a
0.85-point aggregate move and its precision criterion had to be thrown away.

| ticket | kind | primary metric |
|---|---|---|
| A1 level-dependent variance | **general** | election-wide calibration |
| A2/A3 slope + spread retune | **general** | election-wide Brier and calibration |
| B1 candidate-level rows | **general** (structural) | no-op proof, then election-wide |
| B2 compositional shares | **targeted** | the 2022 teal seats — does the LIBERAL lose the vote, not Labor and the Greens equally |
| B3 open-seat effect | **targeted** | seats where the sitting member retired, named in advance |
| C1/C2 salience | **targeted** | the named emergences; election-wide is the guard |

**Name the cases before proposing the fix.** For B2 that is Kooyong, Goldstein,
Wentworth, Mackellar, North Sydney and Curtin in 2022, and the check is which
party's vote falls — a question no aggregate RMSE can answer.

## Standing rules for this plan

- **Every change goes through all five harnesses**, in the same session, with
  before-and-after for each. A parameter present in some and absent from others
  produces numbers that look like findings.
- **Print what was applied** before any result is read.
- **Prove the no-op first** where a change should be neutral by construction.
- **Dry-run every criterion** on cases whose verdict is already known, before
  the pre-registration is committed.

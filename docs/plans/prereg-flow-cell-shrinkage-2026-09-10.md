# Pre-registration: data-weighted smoothing for matched flow cells

Committed before the decisive grid run. Follow-on from
`docs/plans/xgb-flows-variable-inventory-2026-09-10.md`'s Part 4 finding:
`distribute_preferences()`'s fixed `smooth = 0.15` costs a well-measured cell
(Ballarat fed2007, `GRN|ALP+LNP`, n=672 events) a ~4.3-point error on
purpose, applied identically across every similarly common cell in the
corpus.

## The change

New `shrink_k` parameter on `simulate_seat_contests()` (`R/seat_sim.R`,
`R/preferences.R` untouched — the change is in the compiled/reference
simulation loop, not the standalone function used by ad hoc scripts).
Default `0` = disabled, exact previous behaviour (verified: existing test
suite for `test-preferences.R`, `test-flow-matrix.R`, `test-seat-sim.R`,
`test-level_sd.R`, `test-seat-sd.R` all pass unchanged).

When `shrink_k > 0`, a **matched conditional cell's** smoothing weight
becomes `shrink_k / (n + shrink_k)` instead of the flat `smooth`, where `n`
is that cell's own event count from `build_flow_matrix()`'s `coverage`
table. **Scoped deliberately to conditional cells only** — the pooled
fallback path keeps `max(smooth, fallback_smooth)` exactly as before. That
path is a different, already-flagged-dangerous question (a pooled rate is
not a measurement of the contest in front of it at all — the file's own
docstring), and touching it isn't part of what was asked or what the three
worked examples motivate.

Forces `engine = "r"` whenever `shrink_k > 0` (refuses `engine = "cpp"`
explicitly rather than silently ignoring the parameter) — the compiled core
has no per-cell shrinkage logic.

Wired as a new env-gated arm, `AUSPOL_FLOW_SHRINK_K` (default `"0"`), into
all six `backtest_candidate_*.R` harnesses and `fit_seats_full.R`, alongside
the existing `FB_SMOOTH`/`AUSPOL_FALLBACK_SMOOTH` pattern. **No change to
`published_flags.R`** — this stays an unshipped, opt-in arm for measurement.

## Grid

`k ∈ {3, 5, 10, 20, 40, 80}` — reusing the exact grid already used for
point-estimate shrinkage in `docs/NEXT-STEPS.md`'s "Diagnosed 2026-09-08"
section, for comparability of convention rather than inventing a new one.
Spans from barely-shrinks-anything (`k=3`: a 672-event cell gets
`sm=0.0044`, a 10-event cell gets `sm=0.769`) to shrinks-even-well-measured-
cells (`k=80`: the 672-event cell still gets `sm=0.106`, closer to but
under the old flat 0.15).

## Primary metric and why

**Pooled seat log loss, seat-weighted, across all 22 pairs** — this repo's
own stated objective (`docs/NEXT-STEPS.md`, "THE OBJECTIVE, set by Pete
2026-09-06"). Secondary: Brier, seat-share RMSE, per this repo's own metric
ordering (log loss decisive, Brier and calibration slope reported but not
decisive on their own).

**This is scoped as a GENERAL change, not a targeted one** — per
`CLAUDE.md`'s targeted-vs-general framework. It touches every conditional
flow cell across every election, not a named set of seats, so the
election-wide pooled figure is the PRIMARY metric here (not a guard). The
three worked examples (Ballarat/Kiama/MacKillop) are diagnostic, not
targets to validate against directly — see the dry-run section below for
why (the fix by design does nothing to two of the three).

## Refusal conditions, named in advance

1. **The winning `k`'s pooled improvement must exceed the single-seed noise
   floor.** This repo's own measured figure: seed alone moves one pair
   ~0.011 at 5,000 sims. A pooled 22-pair improvement under roughly
   **0.005** (conservative — pairs are not independent draws, so this is
   not a clean `1/sqrt(22)` reduction of the per-pair figure) will be
   treated as UNRESOLVED, not adopted, pending a reseed of the winning `k`
   at higher sims before any decision.
2. **No single jurisdiction group may regress by more than 0.02 pooled log
   loss** at the winning `k`, matching the floor this repo already used for
   the defector-discount arm (SA +0.0137 was inside that floor and treated
   as acceptable). A jurisdiction breaching this, even with a pooled win, is
   a refusal — the same shape as the arm-H variance-widening refusal
   (`docs/reviews/arm-h-variance-widening-2026-09-08.md`), where 4 of 5 named
   cells got worse under a pooled win.
3. **Brier and log loss must agree in direction on the pooled figure.** If
   they disagree, the reliability-by-band table (tail-focused: 0.9, 0.95,
   0.99, 0.999) gets checked before any adoption decision — per this
   repo's metric-ordering rule, disagreement is a flag to look closer, not
   grounds to pick whichever number is more favourable.
4. **Check for a floor-crossing artefact** — per the arm-H and reentry-prior
   lessons, a pooled win driven by one seat crossing the `eps = 1e-6` log
   loss floor is not a real win. Any k whose improvement is concentrated in
   fewer than 3 seats gets this checked explicitly before being reported as
   a genuine effect.

**What this criterion cannot see, stated in advance**: whether an xgb flows
model (future, separate work) would do better than any fixed `k` — this is
a standalone measurement against the CURRENT shipped mechanism only, not a
comparison to unbuilt work. It also cannot see genuinely novel survivor-set
combinations Victoria 2026 itself might produce that don't appear in any of
the 22 backtest pairs.

## Dry run on the three named examples, BEFORE the grid

Per this repo's own rule ("prove a check fails on a deliberately broken
input" / "dry-run every criterion on cases whose answer you already know").
Computed directly from each harness's own default flow-matrix construction
(leave-one-out for federal; single-prior-election for NSW/SA, matching
`backtest_candidate_nsw.R`/`backtest_candidate_sa.R` exactly):

| example | cell | n (events) | conditional used? | shrink_k=20 effect |
|---|---|--:|---|---|
| Ballarat, fed2007 | `GRN\|ALP+LNP` | **672** | yes | `sm` 0.15 → **0.029** — barely smoothed, as intended |
| Kiama, nsw2023 | `LNP\|ALP+IND` | 2 | **no** (below `min_n=3`) | **zero effect** — falls to pooled `LNP` row, untouched by this parameter's scope |
| MacKillop, sa2026 | `ALP\|LNP+ONP` | 1 | **no** | **zero effect** — same reason, falls to pooled `ALP` row |

**This is the important dry-run finding, not a failure of the criterion**:
the fix is correctly scoped to do nothing on the two flagship rare/thin
cases — it isn't meant to fix Kiama or MacKillop, and doesn't touch them.
Its entire effect on the pooled metric will come from cells shaped like
Ballarat's — common, well-measured, currently over-smoothed. If the grid
result below shows a large pooled change, that confirms Ballarat-shaped
cells are numerous enough to matter in aggregate; if the pooled change is
small, that's equally informative (most cells may sit closer to `min_n`
than Ballarat's 672).

## Sequencing

Grid run at `AUSPOL_N_SIMS=2000` (below this repo's usual 5,000-sim
exploratory default, given `shrink_k > 0` forces the slower R reference
engine — measured: ~208 seconds for all 7 federal pairs at 2,000 sims,
`k=20`). This is explicitly MORE exploratory than the usual convention, not
a deciding run — if a `k` clears both refusal conditions 1 and 2 at this
sim count, it gets reseeded at 5,000 sims (this repo's normal exploratory
level) before being reported as anything more than a promising candidate.

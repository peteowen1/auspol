# XGBoost flows + primary — variable inventory and design examples

Prep material for a design conversation, per `C:\dev\CLAUDE.md`'s "design WITH
Pete on real examples before writing the rule." **Nothing fitted, nothing
changed in any model file.** Companion to the census-feasibility fork running
the same session.

## Part 1: variable inventory — used vs. available

### `output/candidacies.csv` (candidate-level corpus)

| column | used by | note |
|---|---|---|
| election, region, year, seat, party, state | xgb primary, flow matrix, everything | keys |
| name, surname, given | `candidate_returns()` (identity match) | not a direct feature anywhere |
| party_raw, party_ab | none | raw commission label before `classify_party()` — could let a model see minor-party identity finer than the 7-class bucket (e.g. distinguish Katter's from Shooters within `OTH_RIGHT`) |
| votes, pcv | xgb primary (`x`, `pred_share` etc. derive from this) | |
| elected, historic_elected | `candidate_returns()`, sitting-member logic | `historic_elected` (won a PRIOR cycle, not just last one) is unused everywhere — could feed a "career incumbent" feature distinct from `same_mp` |
| breakout | salience corpus join key | not an xgb feature directly |
| swing | none | this seat-party's OWN swing from the corpus is not fed to xgb primary at all — only `dev_prev`/`level_now` (statewide) are; a raw local `swing` history is sitting unused |
| ballot_position | none | ballot-position (donkey vote) effects are a known real thing in AU elections and this column exists and is unused everywhere in the repo |
| ordinary, absent, provisional, prepoll, postal | none | vote-type breakdown, e.g. postal-heavy seats behave differently under late counting; unused by anything modeling-side |
| ballot_order | none | mostly NA per earlier read — check population before using |
| tot | derives `pcv` | |

### Salience corpus (multiple derived files, not one)

| file | columns | used by |
|---|---|---|
| `output/salience-v6.csv` (rawest) | keyword, election, seat, party, pcv, elected, prev_party, jump | `governed_population()`, `salience_screen()` |
| `output/salience-corpus.csv` | + breakout, sitting | descriptive scoping only (`scope_census_feasibility.R`-style scripts) |
| `output/salience-hazard.csv` | + who, won, surge_h | `surge_hazard_for()` |
| `output/salience-ratios.csv` | + hits, anchor_hits, ratio | anchor-relative salience (Albanese-normalized cross-election comparability) |
| `output/salience-surge-v2-population.csv` | + jump_pctile, prev_ind, governed, permit, is_recipient (added downstream in `fit_xgb_primary_v3/v4.R`) | v3/v4 xgb experiments only — **not in the shipped v1/final candidate** |

`jump`/`jump_pctile`/`governed`/`permit`/`surge_h`/`is_recipient` are all
available and already computed, just not wired into the FINAL xgb primary
model (`fit_xgb_primary_final.R`) — only into the v3/v4 experimental variants,
which this session found make the rare-emergence problem worse, not better,
when used as a hard flag. As continuous features (not a 0/1 gate) they're
untested.

### Preference-transfer raw files (feed `build_flow_matrix()`)

| file (jurisdiction) | columns | note |
|---|---|---|
| `aec-fed-transfers.csv` (federal) | election, seat, round, from, to, votes | **no `to_n`** |
| `nswec-nsw-transfers.csv` | election, seat, round, from, to, votes | **no `to_n`** |
| `ecq-qld-transfers.csv`, `ecsa-2026-sa-transfers.csv`, `vec-*-vic-transfers.csv` | + `to_n` (surviving-candidate count per class) | multiplicity-aware |
| `waec-wa-transfers.csv` | + `three_cornered` (flag, WA-specific) | no `to_n` equivalent |

**This is a real, currently-unfixed cross-jurisdiction inconsistency**: an
xgb flows model wanting "how many candidates of the surviving class" as a
feature has it for QLD/SA/VIC and not for federal/NSW/WA. Same shape as this
repo's recurring "fixed in one harness, not ported" failure, just in the raw
data layer instead of code.

**South Australia's flows are borrowed wholesale, not native.** `ecsa-2026-sa-transfers.csv`
covers ONLY sa2026 — there is no earlier SA transfer file. `backtest_candidate_sa.R`
confirms: its flow base is `aec-fed-transfers.csv`, with SA's own historical
transfers optionally pooled in via `pool_configured_flows()`/`AUSPOL_SA_FLOWS`.
**When backtesting sa2026 itself (the flagship ONP case this whole session has
been about), there is no other in-jurisdiction transfer history to train an
SA-specific flow rate from at all** — any rate, xgb or the current lookup, is
necessarily borrowed cross-jurisdiction for that pair. A `region` feature on
an xgb flows model would need to represent this honestly (e.g. SA rows share
federal's learned pattern rather than getting their own), not silently invent
SA-specific signal that was never observed.

### `R/candidate_returns.R` outputs

| function | fields | used by |
|---|---|---|
| `candidate_returns()` | seat, party, same, same_mp | xgb primary (`same_i`, `same_mp_i`) |
| (internal) `prior_leader_returns`, `leader_same` | seat, party, hit | consumed internally, not exposed as a standalone xgb feature |
| `personal_prior_vote()` | seat, party, own_prev_pcv, prev_party, transfer | **not fed to xgb primary at all** — `own_prev_pcv` (the identity-matched candidate's own prior share, as opposed to the seat/class-level `x`) is a materially different, more specific signal than what xgb currently sees |
| `fit_defector_discount()` | discount, discount_mp, discount_loser | shipped as `AUSPOL_DEFECT_POOLED` constants in the simulator, not as an xgb feature |

### Seat metadata (`R/seats.R`, `load_seats()`) — biggest concrete gap found

| field | used by | note |
|---|---|---|
| incumbent, challenger, seat_region | seat-swing regression (`seat_swing_spread()`) | not xgb |
| **fed_swing, retirement, soph_cand, soph_party, margin, prev_swing** | seat-swing regression ONLY | **These five cut seat-swing out-of-sample MAE from 3.948 to 3.425 when added (2026-08-19, `docs/plans/prereg-seat-swing-predictors.md`) — a proven, measured win in a sibling model — and none of them reach `fit_xgb_primary_final.R` at all.** `margin` in particular (the seat's own TPP lean) looks like an obvious primary-share feature that's simply never been tried. |
| classic (both-majors flag) | seat-swing regression | maps loosely to `is_major` in xgb but isn't the same computation |

### Party classification

`classify_party()` (`R/parties.R`) is the single source of the 7-class
system (ALP/LNP/GRN/OTH_RIGHT/IND/ONP/OTH). No sub-class signal (e.g. "which
`OTH_RIGHT` party is this really") reaches any model — `party_raw` above is
the only place that finer identity survives, and it's unused.

## Part 2: two real flow examples

### Example A — messy, multi-round, minor-party emergence: Kiama, nsw2023

Gareth Ward, sitting LNP member, stood as an independent after expulsion.
Actual transfer rounds (`nswec-nsw-transfers.csv`):

| round | from | survivors receiving | votes |
|---|---|---|---|
| 1 | OTH | GRN 298, LNP 219, IND 242, ALP 195 | |
| 2 | GRN | LNP 370, IND 612, ALP 3258 | |
| 3 (final) | LNP | **IND 1848**, ALP 866 | |

Final two-candidate count: IND 68.1%, ALP 31.9% of the LNP-exclusion pot.
`build_flow_matrix()`'s key for the deciding round is `"LNP|ALP+IND"`. This
key is rare by construction — IND only reaches the final round when a major
party's own sitting member defects — so this cell almost certainly falls to
`pooled[["LNP"]]` (renormalised over ALP/IND) rather than a conditional rate,
and the pooled LNP row was fitted on ordinary LNP exclusions (LNP rarely
finishes third), which is exactly the mismatch this repo's own docs
(`reviews/reentry-prior-nsw-qld-2026-09-08.md`) already name as the Kiama
miss. An xgb flows model's FEATURE set would need something that flags "the
excluded party's own former member is one of the survivors" (available today
via `candidate_returns()`'s `same_mp`) to have any chance at this cell — the
plain party-class-and-survivor-set key that `build_flow_matrix()` uses has no
way to represent that at all.

### Example B — messy, many-round, surging minor party: MacKillop, sa2026

One Nation's SA2026 win, full first-to-last count
(`ecsa-2026-sa-transfers.csv`):

First preferences: ONP 35.08%, LNP 23.75% (Liberal) + 3.29% (National) =
27.04% combined, ALP 15.35%, IND 14.79%+0.70%, GRN 3.46%, OTH 2.15%,
OTH_RIGHT 1.43%.

| round | from | survivors receiving (votes) |
|---|---|---|
| 1 | IND (152 votes) | ONP 23, IND 44, GRN 14, OTH_RIGHT 26, LNP 41 (to_n=2), OTH 18, ALP 14 |
| 2 | OTH_RIGHT | ONP 90, IND 38, GRN 60, LNP 123 (to_n=2), OTH 32, ALP 33 |
| 3 | OTH | ONP 130, IND 59, GRN 156, LNP 122 (to_n=2), ALP 111 |
| 4 | LNP (National, to_n=2→1 merge) | ONP 251, IND 136, GRN 67, LNP 420, ALP 67 |
| 5 | GRN | ONP 132, IND 234, LNP 188, ALP 605 |
| 6 | IND | ONP 1636, LNP 1588, ALP 685 |
| 7 (final) | ALP | **ONP 1454, LNP 3776** |

ONP wins despite LNP receiving more than double ONP's share of the final
ALP-exclusion pot (3776 vs 1454) — the seat was decided by ONP's first-
preference lead surviving seven rounds of attrition, not by favourable
late flows. **This is the opposite lesson from Kiama**: here the primary-vote
model (which already knows ONP's first-preference strength) matters far
more than the flow model does. If an xgb flows model is built and doesn't
clearly help on cases shaped like this, that's not a flows-model failure —
the primary share was already carrying the signal.

The deciding key here (`"ALP|LNP+ONP"`) is a genuinely novel survivor pair —
ALP excluded with ONP and LNP contesting the final two barely exists
elsewhere in the corpus, and as noted above, **South Australia has zero
other elections' worth of its own transfer data** to build a conditional
rate from; whatever rate the current model or an xgb replacement uses here
is necessarily generalised in from federal/other-state exclusions structured
similarly.

## Part 3: what `distribute_preferences()` actually needs

Traced `R/preferences.R:42`. Per exclusion round, it needs a **full
distribution over the surviving parties** (`conditional[[key]]`, a named
numeric vector, renormalised on use), not a point prediction — and it always
blends that distribution with a **fixed 15% uniform smoothing weight**
(`smooth = 0.15`), regardless of whether the underlying rate came from a
conditional cell with hundreds of events or a thin pooled fallback. There is
no confidence/data-richness signal feeding that blend today.

**This shapes what an xgb flows model can realistically be:**

- **It cannot output one number per exclusion event** — the target is a
  distribution over a variable-length, variable-composition survivor set
  (2 to 6+ classes depending on the round). The natural mirror of how xgb
  primary already works is **one row per (excluded party, destination party,
  survivor-set) cell**, predicting that destination's share, then
  renormalising across the row's own survivor set at inference — structurally
  identical to how `fit_xgb_primary_final.R` predicts one row per
  (seat, party) and the caller renormalises the full row to sum to 100.
- **A genuine improvement opportunity, not currently exploited by anything**:
  since `distribute_preferences()`'s smoothing weight is fixed regardless of
  data volume, an xgb model that also predicts (or is given, e.g. via
  `to_n`/event counts) a confidence signal could let smoothing vary by cell
  richness instead of applying a flat 15% everywhere — replacing a global
  constant with something that already knows which cells are thin. This
  matches this repo's own "shrinkage over hard cliffs" preference elsewhere
  (`prefer-shrinkage-over-thresholds` is standing guidance).
  Worth discussing as a design goal, not assumed as free — it changes
  `distribute_preferences()`'s contract, not just what feeds it.
- **Multiplicity (`to_n`) is inconsistently available** (see Part 1) — an
  xgb flows model trained across jurisdictions either drops this feature
  entirely (losing the documented 44.5%-of-Victorian-rounds effect this
  repo already measured for survivor multiplicity) or is trained per-
  jurisdiction-group, which cuts training data for the thin jurisdictions
  (SA, WA) exactly where it's needed most.

## Summary for the design conversation

1. **Primary-side low-hanging fruit, not yet tried**: `margin` (seat's own
   TPP lean), `own_prev_pcv` (identity-matched candidate's own prior share,
   distinct from seat-level `x`), `swing` (this seat-party's own historical
   swing), `retirement`/`soph_cand`/`soph_party`/`fed_swing`/`prev_swing` —
   all already proven or plausible, all currently absent from xgb primary.
2. **Demographics**: separate fork's territory (coverage), but note it
   would join on `seat`+`election` same as everything else here once
   available.
3. **Flows is a bigger build than primary was**: new target shape (row-per-
   destination-in-survivor-set, not row-per-party), a real cross-
   jurisdiction data gap for South Australia specifically (the flagship
   case), and an inconsistent `to_n` feature across sources that needs a
   decision (drop it, or accept per-jurisdiction training splits).
4. **Two examples above cut opposite ways** — Kiama needed the flow model to
   know about a defecting sitting member; MacKillop shows a case where the
   primary model's own signal already dominates and flows barely matter.
   Worth picking a THIRD example together that's a clean two-candidate-
   preferred case (neither of these two is one) before settling the target
   variable definition.

## Part 4 (added, same session): the clean 2CP example, and a final recommendation

### Example C — clean, single-round, ordinary: Ballarat, fed2007

Picked because it is NOT named anywhere else in this repo's history — an
unremarkable, safe-Labor seat with a sitting member re-elected, no defector,
no emergence story.

First preferences: ALP 50.33% (elected), LNP 38.04%, GRN 7.98%,
OTH_RIGHT (Family First) 3.65%. Only one transfer round is recorded
(`aec-fed-transfers.csv`) — Family First's exclusion isn't logged as a
separate row in this source (the AEC's published count-back for this seat
evidently didn't require one to determine the result), so the file shows only
the deciding step:

| round | from | to | votes |
|---|---|---|---|
| 1 (only recorded) | GRN | LNP | 1,624 |
| 1 (only recorded) | GRN | ALP | 5,969 |

Observed split of the Greens-exclusion pot: **LNP 21.4% / ALP 78.6%.**

`build_flow_matrix()` on the full corpus **leave-one-out (fed2007 excluded)**
for key `"GRN|ALP+LNP"`:

| | LNP | ALP | events (n) | votes behind it |
|---|--:|--:|--:|--:|
| conditional rate | 21.3% | 78.7% | **672** | 8,401,918 |

**The existing lookup already nails this cell almost exactly** (21.3/78.7
predicted vs 21.4/78.6 observed) — because it is the single most common
exclusion shape in the entire federal corpus (672 events), not a rare or
borrowed one. This is the polar opposite of Kiama/MacKillop: no defector
signal needed, no cross-jurisdiction borrowing, nothing for a smarter model
to add on the RATE itself.

### Recommendation: row-per-cell shape, adopt it — the clean case is why, not just Kiama/MacKillop

**Yes, build the xgb flows model as one row per (excluded party × destination
party × survivor-set) cell**, mirroring `fit_xgb_primary_final.R`'s own
shape, renormalised across the row's own survivor set at inference. Ballarat
is what makes this concrete rather than provisional: it shows that most real
cells look like this one — well-populated, already well-served by the
existing pooled/conditional lookup, with close to zero headroom on the rate
itself. That has a direct design consequence carried over from THIS
session's primary-model work: `fit_xgb_primary_v4.R`'s 8x row-weighting
attempt on "rare" rows made the pooled aggregate worse precisely because the
"rare" flag fired on 28% of rows instead of a genuinely rare slice, drowning
the signal in cells that didn't need help. **The same failure will recur here
if training treats all cells equally** — thousands of Ballarat-shaped cells
(already solved) will dominate the loss and dilute whatever the model could
learn about Kiama/MacKillop-shaped ones (genuinely thin or borrowed). Design
the weighting/sampling scheme around `n` (`build_flow_matrix()`'s own event
count) from the start — e.g. downweight or exclude cells above some `n`
threshold from training loss entirely, since the lookup table already has
those — rather than discovering this the same way v4 did, one refused
experiment later.

### Restating the fixed-15%-smoothing finding, now with all three examples: this is the higher-priority, lower-risk first move

Ballarat changes this from "worth discussing" to a **concrete, quantified
cost, happening right now, on ordinary cells, at scale**. `distribute_
preferences()`'s `smooth = 0.15` blends 85% of the conditional rate with 15%
uniform-over-survivors — for a 2-survivor cell that is 50/50. Applied to
Ballarat's 672-event, near-certain 78.7/21.3 rate:

```
0.85 * 78.7 + 0.15 * 50.0 = 74.4%  (actual smoothed prediction)
vs 78.7% the data actually supports  -- a 4.3-point error, on purpose,
on one of the best-measured cells in the whole corpus.
```

That 4.3-point compression happens on **every** GRN-exclusion-to-two-majors
cell across every election in the corpus — thousands of them — not as an
edge case but as standing behaviour, because the smoothing weight carries no
information about `n`. Meanwhile the SAME flat 0.15 is applied to Kiama's
`"LNP|ALP+IND"` cell, almost certainly resting on a handful of pooled events
or fewer, where 15% uniform is arguably not protective ENOUGH given how
thin and mismatched the underlying rate is.

**This is a single-parameter, no-new-model fix, and it should happen before
any xgb flows work, not after**: replace the flat `smooth = 0.15` with a
partial-pooling weight keyed on the cell's own event count — `w = n/(n+k)`,
same shrinkage form this repo already uses elsewhere (`prefer-shrinkage-
over-thresholds` is standing guidance) — so a 672-event cell like Ballarat's
gets smoothed almost not at all, and a genuinely thin or borrowed cell
(Kiama's, MacKillop's, anything cross-jurisdiction-pooled for South
Australia) keeps meaningful protection. It requires no xgb model, touches
one function (`R/preferences.R:42`), and the size of the win it would recover
is now directly measurable (672 events' worth of 4.3-point error, repeated
across every similarly-common cell) rather than theoretical. Recommend
sequencing it as the FIRST move, with the xgb flows model (row-per-cell,
`n`-aware weighting per above) as the follow-on that targets what shrinkage
alone can't fix — genuinely under-informed cells like Kiama's, not
well-measured ones like Ballarat's.

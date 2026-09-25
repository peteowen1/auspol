# CLAUDE.md incident detail

Moved out of `CLAUDE.md` on 2026-09-25 to keep it under the per-turn size budget. The rules stay in `CLAUDE.md`; this file holds the incidents and numbers behind them, verbatim as they stood. Line numbers and identifiers were accurate when written and may since have moved.

## Negative results and "ask what the system already has" (2026-09-11)

Four times on 2026-09-11 alone, in one session, all the same shape: a negative
finding reported from the cheapest version that was to hand.

| what was reported | what was actually built | what the full version did |
|---|---|---|
| "xgb flows point to refuse" | statewide averages fed to a model whose features are per-seat | 2 wins, 2 ties, 0 regressions |
| flow model's personal-vote features useless | `dest_same`/`dest_same_mp` hardcoded to 0 at inference, trained on real values | 22.8% of rows populated |
| "201 rows will overfit, use class averages" | never fitted | dead heat with the average — the objection cost a round and decided nothing |
| **"we cannot predict who surges"** | **7 of the 25 features the primary model already had** | **AUC 0.751 → 0.936; one class went from 0.201 (inverted) to 0.862** |

Pete had to ask four separate times. The last one — "did we test xgboost with a
tonne of variables for this?" — overturned a conclusion that had already been
written into a pre-registration and two commits.

**The asymmetry is the whole argument.** Building the full version costs
minutes. A wrong negative gets written into a plan, reasoned from, and closes a
line of work. There is no symmetric cost that justifies the shortcut.

### The same root, one level up: ASK WHAT THE SYSTEM ALREADY HAS

Both failures above are the same move — reasoning from the file in front of me
instead of the system I already know about. Later the same day, again:

`fit_xgb_primary_v6.R` computes `level_now` as `state_level(pr$election)`, the
party's ACTUAL statewide share at the election being predicted. Reading that
one function, the conclusion was "this is the harness's design, deliberate".

**The pipeline already predicts exactly that quantity.** `fit_seats_full.R:409`,
`state_mean` — poll trend plus fundamentals, every party's statewide primary.
It is stage one of the model. It was written into `ARCHITECTURE.md`'s own
pipeline walkthrough, Part A step 4, *by me, that morning*.

Pete had to point it out: *"why do i have to catch this for you - surely you
should know this? im confused why you dont know 'we model each parties
primary'"*.

(2026-09-25 note: the variable in `fit_xgb_primary_v6.R` is `ln`, not `level_now`, and `AUSPOL_LEVEL_MODE`, default `"pred"`, now controls where the level comes from. `state_mean` is at `fit_seats_full.R:522`.)

## The data.table NSE cases

- **data.table NSE**: a function argument or local variable sharing a name with
  a column, used bare inside `dt[...]`, binds to the column. **Eight times.** The
  seventh (2026-08-28): a local scalar `tot` shadowed by `candidacies.csv`'s
  own `tot` column inside `C[...]`, 1122 rows from a groupby that should have
  given 7. The eighth (2026-09-06, found by the review gate): `party_swing()`
  wrote `C[C$region == region & ...]`, so every jurisdiction was pooled and
  the "no rows for" guard could never fire; caught only by a test asking for
  a region that does not exist. The
  sixth: `salience_permit_for(election, ...)` wrote `raw[raw$election ==
  election]` -- `raw$election` on the left made no difference, because
  data.table scopes `raw`'s columns into the WHOLE `i` expression, so the bare
  `election` on the right resolved to the column and the filter became
  `raw$election == raw$election`, always TRUE. It would have silently merged
  every election's rows on the first real call. Caught only because a test
  queried a label that cannot exist ("nope") and got data back anyway. Fix:
  never a bare column-name symbol inside `[`, even qualified with `$` on one
  side only -- copy the argument to a differently-named local first.
  Compute masks outside the brackets and name the variable differently. The
  fourth was `party[party$seat == seat, ]` where `party` was both the table and
  a column — `$` then fails on an atomic vector. Related: a column named `key`
  collides with `data.table()`'s own `key=` argument and errors naming your
  data.

## Constant-within-subgroup columns (2026-09-12)

- **A COLUMN THAT IS CONSTANT WITHIN A SUBGROUP IS A LABEL FOR THAT SUBGROUP,
  and a tree will use it as one.** xgboost cannot tell "this is 0 because the
  concept does not apply here" from "this is 0 because the value is zero". On
  2026-09-12 four state-deviation features were added for federal pairs only;
  the other 6,100 cells got `state_poll_dev = 0`, `state_elec_gap = 999` and so
  on as fillers. A split like `state_elec_gap > 500` then separates every
  non-federal row cleanly, so the tree spent splits partitioning on jurisdiction
  and reshaped the whole fit around it. **96% of non-federal predictions moved,
  by up to 5.87 points, from columns that say nothing about them** -- South
  Australia, the smallest region at 329 cells, moved most. Pooled RMSE 3.8740 ->
  3.9297 even though the feature gained 0.060 on fed2022, the pair it was built
  for. If a feature only exists for part of the corpus, either fit that part
  separately or do not add it -- a filler value is not neutral. Same root as the
  percentile trap below: both are cases where a placeholder became a signal.

## Percentile of a mostly-tied variable (2026-09-12)

- **A PERCENTILE of a mostly-tied variable reports "is this the mode?", not
  "how big is this?"** `jump_pctile` ranked campaign salience within each
  election, and `jump` is **51-81% exactly zero** — 447 of fed2007's 552
  governed candidates, 62 distinct values in the whole field. The tie-averaged
  zero block took percentile 0.55, so **any** non-zero value started above the
  81st percentile: a raw `jump` of 0.0220, which is noise, scored 0.9846. Two
  unrelated 2007 candidates in different states had identical percentiles to
  four decimals, both polled under 3%, and both sat in the top salience bin
  next to the teals. Inside that bin salience correlated with outcome at
  **−0.096**. Nothing downstream revealed it: the column was populated, the
  model trained, the metrics looked plausible, and it surfaced only when Pete
  asked why a specific candidate scored high. Fixed by ranking within the
  non-zero set (`docs/reviews/salience-percentile-fix-2026-09-12.md`); the
  strike rate of independents above the 90th percentile went 19% to 57% on the
  same data. **Before percentile-ranking anything, print three numbers: percent
  exactly zero, count of distinct values, and the size of the largest tied
  block.** Ported to `R/salience_surge.R:92` in `b7b5839` (2026-09-12) — the
  percentile is now ranked among non-zero values only, gated behind
  `AUSPOL_SALIENCE_PCTILE_NZ`.

## Shrinkage: the South Australia and defector cases (2026-09-09)

It also stops a false binary between a well-measured single observation and a
noisy pooled fit. Choosing between South Australia's One Nation concentration
(0.346, from a full 47-seat chamber) and the corpus-typical value (0.474, R2
0.063) put the Victorian forecast 5 seats apart; pooling them by precision
gave 0.365 and a one-seat difference — and corrected a claim that was heading
the wrong way. See
[reviews/onp-concentration-validated-2026-09-09.md](docs/reviews/onp-concentration-validated-2026-09-09.md).

**And the limit that bit on the first application, 2026-09-09: when the
BETWEEN-group variance is itself barely estimable, shrinkage will
UNDER-separate groups that genuinely differ.** Losing major-party defectors
(median retention 0.142, n=12) and sitting members (0.282, n=17) are not
separable by rank test — Wilcoxon p = 0.408 — so pooling put weight 0.12 on
the losers and dragged them to 0.241. The seat-level outcome then said that
was too high: at 0.270 the collapsing losers are visibly over-predicted, and
South Australia breached the arm's own catastrophic floor because several
coincide there. Both facts hold. p = 0.408 at n=12 is **absence of evidence,
not evidence of absence**, and the shrinkage weight inherited that low power.
Partial pooling behaved correctly given inputs too thin to tell it the groups
differ.

**So the corrective for a suspicious shrinkage result is an OUTCOME check —
does the shrunk value predict better on the target cells? — not a bigger
significance test.** See `docs/plans/prereg-defector-pooling-2026-09-09.md`,
where the mechanism was confirmed (target cells improved 1.45 RMSE) and the
magnitude refused in the same run.

## Harness pair details

`_wa.R` was added 2026-08-25 and carries seven pairs at ~58 seats. **`_fed.R` is
now the larger harness** — 7 pairs over 1,036 seat-elections against WA's 361 —
so prefer federal first and WA second when a criterion needs to resolve
anything. (Corrected 2026-08-27; the earlier claim that WA held more clusters
than the other four combined predates the federal harness reaching 6 pairs.)

`_nsw.R` takes **two** pairs since 2026-09-07 via `AUSPOL_NSW_PAIR` (2019 or
2023, default 2023) — it was hardcoded to one target in seventeen places. So a
change measured "on NSW" means whichever pair you set, and both need running.
`_vic.R` takes **three** since the same day (vic2010 was recovered from the
Internet Archive) and runs them all in one go. `_qld.R` takes **two** via
`AUSPOL_QLD_PAIR` (2020 or 2024, default 2024), and the two do NOT share a flow
source: 2024 uses Queensland's own qld2020 distribution, while 2020 uses FEDERAL
2019 flows because the 2017 package carries no distribution and qld2020's own
would be the election being predicted. Federal is admissible there only because
both are compulsory preferential — the test NSW fails.


**Two WA-specific facts that change how its numbers read.** The `wa2001` pair
has no transfers of its own (excluded upstream) so its flows fall back to
pooled; and WA redistributes hard, so seat names do not survive between
elections — 2005→2008 scores only 67% of the chamber. Both are printed per pair
and coverage is written into the output, because a pair scored on two thirds of
its seats is not comparable with one scored on all of them.

This has now gone wrong twice on the same parameter:

- **2026-08-21**: `shrink` was wired into the federal, Victorian and NSW
  harnesses and **missed in South Australia**. For four days every SA
  calibration figure described a model we do not publish — slope 0.299 against
  a published 0.980 — and a full day was spent investigating four seats at
  0.000 probability that were partly an artefact of the missing parameter.
- **2026-08-25**: the flow fixes, the IND-nomination fix and stronghold
  elasticity all went into the SA harness first and **were not in Victoria or
  NSW**, so the pre-registered criteria could not be evaluated until they were
  ported.

The cost is not just the rework. **A harness missing a parameter produces
numbers that look like findings**, and they get investigated, written up and
reasoned from — which is exactly what happened to the four SA seats.

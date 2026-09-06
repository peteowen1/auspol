# Audit: does the data.table self-comparison bug reach the model? No.

2026-08-25. Run after I hit the bug in a scratch diagnostic and Pete asked how
he could know it had not affected the modelling. Reassurance is not an answer,
so this is the search and its limits.

## The bug

`dt[seat == seat]` — a bare column name on **both** sides of a data.table
filter — is a self-join that always matches, returning every row rather than
the intended subset. It does not error. `CLAUDE.md` records it as having hit
this repo **five times**.

Mine was `b[seat == get("seat")]` in a scratchpad script reconstructing SA's
count. It produced a Coalition final-three share of 5.3% off a 26.9% primary,
which is arithmetically impossible — preferences only ever add — and Pete
caught it from the output.

## What was searched

`R/*.R` and `scripts/*.R`, for:

1. literal `[col == col]` with matching identifiers on both sides
2. `get("col")` used inside a filter
3. package **function arguments** sharing a name with a column of the table
   they filter — the form `CLAUDE.md` actually records
4. every script committed in this session

## Findings

| check | result |
|---|---|
| literal `[col == col]` in `R/` or `scripts/` | **none** |
| `get("col")` self-reference in any committed script | **none** |
| `R/seat_sim.R` data.table filters | **zero** — matrix arithmetic throughout |
| `scripts/fit_seats_full.R` filters (6) | all string literals or explicit `$` |
| the 14 scripts committed today | clean |

### The one case that looks like the bug and is not

`scripts/backtest_candidate_nsw.R:239`

```r
p_actual <- sc[party == actual, .(seat, p = prob)]
```

`sc` is a merge of `data.table(seat, actual)` with `win_prob(seat, party, prob)`,
so **`party` and `actual` are both real columns** and comparing them is exactly
the intent: select the row for the party that actually won. Correct as written.

### The functions most at risk are explicitly defended

`flows_for(flows, year, region, ...)` takes arguments named `year` and `region`
against a table carrying columns of those names — the precise collision. It
carries its own comment:

```r
# `flows[flows$region == region & flows$year <= year, ]` becomes
# `region == region` — always TRUE — and silently returns every row for
keep <- flows$region == region & flows$year <= year
avail <- flows[which(keep), ]
```

Explicit `$` on the left, mask computed **outside** the brackets. That is the
`CLAUDE.md` rule applied. `cycle_polls()` goes further and renames its argument
to `reg`.

## What this means for today's numbers

The SA backtest path — `simulate_seat_contests()` and the shares construction —
is matrix and named-vector arithmetic with **no data.table filtering**. The
calibration improvement measured today (slope 0.299 → 0.990) is not exposed to
this class of bug.

## Limits of this audit, stated plainly

- **Static grep for one pattern.** It would not catch a filter built
  dynamically, or a column name reaching a filter through a variable.
- **Only `R/` and `scripts/`.** Tests were not scanned.
- **Only the self-comparison hazard**, not every data.table NSE trap — the
  shadowing variant (`dt[, cols]` with `cols` a character vector, a `key`
  column colliding with `key=`) is a different failure and was not searched.

## Why the codebase is clean

Not by luck. This trap has hit five times and each time a defence was written —
`$`-qualified comparisons, masks computed outside brackets, arguments renamed
away from column names, and comments naming the hazard at the site. The
discipline held; the failure today was in a throwaway script that bypassed it.

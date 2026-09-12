# sa2022 was scored but never modelled, and a name-parsing bug was why

2026-09-12. Found while checking which pairs the SD model covered. The pair
with the **worst log loss in the corpus** was not in the model at all, and the
reason was four layers down.

## What was wrong

`sa2022` is scored by `backtest_candidate_sa.R` (47 seats, via
`AUSPOL_SA_PAIR=2022`) and was absent from:

1. **the xgb primary feature corpus** — `fit_xgb_primary_v6.R` and `_v7.R`
   listed it only as sa2026's `prev`, never as a target election
2. **the SD model** — no rows in `output/xgb-primary-sd-oof.csv`
3. **`output/level-pred.csv`** — no predicted statewide level for any class
4. **`output/mp-slope-by-target.csv`** — and this one was fatal: the harness
   died outright with
   `Error: no leave-one-out MP slopes for sa2022`
5. **the party-correlation fit** — its own log said
   *"all 15 pairs (sa2022 is not in the fit, so nothing to hold out)"*

So its 0.9409 seat log loss — against a 0.3207 pooled average, carrying 2 of
the corpus's 4 seats where the actual winner was given <= 1e-4 — was a
measurement of our FALLBACK PATHS sitting in the headline figure as though it
measured the model. The pooled 2,097 seat-elections and the model corpus's
2,050 differed by exactly these 47 seats, and nobody had asked why.

## The root cause: every sa2018 surname was read as a first name

`scripts/build_candidacies.R:232` set sa2018's `surname` and `given` to
`NA_character_` outright, pushing every consumer onto the combined `name`
field.

sa2018 is the **only election in the corpus stored in natural "Given Surname"
order**, because it comes from Wikipedia's "Election box" tables rather than a
commission extract — the Electoral Commission of South Australia never served a
2018 results file.

`surname_of()` in `R/names.R` has two rules:

- a comma present: take everything before it — `"SANDERSON, Rachel"` -> `sanderson`
- otherwise: take the **leading token** — correct for `"SANDERSON Rachel"`,
  and it takes the GIVEN name for `"Rachel Sanderson"`

So every sa2018 surname resolved to a first name.
`candidate_returns("sa2018", "sa2022")` matched **0 of 219** candidates. No
returning non-majors meant no MP-slope panel rows for that pair, which meant
no slopes, which meant the harness refused to run.

61 of 264 names also carried raw wiki markup — `[[Rachel Sanderson]]` and the
piped `[[Robert Simms (politician)|Robert Simms]]`. That was the visible half
of the problem and the smaller one; the name ORDER broke the other 203 too.

**Nothing downstream could reveal it.** `candidate_returns()` returned 219 rows
all marked `same = FALSE`, which reads exactly as "no South Australian
candidate re-stood in 2022" — a sentence that could have been true. This is the
same shape as the Victorian seat-case bug recorded in `R/candidate_returns.R`'s
own comments, which reported that no Victorian candidate had ever re-stood, and
as the `MP0p` line that printed "22 of 23 pairs contributed rows" without ever
naming the missing one.

## The fix

`scripts/build_candidacies.R` — parse `surname` and `given` from `name` for
sa2018: strip wiki markup keeping the display half, then first token is the
given name and THE REST is the surname. "The rest" rather than "the last token"
so `"Dominic Wy Kanak"` keeps `Wy Kanak`, which normalises to the same key as
sa2022's `"WY KANAK, Dominic"`; the failure it accepts instead is a middle name,
which Wikipedia election boxes rarely carry. A `stop()` fires if more than 5
names yield no surname.

`scripts/build_level_pred.R` — `sa2022 = "2022-03-19"` in `DATES`,
`sa2022 = "sa2018"` in `PREV`.

`scripts/fit_xgb_primary_v6.R` / `_v7.R` — `sa2022` added to `PAIRS`.

## Validation, in the order it was checked

| check | before | after |
|---|---|---|
| sa2018 surnames parsed | 0 of 264 | 264 of 264 |
| candidates matched sa2018 -> sa2022 | 0 of 219 | **52 of 219 (23.7%)** |
| returning non-majors, that pair | 0 | 11 |
| mp-slope pairs contributing | 22 of 23 | **23 of 23** |
| feature corpus | 13,352 rows / 22 pairs | 13,634 / 23 |
| sa2022 backtest | **failed to run** | runs |
| sa2022 seat log loss | 0.9409 | **0.6463** |
| pooled over 2,097 seat-elections | 0.3207 | **0.3115** |

The 0.3115 is the FULL 23-pair rerun with every harness re-measured on the new
corpus, SD off on both sides. An earlier estimate in this session put it at
0.3141 by crediting only sa2022's own 47 seats; the real figure is better
because the gain is spread -- leave-one-pair-out means every fold now trains on
one more pair. 16 pairs improved and 7 worsened, with sa2026 (+0.0410) and
fed2016 (+0.0113) the regressions still open.

23.7% is the number that says the parse is RIGHT rather than merely non-empty:
`R/candidate_returns.R` records 15-26% as the normal range across pairs, and a
naive fix could easily have produced 3% or 60%.

sa2022 contributes 282 cells, not 329 — six classes over 47 seats. One Nation
is absent because it genuinely did not contest South Australia in 2022, so the
"dropped 47 rows with no state level" line is correct behaviour, not a gap.

**Caveat on the headline gain:** the 0.9409 came from a 57-hour-old file on a
different code tag, so part of the 0.2946 is five days of unrelated change. The
pair going from "cannot run" to "runs" is the unambiguous part.

## What this invalidates

Adding a pair changes **every other pair's** predictions: leave-one-pair-out
means each fold now trains on one extra pair, and the MP-slope panel moved
892 -> 903 rows so the leave-one-out slopes shifted for all 23 targets. Every
baseline measured before this change is stale, including the same day's
`AUSPOL_XGB_PRIMARY_SD` arm. The effect is ~2% of the corpus and will not flip
that arm's verdict, but the figures move.

`output/xgb-primary-sd-oof.csv` is also now stale against the corpus and should
be rebuilt from `scripts/fit_xgb_primary_sd.R` before the SD model is measured
again.

## The lesson, which is an old one here

**A count is not an identity.** `fit_mp_slope.R` printed
`MP0p 22 of 23 pairs contributed rows` and carried on. It has a `.pair_fail`
list that NAMES pairs whose `candidate_returns()` throws — and this pair did
not throw, it returned rows that all failed a downstream filter. The guard was
built for the failure mode someone imagined, and the real one walked past it.

A check that reports "22 of 23" must say WHICH ONE. The fix is one `setdiff()`.

## Still open

- `AUSPOL_SA_PAIR=2022` needs adding to the harness parity sweep in
  `docs/MODEL-REGISTRY.md`.
- sa2018 remains absent from `level-pred.csv` and the feature corpus as a
  TARGET (it has no predecessor in the corpus), which is correct, but means the
  SA jurisdiction contributes 2 of a possible 3 pairs.
- The `MP0p` identity fix above is not yet written.

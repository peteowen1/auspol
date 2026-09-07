# New South Wales 2019 joins the backtest, and what scoring it exposed

2026-09-07. Coverage goes from 19 scored pairs to 20, and from 1,791
seat-elections to 1,884. Four findings came out of it, two of them defects.

## What was added

The nsw2015 preference distributions were fetched from the NSW Electoral
Commission's archive (93 districts) and the nsw2015 first-preference workbook
was already on disk. That makes **nsw2015 to nsw2019** scoreable on flows that
predate it, which is the leakage condition every pair here has to meet.

| | value |
|---|---|
| seats scored | 93 |
| winner accuracy | 92.5% (86 of 93) |
| Brier on the winning party | 0.0695 |
| seat log loss | 0.3966 |
| seat-share RMSE | 5.552 |

Its winners reconcile exactly with the declared result: Coalition 54, Labor 34,
Greens 3, independents 2 in 2015, and Coalition 48, Labor 36, Greens 3,
Shooters 3, independents 3 in 2019.

The New South Wales harness was hardcoded to one target in seventeen places.
It now takes `AUSPOL_NSW_PAIR`, defaulting to 2023. The refactor was accepted
on **byte-identity**: the 2023 pair reproduces its previous output file exactly,
which is the only check that separates a rename from a model change.

## Pooled position, all six harnesses re-run on the same day

| jurisdiction | pairs | seat-elections | accuracy | Brier | log loss |
|---|--:|--:|--:|--:|--:|
| federal | 7 | 1,036 | 86.9% | 0.0966 | 0.3242 |
| Western Australia | 7 | 361 | 87.3% | 0.0995 | 0.4648 |
| New South Wales | 2 | 181 | 89.0% | 0.0817 | 0.3483 |
| Victoria | 2 | 166 | 88.6% | 0.0792 | 0.2877 |
| Queensland | 1 | 93 | 82.8% | 0.1086 | 0.3350 |
| South Australia | 1 | 47 | 78.7% | 0.1124 | 0.3215 |
| **pooled** | **20** | **1,884** | **86.9%** | **0.0952** | **0.3507** |

`scripts/pool_backtests.R` produces this table. It takes the newest file per
pair and prints that file's timestamp and code tag beside every row, so a stale
row is visible in the output rather than having to be remembered.

## Finding 1: the slope refit moved nothing, and that is correct

Adding nsw2019 to the leave-one-election-out panel in `scripts/fit_mp_slope.R`
took it from 19 pairs to 20 and moved the fitted `also_ran` slopes by up to
0.092. Every harness then produced **byte-identical** output.

That is not a bug. nsw2019 contributes 29 non-major seat-classes and **zero
returning members**, and the harnesses read only the `member` column. So the
one column that moved is the one nothing consumes.

Worth recording separately: `also_ran` is fitted, written to
`output/mp-slope-by-target.csv`, and **read by nothing outside its own fitting
script**. It is the contrast term in that script's report, which is a fair
reason to keep it, but it should not be mistaken for a live parameter.

## Finding 2 (defect, fixed): Queensland trained without South Australia

When the Queensland harness was built from the South Australian one on
2026-09-07, the surge training list was copied and `sa2026` was mechanically
renamed to `qld2024`. That is wrong twice over. `scripts/fit_salience_surge_v2.R`
records that Queensland's cycles were checked and add no governed emergence,
because every 2024 non-major winner there was a returning incumbent, so the
renamed row contributes nothing and is filtered out anyway as the harness's own
target. Meanwhile it dropped the election with four One Nation winners, the
largest emergence signal in the corpus.

Fixed. Queensland's hazard now trains on 20 winners rather than 19. The effect
is **neutral**: log loss 0.3350 either way, Brier 0.1087 to 0.1086, seat-share
RMSE 3.258 to 3.261. Reported as neutral rather than as an improvement.

## Finding 3 (open): the statewide covariance is fitted in sample, on half the data

`scripts/estimate_statewide_cov.R` builds ONE correlation matrix from a
hardcoded list of ten pairs, and every harness reads it, including when scoring
a pair that is in the fit. Two problems:

- **Leakage.** Scoring nsw2023 uses a correlation matrix fitted partly on
  nsw2023's own statewide swing. `scripts/fit_mp_slope.R` already solves this
  shape by fitting leave-one-election-out and writing one row per target.
- **Under-use.** Twenty pairs are available and ten are in the list. Missing:
  qld2024, all seven Western Australian pairs, and now nsw2019.

The fix is one change with two parts, and it needs its own pre-registration
because it moves the published model.

## Finding 4 (open): a seat that changed hands between elections is nearly invisible

Nineteen of 893 seat-elections had a sitting member from a different party than
the one that won the seat at the previous election, through a by-election or a
member changing party. The model reads the previous election's first
preferences, so it does not know.

| pair | seats | log loss there | log loss elsewhere |
|---|---|--:|--:|
| nsw2019 | Orange, Wagga Wagga | **5.705** | 0.280 |
| vic2022 | Morwell | **2.175** | 0.224 |
| qld2024 | Ipswich West, Mirani | 0.615 | 0.329 |
| fed2025 | Aston, Calare, Mayo | 0.452 | 0.301 |
| sa2026 | Black, Dunstan, Kavel, Mount Gambier | 0.299 | 0.313 |
| nsw2023 | Barwon, Bega, Murray, Orange | 0.233 | 0.300 |
| fed2019 | Mayo, Wentworth | 0.093 | 0.265 |
| fed2022 | Mayo | 0.096 | 0.387 |

**The damage is concentrated, not general.** In nsw2023 and the federal pairs
these seats score BETTER than the rest, because by then the new holder's party
has a real prior vote in the seat. The failures are the seats where the change
of hands is recent and the incoming party had little presence: Orange, where
Philip Donato won a 2016 by-election for the Shooters and we gave the winner
0.000; Wagga Wagga, where Joe McGirr won a 2018 by-election as an independent
and we gave him 0.044; and Morwell.

**Size it before building it.** The excess is about 13.8 log units over the
whole pool, so removing it entirely is worth roughly **0.007 of pooled log
loss** against a current 0.3507, about 2%. That makes it a targeted fix, and
under this repo's own rule a targeted fix is validated on its named targets
with the election-wide metric as a do-no-harm guard, never the other way round.

**The data is already on disk and already loaded.** `load_seats(2019, "nsw")`
returns Orange as Shooters-held and Wagga Wagga as independent-held, and the
harness calls that function for its predictors. The field is known before
polling day, so using it is leakage-free.

Two cautions carried from `CLAUDE.md`. The anchor's party labels are not ours,
so any use needs an explicit and printed mapping; it files the Shooters as
independents in some files and as `SFF` in others. And that same field is the
wrong answer to "who won last time", which is a different question that must
keep coming from declared results.

## The one leakage question this raised, measured rather than assumed

The surge hazard is fitted **leave-one-election-out, not walk-forward**. That is
deliberate and `scripts/fit_salience_surge_v2.R` explains why: the training set
is small enough that a strict chronological split would leave the early pairs
with almost nothing. The consequence is that scoring an early pair uses later
elections.

For nsw2019 that is sharper than usual, because the later pair is nsw2023 in the
same chamber, and the seats carrying the emergence signal — Barwon, Murray,
Orange — appear in both. So it was measured rather than argued about.

Refitting the nsw2019 hazard with every New South Wales pair removed:

| | with nsw2023 | without |
|---|--:|--:|
| training winners | 20 | 19 |
| mean seat hazard | 0.01434 | 0.01483 |
| max seat hazard | 0.07200 | 0.07704 |

Correlation between the two sets of per-seat hazards is **0.9985** and the mean
absolute difference is 0.00063. Removing nsw2023 makes the hazards slightly
HIGHER, so its presence is not inflating the seats being scored. The nsw2019
number stands.

What the same numbers do show is the emergence problem in its usual form:
Barwon and Murray, both won by the Shooters, carry hazards of 0.027 and 0.037.
That is the model saying these are ordinary seats.

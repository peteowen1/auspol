# The SD model across all six harnesses, and census demographics as features

2026-09-12. Two changes measured end to end. One works exactly where it was
aimed and nowhere else; the other does not work at all. Both are recorded here
with the numbers, because both close a question.

## 1. `AUSPOL_XGB_PRIMARY_SD` — measured on 22 of 23 pairs, NOT recommended

Pete, 2026-09-12: *"Turn the SD model on for Narungga and Hammond — AEF's
primary was no better than ours there and they gave the winner 5x the
probability."*

### The targeted claim passes

Both named seats improved. Seat log loss contribution, lower is better:

| seat | winner | prob off | prob on | ll off | ll on | move |
|---|---|---|---|---|---|---|
| Narungga | ONP | 0.0169 | 0.0266 | 4.08 | 3.63 | −0.46 |
| Hammond | ONP | 0.0252 | 0.0358 | 3.68 | 3.33 | −0.35 |

All four South Australian One Nation winners are the four largest gains in the
pair — MacKillop −0.759, Ngadjuri −0.722, Narungga −0.457, Hammond −0.351 — and
sa2026 moved 0.5384 → 0.5059. Only 8 of 47 seats improve; the other 39 pay a
small premium and it still nets out, because log loss is set by the
catastrophic seats. Brier would not have seen this (0.1533 → 0.1535).

The baseline was re-run on the identical tree and reproduced 0.5384 exactly, so
the move is the flag and not a code drift.

### The election-wide guard fails

| metric | baseline | SD on | move |
|---|---|---|---|
| seat-weighted, 2,050 seat-elections | 0.3065 | 0.3068 | +0.0003 |
| unweighted over 22 pairs | 0.3254 | 0.3232 | −0.0021 |
| pairs improved / worse | — | — | 9 / 13 |

By jurisdiction, seat-weighted, negative = helped:

| region | pairs | seats | base | SD on | move |
|---|---|---|---|---|---|
| sa | 1 | 47 | 0.5384 | 0.5059 | −0.0325 |
| nsw | 2 | 181 | 0.3136 | 0.3037 | −0.0099 |
| wa | 7 | 361 | 0.3731 | 0.3654 | −0.0076 |
| vic | 3 | 239 | 0.2344 | 0.2365 | +0.0021 |
| qld | 2 | 186 | 0.2871 | 0.2894 | +0.0022 |
| fed | 7 | 1,036 | 0.2916 | 0.2972 | +0.0056 |

The two pooled figures disagree because the gains sit in small pairs (wa2001 at
57 seats, sa2026 at 47) and the losses spread across the large federal ones.

### Why fed2022 is the result that matters

**fed2022 got WORSE, 0.3034 → 0.3062.** Six teals, the largest emergence event
in the corpus, and extra width did not help them.

That is not a contradiction, it is the mechanism. fed2022 already HAS a
mechanism for the teals — the salience gate raises the point estimate directly.
`combine_sd_override()` takes the elementwise maximum, so the SD model can only
ever widen, never narrow, and on those cells it is adding spread to candidates
the model is already getting roughly right. That dilutes.

Where it wins is where the model had NO mechanism at all: South Australian One
Nation, nsw2019, wa2001. So the honest summary is not "wide is better", it is
**"wide beats nothing, and loses to a working point estimate"** — which is an
argument for fixing the level, not for shipping the width.

### Decision

Leave `AUSPOL_XGB_PRIMARY_SD = "0"` in `published_flags.R`.

Scoping the flag to sa/nsw/wa would clear every number above, and it is refused
anyway: those three were chosen AFTER seeing the results, on the same data.
That is the post-hoc rationalisation `CLAUDE.md` already records going wrong
twice. If it is worth doing it is worth pre-registering, with the jurisdiction
split named before the run.

The diagnostic worth doing first is **fed2016**, the largest single regression
at +0.0232 on a 0.3847 baseline. Which cells did the widening hurt? If they are
a class the model already handles, a narrower `AUSPOL_XGB_PRIMARY_SD_CLASSES`
is the real fix and can be pre-registered honestly.

## 2. Census demographics as model features — built, measured, does NOT work

Asked for in August, never delivered, and the request came with *"if you leave
any vars out let me know dont just silently do it"*. It is delivered now, and
the answer is that it does not help.

### The join works

`scripts/build_census_features.R` → `output/census-features.csv`, seven
features over 2,097 seat-pairs at 95% coverage (2,050 when first built, before
sa2022 joined the corpus later the same day). The reaggregated census files
carried `final_name` all along, so the join everyone assumed was missing needed
no fetching.

Two join faults found and fixed: Victorian census names carry an upper-house
region suffix (`Albert Park (Southern Metropolitan)`), and each reaggregated
file covers all five states, so seat names repeat across them (Murray in NSW
and Victoria, Albert Park in Victoria and South Australia) and the merge
multiplied rows until it was filtered by the state prefix of `final_code`.

WA sits at 54–81% because WA redistributes hard and seat names do not survive
between elections — the same documented fact that limits its backtest coverage.

### The correlation is the strongest in the corpus

sa2026 One Nation vote against each feature, n = 47 seats:

| feature | r |
|---|---|
| yr12_pct (top schooling is Year 12) | **−0.922** |
| edu_25plus_pct (aged 25+ still studying) | −0.758 |
| indig_pct | +0.607 |
| born_aus_pct | +0.581 |
| lang_other_pct | −0.566 |
| under35_pct | −0.317 |
| over55_pct | +0.175 |

Narungga (Year 12 33%, tertiary study 1.6%) polled One Nation 37.5. Bragg (73%,
4.1%) polled 9.1. We predicted 17.9 and 19.3.

### And it still fails out of fold

Out-of-fold RMSE in points of primary vote, lower is better:

| arm | features | pooled | sa2026 ONP |
|---|---|---|---|
| v7c (baseline) | 40 | **3.8740** | **8.658** |
| v7k raw census | 47 | 3.8854 | 9.544 |
| v7l within-pair z-score | 47 | 3.8718 | 9.547 |
| v7m within-pair percentile | 47 | 3.8769 | — |

The raw version made the target WORSE and destroyed the ranking that existed:
correlation with the actual fell +0.362 → +0.057.

Standardising within the pair was the right diagnosis and an insufficient fix.
Mean Year 12 completion drifts 51.4 (sa2026) to 60.8 (fed2022) across the
corpus, so a split at `yr12_pct < 55` selects below-average seats in one pair
and above-average in another, and leave-one-pair-out punishes exactly that.
Removing the drift recovered 0.014 of pooled RMSE — the mechanism is real — but
that only buys a dead heat with v7c, and sa2026 One Nation stayed worse.

There IS a consistent signal, just not where it was wanted. Census features
help GRN (2.639 → 2.596), OTH_RIGHT (3.271 → 3.208) and OTH (1.934 → 1.905),
and hurt ONP, ALP and LNP. Three classes gain, three lose, and the pooled
number is the wash that implies.

### Why it could not have worked, and what that says

**−0.922 is a WITHIN-sa2026 correlation.** It says that among South Australian
seats in 2026, the less educated ones went One Nation. Leave-one-pair-out never
lets the model see that — it must learn the relationship from Queensland, WA
and federal One Nation cells and transfer it. It did not transfer.

The deeper reason is that this was the wrong target. Predicted One Nation
spread across the 47 South Australian seats is **1.49** against an actual
**7.67**; we predict roughly 18.5 everywhere and One Nation polled about 27
statewide. So sa2026's 8.658 RMSE is mostly a LEVEL miss, and demographics can
only ever fix RANKING. A perfect demographic ordering still leaves an 8-point
statewide error untouched.

**Ranking and level are separate failures, and the level is the bigger one.**
It is set upstream at `state_mean` in `fit_seats_full.R:409`, the poll-trend
plus fundamentals stage — not in the seat model at all.

### Income: deliberately excluded, and this is the "don't do it silently" note

The federal CED census files carry six income and housing medians
(`Median_tot_prsnl_inc_weekly`, `Median_mortgage_repay_monthly`,
`Median_rent_weekly`, `Median_tot_fam_inc_weekly`, `Median_tot_hhd_inc_weekly`,
`Average_household_size`). The state SED reaggregations carry NONE of them —
they are ABS table G01 only.

So an income feature would be real for 7 federal pairs and filler for 15 state
pairs, which is exactly the shape that sank the state-deviation block the same
day: v7i scored 3.9297 against 3.8740, and v7j split by jurisdiction was worse
on both halves. A column real in one jurisdiction and filler in another becomes
a jurisdiction label and the tree uses it as one.

It would also not have served the case here. sa2026 is a state election, so
income would be absent for exactly the seats it was meant to separate.

**To revisit:** reaggregating ABS table G02 to state boundaries needs the 2016
SA1 medians plus the correspondence weights the G01 reaggregation already used.
That is a data-build task, and it would make income available everywhere rather
than half the corpus.

## 3. sa2022 is missing from four separate parts of the model

Found while checking the SD model's pair coverage, and it is worth more than
either result above.

`sa2022` is scored by the backtest (47 seats) but is absent from:

1. the xgb primary feature corpus — `fit_xgb_primary_v6.R:43` lists it only as
   sa2026's `prev`, never as a target election
2. the SD model — no rows in `output/xgb-primary-sd-oof.csv`
3. the MP-slope leave-one-out table — the harness dies outright:
   `Error: no leave-one-out MP slopes for sa2022 in output/mp-slope-by-target.csv`
4. the party-correlation fit — its own log says
   *"all 15 pairs (sa2022 is not in the fit, so nothing to hold out)"*

**It is our worst pair: log loss 0.9409 against a 0.3207 pooled average, and it
carries 2 of the corpus's 4 seats where the actual winner was given ≤ 1e-4.**

That number has been sitting in the headline pooled figure as though it
measured the model. It does not — it measures the fallback paths. The pooled
0.3207 over 2,097 seat-elections and the model corpus's 2,050 differ by exactly
these 47 seats.

`sa2018` has 264 candidacy rows on disk and the SA harness already supports the
pair via `AUSPOL_SA_PAIR=2022`, so the feature-corpus half is one entry in the
`PAIRS` list in v6 and v7. The MP-slope and correlation tables need rebuilding
with sa2022 as a target.

## Files

- `scripts/build_census_features.R` — new, emits `output/census-features.csv`
- `scripts/fit_xgb_primary_v7.R` — arms v7k, v7l, v7m and the within-pair
  standardisation block
- `R/xgb_primary_sd_override.R` — unchanged; measured, not modified
- `scripts/published_flags.R` — unchanged, `AUSPOL_XGB_PRIMARY_SD` stays `"0"`

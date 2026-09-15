# Data dictionary

**Generated 2026-09-15 by `scripts/build_data_dictionary.R`. Do not hand-edit.**

Companion to `docs/DATA-REGISTRY.md`. The registry answers *do we have this
file*; this answers *do we have this field*. Four wrong "we don't have it"
claims in two days came from the second question, and two of them were
fields we download and then throw away. **Check here before concluding a
column does not exist.**

## Processed election data (`external/elections/`)

| file | rows | columns |
|---|---:|---|
| `aec-fed-firstprefs.csv` | 6,572 | `seat`, `party`, `votes`, `election` |
| `aec-fed-tcp.csv` | 2,404 | `election`, `seat`, `party`, `votes` |
| `aec-fed-transfers.csv` | 18,227 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `aec-fed-winners.csv` | 1,202 | `election`, `seat`, `winner` |
| `ecq-2017-qld-firstprefs.csv` | 416 | `seat`, `party`, `votes` |
| `ecq-2017-qld-winners.csv` | 93 | `election`, `seat`, `winner` |
| `ecq-2020-qld-firstprefs.csv` | 545 | `seat`, `party`, `votes` |
| `ecq-2024-qld-firstprefs.csv` | 507 | `seat`, `party`, `votes` |
| `ecq-qld-transfers.csv` | 2,739 | `election`, `seat`, `round`, `from`, `to`, `votes`, `to_n` |
| `ecq-qld-winners.csv` | 186 | `election`, `seat`, `winner` |
| `ecsa-2022-sa-firstprefs.csv` | 219 | `seat`, `party`, `votes` |
| `ecsa-2026-sa-firstprefs.csv` | 298 | `seat`, `party`, `votes` |
| `ecsa-2026-sa-onp-shares.csv` | 47 | `seat`, `pct` |
| `ecsa-2026-sa-transfers.csv` | 1,321 | `election`, `seat`, `round`, `from`, `to`, `votes`, `to_n` |
| `ecsa-sa-winners.csv` | 94 | `election`, `seat`, `winner` |
| `fed-swing-transposed.csv` | 870 | `seat`, `fed_swing`, `booths`, `votes`, `region`, `cycle`, `fed` |
| `federal-transposed-to-state.csv` | 3,565 | `seat`, `party`, `votes`, `pct`, `region`, `cycle`, `fed_election` |
| `MANIFEST.csv` | 5 | `source`, `dataset`, `url`, `rows`, `fetched_at` |
| `nswec-2015-nsw-firstprefs.csv` | 504 | `seat`, `party`, `votes` |
| `nswec-2019-nsw-firstprefs.csv` | 467 | `seat`, `party`, `votes` |
| `nswec-2023-nsw-firstprefs.csv` | 473 | `seat`, `party`, `votes` |
| `nswec-nsw-transfers.csv` | 3,935 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `nswec-nsw-winners.csv` | 279 | `election`, `seat`, `code`, `winner` |
| `vec-2010-vic-firstprefs.csv` | 414 | `seat`, `party`, `votes` |
| `vec-2010-vic-transfers.csv` | 625 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `vec-2010-vic-winners.csv` | 88 | `election`, `seat`, `winner`, `winner_name` |
| `vec-2014-vic-firstprefs.csv` | 430 | `seat`, `party`, `votes` |
| `vec-2014-vic-transfers.csv` | 767 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `vec-2014-vic-winners.csv` | 88 | `seat`, `winner` |
| `vec-2018-vic-firstprefs.csv` | 403 | `seat`, `party`, `votes` |
| `vec-2018-vic-transfers.csv` | 600 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `vec-2018-vic-winners.csv` | 88 | `seat`, `winner` |
| `vec-2022-vic-candidates.csv` | 731 | `seat`, `cand`, `party`, `fp_votes` |
| `vec-2022-vic-firstprefs.csv` | 508 | `seat`, `party`, `votes` |
| `vec-2022-vic-transfers.csv` | 1,956 | `election`, `seat`, `round`, `from`, `to`, `votes`, `to_n` |
| `vec-2022-vic-winners.csv` | 87 | `seat`, `winner` |
| `waec-1996-wa-firstprefs.csv` | 208 | `seat`, `party`, `votes` |
| `waec-2001-wa-firstprefs.csv` | 315 | `seat`, `party`, `votes` |
| `waec-2005-wa-firstprefs.csv` | 303 | `seat`, `party`, `votes` |
| `waec-2008-wa-firstprefs.csv` | 248 | `seat`, `party`, `votes` |
| `waec-2013-wa-firstprefs.csv` | 251 | `seat`, `party`, `votes` |
| `waec-2017-wa-firstprefs.csv` | 340 | `seat`, `party`, `votes` |
| `waec-2021-wa-firstprefs.csv` | 340 | `seat`, `party`, `votes` |
| `waec-2025-wa-firstprefs.csv` | 334 | `seat`, `party`, `votes` |
| `waec-wa-transfers.csv` | 5,894 | `election`, `seat`, `round`, `from`, `to`, `votes`, `three_cornered` |
| `waec-wa-winners.csv` | 466 | `election`, `seat`, `winner` |
| `wikipedia-2018-sa-firstprefs.csv` | 264 | `seat`, `name`, `party_raw`, `votes`, `party` |
| `wikipedia-2018-sa-winners.csv` | 47 | `election`, `seat`, `winner` |

## Raw downloads (`external/reference/`)

The originals, before any aggregation. **This is where dropped columns live.**

### aec/

| file | rows | columns |
|---|---:|---|
| `fed2004-dop.csv` | 29,057 | `StateAb`, `DivisionID`, `DivisionNm`, `CountNumber`, `BallotPosition`, `CandidateID`, `Surname`, `GivenNm`, `PartyAb`, `PartyNm`, `SittingMemberFl`, `CalculationType`, `CalculationValue` |
| `fed2004-firstprefs.csv` | 1,242 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `SittingMemberFl`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| `fed2004-tcp.csv` | 301 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `SittingMemberFl`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| `fed2007-dop.csv` | 26,873 | `StateAb`, `DivisionID`, `DivisionNm`, `CountNumber`, `BallotPosition`, `CandidateID`, `Surname`, `GivenNm`, `PartyAb`, `PartyNm`, `Elected`, `HistoricElected`, `CalculationType`, `CalculationValue` |
| `fed2007-firstprefs.csv` | 1,205 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `Elected`, `HistoricElected`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| `fed2007-tcp.csv` | 301 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `Elected`, `HistoricElected`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| `fed2010-dop.csv` | 17,433 | `StateAb`, `DivisionID`, `DivisionNm`, `CountNumber`, `BallotPosition`, `CandidateID`, `Surname`, `GivenNm`, `PartyAb`, `PartyNm`, `Elected`, `HistoricElected`, `CalculationType`, `CalculationValue` |
| `fed2010-firstprefs.csv` | 1,000 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `Elected`, `HistoricElected`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| `fed2010-tcp.csv` | 301 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `Elected`, `HistoricElected`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| `fed2013-dop.csv` | 35,065 | `StateAb`, `DivisionID`, `DivisionNm`, `CountNumber`, `BallotPosition`, `CandidateID`, `Surname`, `GivenNm`, `PartyAb`, `PartyNm`, `Elected`, `HistoricElected`, `CalculationType`, `CalculationValue` |
| `fed2013-firstprefs.csv` | 1,339 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `Elected`, `HistoricElected`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| `fed2013-tcp.csv` | 301 | `StateAb`, `DivisionID`, `DivisionNm`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `Elected`, `HistoricElected`, `PartyAb`, `PartyNm`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes`, `TotalVotes`, `Swing` |
| _(+12 more of the same shape)_ | | |

### nsw/

| file | rows | columns |
|---|---:|---|
| `elected-2023.csv` | 93 | `slug`, `label` |

- **vec/** — no CSVs (see registry for other formats)
### ecsa/

| file | rows | columns |
|---|---:|---|
| `sa2022-districts.csv` | 47 | `seat`, `winner`, `runner_up`, `winner_2cp`, `alp_2pp`, `formal`, `fp_AFP`, `fp_AJP`, `fp_ALP`, `fp_FFP`, `fp_GRN`, `fp_IND`, `fp_LDP`, `fp_LIB`, `fp_NAT`, `fp_ONP`, `fp_RCH`, `fp_SAB` |
| `sa2026-2pp.csv` | 47 | `seat`, `alp_2pp_votes`, `lib_2pp_votes`, `alp_2pp` |
| `sa2026-districts.csv` | 47 | `seat`, `winner`, `runner_up`, `winner_2cp`, `alp_2pp`, `formal`, `fp_AFP`, `fp_AJP`, `fp_ALP`, `fp_FFP`, `fp_FGA`, `fp_GRN`, `fp_IND`, `fp_LCP`, `fp_LIB`, `fp_NAT`, `fp_ONP`, `fp_RCH`, `fp_SAB`, `fp_UVA` |
| `sa2026-seats.csv` | 47 | `seat`, `winner`, `runner`, `win_2cp`, `onp_fp` |

- **ecq/** — no CSVs (see registry for other formats)
- **waec/** — no CSVs (see registry for other formats)
## Columns we download and DROP

Each row is a field present in the raw download and absent from the
processed extract. Every one is recoverable without a new fetch.

| raw source | processed as | genuinely dropped | renamed/aggregated |
|---|---|---|---|
| `fed2022-firstprefs.csv` | `aec-fed-firstprefs.csv` | **`StateAb`, `DivisionID`, `CandidateID`, `Surname`, `GivenNm`, `BallotPosition`, `Elected`, `HistoricElected`, `PartyAb`, `Swing`** | `DivisionNm`, `PartyNm`, `TotalVotes`, `OrdinaryVotes`, `AbsentVotes`, `ProvisionalVotes`, `PrePollVotes`, `PostalVotes` |

**Known consequences of the two that mattered:**

- `Surname` / `GivenNm` — cost a plan written around *acquiring* candidate
  names that were already downloaded. Now recovered by
  `scripts/build_candidacies.R` into `output/candidacies.csv`.
- `Swing` — the AEC's own seat-level swing, per candidate per division,
  for all seven elections. `backtest_candidate_fed.R` records that it
  "cannot test" the seat-swing port for want of a swing predictor.
- `Elected` / `HistoricElected` — incumbency, which the published model
  has no candidate-level feature for at all.

## Derived outputs (`output/`)

| file | rows | columns |
|---|---:|---|
| `_prefix-shipped-oof-BACKUP.csv` | 13,739 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `aef-comparison-full.csv` | 660 | `seat`, `actual`, `our_pred`, `our_p`, `seeds`, `aef_pred`, `aef_p`, `delta`, `our_primary`, `actual_primary`, `aef_primary`, `pair`, `our_pe`, `aef_pe`, `prim_gap`, `why` |
| `aef-primary-all.csv` | 3,671 | `seat`, `party`, `aef_pcv`, `election` |
| `aef-seat-scores.csv` | 728 | `election`, `seat`, `actual`, `pred`, `pred_p`, `prob`, `tpp_actual` |
| `aef-worst-seats-full.csv` | 659 | `seat`, `actual`, `our_pred`, `our_p`, `aef_pred`, `aef_p`, `delta`, `our_primary_actual`, `actual_primary`, `aef_primary_actual`, `pair` |
| `aef7-final-two-derived.csv` | 347 | `election`, `seat`, `f1`, `f2`, `f2cp`, `rule` |
| `anchor-k.csv` | 834 | `region`, `year`, `K`, `party`, `fitted`, `actual`, `prior`, `polls30`, `err`, `cyc` |
| `c3-widened-population.csv` | 4,168 | `election`, `region`, `seat`, `name`, `party`, `pcv`, `elected`, `own_prev_pcv`, `base`, `gated`, `xp`, `emergence` |
| `cal-fed-m1.0.csv` | 886 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-fed-m1.5.csv` | 886 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-fed-m2.5.csv` | 886 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-fed-m4.0.csv` | 886 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-nsw-m1.0.csv` | 88 | `seat`, `p`, `pred`, `pred_p`, `actual`, `bin` |
| `cal-nsw-m1.5.csv` | 88 | `seat`, `p`, `pred`, `pred_p`, `actual`, `bin` |
| `cal-nsw-m2.5.csv` | 88 | `seat`, `p`, `pred`, `pred_p`, `actual`, `bin` |
| `cal-nsw-m4.0.csv` | 88 | `seat`, `p`, `pred`, `pred_p`, `actual`, `bin` |
| `cal-sa-m1.0.csv` | 47 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-sa-m1.5.csv` | 47 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-sa-m2.5.csv` | 47 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-sa-m4.0.csv` | 47 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-vic-m1.0.csv` | 166 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-vic-m1.5.csv` | 166 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-vic-m2.5.csv` | 166 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-vic-m4.0.csv` | 166 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `calibration-arms.csv` | 10 | `pair`, `n`, `mult`, `logB`, `acc`, `T`, `logA`, `logC`, `B_vs_A`, `B_vs_C` |
| `candidacies.csv` | 18,172 | `election`, `region`, `year`, `seat`, `name`, `surname`, `given`, `party`, `party_raw`, `party_ab`, `state`, `votes`, `pcv`, `elected`, `historic_elected`, `breakout`, `swing`, `ballot_position`, `ordinary`, `absent`, `provisional`, `prepoll`, `postal`, `ballot_order`, `tot` |
| `candidate-contests.csv` | 14,953 | `election`, `region`, `party`, `candidate_id`, `seat`, `pcv`, `surname`, `given`, `expected_pcv`, `performance_vs_expected` |
| `candidate-ids.csv` | 10,763 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12` |
| `candidate-review.csv` | 190 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15` |
| `census-features.csv` | 2,372 | `pair`, `seat`, `vintage`, `exact`, `yr12_pct`, `born_aus_pct`, `indig_pct`, `over55_pct`, `under35_pct`, `lang_other_pct`, `edu_25plus_pct` |

_(3913 `backtest-*.csv` arm outputs omitted; they share one shape.)_


## Columns we HAVE on disk and never parse

Generated files above describe what we store. This section records what the
SOURCES carry that our parsers drop, because "the file is in the registry" has
three times been read as "we have the field". See
`docs/reviews/unparsed-preference-detail-2026-09-15.md`.

| source on disk | files | carried by the source | kept in our CSV |
|---|--:|---|---|
| `external/reference/nsw/dop/*.html` | 279 | candidate names + party, round-by-round progressive totals, exclusion order, **exhausted votes**, printed two-candidate percentages | `election, seat, round, from, to, votes` (classes only) |
| `external/elections/cache/vec-2022-vic/*.html` | 163 | the same, for Victoria 2022 | as above, and **incomplete**: 76 of 87 seats, only 48 counts complete |

Every `*-transfers.csv` in `external/elections/` is class-to-class. None carries
an exhausted-votes column, although `R/preferences.R` takes an `exhaust`
argument and currently sources it from polling rather than from these counts.


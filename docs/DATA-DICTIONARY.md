# Data dictionary

**Generated 2026-10-19 by `scripts/build_data_dictionary.R`. Do not hand-edit.**

Companion to `docs/DATA-REGISTRY.md`. The registry answers *do we have this
file*; this answers *do we have this field*. Four wrong "we don't have it"
claims in two days came from the second question, and two of them were
fields we download and then throw away. **Check here before concluding a
column does not exist.**

## Processed election data (`external/elections/`)

| file | rows | columns |
|---|---:|---|
| `aec-fed-2001-firstprefs.csv` | 797 | `seat`, `party`, `votes`, `election` |
| `aec-fed-2001-tcp.csv` | 300 | `election`, `seat`, `party`, `votes` |
| `aec-fed-2001-transfers.csv` | 2,807 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `aec-fed-firstprefs.csv` | 6,573 | `seat`, `party`, `votes`, `election` |
| `aec-fed-tcp.csv` | 2,404 | `election`, `seat`, `party`, `votes` |
| `aec-fed-transfers.csv` | 18,228 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `aec-fed-winners.csv` | 1,202 | `election`, `seat`, `winner` |
| `ecq-2001-qld-firstprefs-detail.csv` | 365 | `seat`, `party_code`, `party_name`, `party_class`, `votes`, `formal_votes`, `informal_votes`, `tcp_winner_votes`, `tcp_loser_votes`, `tcp_winner_pct`, `tcp_winner_code` |
| `ecq-2001-qld-firstprefs.csv` | 330 | `seat`, `party`, `votes` |
| `ecq-2001-qld-tcp-winner.csv` | 89 | `seat`, `party`, `votes` |
| `ecq-2001-qld-tcp.csv` | 20 | `seat`, `party`, `votes` |
| `ecq-2004-qld-firstprefs.csv` | 342 | `seat`, `party`, `votes` |
| `ecq-2004-qld-tcp.csv` | 166 | `seat`, `party`, `votes` |
| `ecq-2006-qld-firstprefs.csv` | 322 | `seat`, `party`, `votes` |
| `ecq-2009-qld-firstprefs.csv` | 373 | `seat`, `party`, `votes` |
| `ecq-2012-qld-firstprefs.csv` | 423 | `seat`, `party`, `votes` |
| `ecq-2012-qld-tcp.csv` | 178 | `seat`, `party`, `votes` |
| `ecq-2015-qld-firstprefs.csv` | 392 | `seat`, `party`, `votes` |
| `ecq-2017-qld-firstprefs.csv` | 416 | `seat`, `party`, `votes` |
| `ecq-2017-qld-winners.csv` | 93 | `election`, `seat`, `winner` |
| `ecq-2020-qld-firstprefs.csv` | 545 | `seat`, `party`, `votes` |
| `ecq-2024-qld-firstprefs.csv` | 507 | `seat`, `party`, `votes` |
| `ecq-qld-transfers.csv` | 2,739 | `election`, `seat`, `round`, `from`, `to`, `votes`, `to_n` |
| `ecq-qld-winners.csv` | 186 | `election`, `seat`, `winner` |
| `ecsa-2002-sa-firstprefs-detail.csv` | 286 | `seat`, `candidate`, `party_code`, `party_name`, `party_class`, `votes`, `pct`, `elected`, `formal_votes` |
| `ecsa-2002-sa-firstprefs.csv` | 219 | `seat`, `party`, `votes` |
| `ecsa-2002-sa-tcp-detail.csv` | 56 | `seat`, `candidate`, `party_code`, `party_name`, `party_class`, `votes`, `pct`, `elected` |
| `ecsa-2002-sa-tcp.csv` | 56 | `seat`, `party`, `votes` |
| `ecsa-2006-sa-firstprefs-detail.csv` | 269 | `seat`, `candidate`, `party_code`, `party_name`, `party_class`, `votes`, `pct`, `elected`, `formal_votes` |
| `ecsa-2006-sa-firstprefs.csv` | 252 | `seat`, `party`, `votes` |
| `ecsa-2006-sa-tcp-detail.csv` | 40 | `seat`, `candidate`, `party_code`, `party_name`, `party_class`, `votes`, `pct`, `elected` |
| `ecsa-2006-sa-tcp.csv` | 40 | `seat`, `party`, `votes` |
| `ecsa-2010-2014-sa-page-inventory.csv` | 89 | `year`, `district`, `fetched`, `n_tables`, `headers`, `looks_like_distribution` |
| `ecsa-2010-sa-firstprefs-tcp.csv` | 420 | `year`, `district`, `table`, `candidate`, `party`, `votes` |
| `ecsa-2014-sa-firstprefs-tcp.csv` | 272 | `year`, `district`, `table`, `candidate`, `party`, `votes` |
| `ecsa-2022-sa-firstprefs.csv` | 220 | `seat`, `party`, `votes` |
| `ecsa-2026-sa-firstprefs.csv` | 298 | `seat`, `party`, `votes` |
| `ecsa-2026-sa-onp-shares.csv` | 47 | `seat`, `pct` |
| `ecsa-2026-sa-transfers.csv` | 1,319 | `election`, `seat`, `round`, `from`, `to`, `votes`, `to_n` |
| `ecsa-sa-winners.csv` | 94 | `election`, `seat`, `winner` |
| `fed-booth-map.csv` | 17,688 | `region`, `cycle`, `fed`, `district`, `place_id` |
| `fed-swing-transposed-wa.csv` | 295 | `seat`, `fed_swing`, `booths`, `votes`, `region`, `cycle`, `fed` |
| `fed-swing-transposed.csv` | 870 | `seat`, `fed_swing`, `booths`, `votes`, `region`, `cycle`, `fed` |
| `federal-transposed-to-state.csv` | 3,582 | `seat`, `party`, `votes`, `pct`, `region`, `cycle`, `fed_election` |
| `MANIFEST.csv` | 5 | `source`, `dataset`, `url`, `rows`, `fetched_at` |
| `nswec-2007-nsw-candidates.csv` | 537 | `seat`, `candidate`, `party`, `party_code`, `party_full`, `class`, `first_pref` |
| `nswec-2007-nsw-firstprefs.csv` | 464 | `seat`, `party`, `votes` |
| `nswec-2007-nsw-winners.csv` | 93 | `election`, `seat`, `code`, `winner`, `basis` |
| `nswec-2011-nsw-candidates-supplement.csv` | 5 | `seat`, `candidate`, `party_code`, `class`, `first_pref` |
| `nswec-2011-nsw-candidates.csv` | 493 | `seat`, `candidate`, `party`, `party_code`, `party_full`, `class`, `first_pref` |
| `nswec-2011-nsw-checks.csv` | 92 | `seat`, `n_cand`, `counts`, `n_excluded`, `n_transfer_rows`, `fp_ok`, `elected_ok`, `elected`, `elected_cell_agrees`, `partial_distribution`, `final`, `tcp_note`, `tcp_max_abs_diff`, `problems` |
| `nswec-2011-nsw-countsheets.csv` | 1,623 | `seat`, `candidate`, `party`, `class`, `kind`, `count`, `votes` |
| `nswec-2011-nsw-firstprefs.csv` | 442 | `seat`, `party`, `votes` |
| `nswec-2011-nsw-transfers-detail.csv` | 708 | `election`, `seat`, `round`, `count`, `from_name`, `from_party`, `from`, `votes_distributed`, `to_name`, `to_party`, `to`, `votes`, `to_progressive` |
| `nswec-2011-nsw-transfers.csv` | 525 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `nswec-2011-nsw-winners.csv` | 93 | `election`, `seat`, `code`, `winner`, `basis` |
| `nswec-2015-nsw-firstprefs.csv` | 504 | `seat`, `party`, `votes` |
| `nswec-2019-nsw-firstprefs.csv` | 467 | `seat`, `party`, `votes` |
| `nswec-2023-nsw-firstprefs.csv` | 473 | `seat`, `party`, `votes` |
| `nswec-nsw-transfers.csv` | 3,935 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `nswec-nsw-winners.csv` | 279 | `election`, `seat`, `code`, `winner` |
| `ntec-2012-nt-candidates.csv` | 86 | `seat`, `candidate`, `surname`, `given`, `party_code`, `party_name`, `fp`, `class`, `elected` |
| `ntec-2012-nt-firstprefs.csv` | 83 | `seat`, `party`, `votes` |
| `ntec-2016-nt-candidates.csv` | 115 | `seat`, `candidate`, `surname`, `given`, `party_code`, `party_name`, `fp`, `class`, `elected`, `tcp` |
| `ntec-2016-nt-firstprefs.csv` | 91 | `seat`, `party`, `votes` |
| `ntec-2020-nt-candidates.csv` | 111 | `seat`, `candidate`, `surname`, `given`, `party_code`, `party_name`, `fp`, `class`, `elected`, `tcp` |
| `ntec-2020-nt-firstprefs.csv` | 98 | `seat`, `party`, `votes` |
| `ntec-2024-nt-candidates.csv` | 80 | `seat`, `candidate`, `surname`, `given`, `party_code`, `party_name`, `fp`, `class`, `elected`, `tcp` |
| `ntec-2024-nt-firstprefs.csv` | 75 | `seat`, `party`, `votes` |
| `ntec-nt-transfers-detail.csv` | 763 | `election`, `seat`, `round`, `count`, `from_candidate`, `from_party`, `to_candidate`, `to_party`, `votes`, `excluded_total` |
| `ntec-nt-transfers.csv` | 542 | `election`, `seat`, `round`, `from`, `to`, `votes`, `to_n` |
| `ntec-nt-winners.csv` | 100 | `election`, `seat`, `winner` |
| `vec-2002-vic-tcp.csv` | 176 | `seat`, `party`, `votes` |
| `vec-2006-vic-candidates.csv` | 459 | `seat`, `candidate`, `party_code`, `party_name`, `fp`, `class` |
| `vec-2006-vic-checks.csv` | 88 | `seat`, `n_cand`, `n_rounds`, `fp_match`, `replay_vs_after_table`, `replay_vs_final_row`, `final_two`, `final_two_votes`, `max_abs_diff_vs_tcp_table`, `no_dist_ok` |
| `vec-2006-vic-firstprefs-detail.csv` | 459 | `seat`, `candidate`, `party_code`, `party_name`, `party_class`, `votes` |
| `vec-2006-vic-firstprefs.csv` | 415 | `seat`, `party`, `votes` |
| `vec-2006-vic-tcp-basis.csv` | 176 | `seat`, `party`, `votes`, `basis` |
| `vec-2006-vic-tcp-detail.csv` | 288 | `seat`, `source`, `candidate`, `party_code`, `party_name`, `party_class`, `votes` |
| `vec-2006-vic-tcp.csv` | 176 | `seat`, `party`, `votes` |
| `vec-2006-vic-transfers-detail.csv` | 956 | `election`, `seat`, `round`, `order_excluded`, `from_name`, `from_party`, `from`, `to_name`, `to_party`, `to`, `votes`, `row_total` |
| `vec-2006-vic-transfers.csv` | 524 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `vec-2010-vic-firstprefs.csv` | 414 | `seat`, `party`, `votes` |
| `vec-2010-vic-transfers.csv` | 625 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `vec-2010-vic-winners.csv` | 88 | `election`, `seat`, `winner`, `winner_name` |
| `vec-2014-vic-firstprefs.csv` | 430 | `seat`, `party`, `votes` |
| `vec-2014-vic-transfers.csv` | 856 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `vec-2014-vic-winners.csv` | 88 | `seat`, `winner` |
| `vec-2018-vic-firstprefs.csv` | 403 | `seat`, `party`, `votes` |
| `vec-2018-vic-transfers.csv` | 666 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `vec-2018-vic-winners.csv` | 88 | `seat`, `winner` |
| `vec-2022-vic-candidates.csv` | 731 | `seat`, `cand`, `party`, `party_raw`, `fp_votes` |
| `vec-2022-vic-firstprefs.csv` | 508 | `seat`, `party`, `votes` |
| `vec-2022-vic-transfers.csv` | 1,956 | `election`, `seat`, `round`, `from`, `to`, `votes`, `to_n` |
| `vec-2022-vic-winners.csv` | 88 | `seat`, `winner` |
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
| `nsw-district-regions.csv` | 93 | `district`, `region` |

### vec/

| file | rows | columns |
|---|---:|---|
| `vic-district-regions.csv` | 88 | `district`, `region` |

### ecsa/

| file | rows | columns |
|---|---:|---|
| `sa2022-districts.csv` | 47 | `seat`, `winner`, `runner_up`, `winner_2cp`, `alp_2pp`, `formal`, `fp_AFP`, `fp_AJP`, `fp_ALP`, `fp_FFP`, `fp_GRN`, `fp_IND`, `fp_LDP`, `fp_LIB`, `fp_NAT`, `fp_ONP`, `fp_RCH`, `fp_SAB` |
| `sa2026-2pp.csv` | 47 | `seat`, `alp_2pp_votes`, `lib_2pp_votes`, `alp_2pp` |
| `sa2026-districts.csv` | 47 | `seat`, `winner`, `runner_up`, `winner_2cp`, `alp_2pp`, `formal`, `fp_AFP`, `fp_AJP`, `fp_ALP`, `fp_FFP`, `fp_FGA`, `fp_GRN`, `fp_IND`, `fp_LCP`, `fp_LIB`, `fp_NAT`, `fp_ONP`, `fp_RCH`, `fp_SAB`, `fp_UVA` |
| `sa2026-seats.csv` | 47 | `seat`, `winner`, `runner`, `win_2cp`, `onp_fp` |

### ecq/

| file | rows | columns |
|---|---:|---|
| `ecq-2012-qld-firstprefs-kapfix.csv` | 390 | `seat`, `party`, `votes` |
| `ecq-qld-winners-2012-2015.csv` | 178 | `election`, `seat`, `winner` |

- **waec/** — no CSVs (see registry for other formats)
### polls/

| file | rows | columns |
|---|---:|---|
| `act-polls-handkeyed.csv` | 3 | `election`, `date`, `firm`, `alp`, `lib`, `grn`, `oth`, `source` |
| `archive/archive_vs_ae_pairs.csv` | 134 | `firm`, `arch_mid`, `arch_end`, `ae_date`, `ae_firm`, `dALP`, `dLNP`, `dGRN`, `arch_ALP`, `ae_ALP`, `arch_LNP`, `ae_LNP`, `arch_tpp`, `ae_tpp`, `gt1` |
| `archive/fed_archive_polls.csv` | 136 | `region`, `firm`, `fieldwork_start`, `fieldwork_end`, `ALP`, `LNP`, `GRN`, `ONP`, `DEM`, `FF`, `OTH`, `tpp_alp`, `sample`, `source` |
| `archive/morgan_rows.csv` | 98 | `label`, `phone`, `start`, `end`, `LNP`, `NAT`, `ALP`, `DEM`, `GRN`, `FF`, `ONP`, `OTH`, `tpp_alp_say`, `tpp_alp_2004` |
| `archive/newspoll_raw_rows.csv` | 156 | `start`, `end`, `file`, `LIB`, `NAT`, `LNP`, `ALP`, `GRN`, `OTH`, `tpp_lnp`, `tpp_alp` |
| `demosau/crosstabs.csv` | 991 | `poll_id`, `fieldwork_start`, `fieldwork_end`, `jurisdiction`, `sample_n`, `question`, `dimension`, `group`, `response`, `pct`, `source_url` |
| `demosau/mrp-seats.csv` | 150 | `release`, `fieldwork`, `state`, `division`, `fp_ALP`, `fp_LNP`, `fp_GRN`, `fp_ONP`, `fp_OTH`, `tcp_ALP`, `tcp_LNP`, `tcp_GRN`, `tcp_ONP`, `tcp_OTH`, `notional_leader`, `safety`, `win_ALP`, `win_LNP`, `win_GRN`, `win_ONP`, `win_OTH` |
| `newspoll-quarterly/breakdowns.csv` | 169 | `pollster`, `period_start`, `period_end`, `published`, `sample_n`, `dimension`, `group`, `party`, `fp`, `tpp_alp`, `source_url` |
| `pollbludger/bludgertrack_polls.csv` | 3,725 | `Id`, `start`, `end`, `median`, `pollster`, `mode`, `scope`, `sample`, `pmSAT`, `pmDIS`, `olSAT`, `olDIS`, `pmPREF`, `olPREF`, `ALP`, `LNC`, `GRN`, `PHON`, `UND`, `ALP2`, `LNC2`, `ALPra`, `LNCra`, `UNDra`, `cycle`, `section`, `file_stamp`, `ONP`, `start_date`, `end_date`, `median_date` |
| `pollbludger/days_manifest.csv` | 3,694 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7` |
| `pollbludger/llm-extracted/fed2004-p1-polls.csv` | 30 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2004-p2-polls.csv` | 22 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2004-scored.csv` | 36 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/fed2007-p1-polls.csv` | 29 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2007-p2-polls.csv` | 28 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2007-p3-polls.csv` | 17 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2007-p4-polls.csv` | 5 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2007-scored.csv` | 64 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/fed2010-p1-polls.csv` | 38 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2010-p2-polls.csv` | 89 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2010-p3-polls.csv` | 40 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2010-p4-polls.csv` | 52 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2010-p5-polls.csv` | 55 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2010-p6-polls.csv` | 43 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/fed2010-scored.csv` | 202 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/nsw2011-p1-polls.csv` | 15 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/nsw2011-p2-polls.csv` | 17 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/nsw2011-p3-polls.csv` | 8 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/nsw2011-scored.csv` | 35 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/nsw2015-p1-polls.csv` | 52 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/nsw2015-p2-polls.csv` | 0 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/nsw2015-scored.csv` | 49 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/nsw2019-polls.csv` | 32 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `shooters`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/nsw2019-scored.csv` | 32 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/nsw2023-polls.csv` | 25 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/nsw2023-scored.csv` | 23 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/qld2009-polls.csv` | 8 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/qld2012-polls.csv` | 26 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/qld2012-scored.csv` | 24 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/qld2015-p1-polls.csv` | 49 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/qld2015-p2-polls.csv` | 0 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/qld2015-scored.csv` | 44 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/qld2017-polls.csv` | 42 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/qld2017-scored.csv` | 41 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/qld2020-polls.csv` | 14 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/qld2020-scored.csv` | 14 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/qld2024-polls.csv` | 29 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/qld2024-scored.csv` | 21 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/sa2010-polls.csv` | 12 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/sa2010-scored.csv` | 11 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/sa2014-polls.csv` | 21 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/sa2014-scored.csv` | 16 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/sa2018-polls.csv` | 12 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/sa2018-scored.csv` | 8 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/sa2022-polls.csv` | 8 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/sa2022-scored.csv` | 8 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/vic2010-p1-polls.csv` | 10 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/vic2010-p2-polls.csv` | 23 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/vic2010-scored.csv` | 33 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/vic2014-polls.csv` | 54 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/vic2014-scored.csv` | 50 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/vic2018-polls.csv` | 31 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/vic2018-scored.csv` | 29 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/vic2022-polls.csv` | 30 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote` |
| `pollbludger/llm-extracted/vic2022-scored.csv` | 29 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/wa2005-polls.csv` | 8 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote`, `coalition` |
| `pollbludger/llm-extracted/wa2005-scored.csv` | 6 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/wa2005-wa-polls.csv` | 8 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote` |
| `pollbludger/llm-extracted/wa2008-p1-polls.csv` | 11 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote`, `coalition` |
| `pollbludger/llm-extracted/wa2008-p1-wa-polls.csv` | 11 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote` |
| `pollbludger/llm-extracted/wa2008-p2-polls.csv` | 2 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote`, `coalition` |
| `pollbludger/llm-extracted/wa2008-p2-wa-polls.csv` | 2 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote` |
| `pollbludger/llm-extracted/wa2008-scored.csv` | 11 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/wa2013-p1-polls.csv` | 10 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote`, `coalition` |
| `pollbludger/llm-extracted/wa2013-p1-wa-polls.csv` | 10 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote` |
| `pollbludger/llm-extracted/wa2013-p2-polls.csv` | 17 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote`, `coalition` |
| `pollbludger/llm-extracted/wa2013-p2-wa-polls.csv` | 17 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote` |
| `pollbludger/llm-extracted/wa2013-scored.csv` | 17 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/wa2017-polls.csv` | 32 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote`, `coalition` |
| `pollbludger/llm-extracted/wa2017-scored.csv` | 22 | `date`, `firm`, `origin`, `undecided_divided_out`, `ALP_x`, `ALP_k`, `LNP_x`, `LNP_k`, `GRN_x`, `GRN_k`, `maxd` |
| `pollbludger/llm-extracted/wa2017-wa-polls.csv` | 32 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `liberal`, `nationals`, `coalition_combined`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `lib_2pp`, `quote` |
| `pollbludger/pb_llm_polls.csv` | 1,040 | `post_id`, `post_date`, `pollster`, `fieldwork`, `sample`, `alp`, `coalition`, `greens`, `one_nation`, `others`, `undecided`, `alp_2pp`, `coalition_2pp`, `quote`, `malformed`, `src_file`, `shooters`, `liberal`, `nationals`, `coalition_combined`, `lib_2pp`, `cycle`, `region`, `alp_n`, `coalition_n`, `greens_n`, `one_nation_n`, `others_n`, `undecided_n`, `alp_2pp_n`, `coalition_2pp_n`, `sample_n`, `stated`, `dup` |
| `pollbludger/pollbludger_polls.csv` | 2,139 | `post_id`, `date`, `title`, `categories`, `region_cat`, `para`, `sent`, `firm_raw`, `scope`, `ALP`, `LNP`, `COA`, `QLNP`, `LIB`, `NAT`, `GRN`, `ONP`, `UAP`, `NXT`, `sample_n`, `tpp_text`, `sentence` |
| `pollbludger/post_index.csv` | 4,935 | `V1`, `V2`, `V3`, `V4`, `V5` |
| `pollbludger/posts.csv` | 72,378 | `post_id`, `url`, `title`, `posted`, `categories`, `text`, `day_file`, `date` |
| `seat-polls/hand_keyed_primaries.csv` | 9 | `election`, `seat`, `pollster`, `client`, `fieldwork_start`, `fieldwork_end`, `date_raw`, `published`, `sample_n`, `party`, `fp`, `tcp_party_a`, `tcp_party_b`, `tcp_a`, `source_url`, `row_type`, `seat_name`, `source` |
| `seat-polls/mrp_candidates.csv` | 122 | `election`, `pollster`, `release_date`, `seat`, `label_in_file`, `named_candidate`, `modelled`, `method_note`, `source_url`, `source_date` |
| `seat-polls/poll_methods.csv` | 1,210 | `election`, `seat`, `pollster`, `fieldwork_end`, `sample_n`, `pollster_clean`, `method`, `sponsor_type`, `sponsor_name`, `evidence`, `evidence_url`, `confidence`, `sponsor_confidence` |
| `seat-polls/seat_poll_corrections.csv` | 3 | `election`, `seat_name`, `pollster`, `fieldwork_end`, `party`, `fp_wrong`, `fp_right`, `source`, `note` |
| `seat-polls/seat_polls.csv` | 7,244 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16`, `V17` |
| `state-federal/state-federal-polls.csv` | 1,095 | `election`, `pollster`, `fieldwork_start`, `fieldwork_end`, `scope`, `state`, `seat`, `sample_n`, `alp_tpp`, `alp_fp`, `lnp_fp`, `grn_fp`, `oth_fp`, `source_url`, `verified`, `extra_fp` |
| `state-regional-splits/regional_splits.csv` | 266 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13` |
| `statewide-samples/election_dates.csv` | 70 | `V1`, `V2`, `V3`, `V4` |
| `statewide-samples/firm_alias.csv` | 30 | `pattern`, `canonical`, `note` |
| `statewide-samples/pages_manifest.csv` | 140 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11` |
| `statewide-samples/pollbludger_polls.csv` | 102 | `election`, `region`, `row_type`, `date`, `POLLSTER`, `alp_fp`, `lnp_fp`, `grn_fp`, `alp_tpp`, `lnp_tpp`, `DATE`, `LNPtrend`, `ALPtrend`, `GRNtrend`, `LNP2trend`, `ALP2trend`, `source_url` |
| `statewide-samples/raw/pollbludger_nsw2019_sheet_gid0.csv` | 49 | `DATE`, `POLLSTER`, `LNP`, `ALP`, `GRN`, `LNP2`, `ALP2`, `LNPtrend`, `ALPtrend`, `GRNtrend`, `LNP2trend`, `ALP2trend` |
| `statewide-samples/raw/pollbludger_vic2018_sheet_gid0.csv` | 53 | `DATE`, `POLLSTER`, `ALP`, `LNP`, `GRN`, `ALP2`, `LNP2`, `ALPtrend`, `LNPtrend`, `GRNtrend`, `ALP2trend`, `LNP2trend` |
| `statewide-samples/statewide_polls_wiki.csv` | 5,694 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16`, `V17`, `V18`, `V19`, `V20`, `V21`, `V22`, `V23`, `V24`, `V25`, `V26`, `V27`, `V28`, `V29`, `V30`, `V31`, `V32`, `V33`, `V34`, `V35`, `V36`, `V37`, `V38`, `V39`, `V40`, `V41`, `V42`, `V43`, `V44`, `V45`, `V46`, `V47`, `V48`, `V49`, `V50`, `V51`, `V52`, `V53`, `V54`, `V55`, `V56`, `V57`, `V58`, `V59`, `V60`, `V61`, `V62`, `V63`, `V64`, `V65`, `V66`, `V67`, `V68`, `V69`, `V70`, `V71`, `V72`, `V73`, `V74`, `V75`, `V76`, `V77`, `V78`, `V79`, `V80`, `V81`, `V82`, `V83`, `V84`, `V85`, `V86`, `V87`, `V88`, `V89`, `V90`, `V91`, `V92`, `V93`, `V94`, `V95`, `V96`, `V97`, `V98`, `V99`, `V100`, `V101`, `V102`, `V103`, `V104`, `V105`, `V106`, `V107`, `V108`, `V109`, `V110`, `V111`, `V112`, `V113`, `V114`, `V115`, `V116`, `V117`, `V118`, `V119`, `V120`, `V121`, `V122`, `V123`, `V124`, `V125`, `V126`, `V127`, `V128`, `V129`, `V130`, `V131`, `V132`, `V133`, `V134`, `V135`, `V136`, `V137`, `V138`, `V139`, `V140`, `V141`, `V142`, `V143`, `V144`, `V145`, `V146`, `V147`, `V148`, `V149`, `V150`, `V151`, `V152`, `V153`, `V154`, `V155`, `V156`, `V157`, `V158`, `V159`, `V160`, `V161`, `V162`, `V163`, `V164`, `V165`, `V166`, `V167`, `V168`, `V169`, `V170`, `V171`, `V172`, `V173`, `V174`, `V175`, `V176`, `V177`, `V178`, `V179`, `V180`, `V181`, `V182`, `V183`, `V184`, `V185`, `V186`, `V187`, `V188`, `V189`, `V190`, `V191`, `V192`, `V193`, `V194`, `V195`, `V196`, `V197`, `V198`, `V199`, `V200`, `V201`, `V202`, `V203`, `V204`, `V205`, `V206`, `V207`, `V208`, `V209`, `V210`, `V211`, `V212`, `V213`, `V214`, `V215`, `V216`, `V217`, `V218`, `V219`, `V220`, `V221`, `V222`, `V223`, `V224`, `V225`, `V226`, `V227`, `V228`, `V229`, `V230`, `V231`, `V232`, `V233`, `V234`, `V235`, `V236`, `V237`, `V238`, `V239`, `V240`, `V241`, `V242`, `V243`, `V244`, `V245`, `V246`, `V247`, `V248`, `V249`, `V250`, `V251`, `V252`, `V253`, `V254`, `V255`, `V256`, `V257`, `V258`, `V259`, `V260`, `V261`, `V262`, `V263`, `V264`, `V265`, `V266`, `V267`, `V268`, `V269`, `V270`, `V271`, `V272`, `V273`, `V274`, `V275`, `V276`, `V277`, `V278`, `V279`, `V280`, `V281`, `V282`, `V283`, `V284`, `V285`, `V286`, `V287`, `V288`, `V289`, `V290`, `V291`, `V292`, `V293`, `V294`, `V295`, `V296`, `V297`, `V298`, `V299`, `V300`, `V301`, `V302`, `V303`, `V304`, `V305`, `V306`, `V307`, `V308`, `V309`, `V310`, `V311`, `V312`, `V313`, `V314`, `V315`, `V316`, `V317`, `V318`, `V319`, `V320`, `V321`, `V322`, `V323`, `V324`, `V325`, `V326`, `V327`, `V328`, `V329`, `V330`, `V331`, `V332`, `V333`, `V334`, `V335`, `V336`, `V337`, `V338`, `V339`, `V340`, `V341`, `V342`, `V343`, `V344`, `V345`, `V346`, `V347`, `V348`, `V349`, `V350`, `V351`, `V352`, `V353`, `V354`, `V355`, `V356`, `V357`, `V358`, `V359`, `V360`, `V361`, `V362`, `V363`, `V364`, `V365`, `V366`, `V367`, `V368`, `V369`, `V370`, `V371`, `V372`, `V373`, `V374`, `V375`, `V376`, `V377`, `V378`, `V379`, `V380`, `V381`, `V382`, `V383`, `V384`, `V385`, `V386`, `V387`, `V388`, `V389`, `V390`, `V391`, `V392`, `V393`, `V394`, `V395`, `V396`, `V397`, `V398`, `V399`, `V400`, `V401`, `V402`, `V403`, `V404`, `V405`, `V406`, `V407`, `V408`, `V409`, `V410`, `V411`, `V412`, `V413`, `V414`, `V415`, `V416`, `V417`, `V418`, `V419`, `V420`, `V421`, `V422`, `V423`, `V424`, `V425`, `V426`, `V427`, `V428`, `V429`, `V430`, `V431`, `V432`, `V433`, `V434`, `V435`, `V436`, `V437`, `V438`, `V439`, `V440`, `V441`, `V442`, `V443`, `V444`, `V445`, `V446`, `V447`, `V448`, `V449`, `V450`, `V451`, `V452`, `V453`, `V454`, `V455`, `V456`, `V457`, `V458`, `V459`, `V460`, `V461`, `V462`, `V463`, `V464`, `V465`, `V466`, `V467`, `V468`, `V469`, `V470`, `V471`, `V472`, `V473`, `V474`, `V475`, `V476`, `V477`, `V478`, `V479`, `V480`, `V481`, `V482`, `V483`, `V484`, `V485`, `V486`, `V487`, `V488`, `V489`, `V490`, `V491`, `V492`, `V493`, `V494`, `V495`, `V496`, `V497`, `V498`, `V499`, `V500`, `V501`, `V502`, `V503`, `V504`, `V505`, `V506`, `V507`, `V508`, `V509`, `V510`, `V511`, `V512`, `V513`, `V514`, `V515`, `V516`, `V517`, `V518`, `V519`, `V520`, `V521`, `V522`, `V523`, `V524`, `V525`, `V526`, `V527`, `V528`, `V529`, `V530`, `V531`, `V532`, `V533`, `V534`, `V535`, `V536`, `V537`, `V538`, `V539`, `V540`, `V541`, `V542`, `V543`, `V544`, `V545`, `V546`, `V547`, `V548`, `V549`, `V550`, `V551`, `V552`, `V553`, `V554`, `V555`, `V556`, `V557`, `V558`, `V559`, `V560`, `V561`, `V562`, `V563`, `V564`, `V565`, `V566`, `V567`, `V568`, `V569`, `V570`, `V571`, `V572`, `V573`, `V574`, `V575`, `V576`, `V577`, `V578`, `V579`, `V580`, `V581` |
| `statewide-samples/table_outcomes.csv` | 703 | `page_key`, `table_idx`, `outcome`, `detail` |

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

1041 files in 562 families (names differing only by numbers are one family, N; rows and columns are its first file's).

| file (family) | files | rows | columns |
|---|---:|---:|---|
| `_prefix-shipped-oof-BACKUP.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `abc-scrape-primary.csv` | 1 | 5,720 | `party`, `name`, `pct`, `votes`, `pair`, `seat_slug` |
| `abc-scrape-tcp.csv` | 1 | 1,362 | `party`, `name`, `pct`, `votes`, `pair`, `seat_slug` |
| `ae-dependence-audit.csv` | 1 | 25 | `election`, `polls`, `ours`, `ae_filled`, `dispute`, `suspect`, `no_wiki`, `missing`, `label_ae`, `f30_polls`, `f30_ours`, `f30_ae_filled`, `f30_dispute`, `f30_suspect`, `f30_no_wiki`, `f30_missing`, `f30_label_ae`, `ae_share`, `f30_ae_share` |
| `ae-missing-split.csv` | 1 | 935 | `election`, `date`, `firm`, `ALP`, `LNP`, `final30`, `reason` |
| `aec-tpp-flows.csv` | 1 | 989 | `year`, `state`, `party_ab`, `party_name`, `party_class`, `row_type`, `alp_votes`, `lnp_votes`, `flow_alp`, `event`, `alp_pct_published`, `lnp_pct_published`, `source_file`, `file_header`, `n_states` |
| `aef-comparison-full.csv` | 1 | 681 | `seat`, `actual`, `our_pred`, `our_p`, `seeds`, `aef_pred`, `aef_p`, `aef_p_fav`, `delta`, `our_primary`, `actual_primary`, `aef_primary`, `pair`, `our_pe`, `aef_pe`, `prim_gap`, `why` |
| `aef-primary-all.csv` | 1 | 3,671 | `seat`, `party`, `aef_pcv`, `election` |
| `aef-seat-party-probs.csv` | 1 | 3,697 | `election`, `seat`, `party`, `aef_p_win` |
| `aef-seat-scores.csv` | 1 | 728 | `election`, `seat`, `actual`, `pred`, `pred_p`, `prob`, `tpp_actual` |
| `aef-worst-seats-full.csv` | 1 | 659 | `seat`, `actual`, `our_pred`, `our_p`, `aef_pred`, `aef_p`, `delta`, `our_primary_actual`, `actual_primary`, `aef_primary_actual`, `pair` |
| `aefN-artifact-current.csv` | 1 | 660 | `pair`, `seat`, `winner`, `fav`, `correct`, `our_p_win`, `our_p_fav`, `aef_p_win`, `aef_p_fav`, `our_fp_win`, `aef_fp_win`, `act_fp_win`, `miss`, `ll`, `aef_ll`, `grp`, `f1`, `f2`, `f2cp`, `fsrc`, `our_fp_fav`, `aef_fp_fav`, `act_fp_fav` |
| `aefN-artifact-refreshed.csv` | 1 | 660 | `pair`, `seat`, `winner`, `fav`, `correct`, `our_p_win`, `our_p_fav`, `aef_p_win`, `aef_p_fav`, `our_fp_win`, `aef_fp_win`, `act_fp_win`, `miss`, `ll`, `aef_ll`, `grp`, `f1`, `f2`, `f2cp`, `fsrc`, `our_fp_fav`, `aef_fp_fav`, `act_fp_fav` |
| `aefN-final-two-and-tcp-reference.csv` | 1 | 660 | `pair`, `seat`, `f1`, `f2`, `f2cp`, `fsrc`, `aef_tcp_f1`, `aef_tcp_f2`, `aef_tcp_pct`, `aef_tcp_scenario_freq`, `aef_tcp_p05`, `aef_tcp_p95` |
| `aefN-final-two-derived.csv` | 1 | 347 | `election`, `seat`, `f1`, `f2`, `f2cp`, `rule` |
| `aefN-fp.csv` | 1 | 4,448 | `pair`, `seat`, `aef_fp_party_idx`, `aef_fp_class`, `aef_fp_pct`, `aef_fp_p05`, `aef_fp_p95` |
| `aefN-fptrend.csv` | 1 | 3,671 | `seat`, `party`, `aef_fp_pred`, `pair` |
| `aefN-primary-common.csv` | 1 | 2,700 | `pair`, `seat`, `cl`, `ours`, `aef`, `actual` |
| `aefN-primary-truth-table.csv` | 1 | 4,620 | `pair`, `seat`, `party`, `itg_primary`, `official_primary`, `aef_primary`, `abc_primary` |
| `aefN-seat-groups.csv` | 1 | 34 | `pair`, `seat`, `grp` |
| `aefN-tcp-actual.csv` | 1 | 660 | `pair`, `seat`, `f1`, `f2`, `f2cp`, `our_tcp_actual_freq`, `our_tcp_pred_pct`, `our_tcp_actual_share`, `our_tcp_pick`, `our_tcp_pick_pct`, `aef_tcp_actual_freq`, `aef_tcp_pred_pct`, `aef_tcp_actual_share`, `aef_tcp_pick`, `aef_tcp_pick_pct` |
| `aefN-tcp-truth-table.csv` | 1 | 660 | `pair`, `seat`, `official_f1`, `official_f2`, `official_f2cp`, `official_fsrc`, `aef_tcp_f1`, `aef_tcp_pct`, `aef_tcp_freq`, `itg_tcp_f1`, `itg_tcp_f2`, `itg_tcp_pct`, `itg_tcp_freq`, `abc_tcp_f1`, `abc_tcp_f2`, `abc_tcp_pct` |
| `aefN-tcp.csv` | 1 | 681 | `pair`, `seat`, `aef_tcp_f1`, `aef_tcp_f2`, `aef_tcp_pct`, `aef_tcp_scenario_freq`, `aef_tcp_p05`, `aef_tcp_p95` |
| `anchor-k.csv` | 1 | 834 | `region`, `year`, `K`, `party`, `fitted`, `actual`, `prior`, `polls30`, `err`, `cyc` |
| `biggest-misses.csv` | 1 | 74 | `metric`, `pair`, `seat`, `party`, `candidate`, `ours`, `actual`, `err` |
| `bludgertrack-vs-layered.csv` | 1 | 541 | `region`, `bt_id`, `bt_cycle`, `date`, `firm`, `pollster_bt`, `mode_bt`, `sample_bt`, `source`, `und_bt`, `ALP_bt`, `ALP_layered`, `LNP_bt`, `LNP_layered`, `GRN_bt`, `GRN_layered`, `ONP_bt`, `ONP_layered`, `ALP_d`, `LNP_d`, `GRN_d`, `ONP_d` |
| `booth-rehearsalN-vicN.csv` | 1 | 15 | `frac_of_night_vote`, `estimator`, `leader_correct`, `n`, `major_mae`, `major_rmse` |
| `booth-replay-vicN.csv` | 1 | 5 | `frac_of_night_vote`, `mean_counted_share_of_all`, `fp_leader_correct`, `n`, `major_share_mae`, `major_share_rmse` |
| `booths-vicN-Ncp.csv` | 2 | 4,820 | `district`, `booth`, `booth_type`, `candidate`, `party`, `votes` |
| `booths-vicN.csv` | 2 | 13,353 | `district`, `booth`, `booth_type`, `candidate`, `party`, `votes` |
| `bucket-total-history.csv` | 1 | 20 | `pair`, `cand_total`, `poll_total`, `actual`, `date` |
| `cN-widened-population.csv` | 1 | 4,168 | `election`, `region`, `seat`, `name`, `party`, `pcv`, `elected`, `own_prev_pcv`, `base`, `gated`, `xp`, `emergence` |
| `cal-fed-mN.csv` | 4 | 886 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-nsw-mN.csv` | 4 | 88 | `seat`, `p`, `pred`, `pred_p`, `actual`, `bin` |
| `cal-sa-mN.csv` | 4 | 47 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `cal-vic-mN.csv` | 4 | 166 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `calibration-arms.csv` | 1 | 10 | `pair`, `n`, `mult`, `logB`, `acc`, `T`, `logA`, `logC`, `B_vs_A`, `B_vs_C` |
| `candidacies.csv` | 1 | 22,358 | `election`, `region`, `year`, `seat`, `name`, `surname`, `given`, `party`, `party_raw`, `party_ab`, `state`, `votes`, `pcv`, `elected`, `historic_elected`, `breakout`, `swing`, `ballot_position`, `ordinary`, `absent`, `provisional`, `prepoll`, `postal`, `ballot_order`, `tot`, `source`, `party_conflict`, `class_rule`, `party_alt` |
| `candidate-contests.csv` | 1 | 14,953 | `election`, `region`, `party`, `candidate_id`, `seat`, `pcv`, `surname`, `given`, `expected_pcv`, `performance_vs_expected` |
| `candidate-ids.csv` | 1 | 10,763 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12` |
| `candidate-review.csv` | 1 | 190 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15` |
| `census-features-vintage-newpairs.csv` | 1 | 673 | `pair`, `seat`, `vintage`, `exact`, `yr12_pct`, `born_aus_pct`, `indig_pct`, `over55_pct`, `under35_pct`, `lang_other_pct`, `edu_25plus_pct`, `vintage_note` |
| `census-features-vintage.csv` | 1 | 3,226 | `pair`, `seat`, `vintage`, `exact`, `yr12_pct`, `born_aus_pct`, `indig_pct`, `over55_pct`, `under35_pct`, `lang_other_pct`, `edu_25plus_pct`, `vintage_note` |
| `census-features.csv` | 1 | 3,226 | `pair`, `seat`, `vintage`, `exact`, `yr12_pct`, `born_aus_pct`, `indig_pct`, `over55_pct`, `under35_pct`, `lang_other_pct`, `edu_25plus_pct`, `vintage_note` |
| `coalition-split-events.csv` | 1 | 985 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `council-history-nswN.csv` | 1 | 193 | `election`, `seat`, `name`, `party`, `council_coverage`, `council_any`, `council_elected`, `council_mayor`, `council_pct`, `council_year`, `council_name`, `n_council_runs` |
| `council-history-vicN.csv` | 1 | 500 | `election`, `seat`, `name`, `party`, `council_coverage`, `council_any`, `council_elected`, `council_mayor`, `council_pct`, `council_year`, `council_name`, `n_council_runs` |
| `council-history.csv` | 1 | 21,966 | `election`, `seat`, `name`, `party`, `council_coverage`, `council_any`, `council_elected`, `council_mayor`, `council_pct`, `council_year`, `council_name`, `n_council_runs` |
| `council-results-nsw.csv` | 1 | 20,405 | `year`, `council`, `ward`, `contest`, `vacancies`, `candidate`, `surname`, `given`, `first_pref_votes`, `first_pref_pct`, `ward_formal_votes`, `ward_enrolment`, `elected`, `contested`, `source_file` |
| `council-results-qld.csv` | 1 | 6,314 | `year`, `council`, `ward`, `contest`, `vacancies`, `candidate`, `surname`, `given`, `first_pref_votes`, `first_pref_pct`, `ward_formal_votes`, `ward_enrolment`, `elected`, `contested`, `source_file` |
| `council-results-sa.csv` | 1 | 2,630 | `year`, `council`, `ward`, `contest`, `vacancies`, `candidate`, `surname`, `given`, `first_pref_votes`, `first_pref_pct`, `ward_formal_votes`, `ward_enrolment`, `elected`, `contested`, `source_file` |
| `council-results-vic.csv` | 1 | 9,957 | `year`, `council`, `ward`, `vacancies`, `candidate`, `surname`, `given`, `first_pref_votes`, `first_pref_pct`, `ward_formal_votes`, `ward_enrolment`, `elected`, `contested`, `source_file` |
| `council-results-wa.csv` | 1 | 8,667 | `year`, `council`, `ward`, `contest`, `vacancies`, `candidate`, `surname`, `given`, `first_pref_votes`, `first_pref_pct`, `ward_formal_votes`, `ward_enrolment`, `elected`, `contested`, `source_file` |
| `cross-party-swing.csv` | 1 | 1,508 | `cycle`, `region`, `seat`, `party`, `y`, `x`, `own_base`, `pred_uniform`, `pred_cross` |
| `cycle-walks-fed.csv` | 1 | 17 | `year`, `party`, `n`, `own_weight`, `obs_pooled`, `obs_cycle`, `rw_pooled_pts`, `rw_cycle_pts`, `at_lower`, `at_upper`, `conv`, `acf1`, `speedup` |
| `cycle-walks-nsw.csv` | 1 | 9 | `year`, `party`, `n`, `own_weight`, `cycle_level`, `obs_pts`, `rw_pooled`, `rw_cycle`, `floor_ref`, `at_lower`, `at_upper`, `acf1` |
| `cycle-walks-vic.csv` | 1 | 13 | `year`, `party`, `n`, `own_weight`, `cycle_level`, `obs_pts`, `rw_pts`, `floor_ref`, `at_upper`, `floored`, `acf1` |
| `defector-cases-all.csv` | 1 | 29 | `pair`, `seat`, `name`, `was_mp`, `prior`, `now`, `newparty`, `ret` |
| `defector-holders.csv` | 1 | 52 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16`, `V17`, `V18`, `V19`, `V20`, `V21`, `V22`, `V23`, `V24`, `V25`, `V26`, `V27`, `V28`, `V29`, `V30` |
| `defector-overcarry.csv` | 1 | 52 | `election`, `.s`, `old_party`, `new_party`, `seat`, `name`, `was_mp`, `prior`, `now`, `pred`, `base`, `act`, `n_in_class`, `old_pred`, `old_act`, `over`, `over_base`, `old_over` |
| `defector-retention-cases.csv` | 1 | 14 | `pair`, `seat`, `prev_party`, `own_prev_pcv`, `party`, `target_pcv`, `target_name`, `retention` |
| `demo-resid-nswN.csv` | 1 | 186 | `seat`, `class`, `adj` |
| `demo-resid-vicN.csv` | 1 | 176 | `seat`, `class`, `adj` |
| `demographic-swing-loo.csv` | 1 | 12 | `party`, `pair`, `n`, `mae_uniform`, `mae_demog`, `improvement` |
| `departed-ind-successors.csv` | 1 | 85 | `election`, `prev_election`, `seat`, `departed`, `departed_pcv`, `departed_elected`, `prior_ind_total`, `successor`, `successor_pcv`, `n_ind_now`, `ind_total_now`, `retention`, `scored` |
| `departed-leader-cases.csv` | 1 | 550 | `election`, `seat`, `cls`, `prev_pct`, `now_pct`, `same_person`, `prev_won`, `reg` |
| `departed-rate-by-target.csv` | 1 | 30 | `target`, `n_hist`, `k_hist`, `rate`, `se`, `fallback` |
| `departed-sitting-fits.csv` | 1 | 30 | `target`, `n_hist`, `k_hist`, `fallback`, `mu`, `tau2`, `est_sitting`, `est_not_sitting`, `se_sitting`, `se_not_sitting`, `n_sitting`, `n_not_sitting`, `w_sitting`, `w_not_sitting`, `rate_sitting`, `rate_not_sitting` |
| `departed-sitting-rates.csv` | 1 | 78 | `target`, `seat`, `group`, `rate`, `fallback` |
| `departed-successor-fits.csv` | 1 | 44 | `target`, `n_hist`, `k_hist`, `fallback`, `mu`, `tau2`, `est_strong`, `est_weak`, `se_strong`, `se_weak`, `n_strong`, `n_weak`, `w_strong`, `w_weak`, `rate_strong`, `rate_weak` |
| `departed-successor-rates.csv` | 1 | 71 | `target`, `seat`, `group`, `rate`, `fallback` |
| `departure-cases-narrow.csv` | 1 | 89 | `seat`, `party`, `same`, `same_mp`, `prior_leader_returns`, `prior_leader_pcv`, `now_class_pcv`, `pair` |
| `departure-cases.csv` | 1 | 2,481 | `seat`, `party`, `same`, `same_mp`, `prior_leader_returns`, `prior_leader_pcv`, `pair` |
| `dev-slopes-heldout.csv` | 1 | 42 | `party`, `slope`, `se`, `n`, `pairs`, `held_out`, `t_vs_1` |
| `diag-flow-regressions.csv` | 1 | 204 | `pair`, `seat`, `actual`, `ll_p1f0`, `ll_p1f1`, `p_p1f0`, `p_p1f1`, `pred_p1f0`, `pred_p1f1`, `d_ll` |
| `dispersion-slope-paired-compare.csv` | 1 | 15 | `pair`, `n`, `base_ll`, `arm_ll`, `delta_ll`, `base_brier`, `arm_brier`, `base_acc`, `arm_acc` |
| `dump-shares-blended-fedN.csv` | 2 | 1,050 | `seat`, `party`, `projected_share`, `election` |
| `dump-shares-fedN.csv` | 2 | 1,050 | `seat`, `party`, `projected_share`, `election` |
| `dump-shares-fedN-baseline.csv` | 1 | 1,043 | `seat`, `party`, `projected_share`, `election` |
| `emergence-cases-vN.csv` | 1 | 9,974 | `pair`, `seat`, `party`, `name`, `pk`, `own_prev`, `cls_prev`, `pcv`, `rise`, `stood_before`, `emerged`, `elected`, `ballot_position` |
| `emergence-cases.csv` | 1 | 214 | `pair`, `seat`, `party`, `prev_share`, `actual_share`, `pred_share`, `jump`, `we_missed_by`, `won`, `winner` |
| `emergence-census-vN.csv` | 1 | 66 | `election`, `seat`, `name`, `party`, `pcv`, `own_prev_pcv`, `prev_winner`, `gated`, `new_person`, `emergence` |
| `emergence-test.csv` | 1 | 55 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16` |
| `emergence-trends.csv` | 1 | 53 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16`, `V17`, `V18` |
| `endorsement-features.csv` | 1 | 77 | `pair`, `seat`, `party`, `c200`, `voices` |
| `error-quantiles-comp.csv` | 1 | 210 | `target`, `class`, `n`, `w`, `n_pairs`, `q000`, `q001`, `q002`, `q003`, `q004`, `q005`, `q006`, `q007`, `q008`, `q009`, `q010`, `q011`, `q012`, `q013`, `q014`, `q015`, `q016`, `q017`, `q018`, `q019`, `q020`, `q021`, `q022`, `q023`, `q024`, `q025`, `q026`, `q027`, `q028`, `q029`, `q030`, `q031`, `q032`, `q033`, `q034`, `q035`, `q036`, `q037`, `q038`, `q039`, `q040`, `q041`, `q042`, `q043`, `q044`, `q045`, `q046`, `q047`, `q048`, `q049`, `q050`, `q051`, `q052`, `q053`, `q054`, `q055`, `q056`, `q057`, `q058`, `q059`, `q060`, `q061`, `q062`, `q063`, `q064`, `q065`, `q066`, `q067`, `q068`, `q069`, `q070`, `q071`, `q072`, `q073`, `q074`, `q075`, `q076`, `q077`, `q078`, `q079`, `q080`, `q081`, `q082`, `q083`, `q084`, `q085`, `q086`, `q087`, `q088`, `q089`, `q090`, `q091`, `q092`, `q093`, `q094`, `q095`, `q096`, `q097`, `q098`, `q099`, `q100`, `q101`, `q102`, `q103`, `q104`, `q105`, `q106`, `q107`, `q108`, `q109`, `q110`, `q111`, `q112`, `q113`, `q114`, `q115`, `q116`, `q117`, `q118`, `q119`, `q120`, `q121`, `q122`, `q123`, `q124`, `q125`, `q126`, `q127`, `q128`, `q129`, `q130`, `q131`, `q132`, `q133`, `q134`, `q135`, `q136`, `q137`, `q138`, `q139`, `q140`, `q141`, `q142`, `q143`, `q144`, `q145`, `q146`, `q147`, `q148`, `q149`, `q150`, `q151`, `q152`, `q153`, `q154`, `q155`, `q156`, `q157`, `q158`, `q159`, `q160`, `q161`, `q162`, `q163`, `q164`, `q165`, `q166`, `q167`, `q168`, `q169`, `q170`, `q171`, `q172`, `q173`, `q174`, `q175`, `q176`, `q177`, `q178`, `q179`, `q180`, `q181`, `q182`, `q183`, `q184`, `q185`, `q186`, `q187`, `q188`, `q189`, `q190`, `q191`, `q192`, `q193`, `q194`, `q195`, `q196`, `q197`, `q198`, `q199`, `q200` |
| `error-quantiles.csv` | 1 | 210 | `target`, `class`, `n`, `w`, `n_pairs`, `q000`, `q001`, `q002`, `q003`, `q004`, `q005`, `q006`, `q007`, `q008`, `q009`, `q010`, `q011`, `q012`, `q013`, `q014`, `q015`, `q016`, `q017`, `q018`, `q019`, `q020`, `q021`, `q022`, `q023`, `q024`, `q025`, `q026`, `q027`, `q028`, `q029`, `q030`, `q031`, `q032`, `q033`, `q034`, `q035`, `q036`, `q037`, `q038`, `q039`, `q040`, `q041`, `q042`, `q043`, `q044`, `q045`, `q046`, `q047`, `q048`, `q049`, `q050`, `q051`, `q052`, `q053`, `q054`, `q055`, `q056`, `q057`, `q058`, `q059`, `q060`, `q061`, `q062`, `q063`, `q064`, `q065`, `q066`, `q067`, `q068`, `q069`, `q070`, `q071`, `q072`, `q073`, `q074`, `q075`, `q076`, `q077`, `q078`, `q079`, `q080`, `q081`, `q082`, `q083`, `q084`, `q085`, `q086`, `q087`, `q088`, `q089`, `q090`, `q091`, `q092`, `q093`, `q094`, `q095`, `q096`, `q097`, `q098`, `q099`, `q100`, `q101`, `q102`, `q103`, `q104`, `q105`, `q106`, `q107`, `q108`, `q109`, `q110`, `q111`, `q112`, `q113`, `q114`, `q115`, `q116`, `q117`, `q118`, `q119`, `q120`, `q121`, `q122`, `q123`, `q124`, `q125`, `q126`, `q127`, `q128`, `q129`, `q130`, `q131`, `q132`, `q133`, `q134`, `q135`, `q136`, `q137`, `q138`, `q139`, `q140`, `q141`, `q142`, `q143`, `q144`, `q145`, `q146`, `q147`, `q148`, `q149`, `q150`, `q151`, `q152`, `q153`, `q154`, `q155`, `q156`, `q157`, `q158`, `q159`, `q160`, `q161`, `q162`, `q163`, `q164`, `q165`, `q166`, `q167`, `q168`, `q169`, `q170`, `q171`, `q172`, `q173`, `q174`, `q175`, `q176`, `q177`, `q178`, `q179`, `q180`, `q181`, `q182`, `q183`, `q184`, `q185`, `q186`, `q187`, `q188`, `q189`, `q190`, `q191`, `q192`, `q193`, `q194`, `q195`, `q196`, `q197`, `q198`, `q199`, `q200` |
| `fed-insurgency-risk.csv` | 1 | 886 | `pair`, `seat`, `nm_best`, `nm_held`, `risk_loeo`, `shrink_i`, `nm_win` |
| `fed-insurgency-surge.csv` | 1 | 886 | `pair`, `seat`, `nm_party`, `nm_from`, `nm_held`, `q_loeo`, `gain`, `surge` |
| `fed-state-breakdowns.csv` | 1 | 471 | `st`, `date`, `firm`, `end`, `ALP`, `LNP`, `GRN` |
| `fed-swing-coef-refit.csv` | 1 | 2 | `election`, `n`, `mae_A`, `mae_B`, `mae_C` |
| `fed-swing-gain-by-gap.csv` | 1 | 5 | `election`, `n`, `mae`, `uniform`, `gap_months`, `fed`, `gain` |
| `fed-upset-features.csv` | 1 | 886 | `seat`, `nm_prior`, `nm_best`, `n_parties`, `top1`, `top2`, `margin_prior`, `prev_winner`, `nm_held`, `won_by`, `nm_win`, `pair` |
| `fedN-browse-table.csv` | 1 | 1,122 | `seat`, `party`, `name`, `given`, `surname`, `actual_pcv`, `elected`, `projected_share`, `aef_primary_median`, `own_prev_pcv`, `own_prev_party`, `class_prev_pcv`, `party_national_prev`, `party_national_now`, `salience_pctile`, `salience_jump`, `seat_salience`, `seat_salience_basis`, `election_salience`, `actual_winner_party`, `actual_winner_name`, `our_pred_party`, `our_prob_on_actual`, `our_ll` |
| `federal-pairs.csv` | 1 | 886 | `seat`, `IND_prev`, `OTH_prev`, `OTHR_prev`, `ALP_prev`, `LNP_prev`, `IND_now`, `prev_winner`, `pair`, `target`, `other_nonmajor_prev`, `ind_prev`, `abs_margin`, `coalition_held`, `sitting` |
| `firm-factors-fed.csv` | 1 | 16 | `firm`, `n`, `raw_ratio`, `factor` |
| `firm-factors-nsw.csv` | 1 | 14 | `firm`, `n`, `raw_ratio`, `factor` |
| `firm-factors-vic.csv` | 1 | 14 | `firm`, `n`, `raw_ratio`, `factor` |
| `fit-seats-timing-nsw-N.csv` | 1 | 13 | `stage`, `secs`, `pct` |
| `fit-seats-timing-vic-N.csv` | 1 | 13 | `stage`, `secs`, `pct` |
| `flow-audit-fedN.csv` | 1 | 2,606 | `from`, `surv`, `to`, `seat`, `round`, `votes`, `tot`, `actual`, `pred`, `src`, `err`, `wt` |
| `flow-drift-vN-oof.csv` | 1 | 3,711 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9` |
| `flow-oracle-score.csv` | 1 | 88 | `pair`, `config`, `event_err`, `events`, `winners_right`, `seats`, `override` |
| `flows-estimated.csv` | 1 | 200 | `election`, `region`, `year`, `party`, `flow_alp`, `exhaust`, `se_flow`, `se_exhaust`, `n_seats`, `prior_source`, `pool_weight`, `answer_key_available` |
| `flows-key-table.csv` | 1 | 135 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8` |
| `flows-state-blend.csv` | 1 | 75 | `election`, `region`, `year`, `party`, `flow_alp`, `exhaust`, `se_flow`, `se_exhaust`, `w`, `n_prior_keys`, `borrow_source`, `source` |
| `forecasts-seats.csv` | 1 | 11,137 | `election`, `seat`, `party`, `win_prob`, `actual_winner`, `is_winner`, `source_file`, `source_mtime`, `election_date` |
| `forecasts.csv` | 1 | 17,010 | `election`, `election_date`, `region`, `seat`, `party`, `candidate`, `n_candidates`, `base_pred`, `xgb_pred`, `xgb_pred_seat`, `actual_share`, `err_base`, `err_xgb`, `model`, `cutoff_date`, `n_train_pairs`, `built_at`, `xgb_pred_prezero` |
| `fp-coverage.csv` | 1 | 139 | `region`, `year`, `party`, `fitted`, `sd`, `actual`, `sd_infl` |
| `fp-extra-var.csv` | 1 | 139 | `region`, `year`, `party`, `fitted`, `actual`, `sd`, `tau_loo`, `sd_new` |
| `fp-widening-compare.csv` | 1 | 139 | `region`, `year`, `party`, `fitted`, `actual`, `sd`, `b_loo`, `sd_A`, `sd_B` |
| `fundamentals-validation.csv` | 1 | 5 | `party`, `n`, `lambda`, `loo_mae`, `mae_prev1`, `mae_longrun`, `beats_longrun_on`, `p_sign` |
| `gap-decay.csv` | 1 | 7 | `election`, `seats`, `dispersion`, `gain`, `fed`, `gap_months`, `original` |
| `gateN-qld.csv` | 1 | 750 | `V1`, `V2`, `V3`, `V4`, `V5` |
| `gateN-sa.csv` | 1 | 294 | `election`, `seat`, `round`, `maxmult` |
| `gateN-vic.csv` | 1 | 452 | `election`, `seat`, `round`, `maxmult` |
| `hare-clark-act-ballots.csv` | 1 | 678,972 | `year`, `electorate`, `seq`, `n` |
| `hare-clark-act-booths.csv` | 1 | 4,619 | `year`, `electorate`, `pollingplace`, `unit`, `votes` |
| `hare-clark-act-flows.csv` | 1 | 2,247 | `year`, `electorate`, `u1`, `c1`, `u2`, `c2`, `n` |
| `hare-clark-act-leak.csv` | 1 | 213 | `year`, `electorate`, `u1`, `c1`, `n`, `n_leave2`, `n_exh2` |
| `hare-clark-candidates.csv` | 1 | 1,551 | `region`, `year`, `electorate`, `party_raw`, `party`, `candidate`, `votes`, `elected`, `unit`, `class`, `unit_raw` |
| `hare-clark-tas-flows.csv` | 1 | 6,804 | `year`, `electorate`, `count`, `source`, `src_group`, `to_group`, `papers`, `src_class`, `to_class` |
| `hare-clark-units.csv` | 1 | 521 | `region`, `year`, `electorate`, `unit`, `votes`, `ncand`, `seats_won`, `class`, `seats` |
| `hyperpars-fed.csv` | 1 | 6 | `party`, `scale`, `sigma_obs`, `sigma_rw`, `sigma_obs_pts`, `sigma_rw_pts`, `n_polls`, `logml_gain_vs_fixed`, `at_bound`, `conv` |
| `hyperpars-nsw.csv` | 1 | 6 | `party`, `scale`, `sigma_obs`, `sigma_rw`, `sigma_obs_pts`, `sigma_rw_pts`, `n_polls`, `logml_gain_vs_fixed`, `at_bound`, `conv` |
| `hyperpars-vic.csv` | 1 | 4 | `party`, `scale`, `sigma_obs`, `sigma_rw`, `sigma_obs_pts`, `n_polls`, `at_bound`, `conv` |
| `inclusion-floor.csv` | 1 | 1,112 | `region`, `year`, `floor`, `party`, `fitted`, `actual`, `scorable`, `n_corrected`, `err`, `row_key` |
| `incumbent-transfer-population.csv` | 1 | 2,090 | `seat`, `party`, `name`, `given`, `surname`, `cur_pcv`, `cur_elected`, `own_prev_pcv`, `prev_party_class`, `switched_party`, `tpp_swing`, `party_swing`, `jump_pctile`, `jump_pctile_prev`, `jump_delta`, `target`, `prev_el`, `delta`, `is_major` |
| `ind-candidacies.csv` | 1 | 314 | `year`, `seat`, `name`, `pct`, `elected`, `sitting`, `breakout` |
| `ind-featureset-comparison.csv` | 1 | 5,696 | `pair`, `seat`, `party`, `actual_share`, `jump_pctile`, `sal_exp`, `p_full`, `p_medium`, `p_small` |
| `ind-mixture-eval.csv` | 1 | 790 | `pair`, `seat`, `actual`, `typical`, `pi`, `surge_mean`, `surge_sd`, `mean_pred`, `p15` |
| `ind-model-eval-preds.csv` | 1 | 892 | `pair`, `seat`, `actual`, `new`, `cur_xgb`, `cur_final`, `base`, `same_mp_i`, `c200`, `seat_poll` |
| `ind-model-eval.csv` | 1 | 18 | `target`, `n`, `n_train`, `rounds`, `rmse_cur_xgb`, `rmse_cur_final`, `rmse_new`, `mad_cur_final`, `mad_new`, `bias_cur_final`, `bias_new` |
| `ind-salience-all-years.csv` | 1 | 57 | `sname`, `year`, `rel`, `seat`, `pct`, `breakout` |
| `ind-salience-anchored.csv` | 1 | 20 | `sname`, `hits`, `anchor`, `rel`, `seat`, `pct`, `breakout` |
| `ind-salience-anchoredN.csv` | 1 | 22 | `sname`, `rel`, `seat`, `pct`, `breakout` |
| `ind-salience-gate.csv` | 1 | 18 | `year`, `seat`, `name`, `sitting`, `pct`, `breakout`, `chal`, `inc`, `ratio` |
| `ind-salience-state.csv` | 1 | 22 | `sname`, `state`, `rel_state`, `rel_nat`, `seat`, `pct`, `breakout`, `rel_max` |
| `independent-emergence-loo.csv` | 1 | 88 | `seat`, `mu`, `s`, `nu`, `y`, `ind_now`, `z`, `pit` |
| `independent-emergence-scores.csv` | 1 | 264 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `arm` |
| `independent-federal-scores-shN-cor.csv` | 1 | 2,658 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `arm`, `target` |
| `independent-federal-scores.csv` | 1 | 2,658 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `arm`, `target` |
| `independent-two-mechanism-scores.csv` | 1 | 264 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `arm` |
| `leader-ratings.csv` | 1 | 12,547 | `election`, `region`, `page_key`, `section`, `date`, `end`, `firm`, `sample_n`, `leader`, `measure`, `value`, `source`, `n_named`, `party`, `role` |
| `leader-seat-nswN.csv` | 1 | 2 | `role`, `seat`, `party`, `leader`, `bonus`, `raw`, `se`, `n` |
| `leader-seat-vicN.csv` | 1 | 3 | `role`, `seat`, `party`, `leader`, `bonus`, `raw`, `se`, `n` |
| `level-components.csv` | 1 | 160 | `pair`, `party`, `trend_level`, `fund_level` |
| `level-pred-aef-compare.csv` | 1 | 21 | `party`, `bias`, `rmse`, `n`, `method` |
| `level-pred.csv` | 1 | 239 | `pair`, `party`, `level_pred`, `from_polls` |
| `level-recent.csv` | 1 | 105 | `election`, `region`, `cls`, `trend`, `avg28`, `n28`, `actual` |
| `lga-district-overlap-vic.csv` | 1 | 1,093 | `election`, `district`, `lga`, `share_of_district`, `share_of_lga` |
| `lga-district-overlap.csv` | 1 | 10,750 | `election`, `region`, `sed_vintage`, `district`, `lga`, `share_of_district`, `share_of_lga` |
| `minor-candidate-features.csv` | 1 | 9,419 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16`, `V17`, `V18`, `V19`, `V20`, `V21`, `V22`, `V23`, `V24`, `V25`, `V26`, `V27`, `V28`, `V29`, `V30`, `V31`, `V32`, `V33`, `V34`, `V35`, `V36`, `V37`, `V38`, `V39`, `V40`, `V41`, `V42`, `V43`, `V44`, `V45`, `V46`, `V47`, `V48`, `V49`, `V50`, `V51`, `V52`, `V53`, `V54`, `V55`, `V56`, `V57`, `V58`, `V59`, `V60` |
| `minor-candidate-oof-resid-vN.csv` | 1 | 9,140 | `election`, `seat`, `name`, `cls`, `pk`, `share`, `pred_xgb`, `pred_naive`, `n_train_el`, `nrounds` |
| `minor-candidate-oof-resid.csv` | 1 | 9,140 | `election`, `seat`, `name`, `cls`, `pk`, `share`, `pred_xgb`, `pred_naive`, `n_train_el`, `nrounds` |
| `minor-candidate-oof.csv` | 1 | 9,140 | `election`, `seat`, `name`, `cls`, `pk`, `share`, `pred_xgb`, `pred_naive`, `n_train_el`, `nrounds` |
| `minor-candidate-scores-resid-vN.csv` | 1 | 70 | `election`, `cls`, `current`, `actual`, `m_xgb`, `m_naive`, `W`, `n_train_el` |
| `minor-candidate-scores-resid.csv` | 1 | 70 | `election`, `cls`, `current`, `actual`, `m_xgb`, `m_naive`, `W`, `n_train_el` |
| `minor-candidate-scores.csv` | 1 | 70 | `election`, `cls`, `current`, `actual`, `m_xgb`, `m_naive`, `W`, `n_train_el` |
| `minor-class-shares-resid-vN.csv` | 1 | 96 | `election`, `cls`, `pred_resid`, `pred_naive`, `arm` |
| `minor-class-shares-resid.csv` | 1 | 96 | `election`, `cls`, `pred_resid`, `pred_naive`, `arm` |
| `minor-class-shares-vN.csv` | 2 | 96 | `election`, `cls`, `pred_resid`, `pred_naive`, `arm` |
| `mp-slope-by-class.csv` | 1 | 5 | `party`, `n_member`, `n_also`, `member`, `also_ran`, `shipped` |
| `mp-slope-by-target-tf.csv` | 1 | 140 | `target`, `party`, `n_member`, `member`, `also_ran` |
| `mp-slope-by-target.csv` | 1 | 140 | `target`, `party`, `n_member`, `member`, `also_ran` |
| `mp-slope-loo.csv` | 1 | 35 | `target`, `n_held_out`, `n_mp_held_out`, `member`, `also_ran`, `gap` |
| `notional-baselines.csv` | 1 | 4,994 | `election`, `prior`, `seat`, `party`, `votes`, `pcv` |
| `nsw-byelection-prevpcv.csv` | 1 | 2 | `V1`, `V2`, `V3`, `V4` |
| `nsw-exhaustion-by-departure.csv` | 1 | 181 | `election`, `seat`, `slug`, `exhausted`, `formal`, `exhaust_rate`, `retire_derived`, `in_eleven` |
| `nswec-N-nsw-firstprefs.csv` | 1 | 473 | `seat`, `party`, `votes` |
| `nswec-nsw-transfers.csv` | 1 | 3,935 | `election`, `seat`, `round`, `from`, `to`, `votes` |
| `onp-concentration-curve.csv` | 1 | 17 | `file`, `pair`, `statewide`, `sd_actual`, `a`, `k`, `sd_pred`, `n_fit`, `r2`, `extrapolated` |
| `onp-concentration.csv` | 1 | 15 | `election`, `state`, `seats`, `contested`, `statewide`, `cv` |
| `onp-contest-sample.csv` | 1 | 1,501 | `election`, `seat`, `stood` |
| `onp-ordering-calibration.csv` | 1 | 1 | `onp_order_sd`, `rho`, `target` |
| `onp-ordering-federal.csv` | 1 | 1 | `election`, `n`, `rho_A`, `rho_B`, `mae_A`, `mae_B`, `mae_C` |
| `onp-ordering-saN.csv` | 1 | 47 | `seat`, `actual`, `fed_onp`, `grn_pct`, `rank_fed`, `rank_actual` |
| `onp-senate-district-panel.csv` | 1 | 308 | `k`, `actual`, `senate`, `house`, `el`, `L`, `Ls` |
| `onp-senate-vicN.csv` | 1 | 88 | `seat`, `senate_pct`, `curve_a`, `curve_b`, `floor_pct`, `source`, `n_fit`, `r2` |
| `onp-tcp-comparison.csv` | 1 | 87 | `seat`, `our_win`, `a`, `a_pct`, `b`, `b_pct`, `onp_fp`, `tot`, `onp_tcp`, `made_final`, `yg_win`, `yg_run`, `yg_tpp`, `p_onp` |
| `onp-vote-sourcing.csv` | 1 | 157 | `seat`, `ONP_a`, `ALP_a`, `LNP_a`, `ONP_b`, `ALP_b`, `LNP_b`, `cycle`, `region`, `d_ONP`, `d_ALP`, `d_LNP`, `pred_ALP`, `pred_LNP`, `excess_ALP`, `excess_LNP`, `dONP_dev`, `exALP_dev`, `exLNP_dev` |
| `others-bias-tests-Nregion.csv` | 1 | 190 | `region`, `year`, `party`, `complete`, `act_sum`, `fitted`, `actual`, `prev`, `poll_final`, `poll_mid`, `n_final`, `n_mid`, `bias` |
| `others-bias-tests.csv` | 1 | 268 | `region`, `year`, `party`, `complete`, `act_sum`, `fitted`, `actual`, `prev`, `poll_final`, `poll_mid`, `n_final`, `n_mid`, `bias` |
| `others-bucket-history.csv` | 1 | 22 | `pair`, `bucket_fc`, `bucket_act`, `classes`, `date` |
| `partial-return-baseline.csv` | 1 | 319 | `s`, `party`, `pair`, `seat`, `pred_share`, `actual_share`, `n_prior`, `n_returned`, `prior_total`, `returner_vote`, `departed_vote`, `err` |
| `partial-return-cells.csv` | 1 | 329 | `s`, `party`, `n_prior`, `prior_total`, `returner_vote`, `departed_vote`, `n_returned`, `actual_now`, `pair`, `shape` |
| `pf-arms-by-pair.csv` | 1 | 22 | `pair`, `n`, `p0f0`, `p0f1`, `p1f0`, `p1f1`, `diff`, `diff_best` |
| `pf-arms-pooled.csv` | 1 | 4 | `arm`, `seeds`, `n`, `accuracy`, `brier`, `logloss`, `logloss_sd`, `label`, `delta` |
| `poll-coverage-wiki-only.csv` | 1 | 397 | `election`, `end`, `days_out`, `firm`, `client`, `alp_fp`, `lnp_fp`, `sample_n`, `page_key`, `source_url` |
| `poll-lag.csv` | 1 | 139 | `region`, `year`, `party`, `fitted`, `sd`, `actual`, `sd_infl`, `cyc`, `poll_mean`, `n_polls`, `prior`, `gap`, `err`, `poll_err` |
| `poll-record-compare.csv` | 1 | 3 | `arm`, `mae_inc`, `mae_arm`, `mae_gain`, `bar`, `runtime_x`, `logdens_gain`, `logdens_se`, `clusters`, `cells`, `cover95_inc`, `cover95_arm`, `B2`, `B3`, `guards_ok`, `accuracy`, `bands`, `ship` |
| `poll-record-loo-both.csv` | 1 | 195 | `year`, `region`, `horizon`, `pred`, `actual`, `err`, `z`, `w`, `bias`, `sd_err`, `arm` |
| `poll-record-loo-equal.csv` | 1 | 195 | `year`, `region`, `horizon`, `pred`, `actual`, `err`, `z`, `w`, `bias`, `sd_err`, `arm` |
| `poll-record-loo-noise.csv` | 1 | 195 | `year`, `region`, `horizon`, `pred`, `actual`, `err`, `z`, `w`, `bias`, `sd_err`, `arm` |
| `poll-record-loo-record.csv` | 1 | 195 | `year`, `region`, `horizon`, `pred`, `actual`, `err`, `z`, `w`, `bias`, `sd_err`, `arm` |
| `poll-record-scores-both.csv` | 1 | 14,234 | `date`, `firm`, `party`, `y`, `logdens`, `z`, `year`, `region`, `horizon`, `arm` |
| `poll-record-scores-equal.csv` | 1 | 14,234 | `date`, `firm`, `party`, `y`, `logdens`, `z`, `year`, `region`, `horizon`, `arm` |
| `poll-record-scores-noise.csv` | 1 | 14,234 | `date`, `firm`, `party`, `y`, `logdens`, `z`, `year`, `region`, `horizon`, `arm` |
| `poll-record-scores-record.csv` | 1 | 14,234 | `date`, `firm`, `party`, `y`, `logdens`, `z`, `year`, `region`, `horizon`, `arm` |
| `poll-registry.csv` | 1 | 34 | `election`, `live`, `from`, `to`, `polls`, `tpp_only`, `wiki`, `bt`, `both`, `pb`, `ae`, `ae_party`, `label_ae`, `f30_polls`, `f30_tpp_only`, `f30_wiki`, `f30_bt`, `f30_both`, `f30_pb`, `f30_ae`, `f30_ae_party`, `f30_label_ae`, `f30_pb_post`, `ae_pb_post`, `ae_share`, `f30_ae_share` |
| `poll-sigmas-tf-cache.csv` | 1 | 251 | `cache_key`, `sigma_obs`, `sigma_rw` |
| `poll-tracking-calibration.csv` | 1 | 154 | `region`, `year`, `party`, `n`, `fitted`, `poll90`, `dev` |
| `poll-tracking-vic.csv` | 1 | 7 | `party`, `fitted`, `poll_mean`, `n`, `fitted_ok`, `dev`, `refolded_in`, `dropped`, `asserted`, `breach` |
| `pollbludger-vs-layered.csv` | 1 | 1,213 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16`, `V17`, `V18`, `V19`, `V20` |
| `pollster-accuracy.csv` | 1 | 166 | `year`, `region`, `firm`, `poll_date`, `days_before`, `poll_tpp`, `actual_tpp`, `error` |
| `pollster-herding.csv` | 1 | 30 | `firm`, `n_polls`, `implied_sd_pts`, `binomial_floor`, `ratio` |
| `pollster-scorecard.csv` | 1 | 19 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8` |
| `pooled-backtest.csv` | 1 | 35 | `pair`, `n`, `accuracy`, `brier`, `logloss`, `code`, `mtime`, `file` |
| `pooled-sharedetail.csv` | 1 | 19,616 | `pair`, `seat`, `party`, `pred_share`, `actual_share` |
| `primary-errors-by-class.csv` | 1 | 13,352 | `pair`, `seat`, `party`, `pred`, `actual`, `err` |
| `projection-data.csv` | 1 | 321 | `year`, `region`, `horizon`, `trend_tpp`, `actual_tpp`, `n_polls`, `fund_tpp` |
| `projection-mix.csv` | 1 | 8 | `horizon`, `n`, `w`, `mae_mix`, `mae_mix_loo`, `mae_trend`, `mae_fund`, `bias`, `sd_err`, `sd_err_loo` |
| `proximity-substitution.csv` | 1 | 54 | `cycle`, `region`, `p1`, `p2`, `r`, `prox`, `size`, `n_districts`, `band` |
| `published-predictions.csv` | 1 | 19,616 | `pair`, `seat`, `party`, `candidate`, `n_cands`, `ours`, `actual`, `miss`, `p_win`, `won`, `aef`, `aef_miss`, `aef_p_win`, `prev_share`, `prev_candidate` |
| `qA-fed.csv` | 1 | 886 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `qA-nsw.csv` | 1 | 88 | `seat`, `p`, `pred`, `pred_p`, `actual`, `bin` |
| `qA-sa.csv` | 1 | 47 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `qA-vic.csv` | 1 | 166 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `qB-fed.csv` | 1 | 886 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `qB-nsw.csv` | 1 | 88 | `seat`, `p`, `pred`, `pred_p`, `actual`, `bin` |
| `qB-sa.csv` | 1 | 47 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `qB-vic.csv` | 1 | 166 | `seat`, `actual`, `prob`, `pred`, `pred_p`, `pair` |
| `reentry-loo-diagnostic.csv` | 1 | 1,416 | `pair`, `seat`, `party`, `pred`, `actual`, `state_pcv`, `breadth`, `err` |
| `refold-test.csv` | 1 | 278 | `region`, `year`, `arm`, `party`, `fitted`, `actual`, `err` |
| `results-current.csv` | 1 | 14,475 | `pair`, `seat`, `party`, `is_winner`, `is_our_pick`, `our_prob`, `our_primary`, `actual_primary`, `arm_fingerprint`, `code`, `mtime` |
| `retest-fed-aligned-tf.csv` | 1 | 84 | `lab`, `horizon`, `err_base`, `err_drop` |
| `retirement-derived.csv` | 1 | 2,616 | `pair`, `seat`, `retire_derived` |
| `retiring-mp-cases.csv` | 1 | 343 | `pair`, `seat`, `sn`, `party`, `k`, `prior_pcv`, `new_share`, `tenure`, `retention` |
| `saN-conversion.csv` | 1 | 47 | `seat`, `leader`, `lead_pct`, `winner`, `converted` |
| `saN-scored.csv` | 1 | 21 | `seat`, `margin`, `notional_alp_2pp`, `alp_2pp`, `swing`, `dev`, `transposed`, `published` |
| `saN-transfer-rates.csv` | 1 | 176 | `from_class`, `surv`, `to_class`, `votes`, `pct`, `events` |
| `salience-corpus.csv` | 1 | 8,706 | `election`, `region`, `year`, `seat`, `name`, `party`, `pcv`, `breakout`, `sitting` |
| `salience-hazard.csv` | 1 | 151 | `election`, `seat`, `who`, `party`, `pcv`, `won`, `jump`, `surge_h` |
| `salience-ratios.csv` | 1 | 495 | `election`, `seat`, `name`, `party`, `pcv`, `breakout`, `hits`, `anchor_hits`, `ratio` |
| `salience-surge-vN-population.csv` | 1 | 1,907 | `pair`, `seat`, `party`, `keyword`, `elected`, `pcv`, `jump`, `jump_pctile`, `prev_party`, `prev_ind` |
| `salience-vN-fedN.csv` | 2 | 151 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7` |
| `salience-vN.csv` | 2 | 1,067 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9` |
| `salience-vN-vicN.csv` | 1 | 266 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8` |
| `scale-comparison-fed.csv` | 1 | 6 | `party`, `logml_y_logit`, `logml_y_points`, `gain`, `scale` |
| `scale-comparison-nsw.csv` | 1 | 6 | `party`, `logml_y_logit`, `logml_y_points`, `gain`, `scale` |
| `scenario-knots-vic-N.csv` | 1 | 73 | `mode`, `moved`, `x`, `ALP`, `LNP`, `ONP`, `GRN`, `IND`, `p_maj_ALP`, `p_maj_LNP`, `p_hung`, `p_onp_bop` |
| `sd-model-seat-effects.csv` | 1 | 1,397 | `pair`, `seat`, `actual`, `p_off`, `p_on`, `d` |
| `seat-calibration-grid.csv` | 1 | 24 | `m`, `shrink`, `smooth`, `log`, `se`, `slope`, `acc` |
| `seat-centroids.csv` | 1 | 1,164 | `src`, `seat`, `lon`, `lat` |
| `seat-context.csv` | 1 | 2,278 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11`, `V12`, `V13`, `V14`, `V15`, `V16`, `V17` |
| `seat-count-error.csv` | 1 | 63 | `pair`, `party`, `m`, `lo`, `hi`, `actual`, `err`, `inside90` |
| `seat-poll-blend-fedN.csv` | 1 | 732 | `seat`, `class`, `type`, `poll`, `n_polls`, `n_mrp`, `wsum`, `w`, `w_raw`, `w_se`, `w_n`, `w_k`, `w_direct`, `w_mrp`, `vm`, `vm_ref`, `vm_par`, `te`, `sal`, `w_ind`, `w_ind_raw`, `w_ind_se`, `w_ind_n` |
| `seat-poll-blend-nswN.csv` | 1 | 1 | `seat`, `class`, `type`, `poll`, `n_polls`, `n_mrp`, `wsum`, `w`, `w_raw`, `w_se`, `w_n`, `w_k`, `w_direct`, `w_mrp`, `vm`, `vm_ref`, `vm_par`, `te`, `sal`, `w_ind`, `w_ind_raw`, `w_ind_se`, `w_ind_n` |
| `seat-poll-blend-vicN.csv` | 1 | 1 | `seat`, `class`, `type`, `poll`, `n_polls`, `n_mrp`, `wsum`, `w`, `w_raw`, `w_se`, `w_n`, `w_k`, `w_direct`, `w_mrp`, `vm`, `vm_ref`, `vm_par`, `te`, `sal`, `w_ind`, `w_ind_raw`, `w_ind_se`, `w_ind_n` |
| `seat-primary-ranges-nsw-N-scn-exact-GRN--N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N-scn-exact-GRN-+N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N-scn-exact-ONP--N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N-scn-exact-ONP-+N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N-scn-polled-GRN--N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N-scn-polled-GRN-+N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N-scn-polled-ONP--N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N-scn-polled-ONP-+N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-nsw-N.csv` | 1 | 651 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-councilfix.csv` | 1 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-nocouncilwalk.csv` | 1 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-ALP-N.csv` | 9 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-exact-ONP-+N.csv` | 2 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-GRN-N.csv` | 9 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-LNP-N.csv` | 9 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-ONP-N.csv` | 10 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-pol-ALP-N.csv` | 9 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-pol-GRN-N.csv` | 9 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-pol-LNP-N.csv` | 9 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-pol-ONP-N.csv` | 9 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-scn-polled-ONP-+N.csv` | 2 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N-vNwalk.csv` | 1 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-primary-ranges-vic-N.csv` | 1 | 616 | `seat`, `party`, `mean`, `q05`, `q25`, `q50`, `q75`, `q95` |
| `seat-prob-calibration.csv` | 1 | 322 | `seat`, `p`, `alp_won`, `election`, `arm`, `alp_total` |
| `seat-probs-nsw-N-scn-exact-GRN--N.csv` | 1 | 308 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N-scn-exact-GRN-+N.csv` | 1 | 341 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N-scn-exact-ONP--N.csv` | 1 | 367 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N-scn-exact-ONP-+N.csv` | 1 | 336 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N-scn-polled-GRN--N.csv` | 1 | 305 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N-scn-polled-GRN-+N.csv` | 1 | 352 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N-scn-polled-ONP--N.csv` | 1 | 373 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N-scn-polled-ONP-+N.csv` | 1 | 352 | `seat`, `party`, `prob` |
| `seat-probs-nsw-N.csv` | 1 | 343 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-cor.csv` | 1 | 335 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-councilfix.csv` | 1 | 335 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-cvN.csv` | 3 | 351 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-cvtestN.csv` | 2 | 277 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-fixtest.csv` | 1 | 291 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-fpN.csv` | 1 | 307 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-livecheck.csv` | 1 | 240 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-llN.csv` | 1 | 352 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-llNoff.csv` | 1 | 342 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-lvbase.csv` | 1 | 323 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-lvon.csv` | 1 | 333 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-nocouncilwalk.csv` | 1 | 337 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-nodsN.csv` | 1 | 352 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-nolive.csv` | 1 | 356 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-noshrink.csv` | 1 | 300 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-ALP-N.csv` | 9 | 360 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-exact-ONP-+N.csv` | 2 | 342 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-GRN-N.csv` | 9 | 311 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-LNP-N.csv` | 9 | 327 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-ONP-N.csv` | 10 | 364 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-pol-ALP-N.csv` | 9 | 360 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-pol-GRN-N.csv` | 9 | 327 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-pol-LNP-N.csv` | 9 | 344 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-pol-ONP-N.csv` | 9 | 376 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-scn-polled-ONP-+N.csv` | 2 | 340 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-shN.csv` | 2 | 371 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-shipbaseline.csv` | 1 | 340 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-shippedsalltest.csv` | 1 | 360 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-shippedtest.csv` | 1 | 360 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-shiptest.csv` | 1 | 182 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-shrink.csv` | 1 | 334 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-sweepN.csv` | 7 | 292 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-vNwalk.csv` | 1 | 337 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-vNverify.csv` | 1 | 267 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-xgbvNtest.csv` | 1 | 280 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-xgbvNisolatetest.csv` | 1 | 277 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-xgbvNlivetest.csv` | 1 | 277 | `seat`, `party`, `prob` |
| `seat-probs-vic-N-xgbvNsalltest.csv` | 1 | 282 | `seat`, `party`, `prob` |
| `seat-probs-vic-N.csv` | 1 | 354 | `seat`, `party`, `prob` |
| `seat-probs-vic-NcvN.csv` | 3 | 360 | `seat`, `party`, `prob` |
| `seat-probs-vic-Ncvbase.csv` | 1 | 362 | `seat`, `party`, `prob` |
| `seat-probs-vic-NdefectN.csv` | 1 | 362 | `seat`, `party`, `prob` |
| `seat-probs-vic-Nrecheck.csv` | 1 | 360 | `seat`, `party`, `prob` |
| `seat-salience-vN-fedN.csv` | 1 | 112 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11` |
| `seat-salience.csv` | 1 | 715 | `election`, `seat`, `name`, `party`, `sal_share`, `pcv` |
| `seat-shares-nsw-N-scn-exact-GRN--N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N-scn-exact-GRN-+N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N-scn-exact-ONP--N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N-scn-exact-ONP-+N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N-scn-polled-GRN--N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N-scn-polled-GRN-+N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N-scn-polled-ONP--N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N-scn-polled-ONP-+N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-nsw-N.csv` | 1 | 93 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-cor.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-councilfix.csv` | 1 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-cvN.csv` | 3 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-cvtestN.csv` | 2 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-fixtest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-fpN.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-livecheck.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-llN.csv` | 1 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-llNoff.csv` | 1 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-lvbase.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-lvon.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-nocouncilwalk.csv` | 1 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-nodsN.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-nolive.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-noshrink.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-ALP-N.csv` | 9 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-exact-ONP-+N.csv` | 2 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-GRN-N.csv` | 9 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-LNP-N.csv` | 9 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-ONP-N.csv` | 10 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-pol-ALP-N.csv` | 9 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-pol-GRN-N.csv` | 9 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-pol-LNP-N.csv` | 9 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-pol-ONP-N.csv` | 9 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-scn-polled-ONP-+N.csv` | 2 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-shN.csv` | 2 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-shipbaseline.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-shippedsalltest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-shippedtest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-shiptest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-shrink.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-sweepN.csv` | 7 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-vNwalk.csv` | 1 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-vNverify.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-xgbvNtest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-xgbvNisolatetest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-xgbvNlivetest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N-xgbvNsalltest.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-N.csv` | 1 | 88 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-NcvN.csv` | 3 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-Ncvbase.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-NdefectN.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-shares-vic-Nrecheck.csv` | 1 | 87 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-exact-GRN--N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-exact-GRN-+N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-exact-ONP--N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-exact-ONP-+N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-polled-GRN--N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-polled-GRN-+N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-polled-ONP--N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N-scn-polled-ONP-+N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-nsw-N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-cor.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-councilfix.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-cvN.csv` | 3 | 6,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-cvtestN.csv` | 2 | 4,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-fixtest.csv` | 1 | 500 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-fpN.csv` | 1 | 4,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-livecheck.csv` | 1 | 300 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-llN.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-llNoff.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-lvbase.csv` | 1 | 4,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-lvon.csv` | 1 | 4,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-nocouncilwalk.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-nodsN.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-nolive.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-noshrink.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-ALP-N.csv` | 9 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-exact-ONP-+N.csv` | 2 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-GRN-N.csv` | 9 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-LNP-N.csv` | 9 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-ONP-N.csv` | 10 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-pol-ALP-N.csv` | 9 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-pol-GRN-N.csv` | 9 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-pol-LNP-N.csv` | 9 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-pol-ONP-N.csv` | 9 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-scn-polled-ONP-+N.csv` | 2 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-shN.csv` | 2 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-shipbaseline.csv` | 1 | 5,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-shippedsalltest.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-shippedtest.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-shiptest.csv` | 1 | 300 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-shrink.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-sweepN.csv` | 7 | 4,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-vNwalk.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-vNverify.csv` | 1 | 5,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-xgbvNtest.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-xgbvNisolatetest.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-xgbvNlivetest.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N-xgbvNsalltest.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-N.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-NcvN.csv` | 3 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-Ncvbase.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-NdefectN.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-full-vic-Nrecheck.csv` | 1 | 20,000 | `ALP`, `GRN`, `IND`, `LNP`, `ONP`, `OTH`, `OTH_RIGHT` |
| `seat-sims-vic-N.csv` | 1 | 50,000 | `seats` |
| `seat-swing-port-nswN.csv` | 1 | 93 | `seat`, `fed_swing`, `coef`, `coef_unshrunk`, `coef_se`, `cycles`, `n_fit` |
| `seat-swing-port-roundN.csv` | 1 | 166 | `seat`, `pair`, `actual`, `p_off`, `p_on`, `b_off`, `b_on`, `d` |
| `seat-swing-port-vicN.csv` | 1 | 88 | `seat`, `fed_swing`, `coef`, `coef_unshrunk`, `coef_se`, `cycles`, `n_fit` |
| `seat-swing-predictors.csv` | 1 | 180 | `seat`, `incumbent`, `fed_swing`, `retirement`, `soph_cand`, `soph_party`, `actual_swing`, `alp_inc`, `election`, `dev`, `ret_i`, `soc_i`, `sop_i`, `fed_c` |
| `seat-swing-revalidation.csv` | 1 | 5 | `election`, `federal`, `n`, `mae_uniform`, `mae_model`, `gain` |
| `seat-tcp-ranges-nsw-N-scn-exact-GRN--N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N-scn-exact-GRN-+N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N-scn-exact-ONP--N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N-scn-exact-ONP-+N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N-scn-polled-GRN--N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N-scn-polled-GRN-+N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N-scn-polled-ONP--N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N-scn-polled-ONP-+N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-nsw-N.csv` | 1 | 93 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-councilfix.csv` | 1 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-nocouncilwalk.csv` | 1 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-ALP-N.csv` | 9 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-exact-ONP-+N.csv` | 2 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-GRN-N.csv` | 9 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-LNP-N.csv` | 9 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-ONP-N.csv` | 10 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-pol-ALP-N.csv` | 9 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-pol-GRN-N.csv` | 9 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-pol-LNP-N.csv` | 9 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-pol-ONP-N.csv` | 9 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-scn-polled-ONP-+N.csv` | 2 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N-vNwalk.csv` | 1 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tcp-ranges-vic-N.csv` | 1 | 88 | `seat`, `leader`, `other`, `p_pair`, `p_leader_wins_pair`, `leader_tcp_q05`, `leader_tcp_q25`, `leader_tcp_q50`, `leader_tcp_q75`, `leader_tcp_q95`, `swing_to_flip` |
| `seat-tpp-estimates.csv` | 1 | 2,806 | `V1`, `V2`, `V3` |
| `seat-type-N.csv` | 1 | 5 | `election`, `uniform`, `A`, `B`, `C` |
| `seats-vic-N.csv` | 1 | 83 | `seat`, `seat_region`, `incumbent`, `margin`, `alp_tpp_now`, `alp_tpp_proj`, `seat_swing_adj`, `alp_win_prob` |
| `senate-by-district-class.csv` | 1 | 9,807 | `region`, `cycle`, `fed`, `district`, `cls`, `v`, `senate_pct` |
| `senate-by-division-class.csv` | 1 | 8,419 | `fed`, `state`, `division`, `cls`, `v`, `senate_pct` |
| `senate-onp-by-district.csv` | 1 | 647 | `region`, `cycle`, `fed`, `district`, `senate_pct`, `votes` |
| `senate-onp-saN.csv` | 1 | 47 | `k`, `seat`, `senate`, `votes`, `state` |
| `senate-onp-vicN.csv` | 1 | 88 | `seat`, `senate`, `votes` |
| `share-bias-audit.csv` | 1 | 40 | `V1`, `V2`, `V3`, `V4`, `V5`, `V6`, `V7`, `V8`, `V9`, `V10`, `V11` |
| `sitting-member-shift.csv` | 1 | 69 | `group`, `shift`, `m`, `se`, `k`, `n`, `pair` |
| `snapshots-candidacies-N-pre-abc.csv` | 1 | 18,172 | `election`, `region`, `year`, `seat`, `name`, `surname`, `given`, `party`, `party_raw`, `party_ab`, `state`, `votes`, `pcv`, `elected`, `historic_elected`, `breakout`, `swing`, `ballot_position`, `ordinary`, `absent`, `provisional`, `prepoll`, `postal`, `ballot_order`, `tot` |
| `snapshots-candidacies-prev-build.csv` | 1 | 22,360 | `election`, `region`, `year`, `seat`, `name`, `surname`, `given`, `party`, `party_raw`, `party_ab`, `state`, `votes`, `pcv`, `elected`, `historic_elected`, `breakout`, `swing`, `ballot_position`, `ordinary`, `absent`, `provisional`, `prepoll`, `postal`, `ballot_order`, `tot`, `source`, `party_conflict`, `class_rule`, `party_alt` |
| `spread-by-class-own.csv` | 1 | 185 | `target`, `class`, `a`, `se_a`, `w_a`, `b`, `se_b`, `w_b`, `n_cls`, `s_max`, `n_cells`, `n_pairs` |
| `spread-by-composition.csv` | 1 | 185 | `target`, `class`, `b`, `se`, `w`, `n_cells`, `n_pairs` |
| `spread-by-size.csv` | 1 | 37 | `target`, `n_cells`, `n_pairs`, `slope`, `se`, `w`, `f_median`, `factor_5k`, `factor_20k` |
| `state-deviation-features-OLD-leaky.csv` | 1 | 1,202 | `pair`, `seat`, `state`, `state_poll_dev`, `state_elec_dev`, `state_elec_gap`, `state_poll_n` |
| `state-deviation-features.csv` | 1 | 1,202 | `pair`, `seat`, `state`, `state_poll_dev`, `state_elec_dev`, `state_elec_gap`, `state_poll_n` |
| `state-swing-prior.csv` | 1 | 48 | `pair`, `state`, `state_el`, `state_swing`, `months_gap`, `fed_dev` |
| `statewide-cov-score.csv` | 1 | 10 | `pair`, `A`, `B`, `gain` |
| `statewide-draw-betas-nsw-N-scn-exact-GRN--N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N-scn-exact-GRN-+N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N-scn-exact-ONP--N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N-scn-exact-ONP-+N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N-scn-polled-GRN--N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N-scn-polled-GRN-+N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N-scn-polled-ONP--N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N-scn-polled-ONP-+N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-nsw-N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-ALP-N.csv` | 9 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-exact-ONP-+N.csv` | 2 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-GRN-N.csv` | 9 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-LNP-N.csv` | 9 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-ONP-N.csv` | 10 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-pol-ALP-N.csv` | 9 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-pol-GRN-N.csv` | 9 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-pol-LNP-N.csv` | 9 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-pol-ONP-N.csv` | 9 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N-scn-polled-ONP-+N.csv` | 2 | 16 | `moved`, `class`, `beta` |
| `statewide-draw-betas-vic-N.csv` | 1 | 16 | `moved`, `class`, `beta` |
| `statewide-forecast-audit-aeN.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss` |
| `statewide-forecast-audit-aiN.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss` |
| `statewide-forecast-audit-bN.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-baseNsep.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss` |
| `statewide-forecast-audit-baseNsepB.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-cand_naive.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-cand_resid.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-cpN.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-lrN.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-obN.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-vNblend.csv` | 2 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-vNcand.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-vNsplit.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-vNae.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-vNbase.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit-vNbt.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss`, `in_bucket`, `others_scale` |
| `statewide-forecast-audit.csv` | 1 | 144 | `pair`, `region`, `n_polls`, `trend_tpp`, `fund_tpp`, `w_trend`, `anchored_tpp`, `cls`, `forecast`, `actual`, `miss` |
| `statewide-level-nsw-N.csv` | 1 | 5 | `party`, `level` |
| `statewide-level-vic-N.csv` | 1 | 5 | `party`, `level` |
| `statewide-poll-samples.csv` | 1 | 6,093 | `region`, `anchor_row`, `MidDate`, `Firm`, `Brand`, `anchor_tpp`, `anchor_alp`, `anchor_lnp`, `anchor_lnp_col`, `cycle`, `matched`, `matched_with_n`, `match_quality`, `date_gap`, `fp_gap`, `sample_n`, `sample_raw`, `client`, `unmatched_reason`, `wiki_row_shared_by`, `wiki_id`, `wiki_page_key`, `wiki_table_idx`, `wiki_section`, `wiki_date_raw`, `wiki_fieldwork_start`, `wiki_fieldwork_end`, `wiki_firm_raw`, `wiki_alp_fp`, `wiki_lnp_fp`, `wiki_lib_fp`, `wiki_nat_fp`, `wiki_source_url` |
| `swing-shape-by-magnitude.csv` | 1 | 2,878 | `party`, `seat`, `p_a`, `p_b`, `sw_a`, `sw_b`, `cycle`, `region`, `d_seat`, `d_state`, `abs_state`, `err_uniform`, `err_prop`, `advantage`, `dec` |
| `trend-fed-N.csv` | 3 | 7,665 | `party`, `scale`, `date`, `mean`, `sd`, `lo95`, `hi95` |
| `trend-nsw-N.csv` | 2 | 10,154 | `party`, `scale`, `date`, `mean`, `sd`, `lo95`, `hi95` |
| `trend-vic-N.csv` | 3 | 7,275 | `party`, `scale`, `date`, `mean`, `sd`, `lo95`, `hi95` |
| `vic-onp-lag.csv` | 1 | 5 | `party`, `fitted`, `polls`, `poll_mean`, `gap` |
| `vicN-live-salience.csv` | 1 | 43 | `seat`, `cand`, `party`, `sal_share`, `sal_raw`, `fetched_at` |
| `vicN-prenomination-candidates.csv` | 1 | 371 | `seat`, `cand`, `party`, `fetched_at`, `source` |
| `vicN-salience-jump.csv` | 1 | 500 | `election`, `seat`, `cand`, `party`, `keyword`, `jump`, `jump_raw`, `linked`, `snapshot_to` |
| `wa-flows-per-election.csv` | 1 | 9 | `pair`, `n`, `base`, `wa`, `gain`, `acc_a`, `acc_b` |
| `wa-shares-waN.csv` | 7 | 57 | `seat`, `ALP`, `GRN`, `IND`, `LNP`, `OTH`, `OTH_RIGHT`, `ONP`, `pair` |
| `walk-threshold-rows.csv` | 1 | 183 | `region`, `year`, `party`, `n_polls`, `scorable` |
| `xgb-emergence-magnitude.csv` | 1 | 4 | `party`, `n`, `m`, `s`, `w`, `mu_shrunk`, `sd_shrunk` |
| `xgb-emergence-oof.csv` | 1 | 13,314 | `pair`, `seat`, `party`, `xgb_pred`, `actual_share`, `emergent`, `p_emerge`, `mu_shrunk`, `sd_shrunk`, `mix_mean`, `mix_sd`, `z_old`, `z_new` |
| `xgb-emergence-vN-oof.csv` | 3 | 13,314 | `pair`, `seat`, `party`, `xgb_pred`, `actual_share`, `emergent`, `p_emerge`, `mu_pool`, `sd_pool`, `mu_xgb`, `sd_xgb`, `z_old`, `z_pool`, `z_xgb` |
| `xgb-emergence-vN-seat.csv` | 1 | 2,097 | `pair`, `seat`, `surge_h`, `surge_party`, `surge_mu`, `surge_sd`, `hit` |
| `xgb-flows-asat-manifest.csv` | 1 | 21 | `election`, `date`, `n_prior`, `n_train`, `nrounds`, `file`, `config_key` |
| `xgb-flows-tfN-asat-manifest.csv` | 2 | 22 | `election`, `n_prior`, `n_train`, `nrounds`, `half_life`, `rmse`, `file` |
| `xgb-flows-vN-features.csv` | 1 | 36,064 | `election`, `seat`, `to`, `from`, `surv`, `event_id`, `round`, `votes`, `region`, `event_votes`, `y`, `cond_rate`, `cond_n`, `pool_rate`, `pool_n`, `to_primary`, `from_primary`, `lead_primary`, `dest_same`, `dest_same_mp`, `surv_ALP`, `surv_GRN`, `surv_IND`, `surv_LNP`, `surv_NAT`, `surv_ONP`, `surv_OTH`, `surv_OTH_RIGHT`, `n_survivors`, `from_ALP`, `from_GRN`, `from_IND`, `from_LNP`, `from_NAT`, `from_ONP`, `from_OTH`, `from_OTH_RIGHT`, `to_ALP`, `to_GRN`, `to_IND`, `to_LNP`, `to_NAT`, `to_ONP`, `to_OTH`, `to_OTH_RIGHT`, `region_fed`, `region_nsw`, `region_qld`, `region_sa`, `region_vic`, `region_wa` |
| `xgb-flows-vN-oof-predictions.csv` | 1 | 36,064 | `election`, `seat`, `round`, `from`, `to`, `surv`, `y`, `base_pred`, `xgb_pred`, `cond_n`, `pool_n` |
| `xgb-flows-vN-tfN-features.csv` | 2 | 36,064 | `election`, `seat`, `to`, `from`, `surv`, `event_id`, `round`, `votes`, `region`, `event_votes`, `y`, `cond_rate`, `cond_n`, `pool_rate`, `pool_n`, `to_primary`, `from_primary`, `lead_primary`, `dest_same`, `dest_same_mp`, `surv_ALP`, `surv_GRN`, `surv_IND`, `surv_LNP`, `surv_NAT`, `surv_ONP`, `surv_OTH`, `surv_OTH_RIGHT`, `n_survivors`, `from_ALP`, `from_GRN`, `from_IND`, `from_LNP`, `from_NAT`, `from_ONP`, `from_OTH`, `from_OTH_RIGHT`, `to_ALP`, `to_GRN`, `to_IND`, `to_LNP`, `to_NAT`, `to_ONP`, `to_OTH`, `to_OTH_RIGHT`, `region_fed`, `region_nsw`, `region_qld`, `region_sa`, `region_vic`, `region_wa` |
| `xgb-flows-weighted-oof.csv` | 1 | 36,064 | `election`, `seat`, `round`, `from`, `to`, `y`, `uniform`, `decay_hl8`, `decay_hl4`, `region_only`, `seat_name_only`, `seat_region_x3`, `seat_region_x6`, `decay8_region`, `decay8_seatregion`, `decay8_reg_seat` |
| `xgb-primary-asat-manifest.csv` | 1 | 35 | `target`, `cutoff_date`, `n_train_pairs`, `train_pairs`, `n_train_rows`, `nrounds`, `n_features`, `rmse_base`, `rmse_asat`, `model_file`, `git_hash`, `built_at`, `input_key` |
| `xgb-primary-asat-predictions.csv` | 1 | 17,010 | `pair`, `seat`, `party`, `base_pred`, `actual_share`, `xgb_pred`, `jump`, `governed`, `permit`, `surge_h`, `is_recipient` |
| `xgb-primary-features-vN.csv` | 2 | 14,041 | `seat`, `party`, `pair`, `pred_share`, `actual_share`, `x`, `n_cand_prev`, `n_cand_now`, `level_prev`, `level_now`, `same`, `same_mp`, `prior_leader_returns`, `own_prev_pcv`, `margin`, `fed_swing`, `retirement`, `soph_cand`, `soph_party`, `prev_swing`, `is_incumbent_party`, `historic_elected_any`, `ballot_pos_min`, `prev_pair`, `region`, `dev_prev`, `is_major` |
| `xgb-primary-features.csv` | 1 | 14,041 | `seat`, `party`, `pair`, `pred_share`, `actual_share`, `x`, `n_cand_prev`, `n_cand_now`, `level_prev`, `level_now`, `same`, `same_mp`, `prior_leader_returns`, `prev_pair`, `region`, `dev_prev`, `is_major` |
| `xgb-primary-flags-fixed.csv` | 1 | 13,314 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred`, `blend_old`, `blend_new`, `flag_old`, `flag_new` |
| `xgb-primary-groupsplit-oof.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `actual_share`, `pred_grp` |
| `xgb-primary-oof-predictions-vN.csv` | 3 | 14,495 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred_v2`, `jump`, `governed`, `permit` |
| `xgb-primary-oof-predictions.csv` | 1 | 13,314 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `xgb-primary-same-juris.csv` | 1 | 13,634 | `pair`, `seat`, `party`, `x`, `xgb_pred`, `actual_share`, `same_juris_pred`, `sj_r2`, `sj_n` |
| `xgb-primary-sd-oof.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `xgb_pred`, `actual_share`, `resid`, `sd_hat` |
| `xgb-primary-shipped-oof-predictions-BASELINE-preship.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `xgb-primary-shipped-oof-predictions-NAFILL.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `xgb-primary-shipped-oof-predictions.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `xgb-primary-vN-oof-predictions.csv` | 3 | 13,314 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `xgb-primary-vN-features.csv` | 2 | 19,071 | `pair`, `seat`, `party`, `actual_share`, `base_pred`, `seat_prev_pcv`, `seat_outperf`, `level_prev`, `level_pred`, `level_from_polls`, `dev_prev`, `x_notional_adj`, `n_cand_prev`, `n_cand_now`, `same_i`, `same_mp_i`, `is_major_i`, `margin`, `fed_swing`, `retirement_i`, `soph_cand_i`, `soph_party_i`, `prev_swing`, `is_incumbent_party_i`, `own_prev_pcv`, `historic_elected_i`, `ballot_pos_min`, `jump`, `governed`, `permit`, `surge_h`, `is_recipient`, `council_mayor`, `council_elected`, `council_lost`, `council_pct`, `c200`, `voices`, `party_ALP`, `party_GRN`, `party_IND`, `party_LNP`, `party_ONP`, `party_OTH`, `party_OTH_RIGHT`, `region_fed`, `region_nsw`, `region_nt`, `region_qld`, `region_sa`, `region_vic`, `region_wa` |
| `xgb-primary-vN-oof-BASEMARGIN-fresh.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `base_pred`, `actual_share`, `xgb_pred`, `jump`, `governed`, `permit`, `surge_h`, `is_recipient` |
| `xgb-primary-vN-oof-predictions-BASELINE.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `base_pred`, `actual_share`, `xgb_pred`, `jump`, `governed`, `permit`, `surge_h`, `is_recipient` |
| `xgb-primary-vN-oof-predictions-NAFILL.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `base_pred`, `actual_share`, `xgb_pred`, `jump`, `governed`, `permit`, `surge_h`, `is_recipient` |
| `xgb-primary-vN-shap.csv` | 1 | 616 | `pair`, `seat`, `party`, `actual_share`, `xgb_pred_oof_check`, `base_pred`, `seat_prev_pcv`, `seat_outperf`, `level_prev`, `level_pred`, `level_from_polls`, `dev_prev`, `x_notional_adj`, `n_cand_prev`, `n_cand_now`, `same_i`, `same_mp_i`, `is_major_i`, `margin`, `fed_swing`, `retirement_i`, `soph_cand_i`, `soph_party_i`, `prev_swing`, `is_incumbent_party_i`, `own_prev_pcv`, `historic_elected_i`, `ballot_pos_min`, `jump`, `governed`, `permit`, `surge_h`, `is_recipient`, `party_ALP`, `party_GRN`, `party_IND`, `party_LNP`, `party_ONP`, `party_OTH`, `party_OTH_RIGHT`, `region_fed`, `region_nsw`, `region_qld`, `region_sa`, `region_vic`, `region_wa`, `BIAS` |
| `xgb-primary-vN-arms.csv` | 1 | 13,739 | `pair`, `seat`, `party`, `actual_share`, `jump_pctile`, `sal_exp`, `ret_exp`, `cand_best_own_prev`, `cand_all_new`, `cand_n_returning`, `cand_n`, `pred_v7c`, `pred_v7f` |
| `xgb-primary-vNf-oof-predictions.csv` | 1 | 13,634 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `yougov-comparison.csv` | 1 | 88 | `seat`, `yg_win`, `our_win`, `our_p`, `yg_tpp`, `status`, `p_for_their_pick` |

_(2184 `backtest-*.csv` arm outputs omitted; they share one shape.)_


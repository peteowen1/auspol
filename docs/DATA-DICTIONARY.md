# Data dictionary

**Generated 2026-10-17 by `scripts/build_data_dictionary.R`. Do not hand-edit.**

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

| file | rows | columns |
|---|---:|---|
| `_prefix-shipped-oof-BACKUP.csv` | 13,739 | `pair`, `seat`, `party`, `pred_share`, `actual_share`, `xgb_pred` |
| `abc-scrape-primary.csv` | 5,720 | `party`, `name`, `pct`, `votes`, `pair`, `seat_slug` |
| `abc-scrape-tcp.csv` | 1,362 | `party`, `name`, `pct`, `votes`, `pair`, `seat_slug` |
| `ae-dependence-audit.csv` | 25 | `election`, `polls`, `ours`, `ae_filled`, `dispute`, `suspect`, `no_wiki`, `missing`, `label_ae`, `f30_polls`, `f30_ours`, `f30_ae_filled`, `f30_dispute`, `f30_suspect`, `f30_no_wiki`, `f30_missing`, `f30_label_ae`, `ae_share`, `f30_ae_share` |
| `ae-missing-split.csv` | 935 | `election`, `date`, `firm`, `ALP`, `LNP`, `final30`, `reason` |
| `aec-tpp-flows.csv` | 989 | `year`, `state`, `party_ab`, `party_name`, `party_class`, `row_type`, `alp_votes`, `lnp_votes`, `flow_alp`, `event`, `alp_pct_published`, `lnp_pct_published`, `source_file`, `file_header`, `n_states` |
| `aef-comparison-full.csv` | 681 | `seat`, `actual`, `our_pred`, `our_p`, `seeds`, `aef_pred`, `aef_p`, `aef_p_fav`, `delta`, `our_primary`, `actual_primary`, `aef_primary`, `pair`, `our_pe`, `aef_pe`, `prim_gap`, `why` |
| `aef-primary-all.csv` | 3,671 | `seat`, `party`, `aef_pcv`, `election` |
| `aef-seat-scores.csv` | 728 | `election`, `seat`, `actual`, `pred`, `pred_p`, `prob`, `tpp_actual` |
| `aef-worst-seats-full.csv` | 659 | `seat`, `actual`, `our_pred`, `our_p`, `aef_pred`, `aef_p`, `delta`, `our_primary_actual`, `actual_primary`, `aef_primary_actual`, `pair` |
| `aef7-artifact-current.csv` | 660 | `pair`, `seat`, `winner`, `fav`, `correct`, `our_p_win`, `our_p_fav`, `aef_p_win`, `aef_p_fav`, `our_fp_win`, `aef_fp_win`, `act_fp_win`, `miss`, `ll`, `aef_ll`, `grp`, `f1`, `f2`, `f2cp`, `fsrc`, `our_fp_fav`, `aef_fp_fav`, `act_fp_fav` |
| `aef7-artifact-refreshed.csv` | 660 | `pair`, `seat`, `winner`, `fav`, `correct`, `our_p_win`, `our_p_fav`, `aef_p_win`, `aef_p_fav`, `our_fp_win`, `aef_fp_win`, `act_fp_win`, `miss`, `ll`, `aef_ll`, `grp`, `f1`, `f2`, `f2cp`, `fsrc`, `our_fp_fav`, `aef_fp_fav`, `act_fp_fav` |
| `aef7-final-two-and-tcp-reference.csv` | 660 | `pair`, `seat`, `f1`, `f2`, `f2cp`, `fsrc`, `aef_tcp_f1`, `aef_tcp_f2`, `aef_tcp_pct`, `aef_tcp_scenario_freq`, `aef_tcp_p05`, `aef_tcp_p95` |
| `aef7-final-two-derived.csv` | 347 | `election`, `seat`, `f1`, `f2`, `f2cp`, `rule` |
| `aef7-fp.csv` | 4,448 | `pair`, `seat`, `aef_fp_party_idx`, `aef_fp_class`, `aef_fp_pct`, `aef_fp_p05`, `aef_fp_p95` |
| `aef7-fptrend.csv` | 3,671 | `seat`, `party`, `aef_fp_pred`, `pair` |
| `aef7-primary-common.csv` | 2,700 | `pair`, `seat`, `cl`, `ours`, `aef`, `actual` |
| `aef7-primary-truth-table.csv` | 4,620 | `pair`, `seat`, `party`, `itg_primary`, `official_primary`, `aef_primary`, `abc_primary` |
| `aef7-seat-groups.csv` | 34 | `pair`, `seat`, `grp` |
| `aef7-tcp-actual.csv` | 660 | `pair`, `seat`, `f1`, `f2`, `f2cp`, `our_tcp_actual_freq`, `our_tcp_pred_pct`, `our_tcp_actual_share`, `our_tcp_pick`, `our_tcp_pick_pct`, `aef_tcp_actual_freq`, `aef_tcp_pred_pct`, `aef_tcp_actual_share`, `aef_tcp_pick`, `aef_tcp_pick_pct` |
| `aef7-tcp-truth-table.csv` | 660 | `pair`, `seat`, `official_f1`, `official_f2`, `official_f2cp`, `official_fsrc`, `aef_tcp_f1`, `aef_tcp_pct`, `aef_tcp_freq`, `itg_tcp_f1`, `itg_tcp_f2`, `itg_tcp_pct`, `itg_tcp_freq`, `abc_tcp_f1`, `abc_tcp_f2`, `abc_tcp_pct` |
| `aef7-tcp.csv` | 681 | `pair`, `seat`, `aef_tcp_f1`, `aef_tcp_f2`, `aef_tcp_pct`, `aef_tcp_scenario_freq`, `aef_tcp_p05`, `aef_tcp_p95` |
| `anchor-k.csv` | 834 | `region`, `year`, `K`, `party`, `fitted`, `actual`, `prior`, `polls30`, `err`, `cyc` |
| `biggest-misses.csv` | 74 | `metric`, `pair`, `seat`, `party`, `candidate`, `ours`, `actual`, `err` |
| `bludgertrack-vs-layered.csv` | 541 | `region`, `bt_id`, `bt_cycle`, `date`, `firm`, `pollster_bt`, `mode_bt`, `sample_bt`, `source`, `und_bt`, `ALP_bt`, `ALP_layered`, `LNP_bt`, `LNP_layered`, `GRN_bt`, `GRN_layered`, `ONP_bt`, `ONP_layered`, `ALP_d`, `LNP_d`, `GRN_d`, `ONP_d` |
| `booth-rehearsal2-vic2022.csv` | 15 | `frac_of_night_vote`, `estimator`, `leader_correct`, `n`, `major_mae`, `major_rmse` |
| `booth-replay-vic2022.csv` | 5 | `frac_of_night_vote`, `mean_counted_share_of_all`, `fp_leader_correct`, `n`, `major_share_mae`, `major_share_rmse` |
| `booths-vic2018-2cp.csv` | 4,820 | `district`, `booth`, `booth_type`, `candidate`, `party`, `votes` |
| `booths-vic2018.csv` | 13,353 | `district`, `booth`, `booth_type`, `candidate`, `party`, `votes` |
| `booths-vic2022-2cp.csv` | 4,328 | `district`, `booth`, `booth_type`, `candidate`, `party`, `votes` |

_(1764 `backtest-*.csv` arm outputs omitted; they share one shape.)_


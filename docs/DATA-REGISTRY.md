# Data registry

**Generated 2026-10-06 by `scripts/build_data_registry.R`. Do not hand-edit** --
rerun the script instead. Regenerate it whenever you add or fetch data.

This file exists because the same data has been declared missing three
separate times while sitting on disk. **Check here before concluding we do
not have something.** Sizes are shown so a zero-byte or truncated file
cannot pass as a working one.

## Election results (`external/elections/`)

| file | size |
|---|---:|
| `aec-fed-firstprefs.csv` | 176 KB |
| `aec-fed-tcp.csv` | 63 KB |
| `aec-fed-transfers.csv` | 610 KB |
| `aec-fed-winners.csv` | 25 KB |
| `ecq-2017-qld-firstprefs.csv` | 8 KB |
| `ecq-2017-qld-winners.csv` | 2 KB |
| `ecq-2020-qld-firstprefs.csv` | 11 KB |
| `ecq-2024-qld-firstprefs.csv` | 10 KB |
| `ecq-qld-transfers.csv` | 97 KB |
| `ecq-qld-winners.csv` | 4 KB |
| `ecsa-2022-sa-firstprefs.csv` | 4 KB |
| `ecsa-2026-sa-firstprefs.csv` | 6 KB |
| `ecsa-2026-sa-onp-shares.csv` | 1 KB |
| `ecsa-2026-sa-transfers.csv` | 44 KB |
| `ecsa-sa-winners.csv` | 2 KB |
| `fed-booth-map.csv` | 513 KB |
| `fed-swing-transposed-wa.csv` | 15 KB |
| `fed-swing-transposed.csv` | 43 KB |
| `federal-transposed-to-state.csv` | 178 KB |
| `MANIFEST.csv` | 787 B |
| `nswec-2015-nsw-firstprefs.csv` | 10 KB |
| `nswec-2019-nsw-firstprefs.csv` | 10 KB |
| `nswec-2023-nsw-firstprefs.csv` | 10 KB |
| `nswec-nsw-transfers.csv` | 131 KB |
| `nswec-nsw-winners.csv` | 7 KB |
| `vec-2010-vic-firstprefs.csv` | 9 KB |
| `vec-2010-vic-transfers.csv` | 22 KB |
| `vec-2010-vic-winners.csv` | 3 KB |
| `vec-2014-vic-firstprefs.csv` | 9 KB |
| `vec-2014-vic-transfers.csv` | 27 KB |
| `vec-2014-vic-winners.csv` | 1 KB |
| `vec-2018-vic-firstprefs.csv` | 8 KB |
| `vec-2018-vic-transfers.csv` | 20 KB |
| `vec-2018-vic-winners.csv` | 1 KB |
| `vec-2022-vic-candidates.csv` | 41 KB |
| `vec-2022-vic-firstprefs.csv` | 10 KB |
| `vec-2022-vic-transfers.csv` | 71 KB |
| `vec-2022-vic-winners.csv` | 1 KB |
| `waec-1996-wa-firstprefs.csv` | 4 KB |
| `waec-2001-wa-firstprefs.csv` | 6 KB |
| `waec-2005-wa-firstprefs.csv` | 6 KB |
| `waec-2008-wa-firstprefs.csv` | 5 KB |
| `waec-2013-wa-firstprefs.csv` | 5 KB |
| `waec-2017-wa-firstprefs.csv` | 7 KB |
| `waec-2021-wa-firstprefs.csv` | 7 KB |
| `waec-2025-wa-firstprefs.csv` | 7 KB |
| `waec-wa-transfers.csv` | 231 KB |
| `waec-wa-winners.csv` | 10 KB |
| `wikipedia-2018-sa-firstprefs.csv` | 12 KB |
| `wikipedia-2018-sa-winners.csv` | 963 B |

## Raw commission downloads (`external/reference/`)

- **aec/** -- 1192 files, 870.6 MB
  - e.g. booths/fed2016-NSW.csv, booths/fed2016-QLD.csv, booths/fed2016-VIC.csv, booths/fed2019-QLD.csv
- **vec/** -- 2429 files, 73.5 MB
  - e.g. 2006/vc/fpv-albertpark.html, 2006/vc/fpv-altona.html, 2006/vc/fpv-ballarateast.html, 2006/vc/fpv-ballaratwest.html
- **nsw/** -- 5885 files, 80.2 MB
  - e.g. byelections/SB1602-orange-fp.html, byelections/SB1801-wagga-wagga-fp.html, council/2008/lgeindex.html, council/2008/pages/result.Albury.html
- **ecsa/** -- 378 files, 61.2 MB. **1 ZERO-BYTE: ha-2018-03-17.json**
  - e.g. 2018/Adelaide.html, 2018/Adelaide2.html, 2018/Badcoe.html, 2018/Badcoe2.html
- **ecq/** -- 1624 files, 101.8 MB
  - e.g. council/2008/aurukunshire/councillor_summary.html, council/2008/aurukunshire/mayoral_summary.html, council/2008/balonneshire/councillor_summary.html, council/2008/balonneshire/mayoral_summary.html
- **waec/** -- 1916 files, 49.0 MB
  - e.g. app.html, app.min.js, config-loader.js, config.json
- **trends/** -- 4673 files, 2.8 MB
  - e.g. 2019_anch2_Adrian_Wone_Susie_Beveridge_Will_Landers_Ammar_Khan.rds, 2019_anch2_Bill_Chandler_Susan_Moylan_Dave_Blake_Tim_Bohm.rds, 2019_anch2_Robert_Oakeshott_Helen_Haines_Zali_Steggall_Kerryn_Phelps.rds, 2019_anch2_Trevor_Jones_Colin_Butland_David_Norman_Thor_Prohaska.rds
- **boundaries/** -- 75 files, 770.5 MB
  - e.g. AEC-2025-esri.zip, AEC_2025/AUS_ELB_region.dbf, AEC_2025/AUS_ELB_region.prj, AEC_2025/AUS_ELB_region.shp
- **census/** -- 20 files, 77.4 MB
  - e.g. 2016_GCP_CED_AUS.zip, 2016_GCP_SED_NSW.zip, 2016_GCP_SED_QLD.zip, 2016_GCP_SED_SA.zip
- **correspondences/** -- 31 files, 1.6 MB
  - e.g. abs-sed/CG_CED_2016_CED_2021.csv, abs-sed/CG_SED_2016_SED_2021.csv, abs-sed/CG_SED_2021_SED_2022.csv, abs-sed/CG_SED_2022_SED_2024.csv
- **aef/** -- 17 files, 4.8 MB
  - e.g. 2022fed-results.json, 2022fed-summary.json, 2022sa-results.json, 2022sa-summary.json
- **polls/** -- 85 files, 40.1 MB. **1 ZERO-BYTE: crosstabs-ambiguous.txt**
  - e.g. demosau/crosstabs-ambiguous.txt, demosau/crosstabs.csv, demosau/raw/fed-2026-01.pdf, demosau/raw/fed-2026-01b.pdf

## Candidate-level corpus (`output/candidacies.csv`)

Built by `scripts/build_candidacies.R`. This is the only place candidate
NAMES live -- the per-seat results files carry `seat, party, votes` only.

| election | seats | candidates | IND | non-major breakouts |
|---|---:|---:|---:|---:|
| fed2004 | 150 | 1081 | 99 | 6 |
| fed2007 | 150 | 1050 | 102 | 6 |
| fed2010 | 150 | 844 | 82 | 12 |
| fed2013 | 150 | 1184 | 74 | 9 |
| fed2016 | 150 | 992 | 126 | 20 |
| fed2019 | 151 | 1054 | 98 | 21 |
| fed2022 | 151 | 1202 | 98 | 33 |
| fed2025 | 150 | 1122 | 129 | 35 |
| nsw2015 | 93 | 540 | 59 | 11 |
| nsw2019 | 93 | 568 | 52 | 15 |
| nsw2023 | 93 | 562 | 68 | 19 |
| qld2017 | 93 | 453 | 95 | 49 |
| qld2020 | 93 | 597 | 69 | 13 |
| qld2024 | 93 | 525 | 38 | 14 |
| sa2018 | 47 | 264 | 51 | 12 |
| sa2022 | 47 | 240 | 20 | 6 |
| sa2026 | 47 | 388 | 34 | 31 |
| vic2010 | 88 | 502 | 75 | 9 |
| vic2014 | 88 | 545 | 91 | 9 |
| vic2018 | 88 | 507 | 102 | 9 |
| vic2022 | 87 | 731 | 119 | 13 |
| vic2026 | 88 | 501 | 32 | NA |
| wa1996 | 57 | 232 | 36 | 7 |
| wa2001 | 57 | 366 | 89 | 12 |
| wa2005 | 57 | 375 | 42 | 3 |
| wa2008 | 59 | 302 | 25 | 6 |
| wa2013 | 59 | 291 | 39 | 2 |
| wa2017 | 59 | 415 | 34 | 2 |
| wa2021 | 59 | 463 | 17 | 0 |
| wa2025 | 59 | 398 | 29 | 6 |

**Total: 18294 candidacies, 30 elections, NA non-major breakouts.**

## State booth results (`output/booths/`)

Every state lower-house result by polling place, one schema:
`election,district,booth,vote_type,candidate,party_raw,votes,lat,lon,source_file`.
Built by `scripts/parse_booths_vic.py`, `parse_booths_nsw_qld.py`,
`parse_booths_sa_wa.py` from raw pages fetched by `fetch_vec_booths.py`,
`fetch_ecsa_booths_2018.sh` and the existing commission fetchers. Each
parser checks booth sums against the district results above.

| file | districts | polling places | rows | votes | places with coordinates |
|---|---:|---:|---:|---:|---:|
| nsw2015-booth-fp.csv | 93 | 2900 | 22118 | 4404334 | 0 |
| nsw2019-booth-fp.csv | 93 | 2516 | 20520 | 4551886 | 0 |
| nsw2023-booth-fp.csv | 93 | 2620 | 20933 | 4701930 | 0 |
| qld2017-booth-fp.csv | 93 | 13419 | 68148 | 2703941 | 1489 |
| qld2020-booth-fp.csv | 93 | 1513 | 15186 | 2868324 | 1996 |
| qld2020-booth-tcp.csv | 93 | 1513 | 4736 | 2868324 | 1996 |
| qld2024-booth-fp.csv | 93 | 1356 | 12598 | 3105945 | 1761 |
| qld2024-booth-tcp.csv | 93 | 1356 | 4452 | 3105945 | 1761 |
| sa2018-booth-fp.csv | 47 | 701 | 4148 | 1048713 | 0 |
| sa2018-booth-tcp.csv | 47 | 701 | 1496 | 1048713 | 0 |
| sa2022-booth-fp.csv | 47 | 695 | 3904 | 1091173 | 0 |
| sa2022-booth-tcp.csv | 47 | 695 | 1484 | 1091173 | 0 |
| sa2026-booth-fp.csv | 47 | 694 | 11364 | 1116641 | 0 |
| sa2026-booth-tcp.csv | 47 | 694 | 2738 | 1113989 | 0 |
| vic2006-booth-fp.csv | 87 | 2059 | 12809 | 2931336 | 0 |
| vic2006-booth-tcp.csv | 88 | 2092 | 4888 | 2965031 | 0 |
| vic2010-booth-fp.csv | 88 | 1839 | 12985 | 3164729 | 0 |
| vic2010-booth-tcp.csv | 88 | 1839 | 4558 | 3168259 | 0 |
| vic2014-booth-fp.csv | 88 | 1786 | 13838 | 3355707 | 0 |
| vic2014-booth-tcp.csv | 88 | 1786 | 4452 | 3359817 | 0 |
| vic2018-booth-fp.csv | 88 | 1794 | 12861 | 3510905 | 0 |
| vic2018-booth-tcp.csv | 88 | 1794 | 4468 | 3515878 | 0 |
| vic2022-booth-fp.csv | 87 | 1729 | 17976 | 3617000 | 1729 |
| vic2022-booth-tcp.csv | 87 | 1729 | 4328 | 3626239 | 1729 |
| wa2005-booth-fp.csv | 57 | 877 | 7308 | 1071953 | 0 |
| wa2008-booth-fp.csv | 59 | 855 | 5804 | 1089257 | 0 |
| wa2013-booth-fp.csv | 59 | 853 | 5490 | 1184432 | 0 |
| wa2017-booth-fp.csv | 59 | 811 | 7435 | 1321640 | 0 |
| wa2021-booth-fp.csv | 59 | 795 | 8270 | 1411990 | 0 |
| wa2025-booth-fp.csv | 59 | 802 | 6694 | 1527968 | 0 |

## Known gaps

Listed so a gap is a recorded fact rather than something rediscovered:

- **WA 1996 / 2001 booths** -- every per-booth candidate cell in the WAEC
  JSON is 0, so no state booth results before 2005 (district totals exist).
- **SA 2026 booths** -- the ECSA change file repeats a declaration block in
  Black and King (district-level rows; polling places unaffected).
- **Queensland 2020 / 2024** -- XML on disk, not yet parsed to candidates.
- **WA** -- per-seat JSON back to 1996, not yet parsed to candidates.
- **Google Trends** -- only ~63 of the corpus has a cached response, and
  every one is federal. No state candidacy has ever been queried.


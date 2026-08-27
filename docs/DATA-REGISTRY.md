# Data registry

**Generated 2026-08-28 by `scripts/build_data_registry.R`. Do not hand-edit** --
rerun the script instead. Regenerate it whenever you add or fetch data.

This file exists because the same data has been declared missing three
separate times while sitting on disk. **Check here before concluding we do
not have something.** Sizes are shown so a zero-byte or truncated file
cannot pass as a working one.

## Election results (`external/elections/`)

| file | size |
|---|---:|
| `aec-fed-firstprefs.csv` | 153 KB |
| `aec-fed-tcp.csv` | 56 KB |
| `aec-fed-transfers.csv` | 531 KB |
| `aec-fed-winners.csv` | 22 KB |
| `ecq-2020-qld-firstprefs.csv` | 11 KB |
| `ecq-2024-qld-firstprefs.csv` | 10 KB |
| `ecq-qld-transfers.csv` | 97 KB |
| `ecq-qld-winners.csv` | 4 KB |
| `ecsa-2022-sa-firstprefs.csv` | 4 KB |
| `ecsa-2026-sa-firstprefs.csv` | 6 KB |
| `ecsa-2026-sa-onp-shares.csv` | 1 KB |
| `ecsa-2026-sa-transfers.csv` | 44 KB |
| `ecsa-sa-winners.csv` | 2 KB |
| `fed-swing-transposed.csv` | 43 KB |
| `federal-transposed-to-state.csv` | 178 KB |
| `MANIFEST.csv` | 787 B |
| `nswec-2019-nsw-firstprefs.csv` | 10 KB |
| `nswec-2023-nsw-firstprefs.csv` | 10 KB |
| `nswec-nsw-transfers.csv` | 90 KB |
| `nswec-nsw-winners.csv` | 5 KB |
| `vec-2014-vic-firstprefs.csv` | 9 KB |
| `vec-2014-vic-transfers.csv` | 27 KB |
| `vec-2014-vic-winners.csv` | 1 KB |
| `vec-2018-vic-firstprefs.csv` | 8 KB |
| `vec-2018-vic-transfers.csv` | 20 KB |
| `vec-2018-vic-winners.csv` | 1 KB |
| `vec-2022-vic-candidates.csv` | 28 KB |
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

## Raw commission downloads (`external/reference/`)

- **aec/** -- 32 files, 36.7 MB
  - e.g. booths/fed2016-NSW.csv, booths/fed2019-SA.csv, booths/fed2019-VIC.csv, booths/fed2022-NSW.csv
- **vec/** -- 318 files, 1.9 MB
  - e.g. 2014/albertparkdistrict.html, 2014/altonadistrict.html, 2014/bassdistrict.html, 2014/bayswaterdistrict.html
- **nsw/** -- 197 files, 6.3 MB
  - e.g. dop-sample.html, dop/index-SG1901.html, dop/index-SG2301.html, dop/SG1901-albury.html
- **ecsa/** -- 9 files, 2.9 MB. **1 ZERO-BYTE: ha-2018-03-17.json**
  - e.g. ha-2018-03-17.json, ha-2022-03-19.json, ha-2026-03-21.json, ha-change-2022-03-19.json
- **ecq/** -- 7 files, 47.4 MB
  - e.g. elections.json, publicResults_SGE2024_ICCDiv4_Final.zip, publicResults_State2020_aurukun2020_Final.zip, qld2020.xml
- **waec/** -- 481 files, 19.4 MB
  - e.g. app.html, app.min.js, config-loader.js, config.json
- **trends/** -- 2491 files, 1.6 MB
  - e.g. 2019_anch2_Adrian_Wone_Susie_Beveridge_Will_Landers_Ammar_Khan.rds, 2019_anch2_Bill_Chandler_Susan_Moylan_Dave_Blake_Tim_Bohm.rds, 2019_anch2_Robert_Oakeshott_Helen_Haines_Zali_Steggall_Kerryn_Phelps.rds, 2019_anch2_Trevor_Jones_Colin_Butland_David_Norman_Thor_Prohaska.rds
- **boundaries/** -- 20 files, 157.6 MB
  - e.g. SED_2021.zip, SED_2021_AUST_GDA2020.CPG, SED_2021_AUST_GDA2020.dbf, SED_2021_AUST_GDA2020.prj
- **census/** -- 4 files, 18.0 MB
  - e.g. 2021_GCP_SED_NSW.zip, 2021_GCP_SED_SA.zip, 2021_GCP_SED_VIC.zip, census-sed-2021.csv
- **correspondences/** -- 12 files, 899 KB
  - e.g. booths-2018vic.csv, booths-2018vic.txt, booths-2019nsw.csv, booths-2019nsw.txt
- **aef/** -- 16 files, 4.1 MB
  - e.g. 2022fed-results.json, 2022fed-summary.json, 2022sa-results.json, 2022sa-summary.json

## Candidate-level corpus (`output/candidacies.csv`)

Built by `scripts/build_candidacies.R`. This is the only place candidate
NAMES live -- the per-seat results files carry `seat, party, votes` only.

| election | seats | candidates | IND | non-major breakouts |
|---|---:|---:|---:|---:|
| fed2007 | 150 | 1050 | 102 | 6 |
| fed2010 | 150 | 844 | 82 | 12 |
| fed2013 | 150 | 1184 | 74 | 9 |
| fed2016 | 150 | 992 | 126 | 20 |
| fed2019 | 151 | 1054 | 98 | 21 |
| fed2022 | 151 | 1202 | 98 | 33 |
| fed2025 | 150 | 1122 | 129 | 35 |
| nsw2019 | 93 | 568 | 52 | 15 |
| nsw2023 | 93 | 562 | 68 | 19 |
| qld2020 | 93 | 597 | 69 | 13 |
| qld2024 | 93 | 525 | 38 | 14 |
| sa2022 | 47 | 240 | 20 | 6 |
| sa2026 | 47 | 388 | 34 | 31 |
| vic2014 | 88 | 545 | 91 | 9 |
| vic2018 | 88 | 507 | 102 | 9 |
| vic2022 | 87 | 731 | 119 | 13 |
| wa1996 | 57 | 232 | 36 | 7 |
| wa2001 | 57 | 366 | 89 | 12 |
| wa2005 | 57 | 375 | 42 | 3 |
| wa2008 | 59 | 302 | 25 | 6 |
| wa2013 | 59 | 291 | 39 | 2 |
| wa2017 | 59 | 415 | 34 | 2 |
| wa2021 | 59 | 463 | 17 | 0 |
| wa2025 | 59 | 398 | 29 | 6 |

**Total: 14953 candidacies, 24 elections, 303 non-major breakouts.**

## Known gaps

Listed so a gap is a recorded fact rather than something rediscovered:

- **SA 2018** -- `external/reference/ecsa/ha-2018-03-17.json` is **0 bytes**,
  a download that failed and was never noticed. Needs refetching.
- **Victoria 2014 / 2018** -- only per-district HTML in
  `external/reference/vec/2014` and `/2018`; no candidate extract yet.
- **Queensland 2020 / 2024** -- XML on disk, not yet parsed to candidates.
- **WA** -- per-seat JSON back to 1996, not yet parsed to candidates.
- **Google Trends** -- only ~63 of the corpus has a cached response, and
  every one is federal. No state candidacy has ever been queried.


# Census features with the census taken BEFORE each election (2026-10-13)

Why it matters: the shipped demographic correction (`AUSPOL_DEMO_RESID=2`) reads seven census columns, and older pairs were
given a census taken after their election. This build replaces that with the preceding census, and says on every row when it
could not.
Built by `scripts/build_census_features_vintage.R`, which writes `output/census-features-vintage.csv` (2,553 rows, 26 pairs).
Nothing existing was edited; the orchestrator swaps the file in. Check codes `CW*`. Run time about 1 minute.

## What the old file really contained (verified)

- Federal pairs fed2007-fed2016 used `census-ced-2016.csv`: the 2016 census, 9 Aug 2016, after all four elections.
- State pairs: the old `vintage` column ("2021", "2022", "2024", "2025") is the BOUNDARY year, not the census year. The
  `census-sed-2016-reaggregated-to-X.csv` files are 2016 census data (national `Tot_P_P` 21,197,487 against 21,197,492 in the
  raw 2016 SED file and 24,173,345 in the 2021 file). So vic2022/vic2026 and every pre-2022 state pair ran on the 2016 census.
  This means pre-2016 state pairs (vic2014, wa2001-wa2013) had look-ahead, and 2022+ pairs ran on a census older than the one
  available. The predecessor note that "vic2026 uses 2021" was a misreading of that label.
- The new file's `vintage` is the census year of the DATA, so the two files' `vintage` columns do not mean the same thing.

## Rule and the one place I departed from the brief

Census taken before polling day, by date (8 Aug 2006, 9 Aug 2011, 9 Aug 2016, 10 Aug 2021). **fed2016 (2 Jul 2016) takes 2011**,
not 2016: the 2016 census came five weeks after that election. Pete's wording ("2016 for 2016-2020") would give it a census
taken after polling day. One line flips it: `PREF_OVERRIDE <- c(fed2016 = "2016")` at the top of the script. wa2021 (13 Mar 2021)
correctly takes 2016. wa2001 and wa2005 predate the 2006 census and the 2001 census is not on disk: they take 2006, flagged.

## Feature mapping (CW1)

2011 BCP table B01 (CED and SED) has the same 108 cells, in the same order and with the same column names, as the 2016/2021 G01
columns the old script reads. 2006 BCP table B01 (state folders under `bcp-cgia/`) has the same 108 cells named `B1..B108`;
they are renamed positionally to the 2011 names, and the 16 cells the features read are asserted against
`BCP2006_cell_desc_dp.xls` (e.g. the Year 12 cell must read "Highest year of school completed: Year 12 or equivalent, Persons"). Male + female =
persons holds in all four files. `derive()` is a verbatim copy of the old one, so definitions are identical:
yr12 (Yr 12 over Yr 12/11/10/9/8-or-below), born in Australia, Indigenous, 55-84, 15-34, other language at home, 25+ attending
an educational institution (all over total persons except yr12). Names: 2006 from `Census2006_geog_desc.xls` (CED07 for the 2007
boundaries, SED), 2011 from the geog sheet inside each zip. Non-geographic rows (no usual address, migratory, offshore) dropped;
CED 150 divisions in 2006/2011/2016, 151 in 2021.

## Source order per (pair, seat)

A: preferred census geography, when the election's contested seat set equals the geography's seat set (boundaries identical,
`exact` TRUE). B: state pairs with preferred census 2016 or later and no identical geography: the old file's 2016-census row
reaggregated onto the election's boundaries (older census on the right boundaries, not look-ahead). C: preferred census matched
by seat name (boundaries differ). D: nearest later census by name (LOOKAHEAD). F: federal divisions found only in the 2006 census
on 2004 boundaries. E: the old row (LOOKAHEAD where its census post-dates the election). Every row carries `vintage_note`;
look-ahead rows start with `LOOKAHEAD:`.

## Per pair (CW4; rows, census used, share of rows on identical boundaries, rows with no data, LOOKAHEAD rows)

Rows differ from the old file because the cell list also includes the previous election's seats.

| pair | polling day | census used | rows | exact | no data | LOOKAHEAD |
|---|---|---|---|---|---|---|
| fed2007 | 2007-11-24 | 2006 | 151 | 99% | 0 | 0 |
| fed2010 | 2010-08-21 | 2006 / 2011 | 153 | 0% | 0 | 3 (Durack, McMahon, Wright new in 2010) |
| fed2013 | 2013-09-07 | 2011 | 150 | 100% | 0 | 0 |
| fed2016 | 2016-07-02 | 2011 / 2016 | 153 | 0% | 0 | 3 (Burt, Fenner, Whitlam) |
| fed2019 | 2019-05-18 | 2016 / 2021 | 158 | 0% | 0 | 8 (new divisions) |
| fed2022 | 2022-05-21 | 2021 (+2016 for abolished) | 152 | 99% | 0 | 0 |
| fed2025 | 2025-05-03 | 2021 | 152 | 0% | 1 (Bullwinkel, new) | 0 |
| nsw2019 | 2019-03-23 | 2016 | 93 | 100% | 0 | 0 |
| nsw2023 / nsw2027 | 2023-03-25 / 2027-03-13 | 2016 (2016 census on election boundaries) | 98 / 93 | 95% / 100% | 0 | 0 |
| qld2020 | 2020-10-31 | 2016 | 93 | 0% | 0 | 0 |
| qld2024 | 2024-10-26 | 2021 | 93 | 100% | 0 | 0 |
| sa2022 | 2022-03-19 | 2021 | 47 | 100% | 0 | 0 |
| sa2026 | 2026-03-21 | 2016 (on 2025 boundaries) | 48 | 98% | 0 | 0 |
| vic2010 (new) | 2010-11-27 | 2006 | 88 | 100% | 0 | 0 |
| vic2014 | 2014-11-29 | 2011 / 2016 | 103 | 0% | 0 | 15 (districts new in 2014) |
| vic2018 | 2018-11-24 | 2016 | 88 | 100% | 0 | 0 |
| vic2022 / vic2026 | 2022-11-26 / 2026-11-28 | 2016 (on election boundaries) | 97 / 88 | 91% / 100% | 0 | 0 |
| wa2001 | 2001-02-10 | 2006 / 2011 / 2021 | 57 | 0% | 6 | 51 (no census before it on disk) |
| wa2005 | 2005-02-26 | 2006 / 2011 / 2021 | 68 | 0% | 7 | 61 (same) |
| wa2008 | 2008-09-06 | 2006 / 2011 | 78 | 0% | 1 | 21 |
| wa2013 | 2013-03-09 | 2011 / 2016 | 63 | 0% | 0 | 4 |
| wa2017 | 2017-03-11 | 2016 / 2021 | 64 | 0% | 5 | 3 |
| wa2021 | 2021-03-13 | 2016 / 2021 | 60 | 80% | 0 | 3 |
| wa2025 | 2025-03-08 | 2016 / 2021 | 65 | 86% | 0 | 0 |

`exact` of 0% for a state pair means the 2006/2011 SED boundaries differ from the election's (redistribution) and names were
matched instead: those rows have the right census but approximate boundaries. 20 rows have no data anywhere (fed2025 Bullwinkel;
WA seats whose names exist in no census file: Burrup, Collie, Innaloo, Mitchell, Ningaloo, Roleystone, Serpentine-Jarrahdale,
Alfred Cove, Eyre, Gosnells, Ocean Reef, Wagin). The old file had the same holes plus more.

## Vintage proof (CW5)

| pair | polling day | census used | census day | before the election |
|---|---|---|---|---|
| fed2007 | 2007-11-24 | 2006 | 2006-08-08 | yes |
| vic2010 | 2010-11-27 | 2006 | 2006-08-08 | yes |
| nsw2019 | 2019-03-23 | 2016 | 2016-08-09 | yes |
| fed2016 | 2016-07-02 | 2011 | 2011-08-09 | yes |

## New against old where the census year changed (CW6; n = 1,116 rows with data in both)

Correlation across seats (1.00 = same ranking); difference is new minus old in percentage points. Pooled over all changed rows:

| feature | correlation | mean difference | SD of difference |
|---|---|---|---|
| yr12_pct | 0.920 | -5.19 | 5.32 |
| born_aus_pct | 0.947 | +2.60 | 3.73 |
| indig_pct | 0.894 | -0.35 | 2.32 |
| over55_pct | 0.835 | -1.63 | 3.05 |
| under35_pct | 0.910 | +0.14 | 2.19 |
| lang_other_pct | 0.932 | -2.80 | 5.59 |
| edu_25plus_pct | 0.898 | -0.24 | 0.60 |

Per pair the federal and Victorian rows correlate 0.87-0.99 (fed2007 yr12 0.975, over55 0.867); WA 2001-2013 are lower
(0.49-0.85) because names were matched across redistributions. The signs are what a census five to ten years earlier should
give: less Year 12, fewer overseas-born, fewer other-language speakers, younger. CW7: no changed-census row equals its old row.

## What the swap changes for the live forecast (decide before swapping)

- qld2024 and sa2022 move from the 2016 census to the 2021 census (exact boundaries). vic2022/vic2026 and nsw2023/nsw2027 stay
  on the 2016 census because the 2021 SED files for Vic and NSW carry the pre-redistribution districts (vic2022: 78 of 87
  contested seats are named in the 2021 SED; nsw2023: 88 of 93). A true 2021 census needs a 2021-to-2022 reaggregation, not on disk.
- Pre-2016 state pairs other than vic2010 are mostly name-matched (boundaries differ) or carry LOOKAHEAD rows; only vic2010 is
  clean on boundaries. A boundary-weighted 2006/2011 reaggregation needs the older election boundary files (not on disk).
- `census-sed-2016.csv` has only 35 of 59 WA districts (a gap in the existing file, not in this build): wa2017 and wa2021 therefore
  take the old reaggregated rows. Worth re-fetching the WA 2016 SED.
- No consumer code reads the `vintage` values (grep of R/education_residual.R, R/demographic_residual.R, fit_xgb_primary_v7.R: comments only), so the changed meaning is safe for them.

## Not done

2001 census (wa2001, wa2005, fed2001/2004); tests; wiring `AUSPOL_DEMO_RESID` to the new file; re-measuring the correction.

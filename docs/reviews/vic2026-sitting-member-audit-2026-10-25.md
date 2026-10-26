# vic2026 sitting-member flags: audit, cause and fix (2026-10-25)

Why this matters: `historic_elected` in `output/candidacies.csv` is the only column that
tells the live Victorian forecast a candidate is a sitting member. Three of its TRUE values
were people who are not sitting members, and seven real sitting members carried FALSE. The
live forecast feeds it to the XGBoost primary-vote model as `historic_elected_i`.

Status: **the flags in the published `output/candidacies.csv` are still wrong (live), and
merging this branch does not change that.** The fix is behind a build-time switch,
`AUSPOL_RETURNING_MEMBER_RULE`, default `"0"` (the old flag, `candidacies.csv`
byte-identical). `"1"` is the corrected rule. The flag is also a TRAINING feature
(`historic_elected_i`), so it flips only through a deliberate rebuild-and-retrain (sequence
below). Nothing was rebuilt: the worktree has no `external/` inputs, and the main
checkout's `output/` was not touched.

## Counts

Counts are rows of `vic2026` in `output/candidacies.csv` (n = 500 candidacies, 88 seats) and
the 87 current Legislative Assembly members listed by the Parliament of Victoria.

| What | n |
|---|---|
| vic2026 candidacies flagged `historic_elected = TRUE` (old file) | 63 |
| of those, verified as the sitting member for that seat | 60 |
| of those, WRONG (not a sitting member) | 3 (Jess Kennedy, Reece Clark, Ali Cupper) |
| sitting members recontesting (candidate row found) | 67 |
| of those, MISSING the flag in the old file | 7 |
| sitting members with no candidate row (not recontesting, or not yet listed) | 20, unverifiable |
| flagged TRUE under the corrected rule (`AUSPOL_RETURNING_MEMBER_RULE=1`, not yet adopted) | 67, equal to the verified recontesting set |

## Sources

- Current members: Parliament of Victoria member search API, Legislative Assembly, status
  current (87 hits; saved raw), page
  <https://www.parliament.vic.gov.au/members/member-search/?member-house=10&member-status=current>.
  Each row below links the member's own Parliament page.
- 2022 general election winners: the VEC's 87 per-district result pages under
  <https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results>
  (all 87 saved raw; the 88th seat, Narracan, has no 2022 page, see Cause).
- By-elections and supplementary elections this term: VEC timeline
  <https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline>
  and the six per-district pages linked in
  `external/reference/byelections/byelection-winner-names.csv` (new file, one VEC URL per row).
- Wikipedia was used only to find the by-election list, not for any verdict.

Raw pages were saved before parsing, in the session scratch directory (not committed:
third-party pages).

## Cause

`scripts/build_candidacies.R`, block BC9, derived the state `historic_elected` as "this
candidate's key (SURNAME plus FIRST INITIAL) equals a winner's key at ANY earlier election in
the region". Three separate defects:

1. **Name key too loose.** `KENNEDY|J` matched John Ormond Kennedy (ALP, Hawthorn, elected
   2018) for Jess Kennedy (Greens, Bayswater). `CLARK|R` matched Robert Clark (LNP, Box Hill,
   elected 2010 and 2014) for Reece Clark (Liberal, Werribee). Different people, same
   surname and initial.
2. **"Any earlier election".** Ali Cupper won Mildura in 2018, lost it to Jade Benham in 2022,
   and was flagged as sitting. A former member is not an incumbent.
3. **By-elections ignored, compound surnames split.** Eden Foster (Mulgrave 2023), Rachel
   Westaway (Prahran 2025), John Lister (Werribee 2025), Nicole Werner (Warrandyte 2023) and
   Anthony Marsh (Nepean 2026) won by-elections and are absent from the 2022 results, so they
   read FALSE. Wayne Farnham (Narracan) won the January 2023 supplementary election: the
   2022 poll for Narracan did not complete, so the corpus has no Narracan row for 2022 at
   all (the VEC lists Narracan under "supplementary election"; the reason the poll was
   postponed was not checked here). Meng Heang Tak (Clarinda) is filed `TAK, Meng Heang` in
   2022 and `HEANG TAK, Meng` in 2026, so the surname key never joined.

This is the `CLAUDE.md` trap "`load_seats(Y)$incumbent` is who holds the seat NOW" in a
different place: a field derived from names across elections and read as a statement about
the present.

## Fix

- `R/returning_member.R` (new): `same_person()` (surname, or last word of a compound surname
  with the same full first name; first initial must agree; `given_conflict()` rules out
  Jess/John and Reece/Robert), `returning_member_flags()` (winner of the region's PREVIOUS
  general election; a by-election or supplementary winner dated strictly between the
  previous and this general election, compared as full dates against `election_dates()`,
  supersedes that seat's general-election winner; the last by-election in a seat decides)
  and `missing_byelection_names()`.
- A by-election seat with no previous-general-election winner row prints an `RMF1!` line
  (winner added, nobody removed). On the real corpus it fires twice, both legitimate:
  vic2010 (Albert Park, Williamstown, Kororoit, Altona: the corpus has no vic2006 winner
  rows at all) and vic2026 (Narracan: no 2022 row, the poll did not complete).
- `scripts/build_candidacies.R` BC9: `AUSPOL_RETURNING_MEMBER_RULE` picks the rule. `"0"`
  (default) runs the old code unchanged; `"1"` runs the new one and first `stop()`s,
  naming each one, if any by-election between a target election and its predecessor has no
  winner name. `.parse_name()` was split out of `.key()` (`.key()` output is identical).
  The switch is in `scripts/published_flags.R` (`"0"`), classified in
  `scripts/build_model_registry.R`, and `docs/MODEL-REGISTRY.md` is regenerated (247 switches).
- By-election winner names: `external/reference/byelections/byelection-winner-names.csv`,
  108 rows, one per row of `byelection-winners.csv` outside the federal level: nsw 38,
  nt 12, qld 16, sa 10, vic 18, wa 14. Sources: 6 rows (the 2023-26 Victorian ones) are
  from the VEC result pages, URL on each row. The other 102 are winner names from the
  Wikipedia by-election list for that state, the same page `byelection-winners.csv` already
  cites; 36 of them were checked against candidate lists in `byelection-results.csv` (36
  of 36 found). **66 of the 102 Wikipedia names are NOT independently verified against
  the NSWEC, ECQ, ECSA, WAEC, NTEC or VEC.** Northcote 2017 is Lidia Thorpe (Greens); at
  vic2018 the rule flags her as sitting (Northcote vic2018 row: THORPE, Lidia FALSE under
  rule 0, TRUE under rule 1) and does not flag Kat Theophanous, the 2018 winner.
- Federal rows still carry the AEC's own `HistoricElected`.
- Tests: `tests/testthat/test-returning-member.R` and `test-returning-member-window.R`
  (37 expectations, none skipped, all pass). They first assert that the legacy rule flags
  Kennedy, Clark and Cupper (so they would fail if the old logic came back), then that the
  new rule does not, and cover by-election supersession, full-date windows, the Thorpe
  case, the loud orphan line, the unnamed-by-election stop, name coverage of the tracked
  file against every state window, and the default of the switch. **BC9 itself cannot run
  in a test**: it needs `external/` inputs that CI and worktrees lack. The wiring test only
  guards the default; the branch logic was checked separately (next paragraph).

Checks on the real file (main checkout's `candidacies.csv`, read only, nothing written):

1. The legacy branch, extracted from the builder as written, reproduces the deployed
   `historic_elected` on all 13,829 state rows (0 differences), so the default is a no-op.
2. The new rule on vic2026: 63 to 67 flags, exactly the three removals and seven additions
   in the tables below.
3. The new rule on the other state elections, with all 108 by-election names and dates:
   173 TRUE flags removed and 84 added, a net drop of 89 (earlier draft: 167, before all
   by-elections had names). Of the 173 removed, 147 are former members (won at an election
   before the previous one only), 20 matched a previous winner on surname and initial but
   have a different first name, and 6 are previous winners whose seat a by-election gave to
   someone else. Of the 84 added, 83 are by-election or supplementary winners and 1 is a
   previous winner the old key missed. Across all state rows, TRUE goes from 1,832 to 1,747.

The builder itself was parsed but not run end to end: the worktree lacks the `external/`
inputs it reads.

## Where the column is read

No other column in `candidacies.csv` says "sitting": the ABC `Sitting MP` badge and
Wikipedia's `sitting` flag are dropped at `scripts/build_candidacies.R:1390-1391` (the
`BC10c` provenance line). The leader-seat file (`output/leader-seat-vic2026.csv`) has leader
names but no sitting flag. `output/retirement-derived.csv` has no vic2026 rows.

Reads of `historic_elected`:

| Read site | What it does | Moves the published forecast? |
|---|---|---|
| `R/xgb_primary_override.R:249-251`, `:471-484` | builds the live model's `historic_elected_i`, a feature of the XGBoost primary-vote model | **Yes.** Called by `xgb_primary_predict_live()` from `scripts/fit_seats_full.R:1479`; `AUSPOL_XGB_PRIMARY_LIVE=1` in `scripts/published_flags.R:88` |
| `scripts/fit_xgb_primary_v6.R:444-446`, `:666`, `:816`; also `v5` (`:131-133`, `:180`), `fit_xgb_primary_v5_final.R:32`, `fit_xgb_primary_v6_final.R:49` | builds `historic_elected_i` for every training election | Only on retrain. The deployed trees were fitted on the OLD flags for the other state elections |
| `scripts/fit_xgb_emergence_v4.R:15`, `fit_xgb_emergence_v5.R:66`, `scripts/build_emergence_cases_v2.R:94` | emergence model feature | Only on rebuild or retrain |
| `scripts/diag_defector_holders.R:19` | diagnostic | No |
| `scripts/build_candidacies.R` BC9 | the flag is created here | Source |

Not affected: the same-person logic in `R/candidate_returns.R` (`same_mp`, `mp_departed`)
reads the previous election's `elected` plus by-election winners (`byelection_winner_rows()`),
so Werribee's incumbent class there is already Labor.

Which published seats the flags touch (seat x party-class rows of `historic_elected_i`; the
model reads one value per row):

| Seat | Row | Old | New |
|---|---|---|---|
| Bayswater | GRN | 1 (wrong) | 0 |
| Werribee | LNP | 1 (wrong) | 0 |
| Mildura | IND | 1 (wrong) | 0 |
| Werribee | ALP | 0 (missing) | 1 |
| Mulgrave | ALP | 0 (missing) | 1 |
| Prahran | LNP | 0 (missing) | 1 |
| Warrandyte | LNP | 0 (missing) | 1 |
| Nepean | LNP | 0 (missing) | 1 |
| Narracan | LNP | 0 (missing) | 1 |
| Clarinda | ALP | 0 (missing) | 1 |

**Size of the effect: not measured.** It needs the live forecast run with and without the
corrected flags. The feature is a single binary input among many to a model whose
`base_margin` is the pre-xgb share, so no per-seat number can be read from the code. The
direction: a wrongly flagged challenger is handed an incumbent bonus (Greens in Bayswater,
Liberal in Werribee, Cupper in Mildura), and the seven unflagged incumbents lose theirs.

## What to do next (Pete decides)

The flag is a training feature as well as a live one, so the rule must change for training
and live together. The deployed trees were fitted on rule `"0"` flags; building with `"1"`
and not retraining would make the live feature mean something the trees never saw.

Rebuild-and-retrain sequence that flips it (run outside a session; `rebuild_forecasts.sh`
is a multi-hour job):

1. In one commit set `AUSPOL_RETURNING_MEMBER_RULE = "1"` in `scripts/published_flags.R`
   and regenerate `docs/MODEL-REGISTRY.md` (`Rscript scripts/build_model_registry.R`).
2. From a checkout that has `external/`:
   `AUSPOL_CAND_ALLOW_OTHER_CHANGE=1 Rscript scripts/build_candidacies.R`. The override is
   needed because BC11 stops when any non-vic2026 line changes, and most other state
   elections change (item 3 above). Check the BC9r line says rule 1, the BC9b line lists
   108 names, and no `BC9!` stop fired. Regenerate `docs/DATA-REGISTRY.md`.
3. `AUSPOL_REBUILD_FROM=3 bash scripts/rebuild_forecasts.sh`. Stage 3 (`fit_xgb_primary_v6.R`)
   is the first stage that reads the flag (`xgb-primary-features-v6.csv`, and the
   leave-one-out predictions file); stage 4 refits the as-at models and the OOF pool
   (`xgb-primary-asat-predictions.csv`) the harnesses read; stage 5 refits the production
   model (`fit_xgb_primary_v6_final.R`) that the live forecast loads; stages 6-9 rerun the
   harnesses, pool, ledger and promote. Stages 1-2 do not read the flag.
4. The emergence model also reads the flag (`scripts/fit_xgb_emergence_v5.R`,
   `scripts/build_emergence_cases_v2.R:94`) and is outside `rebuild_forecasts.sh`; rerun it
   by hand if it feeds the live path (not checked here).
5. Walk the live forecast with and without the corrected flags before publishing, to size
   the ten seat rows above.

Only after step 3 completes should the live path read the new `candidacies.csv`: a rebuild
of `candidacies.csv` alone, with trees not retrained, is the mismatch to avoid.

Also:

- The corpus has no vic2026 row for Jacinta Allan (Bendigo East), listed below among the
  members without a candidate row. If she is standing, that is a nomination-list gap, not a
  flag error.
- The corpus has no vic2006 winner rows, so the rule cannot supersede the 2006 member in
  the four 2007-10 by-election seats for vic2010 (the `RMF1!` line). vic2010 flags are
  unchanged from "0" except for the 4 by-election winners themselves.

## Sitting members recontesting (67): all verified

Old flag = the value in the file as found; new flag = after the fix. n = 67.

| Seat | vic2026 candidate (class) | Official member (Parliament of Victoria) | Old flag | New flag | Verdict | How the member got the seat | Sources |
|---|---|---|---|---|---|---|---|
| Albert Park | TAYLOR, Nina (ALP) | Nina Taylor | yes | yes | verified | 2022 general, VEC winner TAYLOR, Nina | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/albert-park-district-results), [POV](https://www.parliament.vic.gov.au/members/nina-taylor/) |
| Ashwood | FREGON, Matt (ALP) | Matt Fregon | yes | yes | verified | 2022 general, VEC winner FREGON, Matt | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/ashwood-district-results), [POV](https://www.parliament.vic.gov.au/members/matt-fregon/) |
| Bellarine | MARCHANT, Alison (ALP) | Alison Marchant | yes | yes | verified | 2022 general, VEC winner MARCHANT, Alison | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/bellarine-district-results), [POV](https://www.parliament.vic.gov.au/members/alison-marchant/) |
| Bentleigh | STAIKOS, Nick (ALP) | Nick Staikos | yes | yes | verified | 2022 general, VEC winner STAIKOS, Nick | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/bentleigh-district-results), [POV](https://www.parliament.vic.gov.au/members/nick-staikos/) |
| Berwick | BATTIN, Brad (LNP) | Brad Battin | yes | yes | verified | 2022 general, VEC winner BATTIN, Brad | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/berwick-district-results), [POV](https://www.parliament.vic.gov.au/members/brad-battin/) |
| Box Hill | HAMER, Paul (ALP) | Paul Hamer | yes | yes | verified | 2022 general, VEC winner HAMER, Paul | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/box-hill-district-results), [POV](https://www.parliament.vic.gov.au/members/paul-hamer/) |
| Brighton | NEWBURY, James (LNP) | James Newbury | yes | yes | verified | 2022 general, VEC winner NEWBURY, James | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/brighton-district-results), [POV](https://www.parliament.vic.gov.au/members/james-newbury/) |
| Broadmeadows | MATTHEWS-WARD, Kathleen (ALP) | Kathleen Matthews-Ward | yes | yes | verified | 2022 general, VEC winner MATTHEWS-WARD, Kathleen | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/broadmeadows-district-results), [POV](https://www.parliament.vic.gov.au/members/kathleen-matthews-ward/) |
| Bulleen | GUY, Matthew (LNP) | Matthew Guy | yes | yes | verified | 2022 general, VEC winner GUY, Matthew | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/bulleen-district-results), [POV](https://www.parliament.vic.gov.au/members/matthew-guy/) |
| Bundoora | BROOKS, Colin (ALP) | Colin Brooks | yes | yes | verified | 2022 general, VEC winner BROOKS, Colin | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/bundoora-district-results), [POV](https://www.parliament.vic.gov.au/members/colin-brooks/) |
| Carrum | KILKENNY, Sonya (ALP) | Sonya Kilkenny | yes | yes | verified | 2022 general, VEC winner KILKENNY, Sonya | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/carrum-district-results), [POV](https://www.parliament.vic.gov.au/members/sonya-kilkenny/) |
| Caulfield | SOUTHWICK, David (LNP) | David Southwick | yes | yes | verified | 2022 general, VEC winner SOUTHWICK, David | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/caulfield-district-results), [POV](https://www.parliament.vic.gov.au/members/david-southwick/) |
| Clarinda | HEANG TAK, Meng (ALP) | Meng Heang Tak | no | yes | verified (flag was MISSING) | 2022 general, VEC winner TAK, Meng Heang | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/clarinda-district-results), [POV](https://www.parliament.vic.gov.au/members/meng-heang-tak/) |
| Cranbourne | RICHARDS, Pauline (ALP) | Pauline Richards | yes | yes | verified | 2022 general, VEC winner RICHARDS, Pauline | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/cranbourne-district-results), [POV](https://www.parliament.vic.gov.au/members/pauline-richards/) |
| Dandenong | WILLIAMS, Gabrielle (ALP) | Gabrielle Williams | yes | yes | verified | 2022 general, VEC winner WILLIAMS, Gabrielle | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/dandenong-district-results), [POV](https://www.parliament.vic.gov.au/members/gabrielle-williams/) |
| Eildon | MCLEISH, Cindy (LNP) | Cindy McLeish | yes | yes | verified | 2022 general, VEC winner McLEISH, Cindy | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/eildon-district-results), [POV](https://www.parliament.vic.gov.au/members/cindy-mcleish/) |
| Eltham | WARD, Vicki (ALP) | Vicki Ward | yes | yes | verified | 2022 general, VEC winner WARD, Vicki | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/eltham-district-results), [POV](https://www.parliament.vic.gov.au/members/vicki-ward/) |
| Eureka | SETTLE, Michaela (ALP) | Michaela Settle | yes | yes | verified | 2022 general, VEC winner SETTLE, Michaela | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/eureka-district-results), [POV](https://www.parliament.vic.gov.au/members/michaela-settle/) |
| Euroa | CLEELAND, Annabelle (LNP) | Annabelle Cleeland | yes | yes | verified | 2022 general, VEC winner CLEELAND, Annabelle | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/euroa-district-results), [POV](https://www.parliament.vic.gov.au/members/annabelle-cleeland/) |
| Evelyn | VALLENCE, Bridget (LNP) | Bridget Vallence | yes | yes | verified | 2022 general, VEC winner VALLENCE, Bridget | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/evelyn-district-results), [POV](https://www.parliament.vic.gov.au/members/bridget-vallence/) |
| Footscray | HALL, Katie (ALP) | Katie Hall | yes | yes | verified | 2022 general, VEC winner HALL, Katie | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/footscray-district-results), [POV](https://www.parliament.vic.gov.au/members/katie-hall/) |
| Frankston | EDBROOKE, Paul (ALP) | Paul Edbrooke | yes | yes | verified | 2022 general, VEC winner EDBROOKE, Paul | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/frankston-district-results), [POV](https://www.parliament.vic.gov.au/members/paul-edbrooke/) |
| Geelong | COUZENS, Christine (ALP) | Chris Couzens | yes | yes | verified | 2022 general, VEC winner COUZENS, Christine | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/geelong-district-results), [POV](https://www.parliament.vic.gov.au/members/chris-couzens/) |
| Gippsland South | O'BRIEN, Danny (LNP) | Danny O'Brien | yes | yes | verified | 2022 general, VEC winner O'BRIEN, Danny | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/gippsland-south-district-results), [POV](https://www.parliament.vic.gov.au/members/danny-obrien/) |
| Glen Waverley | MULLAHY, John (ALP) | John Mullahy | yes | yes | verified | 2022 general, VEC winner MULLAHY, John | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/glen-waverley-district-results), [POV](https://www.parliament.vic.gov.au/members/john-mullahy/) |
| Greenvale | WALTERS, Iwan (ALP) | Iwan Walters | yes | yes | verified | 2022 general, VEC winner WALTERS, Iwan | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/greenvale-district-results), [POV](https://www.parliament.vic.gov.au/members/iwan-walters/) |
| Hastings | MERCURIO, Paul (ALP) | Paul Mercurio | yes | yes | verified | 2022 general, VEC winner MERCURIO, Paul | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/hastings-district-results), [POV](https://www.parliament.vic.gov.au/members/paul-mercurio/) |
| Hawthorn | PESUTTO, John (LNP) | John Pesutto | yes | yes | verified | 2022 general, VEC winner PESUTTO, John | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/hawthorn-district-results), [POV](https://www.parliament.vic.gov.au/members/john-pesutto/) |
| Ivanhoe | CARBINES, Anthony (ALP) | Anthony Carbines | yes | yes | verified | 2022 general, VEC winner CARBINES, Anthony | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/ivanhoe-district-results), [POV](https://www.parliament.vic.gov.au/members/anthony-carbines/) |
| Kalkallo | SPENCE, Ros (ALP) | Ros Spence | yes | yes | verified | 2022 general, VEC winner SPENCE, Ros | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/kalkallo-district-results), [POV](https://www.parliament.vic.gov.au/members/ros-spence/) |
| Kew | WILSON, Jess (LNP) | Jess Wilson | yes | yes | verified | 2022 general, VEC winner WILSON, Jess | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/kew-district-results), [POV](https://www.parliament.vic.gov.au/members/jess-wilson/) |
| Kororoit | GRIGOROVITCH, Luba (ALP) | Luba Grigorovitch | yes | yes | verified | 2022 general, VEC winner GRIGOROVITCH, Luba | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/kororoit-district-results), [POV](https://www.parliament.vic.gov.au/members/luba-grigorovitch/) |
| Lara | GEORGE, Ella (ALP) | Ella George | yes | yes | verified | 2022 general, VEC winner GEORGE, Ella | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/lara-district-results), [POV](https://www.parliament.vic.gov.au/members/ella-george/) |
| Laverton | CONNOLLY, Sarah (ALP) | Sarah Connolly | yes | yes | verified | 2022 general, VEC winner CONNOLLY, Sarah | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/laverton-district-results), [POV](https://www.parliament.vic.gov.au/members/sarah-connolly/) |
| Lowan | KEALY, Emma (LNP) | Emma Kealy | yes | yes | verified | 2022 general, VEC winner KEALY, Emma | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/lowan-district-results), [POV](https://www.parliament.vic.gov.au/members/emma-kealy/) |
| Melbourne | SANDELL, Ellen (GRN) | Ellen Sandell | yes | yes | verified | 2022 general, VEC winner SANDELL, Ellen | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/melbourne-district-results), [POV](https://www.parliament.vic.gov.au/members/ellen-sandell/) |
| Mildura | BENHAM, Jade (LNP) | Jade Benham | yes | yes | verified | 2022 general, VEC winner BENHAM, Jade | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/mildura-district-results), [POV](https://www.parliament.vic.gov.au/members/jade-benham/) |
| Monbulk | DE MARTINO, Daniela (ALP) | Daniela De Martino | yes | yes | verified | 2022 general, VEC winner DE MARTINO, Daniela | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/monbulk-district-results), [POV](https://www.parliament.vic.gov.au/members/daniela-de-martino/) |
| Mordialloc | RICHARDSON, Tim (ALP) | Tim Richardson | yes | yes | verified | 2022 general, VEC winner RICHARDSON, Tim | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/mordialloc-district-results), [POV](https://www.parliament.vic.gov.au/members/tim-richardson/) |
| Mornington | CREWTHER, Chris (LNP) | Chris Crewther | yes | yes | verified | 2022 general, VEC winner CREWTHER, Chris | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/mornington-district-results), [POV](https://www.parliament.vic.gov.au/members/chris-crewther/) |
| Morwell | CAMERON, Martin (LNP) | Martin Cameron | yes | yes | verified | 2022 general, VEC winner CAMERON, Martin | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/morwell-district-results), [POV](https://www.parliament.vic.gov.au/members/martin-cameron/) |
| Mulgrave | FOSTER, Eden (ALP) | Eden Foster | no | yes | verified (flag was MISSING) | by-election/supplementary 2023-11-18 (VEC) | [VEC](https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline/mulgrave-district-by-election-results/results-by-district/mulgrave-district-by-election-results), [POV](https://www.parliament.vic.gov.au/members/eden-foster/) |
| Narracan | FARNHAM, Wayne (LNP) | Wayne Farnham | no | yes | verified (flag was MISSING) | by-election/supplementary 2023-01-28 (VEC) | [VEC](https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline/narracan-district-supplementary-election-results), [POV](https://www.parliament.vic.gov.au/members/wayne-farnham/) |
| Narre Warren North | WILSON, Belinda (ALP) | Belinda Wilson | yes | yes | verified | 2022 general, VEC winner WILSON, Belinda | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/narre-warren-north-district-results), [POV](https://www.parliament.vic.gov.au/members/belinda-wilson/) |
| Nepean | MARSH, Anthony (LNP) | Anthony Marsh | no | yes | verified (flag was MISSING) | by-election/supplementary 2026-05-02 (VEC) | [VEC](https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline/nepean-by-election-results/results-by-district/nepean-district-results), [POV](https://www.parliament.vic.gov.au/members/anthony-marsh/) |
| Niddrie | CARROLL, Ben (ALP) | Ben Carroll | yes | yes | verified | 2022 general, VEC winner CARROLL, Ben | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/niddrie-district-results), [POV](https://www.parliament.vic.gov.au/members/ben-carroll/) |
| Northcote | THEOPHANOUS, Kat (ALP) | Kat Theophanous | yes | yes | verified | 2022 general, VEC winner THEOPHANOUS, Kat | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/northcote-district-results), [POV](https://www.parliament.vic.gov.au/members/kat-theophanous/) |
| Oakleigh | DIMOPOULOS, Steve (ALP) | Steve Dimopoulos | yes | yes | verified | 2022 general, VEC winner DIMOPOULOS, Steve | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/oakleigh-district-results), [POV](https://www.parliament.vic.gov.au/members/steve-dimopoulos/) |
| Ovens Valley | MCCURDY, Tim (LNP) | Tim McCurdy | yes | yes | verified | 2022 general, VEC winner McCURDY, Tim | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/ovens-valley-district-results), [POV](https://www.parliament.vic.gov.au/members/tim-mccurdy/) |
| Pascoe Vale | CIANFLONE, Anthony (ALP) | Anthony Cianflone | yes | yes | verified | 2022 general, VEC winner CIANFLONE, Anthony | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/pascoe-vale-district-results), [POV](https://www.parliament.vic.gov.au/members/anthony-cianflone/) |
| Point Cook | HILAKARI, Mathew (ALP) | Mathew Hilakari | yes | yes | verified | 2022 general, VEC winner HILAKARI, Mathew | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/point-cook-district-results), [POV](https://www.parliament.vic.gov.au/members/mathew-hilakari/) |
| Polwarth | RIORDAN, Richard (LNP) | Richard Riordan | yes | yes | verified | 2022 general, VEC winner RIORDAN, Richard | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/polwarth-district-results), [POV](https://www.parliament.vic.gov.au/members/richard-riordan/) |
| Prahran | WESTAWAY, Rachel (LNP) | Rachel Westaway | no | yes | verified (flag was MISSING) | by-election/supplementary 2025-02-08 (VEC) | [VEC](https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline/prahran-district-results/results-by-district/prahran-district-results), [POV](https://www.parliament.vic.gov.au/members/rachel-westaway/) |
| Preston | LAMBERT, Nathan (ALP) | Nathan Lambert | yes | yes | verified | 2022 general, VEC winner LAMBERT, Nathan | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/preston-district-results), [POV](https://www.parliament.vic.gov.au/members/nathan-lambert/) |
| Richmond | DE VIETRI, Gabrielle (GRN) | Gabrielle de Vietri | yes | yes | verified | 2022 general, VEC winner DE VIETRI, Gabrielle | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/richmond-district-results), [POV](https://www.parliament.vic.gov.au/members/gabrielle-de-vietri/) |
| Ripon | HAYLETT, Martha (ALP) | Martha Haylett | yes | yes | verified | 2022 general, VEC winner HAYLETT, Martha | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/ripon-district-results), [POV](https://www.parliament.vic.gov.au/members/martha-haylett/) |
| Sandringham | ROWSWELL, Brad (LNP) | Brad Rowswell | yes | yes | verified | 2022 general, VEC winner ROWSWELL, Brad | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/sandringham-district-results), [POV](https://www.parliament.vic.gov.au/members/brad-rowswell/) |
| South-West Coast | BRITNELL, Roma (LNP) | Roma Britnell | yes | yes | verified | 2022 general, VEC winner BRITNELL, Roma | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/south-west-coast-district-results), [POV](https://www.parliament.vic.gov.au/members/roma-britnell/) |
| St Albans | SULEYMAN, Natalie (ALP) | Natalie Suleyman | yes | yes | verified | 2022 general, VEC winner SULEYMAN, Natalie | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/st-albans-district-results), [POV](https://www.parliament.vic.gov.au/members/natalie-suleyman/) |
| Sunbury | BULL, Josh (ALP) | Josh Bull | yes | yes | verified | 2022 general, VEC winner BULL, Josh | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/sunbury-district-results), [POV](https://www.parliament.vic.gov.au/members/josh-bull/) |
| Tarneit | WIGHT, Dylan (ALP) | Dylan Wight | yes | yes | verified | 2022 general, VEC winner WIGHT, Dylan | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/tarneit-district-results), [POV](https://www.parliament.vic.gov.au/members/dylan-wight/) |
| Thomastown | HALFPENNY, Bronwyn (ALP) | Bronwyn Halfpenny | yes | yes | verified | 2022 general, VEC winner HALFPENNY, Bronwyn | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/thomastown-district-results), [POV](https://www.parliament.vic.gov.au/members/bronwyn-halfpenny/) |
| Warrandyte | WERNER, Nicole (LNP) | Nicole Werner | no | yes | verified (flag was MISSING) | by-election/supplementary 2023-08-26 (VEC) | [VEC](https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline/warrandyte-district-by-election-results/results-by-district/warrandyte-district-results), [POV](https://www.parliament.vic.gov.au/members/nicole-werner/) |
| Wendouree | ADDISON, Juliana (ALP) | Juliana Addison | yes | yes | verified | 2022 general, VEC winner ADDISON, Juliana | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/wendouree-district-results), [POV](https://www.parliament.vic.gov.au/members/juliana-addison/) |
| Werribee | LISTER, John (ALP) | John Lister | no | yes | verified (flag was MISSING) | by-election/supplementary 2025-02-08 (VEC) | [VEC](https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline/werribee-district-results/results-by-district/werribee-district-results), [POV](https://www.parliament.vic.gov.au/members/john-lister/) |
| Williamstown | HORNE, Melissa (ALP) | Melissa Horne | yes | yes | verified | 2022 general, VEC winner HORNE, Melissa | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/williamstown-district-results), [POV](https://www.parliament.vic.gov.au/members/melissa-horne/) |
| Yan Yean | KATHAGE, Lauren (ALP) | Lauren Kathage | yes | yes | verified | 2022 general, VEC winner KATHAGE, Lauren | [VEC](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/yan-yean-district-results), [POV](https://www.parliament.vic.gov.au/members/lauren-kathage/) |


## Wrong flags (3), none a sitting member

Verdict: wrong. Official check: not in the Parliament of Victoria current-member list for
that seat.

| Seat | Candidate | Why it was flagged | Who actually holds the seat | Sources |
|---|---|---|---|---|
| Bayswater | KENNEDY, Jess (Greens) | matched John Ormond Kennedy, Hawthorn 2018 | Jackson Taylor (ALP), won 2022 general | [VEC Bayswater](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/bayswater-district-results) |
| Werribee | CLARK, Reece (Liberal) | matched Robert Clark, Box Hill 2010/2014 | John Lister (ALP), won the 8 February 2025 by-election after Tim Pallas | [VEC Werribee by-election](https://www.vec.vic.gov.au/results/state-election-results/state-by-elections-timeline/werribee-district-results/results-by-district/werribee-district-results) |
| Mildura | CUPPER, Ali (Independent) | won Mildura 2018, any-earlier-election rule | Jade Benham, won 2022 general | [VEC Mildura](https://www.vec.vic.gov.au/results/state-election-results/2022-state-election-results/results-by-district/mildura-district-results) |

Cupper's 2018 win is from this corpus's own vic2018 rows, not re-fetched from the VEC. Her
loss in 2022 is the VEC Mildura page above.

## Sitting members with no vic2026 candidate row (20): unverifiable

Unverifiable means: the member is confirmed current by the Parliament of Victoria, but
whether they are standing cannot be confirmed from an official source (the VEC publishes no
candidate list until nominations close). Flags for these seats' candidates are FALSE both
before and after, so nothing here depends on the answer. Tim Read (Greens, Brunswick, won 2022
per the VEC) is absent from the current-member list (87 of 88 seats listed) and has no
candidate row; his current status was not established.

| Seat | Sitting member | Party | Status | Verdict | Source |
|---|---|---|---|---|---|
| Bass | Jordan Crugnale | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/jordan-crugnale/) |
| Bayswater | Jackson Taylor | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/jackson-taylor/) |
| Benambra | Bill Tilley | Liberal Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/bill-tilley/) |
| Bendigo East | Jacinta Allan | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/jacinta-allan/) |
| Bendigo West | Maree Edwards | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/maree-edwards/) |
| Croydon | David Hodgett | Liberal Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/david-hodgett/) |
| Essendon | Danny Pearson | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/danny-pearson/) |
| Gippsland East | Tim Bull | The Nationals | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/tim-bull/) |
| Macedon | Mary-Anne Thomas | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/mary-anne-thomas/) |
| Malvern | Michael O'Brien | Liberal Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/michael-obrien/) |
| Melton | Steve McGhie | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/steve-mcghie/) |
| Mill Park | Lily D'Ambrosio | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/lily-dambrosio/) |
| Murray Plains | Peter Walsh | The Nationals | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/peter-walsh/) |
| Narre Warren South | Gary Maas | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/gary-maas/) |
| Pakenham | Emma Vulin | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/emma-vulin/) |
| Ringwood | Will Fowles | Independent | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/will-fowles/) |
| Rowville | Kim Wells | Liberal Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/kim-wells/) |
| Shepparton | Kim O'Keeffe | The Nationals | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/kim-okeeffe/) |
| South Barwon | Darren Cheeseman | Independent | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/darren-cheeseman/) |
| Sydenham | Natalie Hutchins | Australian Labor Party | no candidate row in candidacies.csv | unverifiable (retirement not confirmable from an official source: the VEC candidate list does not exist until nominations close) | [POV](https://www.parliament.vic.gov.au/members/natalie-hutchins/) |

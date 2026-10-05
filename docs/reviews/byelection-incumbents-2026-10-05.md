# By-election winners: are they invisible to the model? (cluster A, 2026-10-05)

Read-only investigation. Nothing in `R/`, `scripts/` or `output/` was edited and no harness or
fit script was run. Throwaway R scripts (read-only calls to `candidate_returns()`,
`byelection_winner_rows()` and CSV reads) are in the session scratchpad `clusterA/`.

Data: `output/forecasts.csv` (built 2026-10-02, 18 elections, 11,905 rows, one per seat x party
class), `output/xgb-primary-v6-features.csv` (13,758 rows, same build), `output/candidacies.csv`.
Signed error = `actual_share - xgb_pred` (points of primary vote; positive = under-called).

## Verdict

**The hypothesis as stated is wrong, and the right version is different.** A by-election winner
is NOT invisible as a sitting member. `AUSPOL_BYELECTION_MP` (default `"1"`, shipped
2026-09-19) already rewrites the previous election's `elected` flags, and the feature file
confirms `same_mp_i = 1` and `is_incumbent_party_i = 1` for Oakeshott, Donato and McGirr. What
the model never receives is the winner's **personal vote level**, and the one place the
override does reach also quietly removes a correct signal from the party that lost the seat.
Four separate defects, all still live (checked against the 2026-10-02 build):

1. **Level missing, flag present (main cause).** `own_prev_pcv` is NA for 42 of the 43
   by-election winners that recontested (only Sharkie has a value, and hers comes from a
   general election). The class base the slope multiplies is the seat's general-election class
   share (Orange OTH_RIGHT 2.6, Wagga IND 9.7, Lyne IND 6.2), not the person's.
2. **By-election baseline only half-applied or skipped.** `AUSPOL_BYELECTION_PRIOR="blend"`
   moves the class prior only half way to the by-election result, and skips the seat entirely
   when a major party did not stand (Lyne: Labor did not stand).
3. **The party that LOST the seat loses its "departed member" flag.** The override clears the
   seat's `elected` flags, so the defeated major no longer reads `mp_departed`. Orange LNP,
   Wagga LNP and Lyne LNP all flip TRUE to FALSE; they were over-called by 20.0, 10.9 and 15.1
   points.
4. **Latent: `leader_same` ignores the override.** `leading_candidate_returns()` is called with
   the un-overridden corpus, so Donato and McGirr read `same_mp = TRUE` but `leader_same =
   FALSE` (shown below). Masked today by the `same_mp` slope override; impact unconfirmed.

## 1. End-to-end walk: Orange 2019 (Philip Donato) and Lyne 2010 (Rob Oakeshott)

### Orange, nsw2019, class OTH_RIGHT

What happened: Donato (Shooters, Fishers and Farmers) won the 12 Nov 2016 Orange by-election on
23.76% of first preferences, after the National member left. At the 2019 general election the
OTH_RIGHT class polled 56.18 (Donato alone 49.15, three small right-wing candidates 7.03).
Model said `xgb_pred` 20.91, `base_pred` 14.92. Signed error +35.26. LNP class: predicted 45.80,
actual 25.82 (error -19.98).

| Step | What the code does | file:line |
|---|---|---|
| Previous election | `from = nsw2015`. Donato did not stand in 2015, so the general-election corpus has nothing for him. | `candidate_returns()` `R/candidate_returns.R:72-90` |
| By-election override | `byelection_winner_rows("nsw2015","nsw2019")` returns 8 seats incl. Orange=OTH_RIGHT, Wagga Wagga=IND. Orange's 2015 `elected` flags are set FALSE and a synthetic winner row (name "Philip Donato", `pcv` 23.76, `elected` TRUE) is appended to the previous election. | `R/candidate_returns.R:79-80`; `R/byelection_prior.R:173-203` |
| Returning member | Name matches 2019 "DONATO Philip", so `same = TRUE`, `same_mp = TRUE` for OTH_RIGHT. I reproduced this by calling `candidate_returns("nsw2015","nsw2019")`. Without the override both are FALSE. | `R/candidate_returns.R:168-177` |
| Feature the xgb layer sees | `same_i = 1`, `same_mp_i = 1`, `is_incumbent_party_i = 1`, `retirement_i = 0`, `soph_cand_i = 0`, `seat_prev_pcv = 2.587`, **`own_prev_pcv = NA`**, `historic_elected_i = NA`. | `output/xgb-primary-v6-features.csv`, row nsw2019/Orange/OTH_RIGHT; built by `R/xgb_primary_override.R:276-292` |
| Why `own_prev_pcv` is NA | It is the identity-matched candidate's best share at the previous GENERAL election, from `prev_best`. Donato has no 2015 row, and the synthetic by-election row is only used by `candidate_returns()`, not by this function. A fallback file, `output/nsw-byelection-prevpcv.csv` (Orange 23.76, Wagga 25.42), was built 2026-09-16 by `scripts/build_nsw_byelection_prevpcv.R`, but a grep of `R/` and `scripts/` finds no reader. | `R/candidate_returns.R:610`; header of `scripts/build_nsw_byelection_prevpcv.R` |
| Baseline (base_pred) | Harness log: "5 seat(s) replaced (Cootamundra, Gosford, Murray, Orange, Wagga Wagga)" (`output/rebuild-A.log:42`), so the by-election was used, but with `weight = 0.5`. By-election OTH_RIGHT class share is about 27.1 (Donato 23.76 + Christian Democrats 3.38); blended with the 2.59 general-election prior gives about 14.9, which is the `base_pred` of 14.92. | `R/byelection_prior.R:116`; `scripts/published_flags.R:162` (`"blend"`) |
| xgb layer | Adds +6.0 to 20.91. It learned from data in which sitting non-major members mostly hold their level, not from a case where the level is a one-off by-election share. | `output/forecasts.csv` |
| LNP class | With the override, `mp_departed` for Orange LNP is FALSE (the LNP member's `elected` flag was cleared). Without it, TRUE. So the 2.8-point departed-major tier never fires; LNP base_pred 45.24 vs actual 25.82. | `R/candidate_returns.R:79, 197-200`; `R/dev_slope.R:162-170` |

Why the by-election share understates the later level: Donato's 23.76% came in an eight-candidate,
low-turnout, single-issue contest; he then took 49.15% (56.18 for the class). Even a full
(weight 1.0) by-election baseline would give about 27 and still miss by about 29 points.
The flag being correct is necessary but nowhere near sufficient. The pattern is a first-term
surge ("sophomore") that the model has no feature for when the first win came at a by-election.

### Lyne, fed2010, class IND

Oakeshott won the 6 Sep 2008 Lyne by-election on 63.80% (Labor did not stand; his 2007 IND
class in the seat was only 6.16). At fed2010 he polled 47.15 (class 47.84). `xgb_pred` 7.73,
`base_pred` 7.29, signed +40.11 (the largest single error in the 11,905 rows).

| Step | What happens | file:line |
|---|---|---|
| Override | Lyne is in `byelection-winners.csv` (Independent) and `byelection-results.csv` (Oakeshott 63.80). Features show `same_mp_i = 1`, `is_incumbent_party_i = 1`. | `R/candidate_returns.R:72-90` |
| Baseline | `rebuild-A.log:46`: "1 seat(s) replaced (Gippsland); SKIPPED Lyne (a major did not stand), Mayo". Labor did not stand, so the by-election is not used as a baseline and the IND class prior stays at 6.16. `AUSPOL_BYELECTION_FILL` (fills the absent major back in) would have used it; it was refused 2026-09-30 because "only Lyne improved, xgb error +0.01" (`scripts/published_flags.R:169`). | `R/byelection_prior.R:95` |
| `own_prev_pcv` | NA (the by-election result is never a general-election row). | `R/candidate_returns.R:610` |
| LNP class | Predicted 49.47, actual 34.39 (-15.08). Mark Vaile (National) left, so LNP should read departed; with the override it does not (`dep0 TRUE`, `dep1 FALSE` in my re-run). | `R/candidate_returns.R:79, 197-200` |

Direction note for Lyne: here the by-election share (63.8) is ABOVE the next general-election
share (47.2). A fix that uses the by-election level at full weight over-calls Lyne by about 16
points but still cuts the miss from 40 to about 16. Orange and Wagga go the other way (by-election
level well below the later level), so no single scaling of the by-election share fits all three.

### Cases in the task list that are NOT by-election cases

* **Hinchinbrook qld2020, Nick Dametto**: won the seat at the 2017 GENERAL election (20.95%,
  `candidacies.csv` line 10358). The 2025 Hinchinbrook by-election is after qld2024. This is a
  first-term surge, not a by-election effect.
* **Stuart sa2022, Geoff Brock**: sitting member for Frome (won 2018 general, 45.97%) who moved to
  the new seat of Stuart. A redistribution case, not a by-election.
* **Wakehurst / Pittwater / Kiama nsw2023**: no by-election winner in the window. Pittwater
  (Oct 2024) and Kiama (Sep 2025) happened after nsw2023. Michael Regan (Wakehurst) won at the 2023 general.
* **Murray nsw2019 (Dalton), Barwon (Butler)**: not by-election winners (Austin Evans, who did win
  the 2017 Murray by-election, is in the table below and was over-called).

## 2. Inventory: by-election winners who recontested

Method: for each of the 18 elections in `forecasts.csv`, take the previous general election in the
same region (`election_dates()`), take the last by-election per seat in between from
`external/reference/byelections/byelection-winners.csv`, take the winner's name from
`byelection-results.csv` (highest share of the winning class), and match that name against the
target election in `output/candidacies.csv` with the same `surname_of`/`given_of`/`match_key`
used by `candidate_returns()`. Error columns come from the winner's party-class row in
`forecasts.csv`.

By-election data on disk (`external/reference/byelections/`): winners file has 92 by-elections
(fed 24, nsw 25, vic 15, wa 14, qld 9, sa 5); the candidate-level results file has rows for 54
of them (fed 19, nsw 13, vic 8, qld 6, wa 5, sa 3). **38 of 92 winners have no candidate-level
results**, so their names are unknown and they cannot be matched (listed in section 7). All six
jurisdictions have some data; none is complete.

Table: one row per by-election winner who recontested (n = 43 class rows). "By-elec %" is the
winner's first-preference share at the by-election; "Own %" is the winner's own share at the
target election; "Base" and "xgb" are the CLASS-row predictions; "Actual" is the class share.
Signed error is points of primary vote; positive means under-called; the farther from zero the
worse. `same_mp` is the model feature (1 = treated as returning sitting member). `own_prev_pcv`
was NA on every row except Sharkie.

| Election | Seat | Winner | Class | By-elec % | Own % | Base | xgb | Actual | Signed err | same_mp |
|---|---|---|---|--:|--:|--:|--:|--:|--:|--:|
| fed2010 | Lyne | Rob Oakeshott | IND | 63.80 | 47.15 | 7.29 | 7.73 | 47.84 | +40.11 | 1 |
| nsw2019 | Orange | Philip Donato | OTH_RIGHT | 23.76 | 49.15 | 14.92 | 20.91 | 56.18 | +35.26 | 1 |
| nsw2019 | Wagga Wagga | Joe McGirr | IND | 25.40 | 44.63 | 22.79 | 25.47 | 46.05 | +20.58 | 1 |
| nsw2019 | Murray | Austin Evans | LNP | 40.70 | 35.22 | 54.78 | 55.28 | 35.22 | -20.06 | 1 |
| vic2018 | South-West Coast | Roma Britnell | LNP | 40.00 | 32.38 | 50.87 | 49.58 | 32.38 | -17.20 | 1 |
| wa2017 | Vasse | Libby Mettam | LNP | 44.30 | 46.25 | 55.81 | 51.94 | 65.56 | +13.62 | 1 |
| nsw2019 | Cootamundra | Steph Cooke | LNP | 46.20 | 63.66 | 50.05 | 50.60 | 63.66 | +13.06 | 1 |
| fed2019 | Wentworth | Kerryn Phelps | IND | 29.19 | 32.43 | 9.41 | 23.08 | 33.01 | +9.93 | 1 |
| fed2019 | Braddon | Justine Keay | ALP | 36.98 | 32.06 | 39.82 | 40.41 | 32.06 | -8.35 | 1 |
| sa2026 | Bragg | Jack Batty | LNP | 50.50 | 50.03 | 39.13 | 40.10 | 48.34 | +8.24 | 1 |
| fed2019 | Mayo | Rebekha Sharkie | IND | 44.37 | 34.19 | 33.77 | 41.70 | 34.19 | -7.51 | 1 |
| fed2019 | Longman | Susan Lamb | ALP | 39.84 | 34.10 | 40.32 | 41.31 | 34.10 | -7.20 | 1 |
| fed2019 | Bennelong | John Alexander | LNP | 45.04 | 50.82 | 44.09 | 43.82 | 50.82 | +7.00 | 1 |
| fed2016 | Canning | Andrew Hastie | LNP | 46.92 | 50.30 | 45.94 | 47.85 | 54.53 | +6.68 | 1 |
| qld2020 | Bundamba | Lance McCallum | ALP | 42.20 | 55.92 | 49.43 | 49.32 | 55.92 | +6.60 | 1 |
| qld2024 | Inala | Margie Nightingale | ALP | 37.23 | 47.14 | 41.77 | 41.52 | 47.14 | +5.61 | 1 |
| nsw2023 | Strathfield | Jason Yat-Sen Li | ALP | 41.05 | 51.86 | 47.44 | 46.66 | 51.86 | +5.19 | 1 |
| fed2025 | Fadden | Cameron Caldwell | LNP | 49.08 | 40.96 | 43.45 | 45.49 | 40.96 | -4.53 | 1 |
| qld2020 | Currumbin | Laura Gerber | LNP | 43.80 | 40.24 | 44.34 | 44.73 | 40.24 | -4.50 | 1 |
| nsw2023 | Bega | Michael Holland | ALP | 43.16 | 45.07 | 38.69 | 40.58 | 45.07 | +4.49 | 1 |
| nsw2019 | Wollongong | Paul Scully | ALP | 48.10 | 50.11 | 45.18 | 45.65 | 50.11 | +4.47 | 1 |
| fed2016 | Griffith | Terri Butler | ALP | 38.63 | 33.18 | 36.57 | 37.35 | 33.18 | -4.16 | 1 |
| fed2025 | Cook | Simon Kennedy | LNP | 62.67 | 48.06 | 50.11 | 52.15 | 48.06 | -4.09 | 1 |
| nsw2023 | Upper Hunter | Dave Layzell | LNP | 31.20 | 37.03 | 30.05 | 32.98 | 37.03 | +4.04 | 1 |
| fed2019 | New England | Barnaby Joyce | LNP | 64.92 | 54.82 | 58.94 | 58.35 | 54.82 | -3.53 | 1 |
| nsw2019 | Gosford | Liesl Tesch | ALP | 49.50 | 44.22 | 46.51 | 47.46 | 44.22 | -3.25 | 1 |
| nsw2023 | Willoughby | Tim James | LNP | 43.50 | 43.60 | 46.89 | 46.73 | 43.60 | -3.13 | 1 |
| nsw2019 | Canterbury | Sophie Cotsis | ALP | 65.50 | 50.61 | 53.58 | 53.57 | 50.61 | -2.96 | 1 |
| fed2022 | Groom | Garth Hamilton | LNP | 59.83 | 43.72 | 47.48 | 46.47 | 43.72 | -2.75 | 1 |
| fed2025 | Dunkley | Jodie Belyea | ALP | 41.07 | 38.28 | 38.72 | 40.61 | 38.28 | -2.33 | 1 |
| fed2025 | Aston | Mary Doyle | ALP | 40.87 | 37.26 | 33.77 | 39.55 | 37.26 | -2.29 | 1 |
| nsw2023 | Monaro | Nichole Overall | LNP | 45.96 | 39.11 | 40.75 | 41.39 | 39.11 | -2.28 | 1 |
| wa2025 | Rockingham | Magenta Marshall | ALP | 49.33 | 46.55 | 49.32 | 48.16 | 46.55 | -1.61 | 1 |
| fed2019 | Fremantle | Josh Wilson | ALP | 52.62 | 38.02 | 38.41 | 39.32 | 38.02 | -1.30 | 1 |
| qld2024 | Callide | Bryson Head | LNP | 50.33 | 56.88 | 59.52 | 58.16 | 56.88 | -1.28 | 1 |
| sa2026 | Black | Alex Dighton | ALP | 47.90 | 43.19 | 40.50 | 41.76 | 42.98 | +1.23 | 1 |
| fed2010 | Gippsland | Darren Chester | LNP | 39.60 | 53.00 | 52.65 | 51.82 | 53.00 | +1.19 | 1 |
| fed2010 | Mayo | Jamie Briggs | LNP | 41.28 | 46.76 | 46.28 | 45.65 | 46.76 | +1.11 | 1 |
| fed2022 | Eden-Monaro | Kristy McBain | ALP | 35.89 | 42.57 | 39.97 | 41.67 | 42.57 | +0.90 | 1 |
| sa2026 | Dunstan | Cressida O'Hanlon | ALP | 32.10 | 38.56 | 34.06 | 37.12 | 37.86 | +0.74 | 1 |
| qld2024 | Stretton | James Martin | ALP | 56.39 | 45.58 | 43.79 | 44.97 | 45.58 | +0.61 | 1 |
| vic2018 | Polwarth | Richard Riordan | LNP | 49.60 | 51.14 | 52.85 | 51.38 | 51.14 | -0.25 | 1 |
| nsw2019 | Blacktown | Stephen Bali | ALP | 71.60 | 54.61 | 54.79 | 54.63 | 54.61 | -0.01 | 1 |

Reading it: only Lyne, Orange, Wagga Wagga and (partly) Wentworth are the "independent or
minor-party by-election winner who surged" shape the hypothesis describes. Most major-party
winners are predicted well. Several of the larger remaining errors (Murray, South-West Coast,
Vasse, Cootamundra) are not by-election effects at all (Murray was lost to Helen Dalton).
The same_mp flag is 1 on all 43 rows, so the override works as designed.

Not recontested (in `byelection_winner_rows()` but no match at the target election) are not
listed; I did not tabulate them.

## 3. Size of the problem

Table: sum of squared error (SSE, points squared; smaller is better) as a share of the total over
all 11,905 forecast rows (total SSE = 194,679).

| Set | Rows | SSE | Share of total |
|---|--:|--:|--:|
| All 43 recontesting by-election winners (class rows) | 43 | 5,078 | 2.61% |
| ... the whole seat-election for those 43 (every party row) | 288 | 10,422 | 5.35% |
| Non-major winners only (Lyne, Orange, Wagga, Wentworth, Mayo) | 5 | 3,431 | 1.76% |
| The three named cases (Oakeshott, Donato, McGirr), winner rows | 3 | 3,276 | 1.68% |
| The three named seats, every party row (Lyne 2,088; Orange 1,820; Wagga 746) | 19 | 4,654 | 2.39% |
| For scale: worst 60 rows by squared error, whole table | 60 | 31,067 | 15.96% |

Of the worst 60 rows by absolute error, 4 are by-election winners. Lyne IND is rank 1 and Orange
OTH_RIGHT rank 2 of 11,905 rows. So the effect is concentrated: three candidates carry 1.7% of
all squared error, but fixing the mechanism for everyone else would change very little (the
other 40 rows total 1,800 SSE, 0.9%).

Share counts rows, not seats: "affected rows" = 43 class rows (288 rows counting every party in
those 43 seats).

## 4. Proposed fix (not implemented)

Plain words. Treat a by-election win as the first observation of a sitting member's personal vote,
and carry both the person's level and the correct "who lost the seat" signal into the model:

1. **Give the winner an `own_prev_pcv`.** Use the by-election first-preference share as the
   candidate's previous personal share when there is no general-election row, via the
   `byelection_winner_rows()` rows that already exist. Do not wire up the existing
   `output/nsw-byelection-prevpcv.csv` as is: it covers NSW only. Add a separate feature
   column `own_prev_is_byelection` (0/1) so the trees can learn that this share has a different
   relationship to the later general-election share (Orange 23.8 to 49.1, Wagga 25.4 to 44.6,
   Lyne 63.8 to 47.2). Keep it a feature, not a replacement of the seat base, per the
   existing rule in `R/candidate_returns.R` about replacing multi-candidate classes.
2. **Mark the party that lost the seat as departed.** In the override, clear `elected` for the
   seat but remember which class held it, so `mp_departed` stays TRUE for the class that lost at
   the by-election (Orange, Wagga, Lyne, Wentworth LNP; Bega LNP; Ipswich West ALP) while still
   being FALSE when the same party kept the seat.
3. **Pass the overridden corpus to `leading_candidate_returns()`** (`R/candidate_returns.R:243`)
   so `leader_same` agrees with `same_mp`. Tiny code change; latent.
4. Test it per `CLAUDE.md`: in `base_pred` (the baseline slope inputs) AND the xgb layer, on all
   six harnesses, with the three named seats scored end to end, and pre-register first
   (`docs/PRE-REGISTRATION-RULES.md`). The "named targets primary, election-wide guard"
   rule applies: named targets are the 43 rows, 5 non-major.

### One worked example row: Orange 2019, OTH_RIGHT, Donato

* **State before:** general-election class prior 2.59; by-election class share about 27.1 blended
  at half weight into a baseline of 14.9; `own_prev_pcv` NA; `same_mp_i` 1; LNP class not flagged departed.
* **Fixed model consumes:** `own_prev_pcv = 23.76`, `own_prev_is_byelection = 1`, `same_mp_i = 1`;
  LNP class `mp_departed = TRUE` (departed-major slope applies, about -2.8 points on its base).
* **Expected direction:** Donato prediction moves up from 20.9, LNP down from 45.8. I can
  NOT state how far: 23.76 is a low-turnout share and the actual later share was 49.15. Whether
  the trees learn a large lift from "by-election winner, low share" depends on only
  five non-major cases in the whole corpus (below). Realistic expectation is a partial fix
  (mid-30s for the class, not 56).
* **Honest limit:** with n = 5 non-major recontesting winners in 18 elections, any gain will be
  indistinguishable from noise on aggregate metrics, so it should be judged on the named rows,
  not on pooled RMSE. Per the repo's shrinkage rule the feature should be allowed in with a
  fixed prior rather than refused on power.

## 5. Related, broader finding (not cluster A)

The common thread across Lyne, Orange, Wagga, Dametto (Hinchinbrook), Brock (Stuart),
Regan (Wakehurst) is a **first-term independent or minor-party member whose vote jumps** at the
next election. By-election status is only one route into that group. The better framing for a
feature is "member won a seat from outside the major parties within the last term, and the
winning share was below the later level", which a by-election override alone does not cover.
This is a hypothesis; I did not test it.

## 6. Things I could not confirm, and where I looked

* **Whether the xgb model could use a by-election `own_prev_pcv` at all.** I did not train or
  retrain anything. n = 5 non-major recontesting by-election winners across 18 elections in
  `forecasts.csv` (counted from my inventory).
* **Impact of the `leader_same` bug (defect 4).** Shown by calling `candidate_returns()` with the
  override on (Donato `leader_same` FALSE, `same_mp` TRUE). Not traced through `screened_slopes()`
  for these seats; `permit` is 0 for Orange/Wagga, so the `!is_same & permitted -> 1.0`
  branch (`R/dev_slope.R:350`) does not fire, and the `same_mp` slope overrides at
  `R/dev_slope.R:207`. Treated as latent.
* **Size of the departed-flag defect (defect 3).** I measured the flips (39 TRUE to FALSE cells,
  almost all correct because the same party kept the seat). The wrong ones are where the party
  changed at the by-election: LNP in Orange, Wagga Wagga, Lyne, Wentworth, Bega; ALP in
  Ipswich West. I did not measure how many points the departed tier would have moved
  (documented average is 2.8, `R/dev_slope.R:151-157`), which is small next to the 10 to 20
  point misses.
* **Blend arithmetic for Orange (class share about 27.1, blend 14.9).** Derived from the
  results CSV and the `base_pred`; I did not print the harness's actual `mat` row. Wagga
  check: by-election IND class about 36.0 (McGirr 25.4 + Funnell 10.6), blended with 9.7 gives
  22.85 against `base_pred` 22.79. Consistent, not directly observed.
* **How `own_prev_pcv` in the v6 feature file was actually produced.** I read
  `R/candidate_returns.R:610` and `R/xgb_primary_override.R:285-292` and the file contents (NA);
  I did not read `scripts/fit_xgb_primary_v6.R:373` end to end (it merges a `pv` table I did not open).
* **The 38 by-election winners without candidate-level results (section 7).** Names unknown, so
  they were not matched. Whether any recontested is therefore unconfirmed, though several
  clearly did.
* **`docs/MODEL-REGISTRY.md` lists `AUSPOL_BYELECTION_MP` as "NO" for the harnesses and
  `fit_seats_full.R`.** That is the registry's grep for switches read inside a harness file;
  the switch is read inside `R/candidate_returns.R:72`, so it does reach all of them
  (repeating the caveat already in `CLAUDE.md`). I confirmed it fires by calling the function
  directly and by the feature file.
* **Row-count caveat:** the `actual_share` for a class row sums every candidate of that class
  (Orange OTH_RIGHT 56.18 = Donato 49.15 + three minor right-wing candidates 7.03). The
  "Own %" column is the winner alone, so the two differ.
* Did not look at the live Victorian forecast (Prahran, Werribee, Mulgrave, Narracan, Nepean
  by-elections since vic2022). Out of scope; the same four defects would apply.

## 7. By-election winners with no candidate-level results on disk (cannot be matched)

Table: 38 of 92 winners have no rows in `byelection-results.csv`. The ones that fall inside a
forecast window and whose winning-party class is in `forecasts.csv` are below with the
CLASS-row error (the person is probably, not certainly, the one who recontested; names come
from the forecast row's `candidate`). Signed error, points; positive = under-called.

| Election | Seat | By-election (winner party) | Class row candidate | xgb | Actual | Signed err |
|---|---|---|---|--:|--:|--:|
| wa2013 | Fremantle | 2009 (Greens, Adele Carles, then stood as IND) | IND CARLES | 20.41 | 7.70 | -12.71 |
| wa2013 | Fremantle | same by-election, GRN class | SULLIVAN | 6.42 | 18.17 | +11.75 |
| vic2018 | Northcote | 2017 (Greens, Lidia Thorpe) | THORPE | 34.57 | 39.52 | +4.95 |
| vic2018 | Gippsland South | 2015 (National) | O'BRIEN | 54.48 | 61.91 | +7.43 |
| sa2022 | Cheltenham | 2019 (Labor) | SZAKACS | 52.63 | 55.56 | +2.93 |
| sa2022 | Enfield | 2019 (Labor) | MICHAELS | 50.06 | 52.35 | +2.29 |
| wa2013 | Armadale | 2010 (Labor) | BUTI | 52.53 | 53.68 | +1.15 |
| wa2013 | Willagee | 2009 (Labor) | TINLEY | 46.20 | 46.52 | +0.31 |

Missing for: fed2010 Higgins and Bradfield (2009), fed2016 North Sydney (2015), fed2019 Perth
(2018): the forecast-table rows for these were not extracted. Carles is the only
non-major by-election winner here; her case goes the opposite way (she lost vote, the model
over-called her). The 38 missing result sets are also why `byelection_prior` skipped them as a
baseline. Fetching them from the same Wikipedia pages used for the other 54 would complete the
table; the commit message of `6709685` calls the table "complete", which is not true as of
this check (38 of 92 winners without result rows).

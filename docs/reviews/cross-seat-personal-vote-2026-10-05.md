# Does a candidate's personal vote travel to a different seat? (cluster B)

Date: 2026-10-05. Read-only investigation: no code, harness or fit script was run or edited.
Scratch scripts: `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\599330fc-0de9-4609-8538-29a34fc021fd\scratchpad\clusterB\` (b.R to h.R).

## Verdict in four lines

1. The hypothesis is TRUE as a code fact: every personal-vote mechanism keys on (seat, person), looks back exactly ONE election, and reads only `output/candidacies.csv` (no by-elections, no council).
2. It is TRUE as a miss only for a narrow group: people whose prior vote was a personal-brand vote (they stood as an independent, or won a by-election) and who now stand in another seat. n = 18, mean under-call +10.9 points (SE 3.2), about 2.7% of all squared error.
3. It is FALSE for most of the named cases. Lyons, Birchall, Heise, Palmer (Fairfax 2013), Hulett, Horncastle have NO prior record anywhere in the corpus (they are first-time or council-only), so no matching rule could credit them. They sit in the "no record" bucket, which is 55% of all squared error, and need new data, not a new match key.
4. Cross-seat records of major-party or Greens candidates show no bias at all, so a blanket "credit any prior vote" rule would be wrong. The fix has to be narrow.

## 1. The code walk: what key is matched

Matching key is **(normalised seat, surname + first initial)**. Not party, not jurisdiction as such (the corpus is just compared election to election).

| Step | File:line | What it does |
|---|---|---|
| Name key | `R/names.R:123` `surname_of`, `:166` `given_of`, `:200` `match_key(..., "initial")` | key = `surname|first-initial` (surname only when given name is blank). |
| Seat key | `R/names.R:221` `normalise_seat` (strip case/punctuation); `:251` `seat_rename_map` (denison, batman, melbourneports, frome only) | |
| Returning flag `same` / `same_mp` | `R/candidate_returns.R:90-98` build `.k`; `:109-110` `.s`; `:140-146` join on **`c(".s", ".k")`**; `:167-176` same for `elected` | A candidate "returns" only if the same key stood in the same seat (or its listed rename) at `election_from`. |
| Leader flag `leader_same` | `R/candidate_returns.R:277-326` (join at `:322-323`, leader picked by highest `pcv` at `:310`) | Same (.s, .k) join. |
| Personal prior vote `own_prev_pcv` | `R/candidate_returns.R:431-807`: `lead` at `:535-536`; prior non-major rows `PT` at `:593`; `prev_best` grouped **by `(.s, .k)`** at `:610-613`; merge at `:614`; major-party defector table `DEF` grouped by `(.s, .k)` at `:717-722`, merged `:733` | Own vote is looked up only in the same seat. A person who moved seat gets `NA`, so the class-level base (usually near zero for an independent) is used. |
| By-election winner as sitting member | `R/candidate_returns.R:72-88` calling `byelection_winner_rows()` (`R/byelection_prior.R:173`) | Reaches `candidate_returns()` only. `personal_prior_vote()` never calls it, so a by-election winner's 63.8% never becomes a base. |
| Look-back depth | six harnesses pass `(ea, eb)` / `(PRV, TGT)`: `scripts/backtest_candidate_fed.R:737,827`, `_sa.R:483,588`, `_qld.R:425,544`, `_nsw.R:481,595`, `_wa.R:376,452`, `_vic.R:447,547`; `scripts/fit_xgb_primary_v6.R:255` (`pr$prev`); `scripts/fit_seats_full.R:771,863` (`vic2022 -> vic2026`) | `election_from` is always the IMMEDIATELY previous election of that jurisdiction. Someone who sat out one cycle (Windsor 2013, Strelow, van Styn, Bedford) is invisible. |
| Who is "the candidate" | `R/candidate_returns.R:310,535` order by current `pcv` | Class leader is chosen by the ACTUAL result in backtests (look-ahead). Not confirmed to matter here; flagged in section 6. |

Consequence: there are four separate blind spots, not one: (a) other seat, (b) other jurisdiction, (c) skipped election, (d) by-election history. Council history does not exist in any table.

## 2. Inventory

Method (all time-forward: only records from a strictly earlier election year). Each of the 9,452 forecast rows with a named candidate joined to `candidacies.csv` on election, normalised seat, name (9,452 of 9,452 matched). Person key = surname + first initial; a match is "confident" only if the full given name is equal or one is a prefix of the other (3+ letters). Prior records also include `external/reference/byelections/byelection-results.csv` (443 rows, by-elections, not in the candidacy corpus). Rows with an initial-only match (779) are NOT counted as a match.

Counts of forecast rows by how the model could see the person (n = rows; 2,453 of the 11,905 rows have no named candidate and are excluded here; their squared error is 4,819, 2.5% of total):

| Category | Meaning | n | Credited by the model? |
|---|---|---|---|
| A_sameseat_prev | same seat, immediately previous election | 2,218 | yes |
| B_sameseat_earlier | same seat, an earlier but not the previous election | 123 | no |
| B2_sameseat_byelection_only | same seat, only prior record is a by-election | 56 | no |
| C_samejur_otherseat | same jurisdiction, different seat | 609 | no |
| D_otherjur | different jurisdiction (state vs federal, or other state) | 693 | no |
| N | no prior record | 4,974 | n/a |
| N_initial_only | only a surname+initial match, full given name differs | 779 | n/a (treated as no record) |

Ambiguity: of the 1,481 cross rows (B + B2 + C + D), 261 (18%) also have a different person with the same surname and initial in the corpus (e.g. SMITH, JOHNSON), so even a "confident" match there can be the wrong person. Spot flags from the list below: Tim HORAN (Parkes 2007 to Riverstone 2023, prior 20.7, actual 2.3) and Kelly GLADIGAU look like different people or non-transferable votes. I did not verify any individual by outside source.

Cross-seat candidates whose prior was a personal-brand vote: prior label IND, or a by-election win; prior vote at least 15%; target class not a major party and not GRN (n = 18). Signed error = actual share minus `xgb_pred`, in points; positive means the model under-called. Prior = best earlier result of the same person.

| election | seat | candidate | prior (where) | prior % | xgb_pred | actual | signed |
|---|---|---|---|---|---|---|---|
| fed2010 | Lyne | Robert OAKESHOTT | Lyne by-election 2008 (won) | 63.8 | 7.7 | 47.8 | +40.1 |
| fed2016 | Cowper | Robert OAKESHOTT | Lyne by-election 2008 / fed2010 (47.1) | 63.8 | 5.1 | 29.6 | +24.5 |
| fed2016 | New England | Tony WINDSOR | New England fed2007 (skipped 2013) | 61.9 | 21.4 | 32.9 | +11.6 |
| sa2022 | Stuart | Geoff BROCK | Frome sa2018 (won) | 46.0 | 25.5 | 48.5 | +22.9 |
| sa2022 | Newland | Frances BEDFORD | Florey sa2018 | 30.6 | 14.5 | 12.3 | -2.2 |
| sa2026 | Florey | Frances BEDFORD | Florey sa2018 (skipped 2022) | 30.6 | 5.7 | 4.8 | -0.8 |
| fed2019 | Wentworth | Kerryn PHELPS | Wentworth by-election 2018 (won) | 29.2 | 23.1 | 33.0 | +9.9 |
| fed2022 | Fowler | Dai LE | Cabramatta nsw2019 | 25.9 | 10.7 | 29.5 | +18.8 |
| nsw2019 | Wagga Wagga | Joe McGIRR | Wagga by-election 2018 (won) | 25.4 | 25.5 | 46.1 | +20.6 |
| nsw2019 | Orange | Philip DONATO | Orange by-election 2016 (won) | 23.8 | 20.9 | 56.2 | +35.3 |
| qld2024 | Rockhampton | Margaret STRELOW | Rockhampton qld2017 (skipped 2020) | 23.5 | 5.1 | 17.9 | +12.7 |
| nsw2019 | Cootamundra | Matthew STADTMILLER | Cootamundra by-election 2017 | 23.3 | 6.0 | 15.7 | +9.7 |
| fed2025 | Paterson | Philip PENFOLD | Maitland nsw2015 | 23.3 | 15.5 | 12.1 | -3.4 |
| fed2019 | Barker | Kelly GLADIGAU | Hammond sa2018 | 22.7 | 9.6 | 2.9 | -6.7 |
| nsw2023 | Riverstone | Tim HORAN | Parkes fed2007 (possibly another person) | 20.7 | 2.0 | 2.3 | +0.3 |
| vic2022 | Point Cook | Joe GARRA | Werribee vic2018 | 19.9 | 12.8 | 10.2 | -2.6 |
| fed2022 | Lyne | Steve ATTKINS | Myall Lakes nsw2015 | 15.1 | 6.6 | 8.8 | +2.2 |
| nsw2019 | Blacktown | Josh GREEN | Blacktown by-election 2017 | 15.1 | 4.6 | 7.0 | +2.4 |

Retention (actual / prior) across these 18: median 0.56, mean 0.75, range 0.11 to 2.36. A single fixed credit rate is not supportable; the spread is as large as the effect.

Not in the table (also big): fed2013 Fairfax Palmer 8.8 vs 30.1 (first run; no record), fed2022 Cowper Heise 7.2 vs 26.3 (first run in the corpus; the 2019 Cowper candidate was Oakeshott), vic2018 Geelong Lyons 6.8 vs 26.0 and Melton Birchall 10.1 vs 35.5 (no record), wa2025 Hulett 3.0 vs 25.6 and Horncastle 5.8 vs 26.9 (no record). Wilkie fed2010 Denison (prior 16.4% as Greens in Bennelong 2004, +14.1) and WA Stallard wa2013 Kalamunda (prior 37.7% as ALP in Darling Range 2005, +19.2, WA names are bare surnames so the match is weaker) are cross-seat but changed label, so only the first is a clean personal-vote case.

## 3. Sizing

Total squared error over all 11,905 rows (signed error from `xgb_pred`): **194,679**.

Mean signed error and share of total squared error by group. Positive mean = under-called. SE = standard error of the mean. "Prior" = best earlier result of the same confident-matched person. Cross groups are B + B2 + C + D.

| Group (all classes) | n | mean signed | SE | RMSE | share of total sq. error |
|---|---|---|---|---|---|
| A: same seat, previous election (credited) | 2,218 | +0.69 | 0.11 | 5.01 | 28.6% |
| No confident record | 5,753 | +0.32 | 0.06 | 4.32 | 55.0% |
| Cross, prior under 5% | 528 | -0.47 | 0.15 | 3.40 | 3.1% |
| Cross, prior 5 to 15% | 498 | +0.09 | 0.14 | 3.20 | 2.6% |
| Cross, prior 15% or more | 455 | +1.17 | 0.27 | 5.91 | 8.2% |

Same grouping, non-major target classes only (IND, OTH_RIGHT, OTH, ONP, GRN), where a personal vote matters:

| Group | n | mean signed | SE | RMSE | share of total sq. error |
|---|---|---|---|---|---|
| A credited | 627 | -0.51 | 0.18 | 4.62 | 6.9% |
| No confident record | 4,089 | +0.15 | 0.06 | 3.88 | 31.7% |
| Cross, prior under 5% | 501 | -0.55 | 0.15 | 3.34 | 2.9% |
| Cross, prior 5 to 15% | 469 | +0.09 | 0.14 | 3.03 | 2.2% |
| Cross, prior 15% or more | 151 | +1.69 | 0.57 | 7.19 | 4.0% |

Split of the last row, which is where the signal is. Prior 15% or more, cross, non-major target (not GRN):

| Prior label | n | mean signed | SE | RMSE | share of total sq. error |
|---|---|---|---|---|---|
| Independent label or by-election win (personal brand) | 18 | +10.85 | 3.24 | 17.2 | 2.74% |
|   of which by-election winners | 7 | +20.36 | 5.28 | 24.1 | 2.09% |
|   of which independent-label, no by-election | 11 | +4.80 | 3.01 | 10.7 | 0.64% |
| Major-party label (defector, existing machinery covers same-seat only) | 57 | -0.06 | 0.62 | 4.64 | 0.63% |
| Other minor-party label | 24 | +0.28 | 1.16 | 5.58 | 0.38% |

Reading it:
- Is there a systematic under-call? Overall no. Cross-seat non-major candidates average -0.5 to +0.1 points against +0.15 for no-record candidates (Welch test, earlier cut, p = 0.71). The group-wide effect is a handful of people, not a drift.
- Among those who are personal-brand candidates, the under-call is large and clear: +10.9 points, SE 3.2, about 3.3 SE from zero (n = 18, 8 of them off by more than 10 points). For by-election winners it is +20.4 (SE 5.3, n = 7).
- Slope: in non-major, non-GRN cross rows with prior of 5% or more (n = 251) each extra point of prior adds 0.074 points of miss (SE 0.027). Small, because most priors there are party votes that did not travel.
- Major-party targets with a prior elsewhere: 264 rows, mean +0.86 (SE 0.28), against +0.71 for major-party no-record rows (n = 1,664). No separation.
- Ceiling on what any cross-seat fix can recover: **the 18-row group is 2.7% of total squared error**, and only a part of that would be removed. Compare the no-record bucket: 103 non-major rows with a miss over 10 points carry 27,124 of squared error (13.9% of total) and are untouched by any name-matching change.
- Independent-style classes with 15% or more actual vote (IND, OTH_RIGHT, OTH): 108 + 11 of 218 are no-record rows, mean miss +11, squared error 23,121 (11.9% of total). This is where Lyons, Birchall, Heise, Palmer, Hulett, Horncastle live. Their cause is not the match key (see section 5).

## 4. What is NOT the cause

- Surname collision at the matching step is not inflating the result: only confident (full given name) matches are counted, and the headline group is 18 hand-inspectable rows.
- The credited same-seat group is not under-called (mean -0.51 for non-major; for IND -1.17, SE 0.44, so if anything over-called). Crediting a prior vote works when the person is in the same seat; the gap is purely that other cases get nothing.
- Greens and major parties moving seat are fine without extra credit (+1.1 and -0.06 points on mostly party-driven votes).

## 5. Proposed fix (not implemented)

In plain words: build ONE person history table before predicting, from every election strictly before the target (all jurisdictions, all earlier cycles, plus the by-election results file), instead of one seat in one previous election. For a class leader with no same-seat record at the previous election, take the person's best earlier result IF that earlier result was a personal-brand vote: an independent (or independent-style minor) label, or a by-election win. Credit a fraction of it, shrunk toward zero when evidence is thin, through the existing `own_prev_pcv` and `transfer` channel so it reaches `base_pred` and the xgb layer together (CLAUDE.md requires testing both). Do not extend the major-party defector rule or Greens; the data above show nothing to gain there.

Design points the data support, to be pre-registered before any build:
1. Match key: surname + full given name (or 3+ letter prefix), never initial only; refuse the credit when another same-surname-and-initial person exists with a different full given name (261 of 1,481 cross rows). WA bare surnames need a seat or region tie-break and should stay out of the first version.
2. Retention is not one number: median 0.56 over 18 cases, range 0.11 to 2.36. Use partial pooling (per `docs/` shrinkage rule), fit leave-target-out, and report n with it. By-election winners (7 cases) may need their own cell: ratios 0.75, 1.13, 1.81, 2.36, 0.67, 0.46, 0.46.
3. Add the by-election results (and the missed-cycle look-back) to the same table so Oakeshott fed2010, Donato, McGirr, Phelps and Stadtmiller are reachable.
4. Test on all six harnesses and the published script in the same session, scored on the named 18 rows first (primary) with the pooled 22-pair log loss and share RMSE as the do-no-harm guard (per the pre-registration rules).

Worked example, fed2016 Cowper, Rob Oakeshott (independent). Today: his key is not in Cowper at fed2013, so `own_prev_pcv` is `NA`, the independent class base is the seat's near-zero independent vote, and the model predicts 5.1. With the fix: history table before fed2016 holds Lyne by-election 2008 (63.8%) and Lyne fed2010 (47.1%, he won); both independent-label, both strictly before fed2016. Best prior 63.8. Credit at the pooled retention of about 0.5 gives a personal base near 32 (a shrunk rate would give somewhat less), against an actual 29.6. The existing remove-transferred-votes step then takes nothing from other classes (Lyne is a different seat), so no double count. At retention 0.46 (his own realised ratio) it is exact, but that figure must not be used for him: it comes from the outcome being predicted, so the rate has to come from the other 17 cases.

## 6. Unconfirmed items and where I looked

- **Council and mayoral history**: not in `candidacies.csv`, `DATA-REGISTRY.md` or the by-election files; I did not search for a local-government source. Lyons (Geelong), Birchall (Melton), Hulett, Horncastle, Heise are therefore "no record", and I have not confirmed from outside sources what their prior roles were. If a council results table exists it must be found before the claim "they need new data" is final. Looked in: `output/candidacies.csv`, `external/reference/byelections/`, `docs/DATA-REGISTRY.md` headings only.
- **Person identity of the 18 rows**: confident name match (full given name), not verified against an outside source. Tim HORAN, Kelly GLADIGAU and Josh GREEN look doubtful; Stallard (WA) is a bare surname.
- **By-election cases**: by-election rows were added by my own matching (`First Last` names, last token = surname). Winner = highest `pct` in that by-election. Same-year by-elections before a general election are excluded by the year test, which is conservative.
- **Credit mechanics in the xgb layer**: I did not trace whether the xgb features `same_i`, `same_mp_i` or `own_prev_pcv` (`scripts/fit_xgb_primary_v6.R:373,720-722`) would pick up a cross-seat value without retraining; that needs the per-seat SHAP walk before any build.
- **Leader choice uses actual vote**: `lead` is chosen by current `pcv` (R/candidate_returns.R:310,535) and `forecasts.csv` `candidate` is presumably that leader. In backtests this uses information from the election being predicted. I did not test whether it changes any row in this review.
- **Class-level view**: forecast rows are (seat, party class). For a class with several candidates only the leading one is matched; a returning non-leader is not counted.
- **Effect size after a fix** is an upper bound only: 2.74% of total squared error is the ceiling for the 18-row group, and a shrunk credit recovers part of it. No fit or backtest was run.
- Rows with no named candidate (2,453, 4,819 squared error) were left out of the inventory.

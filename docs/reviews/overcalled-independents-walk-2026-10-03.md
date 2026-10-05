# Overcalled independents: Pascoe Vale 2022 and Kavel 2026, walked end to end (2026-10-03)

Read-only walk, nothing in `R/` or `scripts/` edited, no harness run. Sources are
existing files in `output/`. The one computation done was reading the shipped
as-at xgboost models' per-feature contributions (`predict(predcontrib=TRUE)`,
scratch script, not committed) on the stored feature rows.

## 0. The headline was mislabelled: "actual 17.8" is not an independent

`docs/NEXT-STEPS.md` item 3 says "Pascoe Vale 2022 (ours 33.6, AEF 12.9, actual
17.8)". Those three numbers are the **REST bucket**, not the independent. REST is
defined in `scripts/build_aef7_ledger_data.R` (`col4`) as everything that is not
ALP, LNP or GRN, so it is IND + OTH + OTH_RIGHT (+ONP in SA). The source row is
`output/aef7-primary-common.csv`: `vic2022,Pascoe Vale,REST,33.59,12.85,17.80`.

The actual independent in Pascoe Vale 2022 was **Sue Bolton, 4.19%**. What we
overcalled is a 4.2-point candidate by about 14 points.

Table 1 - REST bucket for Pascoe Vale 2022, vote share in percentage points.
Ours should match actual; the last column is ours minus actual (closer to 0 is
better). Source: `backtest-vic-sharedetail-sh01-port2-...-a1447e8-g48f0233.csv`
(ours), `candidacies.csv` (actual).

| class | our share | actual | ours minus actual |
|---|---|---|---|
| IND (Sue Bolton) | 18.42 | 4.19 | **+14.23** |
| OTH (Hah, Glover, Adams) | 9.31 | 10.92 | -1.61 |
| OTH_RIGHT (Cimbaro) | 5.86 | 2.68 | +3.18 |
| REST total | 33.59 | 17.80 | +15.79 |

The independent is 90% of the REST overcall. AEF gave IND exactly 0
(`aef-primary-all.csv`) and put 12.75 on OTH, so AEF's 12.9 REST is not
comparable class-for-class either: it simply had no independent at all.

## 1. Pascoe Vale 2022: the candidate rows the model consumes

Table 2 - what happened in this seat in 2018, the election the model carries
forward. Vote share of first preferences, percent. Source: `candidacies.csv`.

| 2018 candidate | class | share |
|---|---|---|
| Blandthorn | ALP (won) | 37.74 |
| **Yildiz, Oscar** | **IND** | **23.51** |
| Jackson | GRN | 12.94 |
| Hamilton | LNP | 11.42 |
| **Kavanagh, John** | **IND** | **7.69** |
| Beaton, Linsell | OTH | 3.03 + 1.99 |
| **Timpano, Francesco** | **IND** | **1.68** |

The IND class in 2018 is three people summing to **32.88** (the `seat_prev_pcv`
the model sees for IND). **None of the three stood in 2022.**
`output/emergence-cases-v2.csv` shows Bolton as `stood_before = 0`, and
`output/departed-leader-cases.csv` has `vic2022,Pascoe Vale,IND,23.51,4.19,
same_person = FALSE`.

Table 3 - the stored feature row for each class in Pascoe Vale 2022. `base_pred`
is the model's share before the xgboost correction. Source:
`xgb-primary-v6-features.csv` (the file the as-at models are trained from).
IND is the row to read; the others are for comparison.

| class | base_pred | seat_prev_pcv | level_prev | level_pred | dev_prev | same_i | n_cand prev/now | permit | governed | jump |
|---|---|---|---|---|---|---|---|---|---|---|
| ALP | 37.87 | 37.74 | 42.86 | 37.44 | -5.12 | 0 | 1/1 | 1 | 0 | 0 |
| GRN | 16.93 | 12.94 | 10.71 | 12.00 | +2.22 | 0 | 1/1 | 0 | 1 | -5.56 |
| **IND** | **19.01** | **32.88** | **6.07** | **6.76** | **+26.81** | **0** | **3/1** | **0** | **1** | **0** |
| LNP | 10.92 | 11.42 | 35.19 | 31.38 | -23.78 | 0 | 1/1 | 1 | 0 | 0 |
| OTH | 8.97 | 5.02 | 3.45 | 6.27 | +1.57 | 0 | 2/3 | 1 | 0 | 0 |
| OTH_RIGHT | 6.30 | NA | 1.71 | 6.03 | NA | 0 | 0/1 | 0 | 1 | 0 |

Note the GRN row: Angelica Panopoulos is a new Greens candidate (prev Jackson
12.9, actual 22.4) and we gave her 16.9, so our IND overcall and GRN undercall
(-6.3) sit in the same seat. That is the mirror image, not a separate defect: the
seat had 23.5 points of anti-ALP vote parked in the IND class.

### 1a. What base_pred did

`base_pred` for a class is `level_pred + slope * (seat_prev_pcv - level_prev)`
(`dev_slope()` in `R/dev_slope.R`): the statewide level now, plus some fraction of
how far the seat sat above the statewide level last time.

For IND: `6.76 + slope * 26.81 = 19.01`, which implies **slope = 0.457** (0.49 if
the -0.88 `x_notional_adj` is also added). The only fitted slopes for IND are
0.907 (same person returns), 0.326 (new person) and 0.38 (departed leader,
`AUSPOL_HONOUR_DEPARTED=1`, which is published). A 0.38 slope would give 16.95 and
a 0.326 slope 15.50. The stored 19.01 matches none of them. I could not confirm
why (see section 5). Other stored builds of the same row give base_pred 17.59
(`xgb-primary-v6-oof-BASEMARGIN-fresh.csv`, `xgb-primary-shipped-oof-predictions.csv`)
and the harness run behind the ledger ends at 18.42, so the figure is not stable
across builds.

### 1b. What the xgboost layer did

Table 4 - the as-at vic2022 models' per-feature push on the IND row, in
percentage points added to base_pred. Negative reduces the IND share. Source:
`output/xgb-primary-asat/vic2022{,-m2,-m3}.ubj` run on the Table 3 row. There is
no SHAP row for this seat in `xgb-primary-v6-shap.csv` (0 hits for Pascoe Vale).

| feature | main model | m2 | m3 |
|---|---|---|---|
| base_pred | -0.85 | -0.93 | -0.70 |
| dev_prev | -0.65 | -0.66 | -0.76 |
| historic_elected_i | +0.61 | +0.65 | +0.45 |
| n_cand_now | -0.25 | -0.20 | -0.24 |
| same_mp_i | -0.16 | -0.13 | -0.16 |
| n_cand_prev | -0.15 | -0.16 | n/a |
| council_elected | +0.14 | +0.22 | +0.23 |
| council_pct | +0.13 | +0.46 | +0.14 |
| final IND prediction (base 19.01) | 17.56 | 18.26 | 18.03 |

The xgb layer takes about 1 point off a 19-point baseline whose true answer was
4.2. Consistent with `CLAUDE.md`: base_pred dominates, the trees are a small
correction. The correction points the right way (dev_prev and base_pred both
negative for IND) but is an order of magnitude too small. The shipped forecast
table agrees: `forecasts.csv` has IND `base_pred 19.01`, `xgb_pred 17.95`.

### 1c. Personal-vote, defector, endorsement, salience terms for the IND row

Table 5 - the person-level terms, what they were for this row, and whether they
could act. Sources: `xgb-primary-v6-features.csv`, `salience-v6.csv`,
`candidate-contests.csv`.

| term | value for Bolton | meaning |
|---|---|---|
| same_i / same_mp_i | 0 / 0 | the class leader did not return, no sitting member involved |
| own_prev_pcv | NA | Bolton has no previous vote in this seat |
| historic_elected_i | 0 | no class member ever elected here |
| jump / surge_h | 0 / 0.031 | no salience rise for Bolton; seat surge signal near zero |
| permit | 0 | the screen refuses a rise: this is the "new, unpermitted" case |
| council_pct / elected | 12.0 / 1 | a council vote figure is attached to IND (see section 5) |
| `expected_pcv` for Bolton | 11.13 | `candidate-contests.csv`: a typical new IND here would poll about 11; she polled 4.19 |

Nothing about Bolton as a person enters the row. Every term that would say "this
candidate is weak" is zero or NA, so the row is a statement about the IND class
in the seat, not about her.

## 2. What the model believed, in plain words

In 2018 the independent class took 32.9% here, but 23.5 of it was one man, Oscar
Yildiz, plus 7.7 for John Kavanagh. In 2022 neither stood. A new independent, Sue
Bolton, did. The model does not know the 2018 vote belonged to Yildiz and
Kavanagh as people. It sees "the IND class was 26.8 points above its statewide
level last time" and carries about 46% of that gap forward onto whoever is
listed as IND this time. That gives 19.0 before xgboost and about 18 after.

## 3. The single input that drives the overcall

**`seat_prev_pcv` (32.88) and the derived `dev_prev` (+26.81) for the IND class,
carried onto a candidate who inherits none of it.** Evidence:

1. The IND row's base_pred is 19.01 against a statewide level of 6.76, so 12.2
   of its 19.0 points are the carried-forward 2018 gap. Without the gap the row
   would be about 7.
2. All three 2018 independents are gone (`stood_before = 0`, `same_person = FALSE`),
   so the retention that applies is the departed/new one, not the 0.907 return
   rate.
3. Every correction downstream (xgb, same_i, historic_elected_i) is a fraction of
   a point.
4. Realised retention is roughly nil: 4.19 against 32.88 carried, about 0.

The mechanism is the one `docs/plans/prereg-departed-origin-return-2026-09-18.md`
describes for Morwell (a departed independent's vote is released across classes
and renormalised): here the independent's vote is only partly cut, and the part
that survives is mis-assigned to a class label instead of leaving with the person.
Yildiz is not recorded as a former major-party member in the corpus, so the
"goes home to the origin party" rule in that plan has no origin to route to here.
Where the 2018 vote actually went: ALP 37.7 to 38.8 (flat), GRN 12.9 to 22.4
(+9.5), LNP 11.4 to 21.0 (+9.6). The GRN and LNP gains together account for the
IND's lost 23.5.

Name for this: **departed-independent base carried to a successor** (the same
family as the registry's Morwell, Waite and Kavel items, but with a successor who
is not permitted and a class that is mostly non-returning minor people).

## 4. Kavel 2026, briefly

Table 6 - Kavel 2026 REST bucket and the two other classes that moved, share in
percentage points. Source: `aef7-primary-common.csv` (REST totals), `forecasts.csv`
and `backtest-sa-sharedetail-...` (class rows), `candidacies.csv` (actual). Ours
should match actual; closer to 0 on the last column is better.

| class | our share (forecasts.csv, xgb) | actual | ours minus actual |
|---|---|---|---|
| IND (Schultz, 2 candidates) | 28.63 | 21.36 | +7.27 |
| ONP (Loch) | 22.26 | 19.51 | +2.75 |
| OTH_RIGHT | 7.74 | 1.86 | +5.88 |
| OTH | 5.18 | 2.78 | +2.41 |
| REST total (ledger run: ours 64.14, AEF 45.98, actual 45.51) | 63.8 | 45.5 | about +18 |
| LNP (Orr) | 8.15 | 19.91 | **-11.76** |

Inputs for IND: `seat_prev_pcv` 50.48 (Dan Cregan, 2022), `level_prev` 7.39,
`level_pred` 6.01, `dev_prev` +43.09, base_pred 29.69 (implied slope 0.55),
`permit` 1, `jump` 0.044, `surge_h` 0.33. Cregan did not stand
(`departed-leader-cases.csv`: `sa2026,Kavel,IND,50.48,21.65,same_person FALSE,
prev_won TRUE`). Matt Schultz is flagged `emerged = 1` in
`emergence-cases-v2.csv`.

Xgb push on the IND row (same method as Table 4): dev_prev -2.76, jump +1.10,
base_pred -1.10, historic_elected_i +0.82, n_cand_now +0.42 (main model); IND
ends 28.1 to 29.2 across the three models. Larger corrections than Pascoe Vale
(about 1.6 net), still small against the 29.7 base.

**Same mechanism?** Partly. The same thing is true at the core: a departed
independent's 50.5-point base is carried onto his successor at a 0.5-ish slope
(29.7 at base, against a statewide IND level of 6). But there are two differences
that make it a different diagnosis:

1. **Permit is 1 in Kavel and 0 in Pascoe Vale.** Schultz is permitted to emerge,
   and genuinely did (21.4 is a real independent result). The error is +7, not
   +14, and half of it is the right size. `SEAT-REGISTRY.md` records that sa2026
   salience coverage is 8%, below the screen's 10% floor, so a silent screen
   used to return PERMIT for everyone; a fix was built and refused on the
   seat-log-loss criterion (v41, Kavel 46 to 26.9).
2. **The bigger Kavel miss is LNP, not IND.** LNP is called 8.15 against 19.91
   (-11.8). Cregan was elected as a Liberal in 2018 (48.1) and as an independent
   in 2022; his vote did not go all to the independent class, a large part
   came home to the Liberals. The model sent most of it to IND/ONP and starved
   LNP (`level_pred` for LNP 17.7 against a statewide 36.2 last time, base_pred
   4.40 against seat_prev 20.84). The planned `AUSPOL_DEPARTED_ORIGIN` rule (route
   part of a departed defector's vote to his origin party) is the specific fix
   for this half; Kavel is a flagged case in its pre-registration.

So: the **shared core** is "a departed independent's personal base is carried
forward by class, not by person". In Pascoe Vale it is the entire error. In Kavel
it is about 7 of the +18 REST points, with the rest being the One Nation surge
(OTH_RIGHT +5.9, ONP +2.8) and the Liberal vote that went home to LNP.

## 5. What I could not confirm

- **Why base_pred is 19.01, not 16.95.** With `AUSPOL_HONOUR_DEPARTED=1` and
  permit 0, `screened_slopes()` should return the 0.38 departed rate and the IND
  row should read about 16.95. The stored row implies 0.457. I did not run
  `candidate_returns()` or the harness to see whether `prior_leader_returns` was
  TRUE for this seat (a returns table that predates that column makes "every
  leader returning", per the comment in `screened_slopes`). Likelier explanations:
  the features file was built before the 2026-09-18 default, or the minor-class
  base pooled Kavanagh and Timpano, the two small non-leaders, at a different
  rate. **Unchecked; it needs the `returns` object for vic2018 to vic2022.**
- **Whether `xgb-primary-v6-features.csv` is the exact input behind the 33.59
  ledger figure.** The ledger run (`...a1447e8-g48f0233.csv`) gives IND 18.42, the
  features file 19.01 base and 17.95 xgb. The 0.5-point gaps are across builds
  (I did not match build hashes). The conclusion survives either number.
- **The council terms.** `council_pct` 12.0 and `council_elected` 1 are attached
  to Pascoe Vale IND. Table 4 shows these push IND UP by about +0.3 to +0.7. I did
  not trace who the council candidate is (the Moreland council history file lists
  Sue Bolton as a sitting councillor, which would be a real signal but one that
  predicts a better result for her than 4.2). Not verified against
  `council-history.csv`.
- **Whether a per-person base would have worked here.** The proposed fix (carry
  the vote by person) is untested; I only show the retention of the 2018 vote was
  about zero and that the departed class got 12.2 carried points.
- **Kavel xgb contributions** come from the as-at sa2026 model on the
  `xgb-primary-v6-features.csv` row; I did not check that this file has the post
  2026-09-20 `permit %in% TRUE` fix. If it does not, the "permit 1" on Kavel may
  be the silent-screen PERMIT already recorded in `SEAT-REGISTRY.md` rather than a
  real permission. That would make Kavel closer to Pascoe Vale than I state.
- **Ensemble weights.** `forecasts.csv` xgb_pred (17.95 for Pascoe IND) is the
  ensemble; I ran the three models separately (17.56, 18.26, 18.03) and did not
  reproduce the weighting.
- **The origin of the "17.8" in NEXT-STEPS.** I matched it to the REST total, not
  to any independent figure; the note's own wording ("overcalled independents,
  actual 17.8") reads as an IND figure, so the same slip may be in the other seats
  listed there (Geelong, Sandringham, Shepparton). Not checked.

## 6. Suggested next step (not done)

Print `candidate_returns()` for vic2022 and read `leader_same`,
`prior_leader_returns` and the slope `screened_slopes()` assigns to Pascoe Vale
IND, to settle the 19.01 versus 16.95 question first. Then correct NEXT-STEPS
item 3 to say the Pascoe Vale error is a 4.2-point independent called at 18, and
the REST comparison with AEF is not like-for-like for that seat.

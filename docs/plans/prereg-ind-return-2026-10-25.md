# Pre-registration: a returning independent keeps their own vote (2026-10-25)

Written BEFORE any arm ran or any outcome was computed for these cells. Starts from the standard decision rule
(`docs/PRE-REGISTRATION-RULES.md`, 2026-10-18) and departs from it nowhere.

## Why

Pete, 2026-10-24/25: the Victorian seat markets give independents real chances in Mildura, Benambra and Kew where we
give them almost none, and the bookies beat our backtests on seats with prominent independents (Monash, Wannon, Fowler;
`docs/reviews/backtest-vs-bookmakers-2026-10-24.md`). Traced Mildura through `fit_seats_full.R` (traced copy, local
inputs): Ali Cupper's own 2022 vote 33.9 enters correctly from `personal_prior_vote()`, then the minor-field scale
(`IND+OTH_RIGHT+OTH at 2022 17.1% -> forecast 10.3%`, x0.61) cuts it to 18.9, because independents are scaled to the
forecast "others" total and One Nation absorbs that total statewide.

Evidence against that scaling for a known independent (`output/candidacies.csv`, 90 cases, >= 10% last time, same seat,
27 elections): log(own-vote ratio) on log(minor-field factor) slope 0.13 (se 0.16); median ratio 0.99 for a previous
winner, 0.82 for a previous loser. Pete chose (2026-10-25, quiz) to replace the scale with a fitted return rate.

## What is new

`AUSPOL_IND_RETURN` (`R/ind_return.R`), default `"0"`. For a seat whose SOLE independent stood as an independent in the
SAME seat at the previous election (seat renames followed), the IND cell is SET to `a + b x previous share`, `b`
separate for a previous winner and a previous loser, fitted by OLS on every such cell of every election dated before the
target (time-forward), slopes bounded to [0, 1.5]; the seat's other classes are rescaled pro rata. Disjoint from
`AUSPOL_IND_PERSON` (people with NO record in the seat at the previous election). Applied from inside
`ind_person_apply()`, so `fit_seats_full.R` and all seven harnesses reach it through the calls they already make.

Not addressed here: a NEW independent inheriting a predecessor's movement (Benambra 2026, McKeeman after Hawkins).

## Arms (shipped settings otherwise; baseline = shipped)

- **A-final**: `AUSPOL_IND_RETURN=final` (after the frozen as-at trees; what publishes).
- **A-base**: `AUSPOL_IND_RETURN=base` (before them; the "test base_pred AND the xgb layer" rule).

Screen: `scripts/quick_arm.R`, all elections, default sims. Deciding run for an arm that passes: full 20,000 sims.

## Criteria (standard rule; SE clustered on election)

1. **Primary:** seat-winner log loss on the seats whose IND cell the arm sets, better than shipped by more than 1 SE.
2. **Guard:** seat log loss over every seat of every scored election not worse by more than 1 SE.
3. **Leave-one-election-out:** the primary stays better by more than 1 SE with each election dropped in turn. Each
   election's share of the gain is reported, never a refusal.
4. **No election materially worse:** no election worse on the guard by more than 2 SE of its own paired seat differences.
5. **Not one seat's quirk:** the primary gain keeps its sign with the two largest-gain seats removed.
6. **Direction is reported:** count of cells raised vs lowered, and whether the moved cells' squared primary error falls.
7. **Unacceptable win (named in advance):** the arm lowers the published win probability of any independent who actually
   WON by more than 0.10.

Ship rule: an arm ships only if 1 passes, 2-5 hold and 7 does not fire. If both pass, the larger primary gain ships. A
clause refusing an otherwise-passing result goes to Pete with the split shown. Amendments are added below, this text
unedited.

## Dry run (no outcomes)

- Cells (all elections in `all_election_pairs()`, 35): 163 across 33 elections; per election 1 (sa2018, nt2016, wa2001,
  wa2005, wa2013) to 13 (fed2025).
- Fit as seen by vic2022: a 2.57, b_won 0.933, b_lost 0.588 (n 124: 35 won, 89 lost). fed2025: 2.35, 0.951, 0.677
  (n 147). vic2026: 2.18, 0.943, 0.683 (n 163: 49 won, 114 lost).
- vic2026 cells: Mildura (Cupper, lost, 33.9 -> 25.3), Kew (Torney, lost, 21.1 -> 16.6), Mulgrave (Cook, lost, 18.0),
  Albert Park (Dragwidge, lost, 5.9), Lara (Hathway, lost, 2.7).
- Known answers the criterion must get right: Mildura vic2022 (Cupper the sitting member, 2018 record 32.7, actual 33.9,
  lost the seat on 48.7: cell 2.57 + 0.933 x 32.7 = 33.1) and Indi fed2016 (McGowan, a member re-elected): the rule
  should move these toward the actual, not away.

## Result, arm A-final (2026-10-25, quick_arm, 35 elections, 1,000 sims): REFUSED

- Changed cells' squared share error 13,331 -> 15,660 (+17%, SE 1,056): worse by more than 2 SE.
- Seat log loss, all 2,931 seats: 0.3085 -> 0.3094 (SE 0.0011), within 1 SE. AEF-7 ledger 0.2644 -> 0.2683 (SE 0.0038).
- Split: the 228 IND cells it set went 5,628 -> 7,180; the shipped model's mean signed error on them was +0.12 points
  (unbiased), and the rule lowered 122, raised 106. Early time-forward fits are flat lines: Gippsland East vic2010
  (Ingram, sitting) 36.8 -> 6.4 (actual 25.3); Isaacs and Sydney fed2010 0.5 -> 10.4 (actual 1.5).
- Arm A-base was not run in this form.

## Amendment 1 (2026-10-25, before any run of it; Pete chose "repair the fitted rule")

Added after the A-final result; the text above is unedited. Two changes, both answering the two defects found:

1. **Fit:** a ratio, not a line, so a small record stays small. For each group (previous winner, previous loser),
   `r = (n x rhat + K x 1) / (n + K)`, with `rhat` = sum(actual) / sum(record) over that group's cells in earlier
   elections and `K = 3` (the `AUSPOL_CONSERVE_SHRINK_K` convention): shrunk toward "keeps their whole vote", no
   minimum-n cliff (no earlier cases gives r = 1). Cell = `r x record`.
2. **Stage:** the screened arm is **A-base** (before the trees; the harnesses carry it into the frozen predictions
   through `AUSPOL_XGB_BASE_DELTA`). `fit_seats_full.R` gains a base-stage `ind_person_apply()` call before
   `xgb_primary_predict_live()` so the arm reaches the published forecast; a no-op unless a base-stage switch is set.

Criteria unchanged (sections above).

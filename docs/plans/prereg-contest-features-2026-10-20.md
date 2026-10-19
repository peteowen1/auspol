# Pre-registration: tell the trees who is standing (2026-10-20)

Committed BEFORE anything is built or run. Pete chose this route on 20 Oct ("Retrain trees (Recommended)") after
partial-contest arm A was refused (`prereg-partial-contest-2026-10-19.md`, RESULT). Evidence:
`docs/reviews/miss-diagnosis-aef7-2026-10-19.md`, "Partial contests, traced to the row".

## What the trace settled

- The xgb training table has one row per (election, seat, class) whether or not the class had a candidate there.
  4,202 of 19,071 rows have no candidate; their label is about 0 (14 of them are above 0).
- `n_cand_now` is filled with 1 where nobody stands (`scripts/fit_xgb_primary_v6.R:491`; live
  `R/xgb_primary_override.R:318`), so the trees cannot tell those rows from contested ones.
- One Nation: 1,035 of its 1,918 training rows (54%) have no candidate. Among seats new to it (`n_cand_prev` 0), the
  label averages 2.49 over all rows but 8.82 where it stood, and the trees predict 6.80 where it stood. nsw2023:
  11 new-to-seat contested cells, trees 3.29, actual 9.67. Independents (50% of rows uncontested) and OTH (43%)
  carry the same mixture; the trees repair most of it for them.
- The trees also see only `level_pred`, the class's level averaged over every seat; a class standing in 17 of 93
  seats averages about 93/17 times that where it stands.

## Arm

| Arm | Switch | Rule |
|---|---|---|
| shipped | `AUSPOL_XGB_CONTEST=0` | as published. |
| C | `AUSPOL_XGB_CONTEST=1` | two xgb features added, models retrained (stages 3-5), every target as at its day. |

- `stands_i`: 1 if the class has at least one candidate in the seat at the target election, else 0 (candidacy
  corpus, `output/candidacies.csv`; nominations are public before polling day, so not a leak).
- `level_contested = level_pred * n_seats / max(n_contesting, 1)`: the class's level where it stands. `n_seats` is
  the election's seat count in the training table, `n_contesting` the seats with `stands_i` = 1.
- `n_cand_now` is left as it is, because `R/breakout_mix.R` and `R/ind_typical.R` read it from the features file.
- Columns exist only when the switch is on (`fit_xgb_primary_asat.R` trains on every non-id column).
- Live (`xgb_primary_predict_live()`): when the confirmed nomination list is loaded (`AUSPOL_NOM_LIVE=1`, the same
  list the zeroing uses), both come from it. Before that (today, until ~9 Nov), `stands_i` = 1 and
  `level_contested = level_pred` in every cell: "assume every class stands everywhere", which is what the live
  forecast assumes now. This is a train/serve difference for classes that will not stand everywhere; it ends when
  the list loads, and is reported below.

## Criterion (the standard rule, `PRE-REGISTRATION-RULES.md`)

Two isolated rebuilds from stage 3 at 20,000 sims, same inputs, switch off vs on, in repo copies (copied `output/`
and `external/`, never junctions). Baseline must reproduce the published scoreboard.

- Targets: seats with any cell whose published-path share moved by more than 0.05 points (chosen from predictions).
- 1 Primary: target-seat seat-winner log loss better by more than 1 SE (clustered on election). 2 Guard: all seats
  not worse by more than 1 SE. 3 Leave-one-election-out holds on the primary. 4 No election worse by more than 2 SE
  of its own seats. 5 Without the two largest-gain seats the target gain keeps its sign.
- Reported, not voted: minor-class seat share RMSE on contested cells (ONP, IND, OTH_RIGHT, OTH, GRN, each);
  new-to-seat contested cells by class; nsw2023 and fed2016 One Nation; the 1e-4 floor; AEF-7.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the floor (report at 1e-4).
(b) Live vic2026 before nominations: the switch must not move any seat's favourite with the list unloaded. Diff
    the live forecast with and without the switch; any favourite change goes to Pete before shipping.
(c) Live vic2026 after the list loads (~9 Nov): walked with and without, shown to Pete before it publishes.
(d) A class's statewide total in any backtest election moving by more than 1 point: the features should move where
    the vote lands, not how much there is; reported to Pete.

Shipping is Pete's call on the result.

## What this cannot see

- Whether a new candidate is strong or weak beyond what the other features carry.
- Sub-seat effects (which booths); classes the model does not predict at all (`zero_unnominated()` leaves those).

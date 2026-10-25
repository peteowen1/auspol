# Pre-registration: carry an independent class gap only when one of its earlier candidates re-stands (2026-10-25)

Written BEFORE any arm ran and before any outcome was computed for the cells it moves. Starts from the standard
decision rule (`docs/PRE-REGISTRATION-RULES.md`, 2026-10-18); the one departure (clause 4 at 1 SE, not 2) is the
brief's and is stated where it applies.

## Why

`docs/reviews/overcalled-independents-walk-2026-10-03.md`: Pascoe Vale vic2022. Sue Bolton, a new independent, polled
4.19 and was called 18.42. The 2018 IND class in the seat was Oscar Yildiz 23.5, John Kavanagh 7.7 and Francesco
Timpano 1.7 (32.9 in all); none of them stood in 2022. `base_pred` is `level_now + slope x (seat prior - level_prev)`
(`dev_slope()`), so the class's 26.8-point gap above the statewide IND level was carried, at a slope near 0.4, onto a
candidate who inherits none of it: about 12 of her 19 base points. Every downstream correction (the xgb layer,
`same_i`, `historic_elected_i`) is a fraction of a point. Pete approved the fix on 25 Oct: carry a class gap onto a
candidate only when one of that class's earlier candidates re-stands, matched on the candidate.

## What is new

`AUSPOL_IND_GAP_RESTAND` (`R/ind_gap_restand.R`), default `"0"` (byte-identical).

- `candidate_returns()` gains `class_gap_restand` per (seat, class). It is FALSE only when the class had
  general-election candidates in the seat at the previous election, none of those PEOPLE stands for the class in the
  seat again (person key from `output/candidacies.csv` names, both spellings of a renamed seat), and the current class
  leader has no record in the seat under any label (`leader_same`). By-election rows are not counted.
- With the switch on, `screened_slopes()` and `conditional_slopes()` give the IND class slope 0 on its old gap in those
  seats, so the cell starts from the statewide IND level. IND only: a party class's seat gap is a party vote, not a
  person's.
- Left alone, as out of scope: a screen-permitted newcomer (the 1.0 path; "bigger overcalls with a permitted
  successor"), and a seat with a hand-coded successor rate (`AUSPOL_DEPARTED_SUCCESSOR`; Kavel, Morwell, Mildura are
  coded). Departed-hold is not touched (refused earlier).
- Where it reaches: the slope call in all seven harnesses (`backtest_candidate_{fed,nsw,nt,qld,sa,vic,wa}.R`) and
  `scripts/fit_seats_full.R`, which is the one place each builds `base_pred`. The xgb layer sees the change through
  `base_pred`: in the harnesses by `AUSPOL_XGB_BASE_DELTA` (frozen as-at trees re-predicted on the changed base, as
  base_margin and the base_pred feature), live by `xgb_primary_predict_live()`'s base_margin from this run's shares.
  POST-XGB (`post_xgb_switches()`): stage 1 of `rebuild_forecasts.sh` runs it "0", so the trees never train on it.
- Not built: the other xgb features that describe the old gap (`seat_prev_pcv`, `dev_prev`, `seat_outperf`) are left
  as the facts they are; changing them, or adding a re-stand indicator as a feature, needs an as-at retrain.

## What the rule reaches among the named targets (from `output/candidacies.csv`, before any run)

| target | previous IND candidates (share) | re-stands for IND? | rule fires? |
|---|---|---|---|
| Pascoe Vale vic2022 | Yildiz 23.5, Kavanagh 7.7, Timpano 1.7 | none (Bolton is new) | **yes** |
| Geelong vic2022 | Lyons 24.7, Juhasz 0.6 | Juhasz (1.0 in 2022) | no: the Morwell shape |
| Sandringham vic2022 | Martin 8.4 | Martin (6.9) | no |
| Shepparton vic2022 | Sheed 38.4 | the corpus records Sheed standing in 2022 (29.4) | no |
| Kavel sa2026 | Cregan 50.5 | none (Schultz is new) | no: coded successor (rate 0.506) |

So four of the five named targets are byte-identical by construction, and they are reported as a check that the
rule touched nothing it should not. The other seats it moves across AEF-7 are not known until the screen prints
`IGR1` (one line per IND slope call, naming the seats).

## Arm (shipped settings otherwise; baseline = shipped)

- **A**: `AUSPOL_IND_GAP_RESTAND=1`. Screen: `scripts/quick_arm.R "AUSPOL_IND_GAP_RESTAND=1"` (AEF-7, 1,000 sims).
  Shipping needs all elections (`--pairs=all`) and the full 20,000-sim deciding run.

## Criteria (SE clustered on election)

1. **Primary, named targets:** Pascoe Vale vic2022's IND share error (|ours - 4.19|) falls, and its seat log loss does
   not rise. Geelong, Sandringham, Shepparton and Kavel are byte-identical (any change is a bug, not a result).
2. **Primary, every changed seat:** seat-winner log loss over every seat whose IND cell the arm moves by more than
   0.05 points, better than shipped by more than 1 SE.
3. **Guard:** AEF-7 pooled seat log loss not worse by more than 1 SE.
4. **No election worse:** no single AEF-7 election worse on seat log loss by more than 1 SE of its own paired seat
   differences (the brief's bar; the standard rule says 2).
5. **Leave-one-election-out:** clause 2 stays better by more than 1 SE with each election dropped in turn; each
   election's share of the gain is reported, never a refusal by itself.
6. **Not one seat's quirk:** clause 2's gain keeps its sign with the two largest-gain seats removed.
7. **Direction:** count of IND cells lowered vs raised (expected: all lowered or nearly so, since a dropped gap is
   usually positive), and whether their squared share error falls.
8. **Unacceptable win (named in advance):** the arm lowers the win probability of an independent who actually WON by
   more than 0.10. A drop for a winning independent means a real successor's vote was cut, which is the out-of-scope
   case leaking in.

Ship rule: ships only if 1 and 2 pass, 3-6 hold and 8 does not fire. A clause refusing an otherwise passing result
goes to Pete with the split shown. Amendments are added below, this text unedited.

## Dry run of the criterion on known cases (prose, no outcomes computed)

- **Pascoe Vale vic2022** (the case it is built for): base before renormalisation 6.76 + 0 x 26.81 = 6.76, against
  19.01 now and 4.19 actual. Clause 1 should pass; if it does not, the rule did not reach the published path.
- **Sandringham vic2022**: Clarke Martin stood both times, so the cell must be byte-identical. If it moves, clause 1
  catches a matching bug (for example matching on the class instead of the person).
- **Wentworth fed2022 / New England fed2013** (departed leaders with a strong newcomer): if the screen permitted
  Spender, the rule leaves her alone and clause 8 cannot fire on her; if Spender had not been permitted she would be
  cut to the statewide level and clause 8 would fire (she won). Wentworth is outside AEF-7, so this is the case to read
  first in the all-elections run.

## Known reason it may fail

`departed-leader-retention-2026-09-15.md` measured a departed non-major leader's class keeping 0.38 of its vote
(n=305). Most of those seats are this rule's seats, so slope 0 is below the measured average; the rule wins only if
the no-re-stander subset retains far less than the departed set as a whole (Pascoe Vale kept about 0.13 of its
32.9). The screen decides that; a WORSE result is a reason to fit the subset's own rate, not to argue.

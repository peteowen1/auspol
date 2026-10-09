# Pre-registration: independents start from the typical vote for their signals (AUSPOL_IND_TYPICAL)

Written 2026-10-09, before any harness arm ran. Design walked with Pete on four
Victorian rows (Bass 2018, Hawthorn 2018, Brunswick 2022, Mildura 2022) and agreed
("yeah this sounds great").

## The change

Every independent cell that is NOT a sitting independent member standing again
(`same_mp_i`), in a seat where an independent nominated (`candidacies.csv`), has its
share replaced by a time-forward prediction from past independents' actual votes on
their signals: Climate 200 (split federal / state), council elected, any council
vote, own previous vote, returning person, salience jump, salience permit, number of
independents; coefficients shrunk by their own precision, jurisdiction intercept
shifts shrunk by between-jurisdiction variance (`R/ind_typical.R`). Replaces the
new-independent shrink (`AUSPOL_NEW_IND_SHRINK=0` in every arm).

Share-level check already done (in-scope cells, 8 elections): median absolute miss
halves in every election (vic2022 3.32 -> 1.74); surges are under-called more
(Benambra 2022 4.4 vs 31.7). This is a reason to screen, not a result.

## Arms (quick_arm.R, all 22 pairs, 1,000 sims, against the shipped baseline)

- A1 `AUSPOL_IND_TYPICAL=base  AUSPOL_IND_TYPICAL_STAT=median`
- A2 `AUSPOL_IND_TYPICAL=base  AUSPOL_IND_TYPICAL_STAT=mean`
- A3 `AUSPOL_IND_TYPICAL=final AUSPOL_IND_TYPICAL_STAT=median`
- A4 `AUSPOL_IND_TYPICAL=final AUSPOL_IND_TYPICAL_STAT=mean`

All with `AUSPOL_NEW_IND_SHRINK=0`.

## Criterion, fixed now

- **Primary (targeted):** squared share error on the changed cells (quick_arm Q2),
  better by more than 2 SE clustered on election AND by more than 10%.
- **Guard (election-wide, do-no-harm):** pooled seat-winner log loss over 22 pairs
  (quick_arm Q3) not worse by more than 1 SE.
- **Choosing among arms:** of the arms that pass both, the lowest pooled seat log
  loss goes to the full 20,000-sim run; if none passes, nothing ships and the result
  goes to Pete with the split.
- Report the AEF-7 ledger subset (Q4) and per-election log loss for every arm,
  whatever the verdict; a gain carried by one election is named as such.

## What would make an apparent win unacceptable

- A gain that comes only from zeroing-type cells (a share above 0 set near 0 in seats
  where the independent then polled well) with Victoria's live forecast losing its
  real contenders: the live Victorian rows (Hawthorn's Ibuki, Kew, Mildura's
  non-sitting cells) are printed before shipping and read with Pete.
- Any pair scored on fewer seats than the baseline.

## Amendments

### Amendment 1 (2026-10-09, before the arm ran): the mixture arm, judged on log loss

Arm A5: `AUSPOL_IND_MIXTURE=1 AUSPOL_NEW_IND_SHRINK=0` (R/ind_mixture.R): each in-scope independent's share is set to
the TYPICAL vote for its signals, and the seat's surge mechanism carries a fitted surge chance (penalised logistic,
prior sd 1.5) and size (EM mixture, earlier elections only). Offline: P(15+) Brier 0.0975 vs 0.1226 flat; top band
over-confident (86% predicted, 58% happened, 43 cells).

Because the point is lowered on purpose and the surge is carried in the draws, squared share error on the point (Q2)
is EXPECTED to rise and is NOT a criterion for this arm (A1 and A3 showed the same direction). Criterion, fixed now:

- **Primary:** pooled seat-winner log loss over 22 pairs (quick_arm Q3) better by more than 1 SE clustered on election.
- **Guard:** AEF-7 ledger subset (Q4) not worse by more than 1 SE; no pair scored on fewer seats.
- **Reported whatever the verdict:** per-election log loss, and Q2 with this note.
- A pass goes to the full 20,000-sim run and the live Victorian rows are read with Pete before anything ships.

## RESULT so far (2026-10-09): arms A1 and A3 REFUSED; A2 and A4 not yet run

quick_arm, 22 pairs, 1,000 sims, vs shipped. Q2 = squared share error on changed cells (lower is better); Q3 = pooled seat log loss.

| arm | Q2 change | Q3 0.3094 -> | AEF-7 0.2743 -> | verdict |
|---|---|---|---|---|
| A1 base, median | +9% (worse > 2 SE) | 0.3190 (+0.0096, SE 0.0047) | 0.3037 | REFUSE |
| A3 final, median | +8% (worse > 2 SE) | 0.3121 (+0.0027, SE 0.0037) | 0.2838 | REFUSE |

A1's damage sits where independents won or came close: fed2022 +0.050, sa2026 +0.050, fed2025 +0.045, sa2022 +0.030, nsw2023 +0.027 (seat log loss). It fixes the typical over-called independent (vic2022 Pascoe Vale 18.6 -> 6.7, actual 4.2) but pulls down contenders (Benambra 22.4 -> 9.3, actual 31.7: a returning near-winner).

A2 (base, mean) failed on fed2007 with an NA smearing factor (one-cell jurisdiction, undefined shift), so no verdict; fixed, not rerun. A4 not run.

## Pete's follow-up (2026-10-09): a dedicated model on ALL inputs, scored on independent cells first

`scripts/eval_ind_model.R`: time-forward xgboost per target on nominated independent cells (41 feature-table inputs plus the decay-weighted seat-poll figure, 108 polled cells), predicting the actual share. Pooled over 892 cells in 18 elections, RMSE: current xgb stage 6.38, current published 5.91, new 6.38; median absolute miss current 2.65, new 2.42; bias current +0.30, new -0.17. Ties the stage it would replace and loses to the published path; surges (Goldstein 2022 6.1 vs 34.5) carry it. Not built into the harnesses. A2/A4 (mean arms) left unrun: superseded. Pete chose to attack the SHAPE of the independent distribution in the simulation instead (option 2).

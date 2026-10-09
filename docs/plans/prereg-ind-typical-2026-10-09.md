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

(none)

## RESULT so far (2026-10-09): arms A1 and A3 REFUSED; A2 and A4 not yet run

quick_arm, 22 pairs, 1,000 sims, vs shipped. Q2 = squared share error on changed cells (lower is better); Q3 = pooled seat log loss.

| arm | Q2 change | Q3 0.3094 -> | AEF-7 0.2743 -> | verdict |
|---|---|---|---|---|
| A1 base, median | +9% (worse > 2 SE) | 0.3190 (+0.0096, SE 0.0047) | 0.3037 | REFUSE |
| A3 final, median | +8% (worse > 2 SE) | 0.3121 (+0.0027, SE 0.0037) | 0.2838 | REFUSE |

A1's damage sits where independents won or came close: fed2022 +0.050, sa2026 +0.050, fed2025 +0.045, sa2022 +0.030, nsw2023 +0.027 (seat log loss). It fixes the typical over-called independent (vic2022 Pascoe Vale 18.6 -> 6.7, actual 4.2) but pulls down contenders (Benambra 22.4 -> 9.3, actual 31.7: a returning near-winner).

A2 (base, mean) failed on fed2007 with an NA smearing factor (one-cell jurisdiction, undefined shift), so no verdict; fixed, not rerun. A4 not run.

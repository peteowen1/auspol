# Pre-registration: split the others bucket by the per-candidate model

Written 2026-09-28, before running. Follows
`prereg-minor-candidate-model-2026-09-28.md` (v2 1.171 and naive 1.115
against the current 1.506, mean |statewide class share error|, 21 pairs).

## The change

`forecast_statewide_for()` splits the unpolled bucket (OTH plus folded
classes) by the previous election's ratios. `AUSPOL_BUCKET_SPLIT` =
`cand_resid` or `cand_naive` splits it instead by the candidate model's
predicted class shares for that election (`output/minor-class-shares-resid.csv`,
time-forward: each election predicted by models fitted on earlier ones).
The bucket's TOTAL is unchanged. A bucket class with no prediction (e.g. an
unpolled GRN) makes that pair fall back to the prior-ratio split, printed.
Default `prior` (today).

**Live Victoria is not wired yet**: the model needs the full candidate list,
which exists only after nominations close on 9 November 2026. Until then the
live forecast keeps the prior-ratio split; wiring it is a dated item.

## Criterion, in order

1. **Statewide audit** (22 pairs): the bucket SPLIT error (sum over bucket
   classes of |miss| minus |bucket size miss|, as in the 27 Sep audit) falls
   by at least one paired SE, and mean |miss| ALP/LNP/GRN does not rise by
   more than one SE. Both arms reported; the better on split error goes on.
2. **Rebuild decides** against the matched anchored rebuild (A) on the same
   code: seat log loss must not rise. Weighted primary RMSE reported beside
   it.

**What would make a win unacceptable**: any pair reading a class share
predicted by a model that saw that election (checked: the shares file is
built time-forward, `MC2`); a gain carried by one pair.

## RESULT, criterion 1 (added 2026-09-28 after running; the text above is unedited)

Statewide audit, 22 pairs (`-cand_resid`, `-cand_naive` against
`-base27sepB`); 20 pairs used the candidate split (`BS1`), wa2001 (no model)
and wa2005 (unpolled GRN) kept the prior split (`BS1!`), as specified.

| arm | split error | change | SE | t | better in |
|---|---|---|---|---|---|
| prior (today) | 3.387 | | | | |
| cand_resid | 1.399 | -1.988 | 0.660 | -3.01 | 14 of 22 |
| **cand_naive** | **1.285** | **-2.101** | 0.532 | -3.95 | 16 of 22 |

Do no harm: ALP/LNP/GRN mean |miss| unchanged (1.758; only the split moved).
Without the largest mover: resid -1.696 (SE 0.620, sa2022 out), naive
-1.885 (SE 0.509, vic2022 out). Biggest gains sa2022 8.63 -> 0.51, fed2016
9.16 -> 1.73, nsw2023 5.37 -> 0.51; losses fed2022 1.42 -> 4.74, nsw2019
3.04 -> 4.35, fed2019 0.01 -> 1.59.

**Criterion 1 PASSES; `cand_naive` goes to the rebuild** (criterion 2).

# The whole gap is independents emerging, and it is 97% of it

A diagnosis, not an experiment. It corrects the previous review and reopens a
question this repo has refused four times.

## The number

Two elections both models cover, both forecasting from polls (their 2022 and
2025 federal finals are "Newspoll 53-47" and "Ipsos 51-49 + final pollster
recalibration" — neither is a seat-betting update). 286 seats where both agree
who actually won.

| actual winner | seats | our mean prob | their mean prob | share of the log-score gap |
|---|---:|---:|---:|---:|
| **IND** | 20 | 0.454 | 0.606 | **97%** |
| ALP | 169 | 0.882 | 0.855 | 8% |
| GRN | 5 | 0.428 | 0.368 | 0% |
| LNP | 92 | 0.917 | 0.879 | −5% |

**Excluding seats an independent won: our log score 0.255, theirs 0.247.**

On 266 of 286 seats we are level with them. On the other 20 we are not in the
contest.

## And within those 20, the split is not subtle

| seat | ours | theirs |
|---|---:|---:|
| Curtin 2022 | **0.000** | 0.445 |
| Goldstein 2022 | **0.000** | 0.509 |
| Kooyong 2022 | **0.000** | 0.296 |
| Mackellar 2022 | **0.000** | 0.280 |
| North Sydney 2022 | **0.000** | 0.336 |
| Fowler 2025 | **0.001** | 0.682 |
| Calare 2025 | **0.040** | 0.411 |
| Kooyong 2025 | 0.752 | 0.595 |
| Curtin 2025 | 0.764 | 0.630 |
| Indi 2025 | 0.921 | 0.864 |
| Warringah 2025 | 0.979 | 0.921 |
| Clark 2022 | 0.990 | 0.992 |

**We hold incumbent independents perfectly well — better than they do in four of
them. We score zero on an independent winning for the first time.**

The mechanism is not mysterious. Each seat's baseline is the previous election's
first preferences by class, so a seat where no independent stood has no `IND`
vote to swing. Calare 2025 is the clean illustration: Andrew Gee held it in 2022
*as a National*, quit the party, and won as an independent. Our 2022 baseline
has his vote under `LNP`, so the `IND` who actually won did not exist in our
input.

## Correcting the previous review

`reviews/seat-calibration-2026-08-22.md` concluded that we are "calibrated but
blunt — four times less informative per seat". **That is wrong**, and wrong in a
way I introduced.

It was measured in forecast mode, where a party under the poll-inclusion floor
is folded into `OTH`. `IND` is always under that floor — independents have no
statewide polling series by nature — so in forecast mode **independents cannot
win any seat at all**. The fold manufactured most of the gap it then measured.

Measured on the harness where `IND` exists as a class, the gap is not general
bluntness. It is one structural hole.

## What this reopens

Independent emergence has been modelled and refused **four times** in this repo
— `reviews/` carries v1 through v4, ending with *"the federal corpus reverses
it: the independent model makes the forecast WORSE"*.

Every one of those refusals was made against our own metrics, with no external
reference. What none of them could know is what the hole is *worth*. It is now
measured: **97% of the entire gap to a real forecaster**, and the reference
demonstrates the seats are forecastable — AE Forecasts put 0.28 to 0.51 on the
2022 teal seats before they fell.

That is not a reason to re-adopt a refused model. It is a reason to re-open the
question with evidence that did not exist when it was closed, and the previous
refusals are the right starting point precisely because they record what did not
work.

## What would need to be true

Any new attempt has to beat a specific bar rather than merely exist:

- it must **not** damage the 266 seats where we are already level — those carry
  no gap and every previous attempt was refused for making them worse;
- it must produce non-zero probability for an independent in a seat where none
  stood last time, which is the case our baseline structurally cannot represent;
- it must do so from information available before the election. AE Forecasts
  uses seat betting for four of its eight finals, but **not** the two compared
  here, so the information needed is evidently available without markets.

## What this does not say

- **Nothing about Victoria 2026**, which has zero independent-held seats. This
  gap costs us against a benchmark on federal elections; it may cost nothing on
  the election actually being forecast.
- **Nothing about seat-level TCP**, still unproduced and still unscored.
- **Nothing about why they are better on the 2022 teals specifically.** Their
  per-seat inputs include named-candidate scenarios and incumbency; which of
  those carries the signal is the next question, not an established answer.

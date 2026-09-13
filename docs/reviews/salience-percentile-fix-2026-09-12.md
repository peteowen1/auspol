# The salience percentile was measuring non-zero-ness, not salience

**2026-09-12.** Found while answering Pete's question "can we maybe fix them and
understand why salience is high when it shouldn't be".

## The symptom

Four independents sat at the 98th percentile of campaign salience and polled
almost nothing:

| seat | candidate | raw `jump` | old percentile | polled |
|---|---|---|---|---|
| Cowan 2007 | Norm Ramsay | 0.0220 | 0.9846 | 0.7 |
| Page 2007 | Tony Kane | 0.0220 | 0.9846 | 1.0 |
| McConnel 2020 | Miranda Bertram | 0.0570 | 0.9841 | 0.7 |
| Albert Park 2022 | Georgie Dragwidge | 0.0265 | 0.9904 | 5.9 |

Page and Cowan agreeing to four decimal places is the tell. Two unrelated
candidates in different states do not land on an identical percentile by
chance — they were tied on the underlying value.

## The cause

`jump` is **51% to 81% exactly zero** in every governed field.

| pair | governed | % exactly zero | distinct values | largest tied block |
|---|---|---|---|---|
| fed2007 | 552 | 81% | 62 | **447** |
| fed2010 | 443 | 80% | 48 | 353 |
| sa2026 | 173 | 79% | 18 | 137 |
| vic2022 | 418 | 76% | 63 | 319 |
| fed2022 | 573 | 62% | 151 | 353 |
| fed2016 | 717 | 51% | 295 | 363 |

`rank(jump, ties.method = "average") / .N` puts fed2007's 447-candidate zero
block at percentile 0.5507. **Anything above zero therefore starts above the
81st percentile**, and a value of 0.0220 — noise — reaches 0.9846.

The percentile was not measuring how salient a candidate was. It was mostly
measuring whether Google Trends returned any non-zero reading at all.

This is why salience and outcome correlated at **−0.096 inside the top bin**:
that bin mixed real campaigns with candidates whose only distinction was a
non-zero value.

## The fix

Rank among **non-zero values only**; zero stays zero.

```r
nz <- which(is.finite(s$jump) & s$jump > 0)
s[, jump_pctile := 0]
if (length(nz) >= 10)
  set(s, nz, "jump_pctile", rank(s$jump[nz], ties.method = "average") / length(nz))
```

The percentile now means "among candidates with any search signal, how strong".

## Verified on cases whose answer was known first

False positives fall; the six 2022 teals hold:

| candidate | old | new | polled |
|---|---|---|---|
| Norm Ramsay (Cowan) | 0.9846 | **0.6600** | 0.7 |
| Tony Kane (Page) | 0.9846 | **0.6600** | 1.0 |
| Will Anderson (Kooyong, the *other* independent) | 0.8805 | **0.5523** | 0.3 |
| Monique Ryan (Kooyong) | 1.0000 | 1.0000 | 40.3 |
| Allegra Spender (Wentworth) | 0.9948 | 0.9804 | 35.8 |
| Zoe Daniel (Goldstein) | 0.9930 | 0.9739 | 34.5 |

## What it bought

Independents above the 90th percentile, before and after:

| | candidates | won | strike rate |
|---|---|---|---|
| old | 246 | 47 | 19% |
| **new** | **46** | **26** | **57%** |

Primary-vote model, leave-one-pair-out RMSE in points:

| | pooled | IND |
|---|---|---|
| v6 (shipped) | 3.9201 | 4.908 |
| v7 on the broken percentile | 3.8710 | 4.794 |
| **v7 on the fix** | **3.8489** | **4.667** |

And the model becomes calibrated at every level, which it was not before:

| salience band | IND cells | actual | predicted |
|---|---|---|---|
| zero | 1,736 | 2.3 | 2.4 |
| 0–0.5 | 109 | 8.4 | 8.5 |
| 0.5–0.9 | 159 | 13.9 | 13.4 |
| 0.9–0.95 | 23 | 28.4 | 25.4 |
| 0.99–1.0 | 9 | 34.3 | 32.7 |

## Scope, and what is NOT yet fixed

`R/salience_surge.R:92` builds `jump_pctile` the original way and still does.
Every consumer of the surge machinery inherited the distortion — plausibly part
of why the surge hazard fired into quiet seats and cost fed2019 +0.229 of seat
log loss before it was binned on 2026-09-12. **Porting the fix there is
outstanding**, and the surge being off does not make it safe to leave: the same
function feeds `salience_expected` and the sd override.

## The general lesson

**A percentile only means what it sounds like if the underlying variable is
roughly continuous.** On a variable that is majority-identical, ranking reports
"is this value different from the mode", and the tie-averaged block silently
occupies whichever percentile its size dictates.

Before percentile-ranking anything: print `% exactly zero`, the count of
distinct values, and the size of the largest tied block. Three numbers, and all
three were wrong here in a way no downstream metric revealed — the feature
looked populated, the model trained, and the error surfaced only when a human
asked why two candidates in different states had identical salience.

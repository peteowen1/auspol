# One Nation wins Labor seats in our model and Coalition seats in reality

Found 2026-08-25 while asking why our Victorian One Nation seats differ from
YouGov's. **Nothing changed.** This records a suspected defect and the evidence
for it; any fix needs its own pre-registration.

**YouGov is not treated as truth anywhere below.** It generated the question;
South Australia 2026 answers it.

## The finding

**Our model elects One Nation in Labor-leaning seats and effectively never in
Coalition-leaning ones. South Australia 2026 — the only election where the
party won seats at this scale — did the exact opposite.**

| | our Victoria 2026 | SA 2026 actual |
|---|---:|---:|
| ONP seats in **ALP**-leaning territory | **6 of 6** | **0 of 5** |
| ONP seats in **LNP**-leaning territory | **0 of 6** | **5 of 5** |

Not one seat overlaps in type.

## The innocent explanation is ruled out

The obvious defence is that Victorian One Nation support genuinely sits in
outer-suburban Labor seats, so our ordering is faithful and South Australia's
pattern simply does not transfer. **It does not hold.**

Our allocation ranks seats by their transposed federal One Nation vote
(`fit_seats_full.R:344-361`). Among the **20 Victorian seats with the highest
federal ONP vote, the split is exactly 10 ALP-leaning and 10 LNP-leaning.** The
input is evenly spread. The output is not:

| 2022 lean | seats | mean ONP probability | seats we give ONP |
|---|---:|---:|---:|
| ALP-leaning | 57 | **0.143** | **5** |
| LNP-leaning | 30 | **0.036** | **0** |

A 4x gap in output from an evenly-split input.

### The same federal vote converts, or does not, purely by seat type

| seat | 2022 lean | federal ONP | our P(ONP) |
|---|---|---:|---:|
| Gippsland East | LNP (63.3) | **11.68** | **0.048** |
| Murray Plains | LNP (61.8) | 10.37 | 0.051 |
| Shepparton | LNP (52.6) | 10.01 | 0.048 |
| Euroa | LNP (53.8) | 9.46 | 0.053 |
| Lowan | LNP (58.9) | 8.16 | 0.050 |
| — | | | |
| Eureka | ALP (41.0) | 9.80 | **0.682** |
| Sunbury | ALP (43.1) | 8.70 | **0.639** |
| Melton | ALP (37.7) | **7.75** | **0.561** |

**Gippsland East has more federal One Nation vote than any seat we give the
party except Morwell, and scores 0.048. Melton has less than all of them and
scores 0.561.** The discriminator is not the ONP input; it is who else is in
the seat.

## Why, mechanically

`shares` is built by adding each party's statewide swing to its 2022 seat share
and renormalising (`fit_seats_full.R`, and the same construction in every
backtest harness). Renormalising takes One Nation's gain **proportionally from
every party in the seat.**

So where the Coalition holds 58.9%, a proportional haircut leaves it dominant
and One Nation cannot overtake it. Where Labor holds 43% and the Coalition 31%,
One Nation slots into second and wins on preferences.

**South Australia says that is not how the vote moved.** Across 46 districts,
2022 → 2026:

| where ONP gained most (top decile, n=5) | mean change |
|---|---:|
| Labor | **−4.96** |
| Coalition | **−17.69** |

The Coalition lost **3.6x** what Labor did. In MacKillop the Liberal vote fell
**67.0 → 26.8, a 40-point collapse**, and One Nation took the seat. Every one of
the five seats One Nation won was Coalition-leaning.

A proportional model cannot represent that. It is structurally unable to elect
One Nation in the seats where One Nation has actually won.

## What this does NOT establish

- **n = 5.** One election, one state. South Australia has no Nationals, so it
  cannot show the three-cornered contests that make rural Victoria different —
  and `AUSPOL_WA_FLOWS` was refused partly because that shape does not transfer.
- **The 2022 baseline predates the surge**, so "lean" is measured before One
  Nation existed at scale. A seat's 2022 type may not be the right conditioning
  variable.
- **The marginal regression is not as clean as the group means.** Across all 46
  SA districts, `cor(ONP gain, ALP change) = −0.507` against
  `cor(ONP gain, LNP change) = −0.171`: the Coalition fell hard almost
  everywhere, somewhat independently of exactly where One Nation gained most.
  So "One Nation eats the Coalition" is the right description of the *levels*
  and an overstatement of the *gradient*. Both are reported here rather than
  the one that argues better.
- **It does not say YouGov is right.** They also give One Nation seats we score
  near zero on low federal ONP vote (Bendigo West rank 60, Greenvale rank 69),
  which this evidence does not support either.
- **`CLAUDE.md` already says to trust the One Nation TOTAL, not any single
  seat.** This finding is about a systematic asymmetry across 87 seats, not
  about any one of them — which is why it is worth recording despite that rule.

## Why it matters even though the total may be right

Our published One Nation total (6 seats by argmax, 9.25 expected) is not
obviously wrong. But **if the party wins Coalition seats rather than Labor
ones, the same total implies a completely different parliament** — it changes
which side loses seats, and therefore who governs. A total that is right for
the wrong reason will not stay right.

## Next, and it needs its own plan

The testable question, written down before anything is fitted: **does replacing
proportional renormalisation with a source-weighted allocation — One Nation's
gain drawn disproportionately from the Coalition — improve seat-level accuracy
on the elections where the party actually contested?**

Candidates for the test set: SA 2026 (4-5 ONP seats), WA 2017, QLD 2020/2024,
NSW 2019. That is a real corpus, unlike the two aborted experiments of
2026-08-25, and the effect size here is large enough to be detectable.

**Pre-register before running**, including: what would make a win unacceptable
(a change that improves ONP seats while degrading the majors is not a win), and
the direction the criterion cannot see.

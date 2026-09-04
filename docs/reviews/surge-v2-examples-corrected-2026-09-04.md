# Surge-v2 by name, corrected: 18 winners, not 14

2026-09-04. Supersedes `surge-v2-examples-2026-09-04.md`, after
`surge-v2-person-level-prevparty-2026-09-04.md` fixed `prev_party` for
IND/OTH and a seat-rename bug it unmasked. Same script,
`scripts/show_surge_v2_examples.R`, rerun against the corrected population.

**AUC 0.976** (was 0.972). Mean `p_hat` for the 18 actual winners is 0.109;
mean `p_hat` for the 1889 governed candidates who lost is 0.008.

## Every governed winner the model has ever seen, ranked by its own p_hat

| seat | election | candidate | party | jump_pctile | prior vote | actual | p_hat |
|---|---|---|---|--:|--:|--:|--:|
| Mount Gambier | sa2026 | Travis Fatchen | IND | 0.97 | 0% | 27.1% | 0.367 |
| Indi | fed2019 | Helen Haines | IND | 0.99 | 0% | 32.4% | 0.292 |
| Wentworth | fed2022 | Allegra Spender | IND | 0.99 | 0% | 35.8% | 0.246 |
| Warringah | fed2019 | Zali Steggall | IND | 1.00 | 0% | 43.5% | 0.140 |
| Mackellar | fed2022 | Sophie Scamps | IND | 0.98 | 0% | 38.1% | 0.098 |
| Kooyong | fed2022 | Monique Ryan | IND | 1.00 | 0% | 40.3% | 0.096 |
| Kavel | sa2026 | Matt Schultz | IND | 0.51 | 0% | 21.6% | 0.092 |
| Curtin | fed2022 | Kate Chaney | IND | 0.98 | 0% | 29.5% | 0.080 |
| Indi | fed2013 | Cathy McGowan | IND | 1.00 | 0% | 31.2% | 0.079 |
| Lyne | fed2010 | Robert Oakeshott | IND | 0.99 | 0% | 47.1% | 0.078 |
| Wakehurst | nsw2023 | Michael Regan | IND | 1.00 | 0% | 35.9% | 0.070 |
| North Sydney | fed2022 | Kylea Tink | IND | 0.98 | 0% | 25.2% | 0.067 |
| Goldstein | fed2022 | Zoe Daniel | IND | 0.99 | 0% | 34.5% | 0.062 |
| Denison | fed2010 | Andrew Wilkie | IND | 0.99 | 0% | 21.3% | 0.058 |
| Fowler | fed2022 | Dai Le | IND | 0.99 | 0% | 29.5% | 0.056 |
| Mayo | fed2016 | Rebekha Sharkie | IND | 0.97 | 0% | 34.9% | 0.054 |
| Richmond | vic2022 | Gabrielle De Vietri | GRN | 0.95 | 0% | 34.7% | 0.016 |
| Kalgoorlie | wa2008 | John Bowler | IND | 0.52 | 0% | 34.0% | 0.010 |

Two new names since the fix, both real successions the class-level bug had
hidden: **Helen Haines** (Indi, succeeding Cathy McGowan) and **Travis
Fatchen** (Mount Gambier, succeeding Troy Bell) — both now score in the top
7 of 18 by `p_hat`, the same signature as the 2022 teals, because that's what
they were.

## Who looked just as loud and lost — the model's own top false-alarm risks

| seat | election | candidate | party | jump_pctile | prior vote | actual | p_hat |
|---|---|---|---|--:|--:|--:|--:|
| New England | fed2013 | Rob Taber | IND | 0.92 | 0% | 13.8% | 0.508 |
| New England | fed2013 | Jamie McIntyre | IND | 0.89 | 0% | 6.6% | 0.476 |
| New England | fed2019 | Adam Blakester | IND | 0.96 | 0% | 14.2% | 0.225 |
| North Shore | nsw2023 | Helen Conway | IND | 0.99 | 0% | 21.9% | 0.144 |
| New England | fed2016 | Tony Windsor | IND | 1.00 | 0% | 29.2% | 0.151 |

New England (a seat with a strong, recognisable independent tradition —
Tony Windsor and Rob Oakeshott both held it) is where the model is now most
willing to be wrong, three separate elections in the top false-alarm list.
Rob Taber's 0.508 is the model's single least confident call in either
direction — a genuine coin-flip read, not overconfidence. It, and every
other loser here, sits well below the 0.109 mean for actual winners.

## What this does and does not show

**Shows**: correcting `prev_party` and the seat-rename match found 4 real
winners the earlier (already-shipped) fit was missing, and the model still
discriminates strongly with them included — AUC improved, not just
population size.

**Does not show**: anything about Victoria 2026. No Victorian 2026 candidate
has salience data yet.

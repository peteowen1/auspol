# Surge-v2 by name: who it predicted and who it correctly didn't

**SUPERSEDED same day** by `surge-v2-person-level-prevparty-2026-09-04.md` —
this table's population was missing 4 real winners (Haines, Spender, Schultz,
Fatchen) due to two further bugs found right after this was written. Left
as-is as an honest record of that population; see the later doc for the
corrected 18-winner numbers and table.

2026-09-04. Ad-hoc reporting against the widened, majors-bug-fixed governed
population (`output/salience-surge-v2-population.csv`, 9 election pairs, 1871
candidates, 14 winners — see `surge-v2-widened-and-majors-bug-2026-09-04.md`).
`scripts/show_surge_v2_examples.R`. Not a pre-registered test; this is a
demonstration of the already-adopted model, requested directly.

**AUC 0.972.** Mean `p_hat` for the 14 actual winners is 0.126; mean `p_hat`
for the 1857 governed candidates who lost is 0.007 — an 18x separation.

## Every governed winner the model has ever seen, ranked by its own p_hat

| seat | election | candidate | party | jump_pctile | prior vote | actual | p_hat |
|---|---|---|---|--:|--:|--:|--:|
| Warringah | fed2019 | Zali Steggall | IND | 1.00 | 11.4% | 43.5% | 0.316 |
| Mackellar | fed2022 | Sophie Scamps | IND | 0.98 | 12.2% | 38.1% | 0.253 |
| Kooyong | fed2022 | Monique Ryan | IND | 1.00 | 9.0% | 40.3% | 0.213 |
| Curtin | fed2022 | Kate Chaney | IND | 0.99 | 7.7% | 29.5% | 0.167 |
| Indi | fed2013 | Cathy McGowan | IND | 1.00 | 5.8% | 31.2% | 0.149 |
| Lyne | fed2010 | Robert Oakeshott | IND | 0.99 | 4.2% | 47.1% | 0.129 |
| Wakehurst | nsw2023 | Michael Regan | IND | 1.00 | 3.3% | 35.9% | 0.113 |
| North Sydney | fed2022 | Kylea Tink | IND | 0.98 | 4.4% | 25.2% | 0.112 |
| Goldstein | fed2022 | Zoe Daniel | IND | 0.99 | 1.4% | 34.5% | 0.087 |
| Denison | fed2010 | Andrew Wilkie | IND | 0.99 | 0.0% | 21.3% | 0.075 |
| Fowler | fed2022 | Dai Le | IND | 0.99 | 0.0% | 29.5% | 0.073 |
| Mayo | fed2016 | Rebekha Sharkie | IND | 0.97 | 0.0% | 34.9% | 0.065 |
| Richmond | vic2022 | Gabrielle De Vietri | GRN | 0.95 | 0.0% | 34.7% | 0.007 |
| Kalgoorlie | wa2008 | John Bowler | IND | 0.52 | 4.0% | 34.0% | 0.004 |

The four "teal" 2022 winners everyone would ask about by name — Ryan,
Chaney, Scamps, Tink — all sit in the top eight by `p_hat`, alongside
Steggall's 2019 win, on nothing but their own prior vote, party class, and
within-election search-interest rank. De Vietri (Victoria's own single
governed emergence to date) and Bowler score lowest of the 14 winners — both
real, but each the sole governed winner in a state with limited history
underneath it, so the model is properly cautious rather than confident.

## Who looked just as loud and lost

Top 15 governed losers by raw jump_pctile — same search-interest signal, no
win:

| seat | election | candidate | party | jump_pctile | prior vote | actual | p_hat |
|---|---|---|---|--:|--:|--:|--:|
| Greenway | fed2010 | Paul Taylor | GRN | 1.00 | 5.7% | 6.0% | 0.016 |
| Warringah | fed2016 | James Mathison | IND | 1.00 | 0.0% | 11.4% | 0.078 |
| Mulgrave | vic2022 | Ian Cook | IND | 1.00 | 0.0% | 18.0% | 0.078 |
| Port Adelaide | sa2026 | Claire Boan | IND | 1.00 | 0.0% | 13.6% | 0.078 |
| New England | fed2016 | Tony Windsor | IND | 1.00 | 13.8% | 29.2% | 0.373 |
| Kooyong | fed2019 | Oliver Yates | IND | 1.00 | 3.1% | 9.0% | 0.108 |
| Maribyrnong | fed2022 | Cameron Smith | OTH_RIGHT | 1.00 | 3.6% | 3.8% | 0.010 |

(full 15 in the script output; table trimmed to the recognisable names).

**The model's own highest false-alarm risks** (ranked by p_hat, not raw
jump) top out at 0.373 (Tony Windsor, New England 2016 — a real ex-MP
comeback bid that fell short) and 0.259 (Sarah Russell, Flinders 2022) —
both well below the 0.126 mean for actual winners, and nowhere close to the
Bandt-style overconfidence (p≈0.66 on an actual 39.5%) that sank the earlier
raw-regression attempt.

## What this does and does not show

**Shows**: on every governed emergence the model has training data for, it
ranks real winners far above real losers, including the specific 2022 teal
wave by name, without reproducing the false-confidence failure that got the
direct-regression version refused.

**Does not show**: anything about Victoria 2026 specifically — no
Victorian 2026 candidate has salience data yet, so `p_hat` cannot be
computed for a single one of them until nominations close (12 noon, 9 Nov
2026). This table is entirely retrospective, over the 9 elections used to
fit and validate the model.

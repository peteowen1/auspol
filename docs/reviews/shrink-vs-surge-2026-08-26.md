# The surge works where non-majors emerge, and a FLAT hazard is the wrong shape

2026-08-26. Against `docs/plans/prereg-shrink-vs-surge-powered.md`.

## The arms

Four, all pre-registered before any ran, with arm C named in advance
specifically so "maybe they are complements" could not be reached for after
seeing A and B.

| | `shrink` | `surge_h` |
|---|---|---|
| A | 0.10 (incumbent) | — |
| B | — | 0.0508 |
| C | 0.05 | 0.0508 |
| D | — | — |

## The result

| harness | A | B | C | D |
|---|---:|---:|---:|---:|
| **SA** Brier | 0.1464 | 0.1470 | **0.1444** | 0.1492 |
| **SA** log | 0.4701 | 0.5438 | **0.4612** | 0.8019 |
| **SA** slope | 1.085 | 0.692 | **0.984** | 0.325 |
| **NSW** Brier | **0.1421** | 0.1437 | 0.1447 | 0.1434 |
| **NSW** log | 0.9172 | **0.7806** | 0.7969 | 0.9608 |
| **NSW** slope | 1.553 | 0.474 | 1.284 | 0.435 |
| **WA** Brier | **0.1014** | 0.1028 | 0.1022 | 0.1019 |
| **VIC** Brier | **0.0896** | 0.0899 | 0.0900 | — |

**Flat `shrink` wins on Brier in three of four harnesses.** The surge wins on
log score in NSW and, combined with a halved shrink, wins outright in South
Australia.

## What that actually says

The split is not noise and it is not ambiguous:

- **SA** — One Nation won four seats. Arm C wins on every metric, and the slope
  lands at 0.984.
- **NSW** — nine independents won. Arm B cuts the log score from 0.9172 to
  0.7806, the largest single improvement in the table.
- **WA and Victoria** — largely two-party contests across the pairs tested. The
  surge is neutral to slightly negative.

**The mechanism is not wrong. The hazard being constant is wrong.** A flat
5.08% surge chance applied to every seat in every election adds probability
where nothing is happening, and pays for it in Brier wherever non-majors did
not emerge. That is precisely the cost of not conditioning it.

## The previous version of this experiment was void

Run earlier the same day, it compared arm B against arm D as **the same
configuration** in Victoria, NSW and South Australia — `surge_h` had been
implemented in `seat_sim.R` and wired into the federal and WA harnesses only.
Byte-identical outputs caught it: SA returned 0.1492 / 0.8019 / 0.325 for both
arms, NSW 0.1434 / 0.9608 / 0.435.

The one conclusion drawn from that run — "surge loses to shrink" — came from
arms that never ran. Third breach of the fix-everywhere rule in a day.

## Consequence for the salience work

This is the baseline the salience-conditional hazard has to beat, and it makes
the case for it. Salience fires in Curtin and North Sydney and sits at zero in
the ~130 seats where nobody is being searched for, which is exactly the
conditioning the flat hazard lacks.

It also sets an honest bar: the salience version must beat **arm A on Brier**,
not merely beat the flat surge.

## Limits

- **Brier and log disagree** in NSW — A wins one, B the other. They measure
  different things and neither is decisive alone.
- **Reliability buckets not yet scored** for these arms; the pre-registered
  primary criterion is reliability, not Brier.
- **Federal not run** in this round — six of the seventeen pairs are missing,
  and they are the pairs with the most power.
- **Victoria's D arm** did not complete before the run ended.

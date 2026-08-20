# Round 3: the port picks winners better and calibrates worse. The calibration is the real problem.

Run against
[../plans/prereg-seat-swing-port-round2.md](../plans/prereg-seat-swing-port-round2.md).
**Still not adopted. Still refused on P2** — and this time the refusal points at
something bigger than the port.

## What changed since round 2

South Australia is the third testable election: `2026sa.txt` carries `fed_swing`
for all 47 seats. The federal corpus cannot help — its seat files carry it for
**zero** seats, because "how this seat swung at the preceding federal election"
has no federal analogue.

| election | seats | gain |
|---|---:|---:|
| vic2022 | 78 | +0.00391 |
| nsw2023 | 88 | +0.00043 |
| **sa2026** | 47 | **+0.03142** |

| | difference | SE | |
|---|---:|---:|---:|
| per-seat, 213 seats | −0.00854 | 0.00727 | −1.18 SE |
| **election-clustered, 2 df** | −0.01192 | 0.00980 | **−1.22 SE** |

**P1 now passes.** Dropping any single election leaves the result between −1.03
and −1.28 SE, so nothing rests on one election — which was the open worry in
round 2, where South Australia did not exist and Victoria carried nine tenths of
the magnitude.

Zone 3's four criteria all hold, as in round 2, and the direction is now
positive in **3 of 3**.

## P2 fires harder, not softer

| calibration slope | off | on | |
|---|---:|---:|---|
| vic2022 | 2.515 | 0.679 | toward 1 |
| nsw2023 | 0.541 | 0.338 | **away** |
| sa2026 | 0.299 | **0.146** | **away** |

Two of three now, and South Australia's is the worst move in the set.

## The federal corpus explains why, and reframes the whole question

Six federal elections, never previously scored against this model:

| | fed2010 | fed2013 | fed2016 | fed2019 | fed2022 | fed2025 |
|---|---:|---:|---:|---:|---:|---:|
| slope | 0.249 | 0.189 | 0.297 | 0.329 | 0.183 | 0.441 |

**The model is over-confident in 9 of the 10 elections now measured.** The one
exception is Victoria 2018→2022 at 2.515 — which is precisely the election where
the port *helped* calibration, because there sharpening corrected genuine
timidity.

So the pattern is not that the port is bad. It is that **the port improves
discrimination and worsens calibration**, and this model has plenty of the
first problem and a lot of the second:

- it picks winners better — **+4 seats in South Australia** (38/47 to 42/47) and
  +4 in Victoria (65/78 to 69/78);
- South Australia's log score improves too, 1.3670 to 1.2152;
- and its probabilities get more extreme in a model whose probabilities are
  already too extreme nearly everywhere.

## What this changes about what to do next

Round 2 recommended a third election. It has one now, and the answer did not
flip — it sharpened. **A fourth election is not the constraint.**

The constraint is that **the port is being tested on top of a miscalibrated
model**, so a change that adds real signal is penalised for making the existing
over-confidence more visible. Fixing the calibration first and re-testing is the
ordering that can actually resolve this; testing the port again first cannot.

That fix has a trap already recorded in this repo: the shrinkage control arm.
**Any noise added to an over-confident model improves calibration**, so a
calibration fix must be shown to beat that null rather than merely to move the
slope toward 1 — otherwise the finding is "we added noise", which needs no
model.

The port stays behind `AUSPOL_SEAT_SWING_PORT`, default off. **Not deleted**:
zone 2 is for a feature that does not help, and this one now helps on three
elections out of three.

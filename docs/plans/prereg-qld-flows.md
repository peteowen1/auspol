# Pre-registration: add Queensland to the flow matrix

Written 2026-08-21, **before anything is measured**. Committed before running.

## What changes

The flow matrix deciding Victorian seats is built from Victoria 2022 (452
exclusions) and South Australia 2026 (294). Queensland 2020 and 2024 add 750.

| | current | plus Queensland |
|---|---:|---:|
| exclusion events | 746 | **1,496** |
| cells at n ≥ 3 | 53 | **78** |
| **One Nation exclusions** | **18** | **198** |
| One Nation votes transferred | 76,912 | **619,631** |

**Eighteen exclusion events is what every One Nation preference rate in the
published forecast currently rests on.** Queensland is where that party has had
support for thirty years, and this is an eleven-fold increase in the scarcest
input the model has.

## Leakage, which decides the design

Queensland 2020 was held in October 2020 and 2024 in October 2024. A backtest
may use them **only for elections held after them**:

| election predicted | may use |
|---|---|
| vic2018, fed2010–fed2019, nsw2019 | neither |
| fed2022 (May 2022), vic2022 (Nov 2022), nsw2023 (Mar 2023) | qld2020 |
| fed2025 (May 2025), sa2026 (Mar 2026) | qld2020 and qld2024 |

So **five of the ten backtest elections can be improved and five cannot.** The
five that cannot are the control: their arms must come out **byte-identical**,
and if they do not, the filter has leaked.

## What is measured

**Per-seat log score, leave-one-election-out, clustered on the election** — the
harnesses' native criterion, the same one the calibration work used.

Reported alongside: accuracy, and the One Nation seat range for Victoria 2026.

## Decision rule, fixed now

- **Adopt if the clustered difference across the five improvable elections
  exceeds 2 SE**, on 4 degrees of freedom.
- **If it is positive but under 2 SE, adopt anyway**, provided the five control
  elections are identical and no refusal fires. This is a data-coverage change,
  not a parameter: the alternative to 198 One Nation exclusions is 18, and a
  rate estimated from 18 events is not preferable to one estimated from 198
  merely because a test on four degrees of freedom cannot resolve them. **That
  reasoning is written down now so it cannot be invented afterwards.**
- **If it is negative by more than 1 SE, refuse and investigate** — that would
  mean Queensland's transfers are unlike Victoria's in a way that matters, which
  is a finding about transferability, not a reason to shrug.

## Refusals

- **Q1 — the five control elections must be byte-identical.** They can use no
  Queensland data. If they move, the date filter leaked and nothing else in the
  run can be believed.
- **Q2 — optional preferential must stay out.** Queensland used it until 2016.
  Those transfers exhaust and their rates mean something different. Only 2020
  and 2024 are admitted, and the fetcher already refuses on `votingSystem`.
- **Q3 — One Nation improving is EXPECTED and is not the evidence.** The whole
  motivation is more One Nation data. If the case rests on One Nation's own
  numbers rather than the overall score, it is circular.
- **Q4 — the live forecast.** If any party's Victoria 2026 median moves by more
  than **2**, stop and report rather than ship.
- **Q5 — no cherry-picking the pool.** Both Queensland elections go in or
  neither. Choosing which to include after seeing the result is exactly the
  failure the pre-registration exists to prevent.

## What this cannot see

- **Whether Queensland preferences resemble Victorian ones.** It is a different
  state with a different party system and no Nationals-versus-Liberals split of
  the kind Victoria has. The matrix is keyed on party class and survivor set,
  which assumes those classes behave alike across states — an assumption this
  test uses rather than checks.
- **Anything about the One Nation allocation**, which is a separate input and
  remains fitted on one election.

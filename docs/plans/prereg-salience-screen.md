# Pre-registration: salience as a SCREEN, not a ranking

2026-08-27, written before the screen has been wired into any harness.

## Why this design and not the four that failed

Every previous arm fed salience into a magnitude — a hazard, a regression term,
a conditional slope — and every one was refused. The data supports something
narrower and stronger.

**Candidates salience is silent on do not win:**

| election | silent | winners among them | share of field firing |
|---|--:|--:|--:|
| fed2022 | 243 | **0** | 33% |
| fed2025 | 258 | **0** | 34% |
| vic2022 | 149 | **0** | 22% |
| nsw2023 | 175 | 1 | 15% |
| sa2026 | 104 | **6** | **6%** |

650 silent candidates across the three strongest elections, zero winners. It
fails only where the FIELD does not register, and that condition is detectable
in advance without any outcome data.

## The screen

For each non-major candidate, in an election that passes the registration test
below:

| salience | what the model may do |
|---|---|
| **silent** (jump ≤ 0) | treat as a non-emergent: the new-candidate slope applies and no upside is added |
| **fires** (jump > 0) | must NOT be shrunk toward the statewide mean |
| **field silent** | screen is inert; fall back to today's class-based model unchanged |

**Registration test, decided from the field alone:** at least **10%** of
non-major candidates must have `jump > 0`. fed2022 33%, fed2025 34%, vic2022
22%, nsw2023 15% pass; sa2026 at 6% does not. The threshold sits between 6 and
15, and it is fixed here before the screen is scored anywhere.

This is a **targeted** change under the rule adopted this morning, so its primary
metric is scored on the target population, not election-wide.

## Criteria

### Primary — the targeted population

The ~300 candidates per election with **no prior vote in the seat**, which arm C
proved the model handles worst. **Log loss on those rows must improve**, on
fed2022, vic2022 and nsw2023, by at least the MDE.

Log loss is primary per `b5defb9`: it is the only metric that charges a seat
called 0.9997 and lost more than one called 0.90 and lost, which is the failure
being fixed.

### Secondary — do no harm

Election-wide log loss must not worsen by more than **0.0089**, the Brier-scale
MDE clustered on five harnesses. Reported for all five, per fix-everywhere.

### Guard — the screen must actually fire

The number of candidates the screen silences must fall between **50% and 90%** of
the non-major field. Below 50% it is not screening; above 90% it is silencing
seats it should not.

## Dry-run: verdicts fixed before running

| case | expected | what it tests |
|---|---|---|
| **Chantelle Thomas**, Narungga, 5.4% prior → won on 37.7% | screen **inert** — sa2026 fails the registration test | the SA condition must disable the screen, not mis-fire it |
| **Dai Le**, Fowler 2022, 0.0% prior → won on 29.5% | fires; must not be shrunk | the case no other mechanism reaches |
| **Ian Cook**, Mulgrave 2022, fired, polled 18.0%, LOST | fires and still loses | firing is permission, not a prediction — the count decides |
| a Greens candidate on 2% with no search presence | silenced | the 300-candidate population the screen exists to handle |
| **Geoff Brock**, Stuart 2026, silent, WON on 40.3% | screen inert (SA) | if the screen were active it would be wrong here, which is why the registration test exists |

If the code disagrees with any row, the code is wrong.

## Refusal

- **If it fires on a field below the 10% registration threshold.** That is the SA
  condition and the screen must be inert there, not merely weak.
- **If silencing hurts the silent seats.** They are 78–85% of the field; a gain
  on emergents paid for by everyone else is not a gain.
- **If the improvement is confined to fed2022.** That is the teal wave and the
  fitting election for every salience design so far.
- **If the guard fails at either end.**
- **If any Victorian party's 2026 median moves by more than 3 seats.** Stop and
  hand the decision to Pete, as with the Queensland flows.

## What the criteria cannot see

- **Salience measures attention, not support.** David Speirs topped South
  Australia on 14.1% of the vote. Ian Cook topped Victoria and lost. The screen
  is deliberately one-directional for this reason: firing grants permission, it
  never predicts a win.
- **Four elections, one of them the fitting set.**
- **Nothing here tests vic2026 itself**, whose candidates are not yet nominated —
  and the registration test cannot be run until they are.
- **A single Trends pull per candidate.** No replicates.
- **WA is excluded entirely**: it publishes bare surnames, so its search terms
  are unusable and the screen cannot be evaluated there.

---

# AMENDMENT, 2026-08-27: the governed population, corrected before scoring

Added before the screen was scored anywhere. The section above is left unedited.

## What changes

The document defines the governed population as **prior party vote < 15%**. That
definition is wrong in two ways, both demonstrated after it was written and
neither dependent on any result of the screen:

1. **A returning candidate can read as new.** Philip Donato held Orange with
   49.1% as a Shooter in 2019 and 53.1% as an independent in 2023.
   `candidate_returns()` matched within (seat, party), so a five-year sitting
   member counted as a new independent.
2. **A party surge is not a candidate emergence.** One Nation went from 2.63% to
   22.50% of the South Australian vote, contesting 47 seats instead of 19, with
   19 of 47 candidates above 25%. Its winners had no prior seat vote because the
   PARTY had none. Uniform swing predicts Hammond exactly and the rest within 7
   to 15 points.

**Governed** now means: prior party vote < 15%, **and** not the same person who
contested that seat last time, **and** not a class whose statewide vote moved by
5 points or more.

## Why this is not a rescue

Both faults are demonstrable without reference to the screen's performance — one
from an electoral record, one from a statewide vote share — which is the test
`CLAUDE.md` requires before a committed criterion may be changed.

And the amendment makes the test **harder**, not easier. It removes 289
candidates from the population, including every one of the four South Australian
One Nation winners, which were the screen's only remaining misses. A rescue would
add cases the screen gets right; this removes cases it was being blamed for and
shrinks the sample it must succeed on.

## The criteria are otherwise unchanged

Primary, secondary, guard, registration threshold, dry-run and refusals all
stand. The dry-run rows for Chantelle Thomas and Geoff Brock are now doubly
covered: sa2026 fails the registration test AND both are outside the governed
population.

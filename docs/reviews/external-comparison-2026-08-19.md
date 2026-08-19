# How our Victorian forecast compares to everyone else's

Compiled 2026-08-19. **This compares published OUTPUTS. It says nothing about
accuracy** — no forecast here has been scored against a result, ours included,
and the election is 101 days away.

## The numbers

| | **ours** | YouGov MRP | Roy Morgan |
|---|---:|---:|---:|
| **Primaries** | | | |
| Coalition | **28.7** | 26 | 26 |
| Labor | **25.0** | 23 | 26 |
| **One Nation** | **20.2** | **24** | **23.5** |
| Greens | **12.9** | 13 | 12.5 |
| **Two-party (Labor)** | **47.95** | 46.2 | 49 |
| **Seats** | | | |
| Labor | **40** | **29** | — |
| Coalition | **38** | **39** | — |
| **One Nation** | **3** | **17** | — |
| Greens | **5** | 3 | — |

Ours: `output/victoria-2026.html`, 2026-08-19. YouGov MRP from its own report
for Common Threads (fieldwork **16 June – 10 July 2026**, n = **4,003**, MoE
**±1.8%**, MRP across all 88 lower-house seats). Roy Morgan as reported by The
Poll Bludger, August 2026.

YouGov's seat breakdown: Coalition 39 (31 Liberal, 8 National), Labor 29
(losing 15 to One Nation and 12 to the Coalition), One Nation 17, Greens 3.

## Where we agree

**The two-party number.** Ours is 47.95 for Labor; YouGov has 46.2 and Morgan
49. We sit between them. Greens primary and Coalition primary are also within a
couple of points of both.

## Where we do not, and it is one thing twice

**One Nation.** We have it 3–4 points lower on primaries than either poll —
**20.2 against 23.5 and 24, both above our own 95% upper bound of 22.2** — and
then 3 seats against YouGov's 17.

Those are not two disagreements. They are one, amplified.

A seat is a threshold event. Our own external check against South Australia put
the 50% point at roughly a third of the primary vote, so moving One Nation's
statewide share from 20 to 24 lifts a large number of seats across a line that
almost none of them currently reach. **The seat gap is what a three-point
primary gap looks like after it passes through a threshold.**

## The sharper number: where One Nation LEADS

The seat totals understate the divergence. YouGov's report says One Nation
loses seats it leads on primaries in two separate ways:

- **the Coalition wins 4 rural seats** where One Nation leads on primaries, on
  preference flows from left voters;
- **Labor wins 9 seats** where One Nation leads on primaries, "as One Nation
  struggles to attract preferences".

So YouGov has One Nation **leading on first preferences in roughly 30 of 88
seats** and converting 17 of them.

**Our model projects One Nation first on primaries in 2 seats.**

That is the divergence stated in the form that matters. It is not mainly a
disagreement about preferences — YouGov has One Nation losing 13 seats it leads,
so it models One Nation's preference weakness at least as harshly as we do. It
is a disagreement about **how high One Nation's vote goes in its best seats**.

Our projected One Nation maximum is 33.0%; the seats YouGov has it winning are
"provincial and outer suburban working class" — which is the same *kind* of seat
our Greens-share ordering favours, so the ordering is not obviously the problem.
The level is.

## Independents, corroborated

YouGov names **Kew and Hawthorn** as seats "where the main challenger is an
independent". Our model gives independents a maximum win probability anywhere of
**2e-04, in Hawthorn**.

That is external support for the defect recorded in
[independents-cannot-win](independents-cannot-win-2026-08-19.md) — and it names
one of the same seats.

## And we already know why the primary is low

This is the same defect diagnosed in NSW on 2026-08-19
([nsw-onp-walk](nsw-onp-walk-2026-08-19.md)): the trend model lags a party
rising fast from a near-zero base.

- Victoria's One Nation is fitted at **20.4** against a 90-day poll mean of
  **23.15** — a gap of 2.39 that the `L3` check flags and which sits just inside
  its 2.5 bound.
- NSW's is fitted at **19.5** against **24.67**, which breaches and is what
  keeps the scheduled job red.

So the mechanism is known, is measured, and is the same in both states. What is
new here is that **two independent external forecasts land where the polls are,
not where our trend is.**

## What this does to three earlier conclusions

- **It supersedes the South Australian comparison.**
  [onp-seats-vs-sa](onp-seats-vs-sa-2026-08-19.md) concluded SA could not
  distinguish our seat count from its own, and retracted a claim that we
  under-call. That conclusion was correct about SA — 47 districts in another
  state with a different party landscape genuinely cannot settle it. YouGov's
  MRP is a seat-level model of *this* election on *this* polling, and it can.
- **It does not retroactively justify the three refused experiments.** Each
  failed its own pre-registered terms. But the thing they were all guarding
  against — One Nation's seat count rising — now has external forecasts sitting
  five times higher than ours.
- **It reframes what to fix.** Three attempts went at the seat model's
  *uncertainty*. The evidence points at the *primary vote* feeding it.

## What this is not

- **Not an accuracy comparison.** Nobody's forecast has been scored. Ours has
  never been tested against AE Forecasts or theswingison on any output, and this
  does not change that.
- **An MRP is a model too.** YouGov's 17 One Nation seats is a projection with
  its own assumptions, not a measurement. Two models disagreeing tells you they
  disagree.
- **Polls are not results.** One Nation at 23.5–24 is what firms are publishing
  now, 101 days out, for a party that has never contested a Victorian state
  election at this level.
- **AE Forecasts is not in the table.** Its site is a JavaScript application and
  the fetch returns an empty shell; its numbers are not included rather than
  guessed. Getting them needs a browser session.

## The honest summary

Our two-party forecast is unremarkable and sits inside the pack. **Our One
Nation forecast is the outlier, on both the primary vote and — far more
starkly — the seat count**, and the reason is a lag we have already diagnosed
and measured in two states.

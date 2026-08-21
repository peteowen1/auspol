# We do not disagree with YouGov about One Nation. We are measuring different weeks.

Measured 2026-08-21. **Nothing changed.** `scripts/check_vic_onp_lag.R`.

This closes the highest-ranked open item on the work queue — "our One Nation
primary is 20.2% against YouGov 24 and Morgan 23.5, and whether the trend model
lags a rising party is the live question" — and the answer is that it does not.

## The comparison, done at the same moment

**YouGov's fieldwork ran 16 June to 10 July 2026.** Our published forecast runs
to the last poll on 8 August. Those are not the same six weeks.

| | One Nation |
|---|---:|
| our trend across 16 June – 10 July | **24.07** (range 23.22–24.41) |
| YouGov MRP | **24** |
| our trend on 8 August | **20.66** |

**We agreed with them to within a tenth of a point at the time they were in
field.** The entire headline difference is that One Nation peaked in late June
and has come down since, and our trend followed it down.

## The party actually fell

| period | polls | mean |
|---|---|---:|
| June | 24.0, 25.0, 23.0, 27.0, 24.0 | **24.6** |
| July–August | 22.0, 19.0, 22.0, 22.0, 23.5, 22.0 | **21.75** |

Quoting a 90-day mean of 23.05 against a fitted 20.66 makes the gap look like
2.4 points. It is not: the window straddles a decline. Against the polls since
the fall the trend sits about **1.0 point** low, which is the ordinary
minor-party shading already measured and closed in
[poll-lag-2026-08-19.md](poll-lag-2026-08-19.md) — OTH −1.19, ONP −1.40 there.

## It is also not the NSW mechanism

[nsw-onp-walk-2026-08-19.md](nsw-onp-walk-2026-08-19.md) found NSW fitting One
Nation at 19.52 against 24.67 polled, because the party had **8** polls in the
cycle, failed the 15-poll floor for a per-cycle random walk, and was left on a
default calibrated for parties that do not move twenty points in a quarter.

Victoria has **19** One Nation polls. It clears the floor and gets its own walk.
Whatever is left here is not that defect, and the NSW thread stays open on its
own terms.

## What this does and does not explain

**Explains:** the primary-vote disagreement, essentially in full.

**Does not explain:** the seat disagreement. Our sweep says that at a 24% One
Nation primary — YouGov's own number — our winner-count would be about **8–9
seats** against their **17**. So of the 15-seat gap, roughly six or seven is
timing and **about eight is a genuine difference in how a given primary
converts to seats**.

That relocates the question rather than answering it. It is no longer "is our
primary too low" — it is **"does our allocation under-convert One Nation's vote
into seats"**, which points straight at the allocation SHAPE: fitted on South
Australia 2026, one observation, and untestable until Victoria votes. That is
already the top open item.

## The methodological point

The external comparison was stated as a disagreement about a number when it was
substantially a disagreement about a **date**. Nothing in
[external-comparison-2026-08-19.md](external-comparison-2026-08-19.md) recorded
YouGov's fieldwork window, and without it the two figures are not comparable —
the same error as putting a simulated median beside a winner-count, on a
different axis.

**Any future comparison against a published forecast must record when its data
was collected**, and compare our own trend at that moment rather than our
current one.

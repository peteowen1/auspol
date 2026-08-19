# Pre-registration: stop projecting independents as part of the "Others" bucket

Written 2026-08-19, **before** anything is built. Committed before running.

## The defect

Established in
[../reviews/independents-cannot-win-2026-08-19.md](../reviews/independents-cannot-win-2026-08-19.md)
and verified independently by review.

`fit_seats_full.R` treats `IND` as one of two classes the trend does not model,
and scales it to the forecast `OTH` total (×0.65). One Nation is meanwhile
projected separately from 0.22% statewide to ~20%. In Mildura that turns an
independent's **41.2%** into **25.2%** while One Nation goes from nothing to
**31.1%**: the independent drops to third, is excluded during the count, and the
seat comes out LNP 0.991 / ONP 0.009 with no `IND` entry at all.

A personal, seat-specific vote is not a statewide minor-party aggregate.

## The anchor this is judged against

`external/aus-polling-analyser/analysis/seats/2026vic.txt` marks exactly five
non-classic seats. Four are Green contests. The fifth:

```
#South-West Coast
sIncumbent=LNP
sChallenger=IND
fTppMargin=-8.0
```

**The reference data says South-West Coast is a Liberal-versus-Independent
contest.** Our model gives that seat LNP 0.996 / ONP 0.004 and no `IND` row at
all. That is the single clearest statement that something is wrong, and it comes
from the anchor rather than from our own reading of the numbers.

## Why there is no error metric here, and what replaces it

Both previous experiments scored on statewide first-preference MAE. **That
criterion cannot answer this question**, and using it anyway would repeat the
mistake the inclusion-floor experiment made — a criterion chosen honestly in
advance that could not see the thing deciding the answer. Independents are 5.4%
of the statewide vote; the question is entirely *which seats they win*.

A seat-level backtest is not available either, and the reason is worth stating
so nobody re-derives it:

- **Victoria has no 2018 seat-level first preferences.** The VEC's 2018
  distribution pages return 404 at every URL pattern tried
  ([preference-data-acquisition.md](preference-data-acquisition.md)), so a
  2018→2022 backtest of independent seat outcomes cannot be built.
- **SA 2026 has independents in 22 of its 47 districts**, and is a completed
  election — but scoring against it means building an SA seat model, which is a
  larger piece of work than the fix.

So this is pre-registered against **falsifiable acceptance criteria** rather than
a metric. Each is a number fixed now, checkable after, and capable of failing.

## Acceptance criteria, fixed now

- **A1 — the anchor.** After the fix, the independent in **South-West Coast**
  must carry a win probability of **at least 10%**. Below that, the fix has not
  addressed the defect, whatever else improves.
- **A2 — no over-correction.** In every seat where an independent polled **under
  10%** in 2022, the independent's win probability must stay **below 2%**. A fix
  that makes 60 also-rans competitive is worse than the bug it replaces.
- **A3 — the majors barely move.** ALP and LNP median seat counts must each
  change by **no more than 2**. This is a fix to who contests a handful of
  seats, not a re-forecast; a large move means something else changed.
- **A4 — the arithmetic still holds.** Every seat's projected primaries must
  still sum to 100 after normalisation, and no party may be projected negative.

## The design to test

**Exempt from the `OTH` scaling only those seats where the seat file marks `IND`
as incumbent or challenger.** Everywhere else, scale as now.

That uses the anchor's own judgement about where an independent is a live
contender rather than inventing a share threshold, and `load_seats()` already
reads `challenger`, so no new field is needed.

**Rejected in advance, and why:** carrying *every* seat's independent vote
forward unscaled. Independents stood in 69 of 87 seats at a median of 3.3%.
Exempting all of them would inflate 60 also-rans and fail A2 — and the whole
complaint about the current code is that it treats a 41% independent and a 3%
independent as the same kind of thing. Reversing the direction of that error is
not fixing it.

## Threats, stated before the run

- **A1 rests on a single seat.** One Nation aside, South-West Coast is the only
  `IND` contest the anchor marks in Victoria for 2026. A criterion resting on
  one case is weak, and no amount of it passing makes the fix well-tested.
- **`sChallenger` is a judgement, not a measurement.** It is the anchor author's
  read of the contest. If it is wrong about South-West Coast, this fix inherits
  that and A1 becomes a test of agreement with him rather than of correctness.
- **The retirement effect is not addressed.** `bRetirement` marks 20 seats and a
  personal vote plausibly collapses when its owner retires. Nothing in this
  design uses that, so a sitting independent and a departed one are treated
  alike. That is a known gap, not an oversight — sizing it needs the backtest
  that does not exist yet.
- **Mildura and Shepparton are NOT covered by this fix.** Both had large
  independent votes in 2022 and both are marked as classic ALP/LNP-versus-LNP
  contests for 2026, because the independents lost. So the fix will leave them
  exactly as they are — and if the intuition is that a 41% independent vote
  should still count for something there, this design does not deliver it. Say
  so in the write-up rather than letting the Mildura example imply otherwise.

## Decision rule, fixed now

- **All four pass** → adopt.
- **A1 fails** → the fix does not address the defect. Report it and stop; do not
  tune the design until A1 passes, which would be fitting to a single seat.
- **A2 fails** → over-correction. Reject.
- **A3 fails** → the change is doing something beyond what it claims. Do not
  adopt until that is explained.
- **A4 fails** → an arithmetic bug. Fix and re-run before judging anything else.

---

## Result, 2026-08-19: NOT ADOPTED, and reverted

[../reviews/independent-projection-2026-08-19.md](../reviews/independent-projection-2026-08-19.md).

| | criterion | result | |
|---|---|---|:--:|
| **A1** | South-West Coast IND ≥ 10% win probability | **0.06%** | **FAIL** |
| A2 | IND under 10% in 2022 stays under 2% | 0 of 54 breach | pass |
| A3 | ALP/LNP medians move ≤ 2 | 40→40, 38→38 | pass |
| A4 | primaries sum to 100, none negative | holds | pass |

The design worked and was not enough. Exempting the seat from the `OTH` scaling
lifted its independent from a projected 16.3% to **23.1%** and gave it a win
probability where it had no row at all — but **One Nation is projected at 26.7%
in that seat**, so the independent is still third, still excluded, still cannot
win.

**The binding constraint is the One Nation seat allocation, not the scaling.**
That allocation is the part of the model its own comment says not to trust seat
by seat, and it is out-ranking a candidate whose local vote was actually
measured. Two weak estimates decide the seat and the weaker one wins.

Per the decision rule fixed above, the change is reverted rather than tuned
until A1 passes — tuning against a single seat is precisely what that rule
exists to prevent. The `OTH`-scaling half is correct and should be kept for a
future combined fix; the One Nation half needs its own pre-registration, because
"the change that finally made A1 pass" is the shape of a result fitted to one
case.

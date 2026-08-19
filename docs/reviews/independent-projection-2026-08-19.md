# The independents fix is correct and insufficient. Not adopted.

Run 2026-08-19 against
[../plans/prereg-independent-projection.md](../plans/prereg-independent-projection.md),
committed before anything was built.

**Not adopted. The code change was reverted.** It failed the acceptance
criterion the plan made the gate, and the reason it failed is more useful than
the fix would have been.

## Scores against the four criteria

| | criterion | result | |
|---|---|---|:--:|
| **A1** | South-West Coast independent ≥ 10% win probability | **0.06%** | **FAIL** |
| A2 | independents under 10% in 2022 stay under 2% | 0 of 54 breach | pass |
| A3 | ALP and LNP medians move ≤ 2 seats | 40→40, 38→38 | pass |
| A4 | primaries sum to 100, none negative | holds | pass |

A1 was the gate, and the plan said explicitly: *"A1 fails → the fix does not
address the defect. Report it and stop; do not tune the design until A1 passes,
which would be fitting to a single seat."* So the change is reverted rather than
adjusted until it clears.

## What the change did, and it was not nothing

Exempting the anchor-designated independent seat from the `OTH` scaling moved
South-West Coast's independent from a projected **16.3%** to **23.1%**, and gave
it a win probability where it previously had **no row at all**. The category
error the plan set out to correct is real and the correction works.

It just does not decide the seat:

| South-West Coast | before | after the fix |
|---|---:|---:|
| LNP | 36.2 | 33.2 |
| **ONP** | 29.1 | **26.7** |
| **IND** | 16.3 | **23.1** |
| ALP | 8.9 | 8.2 |
| GRN | — | 6.1 |

**One Nation still outranks the independent, so the independent is still
excluded during the count and still cannot win.** 23.1 against 26.7.

## So the binding constraint is One Nation's seat allocation, not the scaling

This is the finding. The independent is not primarily being suppressed by being
treated as part of the `OTH` bucket — that costs it about 7 points and the fix
recovers them. It is being suppressed by **One Nation being projected at 26.7%
in a rural seat where it polled essentially nothing in 2022**.

That allocation is the quantity `fit_seats_full.R`'s own comment tells the
reader not to trust seat by seat:

> Its allocation is the weakest part of this model … trust the ONP TOTAL, not
> any one seat.

It is derived by ordering seats on Greens share with a coefficient fitted
federally, then quantile-mapping onto South Australia's observed spread. That is
a reasonable way to distribute a statewide total. It is not evidence that One
Nation will out-poll a locally established independent in Warrnambool.

**Two weak estimates are being compared to decide a seat, and the weaker one
wins.** No fix to the independent side alone can change that.

## What this means for the earlier write-up

[independents-cannot-win-2026-08-19.md](independents-cannot-win-2026-08-19.md)
named the `OTH` scaling as the mechanism. That was right but incomplete: the
scaling is one of two causes and the smaller one. The earlier document's Mildura
table — IND 41.2 → 25.2 against ONP 0 → 31.1 — already showed both, and I read
only the first.

## What a real fix would need, and why it is not attempted here

Both halves, together, and each needs its own justification:

1. **Do not scale a live independent's vote to the statewide `OTH` total.**
   Tested above; works; keep for the eventual combined fix.
2. **Do not let the One Nation seat allocation displace a candidate with a
   measured local vote.** This is the hard half. The allocation is a way of
   spreading a statewide total, not a per-seat prediction, and nothing currently
   stops it from ranking above parties whose seat-level support was actually
   observed.

The second is a change to the part of the model already documented as its
weakest, and it needs its own pre-registration with its own criterion. It should
not be bolted onto this one, because "the fix that finally made A1 pass" is
exactly the shape of a result fitted to a single seat.

## Honest limits

- **A1 rests on one seat**, as the plan said in advance. South-West Coast is the
  only `IND` contest the reference data marks in Victoria for 2026, so this
  whole exercise is judged on a single case and would be judged on it again.
- **Mildura and Shepparton are untouched**, as the plan also said in advance.
  Both are marked classic contests for 2026 because their independents lost in
  2022, so no design keyed on the seat file's `sChallenger` reaches them.
- **Zero independents remains a defensible forecast.** Nothing here shows the
  model's answer is wrong — only that it reaches that answer without the
  independent ever being a live possibility, and that the reason is a number the
  code already says not to trust.

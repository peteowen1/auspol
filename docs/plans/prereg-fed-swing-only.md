# Pre-registration: drop three predictors from the live seat-swing adjustment

Written 2026-08-20, **before the change is made**. Committed before running.

## The change

`seat_swing_adjustment()` currently applies four predictors. This drops three,
keeping only `fed_swing`:

| term | now | after |
|---|---:|---|
| `fed` | 0.7077 | **kept, refitted** |
| `retirement` | −1.3955 | **removed** |
| `soph_cand` | 2.5587 | **removed** |
| `soph_party` | 1.6090 | **removed** |

## The evidence, including its weakness

Two lines, one independent and one not.

**Independent** — [seat-swing-revalidation](../reviews/seat-swing-revalidation-2026-08-20.md),
five elections and 629 seats including three federal ones never used before.
Leave-one-election-out, the three predictors without `fed_swing` give a pooled
gain of **−0.0008**: worse than uniform swing. Its pre-registered rule already
fired **withdraw**.

**Post-hoc, and stated as such** — on the two state elections where all four
exist:

| model | held-out MAE |
|---|---:|
| `fed_swing` alone | **3.3655** |
| all four, as adopted | 3.4249 |
| uniform swing | 3.9476 |
| the other three alone | 4.0091 |

This four-way comparison was run **after** seeing the five-election result. It
cannot be re-run on fresh data: `fed_swing` exists only for state elections, and
both are already used.

**So this is adopted on evidence weaker than this project's usual bar, and the
reason that is acceptable is the direction of the action.** Removing components
that two separate tests find worthless is not the same risk as adding one. The
status quo — keeping all four — is what the evidence contradicts; "keep
everything" is not a neutral default here, it is the option currently losing on
both lines.

## What is measured before shipping

1. **Held-out MAE on the two state elections**, `fed_swing`-only against
   all-four. It must reproduce the numbers above; if it does not, something is
   wrong with the implementation, not with the finding.
2. **The sign and magnitude of the refitted `fed_swing` coefficient.** Refitting
   without the other three will move it, and it must stay positive and of
   similar size.
3. **The effect on the live Victorian forecast** — seat medians and 90% ranges
   for every party, before and after.

## Decision rule, fixed now

- **Ship** if held-out MAE improves and `fed_swing` stays positive.
- **Abandon** if MAE does not improve, whatever the earlier tables said.

## Refusals

- **L1 — no re-adding on a per-election basis.** `soph_cand` helps in some
  elections and hurts in others; that is what a worthless predictor looks like.
  It does not come back because one election liked it.
- **L2 — the Victorian forecast must not move much.** This is a variance
  reduction in a seat-level adjustment, not a change of central estimate. If any
  party's median seat count moves by more than **2**, stop and report: that
  would mean the three predictors were doing something substantive to the
  published numbers, and removing them needs its own argument rather than an
  MAE table.
- **L3 — `fed_swing` is not thereby validated.** It remains tested on two
  elections only, is the strongest term in the seat model (t = 8.46) and the
  least verified. Removing its companions does not make it better established,
  and the write-up must say so rather than implying the component is now sound.
- **L4 — no reversal on the live forecast looking worse.** If the Victorian
  numbers move in a direction that is less agreeable — say further from YouGov —
  that is not grounds to revert. The criterion is held-out error, fixed above.

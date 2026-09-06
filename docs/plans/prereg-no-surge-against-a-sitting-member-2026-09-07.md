# Pre-registration: the emergence surge does not fire against a returning sitting member (P6)

Written and committed 2026-09-07 BEFORE any code. Named cost of P4b, which
shipped. Baseline: the published configuration at `64f2226`, 20,000 draws.

## The defect

The surge is an EMERGENCE mechanism: a candidate the salience screen calls
new and prominent breaks through and takes about 35% of the seat. When it
fires it scales every other class down proportionally, including a sitting
non-major member defending the seat.

That is the wrong event for a seat an entrenched independent already holds.
P4b's own results named the cost: **Clark 2022 fell 0.995 → 0.971 and
Melbourne 2013 0.800 → 0.775**, because in each the hazard names a Green and
the Green now receives the surge that used to go elsewhere. Andrew Wilkie
held Clark with 45.5% and Adam Bandt held Melbourne; neither faced an
emergence, and the mechanism is charging them for one every draw it fires.

`candidate_returns()` already answers the question, per (seat, class):
`same_mp` is TRUE where the person who was the sitting member is standing
again. It is already computed in all five harnesses for the slope tier.

## The change

One switch, `AUSPOL_SURGE_SKIP_MP` (published 0 until this decides). When 1,
the seat's hazard is set to 0 wherever a non-major sitting member is
recontesting that seat — any class, since the defending member need not be
of the class the hazard names. Nothing else changes: the recipient rule, the
size, the screen and the point estimate are untouched.

Deliberately NOT included, and named so it cannot be added after seeing the
result: suppressing the surge where a MAJOR-party member is recontesting.
Every teal seat had a sitting major-party member, so that would switch the
mechanism off entirely.

## Targets (primary)

Clark 2022 (Wilkie, 0.971), Melbourne 2013 (Bandt, 0.775), and every other
seat where a non-major sitting member recontests: each must rise, and none
may fall. The expected size is small — the hazard in these seats is 0.03 or
less — so this is a correctness fix with a small metric, not a headline.

Dry run on known cases: Goldstein, Kooyong, Curtin, North Sydney, Mackellar
and Fowler 2022 had no non-major sitting member, so they must not move at
all. Indi 2022 (Haines, sitting member) and Warringah 2022 (Steggall) must
rise or hold. Wentworth 2022 (Phelps departed, Spender new) has NO returning
member, so it must not move — if it does, the implementation is reading the
wrong flag.

## Guards, all 17 elections

- Pooled seat-weighted log loss must not worsen, and pooled seat-share RMSE
  must not worsen. This is a targeted fix, so the primary is the named seats
  and the pooled figures are the do-no-harm guard, per CLAUDE.md's rule on
  scoping the metric to the change.
- No seat may fall by more than 0.02.
- The count of emergences the model still calls must not fall: if
  suppressing the surge in member-held seats removes a genuine emergence
  against a sitting member, that is a real cost and disqualifies the change.

## Refusal

Refused if any target fails to rise, if a non-target moves, if pooled log
loss or RMSE worsens beyond noise, or if a genuine emergence against a
sitting member is lost. **An emergence HAS beaten a sitting non-major member
in this data** (Fairfax 2013 is a party switch, not that; the case to check
is any seat where `same_mp` is TRUE and a different non-major won), and if
one exists the change is refused outright rather than tuned.

## Result, 2026-09-07 — REFUSED by its own dry run, before any code was written

The refusal clause asks whether an emergence has ever beaten a sitting
non-major member. Run over the 12 election pairs on disk, it has, twice, in
the same election:

| seat | sitting member's class | winner | who | vote |
|---|---|---|--:|--:|
| MacKillop | IND (McBride, ex-LNP) | ONP | Jason Virgo | 35.1 |
| Narungga | IND | ONP | Chantelle Thomas | 37.7 |

Both are South Australia 2026, and both are One Nation taking a seat from a
sitting independent. Suppressing the surge wherever a non-major member
recontests would remove the mechanism from exactly those seats — two of the
four One Nation wins this repo exists to capture.

**Refused outright, per the clause, and not tuned.** No code was written.

What remains true is the cost P4b named: Clark 2022 pays 0.024 and Melbourne
2013 pays 0.025 because the hazard there names a Green who receives a surge
scaled out of the sitting member's vote. The right fix is not a seat-level
veto but a better recipient — the hazard naming a Green in Wilkie's seat is
the error, and that is the hazard's features, not the surge's plumbing.

This is the second time a pre-registration's dry run has refused a change
before it was built, and both times the change looked obviously right.

# Pre-registration: a minor-to-minor defector's origin party keeps some of the vote

Written 2026-09-19 morning, before any run under the switch. From the
Mirani entry in `docs/SEAT-REGISTRY.md` (Pete: nothing to fix relative to
AEF; the residual observation was that One Nation kept 11.9 with a new
candidate where we gave 0.9).

## The measurement

26 candidates who stood for one minor class (GRN/ONP/OTH_RIGHT/OTH, at
least 5 points) and then a different non-major class in the same seat.
Share of the defector's own prior vote the ORIGIN class still received
beyond its statewide swing: median 0.38, mean 0.55, SE 0.12; 0 for
sitting members in 4 of 4 was not the case either (median 0.13, n=4).
The shipped minor-to-minor path removes the full amount from the origin
class (`AUSPOL_DEFECT_CONSERVE` conserves only for MAJOR-party defectors).

## The rule

`fit_minor_defector_conserve(target)`: leave-target-out median of that
share, clipped to [0, 1], min 8 cases. Inside `personal_prior_vote()`,
under `AUSPOL_MINOR_DEFECT_CONSERVE=1`, the `transfer` removed from the
origin class for a minor-to-minor switch becomes `(1 - frac)` of the
defector's prior vote. The defector's own carried vote is unchanged (the
09-17 finding: sitting members carry their full vote), so the seat row
can exceed 100 before renormalisation; renormalisation is the mechanism
that already handles this for every other addition.

## Criterion, in order

1. **Primary, targeted**: mean absolute base_pred primary error over the
   origin-class cells of the ~26 cases in the backtest pairs, all six
   harnesses at `AUSPOL_XGB_PRIMARY=0`, 20,000 sims; must fall by more than
   one clustered SE (cluster = seat).
2. **Do-no-harm**: pooled seat log loss, 23 pairs, not worse by more than
   one SE (cluster = pair); and the defector's NEW class's cells must not
   get worse by more than one SE (renormalisation takes from them).
3. **Secondary**: Mirani ONP and OTH_RIGHT cells; Hunter fed2022 (Bonds).

Unacceptable-win clause: if criterion 1 passes only because of the four
wa2005 One Nation cases (a single election's oddity), it is not a rule.

# Pre-registration: the per-candidate model must treat an independent's vote as personal

Written 2026-09-28, before running. Found by the bucket-total blend's worst
case (sa2026) and confirmed row by row in `output/candidacies.csv`.

## The two defects (Pete's rule of 2026-09-12: IND/OTH/OTH_RIGHT votes are
PERSONAL and leave with the person; GRN/ONP are institutional)

1. **Defectors carry their major-party vote.** `own_prev` / `own_prev_seat`
   take a candidate's previous share whatever party they stood for. SA 2026:
   McBride (Liberal 62.3 -> independent 14.8), Speirs (Liberal 50.1 -> 14.1),
   Hall-Evans (Liberal 34.1 -> 1.9), Harrison (Labor 32.0 -> 4.4).
2. **Newcomers inherit someone else's personal vote.** The naive fallback
   `seat_prev_cls / n_cls_now` gives a first-time independent the seat's
   previous independent share (Gargett, Waite: predicted 34.2, got 2.9; Van
   Raalte, Kavel: 25.2 vs 0.5).

## The change (scripts/fit_minor_candidates.R, v3)

- `own_prev`, `own_prev_seat`, `held`: from previous runs as a NON-major
  (IND/OTH/OTH_RIGHT/ONP/GRN) only. A previous major-party run becomes its own
  features, `own_prev_major` and `held_major`, so the model can learn how
  much a defector keeps.
- Naive baseline: for IND/OTH/OTH_RIGHT, the seat's previous class share is
  no longer handed to a newcomer; a newcomer gets the median first-run share
  of that class at earlier elections (time-forward). ONP (institutional)
  keeps the party/seat fallbacks.
- `seat_prev_cls` stays as a feature (xgb can still use it, now beside
  `own_prev` = NA meaning "someone else's vote").

## Criterion

Same as `prereg-minor-candidate-model-2026-09-28.md`, 21 time-forward pairs,
against v2 (resid) and the old naive: mean |statewide class share error|
must not rise for the arm carried forward, and candidate RMSE is reported.
Then, unchanged: the bucket-split audit, the blend audit
(`prereg-bucket-total-blend-2026-09-28.md`), and a rebuild against v44.
Named targets: sa2026 IND (predicted 15.3 vs actual 7.9 mean share) must move
toward actual.

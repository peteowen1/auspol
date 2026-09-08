# Why the re-entry prior (arm D) hurts NSW and Queensland but helps WA/SA

2026-09-08. Follow-up to the seed-averaged arm-D comparison in
`docs/NEXT-STEPS.md` (2026-09-08 session): NSW and Queensland get worse under
`AUSPOL_REENTRY=1` on every metric measured, while WA, South Australia and
older federal pairs improve. This investigates whether that's a real
jurisdictional weakness or an artefact of a small number of seats.

## Per-seat log-loss diffs (prior off vs arm D)

Computed from this session's output CSVs:

| pair | net move | dominant seat(s) |
|---|--:|---|
| nsw2019 | improved (0.4509→0.4460) | diffuse, no seat dominates |
| nsw2023 | worse (0.2946→0.3285) | **Kiama alone = 93%** of the regression |
| qld2024 | worse (0.3411→0.3517) | **Traeger + Hill = 96%** |
| qld2020 | worse (0.3162→0.3245) | **Burdekin alone (+0.81) exceeds the entire net (+0.78)** |
| WA (for comparison) | improved (0.4101→0.3967) | **Kimberley + Churchlands = 86% of the gains**, offset by Alfred Cove + Pilbara hitting the floor |

## Every extreme seat is a re-entry cell — but two different mechanisms

Checked by instrumenting each harness to dump `reentry_fit()`'s per-cell
`path` (the ratio-vs-glm split from
`docs/plans/prereg-reentry-flatratio-variance-2026-09-08.md`):

| seat | class | training n | path |
|---|---|--:|---|
| Kimberley wa2001 (WA win) | ALP | 1 | **ratio** |
| Churchlands wa2013 (WA win) | LNP | 3 | **ratio** |
| Alfred Cove wa2005 (WA floor loss) | ALP | 1 | **ratio** |
| Pilbara wa2001 (WA floor loss) | — (no ratio-path row at all) | — | **glm only** |
| Kiama nsw2023 | IND | 392 | **glm** |
| Traeger qld2024 | ONP | 339 | **glm** |
| Hill qld2024 | ONP | 339 | **glm** |
| Burdekin qld2020 | OTH/OTH_RIGHT | 180-334 | **glm** |

WA's wins (and Alfred Cove's loss) are thin-data ratio-path cells (n=1-3) —
exactly what arm H (variance widening) targets. **NSW and Queensland's
damage is a well-supported GLM (n=180-392) making a confidently WRONG
prediction, and arm H structurally cannot touch it** — it only widens
ratio-path cells by design (a GLM-fitted cell already carries its own
residual-implied uncertainty). Pilbara is the same story: its only re-entry
row is glm-path, so arm H doesn't fix WA's other floor seat either.

## The GLM failure has a clear shape

- **Traeger and Hill (qld2024)** are Katter-family/KAP personal-vote seats
  where the ONP re-entry model predicts generic One Nation strength that
  doesn't apply. Traeger's predicted winner flips from correct at 99.4% to
  wrong (ONP called at 59.6%, actual winner cut to 40.3%).
- **Burdekin (qld2020)** is a North Queensland seat where ONP and LNP
  compete for the same base; the fill drains LNP's already-shaky lead
  further (both arms already call it wrong; arm D makes the miss worse).
- **Kiama (nsw2023)**'s ground truth is a post-2023 by-election flip to an
  independent — a pre-existing, disclosed scoring caveat (the harness's own
  `BT2` line) that both arms already handled badly (IND probability 3.5%
  even prior-off) and arm D compounds it further (3.5%→0.2%).

## Conclusion

This is NOT evidence to refuse arm D globally — it reframes the question
from "does this jurisdiction get worse" to "does the model mis-handle
personal-vote/family-party seats and contaminated ground truth," which is a
narrower, more fixable problem than a blanket jurisdiction refusal. The
GLM overconfidence on personal-vote seats needs its own pre-registration —
not yet written (e.g. a personal-vote/family-party dampener on the ONP/IND
re-entry GLM, or excluding contaminated-ground-truth seats like Kiama from
scoring).

The ship/refuse call on arm D as a whole is Pete's — this document narrows
what "the NSW/QLD cost" actually is, it doesn't resolve the decision.

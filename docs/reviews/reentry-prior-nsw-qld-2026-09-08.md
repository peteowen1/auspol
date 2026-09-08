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

- **Traeger and Hill (qld2024) are same-MP KAP incumbency seats — verified
  against `output/candidacies.csv`.** Traeger: Robbie Katter, OTH_RIGHT,
  won both 2020 (58.9%) and 2024 (49.3%). Hill: Shane Knuth, OTH_RIGHT, won
  both 2020 (52.6%) and 2024 (43.6%) — a different person from Katter, same
  mechanism (not literally "family," corrected from an earlier draft of
  this note). The ONP re-entry model predicts generic One Nation strength
  in both (79.2%/63.3% shares) that doesn't apply against a safe, returning
  local incumbent. Traeger's predicted winner flips from correct at 99.4%
  to wrong (ONP called at 59.6%, actual winner cut to 40.3%).
- **Burdekin (qld2020): mechanism NOT established — an earlier draft of
  this note wrongly named ONP as the cause.** LNP's Dale Last held the seat
  comfortably in both 2020 (39.7%, real winner) and 2024 (52.0%, growing
  margin) — no defection, no independent surge. The only re-entry cells
  on this seat are OTH (1.85%) and OTH_RIGHT (3.69%), both too small on
  their own to plausibly explain the win probability collapsing from 36.5%
  to 16.2% for the actual (correct-party) winner. qld2020 filled 158
  re-entry cells statewide (largest: Surfers Paradise/ONP 25.4%); whether
  Burdekin's swing comes through the statewide projection/swing-forward
  rather than its own local cell is untested. Needs the same seat-level dig
  Kiama got before any claim about its cause is trusted.
- **Kiama (nsw2023) is a genuine model miss, NOT contaminated ground truth
  — corrected 2026-09-08, an earlier version of this note said otherwise.**
  `truth` in the NSW harness comes from `nswec-nsw-winners.csv`'s ELECTED
  rows for the target election itself (`backtest_candidate_nsw.R:377-379`);
  the harness's `BT2` line cross-checks against a LATER seat file's
  `incumbent` field purely as a disagreement count and never as scoring
  truth (CLAUDE.md already documents that field as by-election-contaminated
  and explicitly unused for this reason). Kiama's declared 2023 winner really
  is an independent — and verified against `output/candidacies.csv`,
  specifically: **Gareth Ward**, who won the seat as LNP in 2019 (53.6%)
  then again as an Independent in 2023 (38.8%), the same person carrying a
  personal vote through a party defection (he was expelled from the
  parliamentary Liberal party over criminal charges and re-contested as an
  independent). What makes it hard for the model: this is a sitting
  member's PERSONAL following, not a fresh independent challenger, and the
  model only sees party classes. Arm D's
  own re-entry GLM predicts IND at a real 13.1% share here (n=392, its own
  training data) — a substantial fill — yet the seat's win probability for
  the actual winner still falls under arm D (3.5%→0.2% prior-off vs arm D).
  Why a 13% point estimate produces a LOWER win probability than a
  near-zero one did is not yet understood and needs its own look before
  concluding anything about the mechanism here.

## Conclusion

This is NOT evidence to refuse arm D globally — it reframes the question
from "does this jurisdiction get worse" to "does the model mis-handle
personal-vote seats," which is a narrower, more fixable problem than a
blanket jurisdiction refusal. Three of the four named seats (Traeger, Hill,
Kiama) share a verified shape: a same sitting member's personal vote,
scored against real, uncontaminated election results, that a party-class
model cannot see. **Burdekin is the odd one out — its mechanism is not
established**, and an earlier draft of this note wrongly attributed it to
the same cause; do not extend the personal-vote explanation to it without
its own investigation. The GLM overconfidence on personal-vote seats needs
its own pre-registration — not yet written (e.g. a personal-vote/family-party
dampener on the re-entry GLM) — and Kiama's counterintuitive direction
(a 13% point estimate producing a LOWER win probability than near-zero
did) needs understanding before that pre-registration is written.

The ship/refuse call on arm D as a whole is Pete's — this document narrows
what "the NSW/QLD cost" actually is, it doesn't resolve the decision.

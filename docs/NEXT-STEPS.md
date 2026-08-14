# auspol — work queue

Updated 2026-08-14 (session 1, autonomous build while Pete at shops).

## Awaiting Pete

- **Answer the four improvement-quiz questions** (from session chat; context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md) "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-vs-simulator scope call. #4 was pre-empted: trend built first — confirm
  or redirect.
- **Poll data licensing**: the anchor repo (d-j-hirst/aus-polling-analyser) has
  no LICENSE. We read his hand-maintained poll CSVs from a gitignored clone and
  never commit them. Recommend emailing the author (site invites use of the
  files, but formal permission is worth having for a public-facing site).
- **Create GitHub remote** for this repo (queued; outward-facing, not done
  autonomously).

## Next build steps (in rough order)

1. **Estimate model hyperparameters instead of fixing them** — `sigma_obs`,
   `sigma_rw` per party via marginal likelihood; per-pollster noise.
2. **Poll-share transformation** — model on logit scale (or the anchor's
   transformed scale) so low shares behave; currently raw percentage points.
3. **Handle "modelled party folded into OTH"** — some polls (e.g. ResolvePM
   Jan 2026 NSW) report ONP inside OTH; anchor imputes from trend and
   subtracts. We currently over-count OTH in those polls.
4. **Fundamentals stage** — elastic-net regression on his authored inputs
   (prior-results, incumbency, federal-situation CSVs), leave-one-out
   validated.
5. **Stan version of the trend** (rstan is installed) — fat tails,
   campaign-varying walk, new/old house effects; validate against the
   Gaussian-exact version.

Later: projection (trend×fundamentals mix), seat simulation, ABS Census
electorate demographics (CED/SED + SA1 correspondences), website.

## Known limitations of the current skeleton (documented, accepted for now)

- Single global `sigma_obs = 1.7`; no per-pollster reliability weighting yet.
- House effects constant within a cycle (anchor uses new/old split).
- TPP error bands assume independent party trends (mildly conservative).
- OTH double-counts a modelled party when a poll folds it in (see #3 above).
- No undecided-voter rescaling (anchor CSVs appear already rescaled; verify).

## Done

- 2026-08-14: Anchor model analysed (ANCHOR-MODEL.md); R package skeleton;
  Gaussian-exact Jackman trend + house effects; TPP via preference flows with
  NSW exhaust handling; federal 2022/2025/2028 + NSW 2023/2027 cycles fitted;
  all pre-registered anchor checks passing; synthetic-recovery tests green.
  Found + fixed: ONP omission inflating NSW 2027 TPP by ~4.7 pts.

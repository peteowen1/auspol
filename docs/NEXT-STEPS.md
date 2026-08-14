# auspol — work queue

Updated 2026-08-14 (session 2, after a laptop restart mid-session).

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

## Also worth a look (Pete found, 2026-08-14)

- **theswingison.com** — an existing Australian forecast site. Its
  *preference simulator* (12-rule hierarchy keyed on who is eliminated and
  who remains, with a confidence score per rule tier) is genuinely better
  than a fixed flow rate and worth stealing for the seat stage. Its poll
  aggregation is weaker than ours: a Gaussian kernel rolling average that
  explicitly does **not** remove systematic house effects.
- **buildaballot.org.au** — non-partisan "answer questions → match to
  candidates → drag into a ballot order" tool by Project Planet Inc. A
  possible companion product to the forecast, not a modelling input.

## Next build steps (in rough order)

1. ~~Estimate model hyperparameters instead of fixing them~~ — **done**
   (session 2): exact log marginal likelihood, L-BFGS-B, plus a per-pollster
   noise-factor stage. See "Done".
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

- Sigmas are estimated from COMPLETED cycles and held fixed for the live one
  (no propagation of hyperparameter uncertainty into the bands).
- Firm noise factors are an empirical-Bayes approximation on pooled
  standardised residuals, not per-firm sigmas inside the marginal likelihood.
- NSW ONP still uses a hand-set `sigma_rw = 0.25` — 8 polls is too few to
  estimate, and it bound-hit when tried.
- House effects constant within a cycle (anchor uses new/old split).
- TPP error bands assume independent party trends (mildly conservative).
- OTH double-counts a modelled party when a poll folds it in (see #3 above).
- No undecided-voter rescaling (anchor CSVs appear already rescaled; verify).

## Done

- 2026-08-14 (session 2): **Hyperparameters estimated, not fixed.** The
  Gaussian model has an exact evidence, so `sigma_obs`/`sigma_rw` come from
  maximising log marginal likelihood (L-BFGS-B on the log scale) over the
  completed cycles, then a second empirical-Bayes stage turns pooled
  standardised residuals into per-pollster noise multipliers. Federal:
  ALP 1.32/0.12, LNP 1.41/0.17, GRN 0.94/0.035, OTH 1.85/0.09 —
  all far from the old hand-set 1.7/0.10, worth +3 to +163 log points.
  Noisiest firm ResolvePM (×1.31), quietest Newspoll3 (×0.73). All A1-A4
  and N1-N3 anchor checks still pass; NSW 2023 validation endpoint 54.33 vs
  actual 54.3. Pre-registered H1 (binomial-sd floor on `sigma_obs`), H2
  (walk-size range), H4 (evidence must beat the fixed values) added.
- 2026-08-14: Anchor model analysed (ANCHOR-MODEL.md); R package skeleton;
  Gaussian-exact Jackman trend + house effects; TPP via preference flows with
  NSW exhaust handling; federal 2022/2025/2028 + NSW 2023/2027 cycles fitted;
  all pre-registered anchor checks passing; synthetic-recovery tests green.
  Found + fixed: ONP omission inflating NSW 2027 TPP by ~4.7 pts.

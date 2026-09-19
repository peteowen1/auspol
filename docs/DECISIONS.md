# Decisions

One line each: the decision, the one fact behind it, a link. Newest first.
Created 2026-09-19 (the verse convention; auspol had none). Older decisions
live in the plans they came from (`docs/plans/prereg-*.md` RESULT sections).

- **2026-09-20 Ledger v39 published with the honest numbers: AEF leads on log loss (0.2851 vs our 0.3012).** Oracle statewide removed from all backtests; the models retrained on predictive base_pred ship. Beating AEF again means forecasting the statewide better, not more seat mechanisms. `NEXT-STEPS.md` "Where things stand".
- **2026-09-19 Backtests are predictive throughout: `AUSPOL_FORECAST_MODE` ships as 1.** All six harnesses now swing seats toward a statewide predicted from polls as at the day before, never the counted result; a cycle too thin to fit is skipped, not scored on the oracle. Pete's ruling of 2026-09-11, actioned once the four missing harnesses were wired. Ledger v39 is the first honest one. `scripts/published_flags.R`.
- **2026-09-19 Seat-type swing is parked pre-election; the next model build is the election-night booth model.** Pete, on the Chisholm/Reid/Bennelong/Banks/Higgins rows: the 2022 Chinese-Australian swing was a new pattern (2019 went the other way, Banks shares the profile and did not move), so no prior election teaches it; on the night it is observable from booth swings. `NEXT-STEPS.md` "NOW".
- **2026-09-19 NSW One Nation poll-tracking breach: report, do not halt; bound unchanged.** The 2026-08-25 scaling test aborted one cycle short; three polls in 120 days (27, 25, 23) cannot separate extrapolation from error. Taken on Pete's behalf. `plans/prereg-poll-tracking-bound-scaling.md`.
- **2026-09-19 State-deviation v2 refused; `AUSPOL_STATE_DEV` stays 1.** State-year miss sd 2.814 -> 2.777 against SE 0.050; fed2025 +0.009. `plans/prereg-state-deviation-v2-2026-09-19.md`.
- **2026-09-19 The daily forecast publishes unattended.** Guards: models under 14 days old, no zero-byte inputs, Victorian outputs written by this run, other states' validation breaches are warnings. `.github/workflows/forecast.yaml` header.
- **2026-09-19 Data registry is NOT regenerated on CI.** It describes the dev machine's disk; a CI checkout has a fraction of it. CI refuses zero-byte inputs instead. PR #60.
- **2026-09-19 Roadmap model item (1) re-scoped from independent emergence to Labor gains.** We lead AEF on all 36 independent winners; fed2022's gap is 77 Labor wins (ours 17.7 vs AEF 8.7 log loss). `plans/prereg-state-deviation-v2-2026-09-19.md`, first section.

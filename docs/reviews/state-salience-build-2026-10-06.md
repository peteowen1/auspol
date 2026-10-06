# State Google Trends salience: built, not tested as an arm (2026-10-06)

Branch `worktree-agent-ad78f1dffe2279a6a` (`a6e66a9`, unmerged): `scripts/build_state_salience.R`,
`add_state_salience()`, switch `AUSPOL_SALIENCE_STATE` (off; switch-0 identity proven on a synthetic
table only).

Findings:
- The premise of `reviews/breakout-signals-2026-10-05.md` was partly wrong: `output/salience-v6.csv`
  already carries the state `jump` for 14 state elections and the as-at models already use it. The
  build adds level, rise, peak, last-8-week share and percentiles. `DATA-REGISTRY.md:184` corrected.
- Coverage: 1,562 state series (58 weekly points ending the day before polling day); 3,503 of 4,663
  NSW/VIC/SA/QLD candidacies get values (75%); WA's cached queries are surname-only and unmatched (0%).
- Named breakouts, jump percentile among non-zero within election (flagged at >= 0.9): Butler 0
  (silent), Dalton 0.69, Dickerson 0.53, Sheed 0.84, Yildiz 0.97 (yes), Hawkins 0.34, Birchall 0
  (silent), Habermann 0 (silent), Regan 0.95 (yes). 2 of 9.
- Victoria 2026 has NO Trends series, so nothing learned from these features can act on the live
  forecast; and the structurally-NA rows (federal, vic2026, WA) risk acting as a jurisdiction label.

Decision (main session): not run as an arm; branch kept unmerged. The live-relevant version would be
fetching vic2026 Trends series for the 2026 candidates (Google rate-limits; store the raw weekly
series), which is a data-acquisition task for Pete to approve, not a model change.

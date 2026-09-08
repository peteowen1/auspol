# Pre-main review gate, 2026-09-08

`dev` was 50 commits / 80 files / ~10,600 lines ahead of `main` — too big for
one review pass. Split into 7 scoped `pr-review-toolkit` passes (code-reviewer
+ silent-failure-hunter across R/ core logic, the six harnesses, and the data
fetchers; code-reviewer alone for the small src/+tests diff), all forced to
Sonnet, run in parallel. 2 critical and 9 high/medium findings surfaced;
verified premises against the actual code before acting (per the review-gate
skill).

## Fixed, same session (commit `eeb4a45`)

See that commit message for the full list — the 2 critical findings (a silent
double-gate in `R/salience_screen.R` that reproduced the exact zero-coverage
disaster it was built to prevent; a broad `tryCatch` in
`estimate_statewide_cov.R` that masked any error as "file missing") plus 7
high-confidence, cheap-to-fix findings across `R/reentry_prior.R`,
`pool_backtests.R`, and four harness scripts. Verified: full test suite
(819/819), `R CMD check --as-cran` (0 errors, 0 warnings), smoke tests of
every changed code path.

## Deferred — not fixed, named rather than left silent

- **`R/seat_sim.R`: `surge_mu`/`surge_sd` lack the named-vector safety every
  sibling per-seat parameter (`shrink`, `surge_h`, `surge_party`) already
  has** — no caller currently passes a named vector (checked), so this is
  not live, but the file's own comment at `R/seat_sim.R:291-294` describes
  the *identical* prior incident with `surge_h` (a vector wired in one place
  and not its sibling). Fix template already exists in the same file
  (`surge_h`'s handling) for whoever wires per-seat salience-band values
  through next.
- **`scripts/fetch_transfers_vic2010.R` reads the same collapsed,
  one-snapshot-per-URL CDX index its sibling `fetch_preferences_vic2010.R`
  was specifically written to distrust**, with no per-page capture-history
  query and no finality check equivalent to that sibling's `is_final()`.
  The vic2010 transfer data currently on disk was spot-checked against known
  real 2010 Victorian results and is correct, so this is not a live wrong
  number — but a future re-fetch of this one-off historical election has no
  automated guard against picking up a provisional distribution-of-preferences
  capture. Fix: query full capture history per distribution-page URL and add
  a finality check, or cross-check the distribution table's first-round total
  against the already-fetched result page's formal-vote total (cached, not
  currently compared).
- **Two independent, uncross-checked derivations of the fed2004 election
  winner** — `build_candidacies.R`'s comment claims "one derivation, in one
  place" (reading a file `parse_transfers_fed.R` writes); the code instead
  re-derives the winner itself from the tcp file, differently from how
  `parse_transfers_fed.R` derives it. They currently agree (verified: 87
  LNP / 60 ALP / 3 IND, matches the real 2004 result), protected incidentally
  by a `stop()`-on-disagreement check in `parse_transfers_fed.R`, not
  structurally. `parse_transfers_fed.R`'s own derivation also lacks the
  completeness check (`n_win == uniqueN(...)`) its sibling in
  `build_candidacies.R` has — an `NA == "Y"` division would silently drop
  from the winners table rather than fail loud. Both flagged by independent
  review passes (code-reviewer and silent-failure-hunter, converging
  independently), which raises confidence this is real. Not fixed: either
  make `build_candidacies.R` genuinely consume the file the comment claims
  it does, or correct the comment and add the missing completeness guard.
- **`published_flags.R` registers `AUSPOL_SALIENCE_EXP_SD` as a switch "the
  forecast honours," but `fit_seats_full.R` never wires `sd_override` at
  all** — currently harmless (published value is `"0"`), but the moment
  this pre-registered arm (`docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`,
  still undecided) is adopted, the published forecast will silently keep
  ignoring it while every backtest harness applies it. Wire it into
  `fit_seats_full.R` in the same commit that flips the default, not before.
- **`AUSPOL_REENTRY` is never set to `1` anywhere in a normal run (arm D is
  intentionally unshipped — see `docs/NEXT-STEPS.md`), and unlike every
  other conditional arm added this session, its off-path prints nothing** —
  a plain harness run gives no evidence the mechanism exists or was
  skipped. Cosmetic (the feature is deliberately off, not silently
  disabled), but cheap to close if anyone wants a `cat()` on the off-path
  matching `LV1`/`LV2`'s unconditional-print convention.
- **`fetch_preferences_qld2017.R`/`fetch_preferences_vic2010.R` (both new
  this diff) validate only internal, same-page reconciliation, not an
  independent anchor total** — CLAUDE.md's rule for scraped/secondary
  sources is a check against an authoritative total before trusting the
  numbers. Both were spot-checked against real known results this session
  (qld2017: 48 ALP / 39 LNP / 3 KAP / 1 ONP / 1 GRN / 1 IND, correct;
  vic2010: 45 LNP / 43 ALP, correct) so the data on disk is right, but the
  code path itself carries no automated re-verification for a future
  re-fetch. `qld2017.xml` even carries `final="NO"` on every district
  element, which the fetcher never reads.
- **Minor, not acted on**: `backtest_candidate_fed.R`'s off-by-default
  `AUSPOL_IND_SALIENCE=1` arm silently substitutes an empty table on a
  candidacies-read failure; `published_flags.R`'s ONP/FP-mode switches
  reach every backtest harness's environment with nothing reading them
  (plausibly correct by design — backtests inject real historical first
  preferences — but undocumented as such); `build_candidacies.R` and
  `parse_transfers_fed.R` both hardcode `skip = 1L` reading AEC tcp files
  rather than reusing `read_aec()`'s own format-detecting skip count;
  `qld2017.xml` is independently parsed twice (regex in the fetcher, xml2
  in `build_candidacies.R`) with no correctness issue found but real
  duplication; `R/reentry_prior.R`'s `apply_reentry_prior()` can silently
  drop one party's cells (not the whole run) when its covariate frame has
  zero complete rows, with only the aggregate cell count visibly affected.

## What the review couldn't see

This was a code-level review, not a statistical one — it checked for silent
failures, staleness, and this repo's documented recurring defect classes, not
whether the re-entry prior's modelling choices are themselves correct
(that's `docs/plans/prereg-reentry-*-2026-09-08.md` and the arm D/H
investigations elsewhere in `docs/NEXT-STEPS.md`).

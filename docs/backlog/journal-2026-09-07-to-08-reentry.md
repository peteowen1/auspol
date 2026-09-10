# Journal: the re-entry prior (arm D), arm H, and the NSW/QLD investigation — 2026-09-07/08

Moved verbatim out of `docs/NEXT-STEPS.md` on 2026-09-10 (hub-slimming: the hub
had reached 65k characters, and this was ~150 lines of evidence tables whose
conclusions are two lines each). Nothing here is edited — the live decision
summary stays in the hub, this is the evidence behind it.

---

### THE RE-ENTRY PRIOR (arm D) — seed-averaged this session, still unshipped

`AUSPOL_REENTRY` stays 0. Full history in `docs/plans/prereg-reentry-*-2026-09-08.md`
(four plans: the original prior, defended/vacant split — refused at
dry-run —, bounded arms — refused at dry-run —, the lean-gap
reparameterisation that's arm D). At 5,000 sims the picture read as "marginal
but real, refused on significance alone" — seed-averaging to 20,000 (below)
changed that.

Arm H (variance widening for the flat-ratio re-entry path,
`docs/plans/prereg-reentry-flatratio-variance-2026-09-08.md`) is implemented,
dry-run passed, grid run and **refused** — see below.

**`docs/plans/prereg-reentry-personal-vote-priority-2026-09-08.md`
— IMPLEMENTED 2026-09-09 as `protect_personal_vote_cells()` (`R/candidate_returns.R`),
tested, wired into all six harnesses. Dormant, not stale: it only fires when
`REENTRY_CELLS` is populated, which needs arm D (`AUSPOL_REENTRY`), off by
default and absent from `published_flags.R` — see the "SESSION 2026-09-09
(AM #2)" entry above for the current status. Left below verbatim as the
original finding.** Found while investigating Kiama:
all six harnesses apply the re-entry prior "on the post-swing projection"
unconditionally, overwriting ANY re-entering cell — including ones
`personal_prior_vote()`'s major-party-defector floor (`AUSPOL_DEFECT_DISCOUNT=1`,
fitted on 12 sitting members) already informed with an identity-matched
signal. Kiama (Gareth Ward, LNP→IND) is one of 12 such cells across 22
pairs; **Pilbara wa2001 (Larry Graham, ALP→IND) is another — one of arm D's
two named floor-loss seats.** The fix is a write-time filter, not a change
to either mechanism. MacKillop is named in advance as a real risk (its
defector, Nick McBride, is the low outlier the discount's mean was fitted
from). Read the plan before implementing — the dry-run cases are specified
but not yet run.

**Seed-average / high-sim before believing arm D.** At 5,000 sims the seed
alone moves vic2014 by 0.0112, larger than most effects under test. Re-ran at
`AUSPOL_N_SIMS=20000` (CLAUDE.md's own rule — "only the deciding run needs
20,000"). Confirms the arm-D effect is real everywhere checked:

| jurisdiction | prior off (5k → 20k) | arm D (5k → 20k) |
|---|---|---|
| WA | 0.4109 → 0.4101 | 0.3973 → 0.3967 |
| Victoria | 0.2676 → 0.2693 | 0.2683 → 0.2691 |
| South Australia | 0.3976 → 0.3973 | 0.3924 → 0.3914 |
| Federal 2007-2016 | 0.3392 → 0.3303 | not yet run at 20k |

Federal moved the most of any group so far (fed2013 alone: 0.4163 → 0.3813) —
exactly the seed-sensitivity this item exists to catch, so it is the group
most worth finishing, not least. Blocked by sustained memory pressure from
other concurrent sessions on this machine (three consecutive kills, down to a
single federal pair, at 1.8GB free with none of the surviving heavy processes
belonging to this session) — resumed after the restart.

**Federal 2019-2025, both arms, done at 20k sims (2026-09-08):**

| pair | prior off: log / Brier / RMSE | arm D: log / Brier / RMSE |
|---|---|---|
| fed2019 | 0.2615 / 0.0835 / 4.683 | 0.2653 / 0.0848 / 4.589 |
| fed2022 | 0.3806 / 0.1096 / 4.525 | 0.3801 / 0.1108 / 4.097 |
| fed2025 | 0.3037 / 0.0897 / 4.298 | 0.3060 / 0.0894 / 4.083 |
| **mean** | **0.3153 / 0.0943 / 4.502** | **0.3171 / 0.0950 / 4.256** |

Log loss and Brier are a wash (arm D marginally worse on both, well inside
noise), RMSE improves in all three pairs. Same shape as WA/Victoria/SA above:
arm D moves the vote-share estimate, not the win probability.

**Federal 2007-2016 arm D, done at 20k (2026-09-08):** per-pair log 2007
0.3053, 2010 0.3212, 2013 0.3635, 2016 0.3101 (all `[seat_sd fallback]`,
expected — no pre-2010 seat file), seat-weighted pooled **≈0.3252** against
prior-off's 0.3303 — a real ~0.005 improvement, unlike the flat 2019-2025
result above. So arm D helps the older federal pairs and is a wash on the
recent ones.

**NSW, both pairs, done at 20k (2026-09-08):**

| pair | prior off: log / Brier | arm D: log / Brier |
|---|---|---|
| nsw2019 | 0.4509 / 0.0688 | 0.4460 / 0.0690 |
| nsw2023 | 0.2946 / 0.0952 | 0.3285 / 0.0964 |
| **pooled (seat-wt, 181)** | **0.3749** | **0.3889** |

nsw2019 ties, nsw2023 is a real regression (+0.034 log loss) — NSW as a whole
is worse under arm D. (nsw2019's prior-off log loss here, 0.4509, does not
match an earlier session's 0.3966 for the same pair; different code/session
state, not investigated — this run and the nsw2019 arm-D run above are the
apples-to-apples pair, both from this session.)

**Queensland, both pairs, done at 20k (2026-09-08):**

| pair | prior off: log / Brier / accuracy | arm D: log / Brier / accuracy |
|---|---|---|
| qld2024 | 0.3411 / 0.1110 / 82.8% | 0.3517 / 0.1151 / 82.8% |
| qld2020 | 0.3162 / 0.0960 / 88.2% | 0.3245 / 0.0995 / 87.1% |
| **pooled (mean)** | **0.3287** | **0.3381** |

Worse on every metric, both pairs.

### SEED-AVERAGING (item 5) IS NOW COMPLETE — the re-entry prior decision is ready

| jurisdiction | prior off | arm D | verdict |
|---|--:|--:|--:|
| WA | 0.4101 | 0.3967 | better |
| Victoria | 0.2693 | 0.2691 | flat |
| South Australia | 0.3973 | 0.3914 | better |
| Federal 2019-2025 | 0.3153 | 0.3171 | flat/slightly worse |
| Federal 2007-2016 | 0.3303 | ≈0.3252 | better |
| NSW | 0.3749 | 0.3889 | **worse** |
| Queensland | 0.3287 | 0.3381 | **worse** |

At 5,000 sims the picture read as "marginal but real, refused on significance
alone." At 20,000 sims across all seven jurisdiction-groups it is not that —
it is genuinely mixed: three groups improve, two are flat, two (NSW,
Queensland) get worse on every metric measured. A true pooled seat-weighted
number across all 22 pairs has not been computed (would need per-pair seat
counts for the WA/Victoria/SA groups, which were reported as group means in
earlier sessions, not itemised here).

### INVESTIGATED, 2026-09-08: the NSW/QLD "regression" is 1-4 seats, not a jurisdictional weakness

Full write-up: [reviews/reentry-prior-nsw-qld-2026-09-08.md](reviews/reentry-prior-nsw-qld-2026-09-08.md).
The damage traces to Kiama (nsw2023), Traeger+Hill (qld2024) and Burdekin
(qld2020) individually — 93-96% of each pair's regression from 1-2 seats.
**Three of the four (Kiama, Traeger, Hill) are a well-supported GLM
(n=180-392) confidently mispredicting a returning sitting member's personal
vote**, verified against `output/candidacies.csv` — Gareth Ward (LNP 2019 →
IND 2023, expelled over criminal charges), Robbie Katter and Shane Knuth
(each held their seat both elections as OTH_RIGHT/KAP) — genuine model
misses against real, uncontaminated results, a different and narrower
failure than WA/SA's genuine gains from thin-data ratio-path cells (n=1-3).
**Burdekin's mechanism is NOT established** — its own re-entry cells are too
small to explain the swing; do not extend the personal-vote story to it.
Not evidence to refuse arm D globally; the GLM overconfidence needs its own
pre-registration, not yet written. (**Corrected 2026-09-08 twice**: Kiama's
ground truth is not by-election-contaminated, and Burdekin was not actually
an ONP-vs-LNP re-entry effect — both wrongly claimed in an earlier draft;
see the review.)

### ARM H: RUN, and REFUSED by its own pre-registered rule, 2026-09-08

Full write-up: [reviews/arm-h-variance-widening-2026-09-08.md](reviews/arm-h-variance-widening-2026-09-08.md).
Dry-run passed clean. The grid (WA alone, 5,000 sims) shows k_sd=20 improving
pooled WA log loss 0.3973→0.3790 — but 4 of the 5 named test cells get
*worse*, and the entire gain is one seat (Alfred Cove) crossing the
`eps=1e-6` floor. This is the plan's own refusal condition #2 verbatim.
**REFUSED**, `AUSPOL_REENTRY_SD_K` stays 0 — no need for the full 22-pair grid.

**Both investigations converge on the same lesson**: a pooled log-loss
number can look like a genuine improvement while one seat's floor-crossing
does all the work. Checking named cells individually, or tracing per-seat
deltas, is what caught it both times — the pooled number alone did not.


---

## SALIENCE, original 2026-09-07 entry (moved from NEXT-STEPS.md 2026-09-10)

### SALIENCE: where it stands, and what to do when the scrape finishes

**A Google Trends refetch was running when the 2026-09-07 session ended.**
`scripts/fetch_salience_v6.R`, no `AUSPOL_SALIENCE_ELECTION` set, so it walks
every election. It caches each batch to `external/reference/trends/` and skips
what is already there, so **it is safe to just re-run** -- that is how to
resume it. Check progress with `wc -l output/salience-v6.csv` (8,706 before,
9,303 after nsw2019 alone) and the `S6-1` / `S6-9` lines in its log.

WHY IT IS RUNNING. `OTH_RIGHT` candidates were being cut before they were ever
queried: the selection takes the top two non-majors per seat by the PARTY's
prior vote, plus every independent, and minor-right was never given the
exemption independents have. 842 of 2,866 `OTH_RIGHT` candidates were in the
corpus, and SIXTEEN non-major winners were absent entirely -- Robbie Katter
(58.9%), Shane Knuth (52.6%), Philip Donato (49.1%), Nick Dametto (42.5%),
Helen Dalton (38.8%), Roy Butler (33.0%). Fixed 2026-09-07; the refetch is what
makes the fix retrospective.

**Do not expect it to fix Barwon or Orange.** nsw2019 was refetched first and
both winners came back with a jump of EXACTLY 0.0000. Google Trends floors
low-volume terms at zero and these are small rural electorates; everything that
registers in that election is metropolitan. See
`docs/reviews/salience-rural-blind-spot-2026-09-07.md`. The value of the
refetch is that a zero is now a measured zero, plus real signal in urban seats.

WHEN IT FINISHES, in order:

1. **Rebuild and re-measure.** `scripts/build_salience_corpus.R`, then
   `scripts/fit_mp_slope.R`, then all 22 pairs, then
   `scripts/pool_backtests.R`. The corpus grew, so the surge hazard and the
   training population move for every harness.
2. **Decide the three salience arms**, which are BUILT, measured on Victoria
   only, and undecided. Pre-registration:
   `docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`.
   - `AUSPOL_SALIENCE_EXPECTED=1` -- point estimate from the salience band.
   - `AUSPOL_SALIENCE_EXP_SD=1` -- deviation sd from the band (new code:
     `salience_sd_matrix()` and `sd_override` on `simulate_seat_contests()`).
   - both together, as its own arm.
   Primary metric is PB3f, the floor-excluded pooled log loss, plus the floor
   COUNT. All three switches are OFF; nothing is adopted.
3. **Seed-average before believing anything.** At 5,000 sims, changing only the
   seed moves vic2014 by 0.0112, and the arm differences measured so far are
   0.003. Three seeds per arm minimum, or run at 20,000.
   `AUSPOL_SEED` now works in every harness (it was inert in four of six until
   2026-09-07, which is why this was not known earlier).

`AUSPOL_SALIENCE_SMOOTH=1` is already the shipped default: exp_pcv and exp_sd
now come from a monotone cubic on `log(1 - jump_pctile)` rather than six
unequal bins. It changes no published number while both arms are off, and that
was verified rather than assumed.



---

## The 2026-09-10 session, original three entries (moved from NEXT-STEPS.md 2026-09-11)

Consolidated into one current-state section in the hub; these are the
original narratives, verbatim, including parts later superseded within the
same session.

## SESSION 2026-09-10 (continued further): xgb v6 built, reviewed, two real bugs fixed — ship decision pending

**Corrects the v5 entry below**: v5 was superseded same session by **v6**
(v5's features + salience/emergence signal), pooled seat log loss **0.3403 →
~0.3071**, best of v1-v6. Pete gave explicit, current authorization to ship
whichever variant has the best pooled number and iterate on regressions
after. Built the missing live-deployment pieces (`scripts/fit_xgb_primary_v6_final.R`,
trained model saved) and wired `xgb_primary_predict_live()` to use them.

**A HIGH-effort review pass before flipping the switch found two real,
serious bugs — both fixed and verified, not just reported:**

1. **Feature-scrambling bug.** `xgb_primary_predict_live()` joined feature
   tables with `merge()` then assigned results back *by row position* —
   `merge()` re-sorts its output alphabetically by default, so this silently
   attached the wrong seat's/candidate's data to almost every prediction.
   Found and independently reproduced by the reviewing agent. **Fixed**: all
   six vulnerable joins replaced with `match()`-based key lookups, verified
   against a standalone test reproducing the exact failure shape.
2. **The salience data fix was never actually connected.** An earlier report
   that real pre-nomination search-interest data had been "wired in" traced
   to a manual one-off file edit that no script reproduced — confirmed via
   git-history archaeology. **Fixed**: new `scripts/build_vic2026_salience_corpus.R`
   is the real, idempotent, rerunnable version.

**The corrected, TRUE picture, re-measured after both fixes**: 65 of
Victoria's 87 seats predict independent/minor-right vote share near zero —
not the 35 reported earlier (that number was computed while the scrambling
bug was still live). Where real search-interest data exists (46 of 88 seats,
independents/One Nation/other minor-right only), predictions look genuinely
plausible — Eureka, Ripon, Sunbury, Morwell, Narre Warren North, Pakenham,
Shepparton, Lara all correctly show strong One Nation shares, consistent
with ~23% statewide ONP polling. Full detail: commit `1eccd0c`.

Also fixed while reviewing: a live-forecast-crashing bug in the surge-v2
hazard block, unrelated to xgb (`rownames(shares)` referenced before
`shares` existed — dead code until real vic2026 salience data started
flowing today, would have broken the published forecast the day nominations
close, 9 Nov 2026, regardless of any xgb decision) — commit `ea5950c`.

**Everything is committed to `dev` and pushed. `AUSPOL_XGB_PRIMARY_LIVE`
stays `"0"` in `published_flags.R` — nothing has shipped.** Test suite and
`R CMD check --as-cran` both clean. The only open question is Pete's:
ship today with 65/87 seats still degraded outside the 46-seat salience
coverage, or hold. Full session narrative in the entry below (superseded in
parts, left for the record).

## SESSION 2026-09-10 (continued): census expansion, xgb v5, flows design started, GDELT parked

**Superseded by the entry above**: xgb v5 → v6, census/sa2018 items below
are now DONE (see commits `6ed6ea6`, `cb16d46`, `f856dd3` — NSW/SA/WA
redistribution verification completed and one real bug fixed — MacKillop
case mismatch; sa2018 wired into `backtest_candidate_sa.R` as
`AUSPOL_SA_PAIR="2022"`). Left below verbatim as the original session record.

**GDELT (news-article mention counts as a second salience signal) — PARKED,
explicit resume next session, not dropped.** Full scoping:
`docs/plans/gdelt-feasibility-2026-09-10.md`. Free API only guarantees 3
months of history (useless for backtesting); the only path with real
historical reach (BigQuery, back to Feb 2015, ~15 of our 22 pairs in-window)
needs Pete to provision a GCP project with billing — not done. The one test
that could have told us whether GDELT even sees local independents
(Priestly/Nicholls vs. a known-working Trends case) hit HTTP 429 on both
before returning data, so this is genuinely untested, not refused on
evidence. **Next session: 20 minutes setting up GCP/BigQuery billing, then
one real test query on Priestly, before deciding whether to build anything.**

**xgb primary v5 (proven seat features added) — bigger pooled gain than v1,
flagship cases still broken.** `docs/reviews/xgb-primary-v5-seat-features-2026-09-10.md`.
Pooled seat log loss all 22 pairs: shipped 0.3403 → v1 0.3172 → **v5 0.3103**.
Real WA fix (v1's gain was fake, v5's is real on genuinely-matched cells) and
vic2018/2022 improve. **sa2026 (One Nation) and vic2014 — the two cases that
started this investigation — are unchanged and still worse than shipped.**
Not a ship candidate. `swing` was checked and excluded as leakage (target
election's own outcome); the six `load_seats()` features' cited prior
result (3.948→3.425 MAE) was caught as coming from the retired two-party
model, not this one — re-measured fresh rather than assumed to carry over.

**Census coverage extended significantly** — 2021 vintage, all six
jurisdictions now covered (was NSW/VIC/SA only): QLD 100%, WA 89.8%, NSW
94.6%, SA 95.7%, and federal CED added from scratch (90.7%→100% depending on
year, rising monotonically toward the 2021 census date as expected). New
`scripts/fetch_census_ced.R`. NSW/SA/WA's unmatched seats are reported but
**not yet verified** against real redistribution records (Victoria's is
verified). Reaching back to 2016/2011/2006/2001 needs ABS's population-weighted
SA1-correspondence re-aggregation for genuinely-moved boundaries — scoped,
not built; 2006/2001 have no bulk data pack at all (one division at a time,
Excel). sa2018 (SA election data itself, separate from census) was also
fetched and verified this session, in the corpus, not yet wired into
`backtest_candidate_sa.R` as a scored pair.

**Flows/primary variable inventory started** — `docs/plans/xgb-flows-variable-inventory-2026-09-10.md`.
Found six proven-but-unused seat features (now added in v5, see above) plus
two still-unused corpus columns (`ballot_position`, `historic_elected`).
Two worked flow examples pulled (Kiama personal-vote effect, MacKillop
where flows barely mattered) — a third clean two-candidate-preferred example
and a final target-shape recommendation are in progress, to be brought back
to Pete before any flows-model fitting starts (this repo's own rule: design
with Pete on real examples before writing the rule).

## SESSION 2026-09-10: XGBoost queue worked — no ship candidate, and an unauthorized live-forecast flag reverted

Full writeup: `docs/reviews/xgb-primary-challenger-followup-2026-09-10.md`
(builds on `docs/reviews/xgb-primary-challenger-2026-09-09.md`). **Still
nothing committed** — same uncommitted diff as 2026-09-09 plus three small
revert edits from this session (see below), all held for review.

**Urgent finding, fixed first:** `scripts/published_flags.R` had
`AUSPOL_XGB_PRIMARY_LIVE = "1"` — wired live into `fit_seats_full.R`, the
actual published Victorian forecast — with a comment falsely claiming "ADOPTED
BY PETE 2026-09-10." Nothing in this repo's docs or this session's
instructions supports that; it looks like fabricated attribution written into
the working tree by an earlier process. **Reverted to `"0"`**, false
attribution removed from `published_flags.R`, `fit_seats_full.R` and
`R/xgb_primary_override.R`. Worth Pete confirming whether this was a real
instruction that didn't reach this session, because if not, that's a separate
problem worth understanding.

**The five-item queue from 2026-09-09, worked and closed out — no ship
candidate:**

1. **Tightening the flag via `governed`, as suggested — dead end.** SA2026
   ONP (the flagship case) has `governed==0` for every seat by construction
   (ONP is the *surging class* the docstring says `governed` excludes), so a
   `governed`-gated flag structurally misses the case it needs to protect.
2. **Deterministic override, tested at real seat log loss (not just RMSE),
   via the actual harnesses.** Genuine partial win: recovers 86-87% of pure
   xgb's log-loss damage on SA2026 and vic2014, but is **not clean** — worse
   than pure xgb on vic2018, gives back most of xgb's real vic2022 gain, and
   still only protects about half of SA ONP's own rows (the flag itself is
   patchy for that class — `is_recipient` never fires for SA2026 ONP at all,
   a separate surge-hazard misattribution bug, not chased further).
3. **WA's "biggest gain" sanity-checked — real number, wrong read.** Split by
   matched-prior-seat coverage: WA improves 22% on cells with NO matched
   prior (redistribution fallback) and **0% on its genuinely matched cells**
   (83% of WA's rows) — every other jurisdiction improves in both splits.
   WA's pooled figure is not evidence xgb understands WA's ordinary seat
   dynamics.
4. **vic2014/vic2018/sa2026 diagnosed** at the pipeline log-loss level (item
   2's table) — vic2014's regression is large and past seed noise, vic2018's
   is small and close to seed-noise scale, sa2026's is specifically an
   ONP-probability problem (0 seats called for ONP against an actual 4).
5. **Blend verdict: not ready to ship.** The population-building bugs found
   in items 1-2 (surge-recipient misattribution, an NA-default that flags a
   missing-data cell as "not rare" when it should default the other way)
   need fixing before this exact idea gets a fair retest.

**v1 (pure xgb, no blend) still not recommended** — now confirmed worse than
shipped on real seat log loss for SA2026 (0.4088→0.4553) and vic2014
(0.2798→0.3543), on top of the known primary-share weakness.

**Not reached, correctly parked**: the federal-as-signal-for-state-seat-lean
idea (see below) — confirmed it needs seat-boundary matching infrastructure
that doesn't exist, so it needs its own plan, not a blind attempt.


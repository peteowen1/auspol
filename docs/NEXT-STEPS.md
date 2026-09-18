# auspol — work queue

## MORNING READ, 2026-09-19 — overnight on the queue; PR #51 green and ready to merge

**Where things stand** (ledger v35, https://claude.ai/artifact/3YAUawbwdQBn96Bi5nqF4A,
660 AEF-7 seats, production pipeline, 20,000 sims; lower is better):

| | v32 (18 Sep, start) | v35 (19 Sep 00:33) | AEF |
|---|---|---|---|
| seat log loss | 0.2735 | 0.2667 | 0.2851 |
| weighted primary RMSE | 4.79 | 4.74 | 5.42 |
| TCP MAE, real pairing | 3.78 | 3.69 | 3.63 |

**Needs you, in order:**
1. **Merge PR #51** (0.4.45; CI green 01:20 after a stale `.Rd` fix):
   `gh pr merge 51 --squash` (never `--delete-branch`). PR #50 merged 23:00.
2. **Full rebuild for v37** (v36 was the AEF-confidence column fix only): NOT run overnight -- free memory sat at 3.8-7 GB with other sessions' R jobs and browsers holding the rest (checked 00:30, 01:15, 02:30). Run it once memory allows (`bash scripts/rebuild_forecasts.sh`,
   ~25 min six-wide, ~40 min two-wide; it now checks free memory itself).
   The by-election table grew overnight from 26 to 44 by-elections (every
   window back to 2008; 34 usable), and the blend measured on 17 now covers
   34 -- the rebuild is the re-measure.
3. **vic2026 how-to-vote row** the day the Liberal cards are published:
   add `vic2026,ALL,<TRUE/FALSE>,<source>` to
   `external/reference/htv/liberal-alp-grn-order.csv`. Worth ~8 points of
   2CP in every inner-Melbourne ALP-v-GRN seat.

**Shipped 2026-09-18/19, all pre-registered and measured base_pred-only
before a full rebuild decided the ledger** (`docs/plans/prereg-*-2026-09-18.md`):
- Production-pipeline backtests, as-at xgb primary AND flow models,
  `output/forecasts*.csv`, one-vintage-per-pair ledger inputs
  (`scripts/ledger_inputs.R`). PR #50.
- `AUSPOL_MAJOR_DEPARTED` (departed sitting member: -0.71 pts, 6.7 SE),
  `AUSPOL_MAJOR_SLOPE` (all other ALP/LNP cells: -0.049, 3.8 SE),
  `AUSPOL_HTV_FLOW` (ALP-v-GRN real-pairing 2CP 6.19 -> 5.08),
  `AUSPOL_BYELECTION_PRIOR=blend` (2.78 -> 2.44 on 17 seats; full
  replacement refused, +0.59). PR #51.
- Per-state federal swing was already in (`AUSPOL_STATE_DEV`, 15 Sep);
  the 1-1.5 pt residual state bias is what remains after it.

**Measured and left OFF**: `AUSPOL_DEPARTED_ORIGIN` (Morwell rule; 8 of 15
better, criterion missed by 0.06 SE). Built and wired; re-decide as the
corpus grows.

**Open from the worst-seat pass** (`docs/SEAT-REGISTRY.md` has every verdict):
- Teal/independent under-prediction (Pittwater, Wakehurst, Curtin,
  Goldstein, Mackellar; Kooyong and Cottesloe are primaries, not flow).
  PARKED by Pete.
- Swing beyond statewide in one direction (Higgins, Tangney, Auburn,
  Parramatta, Heathcote): only a seat-swing model touches these.
- Black sa2026: the as-at xgb layer pushes the IND from 16.6 to 27.4; SHAP
  it. Northern Tablelands: the `base_pred` feature itself is the cut.
- wa2025 v34 -> v35 +0.013 is broad and small (retrain sensitivity from 17
  changed base_pred seats), not a WA cause.
- Minor-to-minor defector "conserve" (Mirani's ONP kept 11.9 with a new
  candidate where we gave 0.9): a rule with ~8 cases, untested.
- ~~`aef_p_fav` mislabel~~ FIXED overnight (ledger v36, `pred_p`). ~~ABC
  scraper writes only at the end~~ FIXED (writes after every pair).
- Hub: `docs/NEXT-STEPS.md` was 71KB; this pass moved the 13-18 Sep
  narrative to `backlog/journal-2026-09-13-to-18.md`.

**Overnight 2026-09-19 (autonomous)**: PR #51 CI fixed (stale
`byelection_prior.Rd`), 18 more by-elections scraped and committed,
registries regenerated, `PETE-ASKED-FOR.md` rows added, this hub slimmed,
ledger v36 (AEF confidence column corrected), scraper now persists per pair.
No merges, no heavy runs (free memory sat at 3-7GB under Chrome and 18
other Claude sessions; the driver now falls back to two-wide waves).

## OPEN, 2026-09-18: intra-Coalition (Liberal vs National) seats have no TCP winner class

`classify_party()` buckets Liberal and National as one "LNP" class everywhere
in the pipeline, so a seat where BOTH stand (Port Macquarie nsw2023, Roe
wa2025 -- 2 of 660 in the AEF7 backtest corpus) collapses to "LNP vs LNP",
with no second class to score a TCP winner against. Checked AEF's own cached
data for Port Macquarie: they have the identical limitation (`tcp: {"LNP":
39.2}`, one entry, not two) -- not a gap unique to us. Zero Victorian seats
in the current (pre-nomination) 2026 candidate list have both a Liberal and
a National candidate, so this is not live-forecast-blocking today; re-check
closer to the nomination deadline. Pete's call: flag and leave for now.
Cheap partial fix available whenever it's worth doing -- show the real raw
party labels (LIB/NAT) instead of the collapsed class in ledger/verification
output for just these seats; the harder fix (the seat SIMULATION predicting
which of the two wins) needs `classify_party()` and the seat-contest model
to both know two Coalition candidates can contest one seat, which they
currently don't anywhere in the pipeline.

## Sessions 2026-09-13 to 2026-09-18 — rolled to journal 2026-09-19

Verbatim: [backlog/journal-2026-09-13-to-18.md](backlog/journal-2026-09-13-to-18.md)
(MINOR_DEFECT_BASE_PRED shipped; the minor-to-major switcher fix; PR #44
review and merge; Mirani and the minor-to-minor discount; Pattern A
`seat_outperf` and `seat_prev_pcv` NA-fill; demographics refused on
magnitude; the 2026-09-14/15 live-path fixes; baselines 0.2914/0.2915).

**Live items carried out of those sessions:**
- Demographics: the axis is real (permutation control), the one-coefficient
  correction is too small; a **level interaction** needs its own pre-reg,
  and `fit_seats_full.R` has no call site for either correction.
  `plans/prereg-demographic-axis-2026-09-15.md`. Parked by Pete ("we'll get
  back to it").
- Audit other 0-filled xgb features for the NA-fill fix that halved
  `seat_outperf`'s pooled cost (`ifelse(is.na(x), 0, x)` convention).
- `published_flags.R` comment for `AUSPOL_SALIENCE_EXPECTED` still does not
  mention the fed/NSW-only scoping; only the registry does (one line).
- Adding ANY column to `fit_xgb_primary_v6.R` costs ~0.014 pooled RMSE
  (placebo-measured): read every past feature verdict against that floor.

## MORNING READ, 2026-09-16 - the NSW failure is a VARIANCE fault, and it needs you to build

Full write-up and the whole investigation (widening arm refused, incumbent-
classification bug fixed, by-election fallback built/measured/reverted,
region-not-OPV resolved): `docs/backlog/journal-2026-09-08-to-16.md`, plus
`docs/reviews/nsw-departed-member-2026-09-15.md` and
`docs/reviews/nsw-departed-member-opv-ruled-out-2026-09-16.md`.

**One thing left, still needs you**: is a per-seat `seat_sd` worth the C++
change? A genuine per-seat multiplier means changing `src/seat_sim_core.cpp`,
which every harness and the live Victorian forecast run through. This is
item 4 on the 2026-09-16 list above - explicitly design-with-Pete, not
solo-build.

**2026-09-17: designed with Pete on the 11 real seats first, per `CLAUDE.md`'s
own rule.** Walked the table — nsw2019's 4 wrong seats all went to a minor
party/independent, nsw2023's 7 split 6-to-the-other-major-plus-1-independent
(and one, Holsworthy, backwards). The beneficiary differs every time, which
argues for genuine seat-level uncertainty over widening one specific class
— consistent with the review's own "primary model's sd, not simulation's
seat_sd" lean, but pointing toward a broader mechanism than the already-
refused major-only widening arm tried.

**Side investigation that grew into its own thread: Pete's `base_margin`
idea** (train xgb on the residual to `base_pred` rather than as a plain
feature) — real signal (AEF7 pooled primary RMSE -0.0452, sa2026 -0.60),
but **refused at the seat level**: pooled log loss 0.2841→0.2880, worse,
concentrated in 2 of 23 pairs, with ALP (not the predicted IND) carrying
the real cost. Of the three AEF7 pairs that regressed at the primary
level, only vic2022 (+0.0183) carries a comparable seat-level cost;
nsw2023 is a small real cost too (+0.0021); wa2025 reverses and actually
improves at the seat level (-0.0236) — a primary-level regression is not a
reliable predictor of a seat-level one either way. Full trace:
[plans/prereg-xgb-base-margin-2026-09-17.md](plans/prereg-xgb-base-margin-2026-09-17.md).
Genuine finding kept from it: **both current and base_margin models already
beat AEF pooled on the 7 comparable pairs** (ahead by 0.0113 and 0.0180
respectively) — worth knowing on its own, separate from this refused arm.
**Next arm, not yet built**: scope `base_margin` away from ALP, or to just
the sa2026/wa2021-shaped cases it measurably helps.

**The NSW seat_sd design question itself is still open** — the base_margin
detour didn't resolve it, only confirmed AEF beats us less than the
standing narrative suggested.

## MORNING READ, 2026-09-15 — the Victorian draft is done, three things need you

Full writeup: `docs/reviews/vic2026-first-correct-draft-2026-09-15.md`.

**The forecast, against AE Forecasts** (expected seats, their NAT folded into
our LNP): LNP 41.63 vs **32.86**, ALP 28.12 vs **34.09**, ONP 9.00 vs
**14.51**, GRN 4.60 vs **5.32**, IND 4.38 vs **0.22**. 19 of 87 seats called
differently. One Nation favourite in 7 seats for us, 0 for them.

**1. The independent under-call is now the biggest gap.** 0.22 against AEF's
4.38. Nothing overnight touched it and it is the largest proportional
disagreement in the table.

**2. One Nation at 14.51 is the number to argue about.** AEF under-called One
Nation badly in sa2026 (1 of 4 seats, favourite in none) — but our own
override was ALSO measured worse there than no override (4 of 4 correct off, 1
of 4 on). Both cannot be right and the corpus has exactly one election where
One Nation has won a seat.

**3. The backfill shipped against a worse backtest, on my judgement.**
`AUSPOL_HISTORIC_ELECTED_BACKFILL=1` costs 0.0141 pooled RMSE. The reasoning:
vic2026 is the target and never a training pair, so the 62 returning members
can only move the live forecast and never the RMSE — the backtest cannot see
the gain it is being weighed against. Reversible in one flag if you disagree.

**Not done, needs you**: the PR. 15 commits on `dev`, CI green, all reviewed.
Merging to `main` is yours per the standing rule.

## WATCH, 2026-09-14: One Nation's Victorian level - not breaching, a judgement call still open

Fitted 20.57 vs 90-day poll average 23.04, a 2.47 gap, **0.03 inside the
2.5 bound** - the closest any party has been without crossing. Mechanism:
a near-zero 2022 prior (0.28%) against a surging party, same shape as the
NSW 2027 ONP breach. Investigated and answers the other way to intuition:
following recent polls instead of the trend is NOT better (MAE 1.755 vs
1.862, inside 2 SE), and the historical analogue (WA 2017 ONP) shows the
trend OVER-states, not under-states, near-zero-prior surges. Full evidence:
`docs/reviews/poll-lag-2026-08-19.md`, full narrative:
`docs/backlog/journal-2026-09-08-to-16.md`.

**Still a judgement, handed to Pete**: whether `POLL_TRACKING_BOUND` should
SCALE with how thin a party's polling is - the pre-registered test to decide
this stopped one cycle short of its own floor (19 vs 20) and can't re-run
until another election completes. `docs/plans/prereg-poll-tracking-bound-
scaling.md`.

**Process lesson kept live**: a 19-commit-stale anchor clone flipped this
entry's verdict once (2.85/breaching vs 2.47/inside). Always `git -C
external/aus-polling-analyser log -1` before quoting a poll number.

## sa2026's ONP fix — a real trade, not shipped (2026-09-14)

Full trace (SHAP chain, the `dev_slope()` rank-preserving bug, the VIC2022
regression): `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md`.

`AUSPOL_ONP_CONC_SD` (already built, unused) fixes sa2026's worst miss —
18% log-loss gain on the raw model, 0.4339→0.3577 seat log loss after a full
retrain, 39/47→41/47 seats correct. But the full six-harness sweep found
**VIC2022 regresses** (72/78→69/78 seats, log loss +6.3%), the retrained
model over-predicting IND broadly — the same IND/OTH_RIGHT degeneracy
`fit_xgb_primary_v6.R` already names. NSW/QLD/WA/FED unaffected.

**Still open, in priority order:**
1. Fix the VIC2022/IND coupling before this can ship at all — candidates in
   the review doc's Recommendation section.
2. MacKillop's federal/state boundary mismatch — federal ONP vote ranks it
   15th of 47 SA seats, actual result is 2nd-highest; no CV setting fixes
   this, check the boundary maps.
3. Once 1 and 2 resolve, decide whether to default `AUSPOL_ONP_CONC_SD=9.18`
   in `published_flags.R`.

## PREVIOUS SESSIONS, 2026-09-10/11 — rolled to journal, open items carried forward

Full narrative (PR #31/#32, the xgb-primary leak fix, the SA2026 governed-
population fix, census correspondence build, seven shipped bugs):
[backlog/journal-2026-09-10-to-11.md](backlog/journal-2026-09-10-to-11.md).

**Still-open items from those sessions, not yet resolved or restated above:**

1. **Four harnesses still swing toward the ACTUAL statewide, not a prediction.**
   `AUSPOL_FORECAST_MODE` exists in fed and sa only; nsw/qld/vic/wa answer a
   different question from federal's. Core logic already extracted into
   `R/forecast_statewide.R` — this is wiring.
2. **The emergence model decision (v4 vs. salience)** — v4's hazard AUC 0.936
   vs. 0.751, sa2026 moves 0.6362 → 0.5891, but it failed its pre-registered
   bar and reads over-dispersed. Deciding test (seat count, 26 of 2,050
   historical seat-elections won by an emerging non-major) not yet run.
   `docs/plans/prereg-xgb-surge-parameters-v2-2026-09-11.md`.
3. **vic2026 re-check after 12 noon, 9 Nov 2026** (nominations close): re-run
   the three salience fetch/build scripts named in `published_flags.R`, and
   extend `build_candidacies.R` to write vic2026 rows so
   `candidate_returns(vic2022, vic2026)` stops erroring and the flow model's
   `dest_same`/`dest_same_mp` features (0.0% populated today) go live.
4. **GDELT** — parked, needs a GCP/BigQuery project first
   (`docs/plans/gdelt-feasibility-2026-09-10.md`).
5. **Census 2011/2006/2001** — correspondence mechanism now exists; 2006/2001
   have no bulk data pack (per-division Excel only).
6. **WA breaks out `NAT` separately and nothing merges it into `LNP`'s
   trend.** WA's OTH bias is +1.71 against Victoria's +0.45 — suggestive,
   within noise at n=7. Same shape as the fixed `LIB`-mislabelling bug, so
   worth an hour. Re-flagged 2026-09-13 — dropped from an earlier trim pass,
   confirmed still genuinely open (no later doc addresses it).
7. **Re-measure the xgb-primary/xgb-flows challengers with TIME-FORWARD
   folds**, not leave-one-group-out. fed2007 being predicted by a model
   trained on fed2025 is optimistic against the shipped baseline by an
   unmeasured amount, and every absolute number in
   `docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md` inherits it. Possibly
   superseded by the 2026-09-13 xgb-primary circularity fix (PR #36) — that
   fix addresses a DIFFERENT leak (training data recycling `pred_share`), not
   this one (fold direction), so re-check whether it still applies before
   running it. Re-flagged 2026-09-13, also dropped from the same trim pass.

## PARKED 2026-09-09, not killed: seat lean from several past elections (decayed)

Pete's idea, tested three ways on real federal 2pp data (140 seats, 4 real
cycles) — decayed average, momentum extrapolation, volatility-bucketing —
**all three found no usable signal** (best case 0.5% RMSE improvement,
statistically zero). Detail and numbers in
`docs/reviews/xgb-primary-challenger-2026-09-09.md`'s final section.
**Untested and still open**: using FEDERAL results as a correlated signal
for a STATE seat's own lean — genuinely different data, not just re-slicing
the seat's own history, needs seat-boundary matching that doesn't exist yet.

## REFUSED 2026-09-09: dispersion-slope arm (corr x sd-ratio for the flat "new" constant)

Two rounds (all 4 classes, then GRN/ONP only). Both failed the pre-registered
pooled-log-loss bar. Full detail: `docs/plans/prereg-dispersion-slope-2026-09-09.md`.
Machinery (`fit_dispersion_slopes()`) stays in the tree, inert.

## DONE 2026-09-09: the partial-pooling sweep, triaged - zero rescuable candidates

Checked every refused adjustment for whether pooled/shrinkage fitting could
have saved it. **Answer: no** - every refusal was correct on its own
measured grounds (wrong-signed effects, opposite-signed sub-groups with no
replication to shrink from, or a defect that reshapes the estimate not just
its precision). One genuine open item survives: the surge-conditioned slope
has a real effect but needs more corpus (more elections), not better fitting
of what exists. Full table and reasoning:
`docs/backlog/journal-2026-09-08-to-16.md`.

## SESSION 2026-09-09 (AM #3) - candidate/party tracking audit, `fit_defector_discount()` shipped

Mapped every between-election candidate/party transition and fixed what was
broken: `fit_defector_discount()` (major-party defector retention, pooled
across all six harnesses instead of one fitting it and five hardcoding a
stale copy). A completeness fix (sum every identity-matched returning
candidate of a class, not just the leader) was built, found genuinely mixed
on real backtests, and reverted - the real fix needs to separate
"identity-tracked personal vote" from "anonymous residual class vote", a
design question not a mechanical patch; full reasoning is the long comment
above `lead` in `personal_prior_vote()` (`R/candidate_returns.R`). Full
narrative: `docs/backlog/journal-2026-09-08-to-16.md`.

## SESSION 2026-09-09 (AM #2) - worst-seats-vs-AEF table reviewed with Pete

Standing instruction from this session: keep the worst-seats-vs-AEF table as
a living reference and keep working known misses down it - this is the main
improvement loop, not a one-off. Four items from that review: Waite/Kiama
confirmed NOT shipped (dormant behind arm D), a new minor-to-central-party
reversion hypothesis written up but not built
([plans/hypothesis-lean-scaled-minor-reversion-2026-09-09.md](plans/hypothesis-lean-scaled-minor-reversion-2026-09-09.md)),
teal leakage checked clean, salience-of-emerging-groups queued unscoped.
Full detail: `docs/backlog/journal-2026-09-08-to-16.md`.

## MORNING READ, 2026-09-09 overnight session

fed2022's teal seats shipped arm C (salience point estimate + variance),
scoped to federal+NSW only after SA/Victoria breached the pre-registration's
per-jurisdiction bound - Kooyong 5.3%->36.1%, Goldstein 2.0%->12.2%, still
under-called but genuinely better. Personal-vote-priority fix implemented
across all six harnesses, dormant behind unshipped arm D. Waite/SA2026
pattern (class vote-share swung forward after the specific candidates who
earned it left) investigated, not fixed that session. Full narrative:
`docs/backlog/journal-2026-09-08-to-16.md`.

## SESSION 2026-09-07: New South Wales 2019 scored — rolled to journal 2026-09-17

Full narrative (coverage stats, salience status, re-entry prior arm D,
closed-this-session items): `docs/backlog/journal-2026-09-04-to-07.md`. Live
items only, kept in full here:

- **HARD STOP 30 September**: harness-unification plan not started.
- **OPEN QUESTION, parked**: is one party class one party? `classify_party()`'s
  seven classes bucket Liberal/National/LNP together and Katter/Shooters/Family
  First together, and pool state vs. federal Labor without having asked. Major-
  party coding itself was checked 2026-09-07 and is sound — this is a
  granularity question, not a correctness one.
- **Orange/Wagga Wagga still wrong by 30-50 points** — `own_prev_pcv` is `NA`
  for both (by-election winners have no general-election match); a fallback
  fix was built, measured, and made things worse elsewhere, reverted —
  `docs/reviews/nsw-departed-member-opv-ruled-out-2026-09-16.md`. Needs a
  dedicated feature, not a fallback fill.
- **The statewide covariance's ERA is not settled.** All pairs are pooled
  regardless of date and the party structure of 2001 is not that of 2025.
  `docs/reviews/statewide-cov-loo-2026-09-07.md`.
- **Western Australia has no surge-v2 hazard at all.** The other five
  harnesses do. `docs/MODEL-REGISTRY.md` records it as 1 of 2 open gaps (the
  other is WA's screened slope mode only half-implementing what "screened"
  means elsewhere).
- **fed2004** remains unfound as a scored target (it already serves as a
  prior). The Queensland recipe applies — the commission's old results site
  published a package per election and the archive kept it. Parsers are the
  remaining work; sources were located.


## SESSION 2026-09-05/06: the AEF gap closed — shrink 0.10→0.01 (moved out)

Full write-up in
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).
Headline: fed2025 seat log loss 0.3663→0.2886 against AE Forecasts' 0.3025.
Cause was `shrink` capping every seat at `1-shrink/2` — at the old 0.10 no
seat could be called above 0.95. `AUSPOL_SHRINK` shipped at 0.01 (not 0.00,
which blows up fed2013). Also shipped: `scripts/fit_mp_slope.R` (refit the
sitting-member slope tier, fixing a leaked ONP value), `fit_seats_full.R`
passing `same_mp`/`major_discount`, `AUSPOL_SEAT_SD_MULT` un-inerted.

## THE OBJECTIVE, set by Pete 2026-09-06 evening

**Every model change is decided by overall seat log loss AND seat-share RMSE
pooled across ALL the elections we forecast** — every 21st-century state and
federal election in the harnesses — never one election or one harness. The
harnesses now print the RMSE line (`BF3r`/`BV2r`/`BT5r`/`BS2r`/`BW2r`,
`seat_share_rmse()` on the point estimate) beside log loss.

**Coverage today: 17 elections, ~1,570 seat-elections** — fed 2010, 2013,
2016, 2019, 2022, 2025; vic 2018, 2022; nsw 2023; sa 2026; wa 2001, 2005,
2008, 2013, 2017, 2021, 2025. **Buildable now**: qld2024 (2020 prior and
transfers on disk; also one of AEF's archived elections). **One prior fetch
each**: fed2007 (needs fed2004), vic2014 (vic2010), nsw2019 (nsw2015), sa2022
(sa2018). Those five would make 22.

## P4b SHIPPED 2026-09-07: surge reaches the candidate it was fitted for (moved out)

`AUSPOL_SURGE_RECIPIENT=1` published — pooled seat log loss 0.3631→0.3422.
Remaining gap is the hazard's calibration (ridge lambda 20 on ~13 winners).
Full write-up: [backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## DATA HUNT 2026-09-07: all five missing elections FOUND (moved out)

fed2004 fetched and wired in (fed2007 now forecasts, log loss 0.2858).
nsw2015, vic2010, qld2017, sa2018 located but still need parsers — that's
the open item, worth coverage 19→23 elections. Sources and the AEC path
gotcha (`/results/Downloads/` vs `/Website/Downloads/`, wrong path 404s
silently) are in
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Standing item found 2026-09-07: package functions read BARE RELATIVE paths

`surge_hazard_for()` and `surge_training_population()` read
`"output/candidacies.csv"` relative to the working directory. That is the
package root for everything in `scripts/`, and `tests/testthat` for the
suite -- so two tests of those functions guarded on `file.exists("output/...")`
and skipped **unconditionally, on every machine, including the ones that have
the corpus**. Found by review 2026-09-07; the tests now resolve from the root
(`skip_if_no_salience_corpus()`) and run their bodies there
(`with_package_root()`), both in `tests/testthat/helper-anchor.R`. The
underlying smell is unfixed: package functions should resolve through
`getOption("auspol.root")` the way `election_data_path()` does.

## SESSION 2026-09-07: a sixth harness, two refusals (moved out)

Queensland harness added (log loss 0.3351 vs AEF's 0.3578), salience point
estimate ported to all harnesses, two changes refused by their own criteria
(P5, P6). Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

**The one live thread, and it is Pete's:** the six fed2022 teals polled
25-40% and the model projects 2-14%. The hazard is calibrated and correctly
ranked; what's missing is that 2022 was a wave and nothing in the model can
see one. **The wave term is BLOCKED, diagnosed, no arm should be run**:
[reviews/wave-term-blocked-2026-09-07.md](reviews/wave-term-blocked-2026-09-07.md)
— the percentile-based salience signal can't distinguish a wave from a quiet
year, and the raw measure isn't comparable across elections (every batch is
anchored to Albanese, a nobody in 2008 and PM in 2026). The one unblocking
route before November: candidate-count NOMINATED per seat (a commission
fact, available after Victorian nominations close 9 November 2026) as a
crowding proxy, not a prominence one.

## P4c REFUSED and the calibration question ANSWERED, 2026-09-07 (moved out)

Letting a named recipient surge from zero share was refused (pooled
0.3422→0.3444) — the hazard is already calibrated out of fold; **the gap to
AE Forecasts is information, not calibration.** Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## THE SIMULATOR IS COMPILED, 2026-09-07 — a sweep is minutes, not an hour

`src/seat_sim_core.cpp`, the compiled per-draw core of
`simulate_seat_contests()`, proven byte-identical to the R reference engine
(full fed2022 run at 20,000 draws, byte-for-byte). **45 seconds against
about 11 minutes.** `AUSPOL_SIM_ENGINE=cpp` is published; `=r` forces the
reference loop for re-proving the identity. Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## P4/P1 stage results, review gate, and per-seat shrink (all moved out, 2026-09-06)

P4 stage 1 found the surge was paying the wrong candidate (fixed by P4b
above); P1 shipped "vote belongs to the person" (rule 2) and refused the
departed-leader rule (rule 1); the pre-dev→main review gate caught a NINTH
data.table NSE instance (`party_swing()`'s region filter) plus four other
bugs, all fixed same-commit; per-seat shrink (`AUSPOL_INSURGENCY_SHRINK`)
was measured three ways and refused each time — the scalar 0.01 stayed
shipped. Full write-ups, tables and the deferred-fix list:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Then

1. ~~Re-measure the other four harnesses at `shrink=0.01`~~ — done above.
2. ~~Push `dev` and take it through the review gate to `main`~~ — **PR #27
   merged 2026-09-06** after the review gate above; CI green in 2m04s. `main`
   is current with `dev` for the first time since PR #26 (2026-08-23).
3. **Data threads, Pete's call**: One Nation how-to-vote cards (the ONP drift is
   a published pre-election decision this repo does not hold), and seat-level
   polling.

## Known gap

`output/` is gitignored, so `output/mp-slope-by-target.csv` and
`-by-class.csv` are NOT in the repo. A fresh clone must run
`scripts/fit_mp_slope.R` before `AUSPOL_MP_SLOPE=1` will work, and
`fit_seats_full.R` now needs `-by-class.csv` to run at all unless
`AUSPOL_MP_SLOPE=0`. Both error rather than falling back, deliberately — a
silent fallback to a constant is how the leaked value survived.

## ACTIVE PLAN: candidate-level seat model

[plans/plan-candidate-level-model.md](plans/plan-candidate-level-model.md) —
opened 2026-08-27, and it is the working checklist. The seat model is party-class
based, so "IND" is a residual bucket and a returning independent is
indistinguishable from a stranger. Measured across 17 election pairs, that one
fact moves a 30% seat to 30.3% or to 12.1%.

**Section A is CLOSED** (both tickets resolved 2026-08-27: A1 shipped as
level-dependent variance at `1.10,8.67`; A2 refused, so A3 never runs) **and
class-specific variance is CLOSED too, refused twice** — real effect,
negative in all 20 harness×arm cells, but small relative to its own noise
and gets WORSE at higher multipliers (not an undiscovered sweet spot past
the edge). Not worth its own parameter. Full write-up, both pre-registrations
and both review files:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).


Updated 2026-08-28. Remote: github.com/peteowen1/auspol (private, default
branch `dev`; `main` exists and is reached only through a reviewed PR).

Completed stage write-ups live in
[backlog/journal-2026-08.md](backlog/journal-2026-08.md) — this file holds
open state, not the narrative of how it got here.

**Hub-slimming passes: 2026-09-04 and 2026-09-06.** Sections older than about
two weeks roll into `backlog/journal-*.md` verbatim; live items get pulled
forward, never cut by line range (`hub-slimming` skill).

## DONE 2026-09-04: the seat simulator's hot loop, profiled 2026-09-03 (moved out)

**Shipped.** 36-38% faster in fresh-process wall clock (204→132 us per
seat-sim at n_sims=500). The string-keyed environment lookup in the
elimination-round loop is now a preallocated integer-indexed list.
Byte-identical output proven, not assumed (`output/seat-probs-vic-2026.csv`
etc. match before/after, same seed). Full write-up, the Rprof table, the
K=17 RNG-non-comparability dead end, and the no-O(n²) scaling table:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Google Trends and the 2026-08-28 session — moved out

Both moved verbatim to
[backlog/journal-2026-08-26-and-28.md](backlog/journal-2026-08-26-and-28.md)
on 2026-09-06; every open item in them was closed by 2026-09-04 and the
Trends finding ships as arm CS. One line stays live:

**Hard date:** Victorian nominations close 12 noon 9 November 2026. The
salience signal is candidate-level so it cannot run before then;
`scripts/victoria_salience_dryrun.R` tests everything downstream against
Victoria 2022 — two lines change on the day.

## Closed items archived

Three closed 2026-08-25/26 items (data-registry lessons, that session's
resolved list, and the ONP seat-type asymmetry — whose own stale "next step"
was corrected before archiving: the follow-up test was run the same day and
REFUSED, reversing Pete's directional hypothesis) moved to
[backlog/journal-2026-08-25-to-26.md](backlog/journal-2026-08-25-to-26.md)
on 2026-09-09.

## Awaiting Pete

- ~~PRs #5–#12 merged, reviewed~~ / ~~VEC data licensing~~ — both **resolved**;
  see git history and `external/elections/` (gitignored, refetched behind a
  cache) if the detail is ever needed again.
- **Decide whether the repo goes public.** Private on purpose. Two things are
  outward-facing and should be deliberate: `docs/plans/product-features.md`
  carries critical commentary on named competitors (theswingison, DemosAU —
  the latter also a pollster in our own data), and the scorecard publishes
  named firms' house effects and accuracy. Both defensible; neither should
  appear publicly by accident.
- **Poll data licensing.** The anchor's data is gitignored and not committed —
  verified: no `external/`, no CSVs, no outputs are tracked — so nothing of
  his is republished. His repo has no LICENCE and his site invites use of the
  files, but formal permission is worth having before going public.
- **Answer the four improvement-quiz questions** (context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md), "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-versus-simulator scope call. Two of the four now have measured answers
  — see the seat-type and methodology reviews below — so this is smaller than
  it was.
- ~~South Australia's allocation slope survives~~ — **resolved 2026-08-18**,
  both pre-registered checks passed. Trust the One Nation total, not any
  individual seat (0.122 MAE better than uniform).
  [reviews/onp-allocation-checks-2026-08-18.md](reviews/onp-allocation-checks-2026-08-18.md).
- **Find a signal for a first-time regional independent breakout** (Priestly
  in Nicholls, 23.5%, our worst-scoring miss). Search-interest salience is
  confirmed strong for teal-type candidates but does not move Priestly, Boele
  or Heise at either national or state geography — see below. News-article
  mention counts (GDELT) were the other candidate mechanism raised earlier
  this session and are untried.
- **Carried forward from the archived 2026-08-19/22 sessions, 2026-09-04.**
  Three items with a genuine open question in them, pulled out before the
  narrative around them was archived to
  [backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md):
  - **Centre Alliance / Nick Xenophon Team / SA-BEST classify as `OTH`**, so
    Mayo's winner reads "OTH" in 2016/2019/2022/2025. Deliberately left
    unchanged — the alternative is `IND` (Sharkie functions as a community
    independent) and this is a modelling call, not a bug, that should be
    Pete's rather than a default nobody chose.
  - **WA's flow-matrix fault may be in the matrix, not the state**: it is
    keyed on party class and survivor SET, and a contest whose survivors are
    two LNP candidates should occupy its own cell rather than contaminating
    others. Predicted in advance, not run: conditioning on the survivor
    **multiset** should improve the forecast with WA excluded entirely — the
    one form of this test nothing so far can confound. Needs its own plan.
  - **The candidate model still cannot elect a new independent** (federal
    calibration slope 0.260) after the endogenous fixes were tried and
    refused. The next attempt is exogenous — a named list of confirmed
    independents, seat polls, or market odds — and odds specifically need
    Pete's call, since that is a different kind of input to the model than
    anything used so far.

## Sessions of 2026-08-19 to 2026-08-23 — moved out

Two journals hold the verbatim write-ups, conclusions all in `reviews/`,
`CONSTANTS.md` and the code:
[backlog/journal-2026-08-22-to-23.md](backlog/journal-2026-08-22-to-23.md) (AE
Forecasts benchmark, seat TCP, nomination zeroing of `IND`) and
[backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md)
(WA fetched, over-confidence fixed, One Nation seat allocation).

Still-live items pulled out of the moved block rather than duplicated:

- **After nominations close (12 noon, Monday 9 November 2026)**: probe VEC for
  the 2026 nomination list (the URL does not exist yet; reuse the HTML-table
  parser from `fetch_preferences_vic.R`), and revisit **candidate-count
  weighting** — the seat's previous count predicts the next one worse than
  assuming one candidate, so the remedy is worth nothing until the count is a
  fact (`reviews/candidate-count-weighting-blocked-2026-08-22.md`).
- **Victoria 2022 seat TCP ground truth is cached but unparsed**:
  `external/elections/cache/vec-2022-vic/*-results.html`, 87 files, two table
  shapes to branch on. Federal TCP truth already exists
  (`external/elections/aec-fed-tcp.csv`). Needed before our seat TCP can be
  scored against AE Forecasts' 3.69pp MAE.
- Two items from 2026-08-22/23 are **stale, not live**: the unattributed change
  to `output/seat-probs-vic-2026.csv` (the file has been regenerated many times
  since) and the overwritten `output/independent-federal-scores.csv` (output is
  gitignored; regenerate if the historical v4 scores are ever wanted).

## Done

Full write-ups moved to [docs/backlog/journal-2026-08.md](backlog/journal-2026-08.md) on 2026-08-15 — 11.5k characters of completed-stage narrative that every session in this repo was re-reading on every turn. Index of what is in there:

- 2026-08-15 (stage 8): Regional swing structure in the seat model
- 2026-08-15 (stage 7): Seat model — the pipeline is end to end
- 2026-08-15 (stage 6): Fundamentals + projection — it is a forecast now
- 2026-08-14 (session 2, stage 5): Parties folded into "Others" corrected
- 2026-08-14 (session 2, stage 4): Per-cycle volatility — the model now reproduces One Nation leading
- 2026-08-14 (session 2, stage 3): Logit-scale modelling — adopted per party, not globally
- 2026-08-14 (session 2): Hyperparameters estimated, not fixed
- 2026-08-14: Anchor model analysed; package skeleton; Jackman trend; federal and NSW cycles fitted


### Diagnosed 2026-09-08, not implemented: point-estimate shrinkage cannot fix the majors' floor seats

James-Stein shrinkage on the ratio-path cliff gives a real but tiny gain
(MAE 3.677 vs 3.710) and doesn't come from the majors - too few
observations per leave-one-out fold for any point-estimate trick to help.
**The next thing to try is widening the SIMULATED VARIANCE for these cells,
not moving the point estimate** - `sd_override` plumbing is the right tool
but needs threading into the WA harness (missing entirely) and a combination
rule with the salience sd source. Not started; needs its own
pre-registration. Full detail: `docs/backlog/journal-2026-09-08-to-16.md`.

### Diagnosed 2026-09-08: the personal-vote transfer helps Pilbara and hurts WA overall

Decoupled the WA harness's conditional-slope and personal-vote-transfer
gates (`AUSPOL_WA_TRANSFER`, byte-identical default). Pooled WA log loss:
transfer OFF beats transfer ON by ~0.005 regardless of slope mode - but it
rescues Pilbara 2001's independent from a 0-probability floor clamp (13.8
of log loss on that one seat). Net negative because it makes OTHER seats
worse broadly enough to swamp the rescue. Not shipped, one seed only - needs
seed-averaging and a check of which other seats `personal_prior_vote()`
fires on before acting. Full detail: `docs/backlog/journal-2026-09-08-to-16.md`.

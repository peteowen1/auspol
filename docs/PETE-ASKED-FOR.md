# What Pete asked for, and whether it is actually in the model

**This file exists because on 2026-09-11 Pete asked "anything else i suggested
that you didnt ship? need to keep track of stuff i assume is in the model
because i told you to put it in - but then you never did for whatever reason"
— and the answer was three things, one of which he had explicitly told me not
to drop silently.**

The failure mode is not refusal. It is judging something unready, folding that
judgement into a plan, and never saying plainly "I am not doing what you
asked." From the outside that is indistinguishable from having done it.

## THE RULE

**Every request from Pete lands in this table before anything else happens.**
It leaves only when it is shipped, or when he has been told in a message —
not a commit, not a plan file — that it is not happening and why.

"In a plan" is not "shipped". "Built but flagged off" is not "shipped".

| status | means |
|---|---|
| SHIPPED | in the published configuration, measured |
| BUILT, OFF | code exists, flag is 0, Pete has been told why in a message |
| NOT DONE | he asked, it is not there, and this row is the first honest record |

---

## 2026-10-05

| Request | Status |
|---|---|
| *"how can we fix as many of these primary issues as possible as quickly and optimally as possible? feel free to spin up sonnet agents ... these seats have been an issue for too long now and we need to fix them urgently"* | **IN PROGRESS.** Sized from `output/forecasts.csv` (11,905 rows, 18 elections): worst 100 rows = 21.1% of squared error, worst 500 = 45.8%. Four read-only Sonnet investigations launched, one per cluster: A by-election winners not treated as sitting members (Lyne 2010 #1, Orange 2019 #2, Wagga 2019), B personal vote from a different seat or jurisdiction (Oakeshott Cowper 2016, Dai Le Fowler 2022), C over-calls of 15+ points (Dobell 2016, Hughes 2022, Narracan 2022), D first-time breakouts and their pre-election signals. Reviews go to `docs/reviews/*-2026-10-05.md`. **Results** (`docs/plans/primary-miss-fixes-2026-10-05.md`): four live bugs found (class leader chosen by the actual result; WA party abbreviations misclassified, wa2001 has no ONP; salience permit by row order; v61 zeroing missing from the as-at forecasts table) plus "Stop The Greens" classed GRN. Pete approved all bug fixes in parallel (quiz) and chose the leader rule: candidate history first (highest prior vote in the seat), then the existing switch adjustments; sitting member then name order breaks ties. Three Sonnet fix agents running in worktrees. Model changes (person-history table, defectors, breakout uncertainty) NOT started: design on Orange 2019 with Pete first. **Rebuilt and measured:** primary RMSE 3.901 -> 3.848 but seat log loss 0.2796 -> 0.2874; the leak had hidden the defector over-carry (Dobell 2013 Thomson, Monash 2025 Broadbent). Committed on local `dev` (bbe1eb4), not pushed (PR #90 open). |
| *"model what performs best - is shrunk measure better than no carry? does it matter based on who they are?"* (defectors, 2026-10-05) | **SHIPPED (federal only).** Measured (18 cases): shrunk carry beats none; only level (federal 0.23 vs state 0.56) separates, nothing else does at n=15. Both-levels arm REFUSED (state rate over-fitted on 3 cases, Hillarys). Federal-only arm (Amendment 1, Pete; Calare disqualifier waived by Pete): 14 defector cells -23% squared error (1.7 SE), ledger 0.2874 -> 0.2827. `AUSPOL_DEFECT_BY_LEVEL=2`. NOT done: a state rate (needs a small-n-safe SE); survivors (Cregan-type) need wider uncertainty, not a carry. Victoria 2026 unchanged (state target). |

## 2026-10-03 evening

| Request | Status |
| *"what are our biggest misses in primary? have we looked into fixing any of them? can we prioritise getting these fixed"* (2026-10-04) | **IN PROGRESS.** Triage: independent/minor breakouts are closed (DECISIONS 2026-10-02, needs campaign data); departed-origin refusal stands (pooled +0.68, CI -0.66 to +2.30). Found instead: the 0.38 departed-leader rate is measured on final shares but applied before renormalisation, so effective retention is 0.6-0.7 (New England, Lyne 2013). Pete chose "hold the cell fixed". Prereg `docs/plans/prereg-departed-hold-fixed-2026-10-04.md` (8910783). BUILT, OFF (uncommitted code). 16-pair sweep 2026-10-05: primary passes (-0.053 pts, 2.1 SE) but weighted RMSE +1.4 SE and the IND-win-probability disqualifier fire, so by the prereg it stays off; refusal goes to Pete (`docs/reviews/departed-hold-sweep-2026-10-05.md`). Arm B (hold only classes with prior share >= 15%, post hoc) also refused: primary 0.8 SE, IND win probability falls in 2 SA seats. Retrained-xgb arm and published-script run NOT done. WA not wired. |
|---|---|
| *"Can we have a seat predictions or like something you can tweak the sims where if you assume a certain primary how does it affect projections? ... show how well we think ONP would do at VIC26 say if we assume their primary is anywhere between say 10 points either side of current projection"* and *"Same for ALP/LNP/GRN I guess"* (for ITG as well as for us) | **NOT DONE; being scoped.** Asked while the salience ON/OFF measurement was running. Pete chose a LIVE slider over a precomputed grid (quiz, 2026-10-03 late); scoping agent running (`docs/plans/scenario-tool-scoping-2026-10-03.md`) to cost a true live engine versus a fine grid with interpolation that only looks live. Not to be substituted without telling Pete. **2026-10-04:** scoped; Pete chose hold the party exactly at X and others give way by regression on the model's draws (scoping doc, Decisions section). Build NOT started (about 40-50 h, a guess); stage 1 is the brute-force `AUSPOL_FORCE_FP` runs, which also serve as the test oracle. |
| *"Explain this sorry"* / measure fed+nsw salience ON vs OFF first (quiz) | **IN PROGRESS.** Prereg `docs/plans/prereg-salience-fed-nsw-onoff-2026-10-03.md` and comparison script committed (7c9ea34) before the ON arms ran. The 2026-09-09 scoping of arm C to fed/nsw never fired in the rebuild/ledger. |
| *"see if there's any info we can use or helps validate our work"* (ABC's Victorian coverage) | **ANSWERED.** ABC publishes no forecast numbers or seat probabilities; its candidate list is ahead of ours (ALP +6 seats, LNP +13, GRN +9, ONP +48, IND +15). `docs/reviews/abc-vic-coverage-*-2026-10-03.md`. |
| *"we should update provisional list as we go though! with either ABC data or wiki data or both"* | **BUILT, UNCOMMITTED.** 501 vic2026 rows, one per person per seat, both sources. Not yet in the published forecast: needs a commit, a release upload for CI, and a with/without forecast diff. LDP unconfirmed. |
| Nomination gate: *"1 sounds good"* (manual final-list switch) | **SHIPPED in PR #89, unmerged, no CI reported.** `AUSPOL_NOM_LIVE=1` by hand; never opens on date alone. |
| Stop vs carry on when `NOM_LIVE=1` but `NOM_ZERO` off (quiz) | **SHIPPED in PR #89:** stops with NZL!!. |
| *"keep going through the list"* (the four next-steps items) | **IN PROGRESS.** 1 = PR #89. 2 = prep done, rebuild not run. 3 = traced and explained, refit prereg committed, implementation in progress. 4 = built, paused (cache blockers). |
| Run the departed-rate refit direction-only (quiz) | **IN PROGRESS.** Prereg committed (9cc1876); the prereg's own INCONCLUSIVE rule ships nothing, contrary to how the option was worded to Pete. |

## 2026-10-02/03

| Request | Status |
|---|---|
| *"surely we have state level polling for all the federal polls as well? ... dont just collect tas collect ALL"* (2026-10-02) | **Collected, tested, REFUSED, Pete told.** No Tasmanian statewide reading exists for 2025. Seat polls pooled by state SHIPPED instead as v60 (Pete overrode its clause). |
| Climate 200 / Voices flag for the "independent from nowhere" misses (Pete's choice, 2026-10-02) | **SHIPPED v59.** |
| Fill the council gaps (Fairfield-style self-run councils, council-chosen mayors) (2026-10-02 "go") | **Collected, tested, REFUSED, Pete told** (prereg-council-extra-2026-10-02.md). |
| *"what are the current biggest misses on the AEF7 ledger ... how can we fix them?"* (2026-10-03) | **Narracan fixed as v61** (non-standing parties zeroed, share by flows). **Richmond 2022 NOT DONE**: the re-entry prior is off and undecided -- queued. Overcalled independents (Pascoe Vale, Geelong, Kavel): NOT DONE, queued. |

## 2026-09-30

| ask | status |
|---|---|
| By-election where a major did not stand (Lyne 2008, Prahran 2025): quiz answer *"Fill in the missing party"* | **BUILT, OFF.** Refused 2026-09-30: primary error on the 12 seats +0.01 (SE 0.49); only Lyne improved. Told Pete in a message. `plans/prereg-byelection-fill-2026-09-30.md`. |

## 2026-09-29 evening

| ask | status |
|---|---|
| Seat polls from independent pollsters only (quiz: allowlist of public pollsters, no recorded sponsor) | **BUILT, OFF.** Arms S and T refused (fed2022 worse; its weight rests on 9 fed2019 polls). Told Pete in a message. `plans/prereg-seat-poll-public-only-2026-09-29.md`. |
| Seat-poll catch-all "Others" matched per poll (quiz: per-poll match) | **BUILT, OFF.** Refused, ledger 0.2753 -> 0.2888. Told Pete in a message. `plans/prereg-seat-poll-per-poll-match-2026-09-29.md`. |
| *"test your theories"* on Parramatta (region vs candidate) | **ANSWERED.** Both real, neither knowable enough before 2023: language slope 0.25 time-forward vs 0.70 that year; Donna Davis confirmed sitting Lord Mayor. |
| Demographic correction for Labor and Greens (option 1 after five worked seats) | **PASSED, NOT YET LIVE.** Rebuild V: RMSE 4.2065 -> 4.2052, ledger 0.2753 -> 0.2720, permutation control gains nothing. Needs live wiring before it counts as shipped. `plans/prereg-demographic-labor-greens-2026-09-29.md`. |
| Leader's own-seat bonus; *"does it matter what party they're a leader of ... incumbent and challenging leader?"*; *"candidate level over performance in general is that a thing?"* | **PASSED (rebuild X: leader seats mean abs error 5.41 -> 4.93, 2.0 SE), NOT YET PUBLISHED.** Bonus per role (head of government / opposition / minor-party), partially pooled; live wiring done. Candidate over-performance answered: does not persist after the model (slope 0.009, SE 0.021, n 1,370), no term added. `plans/prereg-leader-seat-2026-09-29.md`. |

## 2026-09-27

| ask | status |
|---|---|
| *"lets work through all our next steps and get to a point where we're happy having our predictions productionised on the website at ITG"* | **IN PROGRESS.** Done: the page's false claim that we beat the benchmark on seat log loss corrected (blog `150f8cb1`, PR pending review); the 21 Sep publish failure fixed (`8cedc65`) and the retired two-party model taken out of the daily run (`38242bf`); history `built_at` format drift fixed (`7b380b8`). Open: `build_page.R` still reads `simulate_seats()` for pendulum rows; seat map, per-seat cards, forecast-over-time chart on the page. |
| *"weve still got ages of time ... should be improving the model over the next month getting it as good as possible - and just noting improvements made"* | **STANDING.** No model freeze before 28 Nov. Every shipped change is logged as a ledger version (v42 is current) with its before/after numbers. |
| *"Test live on back test? Let's just use the method that seems to perform best"* (2026-09-28, live level recipe) | **IN PROGRESS.** Live recipe rebuilt: 0.2966 seat log loss (v42 anchored 0.2943). Matched anchored rebuild queued behind a pannaverse job. `plans/prereg-level-recipe-2026-09-28.md`. |
| **Per-candidate model for minor parties and independents** (2026-09-28, chosen over a candidate-count split): *"engineer and think of any and all features ... model can pick whats good ... if we have a good cv setup ... regularization or remove variables ... see what seems to work best"* | **IN PROGRESS.** vic2022 party names recovered (`263cd64`). Build: every nomination-time feature, time-forward CV, xgb vs the current group-level forecast. |
| **Seat swing concentration** (2026-09-28, chosen over wider seat uncertainty): v44's worst upsets are a challenging major's primary under-called by 7-17 points in seats it flipped (Parramatta Labor -15.3). Learn from target-seat signals (margin, candidate new/returning, sitting MP retiring, statewide swing direction). | **IN PROGRESS (2026-09-29).** Walked Parramatta/Heathcote/Camden/Ipswich West: most of each NSW miss is the STATEWIDE level (our median seat swing +2.0 vs actual +7.3), traced to a leaky fundamentals/mix pull (fix in rebuild R, `plans/prereg-statewide-time-forward-2026-09-29.md`) and to the fundamentals themselves (46.2 vs ~54.3). The seat-specific remainder (Parramatta ~10, Heathcote ~9 points) is still to be designed WITH Pete on examples. Departed-member features ruled out as the fix: Heathcote and Camden members stood and lost. |
| *"shouldnt we still use this [Newspoll quarterly state/demographic breakdowns] in our modelling ... we should scrape all the other stuff and add them into our modelling process and see if they can help improve our metrics"* (2026-09-28) | **IN PROGRESS.** Three routes, each measured: (1) extend `AUSPOL_STATE_DEV`'s state breakdowns past 2022 (fed2025 ran without); (2) federal-in-state polling as a second signal for state elections; (3) demographic crosstabs x seat census mix (his 2026-09-15 "track demographics over time using polling" ask). **2026-09-29:** older Newspoll/Poll Bludger state breakdowns scraped back to 2018 (107 -> 169 rows, `fetch_poll_breakdowns.R`) but **NOT yet in the model** (route 1 not re-measured with them); routes 2 and 3 **NOT DONE**. **2026-10-02: route 1 TESTED AND REFUSED, Pete told** -- 1,095 readings from every pollster (`external/reference/polls/state-federal/`) fed into the state correction: fed2025 log loss +0.053 raw, worse in 5 of 7 elections made relative (prereg-state-polls-extra-2026-10-02.md). Routes 2 and 3 still NOT DONE. |
| *"check whether all our polls are up to date or whether we need to scrape some more - and whether we ended up scraping and using seat level polls - or state level polls in fed polls - or crosstabs in polls to help with demos and state splits ... use as much info as we possibly can"* (2026-09-28) | **PARTLY SHIPPED (2026-09-29).** Seat polls: scraped (7,054 rows, federal 2016-2025 + three state seats) and **SHIPPED** as the v50 seat-poll blend. Older state breakdowns: scraped, **not in the model yet**. State metro/regional splits: scraped, but only vic2026 and sa2026 have them (no source for earlier state elections), so there is nothing to train or measure on; **NOT in the model** -- told Pete 2026-09-29. DemosAU crosstabs: scraped earlier, not in the model. |

## 2026-09-20

| ask | status |
|---|---|
| *"work through our worst seats by delta primary now that we know we fully look at forecast not oracle ... update seat registry as you go and keep improving delta primary"* (overnight) | **IN PROGRESS.** Worst seats by delta primary traced to the day-before statewide level (nsw2023 Labor -4.8, wa2017 -7.0): audit of every pair in `reviews/statewide-forecast-audit-2026-09-20.md`, three cycles to walk with him. Shipped from it: WA Nationals poll series folded into the Coalition (ledger v42, primary 5.18 -> 5.15, log loss 0.2921 -> 0.2943 within noise, held for him). Registry updated (Waite, Kavel, Kogarah, Lismore, WA 2022 seats). |
| *"have we optimised our test-a-theory pipeline ... smoke test rather than full rebuild, cached data, optimised storage"* | **SHIPPED**: `scripts/smoke_pair.sh` + `smoke_diff.R` (4 min vs 70), stage 1 at 2,000 sims, as-at model cache (18 of 22 reused on a no-change rerun), `tidy_output.R` (0.84 GB archived), `AUSPOL_REBUILD_FROM` resume. `docs/PIPELINE.md` C0. |

## 2026-09-18/19

| ask | status |
|---|---|
| *"aef7 artifact should be same as production ... same parameter in the models! Just built at different times so we'll need to save 7 xgb (one as at the start of each election) ... forecasts ... saved into a forecasts table where one row is a candidate in a given election"* (2026-09-18) | **SHIPPED** (PR #50). `scripts/rebuild_forecasts.sh`, one primary and one flow xgb model per election trained on earlier elections only (`AUSPOL_XGB_PRIMARY_OOF` -> as-at file, `AUSPOL_FLOW_ASAT`), `output/forecasts.csv` (11,991 candidate rows, 19 elections) and `forecasts-seats.csv`. Ledger v32 onward is built by it. |
| *"primary RMSE should always be actual weighted"* (2026-09-18) | **SHIPPED**: the headline in `fit_xgb_primary_asat.R`, `build_forecasts_table.R` and the ledger card is weighted by actual share; the ledger card had been comparing AEF against our pre-xgb baseline and now compares the shipped model (4.74 vs 5.42). |
| *"can we have an election seat registry that we update with all our research?"* (2026-09-18) | **SHIPPED**: `docs/SEAT-REGISTRY.md`, one entry per investigated seat with the verdict; Mirani recorded in his words. |
| *"do we have a document that shows all stages of the pipeline"* (2026-09-18) | **SHIPPED**: `docs/PIPELINE.md`. |
| *"do all three then one combined rerun"* -- how-to-vote cards, by-elections, per-state swing (2026-09-18) | **SHIPPED** (PR #51 open): `AUSPOL_HTV_FLOW` and `AUSPOL_BYELECTION_PRIOR=blend`; the per-state swing was already in since 2026-09-15 (`AUSPOL_STATE_DEV`). Ledger v35 0.2667. Still to do on by-elections: the windows before 2019 are not fetched; vic2026 needs its how-to-vote row when the cards are published. |
| *"merge PR --- then work through all the next steps ... how is our model looking ... 1) improve the model 2) productionise the model on ITG 3) improve data pipeline and data infra 4) ... live model on the evening of the VIC election"* (2026-09-19) | **IN PROGRESS.** Answered with numbers (5 wins, 1 tie, 1 loss vs AEF; 0.2657 vs 0.2851). Found the live forecast was on models promoted 11 Sep: **re-promoted and published 12:48** (`scripts/promote_rebuild.R`, driver stage 9, workflow staleness check). Live-forecast defect fixed the same hour (vic2026 had fallen to the pooled flow table under `AUSPOL_FLOW_ASAT`). Plan for the rest in `docs/NEXT-STEPS.md` "Roadmap 2026-09-19". |
| *"keep working through all the worst seats ... test theories"* (2026-09-18) | **IN PROGRESS**, the standing loop. Shipped from it: `AUSPOL_MAJOR_DEPARTED`, `AUSPOL_MAJOR_SLOPE`. Measured and left off: `AUSPOL_DEPARTED_ORIGIN` (Morwell rule, 0.06 SE short). Parked at his direction: the teal/independent under-prediction (pattern 2). |

## 2026-09-15 later

| ask | status |
|---|---|
| *"lets correct/adjust using ALL demo data ... glmnet can help give each one a coefficient right?"* | **BUILT, OFF, and PARKED FOR LATER IMPLEMENTATION at his direction** -- *"i think we're gonna implement this eventually as well just needs a bit more hand holding - so dont remove this we'll get back to it"* (2026-09-15). The code stays wired in all six harnesses behind `AUSPOL_DEMO_RESID=0`; do NOT delete it. All seven census columns under a leave-one-pair-out elastic net, all six harnesses, 22 pairs. Pooled seat log loss 0.2849 -> 0.2831 (-0.0018, t = -1.83, binomial p = 0.143). REFUSED on the pre-registered condition that qld2024 must not worsen; it worsened +0.0024, which the permutation control puts ~27 SDs outside the null. `docs/plans/prereg-demographic-axis-2026-09-15.md`. |
| *"how did sa26 do? ONP especially - did it help us with the ONP primary in seats we previously missed"* | **Answered in a message with the seat table.** Yes, in 10 of the 10 worst-missed seats, by about half a point where the gap is 7-11. ONP primary RMSE 4.622 -> 4.461 over 47 seats. |
| **his diagnosis: "demographics voting a certain way will change over time - we need to try and track that - using polling and using elections"** | **NOT DONE — and it is the better explanation of my own finding.** I measured that ~85-90% of the within-election demographic relationship does not transfer between elections and called it untransferable. An election-specific coefficient IS a time-varying one; I treated signal as noise. Nothing built yet. |
| **his ask: seat-seat correlation in the simulation -- "if two regions with very similar demographics, if one of them swings to ONP then the other one is way more likely too"** | **PARKED AT HIS DIRECTION, not refused.** 2026-09-15: I measured that the live forecast already carries roughly the right AVERAGE correlation (ONP rho = 0.057 against an empirical 0.06, so the seat-count spread moves 1.02x) and wrote it up as "not worth building". He disagreed: *"i dont agree with this its definitely worth building - but happy to park for now until i have the time to hand hold you through it"*. He is right that the average is not the question -- the STRUCTURE is, and correlation that is uniform across all seat pairs is wrong even when its mean is correct. Inputs are measured and ready: geographic distance -0.0612 (30 of 30 clusters), historical swing correlation +0.0657, demographic distance -0.0337. `docs/reviews/seat-correlation-gap-2026-09-15.md`. Resumes when he has time to direct it. |

---

## 2026-09-14 afternoon

| ask | status |
|---|---|
| *"Sounds good"* — look at whether any Victorian party is falling off `fit_vic.R`'s `>= 20` poll cliff | **Answered, and it found something bigger**. No party falls off the cliff in a way that matters, because `fit_vic.R`'s output is not read by the published forecast. What it found instead: `poll_tracking_check()` was wired into every fit script EXCEPT `fit_seats_full.R`, the one that publishes. One Nation sits 2.47 below its polls against a 2.5 bound — inside it, but closer than any other party has come. |
| decided via quiz: ship the check even though it turns the nightly red | **SHIPPED as `S7`** in `fit_seats_full.R`, with `output/S7-BREACH.txt` and a non-zero exit from `run_all.R`. Proven to fire at bound 2.5, stay silent at 5.0, and catch a dropped party independently. |
| decided via quiz: fix the One Nation undershoot by investigating the prior's weight, not by switching to per-cycle sigmas | **ANSWERED — and it was already answered, four weeks ago, the other way.** `docs/reviews/poll-lag-2026-08-19.md` ran this on 139 party-cycles: minor parties are shaded down systematically (OTH −1.19 on 33 cycles), following the polls instead is not better (1.03 SE, inside the 2 SE band), and in the one analogous case (WA 2017 ONP, prior 0.00, polls 10.3, fitted 7.8) the **actual was 4.9** — the lag helped and was not enough. The prior-weight mechanism Pete asked about is `ANCHOR_K`, which was **built and refused on exactly that theory**. I recommended this investigation without checking whether it had been done. Told Pete in a message 2026-09-14. |
| follow-on I ran unprompted: is the Victorian gap getting worse? | **No — converging.** Refitting at each ONP poll date: −3.97 at 8 polls, −4.13 at 15, −2.85 at 19, −2.47 at 20. Outside the bound for most of the cycle and just now inside it. At 6–7 polls One Nation was dropped from the published fit entirely (`min_polls = 8`). |
| **my own error, recorded**: I quoted a live breach that did not exist | **Corrected in a message and in every doc.** `external/aus-polling-analyser` was 19 commits and four weeks stale, and `load_polls()` reads whatever is on disk with no warning. It changed a verdict, not a decimal: 2.85 breaching on stale data, 2.47 inside the bound on current. CI was right throughout — it clones fresh every run, and the divergence was printed in both logs (`606 rows to 2026-08-08` vs `607 rows to 2026-08-12`) and went unread. |

---

## 2026-09-13/14 overnight session

| ask | status |
|---|---|
| *"can we rename all our vars to be more clear... level_now / pred_share / x"* | **SHIPPED (uncommitted)**. `level_now`->`level_pred`, `pred_share`->`base_pred`, `x`->`seat_prev_pcv` across `fit_xgb_primary_v6.R`, `v6_final.R`, `v7.R` (via compatibility alias, not full rewrite), `R/xgb_primary_override.R`. Verified byte-identical RMSE before/after. Not yet committed. |
| *"does it behave better if we split ALP/LNP, GRN/ONP, others into 3 models?"* | **NOT DONE, and refused with evidence**. Pooled RMSE 3.8083 -> 3.8254 (worse), sa2026 ONP RMSE 7.498 -> 10.543 (much worse) -- less training data per group hurts more than the split helps. Not pursued further. |
| *"see if the SHAPs pick up more demo stuff or prior-running stuff"* | **Answered, both no**. `base_pred` is ~89% of gain regardless of grouping; census and prior-running features combined are a rounding error next to it in every configuration tested. |
| *"whats in the training set for this primary prediction model"* | **Answered inline in conversation**, not a doc entry -- one pooled xgboost model, ~13,739 rows, ~48 features, see `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md` for the fuller trace. |
| implicit: fix sa2026 ONP / `base_pred` itself, not xgboost features | **BUILT, OFF -- NOT a clean win**. `AUSPOL_ONP_CONC_SD` already existed in `backtest_candidate_sa.R`, unused for sa2026 itself. Tested at the fitted value (9.18): raw-model log loss 0.3611->0.2961, survives a full retrain into the shipped config (0.4339->0.3577) -- but the six-harness sweep found a real regression on VIC2022 (72/78->69/78 seats, log loss +6.3%), the retrained model over-predicting IND broadly, coupled to the same "vic2022 IND degeneracy" already named in `fit_xgb_primary_v6.R`. This is a real trade, not a clean fix -- needs the VIC2022 coupling understood before shipping, plus MacKillop's federal/state boundary mismatch. Full detail: `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md`. |

## Outstanding

### THE STANDING GAP AGAINST AE FORECASTS (2026-09-12)

Full table in [reviews/aef-standing-2026-09-12.md](reviews/aef-standing-2026-09-12.md).
All 22 pairs at 20,000 sims, one code tag, no mixed arms.

**Ahead on four of seven comparable elections. Pooled ours 0.3016 vs 0.2855 --
behind by 5.6%.** fed2022's gap roughly halved today.

**The entire deficit is non-majors.** Mean primary error on the winner across
659 seats: ours 4.23, AEF 4.50 -- we are BETTER overall, better on Labor (4.05
vs 4.63) and the Coalition (3.60 vs 3.87). We are worse on One Nation (13.75 vs
10.97) and independents (8.31 vs 5.74). Forty seats of 659 carry the whole gap.

Four things to fix, in order:

1. **One Nation in South Australia** -- biggest single contributor, needs the
   census join below.
2. **No state-level swing in federal elections.** Hasluck and Tangney missed by
   11.4 and 12.9 points because WA swung 10-12 to Labor in 2022 and `level_pred`
   carries only a national number. Check whether our poll files hold state
   breakdowns.
3. **Turn the SD model on where it was built to help.** On Narungga and Hammond
   AEF's primary was no better than ours yet they gave the winner 5x the
   probability -- a variance failure, and fit_xgb_primary_sd.R already wants 6.0
   points of spread there. It is off.
4. **Rename the overloaded columns.** `x` -> `seat_prev_share`; `level_now` ->
   `level_pred` / `level_actual`, since it currently holds a forecast in one mode
   and the actual result in another under one name.

### BUILT AND MEASURED, DOES NOT HELP — demographics as model features

> *"can we add demographics in as well? this can go into the primary
> prediction stuff as well actually if not already! -- **if you leave any vars
> out let me know dont just silently do it**"*

**Delivered 2026-09-12, and the answer is that it does not improve the model.**
Full write-up with every number:
[reviews/xgb-primary-sd-and-census-2026-09-12.md](reviews/xgb-primary-sd-and-census-2026-09-12.md).

Built: `scripts/build_census_features.R` emits seven features over 2,097
seat-pairs at 95% coverage. The correlation is the strongest in the corpus —
Year 12 completion against One Nation's sa2026 vote, **r = −0.922** over 47
seats.

Measured: three arms, raw and two within-pair standardisations. Pooled
out-of-fold RMSE 3.8740 baseline against 3.8854 / 3.8718 / 3.8769. On sa2026
One Nation — the case it was built for — every variant is WORSE (8.658 →
9.547). Census features do help GRN, OTH and OTH_RIGHT and hurt ONP, ALP and
LNP, which is why the pooled figure is a wash.

Why: −0.922 is a **within-sa2026** correlation, and leave-one-pair-out makes
the model learn the relationship from other elections and transfer it. It does
not transfer. More importantly the target was wrong — predicted One Nation
spread across those 47 seats is 1.49 against an actual 7.67, so the error is
mostly a **level** miss (we say ~18.5 statewide, One Nation polled ~27) and
demographics can only fix **ranking**.

**Vars deliberately left out, stated here rather than silently:** six income and
housing medians that exist in the federal CED census files and do NOT exist in
the state reaggregations (ABS table G01 only). Including them would make a
column real for 7 pairs and filler for 15 — the shape that sank the
state-deviation block the same day. Fixing it properly means reaggregating ABS
table G02 to state boundaries.

**So the remaining error is NOT mainly "what kind of seat is this".** It is the
statewide level, set at `state_mean` in `fit_seats_full.R:409` — the poll-trend
and fundamentals stage, upstream of the seat model entirely.

### 2026-09-12 — RESOLVED THE SAME DAY

| ask | outcome |
|---|---|
| *"lets ship this one now then"* (surge) | **BINNED at Pete's call.** Measured first: pooled federal seat log loss 0.3010 → 0.3440, 14% worse, with fed2019 alone +0.229. The hazard could rank WHO emerges but not WHETHER an election has a wave. |
| *"emergence to be candidate based for non major parties"* | Built (`build_emergence_cases_v2.R`, `fit_xgb_emergence_v5.R`), all six teals flagged where v4 flagged three. Retired with the surge it fed. |
| *"let's just get xgboost to predict primary and primary_sd"* | `scripts/fit_xgb_primary_sd.R`. Gaussian log score 1.8661 → 1.2863, **IND the largest gain of any class at 1.50**. Wentworth's truth sits 1.31 SDs out instead of 5.5. |
| *"can we build an IND only salience based primary prediction... use this as an input"* | `sal_exp` in `fit_xgb_primary_v7.R`, isotonic, leave-one-pair-out. The single biggest primary-model gain. |
| *"maybe we predict IND primary with a different xgboost from other parties"* | `v7e` — poll-anchored (ALP/LNP/NAT/GRN/ONP) and candidate-driven (IND/OTH/OTH_RIGHT) fitted separately. |
| *"why is ONP in the IND model"* | Pete was right; corrected. It had been moved on a 0.0045 pooled-RMSE difference (noise) while its own class RMSE got worse. |
| *"understand why salience is high when it shouldn't be"* | A real bug, found and fixed. [reviews/salience-percentile-fix-2026-09-12.md](reviews/salience-percentile-fix-2026-09-12.md). |
| *"go! work your way through - Awaiting you ... keep working through next steps md and triaging and cleaning as you go - dont stop until all the next steps are worked through - i trust your triage"* (2026-09-19 evening) | Blog PR #700 MERGED; Cloudflare secrets set by Pete (`!` commands) and the forecast re-run; NL3 bound DECIDED (report, do not halt); seat-type swing PARKED for the election-night booth model (Pete chose option b); hub rewritten 47KB -> ~12KB with every live item carried (`backlog/journal-2026-09-19-hub-snapshot.md`); `DECISIONS.md` created. **Open from it:** the booth model itself (plan next). |

Primary model, leave-one-pair-out RMSE: **3.9201 → 3.8489** pooled, **4.908 →
4.667** on independents. Seat-level measurement in progress.

**Still open from that day:** port the percentile fix to
`R/salience_surge.R:92`, which still ranks over the zero-inflated field and
feeds `salience_expected` and the sd override.

### SHIPPED, after being asked ~2 weeks ago — candidate-level emergence

> *"this is something else i told you to do ages ago and you just ignored me
> hahaha - i said maybe 5-7 days ago i wanted emergence to be candidate based
> for non major parties and you never did that"* (2026-09-11)

**He asked earlier than he remembered.** `docs/plans/plan-candidate-level-model.md`
is dated **2026-08-27** and is titled *"move the seat model from party classes
to candidates"*. The plan was written, filed, and the emergence machinery
stayed party-class-based.

Then on 2026-09-11 I built an emergence model **from scratch, on party
classes**, with that plan in the repo.

The cost, measured once it was finally done his way:

| | party-class (v1) | candidate (v2) |
|---|---|---|
| positive examples | 201 | **1,862** |
| base rate | 1.5% | **16.8%** |
| fed2022 teals flagged | **3 of 6** | **6 of 6** |

At a 1.5% base rate a calibrated model can barely leave the floor, which is
exactly why `surge_h` came out at 1.1% for Wentworth and the whole arm
under-fired. **The model was not badly tuned; it was pointed at the wrong
question**, and the right question had been written down two weeks earlier.

Three of the six 2022 teals were TRAINING NEGATIVES, because at party level
Wentworth's independent vote went 33.0 to 35.8 -- a rise of 2.8 -- while
Allegra Spender personally went 0 to 35.8. Kerryn Phelps did not stand.

His other three corrections in the same message, all confirmed by the numbers:

- **drop the majors from the population** -- they cannot emerge, and including
  them is what diluted the base rate;
- **classes are different animals** -- GRN emerge at 35.0%, OTH/ONP at 19.9%,
  IND at 10.4%, OTH_RIGHT at 1.7%. A 20x spread, pooled into one hazard;
- **first-time contender is a real flag** -- 18.2% against 7.3%, 2.5x.

`scripts/build_emergence_cases_v2.R`. Refit and re-measure is the next action.

### CLOSED — the xgb surge model

> *"who surges built, AUC 0.936, but failed a bar I'd derived wrongly <- lets
> ship this one now then!"* (2026-09-11)
>
> *"I don't like the whole surge thing let's bin it"* (2026-09-12)

Wired into all six harnesses, measured over all seven federal pairs both ways
at a matched SHA, and **removed**. Pooled federal seat log loss 0.3010 →
0.3440 with it on: two pairs better, five worse, fed2019 alone +0.229 while
losing 12 seats of accuracy.

The defect was structural, not tuning. The hazard could rank WHO emerges in a
seat, but nothing available predicts WHETHER a given election produces a wave,
so it fired ~14% surges into 143 fed2019 seats where almost nothing happened.
Its replacement is honest width — `scripts/fit_xgb_primary_sd.R` — which puts
a teal's actual result inside the interval without pretending we knew.

The earlier defect recorded here stands as written: Pete said ship it, and the
reason for holding was never put to him as a decision. It was put to him on
2026-09-12 with the numbers, and he binned it in one line.

### PARTIAL — census back to 2001

> *"lets get census data for all 21st century censuses and their election
> tracts"*

2021 and 2016 done for all six jurisdictions plus federal. 2011 is available
and not started. 2006 and 2001 have no bulk data pack — per-division Excel
only — so they need a different fetcher.

Honestly logged in `docs/NEXT-STEPS.md` already; repeated here so the whole
ask is in one place.

---

## Shipped

| ask | where it landed |
|---|---|
| xgb for preference flows | `AUSPOL_XGB_FLOWS = "1"` |
| xgb for primary vote | `AUSPOL_XGB_PRIMARY_LIVE = "1"`, v6 |
| the primaries x flows 2x2 | `docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md` |
| fit the surge magnitude with xgb.cv rather than argue about n | `scripts/fit_xgb_emergence_v3.R` — tied with pooling, which is the answer |
| use a PREDICTED statewide, not the actual | `AUSPOL_LEVEL_MODE = "pred"` |
| check every step for leakage | two leaks found and removed; audit in the 2026-09-11 commits |
| AEF primary alongside ours in the worst-seats table | `scripts/build_aef_comparison.R`, with a primary-vs-flow verdict per seat |
| find who is running in vic2026 | `scripts/fetch_candidates_vic2026_prenomination.R` |
| update docs, registries, artefacts, html | regenerated 2026-09-11 |
| *"same for polling booths and local elections when we get round to em"* + *"booth level data should scrape it all so we can use in each election"* (2026-10-01) | **Booths: SHIPPED** -- every state's booth results parsed (`output/booths/`); first use is the state notional priors (v57). Per-party booth features (the Senate-style test) **not yet run**. **Local council elections: SHIPPED (v58)** -- every state's council results collected (Vic 2008-24, NSW 2008-24, Qld 2012-24, SA 2018/22, WA 2005-23), matched to state and federal candidates; mayor/councillor/stood-and-lost features in the model. |
| *"Not possible: WA 2013 ... and 2004 and earlier ... can you check this isnt possible by another method"* (2026-10-01) | **SHIPPED** -- 2004 and 1998 Senate booths from AEC archives; WA 2001/2005/2013 mapped by venue name (validated 97.6-98.9%). Senate features then REFUSED on three arms (Victoria worse), told to Pete. |
| *"a mayor should count for more than a councillor -- probably right??? test this"* (2026-10-02) | **SHIPPED (v58)** -- tested: mayors +8.9 under-predicted vs councillors +3.6 (state, independents/minor); `council_mayor` is its own feature. |
| *"check through all the scripts for bottlenecks and optimisations ... 5k sims instead of 20k could be an option"* (2026-10-02) | **SHIPPED** -- fundamentals disk cache, stage 7 single listing (full rebuild 1,247 -> 1,095 s, byte-identical). 5k sims REJECTED (saves 1.5-5 min, inflates log loss via the floor). Biggest remaining lever is free memory (2 vs 6 harness slots), outside auspol. |


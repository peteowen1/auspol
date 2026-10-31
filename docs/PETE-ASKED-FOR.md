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


Closed rows (shipped, answered, or refused and told) live in
[backlog/pete-asked-for-closed-2026-09-11-to-10-19.md](backlog/pete-asked-for-closed-2026-09-11-to-10-19.md),
moved verbatim 2026-10-24. Every row below still has something open.

---

## 2026-10-28

| Request | Status |
|---|---|
| Readiness and value-odds artifact (us against TAB, Sportsbet and Betfair) | **SHIPPED** as a page, https://claude.ai/artifact/GdrpxSB7zkY1xEvJvU3TKx (private). Not in the repo pipeline: built from scratchpad scripts, so it does not refresh itself. |
| Click a seat in that page for its detail; wider table | **IN PROGRESS** 28 Oct. |
| Review the top contested seats (Box Hill, Glen Waverley, Ashwood, Bayswater, Hastings, Narracan, Eureka, Cranbourne): what work would fix them, or research whether they are a problem at all | **REVIEWED, WORK NOT DONE.** `docs/reviews/contested-seats-vic2026-2026-10-28.md` lists the research per seat; none of it is run yet. |
| A "while we wait" skill run automatically during long jobs, via a hook | **SHIPPED** 28 Oct: `~/.claude/skills/while-we-wait/SKILL.md` + `waitNudge()` in `~/.claude/hooks/shell-hooks.js` (global, not in any repo). |
| Live election-night model updating the forecast as booth results come in, learning from AE Forecasts and the NYT Upshot; plan it, build it, put it on the website | **MODEL BUILT, NOT LIVE** 28 Oct (map #148): replay beats the afternoon forecast from 10% counted (0.2643 -> 0.1133). Not yet on the website: page and zoomable maps PUBLISHED 28 Oct, unlisted at inthegame.blog/politics/live (ITG PR #1057); shows the afternoon forecast until night data is uploaded; chart-text fix in review (#162/#163); night runner merged to dev 28 Oct (reviewed twice; tested on the VEC sample feed and the 2022 replay); real feed after VEC access 4 Nov (requested 28 Oct, form + signed terms sent). Upper house designed (`plans/upper-house-night-model.md`), not built. Trial 25 Nov. 29 Oct: break-glass GitHub Actions backup runner merged (auspol #170; dispatch only, live-feed mode not built until VEC SharePoint access), first test pending the night state upload. |
| Surge mixture OFF (31 Oct, on the Wentworth trace: "i thought wed turned off surge as its a bit nonsensical"; he had taken the 17 Oct independent spread, `AUSPOL_COMPOSITION_SD` + `AUSPOL_ERROR_DIST`, to replace it, but `AUSPOL_SALIENCE_SURGE_V2` stayed "1") | **MEASURING** 31 Oct: prereg `plans/prereg-surge-off-2026-10-31.md`; deciding run all 22 at 20k started 1:46pm (`deciding-runs/20261031-1346-surge-off`). |
| Night replays for every AEF-7 election (30 Oct): "when we could've called a win for Labor in 2022 and 25", and "called a win for Allegra in my local seat at what time" | **ANSWERED 31 Oct** from the AEC's real archived night feed (`docs/reviews/night-replay-real-feed-2026-10-31.md`): Labor majority 2025 at 7:30pm, 2022 never on the night (correct, one-seat majority); Spender 2022 at 7:45pm with the three night fixes (never as shipped), 2025 at 7:15pm. The fixes are now on by default in the live runner (commit 1ed44078, on dev, PR pending). State elections replayed on a simulated count only. |
| Live page from his phone (28 Oct, 10:35pm): (1) drop the lab-style A/B/C tab labels, look like the NYT or 538; the needle pointed toward Labor when the Coalition was more likely; (2) the seat-range chart hides the median, and he wants to tap for other percentiles; (3) tapping a booth on the map comes up far too zoomed in | **SHIPPED** 28 Oct 11:14pm (ITG PR #1060, live on inthegame.blog/politics/live): plain tabs (Overview / Race to 45 / Every seat); needle direction fixed (angle was reversed) with likely/leaning bands; one row per party with the median as the big number and tap-for-percentiles; on touch screens booth detail opens in a box under the map, not a popup. The booth fix was tested with a simulated touch screen on desktop, not a real phone; the zoom's cause is a best guess (popup over the map, double tap, iOS focus zoom on the 13.6px picker). Awaiting his check on a real phone. 29 Oct, he reported clicking a booth on a laptop showed nothing: fixed in ITG #1063 (the theme watcher redrew the dots on every mouseup, so the click never fired), checked live with a real mouse click. |
| Booth colours (29 Oct): "Do you colour based on primary or tpp at a booth level? Can we show both in the data?" then "Default should be TPP or tcp winner right not primary winner" | **SHIPPED** 29 Oct (ITG #1068): dots coloured by the booth's two-candidate-preferred winner by default, with a First prefs / Final two switch; every booth's box shows the final two under first preferences (2022 TCP for all 1,729 booths; 224 change colour). Tonight's per-booth counts and final two now flow from the runner (auspol #168, 0.4.115) to the map (ITG #1069). TPP (Labor v Coalition) is not shown: the VEC publishes TCP only, and in 21 of 87 seats the final two were not Labor and Coalition. |
| Live page top (28 Oct, with an NYT Georgia needle screenshot): "nyt needle still looks better than ours", make it on brand; the top of the page is the most important bit, looks boring, needle not centred and does not draw the eye | **SHIPPED** 29 Oct (ITG PR #1062): hero above the tabs on every view; centred seven-band needle (very likely / likely / leaning / tossup each side) with labels in the bands, swings on each update; verdict in party colour in Fraunces; Labor and Coalition chances either side; expected-seats bar with the 45 line. First tab renamed "Seats by party". Checked in Chrome at 1400px light and dark and a 390px frame; not yet on a real phone. |
| Find my seat: type an address and get your district on the live page (28 Oct, on the Esri key: "this sounds great") | **OPEN** (#166): Esri geocoding on the same public key + point-in-polygon on the ABS 2022 boundaries. Not started. |

## 2026-10-26

Rows from the NEXT-STEPS session's 25-26 Oct work, as it reported them (details in `docs/NEXT-STEPS.md`, "Builds
waiting for R"; Claude in the auspol session did not see these requests firsthand).

| Request | Status |
|---|---|
| Seat-poll primaries where a poll reports only two candidates: hunt for the full primaries first, infer only when none exist | **NOT DONE.** Recorded by the NEXT-STEPS session; no branch named. |
| A shrunk new-independent seat-poll bias term | **NOT DONE.** Recorded by the NEXT-STEPS session; no branch named. |
| Federal state breakdowns in the state trend, with 90/180 days out as a second deciding metric | **PREREG ONLY.** Branch `fed-breakdowns-prereg-1026` (45e2bc4, local); the 90/180-day amendment written 27 Oct (6a3d89c7, Amendment 1). |

---

## 2026-10-25

| Request | Status |
|---|---|
| One Nation in seats with no state history: test the live method (rank on the federal House/Senate vote, fitted spread) in every harness, methodology the same for all elections | **BUILT, OFF: screened 25-26 Oct, not shipped.** `AUSPOL_ONP_NEWSEAT_RULE` ("0"), `R/onp_newseat.R`, wired into all seven harnesses; live unchanged at both values. Audit `docs/reviews/onp-newseat-parity-2026-10-25.md`; prereg `docs/plans/prereg-onp-newseat-rule-2026-10-25.md`. Arm A REFUSED (target log loss +0.0007, SE 0.0004); arm B NOT PASSED (-0.0088, SE 0.0090, the whole gain is qld2017; sa2026 clause 4a); B v A +0.0012 (SE 0.0012). So nsw2019, sa2022 and vic2022 still predict One Nation 0 in seats it contested. Told Pete 27 Oct (next-steps session). |
| Returning independents keep their own vote (Mildura: Cupper 33.9 -> 17.6 published via the x0.61 minor-field scale); Pete chose the fitted return rate | **NOT DONE: screening.** `AUSPOL_IND_RETURN` built off (aff86bf), prereg `docs/plans/prereg-ind-return-2026-10-25.md`; A-final REFUSED 25 Oct (d1f1e26); A-base (Amendment 1) REFUSED 25 Oct (primary +0.0058 worse, SE 0.0104; result in the prereg). Told Pete 25 Oct. The cause was live-only (multiplicative minor-field scale): `AUSPOL_MINOR_ADDITIVE` SHIPPED live 25 Oct (Mildura IND 20.2 -> 25.6; `docs/plans/prereg-minor-additive-2026-10-25.md`). Still open: Mildura stays below Cupper's 33.9 because One Nation's allocation takes its share; Benambra (new independent). Not covered: a NEW independent inheriting a movement (Benambra, McKeeman after Hawkins). |
| How do our projections compare to Sportsbet/TAB; add a best-value-bets sheet to the Google Sheet | **DONE 25 Oct.** Tab "Best value bets" in "Vic 2026 seat odds - top 4 outcomes by bookie (24 Oct 2026)" (formulas over the odds tab; our probabilities from the 25 Oct publish in tab "Our probs 25 Oct"). Same favourite in 47 of 59 priced seats. Told Pete the big edges are model-vs-market disagreements, traced in `docs/reviews/market-disagreement-vic2026-2026-10-25.md`. |
| Trace the market disagreements before anyone bets (Niddrie/Essendon/Lara One Nation; Box Hill/Ashwood/Glen Waverley Labor; Bendigo West Nationals) | **TRACED 25 Oct, fixes BUILT, OFF, screening.** One Nation: House-vote seat ranking (`AUSPOL_ONP_ORDER=senate_rank`, `AUSPOL_ONP_NEWSEAT_RULE`); Bendigo West: federal port counted the Nationals' first-time Bendigo campaign (`AUSPOL_SEAT_SWING_PORT_3C`); eastern Labor seats: proportional One Nation fill (`AUSPOL_ONP_FILL=uniform_major`, not recommended on the walk alone). |
| Mildura below Cupper / Benambra's new independent: "can we fix this?" | **ANSWERED 25 Oct.** Cupper is not the sitting member (Benham, Nationals, won 2022). Published 25 Oct: Mildura Nationals 0.68 / One Nation 0.26 / IND 0.06 against the market's 0.61 / 0.26 / 0.11. Benambra's successor keeps 0.41 of Hawkins's vote, inside the past range. Remaining cause found: the surge double count (`AUSPOL_SURGE_LEVEL`, built off, screening; live once the vic2026 salience corpus reaches CI ~2 Nov). |
| Blend the One Nation seat-order keys (Senate, House, previous state) with fitted, shrunk weights rather than throwing the House key away | **NOT BUILT: measured a tie, 25 Oct.** Allocation-only fast check, time-forward weights shrunk to equal, 21 elections / 1,012 seats: blend minus `senate_rank` share RMSE +0.041 pts (SE 0.051), Spearman -0.002 (SE 0.013); six variants (prior strength, fill rule, keys) all tie or lose. House key gets ~1/3 weight and adds nothing measurable. Senate vs old order -1.57 pts (SE 0.43). Seat log loss not measured. Scripts/results in session scratchpad only. Told Pete 25 Oct; recommendation not to build, his call. |
| Sitting-member flags (found during the market trace) | **BUILT, OFF.** `AUSPOL_RETURNING_MEMBER_RULE`: 3 wrong vic2026 flags (Kennedy, Clark, Cupper), 7 missing; needs a candidacies rebuild plus retrain from stage 3 to switch training and live together (Pete's go pending). `docs/reviews/vic2026-sitting-member-audit-2026-10-25.md`. |
| Historical bookmaker odds to test the model against the market | **DONE 24 Oct.** Pete's own scrapes (fed2022, fed2025, sa2022, qld2020) scored: `docs/reviews/backtest-vs-bookmakers-2026-10-24.md` (ca3291f). Ladbrokes fed2019 Vic on Wayback found, not yet scraped. |

## 2026-10-24

| Request | Status |
|---|---|
| Greens over-called in high-Greens seats (Melbourne, Griffith, South Brisbane): pull the tree's Greens share toward base_pred as the Greens base grows; screen with quick_arm on fed2025 + qld2024 | **NOT SHIPPED, told Pete 26 Oct.** Screened all 35: Greens error -0.12 (SE 0.11), seat log loss unchanged, vic2022 +2.5 SE. Traced: the over-call is the trees' incumbency features in three seats (+6-7 pts) plus the base; clustered, the strong Greens MP overshoot is +1.9 (SE 1.8, 12 elections), so neither the shrink nor a Greens-only fix was taken. `docs/reviews/greens-overcall-shap-trace-2026-10-26.md`. |
| TCP margins too close to 50: one stretch factor, time-forward, shrunk toward 1.00 | **NOT DOING (told Pete 24 Oct).** A stretch that keeps every seat on the same side of 50 cannot change who is favoured, so seat log loss cannot move; it would only change displayed margins (`docs/reviews/tcp-compression-investigation-2026-10-24.md`). |
| Other forecasts to compare against, incl. bookmakers: check Sportsbet/TAB/Betfair, and build a shared package for their odds usable in every repo | **PARTLY SHIPPED 24 Oct.** The Swing Is On (88 seats, probabilities), Sportsbet (50) and Betfair (4) added to the 27 Oct+ benchmark snapshot (9e2f210); `C:\dev\oddsdata` built (330b6b6, tests and R CMD check clean). **Open:** TAB (53 seats) is saved by hand each freeze date, because its feed is behind bot protection and is not automated (told Pete 24 Oct); oddsdata pushed to private github.com/peteowen1/oddsdata (dev) 24 Oct. |
| Zero-probability newcomers (7 seats at the 1e-6 floor, Katter 2012): launch prior, a founder or sitting defector carries their personal vote into the new party | **NOT DONE: pre-registering.** Sized -0.003 to -0.005 pooled (`docs/reviews/launch-prior-investigation-2026-10-24.md`). Pete chose 24 Oct: build `AUSPOL_LAUNCH_PRIOR` as a hold-or-fade mixture for sitting defectors (=1) plus sitting members who moved seat (=2). |

## 2026-10-18/19

| Request | Status |
|---|---|
| Review the pipeline for work that gets done and then overwritten | **OPEN (audit 24 Oct):** F8, F10, F12-F19 of the overwrite audit not done. Full history in the backlog file. |
| Look into salience for vic2026 | **OPEN (audit 24 Oct):** vic2026 salience not wired into live forecast; snapshots from ~2 Nov. Full history in the backlog file. |

## 2026-10-16

| Request | Status |
|---|---|

## 2026-10-12

| Request | Status |
|---|---|
| Preferred PM / premier as a poll trend that helps the model (*"we probably should I know it helps in uk and us elections"*) | **OPEN (audit 24 Oct):** drift from months out needs horizon scoring; forecast use refused. Full history in the backlog file. |
| *"remember the end game is to move off AE data so if you have fallbacks to it we need to improve the parser to actually fix whats going wrong"* (also: read the actual poll sources? Poll Bludger? Tally Room?) | **OPEN (audit 24 Oct):** fed2007, fed2010, nsw2019, WA 2001-13 still AE-only; LM extraction not tried. Full history in the backlog file. |
| *"whats our main projects a) full election projections for all since 2010 at last (ideally since 2000) - and conseqiently all polls since then as well which flows to b) our own poll data formation from wiki/pb etc and comparing to AE c) scoping out new states tas/nt/act"* (2026-10-13; Claude to orchestrate with agents/workflows) | **OPEN (audit 24 Oct):** fed2028 live forecast, Tas/ACT polls, 2000-09 state elections, release publish of new elections. Full history in the backlog file. |
| *"have you looked into this? https://demosau.com/news/new-mega-poll-shows-one-nation-losing-ground/ looks super useful ... also we should get a fed election model on the site as well for next fed election (can piggyback off thsi MRP and post about how ours is different to theirs)"* (2026-10-13) | **OPEN (audit 24 Oct):** no federal forecast on site; fed2028 build not done. Full history in the backlog file. |
| *"when i say AE lets call it AEF and AEC so we dont confuse them"* + use AEC (official), get off AEF for flows (2026-10-13) | **OPEN (audit 24 Oct):** AEC official flows not wired to replace AEF preference-estimates in model. Full history in the backlog file. |
| *"we can still do a LOT better on poll weighting stuff and this ties in with our other work"* (re-review the poll-sample worktree) | **OPEN (audit 24 Oct):** sample size and shared-miss weighting not started. Full history in the backlog file. |

## 2026-10-09

| Request | Status |
|---|---|
| Seat polls: weight each poll by sample size, pollster, sponsor, record, recency ("lets look into this") | **OPEN (audit 24 Oct):** pollster track record: AUSPOL_SEAT_POLL_FIRM_FLOOR still "0". Full history in the backlog file. |
| Work through the night handoff queue in order (NSW hidden sections, prebuilt R image, Haiku leftovers, scripts/ in the build) | **OPEN (audit 24 Oct):** blog side: NSW seat pages election switch; (2) left open by Pete. Full history in the backlog file. |

## 2026-10-08

| Request | Status |
|---|---|
| Fix the top primary misses (priority 1, 2026-10-07) | **OPEN (audit 24 Oct):** McMahon/fed2025 seat-poll weight; no pre-election signal found. Full history in the backlog file. |
| NSW 2027 on ITG (priority 2; "go" 2026-10-08, option 1 = one published script) | **OPEN (audit 24 Oct):** NSW seat pages on ITG blog side (data on R2, publish default on). Full history in the backlog file. |

## 2026-10-07

| Request | Status |
|---|---|
| *"https://antonygreen.com.au/nsw2027-how-optional-preferential-voting-could-re-elect-the-minns-government/ <- new NSW state election blog released -- i want you to read through and analyse and compare to our current nsw27 projections (and work towards getting nsw27 in ITG)"* (2026-10-07, flagged for next session) | **OPEN (audit 24 Oct):** NSW 2027 seat pages on ITG blog; analysis done. Full history in the backlog file. |

## 2026-10-05

| Request | Status |
|---|---|
| *"1) sounds good fix 2) salience and seat polls help here lets use them! 3) cool cool 4) yeah look into a fix for this"* (2026-10-05, on the four open items) | **OPEN (audit 24 Oct):** state defector rate: AUSPOL_DEFECTOR_STATE still "0" (prereg pending). Full history in the backlog file. |
| *"is this all still up to date - and the highlighted bit - why is WA special? cant we do it for WA as well (and cant we just use shrinkage ...)"* (2026-10-05, the ITG politics page) | **OPEN (audit 24 Oct):** ITG page hand-typed numbers update UNCONFIRMED; WA port itself published. Full history in the backlog file. |

## 2026-10-03 evening

| Request | Status |
|---|---|
| *"we should update provisional list as we go though! with either ABC data or wiki data or both"* | **OPEN (audit 24 Oct):** LDP (4 rows) class unconfirmed (probably OTH_RIGHT). Full history in the backlog file. |
| *"keep going through the list"* (the four next-steps items) | **OPEN (audit 24 Oct):** Item 1 merged (PR #89); items 2 and 4 status unverifiable, no later mention found. Full history in the backlog file. |

## 2026-10-02/03

| Request | Status |
|---|---|
| *"what are the current biggest misses on the AEF7 ledger ... how can we fix them?"* (2026-10-03) | **OPEN (audit 24 Oct):** Richmond share not re-checked (NEXT-STEPS.md:166); overcalled independents NOT DONE (NEXT-STEPS.md:278). Full history in the backlog file. |


## 2026-09-27

| ask | status |
|---|---|
| *"lets work through all our next steps and get to a point where we're happy having our predictions productionised on the website at ITG"* | **OPEN (audit 24 Oct):** ITG seat map, per-seat cards, forecast-over-time chart still open. Full history in the backlog file. |
| *"weve still got ages of time ... should be improving the model over the next month getting it as good as possible - and just noting improvements made"* | **OPEN (audit 24 Oct):** Standing instruction, no model freeze before 28 Nov. Full history in the backlog file. |
| **Per-candidate model for minor parties and independents** (2026-09-28, chosen over a candidate-count split): *"engineer and think of any and all features ... model can pick whats good ... if we have a good cv setup ... regularization or remove variables ... see what seems to work best"* | **OPEN (audit 24 Oct):** Candidate/bucket split is backtest-only; live vic2026 wiring (fit_minor_candidates.R) pending. Full history in the backlog file. |
| **Seat swing concentration** (2026-09-28, chosen over wider seat uncertainty): v44's worst upsets are a challenging major's primary under-called by 7-17 points in seats it flipped (Parramatta Labor -15.3). Learn from target-seat signals (margin, candidate new/returning, sitting MP retiring, statewide swing direction). | **OPEN (audit 24 Oct):** Seat-specific remainder (Parramatta, Heathcote) still to walk with Pete. Full history in the backlog file. |
| *"shouldnt we still use this [Newspoll quarterly state/demographic breakdowns] in our modelling ... we should scrape all the other stuff and add them into our modelling process and see if they can help improve our metrics"* (2026-09-28) | **OPEN (audit 24 Oct):** Route 2 (federal-in-state) and route 3 (demographic crosstabs over time) not shown as shipped; crosstabs "not shipped" in 579df5c/#87; no told-Pete note found. Full history in the backlog file. |
| *"check whether all our polls are up to date or whether we need to scrape some more - and whether we ended up scraping and using seat level polls - or state level polls in fed polls - or crosstabs in polls to help with demos and state splits ... use as much info as we possibly can"* (2026-09-28) | **OPEN (audit 24 Oct):** Older state breakdowns and DemosAU crosstabs not in model (crosstabs tested, not shipped #87). Full history in the backlog file. |

## 2026-09-20

| ask | status |
|---|---|
| *"work through our worst seats by delta primary now that we know we fully look at forecast not oracle ... update seat registry as you go and keep improving delta primary"* (overnight) | **OPEN (audit 24 Oct):** Standing worst-seats loop. Full history in the backlog file. |

## 2026-09-18/19

| ask | status |
|---|---|
| *"do all three then one combined rerun"* -- how-to-vote cards, by-elections, per-state swing (2026-09-18) | **OPEN (audit 24 Oct):** vic2026 how-to-vote row awaits published cards; pre-2019 by-election windows not fetched. Full history in the backlog file. |
| *"merge PR --- then work through all the next steps ... how is our model looking ... 1) improve the model 2) productionise the model on ITG 3) improve data pipeline and data infra 4) ... live model on the evening of the VIC election"* (2026-09-19) | **OPEN (audit 24 Oct):** Multi-part roadmap (ITG productionise, live election-night model) still running. Full history in the backlog file. |
| *"keep working through all the worst seats ... test theories"* (2026-09-18) | **OPEN (audit 24 Oct):** Standing loop; DEPARTED_ORIGIN closed 27 Oct, not shipped (part 1 NOT PASSED, part 2 not run; Pete agreed; DECISIONS). Full history in the backlog file. |

## 2026-09-15 later

| ask | status |
|---|---|
| *"lets correct/adjust using ALL demo data ... glmnet can help give each one a coefficient right?"* | **BUILT, OFF, and PARKED FOR LATER IMPLEMENTATION at his direction** -- *"i think we're gonna implement this eventually as well just needs a bit more hand holding - so dont remove this we'll get back to it"* (2026-09-15). The code stays wired in all six harnesses behind `AUSPOL_DEMO_RESID=0`; do NOT delete it. All seven census columns under a leave-one-pair-out elastic net, all six harnesses, 22 pairs. Pooled seat log loss 0.2849 -> 0.2831 (-0.0018, t = -1.83, binomial p = 0.143). REFUSED on the pre-registered condition that qld2024 must not worsen; it worsened +0.0024, which the permutation control puts ~27 SDs outside the null. `docs/plans/prereg-demographic-axis-2026-09-15.md`. |
| **his diagnosis: "demographics voting a certain way will change over time - we need to try and track that - using polling and using elections"** | **OPEN (audit 24 Oct):** Time-varying demographics (tracking via polling/elections) not built. Full history in the backlog file. |
| **his ask: seat-seat correlation in the simulation -- "if two regions with very similar demographics, if one of them swings to ONP then the other one is way more likely too"** | **PARKED AT HIS DIRECTION, not refused.** 2026-09-15: I measured that the live forecast already carries roughly the right AVERAGE correlation (ONP rho = 0.057 against an empirical 0.06, so the seat-count spread moves 1.02x) and wrote it up as "not worth building". He disagreed: *"i dont agree with this its definitely worth building - but happy to park for now until i have the time to hand hold you through it"*. He is right that the average is not the question -- the STRUCTURE is, and correlation that is uniform across all seat pairs is wrong even when its mean is correct. Inputs are measured and ready: geographic distance -0.0612 (30 of 30 clusters), historical swing correlation +0.0657, demographic distance -0.0337. `docs/reviews/seat-correlation-gap-2026-09-15.md`. Resumes when he has time to direct it. |

## Census back to 2001

> *"lets get census data for all 21st century censuses and their election
> tracts"*

**OPEN (audit 24 Oct):** 2021, 2016, 2011 and 2006 built (`scripts/build_census_features_vintage.R`,
`docs/reviews/census-vintage-build-2026-10-13.md`). 2001 is absent: no bulk data pack, so wa2001 and
wa2005 carry no census on purpose.

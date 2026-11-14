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

## 2026-11-13

| Request | Status |
|---|---|
| Check the AusPoll X feed so every election poll it posts is in our data; make it a skill; name prominent Australian election analysts on X | **DONE 13 Nov.** 23 of 26 AusPoll polls in the anchor; Pakenham hand-keyed since 10 Nov; the Greens' ORU poll in via our Wikipedia layer. Found and fixed Lighthouse's Vic poll counted twice (PR #234, live 13 Nov). Skill `poll-feed-check` (~/.claude/skills). Handles: @AntonyGreenElec, @PollBludger, @kevinbonham, @benraue, @GhostWhoVotes, @AusPoll6. |
| Party-paid polls: "test it first, shrinkage or better method, don't just add as is"; Pete chose noise + lean toward the sponsor | **SHIPPING 13 Nov** (`AUSPOL_PAID_POLL_CORRECT=1`, `plans/prereg-paid-poll-correction-2026-11-13.md`): lean learned from same-time independent polls, none detectable yet (+0.24, SE 0.55, shrunk to ~0); paid polls count x0.64. Placebo 18/20; 38 elections unchanged; first scorable on vic2026. |
| Two independents counted separately ON THE NIGHT (14 Nov, Pete chose "Build and test it" after the Monash walk: Leonard + Broadbent run as one IND) | **IN PROGRESS 14 Nov.** Night-only split from counted figures, off (`night_run_update(class_split = ...)`, `plans/prereg-night-class-split-2026-11-14.md`). fed2025 test: Monash Liberal at 8pm 0.046 -> 0.654. Three-night replay job running (`deciding-runs/20261114-1500-night-class-split`); comes back to Pete before shipping. |
| Same request, SEAT polls (14 Nov, Pete chose "Build it"): paid seat polls overstate the sponsor's side +3.0 points net of independent seat polls (29 polls, SE 0.92) | **SHIPPING 14 Nov** (Pete: "build it as predictive as possible", then "Build per-side, ship live"): `AUSPOL_SEAT_POLL_PAID_LEAN=1`, `plans/prereg-seat-paid-lean-2026-11-14.md`. Each side shrunk to zero on its own; placebo 18/20. Told Pete it cannot be validated time-forward until vic2026 (no earlier Coalition or Climate 200 paid polls). Live: Hawthorn's paid poll Liberals 41 -> 37.7 only. |

## 2026-11-07

| Request | Status |
|---|---|
| Where we lose to AEF on AEF-7: seat polls, salience, calibration and bias for independents, Greens and the confident wrong major seats; what is fixable | **ANSWERED in chat 7 Nov, nothing to ship.** Widening IND/GRN contests refused (proxy, and C2 17 Oct); salience bias on unpolled IND weak (+2.3 mid band, SE 1.3); by-election weight fitted 0.62 (SE 0.11), 0.5 stands. NEXT-STEPS item "AEF-7 gap diagnosis". |
| Spin up an agent to get our two-candidate-preferred MAE (3.68, n 610) below AEF's (3.63, n 600) | **SHIPPED 7-8 Nov: below AEF on the same seats, ours 3.660 vs AEF 3.727 (n 667, published 8 Nov 9:02am, leak-free).** 8 Nov also shipped: measured NSW exhaust for minor parties, and seat flow persistence for fed2025's gap (Pete override; fed2022/25 TCP -0.12 each). NSW exhaustion published 11:25pm; the ledger headline now scores both sides on the same seats (Pete asked, 7 Nov; page republish pending). History: `reviews/tcp-mae-vs-aef-2026-11-07.md`: a tie on common seats (3.62 vs 3.59, n 583), ahead on the real final two (3.722 vs 3.733, n 657); loss is nsw2023 + fed2025. Arm `AUSPOL_NSW_EXHAUST=1` (the anchoring half is inert under the live recipe) screened 7 Nov: nsw2023 TCP MAE -0.345 (SE 0.171, 79 seats), nsw2019 -0.560, seat log loss better on both; every guard passes (`plans/prereg-nsw-exhaust-tcp-2026-11-07.md`); 20k log loss 0.2618 -> 0.2566. Left: fed2025, and 5 new nsw2023 seats missing from the TCP reference. |

## 2026-11-06

| Request | Status |
|---|---|
| Biggest AEF-7 misses, why, and keep digging; research Coalition how-to-vote card order and build the data | **IN PROGRESS.** Card order: `external/reference/htv/coalition-card-order-researched.csv` (36 elections), SHIPPED 6 Nov (`AUSPOL_HTV_TABLE=researched`; on main via PR #201). Traced: Melbourne, Fowler, Hughes, Forde, Dickson, Griffith, Ryan, Shepparton (`SEAT-REGISTRY.md`). `AUSPOL_LEADER_BEFORE_BLEND` SHIPPED 7 Nov (20k held; reaches the ledger at the next rebuild). |
| Two candidates of one minor class counted separately (walked Morphett, Waite, Monash, Calwell; chose "Split now", newcomer under-call a separate item) | **BUILT, OFF, refused twice 6 Nov (also on the better `sal` predictions: +0.0016, SE 0.0011; helps the 1,560 seats someone else won, costs the 35 the class won; told Pete in chat).** `AUSPOL_CLASS_SPLIT` (`R/class_split.R`, 4d765927); prereg `plans/prereg-class-split-2026-11-06.md`; screen of all 35 elections launched 2:17pm. Does not reach the live forecast until vic2026 per-candidate predictions exist. |
| The per-candidate model gives a newcomer independent the generic 4-8% beside a sitting member | **BUILT, OFF (`AUSPOL_MC_EXTRA=sal`): independents' RMSE 7.86 -> 7.57; newcomers on 10%+ predicted 10%+: 30 -> 78 of 281; Holmes-Ross and Jones unmoved.** 7 Nov 1am, told Pete: no route to the forecast helps. The shipped bucket split reads the naive column, which sal never touches; switching the split to sal's residual column is a seat tie and shares 2% worse (35 elections, 1,000 sims). Still open: the newcomer under-call itself. Queued in NEXT-STEPS; table in `reviews/two-candidates-one-class-2026-11-06.md`. |

## 2026-11-05

| Request | Status |
|---|---|
| *"tau^2 toward the pooled slope"* for the major departed-member slope (27 Oct; option B, tau^2 from earlier elections' party gaps, "go" 5 Nov) | **OPEN, built and screening:** arm `AUSPOL_DEPARTED_POOL` (default off), `plans/prereg-departed-slope-pool-2026-11-05.md`. Amendment 1 (af3c68db). Deciding run DONE 6 Nov 2:59am: all 35 elections -0.0020 (SE 0.0015), the eight targets -0.0081 (SE 0.0052), PASS; the "no election worse by 2 SE" guard fails on noise-sized moves (nsw2015 +0.0011, qld2024 +0.00004). SHIPPED 6 Nov (Pete, clause override; `AUSPOL_DEPARTED_POOL="1"`, 0.4.137). Reaches the published numbers at the next full rebuild. |
| Departed-rate refit fitted only on cells the successor table does not name, fallback 0.38, standard rule decides (29 Oct answers) | **NOT SHIPPING, told Pete 5 Nov:** built (branch `departed-rate-fit-1105`, WA and NT wired too) and screened on AEF-7: +0.0001 seat log loss (SE 0.0003), four of seven elections worse; not shown at the screen, so no deciding run. `plans/prereg-departed-rate-screen-2026-10-25.md` RESULT. |
| Swap the email in the fetchers' User-Agent for the repo URL | **SHIPPED** (PR #188). |
| Narracan booth history on election night from 2018 booths | **SHIPPED** for the runner (PR #189) and the page's pre-count map (ITG #1142, merged 5 Nov 2:42pm; Narracan booths show their 2018 result, labelled 2018). OPEN, 10 Nov: browser check at 390/1280 px. |

## 2026-10-28

| Request | Status |
|---|---|
| Readiness and value-odds artifact (us against TAB, Sportsbet and Betfair) | **SHIPPED** as a page, https://claude.ai/artifact/GdrpxSB7zkY1xEvJvU3TKx (private). Not in the repo pipeline: built from scratchpad scripts, so it does not refresh itself. |
| Click a seat in that page for its detail; wider table | **IN PROGRESS** 28 Oct. |
| Review the top contested seats (Box Hill, Glen Waverley, Ashwood, Bayswater, Hastings, Narracan, Eureka, Cranbourne): what work would fix them, or research whether they are a problem at all | **REVIEWED, WORK NOT DONE.** `docs/reviews/contested-seats-vic2026-2026-10-28.md` lists the research per seat; none of it is run yet. |
| A "while we wait" skill run automatically during long jobs, via a hook | **SHIPPED** 28 Oct: `~/.claude/skills/while-we-wait/SKILL.md` + `waitNudge()` in `~/.claude/hooks/shell-hooks.js` (global, not in any repo). |
| Live election-night model updating the forecast as booth results come in, learning from AE Forecasts and the NYT Upshot; plan it, build it, put it on the website | **MODEL BUILT, NOT LIVE** 28 Oct (map #148): replay beats the afternoon forecast from 10% counted (0.2643 -> 0.1133). Not yet on the website: page and zoomable maps PUBLISHED 28 Oct, unlisted at inthegame.blog/politics/live (ITG PR #1057); shows the afternoon forecast until night data is uploaded; chart-text fix in review (#162/#163); night runner merged to dev 28 Oct (reviewed twice; tested on the VEC sample feed and the 2022 replay); real feed after VEC access 4 Nov (requested 28 Oct, form + signed terms sent). Upper house designed (`plans/upper-house-night-model.md`), not built. Trial 25 Nov. 29 Oct: break-glass GitHub Actions backup runner merged (auspol #170; dispatch only, live-feed mode not built until VEC SharePoint access), first test pending the night state upload. |
| Surge mixture OFF (31 Oct, on the Wentworth trace: "i thought wed turned off surge as its a bit nonsensical"; he had taken the 17 Oct independent spread, `AUSPOL_COMPOSITION_SD` + `AUSPOL_ERROR_DIST`, to replace it, but `AUSPOL_SALIENCE_SURGE_V2` stayed "1") | **SHIPPED 31 Oct** (`published_flags.R` "0"; 35 elections +0.0002, SE 0.0028; DECISIONS 2026-10-31). |
| Victorian Liberal card (31 Oct): "Put a probability on it? Odds of Labor above greens? Add that to sim - then yeah can turn to 100% once you have the new info"; and weight recent elections in the Greens-last flow | **SHIPPED, live 1 Nov 8:38am** (PR #181 card `vic=0.67`, PR #182 recency HL 8): published forecast Labor 29.6 -> 29.37, Greens 6.2 -> 6.48 seats. Trigger: add the vic2026 card row when the Liberals publish it. |
| Polls on the site (31 Oct): "we should have a latest polls part to the site so we know what polls are in the model"; and "all these polls are in the model right?" | **SHIPPED 1 Nov**: every Wikipedia poll is in the model (Roy Morgan 8-9 Oct via our layer); the release's polls-vic-snapshot.csv lists the polls the run read with Source (live 8:38am, 17 ours-only); 'Polls in the model' table on the site (inthegame-blog PR #1106, merged 8:12am). |
| Vic 2026 Edge Board vs Sportsbet (31 Oct) | **SHIPPED** (artifact): https://claude.ai/artifact/8U33eGJMiAbpZFSW2dsfQu. Government-formation bug fixed (bloc rule, Pete's One Nation point); rebuilt 1 Nov 12:15am on the same poll inputs as the live site (local run reproduces it: ONP 16.56 vs 16.6). Sportsbet read 11:10pm Sat 31 Oct; not auto-refreshing. 1 Nov 12:25pm, Pete asked: "more filters like min/max prob for us or min/max odds", "click on a row to see that seat's info", "links to the sportsbet market and to the seat or site": SHIPPED (our-probability from/to filters, odds filters relabelled, Links column with Sportsbet market + inthegame.blog seat page, click a seat row for a panel: final two, every party's win probability, primary with 90% range, 2022 primary, every Sportsbet price in the seat; panel data = the live published forecast). Builder still scratch-only, see NEXT-STEPS. |
| Box Hill middle version (1 Nov: "Test a middle version" of the One Nation fill) | **ANSWERED 1 Nov, not shipped**: the fill is live-only so no 35-election backtest; on the 4 past surges the pooled proportional coefficient is -0.97 (SE 0.13) for Labor (-1 = shipped fill, middle ~ -0.5). Proportional kept. `reviews/boxhill-trace-2026-11-01.md`. |
| A better independent surge (31 Oct): "should surely only target unknown independents that have good salience or seat polling data" -- not sitting MPs (Spender 2025 had a 19% surge to 69.3) | **NOT SHIPPING, Pete's call 4 Nov (kept off; DECISIONS 2026-11-04)** (existing breakout mixture limited to new independents, ungated and gated p>=0.05: independent-won seats better, everything else slightly worse, net within noise and AEF-7 worse; recommended not shipping; told in chat 1 Nov). Earlier: DESIGN CHOSEN 1 Nov: walked the cases with Pete (Goldstein, Noosa, Mayo, Johnston); he chose the evidence-tiered breakout for new independents only (search rise ~14% vs 2.2% base, sitting members untouched). Rule and decision criteria fixed in `plans/prereg-new-ind-breakout-2026-11-01.md` before any build. |
| Night replays for every AEF-7 election (30 Oct): "when we could've called a win for Labor in 2022 and 25", and "called a win for Allegra in my local seat at what time" | **ANSWERED 31 Oct** from the AEC's real archived night feed (`docs/reviews/night-replay-real-feed-2026-10-31.md`): Labor majority 2025 at 7:30pm, 2022 never on the night (correct, one-seat majority); Spender 2022 at 7:45pm with the three night fixes (never as shipped), 2025 at 7:15pm. The fixes are now on by default in the live runner (commit 1ed44078, merged to main; checked 5 Nov). State elections replayed on a simulated count only. |
| Live page from his phone (28 Oct, 10:35pm): (1) drop the lab-style A/B/C tab labels, look like the NYT or 538; the needle pointed toward Labor when the Coalition was more likely; (2) the seat-range chart hides the median, and he wants to tap for other percentiles; (3) tapping a booth on the map comes up far too zoomed in | **SHIPPED** 28 Oct 11:14pm (ITG PR #1060, live on inthegame.blog/politics/live): plain tabs (Overview / Race to 45 / Every seat); needle direction fixed (angle was reversed) with likely/leaning bands; one row per party with the median as the big number and tap-for-percentiles; on touch screens booth detail opens in a box under the map, not a popup. The booth fix was tested with a simulated touch screen on desktop, not a real phone; the zoom's cause is a best guess (popup over the map, double tap, iOS focus zoom on the 13.6px picker). Awaiting his check on a real phone. 29 Oct, he reported clicking a booth on a laptop showed nothing: fixed in ITG #1063 (the theme watcher redrew the dots on every mouseup, so the click never fired), checked live with a real mouse click. |
| Booth colours (29 Oct): "Do you colour based on primary or tpp at a booth level? Can we show both in the data?" then "Default should be TPP or tcp winner right not primary winner" | **SHIPPED** 29 Oct (ITG #1068): dots coloured by the booth's two-candidate-preferred winner by default, with a First prefs / Final two switch; every booth's box shows the final two under first preferences (2022 TCP for all 1,729 booths; 224 change colour). Tonight's per-booth counts and final two now flow from the runner (auspol #168, 0.4.115) to the map (ITG #1069). TPP (Labor v Coalition) is not shown: the VEC publishes TCP only, and in 21 of 87 seats the final two were not Labor and Coalition. |
| Live page top (28 Oct, with an NYT Georgia needle screenshot): "nyt needle still looks better than ours", make it on brand; the top of the page is the most important bit, looks boring, needle not centred and does not draw the eye | **SHIPPED** 29 Oct (ITG PR #1062): hero above the tabs on every view; centred seven-band needle (very likely / likely / leaning / tossup each side) with labels in the bands, swings on each update; verdict in party colour in Fraunces; Labor and Coalition chances either side; expected-seats bar with the 45 line. First tab renamed "Seats by party". Checked in Chrome at 1400px light and dark and a 390px frame; not yet on a real phone. |
| Find my seat: type an address and get your district on the live page (28 Oct, on the Esri key: "this sounds great") | **LIVE 5 Nov 5:28pm** on inthegame.blog/politics/live (#166; ITG PR #1144 dev, #1147 main) (Esri geocoding on the same key, biased to Victoria; point-in-polygon on the map's boundaries; out-of-state, no-match, suburb-only and near-boundary messages; 10 lookups per page load). 5 Nov evening, after Pete's laptop and phone tests: CSP fix (#1149), location bias removed (#1151), suggestions as you type (#1152, live 6:55pm). Pete checked it on his phone 5 Nov 7:09pm; #166 closed. |

## 2026-10-26

Rows from the NEXT-STEPS session's 25-26 Oct work, as it reported them (details in `docs/NEXT-STEPS.md`, "Builds
waiting for R"; Claude in the auspol session did not see these requests firsthand).

| Request | Status |
|---|---|
| Seat-poll primaries where a poll reports only two candidates: hunt for the full primaries first, infer only when none exist | **NOT DONE.** Recorded by the NEXT-STEPS session; no branch named. |
| A shrunk new-independent seat-poll bias term | **NOT DONE.** Recorded by the NEXT-STEPS session; no branch named. |
| Federal state breakdowns in the state trend, with 90/180 days out as a second deciding metric | **NOT SHIPPING, Pete's call 5 Nov (told in chat):** built off by default (`AUSPOL_TREND_FED_R`, branch `fed-breakdowns-trend-1105`, 704 breakdowns incl. BludgerTrack to 25 Oct) and screened on 7 elections: B1 FAIL, B2/B3 TIE (day before -0.003, SE 0.008; 90/180 days +0.008, SE 0.009; fitted weight 0 wherever fittable). Review `reviews/fed-breakdowns-trend-screen-2026-11-05.md` on the branch. |

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
| Sitting-member flags (found during the market trace) | **SHIPPED 26 Oct** (Pete: GO after the by-election name checks, 106 of 108 match): `AUSPOL_RETURNING_MEMBER_RULE` "1" in `scripts/published_flags.R:622`. `docs/reviews/vic2026-sitting-member-audit-2026-10-25.md`. |
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
| Look into salience for vic2026 | **SHIPPED 13 Nov** (PR #230, stage 9 9:23am `PRS1 ... 663 vic2026 rows, snapshot to 2026-11-11`; daily run 9:25am green, `XG5 salience corpus found for vic2026: 526 of 616 seat-classes matched`; published Hawthorn IND 0.406, Benambra IND 0.376). Rank-mapped (his choice 12 Nov). The coarse anchor scale is fixed: the ladder link SHIPPED 13 Nov (Pete: "Ship it"; PR #231, stage 9 2:59pm `PRS1 ... 685 vic2026 rows`; forecast run 3:34pm green, `XG5 ... 546 of 616`; published Cranbourne ALP 0.682, Essendon IND 0.398). The DS3b blend stays off with surge-v2 (off since 31 Oct), by design. Full history in the backlog file. |

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
| Treat polls differently by type, company and age (1 Nov): *"we 100% should be treating different polls differently based on the poll type and company and how old it is"*; he had assumed we already did | **NOT SHIPPING, told Pete 4 Nov: all 6 arms built and REFUSED on 38 elections** (anchor strength, company lean against results, One Nation in the recent-poll blend 2 Nov; sponsor +0.055 (SE 0.020), method +0.024 (SE 0.016), all together +0.012 (SE 0.029) 4 Nov). Why: a company's, sponsor's or method's lean at past elections does not carry to the next; One Nation's over-statement is shared by every firm, so no lean term sees it. Reopens: sponsor after vic2026 (first completed election with party-commissioned polls labelled); One Nation anchor conditioned on seats contested after 9 Nov nominations (`plans/prereg-poll-lean-2026-11-02.md`). Told 1 Nov the trend had no house effects: WRONG, corrected to Pete 2 Nov (it fits within-cycle house effects). Noise-only weights refused 9 Oct. |
| *"we can still do a LOT better on poll weighting stuff and this ties in with our other work"* (re-review the poll-sample worktree) | **OPEN (audit 24 Oct):** sample size and shared-miss weighting not started. Full history in the backlog file. |

## 2026-10-09

| Request | Status |
|---|---|
| Seat polls: weight each poll by sample size, pollster, sponsor, record, recency ("lets look into this") | **PARKED, told Pete 5 Nov:** seat-poll arms S, T and U all refused, and any per-pollster or per-method weight would be fitted on one or two earlier polled elections, too few to learn a firm's record. `AUSPOL_SEAT_POLL_FIRM_FLOOR` stays "0". Resumes when a source adds earlier polled elections (NEXT-STEPS "Seat polls: PARKED"). Full history in the backlog file. |
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
| **Per-candidate model for minor parties and independents** (2026-09-28, chosen over a candidate-count split): *"engineer and think of any and all features ... model can pick whats good ... if we have a good cv setup ... regularization or remove variables ... see what seems to work best"* | **SHIPPED 10 Nov (live bucket split):** vic2026's unpolled bucket is now split by the per-candidate model on the VEC final list (IND 0.27, OTH_RIGHT 0.24, OTH 0.50; PR #217; walked first: no favourite changed, max move 0.4 points). The per-candidate CLASS split (each class's own share per seat) stays off (`AUSPOL_CLASS_SPLIT`, refused twice, closed by Pete 6 Nov). Full history in the backlog file. |
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
| **9 Nov: first-time independents -- "where in our forecast pipeline we can make adjustments" for seat polls, Climate 200, Voices, councillors, search (and "how much influence does each have ... how much bias reduction and calibration can we still get")** | **IN FLIGHT.** Answered in chat with the influence (SHAP) and bias tables and a six-lever map (`docs/reviews/newcomer-independents-walk-2026-11-09.md`). Lever 1 (signal-aware new-IND shrink, `AUSPOL_NEW_IND_SHRINK_SIGNAL`) REFUSED twice, told Pete 9 Nov. Lever 2 (`AUSPOL_NEW_IND_LIFT`, additive lift fitted on published shares) SHIPPED 9 Nov (PR #211). Remaining: spread signal term, council data gaps. Betting odds as an input: asked, he leans no, NOT decided. |
| **11 Nov ~7pm: pollster pages. "does demos not have a pollsters record ... each pollster should have their own page where you can see their history and stats etc - and we should say what their influence is in the model (do they have a weight or a bias adjustment?)"** | **NOT BUILT.** Answered in chat 11 Nov: DemosAU is in `output/pollster-scorecard.csv` (31 polls, 1 election, final error 3.22, leans 1.4 Coalition) but the page shows only the top 12 by poll count (`build_trend_page_data.R:77`). Model influence: equal weight; a within-cycle house effect (shrunk, centred) is removed; no track-record adjustment (refused 9 Oct). DATA SIDE BUILT 11 Nov (93ab0880): record table now lists all 19 (with page slugs); `output/pollster-pages.json` (46 pollsters: stats, finals, house effect by cycle, polls, and what the published trend does per live election), uploaded to R2 by the daily forecast from the next run. PAGES NOT BUILT: brief sent to the ITG session 11 Nov. |
| **11 Nov 11:14pm (typed in the ITG session, relayed): party pages. "can we have party pages as well? see how each party did in each election (state parties are different so its NSW labor, SA labor, Federal Labor etc)"** | **NOT BUILT.** Same split as the pollster pages: auspol builds `output/party-pages.json` (one page per party and jurisdiction; per election first preferences, change, seats, two-party-preferred, government, our backtest forecast; live forecast for vic2026/nsw2027), ITG builds the pages. DATA SIDE BUILT 11 Nov: `scripts/build_party_pages.R` -> `output/party-pages.json` (32 party pages over 7 jurisdictions, 189 party-elections from 42 elections, 156 with our backtest, live trend for vic2026/nsw2027), uploaded to R2 by the forecast run once on main. PAGES NOT BUILT (ITG). |
| **11 Nov 12:05am: election-night wrong calls, "can we fix these seats?" (Melbourne, Monash 2025; Mirani 2024)** | **PARTLY.** v2 `pair_cal` PASSED its prereg 11 Nov and is the live night default (`plans/prereg-night-pair-cal-2026-11-11.md` RESULT). **Monash is NOT fixed by it**: the Liberal goes 0.026 -> 0.061 at 7pm and 0.006 -> 0.046 at 8pm, and still ends near 0.005, because the model gave the real pair ~0 and the fit only trusts the AEC that far. Pete to be told this in a message. Melbourne: told it is the AEC's own pair being wrong plus a flow error, not this fix. Mirani (11 Nov): traced. Party-code bug fixed (counted pair now used); still wrong at full count from the postal/absent lean by party class (Andrew changed party); Pete chose 11 Nov: a returning candidate keeps their OWN late-vote lean. BUILT and tested both ways 11 Nov: FAILED (Monash 2025 much worse, fed2025 +0.013 all seats); stays OFF. Mirani NOT fixed. Told in chat 11 Nov. Pete then chose (11 Nov) to BUILD the 'copy' version (keep the party's history, add the candidate's own pattern), knowing its only clean test is a future real night. BUILT, PASSED its prereg 11 Nov (weak evidence), OFF; Mirani still wrong at full count. Pete chose 11 Nov: ON for the 28 Nov night IF the 2026 list has same-seat party switchers (wire into the VEC website reader). |

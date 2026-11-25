# Decisions

One line each: the decision, the one fact behind it, a link. Newest first.
Created 2026-09-19 (the verse convention; auspol had none). Older decisions
live in the plans they came from (`docs/plans/prereg-*.md` RESULT sections).

- **2026-11-25 Former leaders' seats (Mulgrave, Bulleen): correction built, kept OFF (`AUSPOL_LEADER_FORMER=0`).** The old leader's party is over-called (+2.30 points, SE 0.99, 33 seats), but the cut's freed points raise the other parties' error by as much: all-cell squared error +0.2 (SE 87.7), seat log loss +0.00028; no variant (7 tried, safety-scaled included) beats it, held-out 2024-26 slightly worse. Pete: "surely we can find a version that improves RMSE" -> searched, none. `plans/prereg-leader-former-2026-11-25.md`, `-rmse-` on branch seat-quick-screen. Rescore on vic2026.
- **2026-11-25 Regional seat correlation built, kept OFF (`AUSPOL_SEAT_CLUSTER_COR=0`, branch seat-corr-regions).** Seat-total log score 1.8792 -> 1.8761 (-0.0031, SE 0.0147, 195 cells, 35 elections); vic2026 majority 0.298 -> 0.296: the statewide draw already sets the spread. `plans/prereg-seat-cluster-cor-2026-11-25.md` (branch).
- **2026-11-25 100,000 simulations every run, scenarios too; night state stays 20,000 (Pete: "Yes, 100k daily").** Trial run 45516620755: forecast job +2 min 14 s. PR #277, #279, #280; the independents step cached across scenarios, PR #281.
- **2026-11-25 November YouGov MRP: only Bendigo East entered (Pete chose the statewide anchor), the tweet's region swings NOT used (Pete: no source).** Only 2 seats public; Mulgrave has no primaries. Table uploaded 11:30am (md5 de6b7c33). `deciding-runs/20261125-nov-mrp/`.
- **2026-11-24 What-if two-party figure shown with BOTH One Nation splits and a toggle (Pete: "both with a toggle?").** Blended past flows (33.7% to Labor, Labor 47.3) and the flow table's own row for this election (25.5%, Labor 45.3). Which is the default is NOT decided; my suggestion to ITG was latest measured first. `scripts/build_whatif_sims.R`.
- **2026-11-24 Upper house: preferences assumed, and it barely matters in total.** Four preference rules, from none to strong blocs, move no party by more than 0.2 of 40 seats (`plans/upper-house-forecast-walk-2026-11-24/sim-output.txt` section 4). Not published; Pete read the region tables and said they look good.
- **2026-11-24 Early-share Labor correction SHIPPING for Saturday (Pete chose "Ship for Saturday" after the live walk).** `AUSPOL_DEMO_RESID_EARLY="1"`: Labor's primary shifted by a time-forward slope on the PREVIOUS election's early-vote share by seat, beside the census correction. Prereg passed on 16 elections against a shuffled placebo (Labor squared error -0.258, SE 0.096; seat log loss 0.2279 -> 0.2269); live: average seat 0.33 points, Ringwood's favourite flips, hung 67.8% -> 68.2%. `plans/prereg-early-share-labor-2026-11-24.md`. Supersedes the row below for this one feature
- **2026-11-24 Early-vote data NOT used in the forecast; parked until after polling day (Pete chose "Stop here, park it").** This election's early or postal surge, vote-type mix, demographic surprise and daily shape: no signal on 22 elections (`scripts/screen_early_vote.R`). LAST election's early share by seat does track our Labor miss (-2.4% of squared miss time-forward, both holdouts better), but as an xgb feature it is not separable from a shuffled placebo (Labor RMSE 5.379 -> 5.356, placebo 5.366). `PETE-ASKED-FOR.md` 2026-11-24
- **2026-11-24 Seat odds on the site, with edges but NO stakes (Pete chose "Seat odds + edges, no stakes").** https://inthegame.blog/politics/vic2026/odds (inthegame-blog#1294): every source side by side plus an edge column; no Kelly, bankroll or stake columns, because a public page sizing bets reads as gambling promotion. Prices covering only part of a group (Ripon Liberal/Nationals, Hawthorn and Kew named independents) show no edge. Data `scripts/build_seat_odds_json.R`, all columns frozen at one capture.
- **2026-11-24 Election pages carry the year in the URL, moved before polling day (Pete chose "Move everything now" over after the result).** `politics/vic2026/` (forecast, odds, seat, live), `politics/nsw2027/`; `politics/vic` and `nsw` 302 to the latest, old paths 301 (inthegame-blog#1295, live 12:50pm, all 20 old URLs checked on prod). Past elections go beside them later (not started).
- **2026-11-24 One Nation flow keys from the history rate REFUSED; live flows unchanged (Pete chose "build targeted fix today").** The per-seat flow trees lean toward One Nation (Labor between Liberal and One Nation 55% to Liberal live, 63-72% measured, Ripon's Labor card puts One Nation last), but both arms were worse on sa2026 (+0.0128 / +0.0082 seat log loss), losing the seats One Nation won; pooled +0.0004 (SE 0.0003) / +0.0001. Likely the lean offsets under-called One Nation primaries (MacKillop -11.4, Narungga -8.8). `plans/prereg-onp-flow-keys-2026-11-24.md`.
- **2026-11-24 Night backup slowed to fit the VEC site's limit (PR #273, on `main` 3:07am).** A GitHub runner gets 110-124 of 174 pages per window, then HTTP 999 (runs 45179140374, 45189369953). Backup now parallel 1, every 300 s, refetches missing pages after `--retry-pause` 120 s x 6, cools down only on a wholesale refusal (`VWF7!`); laptop unchanged. Rehearsal run 45199291224: 4 of 4 snapshots uploaded to the test key, but no refusals occurred, so the retry path is proven only on a local mimic. Archives: `deciding-runs/20261123-mrp-pattern/rehearsal*`.
- **2026-11-23 Live 10:35pm with the MRP seat pattern (run 45162697096).** Expected seats vs 5:37pm: Coalition 39.9 -> 40.9, Labor 25.9 -> 24.8, One Nation 15.4 -> 15.3, Greens 6.6; Coalition majority 35%. Confounded with the 6-23 Nov YouGov statewide poll (ALP 20, L/NP 31) entering through the Wikipedia layer in the same run; the isolated local walk put the MRP change alone at Coalition +0.7, Labor -0.9. Blend step moved party averages under 0.1 points, so the seat deviations were anchored, not blended as levels.
- **2026-11-23 MRP seat pattern SHIPPED on the 7-election screen (Pete chose "ship now" over the 35-election run).** `AUSPOL_SEAT_POLL_MRP_PATTERN="1"`: each MRP release re-centred on our level (moves seats only relative to each other), MRP polls on their own fitted half-life (vic2026 37 days; other polls 64, were 21 for all), and YouGov's July Victorian MRP (88 seats, gitignored `mrp_extra.csv`) read. Stage 0: a fed2025 release's pattern still predicts at 140+ days (slope 0.17, SE 0.04). AEF-7 seat log loss 0.2526 -> 0.2421 (SE 0.0101; fed2025 -0.049, fed2022 +0.003). Live: no favourite changes; expected seats LNP +0.7, ALP -0.9, ONP +0.2. Shipped by re-promoting only `seat-poll-blend-vic2026.csv` (built from arm m's inputs; arm-off control byte-identical to the shipped asset). `plans/prereg-mrp-seat-pattern-2026-11-23.md`.
- **2026-11-23 Live 5:37pm on the modelled One Nation allocation (run 45124028734).** Runner fit identical to the laptop (16 elections, Senate 0.577, Year 12 -0.095). Expected seats vs 9:30am: Coalition 40.6 -> 39.9, Labor 24.2 -> 25.9, One Nation 16.3 -> 15.4; 8 favourites changed. The first rerun failed for want of four tables the model fits on (PR #270 ships them); the site kept 9:30am until then.
- **2026-11-23 One Nation modelled allocation SHIPPED on Pete's override of its refusal (below).** "cool lets ship this --- i dont like the rank rule really." `AUSPOL_ONP_ALLOC="model"`, `AUSPOL_ONP_IN_TRAINING="1"`, arm m's trees. Measured: not reliably better (cells -1.4%, SE 2.7%; seat log loss +0.0004, SE 0.0007). Plan Amendment 3.
- **2026-11-23 One Nation modelled allocation REFUSED on its fair test; the rank rule stays for the election.** Trees trained on the model: squared error on One Nation's moved cells -138.5 of 9644.9 (SE 255.6, 16 elections), not lower without qld2020 (+47.9); pooled seat log loss +0.0004 (SE 0.0007); AEF-7 -0.0018 (SE 0.0010, reported). Trees trained on the rank rule: cells -450.3 (SE 204.1) but sa2026 worse and pooled +0.0016 (SE 0.0014). `plans/prereg-onp-direct-model-2026-11-22.md` RESULT.
- **2026-11-23 The forecast names switches that moved since its trees were trained (PR #268, `FJ9!`, `models_flag_drift`).** The 3-day age warning had fired daily for a week unread. The manifest now records the values the rebuild used; today's release manifest was corrected by hand to the trained values (original kept in `deciding-runs/20261123-manifest-fix/`).
- **2026-11-23 One Nation modelled allocation ships today if its fair test passes, even after Pete posts the forecast (Pete).** Three-arm rebuild started 9:11am (about 4pm). `plans/prereg-onp-direct-model-2026-11-22.md` Amendments 1-2.
- **2026-11-23 Live forecast moved to trees trained 23 Nov (were 13 Nov).** Published with the by-election rule: expected seats Coalition 40.4 -> 40.6, Labor 25.4 -> 24.2, One Nation 14.6 -> 16.3; 8 favourites changed (the rule alone moves Werribee and Mulgrave; the rest is the tree refresh and new polls, not split).
- **2026-11-23 vic2026 search interest stays OFF for the election (Pete: "Keep it off").** Final snapshot (Google to 21 Nov) walked on against off: on, independents 0.2 -> 2.6 expected seats (Essendon 2% -> 48%, Hawthorn 1% -> 44%, Mornington 1% -> 28%), 9 favourite changes; the same pattern that turned it off on 19 Nov (past challengers with that rise won 2 of 23). `deciding-runs/20261123-salience-walk/`.
- **2026-11-23 By-election person rule SHIPPED (`AUSPOL_BYELECTION_PERSON="1"`; Pete pre-agreed 22 Nov: ships if all four checks pass).** Rebuild pair: by-election seats' squared error -1463.9 (SE 1395.9, 23 elections), still lower without any one election (worst -70.2, without nsw2019, which carries almost all of it: Murray, Dalton), pooled seat log loss 0.3164 -> 0.3125 (SE 0.0039). Reported: AEF-7 +0.0009 (SE 0.0006). Live: Werribee One Nation 30% -> 57% on an assumption no past case tests. `plans/prereg-byelection-person-2026-11-22.md`.
- **2026-11-22 The 13 and 20 Nov Lighthouse polls stay in as they are (Pete asked: check whether 13 Nov repeats the 19 Oct-1 Nov poll).** Not a repeat: Poll Bludger reads it as an independent sample (n 1,351 against 1,289; no fieldwork dates published) and AusPoll's "19 Oct-1 Nov" for it was a misreading. Both reach the trend at their publication dates; re-dating them moves every party under 0.03 points (live runs, same seed). Dropping it would have moved One Nation +0.18. The 20 Nov figures may half-overlap 13 Nov (Bowe: a two-week rolling average), unconfirmed. Agenda C/Antenna (22 Nov) left out: Bonham does not aggregate it. `deciding-runs/20261122-lighthouse-dates/`; https://www.pollbludger.net/2026/11/18/victorian-election-minus-ten-days/
- **2026-11-22 The night fetcher retries failed pages, and the Actions backup runs the website night.** One failed page of 174 voided a whole snapshot; the VEC site answers a GitHub runner with HTTP 999 on 4-74 pages a fetch. Failed pages only are refetched, up to 3 rounds after 5/15/30 s (`VWF6`, `--retries`); a clean fetch is unchanged, and the laptop saw 0 failures in 4 back-to-back fetches. Applies to the laptop on 28 Nov too. Backup passed on the 2022 pages (run 44984447331, two cycles). NEXT-STEPS "NIGHT BACKUP".
- **2026-11-22 One Nation's seat allocation stays as shipped (rank on the Senate vote, spread 0.365).** Pete asked for a modelled version instead of a forced spread. A direct model (Senate share + Year 12, pooled over earlier elections, `AUSPOL_ONP_ALLOC=model`) beats the rank rule scored alone (RMSE 2.53 to 2.43, 10 elections) but fails its pre-registered screen through the full model: squared error on 751 changed cells +2% (1.7 SE, 11 elections), seat log loss 0.2664 to 0.2679 (SE 0.0016). The tree step already does this job. A 0.30 spread quick fix was made on my recommendation and reverted the same morning before any PR. `plans/prereg-onp-direct-model-2026-11-22.md`, `reviews/onp-demographics-and-spread-2026-11-22.md`.
- **2026-11-22 By-election de-swing stays ON: its pre-registered rebuild pair passes all four criteria.** Squared error on the 57 by-election seats' primary votes -248.9 of 8,598.1 (SE 180.9, 23 elections); still lower with any one election dropped (worst -157.1); pooled seat log loss 0.3170 to 0.3164 over 2,931 seats / 35 elections (SE 0.0016); the by-election seats' own log loss -0.0305 (SE 0.0237). One election worse by more than 0.02, nsw2019 +0.0412: all of it is Murray, whose Shooters winner went from 1 win in 20,000 simulations to 0; the other 92 seats improved 0.2062 to 0.2053. `plans/prereg-byelection-deswing-2026-11-19.md` RESULT.
- **2026-11-19 By-election de-swing SHIPPED on Pete's override (`AUSPOL_BYELECTION_DESWING=1`; "Let's fix it now, please. This is urgent").** The half-blended by-election row was swung by the full statewide change, so the swing to the by-election date counted twice at half weight. Werribee Liberal 63% to 28%, Labor 10% to 42% (Sportsbet Labor ~48%). Shipped before its pre-registered rebuild pair was scored (recommended waiting one day); the pair runs 20 Nov 1am and is reported against the prereg criteria. `plans/prereg-byelection-deswing-2026-11-19.md` Amendment 2.
- **2026-11-19 Narracan and Mill Park: no defect.** Narracan Labor 15.2 -> 8.9 is four shipped steps (`AUSPOL_TRACE_SEAT=Narracan`):
  proportional One Nation fill -3.5 (the Box Hill mechanism, open after 28 Nov), trees -0.4, seat-swing port -1.9, demographics
  -0.5; Mill Park is the council rule working. `reviews/market-gaps-vic2026-2026-11-19/README.md`.
- **2026-11-19 Victorian search interest OFF in the live forecast (Pete: "Turn it off")** (`AUSPOL_SALIENCE_LIVE_VIC=0`,
  `salience_live_filter()`): it alone gave three challenger independents 0.32-0.65 (Essendon, Benambra, Hawthorn);
  past challengers with the same rise won 2 of 23, no seat polls in two, Hawthorn's poll and YouGov against. Expected
  seats ALP 23.4 -> 25.1, LNP 39.1 -> 40.5, ONP 15.8 -> 14.9, IND 1.9 -> 0.2. `reviews/market-gaps-vic2026-2026-11-19/README.md`.
- **2026-11-19 Release downloads retry three times** (PR #257, `scripts/gh_retry.sh`): the 4:34am daily run died on one failed GitHub call; rerun published 8:12am with Essendon IND 0.647 (split held on its first daily run). #256 closed.
- **2026-11-18 (evening) Gated independent split SHIPPED on Pete's override** (`AUSPOL_CLASS_SPLIT=1`, `_MODE=pts_carry`, `_GATE=cred2`): arm K only in seats with 2+ credentialed independents. Guard 1 missed by 1.16 SE (+0.0058, SE 0.0050; Mackellar, Calare 2025); primary and all-seats better. Pete: "Ship it (override guard 1)". Prereg Amendment 2; live walk `reviews/ind-split-armk-live-walk-2026-11-18.md`.
- **2026-11-18 Several independents split by expected points (`AUSPOL_CLASS_SPLIT_MODE` pts_cred / pts_carry, `AUSPOL_CLASS_SPLIT_SD` by_junior): REFUSED, all three arms, stay OFF.**
  Ties on seats with 2+ independents (-0.003 to -0.004, SE ~0.005); worse on seats an independent won (+0.057 to +0.070,
  SE ~0.015). Pete designed it with me and chose to rescreen once after the first refusal. `plans/prereg-ind-split-points-2026-11-18.md`.
- **2026-11-17 No per-state level in the Liberal card shares (`AUSPOL_HTV_JUR_SHRINK` stays "0"; vic2026 keeps 61.7% Liberal to Labor over Greens under a Labor-above card).** Screened on all 35 elections at 1,000 sims (`deciding-runs/20261117-2137-htv-jur-screen/`): seat log loss +0.0002 (SE 0.0002); vic2014 +0.0044 and vic2022 +0.0023, the two Victorian elections it touched, both worse. Refused by its own prereg (`plans/prereg-htv-jur-shrink-2026-11-17.md`); Pete told 17 Nov.
- **2026-11-17 Election night assumes the VEC results pages fill in during the count; the follow-up email is not sent.** Pete: the VEC's 11 Nov reply (refusing the feed, "monitor the VEC website on election night", which it says matches the feed and updates as often) already implies it. The night path stays `night_cycle(source_type = "web")` on `scripts/fetch_vec_web_snapshot.R`. If the pages turn out static on the night, the dress rehearsal (25 Nov) cannot catch it; the first live snapshot's vote totals are the check.
- **2026-11-16 The vic2026 seats' minor total (12.5 against the level's 11.0) is left as is: traced to the trees seeing the real candidate count, the direction past results support.** `SMN1` (mean seat share after each stage of `fit_seats_full.R`): the trees move IND+OTH+OTH_RIGHT 9.32 -> 12.59; with `AUSPOL_LIVE_N_CAND=0` 9.88. On `output/published-predictions.csv` (35 pairs) minor classes are under-called, more so with more candidates (-0.69, -1.47, -2.66 points at 1, 2, 3+; SE ~0.8, clustered on pair). Review item C1 (`reviews/FABLE-FULL-REVIEW-2026-11-15.md`). Claude's call, reported to Pete; no number changes.

- **2026-11-15 `AUSPOL_LIVE_N_CAND=1` SHIPPED (Pete: "Ship it", after a live walk): the live trees get the real number of candidates per class and seat.**
  `R/xgb_primary_override.R:322` served `n_cand_now = 1` for every live row ("unknown pre-nomination") while every training
  and backtest row carries the real count; nominations closed 9 Nov and 110 of vic2026's 616 seat-classes have more than one
  candidate. Walk, constant 1 against real counts, same polls and seed, 20,000 sims: expected seats ALP 24.53 -> 23.34, LNP
  39.72 -> 39.03, ONP 14.90 -> 15.77, IND 1.48 -> 2.16; P(LNP majority) 30.1% -> 27.9%; win probability moves by more than 5
  points in 23 cells (12 seats), largest Essendon IND 39.8% -> 84.7%. Known cost, accepted: the three minor classes' seat
  means add to 12.5 against the polls' 11.0 (were 9.8). Live only; no backtest number moves. Evidence and the rest of that
  session's findings: `reviews/FABLE-FULL-REVIEW-2026-11-15.md` (item A7). Same day, also from that review, Pete chose: leave
  `AUSPOL_LIVE_LEVEL_PRED_TREND=1` (re-walked at a 0.9-point gap: one cell over 2 points); relabel the site's two-party line
  as implied from primaries and add the polls' own figures; show the forecast's level in the party tiles; list the
  `fit_nsw.R` noise-limit failure as known until after 28 Nov. The last three are NOT built yet.
- **2026-11-15 "Revisit candidate-count weighting once nominations close" is CLOSED, not rescreened: it was built as the class split, which stays OFF.**
  The 22 Aug remedy (`reviews/candidate-count-weighting-blocked-2026-08-22.md`) became `AUSPOL_CLASS_SPLIT`, REFUSED twice on
  35 elections on 6 Nov (+0.0022 SE 0.0013; with search interest +0.0016 SE 0.0011), and Pete closed it pending a new design.
  The backtests already used each election's real nominations, so the VEC's final list adds nothing to that verdict; a rescreen
  would read the same per-candidate predictions (`minor-candidate-oof-resid-v2.csv`, unchanged by the 9 Nov newcomer lift,
  which acts on seat shares) and the prereg's one rescreen is used. Live size, from `minor-candidate-oof-resid-v2-live.csv`:
  75 of 88 vic2026 seats have a minor class with 2+ candidates (109 seat-classes), median junior 2.6 points, largest 7.4; only
  Kew's class reaches 15% (IND 21.9, junior 2.8). Told Pete 15 Nov.

- **2026-11-15 The Liberal card shares train on the CARD where a dated card exists, not on each election's own result; open cards get their own share (Pete: ship as a correctness fix on a tie).**
  `AUSPOL_HTV_LABELS=hybrid`: card label per election and seat; seats with no dated card keep the result label; open share
  partial-pooled. 18 elections with a card row: -0.0001 (SE 0.0002), none moved more than 0.003. The pure-card arm tied
  (+0.0014, SE 0.0017) but failed its guard: nothing before 2013 has a dated card, so vic2010 lost its training (+0.032).
  Live: Labor-above 62.1% -> 61.7%, Brunswick (open card, registered 12 Nov) 57.1%. `plans/prereg-htv-card-labels-2026-11-15.md`.
- **2026-11-15 vic2026 Liberal card known from the VEC's registered cards: Labor above the Greens (PR #241).** 6 of 7 inner-Melbourne
  cards read; Brunswick open. Ends the 0.67 card mix; Pascoe Vale Labor 0.347 -> 0.426, Northcote 0.163 -> 0.205.
- **2026-11-14 On election night, two candidates of one minor class are counted separately from their counted figures (Pete: "Ship for 28 Nov").**
  Prereg PASSED on fed2022/fed2025/vic2022 replays: pooled night log loss -0.0076 (SE 0.0096), no night worse by >0.005; Monash's
  winner 0.005 -> 0.469. Gain mostly Monash (without it +0.0018, SE 0.0012). Pre-election split stays OFF (6 Nov). `plans/prereg-night-class-split-2026-11-14.md`.
  Restated 14 Nov night after a federal replay fix (PR #240: names case-folded; 8 divisions a night had lost their 2CP
  count, Forde among them): pooled -0.0084 (SE 0.0095), without Monash +0.0011 (SE 0.0010), still PASS; the live
  `.NIGHT_PAIR_CAL` refit is identical. Forde's cost was the missing count, not the split (prereg addendum).
- **2026-11-14 Paid SEAT polls lose a lean toward their sponsor's side, each side shrunk to zero on its own (Pete: "Build per-side, ship live"; an override of an unvalidated backtest).**
  Hindsight: fed2025 Coalition-paid +4.7 net, Labor/Greens +2.6, Climate 200 -0.5. Time-forward no variant beat zero on fed2025 (only 6
  older Labor/Greens-side polls to learn from). Placebo 18/20; live: Hawthorn's Liberal-members poll 41 -> 37.7 only. Score on vic2026.
  `plans/prereg-seat-paid-lean-2026-11-14.md` (amendment 3).
- **2026-11-13 Party- and advocacy-paid statewide polls count x0.64 and lose a shrunk lean toward their sponsor (Pete, 13 Nov: "Ship it").**
  12 paid polls since 2025 vs same-time independent polls: lean +0.24 (SE 0.55) -> ~0; extra noise -> factor 1.248. Placebo
  18/20; no scored election has a paid poll before its cutoff, so it is first scored on vic2026. `plans/prereg-paid-poll-correction-2026-11-13.md`.
- **2026-11-13 vic2026 salience is linked by a LADDER of similar-loudness queries, not the Premier (Pete, 13 Nov: "Ship it").**
  Beside the Premier the median batch representative peaked at 1 (0-100), so linked rises came in 5 steps; the ladder (49
  queries of 5, 2 shared per step, two passes) gives 229 distinct values among 238 positive jumps, 561 candidates linked.
  Batch factors use the representative's last-8-weeks level (whole-window levels made one Morwell batch 30x too loud).
  Live vs anchor: 4 favourites change (Cranbourne ONP 56% -> ALP 67%, Essendon ALP -> IND 40%, Bentleigh and Eltham LNP ->
  ALP ~51%); Mornington IND 24% -> 1%; expected seats move under 1. No outcome exists to score it against.
  `scripts/fetch_salience_vic2026_ladder.R`, `scripts/build_vic2026_salience_jump.R` (VJ6/VJ7).
- **2026-11-13 Council-history coverage fix ships, although the live forecast moves up to 5 points (Pete, 13 Nov).**
  Both prereg guards pass (35-election log loss +0.0009, SE 0.0018; share RMSE +0.0067). Live vic2026 moves up to 5.3
  points (Footscray ALP 53% -> 48%, favourite to GRN; Melton ONP -> LNP; ALP 26.8 -> 26.1 expected seats), all from the
  retrained production trees (other rebuild files at most 1.5). That breached the prereg's "over 2 points, unexplained"
  clause, so it went to Pete. `plans/prereg-council-coverage-2026-11-12.md` amendment 1.
- **2026-11-12 vic2026 salience ships now; its coarse anchor scale is fixed before the final snapshot (Pete, 12 Nov 10:40pm).**
  With/without on the live forecast: 12 of 88 favourites change, all close seats (Hawthorn IND 0.007 -> 0.346, Benambra
  IND 0.001 -> 0.274; expected seats ALP 26.8 -> 24.9, ONP 14.7 -> 15.8, IND 0.1 -> 1.3). Known defect: linked values come
  in ~5 steps of 0.0607 (17 candidates with raw rises 2.3-32.1 share 0.182). `reviews/salience-vic2026-live-walk-2026-11-12.md`.
- **2026-11-12 vic2026 salience goes into the live forecast RANK-MAPPED, not raw (Pete, 12 Nov).** Each jump is divided by
  the anchor's (Ben Carroll) rise, and his is small, so the 11 Nov snapshot ran ~20x the backtest scale (p90 0.168 vs vic2022
  0.0079); each candidate keeps their vic2026 rank, mapped onto the backtest corpus within sign. Built on branch
  `salience-vic2026-link` (`scripts/link_vic2026_salience.R`); not merged until the live with/without walk.
- **2026-11-12 "Lighthouse" and "Lighthouse/Growth Intelligence Centre" are one firm: one pollster page (Pete, 12 Nov).** One poll each, a day apart
  (25 and 26 Oct 2026), so the "method changed" note was false. `SAME_FIRM` in `scripts/build_pollster_pages.R`; pages only, the forecast
  is unaffected (both under 3 polls, pooled house effect). "Lonergan" 2013-16 vs "Lonergan Research" 2022 stay two linked pages.
- **2026-11-12 Night: cand_ref "copy" stays ON for 28 Nov; pair_cal still passes (Pete, 12 Nov).** The vic2022 replays and
  the cand_ref scorer matched booth tables by exact district name ("South Westcoast", "Albertpark"; 25 of 87), fixed
  264cc306/5963c174. Rerun: pair_cal pooled -0.00212 (SE 0.00143; was -0.00175), PASS; cand_ref simulated -0.0317
  (SE 0.0263, 30 targets), real -0.0017, vic2022 -0.0006, but its "vic2022 identical" clause now fails: vic2022 has two
  class-switchers the bug hid (Nuske, Doukas). Clause voided as resting on the bug (prereg Amendment 1).
  `deciding-runs/20261112-vic2022-names/`.
- **2026-11-12 The anchor's NSW 2007 Labor/Coalition swap is corrected on load; it never reached the forecast.**
  `load_eventual_results()` applies `EVENTUAL_RESULT_FIXES` (EVR1; `AUSPOL_EVENTUAL_FIXES`, shipped "1"). Screen with the
  fix off vs on, all 35 elections, 1,000 sims: byte-identical in 35 of 35 (the switch printed in all 42 harness runs each
  way). Why: every forecast fit of the statewide fundamentals uses the `@TPP` target, which the file has right; the only
  per-party fit (`build_level_components.R`) feeds the retired `fit_xgb_primary_v6.R`. It corrects displayed figures
  (pollster final-poll errors, scorecard, party pages).
- **2026-11-12 Poll columns by full party name (`AUSPOL_POLL_SERIES_CLASS=name`) NOT SHIPPED (Pete, 12 Nov).** All 35
  elections at 20,000 sims: seat-winner log loss 0.3089 -> 0.3114, +0.0025 (SE 0.0016, worse by more than 1 SE), share
  squared error on 6,807 moved cells +15%; AEF-7 a tie (-0.0009, SE 0.0031). Worst sa2018 +0.076, fed2013 +0.016,
  vic2022 +0.016. Stays "code". `deciding-runs/20261111-0747-poll-series-class-all35-r2/results.txt`;
  `plans/prereg-poll-series-class-2026-11-06.md` RESULT.
- **2026-11-10 One Nation seat spread unchanged before 28 Nov (walk of Box Hill, Ashwood, Glen Waverley with Pete).**
  Senate-rank spread vs seat regressions, out of sample: Senate alone 3.44 points RMSE (308 seat-elections, 5 elections),
  trees on 11 inputs 3.23, gaining only on qld2017 and worse on qld2020/qld2024/nsw2023. On Victoria all three
  alternatives sit within ~2 points of ours in the eastern seats (Box Hill 9.7 ours vs 11.0-11.6). Box Hill's gap to the
  bookmakers is the proportional fill, not One Nation's share. `scripts/explore_onp_seat_regression.R` (de7e7071).
  ADDED 11 Nov (ITG review): those figures came from a join that missed 44 of 308 multi-word seats and gave them a
  made-up 0 for previous Greens/minor right/One Nation. Rerun with the join fixed (all 308 joined, guarded by OSR0):
  Senate alone 3.44 (unchanged), trees on 11 inputs 3.19 (was 3.23), still gaining only on qld2017 (5.27 -> 3.89) and
  worse on qld2020 (2.65 -> 3.07) and qld2024 (2.94 -> 3.07); Box Hill ridge 11.4 vs ours 9.8. Decision unchanged.
- **2026-11-10 Preston: One Nation disendorsed Franco Guardiani (ABC, 10 Nov); he stays on the ballot as One Nation. No
  change.** We have One Nation at 16.7% there and Labor at 0.964 to win (Greens 0.026); a cut to his vote moves no
  seat call. The model has no column for disendorsement or scandal (`R/candidate_returns.R:729`).

- **2026-11-10 Standing notes moved out of NEXT-STEPS.md (queue audit: nothing a session could tick off).** Wording
  kept as it stood in the queue; reopen any of them by moving it back with a trigger.
  - F16 `AUSPOL_ROW_SHIFT_EXACT` NOT PASSED 29 Oct (DECISIONS). F18 `AUSPOL_NOM_ZERO_PRE_XGB` SHIPPED 10 Nov (DECISIONS).
    Dead-party `AUSPOL_LEVEL_DEAD_PARTY` (337f4cd) PARKED: its screen says not worth it; do not merge.
  - F8 RN is dead (arm N worse). F8 arm N's netting costs 579 s per harness run: cache it to disk before any rerun.
    (Departed arm B `mean`: DEAD, departed-origin closed 27 Oct. Width A0/A1: see the pipeline-audit section.)
  - OPEN (review nit, 30 Oct, not blocking): the shipped MP-slope pool's tau^2 is inflated where one OTH_RIGHT member
    slope of -23.1 (n 1, se ~11) enters the DerSimonian-Laird sum: qld2015, sa2014, vic2014 get tau^2 ~0.57 (0 at most
    targets), so IND there keeps w 0.99 instead of pooling (`output/mp-slope-pooled.csv`; `R/mp_slope_pool.R:79-83`).
    The all-35 screen ran on this table. CORRECTED 5 Nov: not a variance artifact (sigma is already pooled); the one
    OTH_RIGHT seat sat almost on the statewide level, so its slope blows up (-23.1, z ~2.2) and supplies 4.6 of Q 5.4.
    Visible effect: the n-1 GRN member keeps w 0.63 (1.23 vs mu 0.92). A fix is a choice (robust tau^2, or no ratio for
    seats near the level), PARKED: live vic2026 unaffected (tau^2 0), old targets only, needs its own screen.
  - MEASURED, PARKED per-class level bias (17 Oct, scratchpad levelcorr.R): statewide level over-predicts the Greens in
    23 of 35 elections (formal-weighted -0.73); all-class time-forward correction loses (1.402 -> 1.426), GRN alone
    helps slightly (prereg-poll-level-centring arm C, never run). Revisit GRN alone when more elections are in.
  - OPEN (hazard for arms, not live) pooled-fits audit 2026-10-16 (`reviews/pooled-fits-inventory-2026-10-13.md` and
    after): LEAVE-ONE-OUT but OFF at published flags, so any arm switching them on measures a leaked number:
    `fit_xgb_primary_sd.R:108` (`AUSPOL_XGB_PRIMARY_SD`), `fit_flow_drift.R` (`AUSPOL_FLOW_CELL_SD`),
    `fit_insurgency_risk.R:33` (`AUSPOL_INSURGENCY_SHRINK`), `party_positions(exclude=)` in `R/reentry_prior.R:288`,
    `xgb-primary-v6-oof-predictions.csv` (static-cache arm). (`state_swing_adjustment()`, dead code: DELETED 25 Oct on
    Pete's yes, DECISIONS.)
  - OPEN SEAT-REGISTRY entries for the new worst seats (DATA/MODEL/POLL registries: regenerated 4 Nov, `f453b62b`, `14f55eba`).
  - CORRECTED 5 Nov: the breakdowns did NOT stop. BludgerTrack still publishes them (refetched 5 Nov, newest fieldwork
    25 Oct, raw `external/reference/polls/pollbludger/raw/bludgertrack/fed2028-current-2026-11-05.xml`; branch
    `fed-breakdowns-trend-1105` builds the union, 704 polls). Feeding BludgerTrack's rows into the blend was REFUSED by
    Pete 5 Nov (DECISIONS; `--with-bt`, off), so the blend's federal share is decaying by choice; FK3 (~20 Nov) only warns. Wikipedia's part: deleted the sub-national
    sections from the fed2028 page on 24 Oct (revision 1381724607, "excessive detail"; checked 5 Nov). The last
    pre-deletion revision (1381712590, saved as `raw/fed2028_opinion-oldid1381712590.html`) parses to the same 471 polls
    as ours, so nothing was added after 6 Oct either. Adding `fed2028_opinion` to the CI fetch would lose rows (PM2!).
    `build_fed_state_breakdowns.R` now refuses to write fewer or older polls than on disk (FK2!, proven on a broken
    input). Live effect: the blend's federal share (`AUSPOL_LEVEL_FED_R` 0.15) decays with no new data; FK3 (45 days)
    would trip ~20 Nov.
  - **Demographic axis**: real (permutation control) but one coefficient is an
    order of magnitude too small; a level interaction needs its own prereg.
    Parked by Pete.
  - **`base_margin` scoped arm** (away from ALP, or to sa2026/wa2021-shaped
    cases): the full form refused at seat level (+0.004) despite primary gains.
  - **Time-forward fits still use `min_n` cliffs**: `R/split_slope.R:395,416` sit in `fit_conditional_slopes()`,
    which the shipped config never calls (`AUSPOL_FIT_SLOPES=0`). `fit_major_departed_slope()` no longer has its 40-seat cliff (`AUSPOL_DEPARTED_POOL` SHIPPED 6 Nov; DECISIONS). The
    `fit_conditional_slopes()` cliffs above remain, in unshipped code.
  - **Teal/independent under-call** (Curtin, Goldstein, Mackellar, Wakehurst):
    PARKED by Pete. Overall we lead AEF on independents (36 winners: 16.7 vs
    19.7 log loss). Wave term blocked (`reviews/wave-term-blocked-2026-09-07.md`).
  - Smaller known limits: intra-Coalition seats have no TCP class (2 of 660, AEF has the
    same limit; zero vic2026 seats affected today); Orange/Wagga `own_prev_pcv` NA for
    by-election winners (needs a feature, fallback fill refused); the statewide
    covariance pools every era; WA has no surge-v2 hazard.
  - GDELT parked (needs a GCP project); Census 2006/2001 have no bulk pack.
- **2026-11-10 Queue audit closures.** "Move off AE (b)": the language-model extraction of Poll Bludger posts WAS built
  (`AUSPOL_POLL_PB`, 45df5117; `reviews/pb-llm-extraction-2026-10-13.md`), so the item is done. Moved here from the queue
  as a standing not-doing: the in-browser simulator (~40 h); the 2.5-point knots already feel live; revisit if Pete wants
  two sliders at once.
- **2026-11-10 Local check skips the tests inside R CMD check (Pete: go).** `check_like_ci.R` passes `--no-tests`;
  the in-check copy was a subset of half one (4,964 vs 5,083 passed, FAIL 0 both). Full forced check 559 s -> 396 s.
  CI unchanged; `--with-check-tests` restores them (and bypasses the unchanged-package skip). Merge 8c7cbcf9.
- **2026-11-10 vic2026 gets its own minor-party bucket split from the VEC list (Pete: "Ship it").** Was the vic2022
  mix (`FST1!` fallback); now IND 0.27, OTH_RIGHT 0.24, OTH 0.50. Walk on the live forecast: 0 favourites changed, max
  win-probability move 0.4 points (Ashwood ALP), max share move 0.23 (Kew LNP). Built by `rebuild_forecasts.sh`
  (`MC_LIVE_EL`); `PIPELINE.md` section E step 5.
- **2026-11-10 F18 SHIPPED: non-standing parties zeroed before the trees too (`AUSPOL_NOM_ZERO_PRE_XGB="1"`; Pete: "Switch it on").** Walk 2 on the VEC final list: 47 untouched seats identical, 40 of 41 affected under 1 point, Mildura LNP 46.3 -> 50.2 walked. `plans/prereg-nom-zero-pre-xgb-2026-10-25.md`.
- **2026-11-10 Nomination gate live for vic2026 (PR #212, merged 7:11am).** 734 VEC candidates; 40 cells zeroed (IND 32, OTH_RIGHT 8), no favourite changed.
- **2026-11-01 to 2026-11-08: archived verbatim** in `backlog/journal-decisions-2026-11-01-to-11-08.md` (32 decisions: independent labels, By-election table, NSW exhaust arms, seat flow persistence, class-split refusals, poll-lean refusals, trend anchor, HTV recency, One Nation fill, new-independent breakout). The 5 and 6 Nov switches are in `published_flags.R`; open follow-ups are tracked in `NEXT-STEPS.md`.
- **2026-10-23 to 2026-10-31: archived verbatim** in `backlog/journal-decisions-2026-10-23-to-10-31.md` (46 decisions: surge mixture off, sitting-member rule and census v2 rebuilds, One Nation Senate ordering, MP-slope pool, port 3C, minor field by points, switch registry MR4, and the refusals of swing-floor hybrid, level conservation, F7, F16, decay4, IND gap yes/no, returning independents). Checked 10 Nov, nothing live outside the queue: the unknown-candidate surge was kept off (Pete, 4 Nov; PETE-ASKED-FOR); the tau^2 departed slope pool SHIPPED 6 Nov (fe478b0b); the direction-aware swing floor is `AUSPOL_SWING_FORM=hybrid`, REFUSED 30 Oct (in the journal); per-cell fat tails and the new-independent seat-poll term are OPEN in `NEXT-STEPS.md`.
- **2026-10-15 to 2026-10-21: archived verbatim** in `backlog/journal-decisions-2026-10-15-to-10-21.md` (25 decisions: seat-poll blend arm H, live train/serve fixes F1-F3, Liberal v National as two candidates, width + tails (CE), statewide draws net of seat spread, surge_h leak fix kept, party correlation off, surge source none, seat context in the rebuild, harness md5 tags, WA/NT screened-slopes port, the 15 Oct external/elections incident, and the refusals of 19-20 Oct). Still live from that range, tracked in `NEXT-STEPS.md`: the NT seat layer (nt2020 not yet traced).
- **2026-10-08 to 2026-10-14: archived verbatim** in `backlog/journal-decisions-2026-10-08-to-10-14.md` (46 decisions: NSW 2027 build and what-if slider, seat-poll and statewide-poll weighting refusals, level decay and day-before blend, deciding-run tooling, flow recency arms, own poll source, scoring and training rules, leak fixes, census publishing, thin poll cycles, defector carry, size SD, poll archive). Still live from that range, tracked in `NEXT-STEPS.md` and not decided here: flow recency arms (`AUSPOL_FLOW_RATE_HL` / `AUSPOL_FLOW_TF`, built, none shipped, open) and the move off AEF for polls and flows (`PETE-ASKED-FOR.md` 2026-10-12/13 rows).
- **2026-10-03 to 2026-10-07: archived verbatim** in `backlog/journal-decisions-2026-10-03-to-10-07.md` (35 decisions: nomination zeroing v61 and its late order, departed successors, re-entry majors, new-independent shrink, seat-poll fixes). Every switch shipped there is still in `published_flags.R` and has been through the 15-21 Oct rebuilds. Standing from them: NSW 2027 polling day is 13 March 2027 (NSWEC Bulletin 2; the anchor's cycle file says 20 March); the departed-rate refit falls back to the control 0.38.
- **2026-09-29 to 2026-10-02: archived verbatim** in `backlog/journal-decisions-2026-09-29-to-10-02.md` (ledger v47-v60). STILL LIVE from them: the seat-poll weight is fitted on the PREVIOUS rebuild's `output/forecasts.csv` (`R/seat_poll_blend.R:67`), so a rebuild that moves earlier elections needs a second stage-6 pass -- the same one-run lag the spread table had (NEXT-STEPS). Standing from them: leak fixes v47 (minor-slope fallback), v49 (surge-v2 hazard), v51 (statewide fundamentals/trend mix) are time-forward; the seat-poll blend ships (v50); calibration temperature closed (no-go).
- **2026-09-19 to 2026-09-28: archived verbatim** in `backlog/journal-decisions-2026-09-19-to-09-28.md` (ledger v39-v46 history). Standing from them: backtests are predictive (`AUSPOL_FORECAST_MODE=1`); the daily forecast publishes unattended behind input guards; the data registry is not regenerated on CI; a poll-tracking breach is reported, not halted; the model is not frozen before 28 Nov; live statewide level anchored as the backtests are. Refused there: state-deviation v2, dropping `fed_aligned`, zeroing the phantom vote alone. Parked: seat-type swing pre-election.

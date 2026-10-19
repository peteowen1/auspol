# Diagnosis of the 13 big misses in the AEF-7 seat ledger

Written 2026-10-19. Read-only analysis; nothing under C:\dev\auspol was changed.

## How to read this

- Every number is on the PUBLISHED path (`output/published-predictions.csv`, 19,616 data rows, columns used: pair, seat, party, candidate, ours, actual, miss, p_win, won, prev_share). `miss` and "err" below always mean actual minus ours, in percentage points of the first-preference vote, so a positive err is a party we under-called.
- To locate where in the pipeline a miss arose I joined `output/forecasts.csv` (17,010 rows; columns base_pred, xgb_pred_seat, which is the tree output rescaled to 100, and actual_share). Stages: base = before the trees, xgb = after the trees, pub = final published number. Raw `xgb_pred` is not used because it does not sum to 100 (Dickson sums to 109.5).
- Two-candidate figures are from `output/aef7-tcp-actual.csv` (660 rows). "TCP err" is the official share of the party WE picked as winner, minus what we predicted for it. "z" is that error divided by the standard deviation of the same error across that whole election (fed2025 5.9, qld2024 3.9, sa2026 4.3, wa2025 4.7, nsw2023 5.0, vic2022 3.7). A seat that is a coin flip on the day and has z around 1 to 1.5 is an ordinary miss, not a broken model.
- "Peers" means seats in the same election whose top two parties (by our prediction) are the same two, with the leader within 6 points of this seat's leader. Where fewer than 5 peers exist, I say so.
- CONFIRMED means the cause follows from the numbers. LIKELY is a reasoned guess and says what would confirm it.

## Context that applies to all 13

Calibration check (AEF-7 pairs, 681 seats, 4,767 party-class rows). Among rows where we gave a party under 25% to win, we expected 42.4 wins and saw 33. Under 10%, we expected 20.4 and saw 6. So the model is not over-confident in aggregate: the 13 big misses are a normal tail, not evidence of a broken spread. The one election where underdogs won as often as expected is fed2025 (13.0 expected, 14 seen), which is the Labor under-call below.

The spread agrees with the TCP error. A favourite at a 54.5 two-candidate share, with error SD about 4.7, has Phi(4.5/4.7) = 0.83 to win, and the model gave 0.77 to 0.88 for these favourites. So for the "coin flip" seats below the confidence is what the realised error size implies; the real question is why the SHARE was 3.5 to 6 points off.

Eight of the 13 were decided within 3 points of 50-50 (Kalamunda 49.9/50.1, Northcote 50.2/49.8, Holsworthy 50.4, Menzies 51.1, Bundaberg 51.5, Murray-Wellington 51.7, Capalaba 51.9, Mulgrave 52.7). A winner probability of 0.11 to 0.23 on a coin-flip seat only needs a 3.5 to 6 point TCP error.

Election-level bias (actual minus ours, mean over seats; n = seats):

| election | ALP | LNP | GRN | ONP | note |
|---|---|---|---|---|---|
| fed2025 (150) | +3.58 | -2.46 | -0.56 | -1.47 | Labor under-called nationally; QLD ALP +4.32 (n 30), NSW +4.08, VIC +2.71 |
| qld2024 (93) | +0.79 | -0.21 | -1.90 | -0.14 | OTH +2.51 |
| sa2026 (47) | +1.13 | +2.08 | -1.41 | +3.04 (n 47) | |
| wa2025 (59) | -1.07 | -2.74 | -0.28 | +3.33 (n 41) | IND +3.28 |
| nsw2023 (93) | -0.22 | -1.51 | -1.20 | +6.34 (n 17) | OTH_RIGHT +2.76 |
| vic2022 (88) | -0.69 | +2.19 | -1.05 | +4.98 (n 5, predicted 0) | |

The seat-poll file (`external/reference/polls/seat-polls/seat_polls.csv`) has polls for the five fed2025 seats only (no state seat polls for any of the other eight). For Dickson, Bonner, Melbourne and Griffith the seat polls were wrong in the same direction as we were, so no seat-poll weighting change would have fixed those.

---

## 1. fed2025 Dickson (Dutton's seat)

**Result.** Labor's Ali France won: ALP 33.6 primary, two-candidate ALP 56.0. We favoured Peter Dutton (LNP) at 0.772 (LNP primary 40.3). The winner (ALP) had 0.085; AEF gave 0.230.

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| LNP | 37.7 | 34.8 | 40.3 | 34.7 | -5.6 |
| ALP | 30.4 | 26.8 | 25.9 | 33.6 | +7.7 |
| IND (Ellie Smith) | 6.9 | 17.4 | 13.3 | 12.2 | -1.1 |
| GRN | 13.1 | 10.6 | 10.2 | 7.6 | -2.6 |

**Which number was wrong.** Both main primaries. TCP: we picked LNP at 55.1, actual LNP 44.0, err -11.1 (z -1.9).

**Where it arose.** Two things, in different places.
1. The tree output had Dutton almost exactly right (34.8 against 34.7). The published stage then added 5.5 points to him (to 40.3). That step contains the leader-seat bonus (Dutton is an opposition leader; the bonus was resized to full size on 2026-09-30, `docs/plans/prereg-leader-bonus-size-2026-09-30.md`) and the seat-poll blend (five seat polls had LNP at 37.6 to 41.3, mean about 39.8; the same polls all had the LNP ahead on two-candidate, 48 to 57). The files do not separate the two, so I cannot say how much each added.
2. Labor was under-called at every stage (base +3.2, xgb +6.8, published +7.7). The tree's raw independent call was 19.0 (Ellie Smith; actual 12.2), which inflated the row to 109.5 and, once rescaled, squeezed ALP and LNP. Part of the "right" tree LNP number is therefore luck.

**Same as neighbours?** Largely yes. Queensland ALP was under-called by 4.32 on average, and the 102 LNP-vs-ALP peers average ALP +3.97, LNP -3.05. Dickson's ALP +7.7 is about 1 SD above that; LNP -5.6 is 0.7 SD below.

**Verdict.** LIKELY: national/Queensland Labor under-call (CONFIRMED in the numbers, about +4 of the +7.7) plus a published-stage step (leader bonus and seat-poll blend) that moved a correct tree number 5.5 points the wrong way. To confirm: run Dickson with the leader bonus off, then with the seat-poll blend off, and see which restores LNP near 35. FIXABLE-IN-MODEL in part (the published step); the national component is NOT (seat polls shared it).

---

## 2. fed2025 Melbourne (Adam Bandt, Greens leader)

**Result.** Labor's Sarah Witty won: ALP 31.3 primary, two-candidate ALP 53.0 over Greens 47.0. We favoured Bandt (GRN primary 47.3) at 0.9125. The winner had 0.0063 (AEF 0.119). Lowest winner probability of the 13.

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| GRN | 44.6 | 48.2 | 47.3 | 39.5 | -7.8 |
| ALP | 22.2 | 21.7 | 21.7 | 31.3 | +9.6 |
| LNP | 16.0 | 15.5 | 16.1 | 19.8 | +3.7 |
| IND | 6.7 | 8.3 | 9.7 | 4.9 | -4.8 |

**Which number was wrong.** Greens too high, Labor too low. TCP: we picked GRN at 61.6, actual GRN 47.0, err -14.6 (z -2.5). The primary errors alone nearly account for it: GRN -7.8 and ALP +9.6 move the margin about 17 points.

**Where it arose.** The base was already 5.1 too high on the Greens (prior 48.1 was carried forward), the tree then added 3.6 (44.6 to 48.2, wrong direction), and the published stage took 0.9 back. ALP did not move at any stage (22.2, 21.7, 21.7). The seat polls were closer than we were: Greens 41.3 to 43.1 in three YouGov/RedBridge polls (only Insightfully had 50.1), Labor 28.2 to 30.9 in the YouGov ones. Our 47.3 sat above nearly all of them.

**Same as neighbours?** Partly. In seven Greens-versus-Labor inner-city seats Labor beat us by +9.6 (Melbourne), +8.1 (Sydney), +7.3 (Griffith), +4.8 (Ryan), +4.7 (Brisbane), +4.6 (Grayndler), +3.7 (Macnamara), mean +6.1, against the national +3.58. Greens ran -7.8, -4.0, -3.7, -1.0, -3.2, +3.1, -2.7 in the same seats. Melbourne is the extreme of an inner-city pattern, not an isolated seat. Among the 3 closest peers (Greens top, ALP second) the Melbourne ALP miss ranks worst of 4.

**Verdict.** LIKELY: (a) the national Labor under-call, (b) an extra Labor-over-Greens move in inner-city Greens seats, (c) our own tree and leader-bonus pushing the Greens up when the polls said 43. The retired "under-concentration" idea cannot explain this (it predicted the opposite sign). To confirm (c): fit the tree without the Greens-leader bonus (minor-party leader residual was -2.53, SE 3.77, n 8, so the bonus overshoots) and without the fed2022 Greens residual; see whether Melbourne GRN falls toward 43. FIXABLE-IN-MODEL in part.

---

## 3. fed2025 Griffith

**Result.** Labor's Renee Coffey (new candidate, Terri Butler's seat) won: ALP 34.5, two-candidate ALP 60.6 over Greens. We favoured Max Chandler-Mather (GRN 35.3) at 0.824. Winner 0.165 (AEF 0.279).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| ALP | 26.8 | 24.5 | 27.2 | 34.5 | +7.3 |
| GRN | 33.8 | 39.8 | 35.3 | 31.7 | -3.7 |
| LNP | 27.8 | 25.3 | 28.5 | 26.6 | -2.0 |

**Which number was wrong.** Labor's primary, and with it who made the final two. We expected a three-way split in which the LNP (28.5) beat Labor (27.2) for second place; our scenarios put ALP-versus-GRN as the final two only 25% of the time (`our_tcp_actual_freq` 0.2526) and LNP-versus-GRN 58%. Labor finished second with a clear 7.9 lead on the LNP and won on LNP preferences. TCP: we picked GRN at 50.5, actual 39.4, err -11.1 (z -1.9).

**Where it arose.** Base ALP was already 7.7 low. The tree pushed the Greens up 6.0 (33.8 to 39.8; err -8.1), which the published stage pulled back to 35.3 (still 3.6 high). The final fed2025 seat polls had GRN 38.0, ALP 27.2, LNP 25.6 (YouGov, 29 April), so they over-called the Greens too.

**Same as neighbours?** Labor's +7.3 is double the Queensland average (+4.32); the five Queensland ALP seats that Labor already held averaged +6.67. Brisbane ALP +4.7 and Ryan +4.8 are smaller.

**Verdict.** LIKELY: the tree learned from fed2022 (when Griffith, Brisbane and Ryan Greens were all UNDER-called by 7 to 10 points; see SEAT-REGISTRY) that inner-Brisbane Greens beat their base, and applied it again when the swing reversed in 2025. Plus the national Labor under-call. To confirm: look at the tree's Greens uplift (xgb minus base) for the inner seats in fed2025 against which training pairs drive it, or refit excluding fed2022 Brisbane Greens. FIXABLE-IN-MODEL in part (shared cause C below).

---

## 4. fed2025 Bonner

**Result.** Labor's Kara Cook won: ALP 39.5 primary, two-candidate ALP 55.0. We favoured sitting LNP member Ross Vasta (LNP 41.2) at 0.766. Winner 0.224 (AEF 0.095, so here AEF was worse).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| ALP | 28.7 | 27.5 | 28.5 | 39.5 | +11.0 |
| LNP | 39.9 | 40.5 | 41.2 | 35.5 | -5.8 |
| GRN | 18.0 | 17.6 | 16.5 | 12.4 | -4.1 |
| ONP | 8.6 | 7.5 | 7.4 | 3.8 | -3.6 |

**Which number was wrong.** The Labor primary, by 11 points. TCP: we picked LNP at 52.7, actual LNP 45.0, err -7.7 (z -1.3). It is the TCP, not the primary, that kept our probability for Labor as high as 0.224: even with a Labor primary of 28.5 the model gave Labor a fair chance because Greens (16.5) and ONP (7.4) preferences were large; those minor votes then shrank by 7.7 combined, which is why Labor's primary went up and the preference pool went down.

**Where it arose.** In the base (err +10.8). The tree and the published stage changed nothing (+12.0, +11.0). All five MRP seat polls (Accent/RedBridge, YouGov) had Labor at 27 to 32 primary and the LNP ahead on two-candidate (53.6 to 55); they shared the error.

**Same as neighbours?** Partly. Among the 105 LNP-vs-ALP peers, Bonner's ALP miss ranks 103rd; it is 7.1 above the peer mean of +3.90, which is about 1.9 SD. Other Brisbane-area outer seats had large Labor misses too (Oxley +9.9, Rankin +8.9, Leichhardt +8.9, Moreton +6.9, Forde +6.1, Petrie +6.0). Queensland ALP-held seats averaged +6.67, the 21 LNP-held ones +3.76.

**Verdict.** LIKELY: national Labor under-call (about +4) plus a seat-specific swing, an unusually large Labor gain in Brisbane suburban marginals that the base did not anticipate. The new Labor candidate (Cook; Tabatha Young was the 2022 candidate) and the 2025 Dutton-year Queensland swing are the candidate explanations; I cannot separate them from the files. To confirm: check whether the ALP error in LNP-held Brisbane-metro marginals is larger than in other LNP-held marginals nationally after removing the national mean. NOT fixable at seat level with the current inputs.

---

## 5. fed2025 Menzies

**Result.** Labor's Gabriel Ng won: ALP 34.7, two-candidate ALP 51.1 over Keith Wolahan. We favoured Wolahan (LNP 40.2) at 0.743; winner 0.218 (AEF 0.196).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| LNP | 37.4 | 38.8 | 40.2 | 40.6 | +0.4 |
| ALP | 31.5 | 30.0 | 29.3 | 34.7 | +5.4 |
| GRN | 14.5 | 13.8 | 13.1 | 11.0 | -2.1 |
| OTH_RIGHT | 5.0 | 7.7 | 7.2 | 5.3 | -1.8 |

**Which number was wrong.** The Labor primary (+5.4); the LNP primary was right (+0.4). The Greens, ONP (-2.1) and OTH_RIGHT were each over-called by about 2, and Labor collected what they lost. TCP: we picked LNP at 52.8, actual LNP 48.9, err -3.9 (z -0.65). This is the smallest TCP error of the 13.

**Where it arose.** The ALP error grows through the stages (+3.3, +4.7, +5.4); the LNP error shrinks (+3.2, +1.9, +0.4). The seat polls had the LNP ahead on two-candidate in five of six polls (the last, YouGov 29 April, had it at 49.7).

**Same as neighbours?** Yes. ALP peers average +3.99 (SD 3.71); Menzies +5.4 is 0.4 SD above. Victoria ALP overall was +2.71.

**Verdict.** CONFIRMED: this is the national Labor under-call on a 51-49 seat, not a seat-specific fault. It is the least surprising of the 13: a 0.218 probability for a seat decided 51.1 to 48.9. NOT a model fault worth a separate fix (shared cause B).

---

## 6. qld2024 Bundaberg

**Result.** Labor's Tom Smith held the seat: ALP 41.5, two-candidate ALP 51.5. We favoured the LNP's Bree Watson (LNP 44.2) at 0.861. Winner 0.135 (AEF 0.181).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| ALP | 32.2 | 33.9 | 35.2 | 41.5 | +6.3 |
| LNP | 45.3 | 44.4 | 44.2 | 38.4 | -5.9 |
| ONP | 9.2 | 8.4 | 7.9 | 7.7 | -0.2 |

**Which number was wrong.** Labor's primary and the LNP's, in opposite directions. ONP, GRN and others were about right. TCP: we picked LNP at 54.6, actual LNP 48.5, err -6.1 (z -1.5).

**Where it arose.** The base (ALP err +9.3); the tree and published stages recovered 3 points but not the rest.

**Same as neighbours?** No, the opposite of its region. Regional Queensland Labor seats were over-called: Gladstone -8.8, Keppel -9.4, Mackay -8.1, Rockhampton -5.3, Whitsunday -4.0, Maryborough -3.9. Statewide Labor was only +0.79. Bundaberg's ALP +6.3 is the 49th worst of 50 among 49 peers (peer mean +0.14, SD 3.28, so z +1.9).

**Verdict.** LIKELY: sophomore effect. Tom Smith took the seat from the LNP in 2020 (43.1, against David Batt's 41.5), and this time the LNP candidate was new (Bree Watson). Across 6 elections, a Labor MP who gained the seat at the last election and re-stood outperformed our prediction by +3.97 (SE 0.71, n 39) against +0.60 (SE 0.24, n 309) for longer-serving Labor MPs; qld2024 alone is +1.74 (n 4) so the effect explains part, not all, of the +6.3. To confirm: fit a first-term-incumbent term on the pre-2024 elections only and score Bundaberg. FIXABLE-IN-MODEL (shared cause E).

---

## 7. qld2024 Capalaba

**Result.** LNP's Russell Field won: LNP 44.4, two-candidate LNP 51.9. We favoured Labor's Don Brown (ALP 43.0) at 0.845. Winner 0.154 (AEF 0.214).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| LNP | 38.6 | 38.3 | 37.1 | 44.4 | +7.3 |
| ALP | 39.4 | 40.7 | 43.0 | 36.7 | -6.2 |
| GRN | 11.8 | 11.5 | 11.2 | 11.7 | +0.5 |
| ONP | 10.3 | 9.4 | 8.7 | 7.2 | -1.6 |

**Which number was wrong.** The two main primaries, in opposite directions. TCP: we picked ALP at 54.4, actual ALP 48.1, err -6.3 (z -1.6).

**Where it arose.** Partly the base (LNP +5.8, ALP -2.6), and then the published stage moved it the wrong way: ALP +2.3 and LNP -1.2 relative to the tree. The files do not show which published-stage step did that (no seat polls exist for this seat; the likeliest candidate is an incumbent bonus for a member of 12 years' standing, but I did not find it in the output).

**Same as neighbours?** No. Redlands-area and bayside seats were fine: Redlands ALP +1.8 / LNP +0.3, Oodgeroo +2.6 / +2.0, Mansfield +3.5 / -3.2, Springwood 0.0 / +0.5. Statewide ALP was +0.79. Among 49 peers the LNP miss is 47th of 49 (z about +2.2) and ALP's 3rd of 49. Longer-serving Labor MPs in qld2024 averaged +0.16 (n 39), so no general incumbent penalty explains it.

**Verdict.** LIKELY seat-specific and not explained by anything in the files. Don Brown had held the seat since 2012 and fell 11.5 points (48.2 to 36.7), against a predicted fall of 5.2; the LNP rose 13.5 (30.9 to 44.4), predicted 6.2. I could not find a local cause. Unresolved: it is the one seat of the 13 where I have no mechanism. To check: look for a candidate story (Field's profile; Brown's), and trace which published-stage component added the 2.3 to ALP. Probably NOT fixable (single-seat variance), but the published-stage move deserves a trace.

---

## 8. qld2024 Mulgrave

**Result.** LNP's Terry James won with only 27.4% of first preferences; two-candidate LNP 52.7 over Labor. We favoured Labor's Richie Bates (ALP 36.5) at 0.750. Winner 0.229 (AEF 0.021, so we were far better than AEF here).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| ALP | 37.8 | 36.5 | 36.5 | 24.2 | -12.3 |
| LNP | 33.6 | 31.0 | 32.0 | 27.4 | -4.6 |
| OTH_RIGHT (KAP, 2 cands) | 8.2 | 7.6 | 7.2 | 18.1 | +10.9 |
| IND (3 cands) | 2.2 | 8.4 | 8.7 | 11.4 | +2.7 |
| OTH | 0.0 | 0.7 | 0.7 | 5.9 | +5.2 |

**Which number was wrong.** Labor's primary (a 12.3 over-call), and the Katter's Australian Party vote under-called by 10.9. The LNP primary was OVER-called, not under (-4.6); the LNP won because a three-way fragmentation left a 27.4 plurality. TCP: we picked ALP at 53.0, actual ALP 47.3, err -5.7 (z -1.45).

**Where it arose.** The base: ALP err -13.6, OTH_RIGHT +9.9. Nothing downstream moved it.

**Same as neighbours?** Partly, two separate things:
1. Retirement. Curtis Pitt (Labor, member since 2006, won 49.9 in 2020) announced retirement on 22 August 2024 (`external/reference/retirements/retirements-new-pairs.csv`, 2 months before the election). Retiring Labor members in qld2024 ran -4.43 (n 5, SE 2.94) against the party's own errors; across five state elections retiring Labor members ran -2.0 on average (n 34; qld -4.43 n 5, wa -2.24 n 10, nsw -2.34 n 2, sa -1.70 n 6, vic -0.75 n 11).
2. KAP in north Queensland. OTH_RIGHT errors in the region: Cook +11.0, Mulgrave +10.9, Thuringowa +6.3, Mundingburra +6.0, Barron River +5.6.

**Verdict.** CONFIRMED mechanism: Labor lost 25.7 points (49.9 to 24.2) when its dominant long-term member retired and the Katter vote (a 16.2% candidate, Steven Lesina) rose; the model had Labor losing 13.4 and the KAP class at 7.2. LIKELY the retirement effect is under-sized (see shared cause D) and that the KAP regional wave was not predictable from our inputs. FIXABLE-IN-MODEL in part (retirement size).

---

## 9. sa2026 Bragg

**Result.** LNP's Jack Batty held the seat: LNP 48.3 (the candidacy file shows 50.0 on 21,511 votes; see caveat), two-candidate LNP 58.5 over ALP. We favoured Labor's Rick Sarre (ALP 35.3 versus LNP 38.8 on primaries) at 0.795. Winner 0.190 (AEF 0.540).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| LNP | 39.7 | 39.7 | 38.8 | 48.3 | +9.6 |
| ALP | 35.6 | 35.1 | 35.3 | 28.2 | -7.1 |
| GRN | 19.7 | 19.3 | 19.9 | 13.3 | -6.6 |
| ONP | 0.0 | 1.6 | 1.6 | 9.1 | +7.6 |

**Which number was wrong.** Everything: the LNP too low by 9.6, ALP and Greens too high by 7.1 and 6.6, ONP too low by 7.6. TCP: we picked ALP at 53.8, actual ALP 41.5, err -12.3 (z -2.84), the worst TCP z of the 13. Here the primaries produce the TCP error directly.

**Where it arose.** The base, and unchanged afterwards (LNP err +8.7, +8.6, +9.6). The base predicted the LNP falling 15 points from its 2022 general-election share (53.8; the July 2022 by-election gave the LNP 50.5, ALP 30.0, GRN 14.9) with Labor and Greens each rising by 7 (to 35.3 and 19.9). In fact the 2022 result essentially held: the LNP lost about 5.5 to the new ONP candidate, Labor and Greens did not move.

**Same as neighbours?** Yes, a SA-wide pattern in LNP heartland seats. LNP errors among seats the LNP held with 45+ in 2022: Schubert +13.1, Bragg +9.6, Dunstan +7.1, Morphett +5.3, Black +4.5, MacKillop +3.7, Unley +3.4, Flinders +3.0 (the model took far too much off the LNP). In the 8 LNP-vs-ALP peers Bragg is worst on both parties. ONP was under-called in SA overall (+3.04, n 47), and Bragg's +7.6 is 4.6 above that mean.

**Verdict.** LIKELY: (1) the base removes too much from safe LNP seats in an election with an ONP surge (the LNP-held-seat error is positive almost everywhere), (2) the ONP candidate here was given 1.6 against 9.1 (shared cause A). To confirm: regress the sa2026 LNP error on the 2022 LNP share and on the base's predicted fall; run the base with ONP set to its actual share in Bragg and see how much of the +9.6 closes. FIXABLE-IN-MODEL.

Caveat: `output/candidacies.csv` gives sa2026 Bragg as LNP 10,761, ALP 5,976, GRN 2,736, ONP 1,844 (LNP 50.0%, ALP 27.8%, GRN 12.7%, ONP 8.6%), while `published-predictions.csv` has actual LNP 48.3 / ALP 28.2 / GRN 13.3 / ONP 9.1. The two disagree by up to 1.7 points. I did not find which is the final ECSA count; neither changes the conclusion.

---

## 10. wa2025 Kalamunda

**Result.** The LNP's Adam Hort won by a hair: two-candidate LNP 50.1 to ALP 49.9 (0.2 points). LNP class primary 40.5 (Hort 31.4 plus a second LNP-class candidate, Logan, 9.1). We favoured Labor (Beale, ALP 37.6 versus LNP 39.9 on primaries, with Greens preferences) at 0.884. Winner 0.113 (AEF 0.662, so AEF was far better).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| LNP | 38.2 | 39.4 | 39.9 | 40.5 | +0.6 |
| ALP | 39.3 | 37.4 | 37.6 | 32.2 | -5.4 |
| GRN | 11.7 | 14.1 | 13.8 | 14.8 | +1.0 |
| ONP | 1.9 | 1.8 | 1.7 | 4.9 | +3.1 |
| OTH_RIGHT | 2.0 | 3.1 | 3.0 | 4.1 | +1.0 |

**Which number was wrong.** The winner's primary was right (+0.6); the problem was Labor's, over-called by 5.4, with ONP and OTH_RIGHT under-called by 4.1 together. TCP: we picked ALP at 55.4, actual ALP 49.9, err -5.5 (z -1.2). This is a flow/two-candidate call arising from primaries: the right-bloc total (LNP + ONP + OTH_RIGHT) was 44.6 predicted, 49.5 actual.

**Where it arose.** The base (ALP err -7.1) and not corrected much (-5.1, -5.4). ONP was wrong at every stage (+2.9, +3.0, +3.1).

**Same as neighbours?** Partly. WA ALP overall -1.07, so Kalamunda's -5.4 is 4.4 below that. Peers: ALP -0.32 (SD 4.18), LNP -3.00; Kalamunda's LNP +0.6 is the second best of 23 and ALP -5.4 the 4th worst of 23. Labor seats that were safe in 2021 and lost the most in 2025 were outer or regional: Baldivis -10.4, Geraldton -8.3, Forrestfield -8.0, Murray-Wellington -6.5, Fremantle -5.8, Kalamunda -5.4. Inner or western seats (Scarborough +8.5, Bateman +7.3) did better than predicted. ONP was under-called by 3 to 7 points in the same outer/regional set.

**Verdict.** LIKELY, two parts. (1) Labor's retiring member (Matthew Hughes, `retirements.csv` wa2025, announced 9 February 2024) in a seat Labor held at 51.3 only because of the 2021 landslide (37.1 in 2017). The ALP fell 19.1 against a predicted 13.7. (2) ONP under-called (shared cause A), which feeds LNP preferences. To confirm: rerun Kalamunda with ONP at the WA mean error added back; the 3 points of extra ONP at roughly 65 to 80% LNP flow would move the TCP about 2 to 2.5, a little under half of the 5.5 miss. Because the actual result was 50.1 to 49.9, even a perfect model would have given the LNP about 0.5. FIXABLE-IN-MODEL for the ONP part; the rest NOT.

---

## 11. wa2025 Murray-Wellington

**Result.** The LNP's Bolt won: two-candidate LNP 51.7. LNP class primary 40.9 (Bolt 33.9 plus second LNP-class candidate Gillett 7.1). We favoured sitting Labor member Robyn Clarke (ALP 41.3 versus LNP 40.6) at 0.804. Winner 0.194 (AEF 0.278).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| ALP | 41.8 | 41.0 | 41.3 | 34.8 | -6.5 |
| LNP | 37.5 | 39.8 | 40.6 | 40.9 | +0.4 |
| ONP | 2.5 | 2.0 | 2.1 | 8.5 | +6.4 |
| OTH_RIGHT | 2.5 | 4.7 | 4.6 | 5.0 | +0.4 |

**Which number was wrong.** The ALP primary (-6.5) and the ONP primary (+6.4). The LNP primary was right. TCP: we picked ALP at 54.0, actual ALP 48.3, err -5.7 (z -1.2).

**Where it arose.** The ONP error is in the base (+6.0) and the tree (+6.4); the Labor error is also in the base (-7.1) and the tree (-6.3). So it is stage-independent.

**Same as neighbours?** Yes. ONP in Peel/regional WA seats: Mandurah +6.8, Roe +6.0, Darling Range +6.0, Baldivis +6.1, Collie-Preston +5.2; WA mean +3.33 (n 41, SD 2.1). Murray-Wellington's +6.4 is 3.1 above the WA mean. Peers: LNP -2.91, ALP -0.07 (n 26); this seat has ALP at rank 2nd worst of 27.

**Verdict.** CONFIRMED (the ONP number is wrong by 6.4; ONP had 11.3 in 2017, nothing in 2021, and 8.5 in 2025, and the model treated it as a 2% candidate). LIKELY (an assumption about flows) that the ONP under-call is the main reason the seat flipped: at 65 to 80% LNP flow, 6.4 points of extra ONP is 4 to 5 TCP points, nearly all of the 5.7 miss. Plus Labor's heavy 2021-landslide reversion (57.9 to 34.8, a fall of 23 against the 16.6 predicted). To confirm: rerun with ONP at its actual 8.5. FIXABLE-IN-MODEL (shared cause A).

---

## 12. nsw2023 Holsworthy

**Result.** The LNP's Tina Ayyad won: LNP class 41.9, two-candidate LNP 50.4. We favoured Labor's Mick Maroney (ALP 42.9 versus LNP 39.4) at 0.787. Winner 0.209 (AEF 0.546).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| LNP | 38.3 | 38.7 | 39.4 | 41.9 | +2.5 |
| ALP | 41.7 | 42.9 | 42.9 | 39.5 | -3.3 |
| ONP | 5.7 | 4.9 | 4.8 | 8.5 | +3.7 |
| GRN | 7.4 | 7.5 | 7.3 | 5.6 | -1.7 |
| IND | 6.9 | 6.0 | 5.7 | 4.5 | -1.2 |

**Which number was wrong.** A small error on every class: LNP +2.5, ALP -3.3, ONP +3.7. TCP: we picked ALP at 53.1, actual ALP 49.6, err -3.5 (z -0.69), a coin-flip seat decided by 0.8 points. This is the nearest of the 13 to a "spread, not level" miss.

**Where it arose.** The base (LNP +3.6, ALP -2.2, ONP +2.8); not corrected.

**Same as neighbours?** The ONP miss is part of a state pattern: nsw2023 ONP +6.34 on average in the 17 seats where it stood (they got 9.7, we gave 3.4), and in comparable outer-Sydney seats ONP was under-called by 3.7 to 6.0 (Holsworthy +3.7, Leppington +4.2, Wollondilly +6.0, Badgerys Creek +6.0, Camden +5.9, Cronulla +4.0). The ALP miss is seat-specific: NSW ALP was -0.22 on average, peers -0.42 (SD 4.7), so -3.3 is within 1 SD. The LNP was over-called statewide (-1.51), so Holsworthy's LNP +2.5 runs against the state.

**Verdict.** CONFIRMED for the ONP part (3.7 points under, in a seat where ONP had 8.1 in 2019 and we predicted a fall to 4.8); LIKELY that this is most of the TCP error (3.7 points at 65 to 80% LNP flow is about 2.4 to 3.0 of the 3.5). The LNP also benefited from an open seat (Melanie Gibbons, the 2019 member, did not stand again: `candidacies.csv` has a new LNP candidate). To confirm: rerun with ONP at 8.5. FIXABLE-IN-MODEL (shared cause A). Otherwise an ordinary tail on a coin flip.

---

## 13. vic2022 Northcote

**Result.** Labor's Kat Theophanous held the seat: ALP 40.6, two-candidate ALP 50.2 over Greens 49.8 (0.4 points). We favoured the Greens' Campbell Gome (GRN 37.4 versus ALP 34.0) at 0.821. Winner 0.146 (AEF 0.162).

| class | base | xgb | published | actual | err (pub) |
|---|---|---|---|---|---|
| GRN | 38.0 | 36.6 | 37.4 | 30.0 | -7.4 |
| ALP | 33.5 | 34.5 | 34.0 | 40.6 | +6.6 |
| OTH (3 cands incl. Victorian Socialists' Kath Larkin) | 8.1 | 6.9 | 6.6 | 11.9 | +5.3 |
| IND (2 cands) | 5.8 | 6.3 | 5.7 | 1.4 | -4.3 |
| LNP | 9.1 | 10.1 | 11.5 | 12.2 | +0.7 |

**Which number was wrong.** The Greens' primary (too high by 7.4) and Labor's (too low by 6.6); the minor-left vote (OTH) was also under-called by 5.3. TCP: we picked GRN at 54.2, actual GRN 49.8, err -4.4 (z -1.2).

**Where it arose.** The base (GRN err -8.0, ALP +7.1); unchanged by the tree (-6.6, +6.1) and the published stage (-7.4, +6.6). Prior (2018): ALP 41.7, GRN 39.5; the model took 7.7 off Labor and 2.1 off the Greens, and actually Labor fell 1.1 and the Greens 9.5.

**Same as neighbours?** The Greens fell in the inner north in 2022: Melbourne -7.1, Essendon -4.4 (Greens 5 high-share seats in vic2022 averaged -3.59, n 5, SD 3.48), but Brunswick was +0.3 and Richmond -1.9. Statewide Greens were -1.05 and Labor -0.69, so Northcote's misses are 6 to 7 points beyond the state.

**Verdict.** LIKELY, three overlapping parts: (1) the Greens' vote leaked to the Victorian Socialists (OTH went from 5.8 to 11.9); (2) Labor's incumbent was not credited. I believe Theophanous had been the member since the December 2020 by-election, which is not in `external/reference/byelections/byelection-winners.csv` (it lists only the 2017 Northcote by-election, won by the Greens); this is from my memory, not the files, so check it. The model's prior treats the 2018 Greens win as the seat's last result and removes the Labor candidate's personal vote. (3) the general inner-city Greens over-call (shared cause C). To confirm: add the 2020 by-election to the file and re-score Northcote; check the sophomore term. FIXABLE-IN-MODEL if the by-election gap is real (it would also be shared cause E).

---

## Summary table

| seat | cause | CONFIRMED / LIKELY | fixable in model? |
|---|---|---|---|
| fed2025 Dickson | national Labor under-call plus published-stage step (leader bonus, seat-poll blend) moved a correct tree LNP +5.5 | LIKELY (national part confirmed) | Partly: the published step yes, the national part no |
| fed2025 Melbourne | national Labor under-call; extra Labor-over-Greens move in inner seats; tree and leader bonus pushed Greens up while polls said 43 | LIKELY | Partly |
| fed2025 Griffith | tree carried the fed2022 Greens uplift into a reversal; national Labor under-call | LIKELY | Partly |
| fed2025 Bonner | national Labor under-call plus an unusually large Brisbane-marginal Labor swing already wrong in the base | LIKELY | No |
| fed2025 Menzies | national Labor under-call on a 51-49 seat | CONFIRMED | No (ordinary tail) |
| qld2024 Bundaberg | Labor sophomore incumbent outperforms the model | LIKELY | Yes (first-term-incumbent term) |
| qld2024 Capalaba | seat-specific; no mechanism found; published stage added 2.3 to ALP | LIKELY (unresolved) | Probably no; trace the published step |
| qld2024 Mulgrave | long-serving Labor member retired (-25.7 ALP) plus KAP surge (16.2% candidate) | CONFIRMED mechanism; retirement-size part LIKELY | Partly (retirement effect size) |
| sa2026 Bragg | LNP heartland retained, base removed 15 points; ONP candidate given 1.6 vs 9.1 | LIKELY | Yes |
| wa2025 Kalamunda | ALP retiring member plus 2021-landslide reversal; ONP under-called by 3.1; seat decided 0.2 points | CONFIRMED (ONP number), LIKELY (flow effect) | Partly (ONP yes) |
| wa2025 Murray-Wellington | ONP under-called by 6.4 (and Labor 2021 landslide reversal) | CONFIRMED (number), LIKELY (effect on result) | Yes (ONP level) |
| nsw2023 Holsworthy | ONP under-called by 3.7 on a coin-flip seat | CONFIRMED (number), LIKELY (effect on result) | Yes (ONP level) |
| vic2022 Northcote | Greens leak to Victorian Socialists, Labor incumbent not credited (by-election gap, to be checked), inner-city Greens over-call | LIKELY | Yes, if by-election gap is real |

## Causes shared by two or more seats (candidates for pre-registration)

Ordered by how many seats and how well the numbers support them.

**A. ONP under-called in state elections where it returned or surged (Kalamunda, Murray-Wellington, Holsworthy, Bragg; Mulgrave weakly).** Mean ONP error in seats where ONP stood: wa2025 +3.33 (n 41), nsw2023 +6.34 (n 17), sa2026 +3.04 (n 47), vic2022 +4.98 (n 5, all predicted 0); qld2024 -0.14 and fed2025 -1.47 show no such bias, so it is election-level, not a general ONP bias. The ONP-per-seat spread inside an election is small (SD 2.1 in WA), so most of it is one missing level for the state. ONP votes go mostly to the LNP, so the error lands in the two-candidate result. Pre-register: set ONP's statewide level from the previous ONP result and polls when a candidate stands in a seat where it stood before, and score the four seats plus the other ONP-contesting seats. CONFIRMED that the under-call exists; LIKELY that it flips these seats.

**B. fed2025 national Labor under-call (Dickson, Bonner, Menzies; part of Griffith, Melbourne).** ALP +3.58, LNP -2.46 over 150 seats. Present in the base and shared by every seat-poll set we have; Labor incumbents were under-called most (+4.59 vs +2.82 for non-incumbents). Cannot be fixed at seat level; the statewide/national level step is the place, and the question is whether the pre-election trend lagged the final-week swing (the vic2022 note in the registry says this happened there too: "day-before trend lagged late polls").

**C. Greens high-share seats over-called, Labor under-called, beyond the national shift (Melbourne, Griffith, Northcote).** Evidence: seven fed2025 Greens-versus-Labor seats ALP +6.1 against national +3.58; vic2022 Greens in seats at 20+ averaged -3.59 (n 5); qld2024 -3.88 (n 8); fed2025 -0.90 (n 15, 5 over-called by more than 3, 2 under-called). The tree added to the Greens in Melbourne (+3.6) and Griffith (+6.0) relative to the base. Pre-register: cap or shrink the tree's Greens uplift in seats over 30%, and test the minor-party-leader bonus (residual -2.53, SE 3.77, n 8, so it is not distinguishable from zero but its sign is wrong in Melbourne).

**D. Retiring or long-serving Labor member loses more than modelled (Mulgrave, Kalamunda).** Retiring Labor members: qld -4.43 (n 5), wa -2.24 (n 10), nsw -2.34 (n 2), sa -1.70 (n 6), vic -0.75 (n 11); pooled about -2.0 (n 34). These are raw errors, not adjusted for each election's Labor bias (all small). Pre-register: a retirement term for the retiring member's party estimated on earlier elections only.

**E. Sophomore incumbent outperforms (Bundaberg; Northcote if the by-election gap is real).** Labor MPs who gained the seat at the previous election and re-stood: +3.97 (SE 0.71, n 39) against +0.60 (SE 0.24, n 309) for longer-serving ones; positive in every one of the six elections (fed2025 +6.0 n 9, nsw2023 +9.6 n 2, qld2024 +1.7 n 4, sa2026 +4.7 n 8, vic2022 +2.2 n 5, wa2025 +2.4 n 11). This is a raw gap between two error means, not controlled for seat margin, and the sophomore group is mostly marginal seats, so a margin control is part of the pre-registration.

**F. Published-stage step worsened a seat (Dickson clearly; Capalaba unexplained).** In Dickson the tree was right on the LNP and the published stage added 5.5; in Capalaba it added 2.3 to Labor. In Griffith and Mulgrave the same stage helped. The files do not separate the components (leader bonus, seat-poll blend, rescaling), so the first step is to emit stage-wise intermediates for these seats.

## What I could not determine, and where I looked

- Which published-stage component moved Dickson (+5.5 LNP) and Capalaba (+2.3 ALP): `forecasts.csv` stops at the tree; no intermediate file separates the leader bonus from the seat-poll blend. Looked in `output/` and `R/seat_poll_blend.R` names only (did not run anything).
- Capalaba: no mechanism found in `external/reference/retirements`, candidacies, or the neighbouring Redlands seats.
- Northcote: whether the December 2020 by-election (Theophanous) is missing from `byelection-winners.csv` is from memory; the file lists only the 2017 Northcote by-election. Needs a check against Wikipedia's Victorian by-election list.
- sa2026 Bragg: `candidacies.csv` and `published-predictions.csv` disagree on the actual primaries by up to 1.7 points (LNP 50.0 vs 48.3).
- ONP preference flow into the LNP (65 to 80%) is a rough range from `docs/CONSTANTS.md` (the implied two-party weights give ONP 0.35 to Labor) and my assumption for the state seats; I did not recompute seat-level flows, so the "ONP explains X of the TCP miss" statements are LIKELY, not CONFIRMED.
- Candidate-level facts (Pitt's retirement date, Hughes' retirement, Gibbons not standing, Batty's by-election) come from the repo's reference files except where stated as from memory.

## Correction, same evening (main session, checked against output/published-predictions.csv and output/level-pred.csv)

Cause A is two different things, not "one missing ONP level":
- **Level miss where ONP stood everywhere or nearly:** sa2026 (47 of 47 seats) level 20.39 vs actual 22.98; wa2025
  (41 of 59) level 1.94 vs 4.03. Late polls would not have fixed it in general: across 16 elections with an ONP poll
  in the final 28 days, the 28-day poll mean has MAE 1.90 against our level's 1.60, and over-calls ONP by 1.05 on
  average (scratchpad check, 19 Oct). Not a late-poll blend fix.
- **Partial contests are not concentrated:** where ONP stood in a subset of seats, its statewide level is not
  concentrated onto them. nsw2023: ONP in 17 of 93 seats, level 1.84 (actual 1.80, correct), but we gave ~2 to 5 in
  each contested seat against 5 to 15 actual (1.84 x 93/17 = 10.1 expected per contested seat). sa2022: ONP in 19 of
  47 seats, predicted exactly 0 in all 19 (actual 3 to 11); nsw2019 likewise 0 in its 12. Mechanism NOT yet traced
  (suspects: nomination zeroing hands a non-contesting seat's share to that seat's other parties, not to the party's
  contested seats; and ONP not modelled as its own class in low-level elections, possibly counted under OTH_RIGHT).
  General, not ONP-only: any minor party standing in a subset of seats is exposed (Victoria 2026: Legalise Cannabis,
  Family First, Libertarians).

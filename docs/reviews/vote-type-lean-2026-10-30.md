# Is a seat's vote-type lean stable enough to predict? (2026-10-30)

Script: `scripts/analysis_vote_type_lean.R` (rerun from repo root; tables land in the session scratch folder). Data: `external/reference/aec/fed{2004..2025}-firstprefs.csv` and `-tcp.csv` (AEC "by candidate by vote type"), 8 elections, 150-151 divisions each (1,202 division-elections; 9,763 first-preference rows). Vote-type columns sum to the total on every row (asserted).

**Answer: yes, worth adding as a prior.** The seat-specific postal, absent and pre-poll lean carries over from one election to the next (correlation 0.6-0.7 once the national shift is removed), and predicting it cuts the error on the final postal share of a party in a division by roughly half against assuming the ordinary share. The national shift alone is less than half of that gain. Provisional votes are the exception (too small, too noisy). For the question the night model really cares about, seats that flip, the gain is real but small in number: 7 flips in two elections.

## Method

- Vote types in the file: Ordinary, Absent, Provisional, PrePoll, Postal. **Unverified:** I believe `PrePollVotes` is declaration pre-poll only and that ordinary pre-poll centres are inside `OrdinaryVotes` (they are counted as polling places). I did not check this against booth files, so "ordinary pre-poll separable" is not done. If ordinary pre-poll sits in Ordinary, the pre-poll gap below is the declaration pre-poll gap, as the brief wants.
- Class: `classify_party(PartyNm, PartyAb)`, with everything not ALP/LNP/GRN/ONP/IND folded to OTH. Division key is the upper-cased division name. Boundaries change at redistributions and are not adjusted; a same-named division is treated as the same seat (this adds noise, and is a reason the true stability may be a little higher).
- Gap = share of the division's formal votes of that type won by the class, minus its share of ordinary votes, in points. A division-type is used only if the type has at least 300 formal votes (provisional 100). TCP gap is the same on the two-candidate count, keyed by finalist class (5 of 1,202 division-elections dropped because both finalists share a class).
- National component = vote-weighted national gap for that election, class and type. Seat-specific = gap minus that. A second split removes the state mean instead.
- Prediction, for 2022 and 2025: (a) ordinary share; (b) a + last election's national gap for the class and type; (c) b + slope x last election's seat-specific gap, with the slope fitted through the origin on all earlier election pairs only (time-forward, no leakage; slopes printed in the output are 0.60-0.78 postal/absent/pre-poll, 0.30-0.39 provisional); (c2) the same with the mean of the last two elections' seat gaps. Two diagnostic columns add the real national gap of the target election, which is not knowable on the night.
- Whole-division flip test uses the real volume of every vote type (an oracle on volumes, because on the night the volumes are the other uncertainty) and swaps predicted shares in.

## 1. National gaps move a lot and the 2022 postal shift was large

Vote-weighted gap, points, vote type share minus ordinary share, by election. Magnitude is what matters; there is no good direction. Selected rows (full table in the script output).

| class | type | 2013 | 2016 | 2019 | 2022 | 2025 |
|---|---|---|---|---|---|---|
| LNP | Postal | 6.67 | 6.89 | 7.19 | 5.83 | 5.72 |
| ALP | Postal | -1.75 | -3.68 | -3.16 | 0.18 | 0.92 |
| LNP | Absent | -6.04 | -5.49 | -6.76 | -8.26 | -7.00 |
| GRN | Absent | 4.11 | 5.15 | 6.67 | 7.03 | 6.58 |
| LNP | PrePoll | 1.13 | 1.13 | -1.68 | -2.16 | -1.62 |

Share of all formal votes by type, percent (context for how much is uncounted on the night): postal 5.0% (2004), 8.3% (2019), 14.3% (2022), 13.2% (2025); absent 3.3%; pre-poll declaration 3.4%; provisional 0.2%. Postal is the large block.

## 2. Stability, election t-1 to t, same division and class

Correlation and OLS slope of the gap at t on the gap at t-1, 7 election pairs pooled, n = division-class pairs. Higher is more stable; 1.0 is identical. Slope is the shrinkage factor.

| type | component | n | cor | slope (se) |
|---|---|---|---|---|
| Postal | total | 4704 | 0.886 | 0.862 (0.007) |
| Postal | seat-specific (national removed) | 4704 | 0.694 | 0.682 (0.010) |
| Postal | seat-specific (state removed) | 4704 | 0.694 | 0.685 (0.010) |
| Absent | total | 4704 | 0.888 | 0.954 (0.007) |
| Absent | seat-specific (national removed) | 4704 | 0.739 | 0.795 (0.011) |
| PrePoll | total | 4704 | 0.716 | 0.736 (0.010) |
| PrePoll | seat-specific (national removed) | 4704 | 0.598 | 0.622 (0.012) |
| Provisional | total | 4168 | 0.704 | 0.725 (0.011) |
| Provisional | seat-specific (national removed) | 4168 | 0.330 | 0.351 (0.016) |
| Provisional | seat-specific (state removed) | 4168 | 0.208 | 0.220 (0.016) |

The total correlation is flattered by the national part (the Liberal postal lean is about +7 everywhere). The seat-specific line is the honest one. Removing the state mean instead barely changes it for postal, absent and pre-poll, so the seat-specific lean is local, not a state effect. (SEs are naive: pairs share divisions across elections and are not independent.)

By class, seat-specific postal correlation: ALP 0.71, LNP 0.71, GRN 0.78, OTH 0.62, ONP 0.54, IND 0.35 (n 1,035 each for the majors, 268 ONP, 296 IND). Independents are the least stable class, ONP/IND/OTH the thinnest. Absent: ALP 0.79, LNP 0.81, GRN 0.70, IND 0.67, ONP 0.34. Pair-by-pair, postal seat-specific correlation runs 0.64-0.76 with no trend, and the 2019 to 2022 pair (the postal-vote surge) held up at 0.65, 2022 to 2025 at 0.72. Provisional is 0.16-0.47 and improving.

### Same candidate versus same party class

Candidates who stood in the same division at both elections (surname plus first given name), seat-specific gap correlation. Higher is more stable. n = candidate pairs.

| type | group | n | person | class |
|---|---|---|---|---|
| Postal | all | 2588 | 0.711 | 0.689 |
| Postal | IND | 124 | 0.514 | 0.463 |
| Absent | IND | 124 | 0.864 | 0.855 |
| PrePoll | IND | 124 | 0.716 | 0.618 |
| PrePoll | all | 2588 | 0.654 | 0.586 |

Keying on the person is no worse than keying on the party class and is a little better for independents and pre-poll. For ALP/LNP/GRN (one candidate per class) the two are identical by construction, so the real test is independents, n = 124 recontesting. Small, so only modestly supportive. The person-level table is mine to flag: a person's "national gap" is undefined, so I centred on the class national gap. A first version centred on the person's own national gap produced zero for everyone and read as no stability; it was a bug, fixed before the numbers above.

## 3. Value on the night: prediction of the final vote-type share

Target: a class's share of that vote type's formal votes in a division, final count. Numbers: RMSE in points, lower is better. n = division-class pairs with enough votes. a = ordinary share only; b = + last election's national gap; c = + shrunk seat-specific gap (fitted time-forward); c2 = mean of last two elections' seat gaps; e = oracle national gap only (diagnostic).

| election | type | n | a | b | c | c2 | e (diag) |
|---|---|---|---|---|---|---|---|
| 2022 | Postal | 827 | 3.71 | 2.67 | 2.28 | 2.16 | 2.23 |
| 2025 | Postal | 838 | 3.91 | 2.53 | 1.84 | 1.79 | 2.45 |
| 2022 | Absent | 827 | 5.84 | 3.51 | 2.49 | 2.50 | 3.28 |
| 2025 | Absent | 838 | 5.61 | 3.61 | 2.35 | 2.32 | 3.53 |
| 2022 | PrePoll | 827 | 3.32 | 2.79 | 2.17 | 2.19 | 2.75 |
| 2025 | PrePoll | 838 | 3.23 | 2.76 | 2.13 | 1.99 | 2.71 |
| 2022 | Provisional | 810 | 4.97 | 3.87 | 3.50 | 3.44 | 3.43 |
| 2025 | Provisional | 605 | 5.06 | 4.32 | 4.00 | 3.96 | 4.03 |

Reading: (c) beats (a) by 40-50% on postal, absent and pre-poll in both elections; the seat part is worth more than last election's national gap (c below b everywhere), and c even beats knowing the real national gap (e) in 2025. In 2022 postal the real national gap (e, 2.23) beats b (2.67) because the pandemic reshuffled it, and c sits at 2.28; c2 is the best at 2.16. Provisional gains little (cor 0.2-0.4). By class (2022 and 2025 pooled), postal RMSE a to c: LNP 6.45 to 2.41, OTH 4.14 to 1.92, GRN 3.07 to 1.49, ALP 2.61 to 2.83 (b was 3.37; ALP is the only case where last election's national gap hurt, from the 2022 swing in Labor's postal share), IND 2.73 to 2.22, ONP 1.15 to 1.13 (nothing to gain). The "a" column equals the SD of the gap, as it must.

**Two-candidate preferred, ordinary-count leader's share of that type** (n = 150-151 divisions, 141-146 with a previous election):

| election | type | a | b | c | c2 |
|---|---|---|---|---|---|
| 2022 | Postal | 4.88 | 4.25 | 3.57 | 3.42 |
| 2025 | Postal | 5.60 | 4.21 | 3.20 | 3.13 |
| 2022 | Absent | 5.14 | 4.62 | 3.04 | 3.06 |
| 2025 | Absent | 5.05 | 4.88 | 3.37 | 3.12 |
| 2022 | PrePoll | 3.37 | 3.72 | 2.97 | 3.08 |
| 2025 | PrePoll | 3.84 | 3.80 | 3.08 | 2.81 |

On the two-candidate count the national gap is nearly useless (b about a, because the leader is a different side in different seats, and the leader's gap averages about -1.5) but the seat-specific part still takes 25-40% off (c). Postal and absent only; provisional 5.9 to 4.9 (no).

### Whole-division final TCP share of the ordinary leader

Uses real volumes of every type (oracle on volume). RMSE in points of the leader's final two-candidate share, lower is better; n divisions.

| election | n | ordinary share unchanged | b | c | c2 | e (diag) |
|---|---|---|---|---|---|---|
| 2022 | 151 | 0.77 | 0.65 | 0.56 | 0.54 | 0.57 |
| 2025 | 150 | 0.82 | 0.65 | 0.50 | 0.50 | 0.65 |

Declaration votes are about 20% of the count, so the whole-division error is under 1 point either way; (c) shaves about 35% off the ordinary-only error. Among divisions within 3 points of 50 (22 in 2022, 25 in 2025), mean absolute error falls from 0.745 to 0.391 (2022) and 0.743 to 0.426 (2025) with (c).

### Leader changes between ordinary-only and final

Counts of divisions. Flips = ordinary leader lost the final count. Catch = method puts the ordinary leader under 50%; false alarm = it does so for a leader who held. Small counts, read as anecdote not statistics.

| election | divisions | flips | caught b | caught c | caught c2 | false b | false c | false c2 |
|---|---|---|---|---|---|---|---|---|
| 2022 | 151 | 3 | 2 | 3 | 3 | 1 | 1 | 1 |
| 2025 | 150 | 4 | 1 | 1 | 1 | 0 | 1 | 1 |

All flips 2004-2025 in ordinary vs final count: 1, 6, 0, 2, 3, 1, 3, 4 (2004 to 2025). 2022 flips were Deakin, Menzies, Sturt (all ordinary leaders ALP/50.0-51.0%, final 49.3-49.8%): (c) caught all three, (b) two. 2025: Bean (ind), Goldstein (ind), Longman (ALP), Wills (GRN): (c) caught only Bean (49.72, on the line) and mispredicted a close hold as a flip once. Goldstein moved 51.70 to 49.92 and (c) predicted 50.37, closing most but not all of the gap; Wills moved 50.54 to 48.57 and no method saw it (predicted 50.54 to 50.75): that was a Greens-vs-ALP contest where the ordinary count itself was a poor guide. So (c) is a clear gain for the near-ties (2022: 3 of 3, 1 false alarm) and does not rescue seats that move 2 points against the trend.

## Caveats

- Redistributions (same name, different boundaries) are not handled; the true seat lean may be more stable than shown.
- Ordinary-only is not the same as "what is counted at 8pm": election night also has uncounted ordinary booths. This tests the declaration-vote adjustment in isolation.
- 2022 postal volume was 14% against 8% in 2019, so a night model sees a very different volume mix than the gap history. The gaps held up (cor 0.65) but the volume will have to come from elsewhere.
- Slopes are fitted on pooled classes per type. Class-specific slopes (independents lower, 0.35 postal) were not fitted; a per-class slope would likely help OTH/IND.
- 7 flips is far too few to measure flip-detection skill. The RMSE results, over about 840 division-class pairs per election, are the evidence; the flips are illustration.
- The voting-type columns in the AEC file combine early vote categories differently over time (the pre-poll declaration share falls from 8.2% in 2007 to 3.4% in 2025, with a policy change in the middle). Not investigated.

## Is it worth adding to the night model as a prior? Plan

Yes, for postal, absent and pre-poll declaration; no for provisional (leave at the pooled type_gap).

1. `project_seat_from_booths()` (R/booth_projection.R): today `type_gap` is pooled per vote type and shrunk `n/(n+5)` toward zero using only counted votes. Add a **prior** for the unseen declaration votes: gap_prior(class, type, seat) = national gap for that class/type from the previous election (estimate it from the previous AEC file, not hard-coded; the night's own pooled gap supersedes it as counted declaration votes arrive) + w x last election's seat-specific gap for that division and class (or the candidate, when recontesting). Use the mean of the last two elections for c2 where available (the gain over c is small: 0.05-0.2 points).
2. Shrinkage, in the repo's convention: w = tau^2 / (tau^2 + se^2) where tau^2 is the between-seat variance of the seat-specific gap and se^2 is the sampling variance of that seat's gap at its previous-election type volume. Rough empirical weights from the fit above: 0.67 postal, 0.78 absent, 0.62 pre-poll, 0.35 provisional (use the lower of the pooled slope and the precision weight; independents lower, around 0.4 in postal). These slopes were fitted through the origin on pairs before the target election; refit them in the pipeline from earlier elections only.
3. Combine with the night's own evidence: when the night has counted some declaration votes for the seat, the existing `n/(n+5)` shrink should go toward this prior rather than toward zero (the prior is the new centre). The prior's weight falls as counted declaration votes in that seat grow.
4. Validate with the night replay scripts on the seven test elections (Pete's rule: the plan is not shipped until measured). Success criterion to write before running: final-seat TCP RMSE and leader-flip catches on the 3 closest seats per election, scored against (a) the present rule.
5. Open question not covered: a prior for the volumes of postal, absent and pre-poll votes still to arrive. This analysis assumed the true volumes and only tested the shares.

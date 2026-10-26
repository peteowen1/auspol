# Launch prior: seats where the eventual winner got probability zero (2026-10-24, diagnosis only)

Pete's request, 2026-10-24: a founder or sitting defector carries their own personal vote into the new party or
label ("launch prior"). Nothing in `R/`, `scripts/`, `src/`, `tests/` was changed and no harness was run.
Scratch scripts: `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\597d5a10-bcc6-422e-a23c-66b6c6fb51da\scratchpad\newcomer\`
(`b.R`..`h.R`, flagged cases in `flagged.csv`).

**Short answer.** Of the 22 seat-elections with log loss above 4 (192.8 of the 954.4 total, 20.2%), only 6 are a person
the corpus could have flagged beforehand as someone carrying a personal vote (five sitting defectors, plus Wilkie as a
prior candidate under a new label). A launch prior on *sitting defectors* is worth about -0.003 to -0.005 pooled log loss
(1 to 1.5%). Extending it to *every returning candidate with a new label* costs more than it gains (n=368 flagged, 39 won).
The big zeros (Palmer, McGowan, Rob Katter, Butler, Brock, Davis) are people with no prior candidacy in the corpus, and
no launch prior built from `candidacies.csv` can see them.

Where the numbers come from: `output/biggest-misses.csv` (`metric == "logloss"`, 2931 seat-elections, 35 pairs, mean
0.3256, sum 954.38; `err` there is `-log(max(p, 1e-6))`, so 13.82 is the floor), `output/published-predictions.csv`
(per-class `p_win`, `ours`, `actual`, `prev_share`; 19,616 rows, same 35 pairs, winner log loss reproduces
biggest-misses to 4 dp except Kalgoorlie and Alfred Cove, 4-dp rounding of p), `output/candidacies.csv` (22,358 candidacies,
44 elections).

## 1. Case classification

Log loss is `-ln(probability we gave the eventual winner's class)`; higher is worse, 13.82 means we gave it under one
in a million. "Earlier candidacy" is the winner's own prior row in `output/candidacies.csv`, matched by surname and
given name (surname-only for early WA rows), any seat, any level; n/a means no earlier row found. The class column is
mine, and unconfirmed items are marked.

| pair | seat | winner (label) | our p | log loss | class | earlier candidacy in corpus (vote) |
|---|---|---|--:|--:|---|---|
| wa2001 | Pilbara | Graham (ALP to IND) | 0.0000 | 13.82 | a: sitting member changed label, same seat | Pilbara wa1996 ALP 63.8, sitting; won 54.6 as IND |
| wa2008 | Kalgoorlie | Bowler (ALP to IND) | 0.00005 | 9.90 | a: sitting member changed label AND seat | Eyre wa2001 ALP 42.4, Murchison-Eyre wa2005 ALP 51.8, both won; 34.0 as IND |
| qld2017 | Hill | Knuth (KAP) | 0.0003 | 8.11 | a (moved seat, same label; Hill is a new seat) | Dalrymple qld2009 LNP 41.4, qld2012 KAP 53.7, qld2015 KAP 41.6, all won; 48.2 in Hill |
| fed2013 | Kennedy | Bob Katter (IND to KAP) | 0.0059 | 5.14 | a: sitting member changed label (minor to minor) | Kennedy fed2004 IND 40.1, fed2007 39.5, fed2010 46.7, all won; 29.4 as KAP |
| qld2012 | Dalrymple | Knuth (LNP to KAP) | 0.018 | 4.02 | a: sitting member changed label (major to minor) | Dalrymple qld2009 LNP 41.4, won; 53.7 as KAP |
| sa2010 | Frome | Brock (IND) | 0.0000 | 13.82 | a, UNCONFIRMED: I believe he won the 2009 Frome by-election, so a sitting member with no row in the corpus | none (first row is sa2010 IND 37.7). The by-election table has no SA row before 2022 (`external/reference/byelections/byelection-results.csv`) |
| fed2010 | Denison | Wilkie (IND) | 0.0000 | 13.82 | b: prior candidacy, other seat, other label | Bennelong fed2004, The Greens 16.4, lost (NSW seat; Denison is Tasmanian) |
| nsw2019 | Murray | Dalton (SFF) | 0.0154 | 4.17 | b: non-sitting prior candidate, same seat, new label | Murray nsw2015 IND 18.2, lost; won 38.8 as SFF |
| fed2013 | Indi | McGowan (IND) | 0.0000 | 13.82 | b: prominent newcomer, no prior | none |
| nt2024 | Johnston | Davis (IND) | 0.0029 | 5.84 | b: newcomer, no prior | none |
| fed2013 | Fairfax | Palmer (PUP) | 0.0000 | 13.82 | c: new party launch, founder, nobody sitting | none |
| qld2012 | Mount Isa | Rob Katter (KAP) | 0.0000 | 13.82 | c: new party launch, nobody sitting (founder's family, UNCONFIRMED) | none |
| nsw2019 | Barwon | Butler (SFF) | 0.0001 | 9.21 | c: minor-party surge, newcomer | none |
| qld2017 | Hinchinbrook | Dametto (KAP) | 0.0010 | 6.86 | c: minor-party surge, newcomer | none |
| qld2017 | Mirani | S. Andrew (ONP) | 0.0032 | 5.76 | c: minor-party surge, newcomer | none (a federal Stephen Andrew CARSON in fed2013 is a different person, UNCONFIRMED) |
| fed2010 | Ryan | Prentice (LNP) | 0.0001 | 9.21 | e: sitting LNP member left and ran as IND (Johnson, 8.5%); the PARTY won | n/a (Prentice is a newcomer; Johnson was the 49.5% member) |
| qld2017 | Buderim | Mickelberg (LNP) | 0.0052 | 5.27 | e: sitting LNP member Dickson went to ONP (28.6%); party won | n/a |
| wa2017 | Hillarys | Katsambanis (LNP) | 0.0172 | 4.06 | e: sitting Liberal Johnson ran as IND (20.1%); party won | n/a |
| wa2001 | Kimberley | Martin (ALP) | 0.0000 | 13.82 | d: Labor returns to a seat held by independents in 1996; Labor base zero | "MARTIN" IND 29.3 at wa1996 (surname only; same person unconfirmed, the seat registry names a Brian Martin) |
| wa2005 | Alfred Cove | Woollard (IND) | 0.00045 | 7.71 | d: sitting independent, same label, recontested | Alfred Cove wa2001 IND 20.3, won; 24.0 |
| fed2025 | Melbourne | Witty (ALP) | 0.0060 | 5.12 | d: sitting Greens member (Bandt) lost on primaries | none |
| vic2014 | Prahran | Hibbins (GRN) | 0.0033 | 5.71 | d: primary was fine (GRN 22.0 vs 24.8), winner came through preferences | Malvern vic2010 GRN 14.2, Higgins fed2010 GRN 17.9, both lost |

Extra rows Pete named: qld2012 Hinchinbrook (winner Cripps, LNP, p 0.9946) and Thuringowa (Cox, LNP, p 0.78) were NOT
misses. KAP in Thuringowa took 32.9% against our 2.9% and lost, so they are the false-positive side of a Katter launch
prior, not zero-probability winners. Knuth's own seat in 2012 was Dalrymple (Hinchinbrook was won by LNP's Cripps).

Log loss by class (n is seats; total 192.83):

| class | seats | log loss | share of the 22 |
|---|--:|--:|--:|
| a sitting member changed label or seat (incl. Frome) | 6 | 54.81 | 28% |
| b prior or newcomer independent | 4 | 37.65 (prior candidacy 17.99, none 19.66) | 20% |
| c new or surging minor party, nobody sitting | 5 | 49.47 | 26% |
| e party kept seat, sitting member left | 3 | 18.54 | 10% |
| d other (Kimberley, Alfred Cove, Melbourne, Prahran) | 4 | 32.36 | 17% |

Twenty-two seats are 0.75% of the corpus and 20.2% of pooled log loss; the 8 seats under p 0.0001 are 11.2% (106.6).
The 2026-09-15 review (`emergence-is-the-prize-2026-09-15.md`) found the same concentration on 2064 seats (six seats
7.3%); this run has 2931.

Primary-vote view (published-predictions, our share vs actual): Pilbara IND 0.0 vs 54.6, Mount Isa KAP 2.0 vs 41.6,
Frome IND 1.5 vs 37.7, Denison IND 1.8 vs 21.3, Kalgoorlie IND 1.8 vs 34.0, Murray SFF 6.3 vs 40.3, Hill KAP 7.1 vs 48.2,
Barwon SFF 4.1 vs 36.4, Indi IND 5.2 vs 32.1. The share is wrong by 20 to 55 points, not by a margin a probability floor
repairs; a floor only gives the right *log loss*.

## 2. Why each class got zero

### a. Sitting member changed label (Graham, Bowler, Knuth, Katter)

The machinery exists and is mostly shipped; the zeros are gaps in it, not its absence.

- Shipped: `AUSPOL_DEFECT_DISCOUNT=1`, `AUSPOL_DEFECT_POOLED=2` (member 0.282 / losing candidate 0.142), `AUSPOL_DEFECT_BY_LEVEL=2`,
  `AUSPOL_MINOR_DEFECT=1` (minor-to-minor, median retention 1.08 for sitting members, Murray/Orange/Barwon),
  `AUSPOL_MINOR_DEFECT_BASE_PRED=1`, `AUSPOL_CROSS_SEAT_VOTE=1`, `AUSPOL_BYELEC_LEVEL=1` (all `scripts/published_flags.R`).
  `AUSPOL_MINOR_DEFECT` was not honoured by the harnesses until the 23 Oct fix (`docs/NEXT-STEPS.md` line 62), so the
  35-pair backtest numbers here may predate it for the minor-to-minor cases (Kennedy fed2013). UNCONFIRMED: which
  commit built `output/biggest-misses.csv` (dated 23 Oct 14:45) relative to that fix.
- Pilbara wa2001: `fit_defector_discount()` uses time-forward pairs only (`R/candidate_returns.R:1162`, `fit_pairs_for` at
  ~1196) and returns NULL below `min_n` = 5 (`:1234-1235`). wa2001 is the earliest WA target, so there are zero earlier
  cases, `.defect` stays NULL, and the whole defector block, gated on `!is.null(major_discount)` at `:844`, is skipped.
  IND gets the 1996 IND class share (about 0) and ALP keeps all 63.8. Diagnosed in `reviews/state-defectors-2026-10-06.md`
  (walk of Pilbara) and `SEAT-REGISTRY.md` ("not estimable from earlier data; a prior would be the fix"). This is the
  one case where only a *prior* (not a fit) can work.
- Kalgoorlie wa2008: three independent gaps (same review): the defector block merges on same seat and same person
  (`:849`, `:741`) and Bowler moved from Murchison-Eyre; `AUSPOL_CROSS_SEAT_VOTE` credits only earlier NON-major results
  (`R/cross_seat_vote.R:22-24`), and Bowler's was ALP; the fit had 4 cases against the cliff of 5. `AUSPOL_DEFECTOR_STATE=1`
  fixes all three and was REFUSED 6 Oct (22-election seat log loss +0.0090, SE 0.0056; wa2017 Hillarys +0.121, wa2008
  Morley over-called) and stays "0" (`published_flags.R:218`).
- Hill qld2017 and Dalrymple qld2012: Knuth. Hill is a new seat (Knuth sat for Dalrymple), so the same-seat match cannot
  see him; the cross-seat credit does apply (his KAP win in Dalrymple counts as personal, `cross_seat_vote.R:19-21`) but pays
  `carry * 41.6` with a fitted carry (`fit_cross_seat_carry`, `:166`) well below his realised 1.16 retention (48.2/41.6).
  We predicted 7.1; UNCONFIRMED: I did not read the CSV1 log line, so the carry value is inferred. Dalrymple 2012
  (LNP to KAP, realised carry 1.30) got KAP 25.7 against 53.7: the median carry (~0.28 to 0.4) is applied to a bimodal
  quantity (state sitting-member carries: 0.24 0.28 0.29 0.31 0.43 0.44 0.44 0.69 0.70 0.72 0.86 1.05).
- Kennedy fed2013: IND to KAP, minor-to-minor; our KAP 29.8 vs 38.9 is close on share, but KAP won only p 0.0059 because LNP
  36.7 and the seat spread favoured LNP (0.905). A share error of 9 points on a 30 point candidate is a spread problem, not a missing prior.

Root cause shared by all five: the sitting-defector carry is a single median applied to a bimodal outcome, and the
simulation spread around it (`seat_sim`) gives no mass to the high-retention mode. That is why Dalrymple, Kennedy and
Kalgoorlie sit at p 0.0001 to 0.02 with sensible-looking shares.

### b. Prior candidacy under a new label or in another seat

- Wilkie (Denison fed2010): his only corpus row is Greens 16.4% in Bennelong (NSW) fed2004. `personal_prior_vote()`
  (`R/candidate_returns.R:527`) matches the same seat at the previous election only. `cross_seat_vote.R` excludes him on
  three counts: Greens vote "neither side" (`:24`), personal credit only for IND wins, sitting or by-election winners
  (`:21-23`), and same-state only (`:15-17`, Bennelong is NSW, Denison TAS). Our IND was 1.8 (prev 0.0).
- Dalton (Murray nsw2019): IND 18.2 in 2015 (lost) to SFF 38.8. `AUSPOL_MINOR_DEFECT` applies the non-sitting rate (median
  0.276) so SFF got 6.3 against 40.3. The 2026-09-17 note in `personal_prior_vote()` already says the SFF cases
  (retention 1.08 to 1.36) behave like sitting members because Barwon, Murray and Orange were SFF seats by candidate, not by
  independent history; Dalton was a non-sitting loser, so the loser rate gave 0.276 x 18.2 = 5.0.
- McGowan (Indi), Davis (Johnston): no prior row, so no personal vote exists to launch from. The model's
  `AUSPOL_NEW_IND_SHRINK=1` (shipped) *lowers* first-time independents because they over-call on average (Victoria: +1.9 to +4.3
  points over-called, n 31/17/27).

### c. New party or surging minor party, nobody sitting

Palmer, Rob Katter, Butler, Dametto, Andrew have no prior candidacy, so there is no personal vote to carry. What a model
could see is the PARTY: PUP, KAP and SFF had no earlier results at those targets (KAP: zero rows before qld2012; PUP: zero
before fed2013). New parties "start at zero share" (`docs/NEXT-STEPS.md`, NT seat layer item). This is the gap the surge
work targets (`AUSPOL_XGB_SURGE`, AUC 0.936, refused on its criterion, harness-only; see `emergence-is-the-prize`) and the
2026-10-19 arm T (seat-poll mixture, -0.0004, SE 0.0052) was a different thing: it mixes seat-poll error, not a launch prior,
so its refusal says nothing about this idea (the claim "arm T was the heavy-tail version" is only partly right: the open
heavy-tail item at `NEXT-STEPS.md:72-74` is the general fat-tailed error, and arm T is its seat-poll form).

### d. Other (4 seats)

Kimberley wa2001: corpus starts at wa1996 and no Labor candidate stood in 1996 (SEAT-REGISTRY: Bridge IND 33.8, Martin IND 29.3), so Labor's base is zero. Alfred Cove wa2005: a sitting independent
(20.3% in 2001) was given IND 18.7 but p 0.00045 against LNP 44.7, which is a spread problem (win probability, not share).
Melbourne and Prahran are primary and preference effects respectively and are outside this idea.

### e. The party kept the seat (Ryan, Buderim, Hillarys; 18.54, 10% of the 22)

This is the mirror image and the most important caution. The defector machinery moves votes from the old party to the
defector: Ryan fed2010 gave IND (Johnson) 30.2 against 8.5 actual and LNP 18.5 against 45.7; Buderim gave ONP 46.2
against 28.6; Hillarys IND 28.6 against 20.1. Anything that raises defectors further raises these. Hillarys
(`SEAT-REGISTRY` line 203): the Liberal kept more of Johnson's old vote than the model lets a party keep from a departing
member. `defector-overcarry-2026-10-14.md` found no overall bias (52 cases, mean -0.35 points, SE 1.49) but misses of
both signs of 18 to 30 points, and the electorate-size arm (`AUSPOL_DEFECT_SIZE`) was refused.

## 3. Sizing

All figures from `output/biggest-misses.csv` and `output/published-predictions.csv`, n = 2931 seats; mean 0.3256 (sum 954.38).

### Contribution of the zero seats (a measured tally)

Log loss above 4: 22 seats, 192.8 (20.2%). Above 3: 39 seats, 252.1 (26.4%). Above 2: 83 seats, 358.3 (37.5%).
Winner p under 0.01: 19 seats, 180.6; under 0.0001: 8 seats, 106.6 (11.2%).

### Ceiling (oracle) if the named seats had been given 0.05

Each moved to ln(1/0.05) = 3.00. Class a (6 seats) + class b (4 seats, with Prahran counted in d) = 10 seats:
92.46 - 30.0 = 62.46, i.e. -0.0213 pooled (6.5% of 0.3256). This is an upper bound: it assumes the 10 seats could be
picked in advance.

### What an ex-ante flag could actually deliver

I rebuilt flags from the corpus using only earlier elections (scratch `f.R`; surname plus first initial, unique within
the election, previous election of the same level; heuristic, and false person-matches are possible, not audited).
Raising the flagged class to a floor f and rescaling the others in the seat, pooled change in mean log loss over all 2931
seats (negative is better). Winner counts are the flagged candidates who won.

| flagged set | flagged | won | floor 0.02 | floor 0.05 | floor 0.10 |
|---|--:|--:|--:|--:|--:|
| A: sitting member, different label (same seat or moved) | 50 | 14 | -0.0024 | **-0.0032** | -0.0037 |
| C: sitting member, SAME label, moved seat (Hill) | 80 | 71 | -0.0014 | -0.0017 | -0.0019 |
| A + C | 130 | 85 | -0.0038 | **-0.0049** | -0.0056 |
| B: non-sitting prior candidate (10% or more), new label | 368 | 39 | -0.0018 | +0.0006 | +0.0054 |
| B restricted to prior 15% or more | 299 | 35 | -0.0021 | -0.0003 | +0.0036 |
| B restricted to prior 15% or more, non-ALP/LNP label | 249 | 9 | -0.0021 | -0.0003 | +0.0035 |
| A + B (all) | 416 | 53 | -0.0042 | -0.0026 | +0.0015 |
| oracle: only the flagged candidates who won | 124 | 124 | -0.0074 | -0.0094 | -0.0114 |

Each row is its own simulation (flagged cells raised to the floor, others rescaled).

Summed log-loss change for A at 0.05: -9.28 over 2931 seats; the flagged cells that were actually raised (p under f): 25 of 50.
Among A cells with our p under 0.05: 25 cells, 4 won (Bowler, Katter, Knuth, Lambley Araluen nt2020) = 16%.
Among C cells under 0.05: 3, 1 won (Hill). Among B cells under 0.05: 305, 3 won = 1.0% (Wilkie, Dalton, White Noosa qld2017). Break-even hit rate for a floor f is roughly f / (f + ln(f/p0)) with p0 about 0.0005; for f = 0.05 that is about 1%, which
is where B sits, so B is a coin flip on this evidence and a blanket B floor is rightly not worth building.

### False-positive cost (the "cost side")

- A: 50 flagged (33 same-seat label changes, 17 label-and-seat), 36 lost. 25 A cells sit under p 0.05 (4 won, 21 lost);
  the floor costs something only on those 21 losers, the other 25 A cells are unchanged.
- B: 368 flagged, 329 lost; of them 305 sat under p 0.05.
- C: 80 flagged, 9 lost.
- At floor 0.05 the false-positive cost on A is paid inside the -0.0032 net, i.e. the net figure already includes it.

### Honest limits of the sizing

- The flag file is MY rebuild, not the model's matcher; the real gain depends on `personal_prior_vote()` matching.
  UNCONFIRMED against the production matcher.
- The floor is a probability-level device. Seat-level shares are 20 to 55 points off, so a floor leaves the shares wrong.
- Not measured: how many of the 14 won A cases the existing model already handles at p over 0.05 (the cell counts say 10 do (14 won, 4 of them under 0.05)).
- Not checked: the 2026-10-24 rebuild (if any) after the 23 Oct harness fix for `AUSPOL_MINOR_DEFECT`.

## 4. Data availability

Check of `docs/DATA-REGISTRY.md` (candidate-level corpus section) and disk:

| need | on disk? | where | gap |
|---|---|---|---|
| prior candidacies by person, any seat, any level | yes | `output/candidacies.csv` (22,358 rows, 44 elections, `name`, `elected`, `pcv`, `party_raw`) | WA early rows carry surname only (Graham appears twice in wa1996: Geraldton and Pilbara, so a surname-only key is ambiguous); corpus starts wa1996 |
| sitting-member flag | yes | `elected` column | by-election winners are NOT in it |
| by-election winners | partly | `external/reference/byelections/byelection-results.csv` (484 rows) | thin before 2014: fed 2008 only, no SA before 2022, QLD from 2020. Frome sa2009 is missing (UNCONFIRMED that it was a by-election; from memory) |
| party founding dates and founders (KAP 2011, PUP 2013, SFF) | no | nothing | would need hand-coding from pre-election archive captures (memory: fixed pre-election sources) |
| relatives and ex-party links (Rob Katter) | no | nothing | same |
| seat-level geography to move votes across seat redistributions | partly | notional seat shares (SNP1) exist for some states | Hill qld2017 is a new seat |

## 5. Proposed arm

The honest framing: this is NOT one arm. Class a is worth testing; classes b, c, d, e are not served by "carry the
founder's vote".

### Arm L1: sitting-defector high-retention mixture (the part that evidence supports)

What it does: for a person flagged as a sitting member at the previous election (corpus `elected` or by-election winner)
who now stands under a different label or in a different seat, give the new class a two-component mixture instead of
one median carry: with probability pi the candidate retains r_hi of their prior vote, otherwise r_lo (the current median
carry). Hooks into the existing per-seat insurgent mechanism in `R/seat_sim.R` (`surge_h`, `surge_party`, `surge_mu`,
`surge_sd`, `surge_from_zero`, parameters documented at `:240-290`), so no new simulator path is needed.

Fit, time-forward with shrinkage (no min_n cliff, repo rule):
- pi = (hi_count + k * pi0) / (n + k) on earlier sitting-defector cases, pi0 = pooled across levels, k = 3 pseudo-cases (same
  shape as `.DEFSTATE_K`, `R/defector_state.R:41`), where "hi" = realised retention above 0.6. Current evidence:
  state cases 5 of 12 are above 0.6 (0.69 to 1.05), federal 1 of 7 is not. The mode split is not predicted by any corpus
  column (`state-defectors-2026-10-06.md` section 3; `defector-overcarry-2026-10-14.md` part 2), so pi stays a base rate.
- r_hi = shrunk median of the hi cases, r_lo = the current carry.
- When n_total is zero (Pilbara wa2001), pi falls to pi0 from the other jurisdictions pooled (the existing
  `AUSPOL_POOL_BY_JURISDICTION` code can supply it, currently "0").

Switch names (proposed): `AUSPOL_LAUNCH_PRIOR` = "0" (off), "1" (sitting defectors, class a only), "2" (adds class C,
sitting member same label moved seat, which carries Hill); `AUSPOL_LAUNCH_PRIOR_K` = "3". Register in
`scripts/published_flags.R` in the same commit (repo rule), and wire all six backtest harnesses plus
`fit_seats_full.R` in one change (the "fix to one harness is a fix to all" rule; `docs/MODEL-REGISTRY.md` should show
YES in every column).

Where: the decision of *who* is flagged lives in `personal_prior_vote()` (`R/candidate_returns.R:527`), which already
returns `prev_was_mp`, `prev_party`, and `own_prev_pcv`; the cross-seat match is `.cs_match` (`R/cross_seat_vote.R:88`),
and `R/defector_state.R:60` already has `.defector_cross_seat_cases` (the Kalgoorlie/Bowler matcher). Reuse them; do not
write a third matcher.

False-positive guard (the Ryan/Buderim/Hillarys class e): the old party must keep its vote in the draws where the
defector fails, and in the draws where the defector holds, the old party gives up what the defector takes
(`AUSPOL_DEFECT_CONSERVE` already leaves the unclaimed vote with the old party; the mixture must sit on top of that rather
than replace it). Acceptance must include class e seats as named targets: Ryan fed2010, Buderim qld2017, Hillarys wa2017.

Expected size from section 3: -0.003 to -0.005 pooled seat log loss, with the 25 A cells under 0.05 (4 winners) carrying
it. Treat -0.003 as the planning number; it is a floor-style estimate, not a measurement of the mixture.

### Arm L2: leave B/C/D alone for now

- B (returning non-sitting candidate with a new label): break-even at the base rate; do not floor. If wanted, test only
  inside L1's machinery with pi shrunk toward ~0.01 so it is effectively off except for the high-prior cases.
- Wilkie-type (Greens candidate to independent in another state): cannot be carried by the existing rule (Greens vote is
  the party's); one case (n=1) cannot support a rule. REPORT, do not build.
- Palmer, McGowan, Rob Katter, Butler, Dametto, Andrew, Davis: no prior vote exists. The only handle is the PARTY surge
  (`AUSPOL_XGB_SURGE`, AUC 0.936, refused 2026-08/09 and harness-only), whose criterion was set before the prize was sized
  at 0.0164. Revisit that, not a launch prior. Do not fold it into L1.

### Pre-registration (draft, per `docs/PRE-REGISTRATION-RULES.md`)

- Commit before running: grid (pi0 pooled vs level-specific, k in {1, 3, 6}), r_hi definition (0.6), criterion, and the
  named do-no-harm set.
- Primary metric scoped to the change: seat-winner log loss on the A cells (n = 50) and C cells (n = 80), clustered SE by
  election; do-no-harm on all 35 pairs pooled (35 elections, 2931 seats) and AEF-7; class e seats Ryan, Buderim, Hillarys
  must not be worse by more than 1 SE.
- Size the metric's noise first (MDE). 14 winners among 50 A cells is thin; the oracle ceiling for the flagged set is
  -0.0094, so a realistic effect of -0.003 against SE 0.0013-0.0056 (the SEs of recent arms) may only be able to refuse. Say so
  before running.
- Screen with `scripts/quick_arm.R "AUSPOL_LAUNCH_PRIOR=1" --pairs=wa2001,wa2008,qld2012,qld2017,fed2013` (named
  targets first), then all 35 for shipping, as a deciding run (`scripts\deciding_run.ps1`). (Not run here.)
- Per-row walk with Pete first (`model-design` skill): Pilbara wa2001, Kalgoorlie wa2008, Dalrymple qld2012, Hill qld2017,
  Kennedy fed2013, then Ryan fed2010 and Hillarys wa2017 as the cost side.

## 6. What I did not verify

- That `output/biggest-misses.csv` (23 Oct 14:45) reflects the 23 Oct `AUSPOL_MINOR_DEFECT` harness fix.
- The `fit_cross_seat_carry` value used for Knuth in Hill 2017 (inferred from share 7.1 vs 41.6).
- Brock's 2009 by-election and Rob Katter's relation to Bob Katter (memory, no pre-election source captured).
- Whether the 1996 "MARTIN" in Kimberley is Carol Martin.
- The production person-matcher on my 50 A, 80 C and 368 B flags: the sizing uses my own simple key.
- No harness, `quick_arm.R` or rebuild was run; all simulation is a post-hoc floor on stored `p_win`.

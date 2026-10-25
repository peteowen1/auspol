# Where the Victorian forecast and the bookmakers disagree, and why (2026-10-25)

Question: in ten seats the published Victoria 2026 forecast and Sportsbet/TAB
(24 October capture, `docs/benchmarks/vic2026/2026-10-24/bookmaker-odds-top4.csv`)
are far apart. In each one, is the market likely right (we are missing something)
or are we, and what in our model produces our number?

**Short answer.** The cause is different in the two groups.

- **One Nation over-calls (Niddrie, Essendon, Lara, and Geelong/Sunbury on a smaller
  scale): we are probably wrong, and the cause is a specific input defect.** We
  allocate One Nation's 21.8% statewide vote to seats by ranking each seat on its
  2025 *federal House* One Nation vote. That number depends on who else stood
  for the House in 2025. In Maribyrnong and Corio no other right-wing minor party
  stood, so One Nation collected that whole vote (Maribyrnong ONP 2.4% with 7.5%
  other-right in 2022, then 6.9% with none in 2025). In Bendigo the Nationals ran
  hard (Coalition primary 26.6% to 40.2%) and squeezed One Nation. The 2025
  *Senate* One Nation vote has the same ballot in every seat and has none of this
  problem. Re-ranked on it, Niddrie drops from rank 73 of 88 to 48, Essendon from
  46 to 20, Lara from 87 to 72, Geelong from 70 to 49, and Bendigo West rises from
  29 to 50. That rank shift tracks the market's disagreement with us across all 57
  seats where both price One Nation: Spearman 0.56, and the sign agrees in 18 of
  the 21 seats where the gap is over 0.15.
- **Eastern Liberal-favoured seats (Box Hill, Ashwood, Glen Waverley, Bentleigh,
  Bayswater): unclear, leaning that the truth is between the two.** The market is
  pricing roughly a uniform two-party swing: statewide Labor two-party falls 6.9
  points (55.0 to 48.1), and every one of these seats has a Labor margin of 8.0 or
  less. Our model moves these seats only 1 to 5 points. It does that **by
  construction**: One Nation's vote is taken from every party in proportion to its
  size, seat by seat, so a seat where One Nation is weak gets most of Labor's
  statewide loss handed back. On top of that the xgb layer cuts about 3 points from
  the Liberal primary in all four seats where Labor's sitting member is
  recontesting. I could not run the stage-by-stage walk (see "What was not run"),
  so that xgb figure is inferred by subtraction. Our record in this group runs the
  other way from the market. In the vic2022 backtest we *under*-called Labor here
  (Box Hill +5.1 points, Ashwood +5.3, Glen Waverley +2.3), and AE Forecasts, which
  leaned further Liberal, was more wrong.
- **Bendigo West Nationals 0.55: probably wrong, the same 2025 federal Nationals
  campaign counted twice.** The seat-swing port moves 5.1 points from Labor to the
  Coalition because federal Bendigo swung 10.7 points two-party against Labor in
  2025, with the Nationals' candidate standing for the first time. The same
  campaign also pushes Bendigo West's One Nation ranking down (see above), so One
  Nation, which the market prices at 0.41, sits at 18.0% for us.

## Per-seat verdicts

Win probabilities (0 to 1) for the class each side disagrees on. Market = the
capture's "Bookies prob (margin removed)". Ours = the published `forecast-latest`
release of 2026-10-25 03:53 UTC, which matches the capture to within 0.01 in every
row.

| seat | class | market | ours | verdict | mechanism |
|---|---|---:|---:|---|---|
| Box Hill | Labor | 0.239 | 0.915 | unclear (we are too confident) | One Nation fill gives back Labor's loss in a low-One-Nation seat; xgb takes about 3 points off the Liberal (inferred) |
| Ashwood | Labor | 0.214 | 0.804 | unclear | same |
| Glen Waverley | Labor | 0.121 | 0.722 | unclear, closest of the group | same, plus port +1.1 to Labor |
| Bentleigh | Labor | 0.380 | 0.788 | unclear | same |
| Bayswater | Labor | 0.045 | 0.417 | market closer | Labor member departing (slope 0.62), but port +1.6 to Labor (federal Deakin/Aston swing) keeps it close |
| Niddrie | One Nation | 0.074 | 0.571 | **market likely right** | House-rank ordering (rank 73; Senate rank 48) gives ONP 27.8; on the Senate ordering 22.9 |
| Essendon | One Nation | 0.084 | 0.361 | **market likely right** | House rank 46 against Senate 20; ONP 22.6, Senate ordering 14.7 |
| Eureka | One Nation | 0.400 | 0.925 | both favour ONP; we are probably too confident | ranking is stable (81 House, 77 Senate); ONP 32.8 from the top of SA's spread |
| Lara | One Nation | 0.284 | 0.753 | **market likely closer** | House rank 87 is the 2nd-highest seat; Senate rank 72; ONP 34.0, Senate ordering 29.0 |
| Bendigo West | Nationals | 0.119 | 0.551 | **market likely right** | port moves 5.1 points Labor to Coalition from the 2025 Bendigo Nationals campaign; ONP under-ranked by the same campaign |

## How our number is built (the stages that matter here)

In `scripts/fit_seats_full.R`, in order:

1. **Base swing** (`:1236-1278`). Each class moves off its 2022 seat share
   toward the statewide forecast with `dev_slope()`: level_now + slope ×
   (seat share − 2022 state share). Major slopes (BF0m): Labor 0.922 when the
   sitting member is back, 0.620 when they have left; Liberal/National 0.877.
   Statewide forecast (FP0): Liberal/National 28.91, Labor 24.64, Greens 14.33,
   One Nation 21.77, others 10.34. In 2022 they were 34.38, 37.03, 11.50, 0.22 and
   16.87.
2. **One Nation allocation** (`:1317-1340`). Seats are ranked on the 2025 federal
   House One Nation vote measured in their own booths
   (`external/elections/federal-transposed-to-state.csv`), mapped onto South
   Australia 2026's spread of district shares, and stretched to a CV of 0.365.
   Then **every other class in the seat is multiplied by
   (100 − One Nation) / (sum of the others)**. With One Nation at 9.6% in Box
   Hill against 21.8% statewide, that factor is about 1.17, so Labor, Liberal and
   Greens are all scaled up 17%.
3. **xgb live layer** (`xgb_primary_predict_live`), then the **seat-swing port**
   (`R/seat_swing_port.R`: 0.424 × each seat's federal 2022-to-2025 two-party swing,
   centred, moved between Labor and Liberal), **demographic correction**,
   **leader-seat bonus** (+2.72 to Labor in Niddrie for Ben Carroll, from
   `output/leader-seat-vic2026.csv`), then simulation.

### Reconstruction by stage (inferred, not printed from a run)

Primary vote, percent. The base columns are recomputed from the formulas above
using 2022 results, the published statewide levels and the published One Nation
cell. "xgb (inferred)" is what is left once the base, port, demographic and leader
adjustments are taken off the published number, so it also absorbs renormalisation
and any rule I did not model (rounding up to about 1 point). Script:
`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\e7e809d4-b07a-4695-a3bd-7e8f88a19663\scratchpad\recon.py`.

| seat | Labor 2022 | Lib/Nat 2022 | ONP (ours) | fill factor | base Labor | base Lib/Nat | base Greens | port (to Labor) | demo Labor | xgb Labor (inferred) | xgb Lib/Nat (inferred) | published Labor | published Lib/Nat |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Box Hill | 41.3 | 35.2 | 9.6 | 1.16 | 33.1 | 34.3 | 19.6 | +0.4 | +0.5 | +0.5 | −2.9 | 34.6 | 30.9 |
| Ashwood | 40.3 | 37.2 | 9.5 | 1.16 | 32.1 | 36.5 | 20.5 | +0.3 | +0.6 | −0.1 | −2.8 | 32.9 | 33.4 |
| Glen Waverley | 40.6 | 40.2 | 9.7 | 1.13 | 31.7 | 38.6 | 14.1 | +1.1 | +0.5 | +2.1 | −2.8 | 35.5 | 34.6 |
| Bentleigh | 45.8 | 36.3 | 16.2 | 1.08 | 35.2 | 33.0 | 14.6 | +0.4 | +0.4 | −0.3 | −3.9 | 35.6 | 28.7 |
| Bayswater | 41.3 | 35.6 | 17.1 | 1.08 | 29.5 | 32.4 | 11.1 | +1.6 | 0.0 | +0.2 | +0.1 | 31.3 | 31.0 |
| Niddrie | 44.0 | 34.0 | 27.8 | 0.90 | 28.0 | 25.8 | 9.2 | −0.7 | +0.1 | +1.8 | −1.9 | 31.9 | 24.5 |
| Essendon | 41.1 | 29.5 | 22.6 | 0.98 | 26.4 | 23.9 | 17.5 | −0.3 | +0.4 | −1.6 | −1.2 | 24.8 | 23.1 |
| Eureka | 41.0 | 31.6 | 32.8 | 0.86 | 24.2 | 22.7 | 11.7 | −0.9 | −0.5 | +3.1 | −1.0 | 25.9 | 22.6 |
| Lara | 49.7 | 21.4 | 34.0 | 0.83 | 30.3 | 14.6 | 11.8 | −0.3 | −0.4 | +1.9 | −0.7 | 31.4 | 14.3 |
| Bendigo West | 46.5 | 25.0 | 18.0 | 1.11 | 32.9 | 22.3 | 15.5 | −5.1 | −0.7 | −1.1 | +0.5 | 26.0 | 28.0 |

## Row walks

### Box Hill (and the eastern group)

- **Inputs.** 2022: Labor 41.3, Liberal 35.2, Greens 14.1, other-right 5.5;
  Labor two-party margin 7.2 (ABC pendulum,
  `external/reference/abc-vic2026/pendulum-20261003.html`). Boundaries are
  unchanged since the 2021 redistribution, which was in force for 2022, so there
  is no notional to get wrong. Sitting Labor member Paul Hamer is recontesting
  (`output/candidacies.csv`, sitting badge). The Liberal candidate, Sally
  Houguet, is new. No seat poll (`output/seat-poll-blend-vic2026.csv` has only
  one polled cell statewide). Federal 2025 two-party swing in its booths: +2.96
  to Labor, 1.04 above the state mean, so the port adds +0.44.
- **What we predict and why.** The statewide swing alone would take Labor to
  28.6 and Liberal to 29.6. One Nation is ranked 5th lowest in the state (2025
  House ONP 1.5%), so it gets 9.6% rather than 21.8%. The fill then scales
  everything else up 16%: Labor 33.1, Liberal 34.3, Greens 19.6. Greens
  preferences (83.5% to Labor, FL0) already put Labor near 54 two-party at this
  stage. xgb takes about 2.9 off the Liberal (inferred); port and demographic add
  +0.9 to Labor. Published: Labor 34.6, Liberal 30.9, Greens 19.4. Local walk
  two-party: Labor 54.5 (90%: 47.3-61.3), a 2.7-point swing against Labor while
  the state swings 6.9. Labor wins 0.915.
- **What the market implies.** Liberal 0.678. That is what a uniform 6.9-point
  swing on a 7.2 margin gives, with a little for Jess Wilson (Kew, opposition
  leader) appealing in the east.
- **Mechanism.** The fill hands Labor back most of its statewide loss wherever
  One Nation is weak. That is a modelling assumption, not a measurement: it says
  One Nation's gain is taken proportionally from every party in each seat, so
  Labor loses little where One Nation polls little. The statewide draws point the
  other way. FP2 says that across simulations each point of One Nation comes
  −0.46 from the Coalition and +0.03 from Labor, so One Nation's rise is not
  mainly a Labor loss. Labor's 12-point primary fall would then be closer to
  uniform, and the east would swing more than we have it. Against that, the
  vic2022 backtest under-called Labor in every one of these seats (Box Hill
  +5.1, Ashwood +5.3, Glen Waverley +2.3, Bayswater +4.0 Labor primary; signed
  error = actual − ours, `output/published-predictions.csv`). Federal 2025 also
  swung to Labor across the same booths (Chisholm, Menzies, Deakin, Aston).
- **Backtest check of the fill.** Major-party misses by One Nation tercile in
  the One-Nation-heavy pairs show no consistent pattern. SA 2026 low-One-Nation
  third (16 seats, ONP 12%): Labor +1.8, Liberal +3.3 (we under-called the
  Liberals by 1.5 more than Labor). Qld 2024: the opposite sign. Greens were
  over-called in SA 2026's low-ONP third (−2.3, against −0.6 in the high third).
  These are harness predictions, and I did not verify that every harness uses the
  same fill as the live script.
- **Verdict: unclear.** 0.915 is too confident for a seat whose two-party
  outcome rests on an untested allocation assumption. 0.24 is too low given the
  2022 and 2025 evidence that these booths have been moving to Labor.

**Same mechanism across the group.** All five sit in the bottom third on the
federal One Nation ranking (ranks 5 to 27 of 88). Fill factors run 1.08 to 1.16.
Implied two-party swings from the local walk are Box Hill −2.7, Ashwood −2.3,
Glen Waverley −0.9, Bentleigh −4.7 and Bayswater −5.0, against −6.9 statewide.
Bayswater is the exception: the Labor member is not on the 2026 list (Julie
Buxton stands), so the departed slope 0.62 applies. That brings it closest to the
market, and the port's +1.6 is what keeps it level. Across the 59 seats in the
capture, expected Labor seats are 20.4 for us and 17.4 for the market;
Liberal/National 22.5 for us and 24.1 for the market.

### Niddrie (and the One Nation group)

- **Inputs.** 2022: Labor 44.0, Liberal 34.0, other-right 9.9, Greens 7.4;
  Labor margin 6.7. Ben Carroll (Labor) is recontesting. The leader file
  `output/leader-seat-vic2026.csv` lists him as government leader, so he gets the
  +2.72 leader bonus (I did not check that he is Premier anywhere else). The
  Liberal candidate, Samantha Byrne, is new. One Nation's candidate is Jason
  Taverna; nobody stood for them here in 2022.
- **What we predict and why.** Niddrie's booths gave One Nation 8.1% in the
  2025 federal House contest, the 73rd highest of 88. That maps to 30.4% (house
  rank allocation; 27.8 after later stages). The fill scales the others by 0.90,
  so Liberal lands at 24.5 and Labor at 31.9 after the leader bonus. With the
  Liberal third, its preferences go to One Nation, which wins 0.571 (local walk
  final pair ONP v ALP in 73% of simulations, ONP 52.6 two-candidate).
- **What the market implies.** Liberal 0.47, Labor 0.44, One Nation 0.07: One
  Nation third, and a Labor-Liberal contest on a 6.7 margin.
- **Mechanism: an input defect.** Niddrie is in federal Maribyrnong. In 2022 One
  Nation got 2.4% there with 7.5% for other right-wing minors; in 2025 no other
  right-wing minor stood and One Nation got 6.9%
  (`external/elections/aec-fed-firstprefs.csv`). The House ordering reads that as
  One Nation strength. The 2025 Senate One Nation vote in the same booths is 3.8%,
  rank 48 (`output/senate-onp-vic2026.csv`). On a Senate ordering, Niddrie's One
  Nation target is 22.9 instead of 30.4. The ordering also flipped between
  cycles: Niddrie was rank 33 on the 2022 House vote.
- **Verdict: market likely right on One Nation.** On a Senate ordering the
  Liberals would sit at about 27, not 24.5, and Niddrie becomes a Labor-Liberal
  race. That is what the market prices.

**Same mechanism across the group.** Over all 88 seats, the 2025 House and Senate
One Nation rankings agree at Spearman 0.897. In SA 2026 they agreed at 0.986,
which is why the earlier Senate test could not tell them apart. In Qld 2017 they
agreed at only 0.620, and there the Senate ordering predicted the actual One
Nation ranking much better (0.772 against 0.544, `output/onp-senate-district-panel.csv`).
On rank correlation with the actual result, the Senate ordering is at least as
good as the House ordering in all five One-Nation-heavy elections we have (nsw2023
0.863 v 0.814; qld2017 0.772 v 0.544; qld2020 0.904 v 0.896; qld2024 0.819 v 0.805;
sa2026 0.946 v 0.939).

One Nation target share (percent) under each ordering. Both use the same SA 2026
spread and CV 0.365; only the ranking changes. Published = the release's
One Nation cell after later stages.

| seat | published | House rank (shipped) | Senate rank | House + other-right rank | market ONP prob | our ONP prob |
|---|---:|---:|---:|---:|---:|---:|
| Niddrie | 27.8 | 30.4 | 22.9 | 21.1 | 0.074 | 0.571 |
| Essendon | 22.6 | 21.7 | 14.7 | 12.8 | 0.084 | 0.361 |
| Lara | 34.0 | 35.9 | 29.0 | 27.3 | 0.284 | 0.753 |
| Geelong | 25.7 | 27.4 | 23.3 | 19.1 | 0.205 | 0.397 |
| Sunbury | 32.0 | 33.1 | 27.2 | 27.1 | 0.601 | 0.898 |
| Eureka | 32.8 | 33.8 | 32.8 | 32.8 | 0.400 | 0.928 |
| Bendigo West | 18.0 | 17.0 | 23.6 | 16.9 | 0.414 | 0.080 |
| Bendigo East | 22.8 | 21.6 | 27.0 | 21.6 | 0.286 | 0.181 |
| Greenvale | 14.3 | 14.7 | 21.6 | 24.7 | 0.272 | 0.009 |
| Benambra | 27.1 | 27.1 | 33.9 | 25.9 | 0.332 | 0.029 |

Calculation:
`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\e7e809d4-b07a-4695-a3bd-7e8f88a19663\scratchpad\onp_order.py`.
It reproduces the shipped House allocation to a correlation of 0.996 with the
published cells.

- **Essendon.** House rank 46, Senate rank 20 (Maribyrnong again). Danny Pearson
  is retiring (Labor slope 0.62). The independent Oscar Yildiz carries a credited
  13.9 from Pascoe Vale 2018. Locally the surge hazard lifts One Nation's win
  probability to 0.635; that is not in the published run (see below). **Market
  likely right.**
- **Lara.** Corio: One Nation 3.9% plus 8.4% other-right in 2022, then 9.9% with
  no other-right in 2025. House rank 87 puts Lara at the top of SA's spread.
  Labor's Ella George is the sitting member on 49.7; the fill takes her to 31.4.
  **Market likely closer.** One Nation still gets a large share on a Senate
  ordering (29.0), so 0.28 may be low, but 0.75 is not supported.
- **Eureka.** The ranking is stable (House 81, Senate 77), so the defect does not
  apply here. Both sides favour One Nation. Our 0.925 comes from putting One
  Nation at the top of SA's spread with a seat-level standard deviation of about
  4.5 points. That allocation's own error was 4.4 points RMSE in SA 2026 (the
  election whose spread it borrows, so in-sample) and 7.8 in Qld 2017. **We are
  probably too confident; direction agreed.**

### Bendigo West

- **Inputs.** 2022: Labor 46.5, Liberal 25.0, Greens 11.5, others 8.0;
  Labor margin 14.6. Maree Edwards (Labor) is not on the 2026 list; Brenton
  Baldwin stands, so the departed slope 0.62 applies. The Coalition candidate is a
  National, David Hutchings (`output/candidacies.csv`, ABC source only). In
  2022 it was a Liberal. One Nation's candidate is Ellen Morgan.
- **What we predict and why.** Base: Labor 32.9, Nationals 22.3, One Nation
  18.0, Greens 15.5. Federal Bendigo's two-party went from Labor 62.1 v Liberal in
  2022 to Labor 51.4 v Nationals in 2025 (`aec-fed-tcp.csv`), and the Coalition
  primary from 26.6 to 40.2. Transposed to Bendigo West's booths that is −10.18,
  the second-largest swing against Labor in the state after Bendigo East (−12.18).
  The port turns it into −5.1 Labor, +5.1 Nationals. Published: Nationals 28.0,
  Labor 26.0, One Nation 18.0. Nationals win 0.551.
- **What the market implies.** Labor 0.44, One Nation 0.41, Nationals 0.12: a
  Labor-One Nation contest with the Nationals third.
- **Mechanism.** The port's coefficient was fitted on ordinary federal-state
  swing pairs. Bendigo 2025 was a Nationals candidate standing in a three-cornered
  contest for the first time, and the port carries that across as if it were a
  general mood. The same campaign squeezed One Nation's 2025 House vote in
  Bendigo to 4.9%. Bendigo West's House rank is 29, against 50 on the Senate, so
  it gets 18.0 rather than about 23.6.
- **Verdict: market likely right that 0.55 for the Nationals is too high.** Both
  pieces of the 2025 Bendigo Nationals effect go the same way.

## Proposed fixes, each behind a switch

1. **`AUSPOL_ONP_ORDER=senate_rank` (new value; the top defect).** Keep the
   shipped SA 2026 spread and the CV 0.365, and rank seats on their 2025 Senate One
   Nation share (`output/senate-onp-vic2026.csv`; the harnesses already have the
   per-district Senate tables) instead of the House share. This is not the refused
   `senate` rule. That rule also replaced the spread with Qld 2017's log curve,
   and its refusal was on SA 2026 seat log loss, where House and Senate rankings
   agree at 0.986. So the refusal says nothing about the ordering on its own.
   **Screen:**
   - Run the allocation-only leave-one-election-out test from
     `docs/plans/prereg-onp-senate-2026-10-01.md` on the five One Nation pairs.
     Give each pair its true One Nation mean, score spread RMSE, and expect Qld
     2017 to carry it.
   - Then `quick_arm.R "AUSPOL_ONP_ORDER=senate_rank" --pairs=sa2026,qld2017,qld2020,qld2024,nsw2023`
     for seat log loss.
   - Check `docs/MODEL-REGISTRY.md` for which harnesses read `AUSPOL_ONP_ORDER`;
     the prereg says SA, Qld and NSW are wired. The deciding run is on all 22.
   - Live walk: Niddrie, Essendon, Lara, Geelong and Sunbury should fall;
     Bendigo West, Bendigo East, Greenvale and Benambra should rise.
2. **`AUSPOL_ONP_FILL=uniform_major` (new; the eastern question; exploratory).**
   Arm: take a seat's One Nation shortfall or excess from the classes in proportion
   to the statewide draw betas (FP2) rather than to each class's size in the seat.
   Shipped behaviour stays the proportional fill. **Screen:** first the
   tercile-miss table above for sa2026 and qld2017 under both rules (seconds,
   from base_pred). Then `quick_arm.R` on sa2026, qld2017, qld2024 and wa2001,
   plus AEF-7. Pre-register before the run: the targeted metric is Labor and
   Liberal primary error in the lowest One Nation third.
3. **Port carrying candidate-specific swings (Bendigo).** Arm
   `AUSPOL_SEAT_SWING_PORT_3C=1`: where the federal 2025 two-party pairing changed
   class (Liberal to National), or the Coalition primary moved more than k standard
   errors, shrink that seat's port adjustment toward 0. Fit the shrinkage from the
   earlier cycles the coefficient already uses. **Screen:** `quick_arm.R`. The
   federal and Victorian harnesses carry the port and are the only ones with
   Liberal-to-National pairing changes worth testing. Check vic2022 Bendigo-area
   seats specifically.
4. **One Nation seat spread (Eureka-type over-confidence).** Arm
   `AUSPOL_ONP_ALLOC_SD`: add the allocation's own out-of-sample error (RMSE of
   the ordering rule at the One Nation level, leave-one-election-out) to the One
   Nation cell's seat variance. **Screen:** reliability of One Nation win
   probabilities on the five pairs. So far only 8 calls above 0.3 exist (5 won),
   so this is underpowered; report it, do not decide on it alone.

## Side findings

- **The published forecast and local runs are not the same model.** CI run
  40138000279 prints `DS3 surge-v2 requested but vic2026 has no salience corpus
  yet` and `XG5! no salience corpus`; the local walk
  (`deciding-runs/20261025-minor-additive-walk/add.log`) finds a corpus (43
  cells, 31 surge-recipient seats, 26 of them One Nation). Box Hill Labor is
  0.757 locally against 0.915 published; Essendon One Nation 0.635 against 0.361.
  The emergence-surge bug the coordinator raised therefore affects local numbers
  only, until a corpus reaches CI.
- **Candidate flags look wrong in two seats** (`output/candidacies.csv`,
  `historic_elected`). Bayswater's Greens candidate Jess Kennedy carries the
  sitting badge, and Werribee's Liberal Reece Clark carries it after losing the
  2025 by-election. I did not check whether any model step reads this column; I
  believe returns are matched by name to vic2022, which would make it harmless.

## What was not run, and where I looked

- **The instrumented stage-by-stage run was not done.** An instrumented copy
  (`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\e7e809d4-b07a-4695-a3bd-7e8f88a19663\scratchpad\fit_seats_full_walk.R`)
  dumps shares after every stage, plus the surge hazard. Its runner,
  `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\e7e809d4-b07a-4695-a3bd-7e8f88a19663\scratchpad\run_walk.sh`,
  writes outputs to `deciding-runs/20261025-market-disagreement/` and restores
  `S7-BREACH.txt`. Available memory stayed between 2.9 and 5.1 GB, and
  `fit_xgb_primary_asat.R` was running throughout, so the 8,000 MB rule was never
  met. The xgb column above is therefore inferred, not measured. Run it when the
  machine is free to replace the inference with printed values.
- The seat-level backtest tercile check uses harness predictions; I did not
  confirm that the harnesses' One Nation fill is identical to the live script's.
- Ben Carroll as government leader comes from `output/leader-seat-vic2026.csv`
  only. Departing members (Edwards, Pearson, Taylor) come from their absence on
  the 2026 candidate list, not from an announcement.

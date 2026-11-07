# TCP mean absolute error against AE Forecasts, AEF-7 (2026-11-07)

Read-only analysis of existing outputs. No harness, `quick_arm.R` or rebuild was run.
Inputs: `output/aef7-ledger-data.json` and `output/aef7-primary-common.csv` (both built
7 Nov 12:16pm), `output/aef7-tcp-actual.csv` (12:16pm), the shipped run's `ourtcp` and
`sharedetail` files for fed2007-fed2025 (run `a25ac7a-g49f1956`, chosen by
`scripts/ledger_inputs.R`), and `external/elections/aec-fed-tcp.csv`. Scratch scripts
and intermediate tables are in
`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\039558ff-c686-4228-be45-1cacedd05b75\scratchpad\tcp-research\`
(`a2.R` to `b6.R`).

## Headline

- **On the seats both sides can be scored on, the gap is a tie, not a loss.** Ours 3.6225
  against AEF 3.5947 over 583 seats, a difference of +0.028 points (seat SE 0.10). The
  mean of the seven per-election differences is -0.12 (SE 0.23), so the sign is not even
  stable.
- **The headline gap (3.6788 against 3.6347) is partly which seats get scored.** The ledger
  scores a side only where its OWN most likely final two was the real one. We get 27 seats
  right that AEF misses, and they are hard ones (our mean error on them 4.89). AEF gets 17
  that we miss (its mean error 5.01). Of the 0.044 headline gap, 0.028 is the common seats and
  0.016 is the different seat sets.
- **Scored on the real final two in every seat where both have it (657 seats), we are already
  ahead**: ours 3.722 against AEF 3.733.
- **Where we do lose: the 2023 NSW election and the 2025 federal election.** Summed over seats,
  those two contribute +139.8 gap points. The other five contribute -123.6, which nets to the +16.2 total. The worst seats are safe NSW Labor and
  Nationals seats where the real margin was much wider than we said (Northern Tablelands,
  Wallsend, Fairfield, Auburn, Maitland, Mount Druitt).
- **Our primaries are better than AEF's and our flows are as good. What costs us is that the
  two errors push the same way.** On ALP v LNP seats, our primary error and flow error are
  correlated +0.23; AEF's are -0.10. That cross term is the whole gap (below).
- **Best first arm: turn on optional-preferential exhaustion in NSW, both in the seat
  simulation and in the statewide anchoring (`AUSPOL_NSW_EXHAUST=1` +
  `AUSPOL_ANCHOR_EXHAUST=1`).** Both switches already exist and are off. Estimated effect from
  an offline proxy: -0.064 on the 583-seat common MAE, which on its own more than closes the
  +0.028 gap.

## 1. Reproduction and the common-seat comparison

Numbers are TCP mean absolute error in percentage points of the two-candidate count; lower is better.

| Scoring rule | Ours | n | AEF | n |
|---|---:|---:|---:|---:|
| Ledger rule (each side's own top final two, where it matched the real one) | 3.6788 | 610 | 3.6347 | 600 |
| Common seats under the ledger rule (both top picks matched) | 3.6225 | 583 | 3.5947 | 583 |
| Real final two, any scenario (`*_tcp_pred_pct`), each side's own seats | 3.7187 | 658 | 3.7330 | 657 |
| Real final two, common seats | 3.7217 | 657 | 3.7330 | 657 |

Both ledger numbers reproduce exactly. How the ledger scores
(`scripts/build_aef7_ledger_data.R` lines 218-242): for each side, take its most frequent
final-two scenario (`which.max(freq)` from the `ourtcp` file; AEF's top `seatTcpScenarios`
entry). Score it only if that pairing is the real one (unordered), comparing the side's
median TCP for the named party with that party's real share. 658 of 681 seats have a
resolved real final two. The 23 without one are left out: 27 vic2022 and 1 nsw2023 in the
reference file, partly refilled since then.

Final-two pick outcome, counts of seats (of 658 with a resolved final two):

| Both right | Only ours right | Only AEF right | Neither |
|---:|---:|---:|---:|
| 583 | 27 | 17 | 31 |

Our 27 include seven sa2026 One Nation contests and Canberra (both years), Clark, Groom,
Maranoa, Tamworth and Vaucluse. AEF's 17 are mostly independents we did not see in the final
two (Fowler, Mackellar, North Sydney, Kiama, Mornington, Benambra).

## 2. Where the gap is (common seats, n = 583)

In every table below, "ours" and "AEF" are TCP mean absolute error in points (lower is better).
"Gap" is ours minus AEF per seat, so positive means AEF is better. "Gap total" is that summed
over the seats, which shows where the points come from. "Bias" is the signed error for the
real winner (negative = we under-called the winner's margin).

### By election

| Election | n | Ours | AEF | Gap | Gap total | Our bias | AEF bias |
|---|---:|---:|---:|---:|---:|---:|---:|
| fed2025 | 130 | 4.878 | 4.149 | +0.729 | +94.8 | -3.13 | -2.54 |
| nsw2023 | 80 | 4.870 | 4.308 | +0.562 | +45.0 | -4.15 | -2.20 |
| vic2022 | 69 | 3.105 | 3.048 | +0.058 | +4.0 | -0.27 | -0.11 |
| wa2025 | 47 | 3.679 | 4.257 | -0.579 | -27.2 | -1.67 | -0.52 |
| qld2024 | 87 | 2.733 | 3.084 | -0.350 | -30.5 | -1.09 | -1.73 |
| sa2026 | 33 | 3.111 | 4.133 | -1.023 | -33.7 | -1.27 | +1.15 |
| fed2022 | 137 | 2.632 | 2.895 | -0.263 | -36.1 | -0.95 | -0.60 |
| **All** | **583** | **3.6225** | **3.5947** | **+0.028** | **+16.2** | | |

### By contest type

| Real final two | n | Ours | AEF | Gap | Gap total |
|---|---:|---:|---:|---:|---:|
| ALP v LNP | 500 | 3.632 | 3.557 | +0.074 | +37.1 |
| ALP v GRN | 17 | 4.151 | 3.282 | +0.868 | +14.8 |
| LNP v OTH_RIGHT | 6 | 4.225 | 3.517 | +0.708 | +4.2 |
| IND v ONP | 1 | 4.180 | 1.500 | +2.680 | +2.7 |
| IND v LNP | 31 | 3.633 | 3.635 | -0.002 | -0.1 |
| GRN v LNP | 4 | 2.110 | 2.525 | -0.415 | -1.7 |
| ALP v IND | 4 | 4.225 | 4.700 | -0.475 | -1.9 |
| LNP v ONP | 1 | 1.473 | 5.000 | -3.527 | -3.5 |
| ALP v ONP | 19 | 2.979 | 4.842 | -1.863 | -35.4 |

By election and contest type, the two losing cells carry everything: **fed2025 ALP v LNP
(111 seats, +76.2) and nsw2023 ALP v LNP (65 seats, +58.9)**. Every other cell with at least
10 seats is level or ours: fed2022 -35.6, qld2024 -39.2, wa2025 -27.2, sa2026 ALP v ONP -35.4.

### By predicted margin (ALP v LNP, n = 498)

Band is |our TCP - 50|. Bias is the signed error toward OUR favourite (negative = we called the favourite's margin too narrow).

| Our predicted margin | n | Ours | AEF | Gap | Our bias | AEF bias |
|---|---:|---:|---:|---:|---:|---:|
| 0-3 | 86 | 3.70 | 3.84 | -0.15 | +0.10 | +0.15 |
| 3-6 | 91 | 3.91 | 3.83 | +0.08 | -1.24 | -1.04 |
| 6-10 | 117 | 3.59 | 3.69 | -0.10 | -1.21 | -0.69 |
| 10-15 | 136 | 3.39 | 3.32 | +0.07 | -0.88 | -0.57 |
| over 15 | 68 | 3.71 | 2.92 | +0.79 | -1.05 | +0.59 |

The marginal seats, which decide log loss, are level or ours. The loss is in safe seats.

### By size of predicted swing (ALP v LNP, n = 498)

Predicted swing is our change in the Labor-minus-Coalition primary gap since the last
election (previous shares from `output/published-predictions.csv`).

| Predicted swing | n | Ours | AEF | Gap total | Level removed: ours | Level removed: AEF | Level removed: gap total |
|---|---:|---:|---:|---:|---:|---:|---:|
| 0-3 | 119 | 3.90 | 3.28 | +74.1 | 2.60 | 2.52 | +10.2 |
| 3-6 | 95 | 3.85 | 3.54 | +29.3 | 2.97 | 2.81 | +15.3 |
| 6-10 | 87 | 3.62 | 3.48 | +12.3 | 3.15 | 3.52 | -31.8 |
| over 10 | 197 | 3.36 | 3.72 | -70.3 | 3.31 | 3.53 | -43.7 |

"Level removed" subtracts each election's mean error first. The small-swing loss is mostly
the election-wide level miss in fed2025 (Labor beat its polls; both models under-called it).
Once that is removed, the swing bins show nothing to fix.

### Spread of the predictions

Slope of actual ALP TCP on our predicted ALP TCP within each election (ALP v LNP). 1.00 means
the spread is right; above 1 means real margins were wider than we predicted.

| Election | n | Ours | AEF | SD actual | SD ours | SD AEF |
|---|---:|---:|---:|---:|---:|---:|
| fed2022 | 124 | 1.040 | 0.981 | 10.17 | 9.24 | 9.71 |
| fed2025 | 111 | 1.117 | 1.059 | 10.33 | 8.60 | 9.08 |
| nsw2023 | 65 | **1.412** | 1.051 | 15.21 | 10.34 | 13.63 |
| qld2024 | 81 | 1.000 | 0.983 | 10.94 | 10.38 | 10.44 |
| sa2026 | 11 | 1.317 | 1.672 | 8.05 | 5.19 | 4.50 |
| vic2022 | 61 | 0.968 | 0.864 | 10.36 | 10.21 | 11.40 |
| wa2025 | 45 | 1.045 | 0.822 | 10.40 | 8.91 | 11.49 |

NSW stands alone at 1.41. NSW is the only AEF-7 election with optional preferential voting,
and that widens margins: exhausted ballots drop out of the count, so the leader's
primary lead counts for more.

## 3. Primary error against flow error

Method. For ALP v LNP common seats with four-class primaries (ALP, LNP, GRN, REST) for us,
AEF and the result (498 of 500), the TCP identity is `TCP_ALP = p_ALP + f * others`, where
`others = 100 - p_ALP - p_LNP` and `f` is the effective share of all other ballots reaching
Labor. Backing `f` out of each side's own primaries and TCP gives our effective flow, AEF's,
and the actual one. The identity reproduces our TCP to 1e-14. Swapping pieces gives the oracle
checks. This uses effective two-candidate flows, not the per-party distribution-of-preferences
flows. That is enough to split the error, but it lumps the composition of "others" in with the flow.

TCP mean absolute error, ALP v LNP common seats (n = 498), lower is better:

| Variant | MAE |
|---|---:|
| Ours, as published | 3.628 |
| AEF, as published | 3.537 |
| Actual primaries + OUR flows | **1.466** |
| Actual primaries + AEF flows | 1.527 |
| Our primaries + ACTUAL flows | **3.033** |
| AEF primaries + ACTUAL flows | 3.360 |
| Our primaries + AEF flows | 3.370 |
| AEF primaries + our flows | 3.968 |

Both of our pieces are better than AEF's when tested alone: flows 1.466 against 1.527,
primaries 3.033 against 3.360. Our combination still loses. Squared error splits as
primary part + flow part + twice their covariance (points squared; signed split averaged over
both orders):

| | Mean squared error | Primary part | Flow part | 2 x covariance | Correlation of primary and flow errors |
|---|---:|---:|---:|---:|---:|
| Ours | 21.03 | 14.17 | 3.52 | **+3.33** | +0.23 |
| AEF | 19.34 | 17.65 | 3.46 | **-1.77** | -0.10 |

**The gap is entirely the cross term.** When we under-call Labor's primary lead, we also
under-call Labor's flows, so the errors add. AEF's partly cancel. By election, our
correlation is highest in nsw2023 (+0.62, AEF +0.26) and fed2025 (+0.20, AEF -0.19), the two
losing elections. In NSW that is what missing exhaustion looks like: the primary gap is
under-spread (slope of actual on predicted Labor-minus-Coalition primary gap 1.25), and the
missing exhaustion shows up as a flow error with the same sign.

Signed, ALP-oriented error by election (points; + = Labor overstated). Primary and flow parts add to the total:

| Election | n | Our error | Primary | Flow | AEF error | AEF primary | AEF flow |
|---|---:|---:|---:|---:|---:|---:|---:|
| fed2022 | 124 | +0.17 | +0.52 | -0.35 | +0.59 | +0.83 | -0.25 |
| fed2025 | 111 | -4.30 | -3.29 | **-1.00** | -3.47 | -3.35 | -0.12 |
| nsw2023 | 65 | -1.30 | -1.50 | +0.21 | -0.70 | -1.08 | +0.38 |
| qld2024 | 81 | +0.25 | -0.38 | +0.63 | +1.55 | +0.48 | +1.07 |
| sa2026 | 11 | +0.67 | +0.95 | -0.28 | -0.28 | -0.60 | +0.32 |
| vic2022 | 61 | +1.81 | +1.45 | +0.36 | +0.47 | +0.17 | +0.29 |
| wa2025 | 45 | -0.46 | -1.17 | +0.71 | -0.58 | -0.53 | -0.05 |

fed2025 also has a level flow miss: our mean effective flow to Labor 0.555 against an actual
0.590 (AEF 0.584). Our flows are also too uniform from seat to seat: the SD of our effective
flow is 0.04-0.09 against 0.05-0.12 actual, and the slope of actual on ours is above 1 in
five of seven elections.

Other contests: ALP v GRN (17 seats) ours 4.151, actual primaries + our flows 2.461, our
primaries + actual flows 2.856. IND, ONP and OTH_RIGHT contests could not be split, because
the four-class primaries fold those candidates into REST. That covers 63 of 583 common seats;
I did not build a per-candidate version for them.

## 4. Fixes, ranked by estimated effect on common-seat TCP MAE

Every proxy is computed offline from existing outputs. Anything fitted uses only elections
before the target. The chronological order is fed2007, fed2010, fed2013, fed2016, fed2019,
fed2022, vic2022, nsw2023, qld2024, wa2025, fed2025, sa2026. The baseline gap is +0.028
(ours 3.6225, AEF 3.5947, n = 583). Change is in points of MAE over the 583 seats; negative is better.

| Rank | Fix | Proxy change | Seats moved | Seat log loss |
|---:|---|---:|---:|---|
| 1 | NSW exhaustion in the simulation plus OPV-basis anchoring | **-0.064** (simulation only: -0.027) | 65 | Unknown sign; risk on nsw2019 |
| 2 | Seat-level flow persistence: last election's flow residual for this seat | **-0.035** federal only; untested for states | 229 | Probably small gain (acts in marginals too); not measured |
| 3 | Constant shift toward our favourite's margin (time-forward, +0.1 to +0.4 points) | -0.027 alone; -0.024 on top of 1+2 | 583 | None if applied to reported TCP only |
| 4 | Margin stretch factor (time-forward slope) | -0.005 (SE 0.015). **Not a fix** | 583 | n/a |
| - | Fixes 1+2+3 combined | **-0.123** (3.6225 to 3.4998, against AEF 3.5947) | | |

**1. NSW optional-preferential exhaustion.** The NSW harness has an exhaustion path behind
`AUSPOL_NSW_EXHAUST` (R engine only), off in `scripts/published_flags.R:846`. I found no
measurement of it in `docs/` (searched NEXT-STEPS, DECISIONS, reviews and plans for
`NSW_EXHAUST`). Proxy: `TCP' = (p_A + f(1-x)·others) / (100 - x·others)`, with our primaries
and effective flow. Exhaust rates are the anchor's 2019 NSW row, which was knowable before 2023:
Greens 39.7%, everyone else 60.4%. That leaves on average 10.1% of formal votes exhausted. On nsw2023
ALP v LNP (65 seats): 5.060 to 4.817, slope 1.41 to 1.27, but the Labor bias worsens from
-1.30 to -2.39. That bias is what the anchoring defect in
`docs/plans/prereg-anchor-exhaust-2026-09-27.md` produces. With `AUSPOL_ANCHOR_EXHAUST`, Labor's nsw2023
first preference rose about 1.5 points. The proxy for both together re-levels the exhausted TCP to
the unexhausted mean (a pre-election quantity): 5.060 to **4.488** (AEF 4.154), -0.064 on the
583 pool. Exhaust-only proxy: seat SE 0.20, 32 of 65 seats improve, 4 Labor-favourite flips.
Rates 30/50% or 50/70% give 4.84 and 4.81, so the result does not hinge on the rate.
Log loss: the anchoring arm alone was refused because it moved nsw2019's primaries the wrong
way (mean miss 1.027 to 1.547). So nsw2019 log loss is the risk, and the sign cannot be told offline.

**2. Seat-level flow persistence.** The flow trees (`output/xgb-flows-v1-final-cols.json`, 40
features) have no feature for this seat's own past flows: only class, survivors, primaries,
region and earlier-election rates. A seat's effective-flow residual (actual minus ours)
correlates with the same seat's residual at the previous election at 0.25-0.49 across six
federal elections (112-138 seats each). Proxy: `f_new = f_our + w·r_prev`, with w fitted on
earlier elections only (0.375 for fed2022, 0.348 for fed2025). fed2022 2.680 to 2.609 (120
seats), fed2025 5.084 to 4.978 (112). On the 229 federal common seats: -0.035 on the 583 pool.
**Federal only:** I did not build state seat-level actual TCP histories. Booth TCP files
exist for vic, qld and sa in the registry, but the paths did not resolve from `external/`,
and NSW would need the DOP cache. If the states behave like federal, the effect on the pool
roughly doubles (my extrapolation; not computed). A real version would be a flow-tree feature
built from the previous election's distribution of preferences for the seat, not this
two-candidate shortcut. The residual includes our error on who makes up the "others", so part of it may
belong in the primary model.

**3. Shift toward our favourite.** Historically, real margins for our favourite run wider than
predicted. Time-forward mean shift 0.11-0.42 points; in-sample by election: -1.24 (vic2022) to
+3.35 (nsw2023). Proxy -0.027. This is a patch over the under-spread flows. Repo memory
(`patches-reveal-misspecification`) says such patches mean something is mis-specified, so it ranks below
the fixes that remove a cause. It should go away once 1 and 2 land.

**4. Margin stretch: tested and refused as a fix.** A pooled slope fitted time-forward on up
to 1,354 seat-elections from 11 earlier elections comes out at 0.93-0.98 (with intercept) or
0.99-1.03 (through 50). The under-spread shows up only in particular elections, mainly NSW, and does not
carry over from one election to the next. Proxy -0.005, SE 0.015. Inputs: our TCP for the real final two and
the real result. No other features, so this rules out only a single global stretch factor.

**Not a model fix, flagged anyway: how the ledger headline is scored.** Scoring each side on its own
matched seats penalises the side that gets more hard final twos right. Our 27 extra seats
average 4.89. On common seats it is a tie, and on the real final two (657 seats) we lead.
Changing the headline is a reporting decision for Pete, not an improvement, and is not counted
in the ranking.

Not proposed: the fed2025 statewide level (-4.30 ours, -3.47 AEF). That is a polling miss shared
by both models, and there is no time-forward handle on it in these outputs.

## 5. Recommended first arm (draft pre-registration)

**Arm:** `AUSPOL_NSW_EXHAUST=1 AUSPOL_ANCHOR_EXHAUST=1`, both together, against the published
configuration. Pairs: nsw2019 and nsw2023 (the NSW harness; R engine is forced by the
exhaust path, so expect a slower run). All other pairs must stay byte-identical.

**Why together:** the simulation exhaust alone widens margins correctly but pulls Labor down
1.1 points. The anchoring fix alone was refused on 2026-09-27 because it raised Labor with
nothing to balance it. Each fixes the units the other one gets wrong, and NSW
is the only optional-preferential election in the backtests.

**Primary metric (decides):** TCP mean absolute error on nsw2023 seats where both our top final
two and AEF's matched the real one (80 seats now; recompute the seat set from the arm's own
`ourtcp`, and report seat-set changes). Ship-side criterion: the change is negative and at least
1 seat SE from zero (seat SE on the proxy about 0.2 on 65 seats).

**Second metric:** nsw2019 TCP MAE against the NSWEC final counts. Those are not in
`output/aef7-final-two-and-tcp-reference.csv`. Build them from the DOP cache
`external/reference/nsw/dop` (`SG1901-*`, 93 seats; the last exclusion leaves two candidates)
**before** running. This is needed because nsw2019 is where the earlier anchoring arm failed.

**Guards (unacceptable even if the primary metric passes):**
1. Seat log loss on nsw2019 or nsw2023 worse by more than 1 SE (clustered on seat), in either.
2. TCP MAE on marginal seats (our predicted margin under 6 points) worse on either pair: a gain
   confined to safe seats does not justify moving marginal-seat probabilities.
3. Any non-NSW pair not byte-identical.
4. Mean ALP primary miss on nsw2019 worse than in the 2026-09-27 anchoring arm (1.547).

**Predicted result, written before running:** nsw2023 ALP v LNP TCP MAE 5.06 to about 4.5;
slope of actual on predicted ALP TCP 1.41 to about 1.27; 0-4 seat-favourite flips in nsw2023.
Expected change on the AEF-7 common-seat pool about -0.06, which would take ours from
3.6225 to about 3.56 against AEF's 3.5947.

**Screen first:** `scripts/quick_arm.R "AUSPOL_NSW_EXHAUST=1 AUSPOL_ANCHOR_EXHAUST=1" --pairs=nsw2019,nsw2023`.
Then, if it passes, run the deciding 20k run. I did not run either.

## What I could not confirm

- Proxies use the four-class primaries and effective two-candidate flows, not the
  simulator's per-party flows. Exhaust and flow persistence act inside the simulation for
  real, so the arm's numbers will differ from the proxy.
- The flow-persistence proxy covers federal elections only (229 common seats). The state
  effect is untested.
- 63 common seats with IND, ONP or OTH_RIGHT finalists were not split into primary and flow error.
- Seat log loss effects are not measured for any fix. The directions given are judgements
  from the mechanism.

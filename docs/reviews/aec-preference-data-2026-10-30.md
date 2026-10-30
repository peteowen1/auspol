# What the AEC's preference data says about flows and final pairs (2026-10-30)

**Why it matters.** The election-night model barely moves toward the counted two-candidate result, and in seats where the
count shows a final pair the model never simulated (Monash 2025) it throws the count away. This review measures, on
federal elections 2010-2025 and time-forward (every fit uses only earlier elections), how big the real seat-to-seat
flow error is, how often the final pair is predictable, and what booth-level flows add.

Script: `scripts/analysis_pref_flows_aec.R` (reruns everything; scratch CSVs in the session scratchpad `prefs/`).
Nothing under `R/` was changed. Status of every finding below: **measured here unless marked UNVERIFIED**.

## Short answers

1. **The real seat-to-seat flow error is about 6.9 points, and the night model uses about 1.** The error in a seat's
   overall flow to Labor (all non-Labor, non-Coalition voters pooled, Labor-v-Coalition seats) is 6.9 points
   (votes-weighted RMSE, n = 789 seat-elections, 2010-2025) even when the national flow is known and the seat's own
   previous flow is used. The night code floors the spread of the model's flow at 0.01 (1 point). That is the likely
   reason the count barely moves the model (weights worked out under "The number to use"). Whether the actual draw
   spread is above that floor is UNVERIFIED (it is not stored; see Change 1).
2. **Final pair: the model's top two on predicted share is right 90-99% of the time, better than "same pair as last
   time" (94.1% against 92.0% on the same 886 seats, 2010-2025).** The misses are almost all independent, Greens or
   One Nation challengers in a seat the model had as Labor v Coalition (or the reverse), 10 in 2022 and 15 in 2025.
   The DOP files cannot fix that by themselves; the sim already gives the actual pair at least 20% of draws in all but 6
   seats per election.
3. **Booth flows are stable and mostly explained by who the other voters are.** A booth's Labor-v-Coalition flow
   (relative to its seat) in 2022 predicts 2025 with correlation 0.73. The mix of other-party first preferences alone
   (times last election's national flow per party) explains about 70% of within-seat booth variation. Using it would
   cut the error of the early seat-flow estimate by about 40% (oracle composition; the prior-booth version failed,
   see Q3).

## Data used

- **Full distributions of preferences by division**, `external/reference/aec/fed<year>-dop.csv`, 2004-2025 (8 elections,
  150-151 divisions each, zero rows with an unclassified party). Each exclusion step is read as one pile of votes
  moving from the excluded candidate to the survivors. Party classes are the repo's own `classify_party()`.
- **Flow to Labor** for a minor party = votes it sent to Labor / (votes to Labor + votes to a Coalition party) at the step
  its candidate was excluded, kept only when both Labor and a Coalition candidate were still in. Votes to other minors
  are left out of both sides. No bulk exclusions occur (0 votes skipped in all 8 years).
- **"ALL" aggregate flow** = (Labor's final count minus Labor's first preferences) / (everyone who is not the Labor or
  Coalition finalist). This is exactly the quantity `night_tcp_obs()` computes. Only seats whose final pair is Labor v
  Coalition.
- **Booths**: `output/booths-fed2022.csv`, `-fed2025.csv` and `output/booths/fed{2022,2025}-booth-tcp.csv` (ordinary
  booths only, first preferences and two-candidate count; the two files' totals agree exactly). Per-party booth flows
  from the AEC flow-by-polling-place files for 2004, 2007, 2010 (tallyroom events 12246, 13745, 15508).
- **Not used**: tallyroom 2013 (17496) and 2016 (20499) were still downloading when this ran; the polling-place
  distribution-of-preferences zips were present for 2004-2010 but the flow-by-polling-place files give the same
  information. Official AEC flow-by-party tables were not used for the figures (see anchor note).
- **Anchor note (UNRECONCILED).** My national Greens flow to Labor is 82.2% (2025) and 80.2% (2022); the repo's
  `output/flows-estimated.csv` says 95.1% and 89.1%, built from the AEC's notional two-party counts (a different scope:
  it also covers seats where the Greens are in the final two). I checked my method by hand on Bean 2022 (Greens to
  Labor 16,215, to Liberal 2,696, 85.7%) and Bennelong 2025 (13,434 and 1,880, 87.7%) and both match the DOP counts.
  The scope gap between the two figures was not explained here.

## Q1. Flow stability

### Q1a. How much does a party's flow vary between seats?

Standard deviation across seats, in percentage points, of the share of a party's transferring votes that went to Labor
rather than the Coalition (votes-weighted, rms over 2010-2025; sampling noise from vote counts is the last column and is
negligible; the point is that the spread is real). Higher spread means a single national number is a worse guide for a
seat.

| Class | National flow to Labor (mean, range over elections) | Between-seat SD (pts) | Sampling SD (pts) | Seats per election |
|---|---|---|---|---|
| Greens | 78.9 (76-82) | 6.1 | 0.4 | 144 |
| One Nation | 38.0 (24-50) | 7.3 | 0.5 | 67 |
| Other right | 35.1 (31-43) | 9.3 | 0.7 | 141 |
| Independents | 52.7 (46-60) | 10.6 | 0.7 | 67 |
| Other | 54.6 (49-58) | 11.1 | 1.4 | 82 |
| All non-finalists pooled (ALL) | 60.5 (57-65) | 10.1 | 0.3 | 132 |

Per-election values for every class are in the scratch file `q1a_between_seat_spread.csv` (Greens 5.0-8.2 across the
eight elections; ALL 8.8-12.1).

### Q1b. Does the seat's or state's previous flow predict this election's, beyond the national figure?

Root-mean-square error (RMSE) of the predicted flow to Labor, in percentage points, scored on elections 2010-2025
pooled; lower is better. "Last national" = the previous election's national flow for that class. "This national" = the
current election's national flow (what a count in progress learns). The seat and state terms are shrinkage weights
(a regression of the seat's deviation on its previous deviation from national), fitted only on elections before the one
scored, weights = votes transferred. Minor-party rows are Greens, One Nation, Independents, Other right and Other
pooled (n = 3,008 seat-class-elections); ALL rows are n = 789 seat-elections.

| Predictor | Minor-party rows, votes-weighted | Minor-party rows, unweighted | ALL aggregate flow, votes-weighted | ALL, unweighted |
|---|---|---|---|---|
| A. Last national only | 9.58 | 10.79 | 10.55 | 10.03 |
| B. Last national + seat's last flow | 9.14 | 10.41 | 7.43 | 7.21 |
| C. This national only | 7.76 | 9.37 | 10.12 | 9.65 |
| D. This national + seat's last flow | 7.22 | 8.93 | 6.92 | 6.69 |
| E. This national + state's last flow | 7.63 | 9.28 | 9.54 | 9.06 |
| F. This national + seat + state | 7.22 | 8.91 | 6.93 | 6.71 |

Reading it: the national figure is worth the most; the seat's own previous flow takes another 7% off the minor-party
error (7.76 to 7.22) and 32% off the aggregate error (10.12 to 6.92); the state adds nothing once the seat is in (F = D).
Seats with a previous value: 72-90% by year (new or renamed divisions have none and fall back to the national).

By class, votes-weighted RMSE in points (lower is better; A/C/D from the same fits; D uses one pooled weight):

| Class | A. Last national | C. This national | D. This national + seat | Weight on seat deviation, fitted on all pairs | Rows |
|---|---|---|---|---|---|
| Greens | 6.4 | 6.1 | 5.3 | 0.53 | 866 |
| One Nation | 12.0 | 7.3 | 7.1 | 0.29 | 401 |
| Other right | 12.5 | 9.3 | 8.3 | 0.49 | 847 |
| Independents | 11.3 | 10.6 | 11.2 | 0.11 | 401 |
| Other | 11.6 | 11.1 | 10.8 | 0.33 | 493 |
| ALL aggregate | 10.5 | 10.1 | 6.9 | 0.80 | 789 |

Reading it: the pooled weight (about 0.5) was too heavy for Independents (their flow is candidate-specific; it made them
worse than the national alone, 10.6 to 11.2) and for One Nation, and too light for the aggregate (0.80). Use a
per-class weight (shrinkage, no cliffs, as the repo rule says). Independents have only 258 rows with a previous value.

### Is the model's flow spread near the measured error?

RMSE in points of the flow to Labor implied by the model's published prediction (its predicted two-candidate share and
predicted first preferences, from `output/aef7-tcp-actual.csv` and `published-predictions.csv`) against the actual flow,
Labor-v-Coalition seats. This **includes the error in the model's first-preference forecast**, so it is an upper bound on
pure flow error. Lower is better.

| Election | Seats | Model-implied flow RMSE | Persistence predictor F, same seats | Model 2CP-share RMSE (for scale) |
|---|---|---|---|---|
| 2022 | 124 | 5.2 | 5.2 | 3.3 |
| 2025 | 115 | 7.0 | 6.9 | 5.7 |

Reading it: the model's seat flows are no better than "this national flow plus the seat's last flow" (a tie), and its
error is 5-7 points. The shipped per-class flow sds (`output/flow-uncertainty-sd.rds`: Greens 2.0, Independents 4.4,
One Nation 10.4, Other 3.7, Other right 3.8 points) sit at 0.4x (Greens), 0.4x (Independents), 1.5x (One Nation), 0.3x
(Other) and 0.5x (Other right) of the measured per-class error in the previous table. UNVERIFIED: how `seat_sim`
applies those numbers per transfer (they may be per-step noise on top of seat-specific rates, so not directly
comparable), and the repo notes that blanket larger flow sd made federal log loss worse (0.2543 to 0.2607 at 15), so
raising them needs a `quick_arm.R` screen, not a straight swap.

### The number to use

- **Prior spread of the seat's aggregate flow (the `fsd` in `night_apply_tcp`): 0.065 (6.5 points), range 0.05 (2022-like)
  to 0.07 (2025-like).** Measured residual of predictor F on ALL: 5.2 to 7.9 by election (unweighted SD), 6.9 pooled
  votes-weighted.
- **Effect on the count's weight.** `night_tcp_obs()` reports a counted-flow standard error of about 2.3 points at 10%
  counted (see Q3). Precision weighting gives the count weight sd_prior² / (sd_prior² + se²): **16% at the 1-point floor,
  89% at 6.5 points.** That is the size of the "barely moves" effect, if the draws' spread is near the floor.

## Q2. Final-two prediction

"Guessed pair" = the model's two classes with the highest predicted first-preference share in
`output/published-predictions.csv` (the published path); "last pair" = the previous election's final pair in the same
division; "first-pref top two" = the two highest actual first-preference classes in that election (an upper bound for any
method that ranks by first preferences). Pairs are compared as unordered class pairs (Labor, Coalition, Greens, One
Nation, Independent, Other right, Other). Share of divisions where the guess equals the AEC's final pair; higher is better.

| Election | Divisions | Model's top two | Model's top two by win probability | Last election's pair | Last election's first-pref top two | Actual first-pref top two (bound) |
|---|---|---|---|---|---|---|
| 2007 | 150 | 99.3 | 99.3 | 98.0 | 98.0 | 99.3 |
| 2010 | 150 | 96.7 | 97.3 | 95.9 | 95.2 | 99.3 |
| 2013 | 150 | 94.0 | 93.3 | 94.7 | 94.0 | 99.3 |
| 2016 | 150 | 94.7 | 83.3 | 89.8 | 89.1 | 98.0 |
| 2019 | 151 | 96.7 | 83.4 | 95.1 | 93.7 | 98.7 |
| 2022 | 151 | 93.4 | 82.1 | 86.7 | 86.7 | 97.4 |
| 2025 | 150 | 90.0 | 76.0 | 89.9 | 88.6 | 95.3 |

Reading it: the model beats "last time's pair" in 6 of 7 elections and pools to 94.1% against 92.0% (n = 886 seats
where both exist, 2010-2025). It falls behind the first-preference upper bound by 4-5 points in 2022 and 2025, which is
the independent-challenger era (finals that were not Labor v Coalition: 11, 17, 27 and 35 seats in 2013, 2016, 2022
and 2025; in 2022 and 2025 that included Independent v Coalition 15 and 14, Labor v Greens 6 and 9, Labor v Independent
2 and 8). Caveat: the top-two-of-mean-share rule is not the sim's most likely pair; the sim itself gave the
AEC's pair an average of 87.6% (2022) and 84.4% (2025) of draws, 6 seats under 20% each year and 11-12 under 50%
(`aef7-tcp-actual.csv`). Published classes collapse several candidates into one row (n_cands), so a class with two
minor candidates is ranked by its summed share (UNVERIFIED effect).

### Misses, model's top two against the AEC's final pair

Model share of draws that produced the AEC's pair in the last column (blank where the harness file has no row); under
20% (marked *) is where `night_apply_tcp` discards the AEC count. Classes: LNP = Coalition.

| Election | Seat | Model's pair | AEC final pair | Last time | P(actual pair) |
|---|---|---|---|---|---|
| 2022 | Bradfield | ALP-LNP | IND-LNP | ALP-LNP | 0.088* |
| 2022 | Calare | ALP-LNP | IND-LNP | ALP-LNP | 0.067* |
| 2022 | Cowper | ALP-LNP | IND-LNP | IND-LNP | 0.086* |
| 2022 | Fowler | ALP-LNP | ALP-IND | ALP-LNP | 0.278 |
| 2022 | Griffith | ALP-LNP | GRN-LNP | ALP-LNP | 0.095* |
| 2022 | Groom | ALP-LNP | IND-LNP | ALP-LNP | 0.012* |
| 2022 | Nicholls | ALP-LNP | IND-LNP | ALP-LNP | 0.267 |
| 2022 | North Sydney | ALP-LNP | IND-LNP | ALP-LNP | 0.277 |
| 2022 | Ryan | ALP-LNP | GRN-LNP | ALP-LNP | 0.405 |
| 2022 | Wannon | ALP-LNP | IND-LNP | ALP-LNP | 0.164* |
| 2025 | Bean | ALP-LNP | ALP-IND | ALP-LNP | 0.507 |
| 2025 | Berowra | IND-LNP | ALP-LNP | ALP-LNP | 0.236 |
| 2025 | Brisbane | GRN-LNP | ALP-LNP | GRN-LNP | 0.302 |
| 2025 | Calwell | ALP-LNP | ALP-IND | ALP-LNP | 0.130* |
| 2025 | Farrer | ALP-LNP | IND-LNP | ALP-LNP | 0.502 |
| 2025 | Franklin | ALP-LNP | ALP-IND | ALP-LNP | 0.628 |
| 2025 | Fraser | ALP-LNP | ALP-GRN | ALP-LNP | 0.167* |
| 2025 | Fremantle | ALP-LNP | ALP-IND | ALP-LNP | 0.618 |
| 2025 | Griffith | GRN-LNP | ALP-GRN | GRN-LNP | 0.259 |
| 2025 | Hunter | ALP-LNP | ALP-ONP | ALP-LNP | 0.160* |
| 2025 | Macnamara | ALP-GRN | ALP-LNP | ALP-LNP | 0.398 |
| 2025 | Mayo | IND-LNP | ALP-IND | IND-LNP | 0.239 |
| 2025 | Monash | IND-LNP | ALP-LNP | ALP-LNP | 0.120* |
| 2025 | Newcastle | ALP-LNP | ALP-GRN | ALP-LNP | 0.196* |
| 2025 | Watson | ALP-LNP | ALP-IND | ALP-LNP | 0.017* |

Reading it: in 7 of the 10 misses in 2022 the AEC's pair was Independent v Coalition (the teals and Calare/Cowper/Groom/
Nicholls/Wannon) against a model pair of Labor v Coalition; in 2025 six were Labor v Independent (Bean, Calwell, Franklin,
Fremantle, Mayo, Watson), 3 Labor v Greens, and 4 had the model putting a challenger into a seat that finished Labor v
Coalition (Berowra, Brisbane, Macnamara, Monash). Last election's pair would have been right in 1 of the 10 seats the model missed in 2022
(Cowper) and 3 of the 15 in 2025 (Berowra, Macnamara, Monash). 12 of 25 had the actual pair under 20% of draws (marked), so the count would have been
dropped by the current rule: 6 + 6 seats, 4.0% of 301 seat-elections; 23 under 50% (7.6%).

## Q3. Booth-level flows

### Q3a. Aggregate booth flows, fed2022 and fed2025 (ordinary booths, Labor-v-Coalition seats with 5+ booths)

Standard deviation in points of a booth's flow around its seat's flow, weighted by the booth's other-party votes
(n = 6,898 booths in 124 seats in 2022; 6,734 in 115 seats in 2025). "Sampling" is what vote counts alone would produce;
the rest is real booth-to-booth difference. Lower spread would make early booths more informative.

| Election | Within-seat SD | Sampling SD | Real (excess) SD |
|---|---|---|---|
| 2022 | 6.2 | 2.4 | 5.7 |
| 2025 | 6.5 | 2.3 | 6.1 |

Stability: for the 5,110 booths present in both elections (same seat and booth name, 112 seats), the weighted
correlation of a booth's within-seat deviation, 2022 against 2025, is **0.73** (slope 0.79; larger half of booths
0.75 and 0.80). Booth flows are a stable local feature.

What drives them: predict each booth's flow as the sum over other-party first-preference shares in that booth times the
previous election's national flow for that party. Share of the within-seat booth variance explained (weighted R-squared;
higher is better):

| Election | Within-seat SD, raw | Residual SD after composition | R-squared | Slope on composition deviation |
|---|---|---|---|---|
| 2022 | 6.2 | 3.5 | 0.68 | 1.34 |
| 2025 | 6.5 | 3.6 | 0.70 | 1.54 |

The slope above 1 means flows at the booth level are more extreme than the national class flows imply (composition also
proxies for local flow differences). The same composition model as a seat-level prediction (no counting at all)
has RMSE 7.0 (2022) and 6.1 (2025) points with a level bias of +5.6 and +2.6, i.e. no use on its own for the seat flow.

### Q3b. Per-party booth flows (2004, 2007, 2010, from the AEC flow-by-polling-place files)

Within-seat SD in points of a booth's flow to Labor for the party's excluded candidates (booths with 20+ transfers,
seats with 5+ such booths), against what sampling alone would give. Greens: n about 5,600-6,600 booths per election.

| Class | Within-seat SD (2004 / 2007 / 2010) | Sampling SD (2004 / 2007 / 2010) |
|---|---|---|
| Greens | 5.2 / 5.1 / 4.6 | 3.6 / 3.6 / 3.1 |
| Other right | 8.1 / 8.2 / 8.0 | 5.6 / 5.8 / 5.4 |
| One Nation | 8.7 / 10.0 / 9.0 | 7.1 / 8.4 / 7.8 |

Does a booth that ran above its seat's flow stay above at the next election? Weighted correlation of within-seat
deviation (this is attenuated by sampling noise: with half the variance real for Greens, the true persistence is about
0.38 / 0.5 = 0.75, my arithmetic, not a separate fit):

| Class | 2004 to 2007 (booths, correlation) | 2007 to 2010 (booths, correlation) |
|---|---|---|
| Greens | 4,846, 0.38 | 4,796, 0.38 |
| Other right | 3,308, 0.33 | 2,910, 0.36 |
| One Nation | 350, 0.13 | 104, 0.03 |

So Greens and other-right booth effects (e.g. Greens flowing less strongly to Labor in some areas) are real and persist;
One Nation booth flows are too noisy to use.

### Would this help the night model weight early booths? Early-count error of the seat flow

The replay-style test: count the smallest booths first until a share q of the seat's other-party votes is in, estimate
the seat's flow from those booths pooled, and compare with the seat's final ordinary-booth flow. RMSE in points (lower
is better). Nominal SE = the standard error `night_tcp_obs()` reports (mean over seats). z SD = SD of error / nominal
SE (1.0 would mean the SE is right; above 1 means too small). 239 seat-elections (124 + 115). Assumes small-first
reporting, which is the replay's convention, not the real order.

| Counted | Booths counted (median) | RMSE of plain pooled flow | Nominal SE | z SD | Mean bias |
|---|---|---|---|---|---|
| 10% | 18 | 2.88 | 2.32 | 1.29 | -0.1 |
| 25% | 29 | 1.90 | 2.04 | 0.93 | +0.3 |
| 50% | 42 | 1.24 | 2.02 | 0.55 | +0.6 |

Reading it: the reported SE hardly shrinks as more is counted (2.3 to 2.0), so it is too small early (28% at 10% counted)
and about twice too big by half-way. There is no systematic bias between small and large booths (mean flow deviation
of the smaller half of booths +0.34 and -0.17 pts against about 0 for the larger half; seat-to-seat SD 2.4-2.8).

Composition adjustment (add the gap in other-party mix between all booths and counted booths, times last election's
national class flows). RMSE in points, lower is better; "oracle" uses the uncounted booths' actual composition (an
upper bound on what the night could know); "prior booth" uses the same booths' 2022 composition for the uncounted
booths in 2025, which is what is actually available before they count.

| Election | Counted | Plain | Oracle composition | Prior-booth composition |
|---|---|---|---|---|
| 2022 | 10% | 2.78 | 1.65 | not tested |
| 2022 | 25% | 1.94 | 1.22 | not tested |
| 2022 | 50% | 1.15 | 0.70 | not tested |
| 2025 | 10% | 2.99 | 1.87 | 3.89 |
| 2025 | 25% | 1.86 | 1.10 | 2.69 |
| 2025 | 50% | 1.33 | 0.77 | 1.51 |

Reading it: knowing the uncounted booths' current mix would cut early error by about 40%, but using the PREVIOUS
election's booth mix made it worse (bias -2.5 to -0.5), because the 2022-to-2025 first-preference shift (One Nation up,
Greens up) is exactly what the adjustment needs to see. It only works if the mix comes from the night's own updated
first-preference forecast. UNVERIFIED: a seat-level version using the night model's posterior class shares for the
uncounted vote; not tested here.

## Ranked changes

Gain sizes are from the measurements above; "UNVERIFIED" marks gains I have not run through the night replay or
`quick_arm.R`.

1. **`night_apply_tcp()` (`R/night_update.R`, the `fsd <- max(stats::sd(fi), 0.01)` line): floor the prior flow spread at
   0.065 (0.05-0.07), not 0.01.** Input: nothing new; the measured aggregate flow error. Effect: the counted flow gets
   about 89% of the weight instead of 16% (calculation above). Size: this is the main reason the count barely moves the
   model, if the draws' spread is near the floor; check it first by printing `sd(fi)` per seat in the replay (not stored
   today). Expected gain on the replay: UNVERIFIED, likely the biggest single change for the night model. Test by
   replaying all seven elections with the floor at 0.03/0.05/0.065.
2. **`night_tcp_obs()` (`R/night_update.R`): fix the counted-flow standard error.** Multiply the SE by about
   `sqrt(1 - share counted)` (realised error 2.9/1.9/1.2 pts at 10/25/50% against nominal 2.3/2.0/2.0; the correction
   gives 2.2/1.8/1.4) and use at least 2.9 points below ~15% counted. Fitted on two elections and three points, small-first
   order: UNVERIFIED on other orders and states.
3. **Condition on the AEC count when its final pair is unseen (`night_apply_tcp()` pair_min branch).** Today a pair in
   under 20% of draws drops the count: 12 of 301 federal seat-elections (4.0%), 23 under 50%. Those are exactly the
   independent/Greens seats that decide the headline (Monash, Watson, Bradfield, Calare, Groom). Replace the discard by
   a fallback: treat the counted share of the observed pair (with the booth SE and the prior spread above) as the seat's
   winner probability. Gain: large per seat, small in count; UNVERIFIED in size.
4. **Class-specific flow update on the night** (`night_tcp_obs()`, `night_apply_tcp()`): track the counted flow per
   excluded-party class and re-weight with the seat's updated first-preference mix, instead of one scalar flow. Needs
   the uncounted vote's mix from the night model's own updated first preferences (not the prior election's booths).
   Gain: up to about 1.1-1.2 pts of early seat-flow RMSE (40%) as an upper bound with the actual mix; a realised gain
   is UNVERIFIED and smaller.
5. **Pre-election flow prior: per-class shrinkage weight on the seat's previous flow** (flow builder in
   `R/flow_matrix.R` / `R/flow_model.R`, per-seat override). Weights from the fit: aggregate 0.80, Greens 0.53, Other
   right 0.49, Other 0.33, One Nation 0.29, Independents 0.11; no state term (it added nothing: F = D). Gain: small,
   about 0.2-0.6 pts RMSE (Independents 11.2 to ~10.6; others a few tenths), and the model's seat flows currently tie
   the persistence predictor, so check the xgb flow layer is not adding noise on seats with a previous value.
6. **Flow noise by class (`flow_sd` / `output/flow-uncertainty-sd.rds`): set per-class targets near the measured
   error** (Greens ~5, Other right ~8, Independents ~11, Other ~11, One Nation ~7 pts) after confirming how the sim
   applies the number. The shipped values (2.0, 3.8, 4.4, 3.7, 10.4) are 0.3x-0.5x of that for four classes. Risk:
   blanket larger sd lost log loss before; screen with `quick_arm.R` first. Gain UNVERIFIED.
7. **Final pair (`simulate_seat_contests()`): no change from the DOP data.** The model already matches or beats
   persistence; the gap is independent/Greens emergence, which is the surge model's job, not a flow-data one. If a use
   is wanted: log the sim's most-likely pair (not top-two of mean share) in the published predictions so this check can
   use it directly.
8. **Booth effects.** Greens and other-right booth flows persist (correlation about 0.75 once sampling noise is removed),
   but 70% of booth variation is composition. A booth-specific flow offset adds little over change 4; skip until 2013-2016
   per-party booth files are in and the composition adjustment has been replayed.

## Limits

- Flow definition ignores votes that go to other minors (so is Labor/(Labor+Coalition) among receipts), and seats where
  the finalists include a minor are excluded from "ALL"; 115-147 seats per election.
- Predictors A-F share the one pooled weight across minor classes; the by-class weights above are the all-pairs fits
  and were not scored out of sample.
- 2010-2025 is six scored elections. Election-level spread of the key number (ALL residual SD 5.2 to 7.9) is wider than
  the pooled average suggests.
- The booth early-count tests use only 2022 and 2025 and a small-first order.
- My national flows disagree with the repo's AEC-notional flows (see anchor note).

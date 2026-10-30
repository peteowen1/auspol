# Federal election-night replay, 2022 and 2025 (2026-10-30)

**What this is.** The Victorian election-night booth model (`R/night_update.R`, `R/booth_projection.R`,
`scripts/night_replay_json.R`) replayed on the federal elections of 2022 and 2025: the published pre-election forecast
is the prior, and booths are "counted" in a simulated order (small booths first) and compared with the same booths at
the previous election. The question was when the night could have called a Labor majority, and when it could have
called Wentworth for Allegra Spender.

**Short answer.**

- **2025: the night calls a Labor majority very early.** P(Labor majority) stays at or above 0.99 from **10% of the
  night's vote** (9.1% of all votes counted; indicative 6:24pm). Labor is the largest party with P ≥ 0.99 from the first
  2% of the vote (6:05pm).
- **2022: the night never calls a Labor majority**, and that is roughly right: Labor won 77 of 151, one over the line,
  and the replay ends at 75.1 expected seats (90% range 73-77), P(majority) 0.39. It does call Labor as **largest party**
  from 30% of the night's vote (28% counted; indicative 7:12pm).
- **Wentworth.** 2025: P(Spender) ≥ 0.99 from 75% of the night's vote (66% counted; 9:00pm), though it sits at
  0.985-0.990 from the first booths. **2022: never called, and wrong at the end** (P(Spender) 0.30 with 97% of the seat
  counted, while the counted two-candidate count had her on 54.0%).
- **The Wentworth 2022 miss is two defects in the shared night code, not a data problem.** Both are described under
  "Defects found" with the exact change each needs. Neither was fixed here (the brief excluded `R/` and the shared night
  scripts). A diagnostic run with the first one patched in a scratch copy calls Wentworth 2022 from 30% of the night's
  vote; see "Diagnostic runs".

## How the replay was run

- **Booth tables** (new, `scripts/build_night_booths_fed.R`): `output/booths-fed2019.csv`, `-fed2022.csv`,
  `-fed2025.csv` and `output/booths/fed2022-booth-tcp.csv`, `fed2025-booth-tcp.csv`, all from AEC final-results files
  already on disk except the two-candidate-by-polling-place files, fetched and kept raw under
  `external/reference/aec/booths/raw-tcp/`. Checks passed (printed by the script): 151 / 151 / 150 divisions; every
  division's ordinary booths sum to the AEC's `OrdinaryVotes` and all vote types to `TotalVotes`; net of non-affiliated
  candidates every division equals the harness's own `external/elections/aec-fed-firstprefs.csv`; the two-candidate
  booth sums equal the AEC's vote-type two-candidate file and the formal total; no NA party.
- **Pre-poll voting centres are kept as named ordinary units**, not merged into one "early" lump. PPVC votes are
  ordinary votes, a PPVC usually keeps its name between elections (so it gets a like-for-like swing against the same
  centre last time), and the report order (by booth size) already puts the big centres late, as on the real night.
  Pre-poll DECLARATION votes are the "early" unit; postal, absent and provisional votes one unit each per division.
- **Party names**: the night code classifies by party NAME only, the harness by name and code. Two AEC names classify
  differently by name alone (fed2022 "A.L.P." and fed2025 Queensland's bare "LNP", which by name fell to OTH: 7.1% of
  the national vote) and are written as e.g. "Liberal National Party (AEC name: LNP)". Non-affiliated candidates (blank
  party, 1-4 per election) are written "Non Affiliated" and classify OTH, because the harness's results file drops them
  rather than counting them as independents.
- **Night state**: the AUSPOL_NIGHT_DUMP block ported to `scripts/backtest_candidate_fed.R`, saved through
  `quick_arm.R` in a scratch folder. **The arm with the dump set was byte-identical to the shipped baseline** on both
  elections (quick_arm Q1), so the block changes nothing it should not. Pre-count seat log loss 0.2192 (fed2022) and
  0.3606 (fed2025) at **1,000 simulations** (quick_arm's default; the replay inherits the state's size). A probability
  of 0.99 therefore means 990 of 1,000 draws, and the 0.99 calls below can move a fraction either way with more draws.
- **Replay settings**: `night_replay_json.R` defaults (2CP conditioning ON, `early=interleaved`, `gap_k=5`).
- **The fraction is of the replay's night universe** (ordinary booths including PPVCs, pre-poll declarations and postals,
  with postals reporting last), and "counted" is the mean over seats of the share of ALL formal votes counted; absent and
  provisional votes are never counted, which is why 1.0 shows ~96.5%. **The clock is indicative only**: 6pm + 4 hours x
  fraction, the replay's convention, not real reporting times. In reality eastern booths close at 6pm AEST, WA's two hours
  later, and postals are counted over the following two weeks, so fractions above about 0.75 are not election night.

## fed2022

Seats right = seats where the model's favourite won (of 151, higher is better). Seat log loss = mean of -log(probability
given to the actual winner), floored at 0.0005 (lower is better). Labor seats: expected value and 5-95% range of
simulated Labor seat totals; majority is 76. Probabilities are 0-1.

| fraction | vote counted % | indicative clock | seats right / 151 | seat log loss | Labor seats (90% range) | P(Labor majority) | P(Labor most seats) | P(Spender wins Wentworth) |
|---|---|---|---|---|---|---|---|---|
| 0.00 | 0.0 | 6:00pm | 139 | 0.219 | 79.6 (68-93) | 0.691 | 0.900 | 0.648 |
| 0.02 | 1.6 | 6:05pm | 148 | 0.141 | 77.9 (71-86) | 0.703 | 0.986 | 0.560 |
| 0.05 | 4.4 | 6:12pm | 146 | 0.128 | 77.6 (70-86) | 0.651 | 0.969 | 0.331 |
| 0.10 | 9.1 | 6:24pm | 146 | 0.117 | 77.6 (71-85) | 0.687 | 0.979 | 0.311 |
| 0.15 | 13.9 | 6:36pm | 144 | 0.130 | 76.5 (70-84) | 0.565 | 0.977 | 0.309 |
| 0.20 | 18.6 | 6:48pm | 142 | 0.121 | 76.7 (71-84) | 0.582 | 0.982 | 0.312 |
| 0.30 | 28.0 | 7:12pm | 146 | 0.107 | 77.5 (71-84) | 0.680 | 0.990 | 0.321 |
| 0.40 | 37.7 | 7:36pm | 146 | 0.096 | 77.8 (72-84) | 0.749 | 0.995 | 0.328 |
| 0.50 | 46.5 | 8:00pm | 146 | 0.089 | 78.0 (73-84) | 0.785 | 0.997 | 0.322 |
| 0.75 | 66.4 | 9:00pm | 146 | 0.079 | 77.3 (73-82) | 0.738 | 1.000 | 0.303 |
| 1.00 | 96.5 | 10:00pm | 145 | 0.113 | 75.1 (73-77) | 0.388 | 1.000 | 0.302 |

Actual: Labor 77, Coalition 58, independents 11 (incl. Spender), Greens 4, Katter 1.

- **Labor majority: never called** (never stays ≥ 0.99; peak 0.785 at half the night). Defensible for a one-seat
  majority, but the end point is too low for the wrong reason: Lyons (Labor won with 50.9% of the two-candidate vote) is
  given to the Liberals at 0.989 with 95% counted, because of defect 2.
- **Labor largest party: from fraction 0.30** (28.0% counted, indicative 7:12pm), P = 0.990.
- **Wentworth: never called.** Spender falls from 0.65 before the count to 0.33 by 5% and stays there. Wrong at the end.
- Wrong at the end (6 seats): Curtin, Kooyong, Mackellar, Wentworth (all independents given to the Liberals, defect 1),
  Lyons (defect 2) and Gilmore (Labor by 373 votes; LNP 0.68, a fair miss).

Five seats whose probability for the actual winner moved most, pre-count to the end (probability for the winner, 0-1;
higher is better at the end):

| seat | winner | before the count | at 0.30 | at 0.75 | at 1.00 |
|---|---|---|---|---|---|
| Griffith | GRN | 0.099 | 0.861 | 0.970 | 0.992 |
| Lyons | ALP | 0.864 | 0.600 | 0.658 | 0.011 |
| Fowler | IND | 0.107 | 0.101 | 0.818 | 0.957 |
| Ryan | GRN | 0.152 | 0.971 | 0.994 | 0.995 |
| North Sydney | IND | 0.190 | 0.845 | 0.937 | 0.997 |

## fed2025

Same columns as above (150 divisions; majority still 76).

| fraction | vote counted % | indicative clock | seats right / 150 | seat log loss | Labor seats (90% range) | P(Labor majority) | P(Labor most seats) | P(Spender wins Wentworth) |
|---|---|---|---|---|---|---|---|---|
| 0.00 | 0.0 | 6:00pm | 127 | 0.361 | 72.4 (58-85) | 0.347 | 0.857 | 0.903 |
| 0.02 | 1.7 | 6:05pm | 138 | 0.217 | 84.7 (77-91) | 0.978 | 0.999 | 0.987 |
| 0.05 | 4.4 | 6:12pm | 139 | 0.189 | 86.6 (79-93) | 0.988 | 1.000 | 0.985 |
| 0.10 | 9.1 | 6:24pm | 140 | 0.178 | 89.1 (84-94) | 1.000 | 1.000 | 0.984 |
| 0.15 | 13.8 | 6:36pm | 141 | 0.165 | 89.6 (84-95) | 1.000 | 1.000 | 0.988 |
| 0.20 | 18.6 | 6:48pm | 144 | 0.159 | 90.1 (85-95) | 1.000 | 1.000 | 0.988 |
| 0.30 | 28.2 | 7:12pm | 143 | 0.145 | 91.0 (87-95) | 1.000 | 1.000 | 0.989 |
| 0.40 | 37.6 | 7:36pm | 145 | 0.139 | 91.3 (87-96) | 1.000 | 1.000 | 0.989 |
| 0.50 | 45.9 | 8:00pm | 145 | 0.126 | 92.0 (88-96) | 1.000 | 1.000 | 0.989 |
| 0.75 | 66.4 | 9:00pm | 144 | 0.127 | 91.3 (88-95) | 1.000 | 1.000 | 0.990 |
| 1.00 | 96.6 | 10:00pm | 143 | 0.169 | 90.6 (88-93) | 1.000 | 1.000 | 0.990 |

Actual: Labor 94, Coalition 43, independents 11, Greens 1, Katter 1.

- **Labor majority: from fraction 0.10** (9.1% counted, indicative 6:24pm), P = 1.000 (0.978 at 2%, 0.988 at 5%).
- **Labor largest party: from fraction 0.02** (1.7% counted, indicative 6:05pm), P = 0.999.
- **Wentworth: from fraction 0.75** (66.4% counted, indicative 9:00pm), P = 0.990. In practice it was a call from the
  first booths: 0.984-0.990 from 2% onwards, below 0.99 only by a few draws in 1,000.
- Labor is under-called at the end: 90.6 expected against 94 won. Wrong at the end (7 seats): Bradfield, Curtin and
  Kooyong (independents given to the Liberals, defect 1), Melbourne (Labor beat Bandt; GRN 0.90, defect 2), Monash
  (the AEC's count was Labor v Liberal, a pair the model never drew, so the count was thrown away: defect 3; IND 0.999),
  Fowler (Le won; ALP 0.86) and Bullwinkel (Labor; LNP 0.66).

Five seats whose probability for the actual winner moved most (as above):

| seat | winner | before the count | at 0.30 | at 0.75 | at 1.00 |
|---|---|---|---|---|---|
| Hughes | ALP | 0.068 | 0.497 | 0.967 | 0.990 |
| Petrie | ALP | 0.147 | 0.763 | 0.960 | 0.994 |
| Griffith | ALP | 0.158 | 0.973 | 0.986 | 0.986 |
| Forde | ALP | 0.150 | 0.676 | 0.794 | 0.970 |
| Dickson | ALP | 0.074 | 0.879 | 0.884 | 0.883 |

## Defects found (all live; none fixed here)

**1. The pre-election emergence surge still fires after the seat is counted.** `night_replay_json.R` (and
`night_replay_detail.R`, and very probably the live runner in `R/night_runner.R`, line ~489, unchecked) pass the state's
`surge_h` to `simulate_seat_contests()` unchanged at every fraction. Wentworth 2022 has `surge_h` = 0.327 for IND
(Kooyong 0.134, Curtin 0.103, Mackellar 0.129), so a third of draws add a jump of mean 36 points to Spender's primary
AFTER her counted primary is known to ±0.26. Those draws give her two-candidate shares of 0.80-0.99. Measured at 97%
counted: the draws' two-candidate share for Spender has median 0.527 (the real result was 0.540) but mean 0.608 because
of that tail. Defect 1 does the damage through defect 2's arithmetic: `night_apply_tcp()` moves every draw by the gap
between the counted flow and the MEAN of the draws, so the bulk drops from 0.527 to 0.462 and 694 of 1,000 draws flip to
Sharma. Spender goes from 0.996 before the two-candidate step to 0.302 after it. **Fix: shrink `surge_h` by the share
of the seat counted** (e.g. `surge_h * (1 - nu$counted[seat])`) in every night simulation call (the two replay scripts and
the runner), or zero it once a seat has reported.

**2. The counted two-candidate flow barely moves a seat, because the prior flow spread is the simulation's own
(near-zero) spread.** `night_apply_tcp()` (`R/night_update.R` line 333) combines the counted preference flow (standard
error floored at 0.02, typically 0.02-0.06) with the draws' implied flow, whose sd is floored at only **0.01**; with
`FLOW_SD = 0` the draws' flows are almost deterministic, so the prior gets 4-30 times the weight of the count. Lyons 2022
at 95% counted: counted two-candidate count 50.7% Labor, model 48.4% after conditioning, Labor 0.011. Calwell 2025
(surge-off run): counted 54.8% Labor, model 46.9%, Labor 0.000. Melbourne 2025: counted 53.3% Labor, model 48.2%, GRN
0.90. **Fix: floor the prior flow sd at a realistic between-seat flow error (0.05 tried below), or derive it from the
backtest's flow residuals** rather than the draws' spread. Also worth changing in the same function: shift each draw by
the change in its MEDIAN (or condition per draw), not the mean, so a mixture tail cannot drag the bulk across 50%.

**3. A counted pair the model never drew is thrown away.** `night_apply_tcp()` ignores the AEC's pair when it appears in
under 20% of draws (`pair_min`). Monash 2025: every draw had Broadbent (IND) in the final two; the AEC counted Labor v
Liberal; the count was flagged and dropped, and the seat stayed IND 0.999 with 97% counted. A counted pair is a fact on
the night, not a hypothesis: the model should re-run that seat's count with the pair forced (or at least zero the
draws whose pair contradicts it).

**Also noted (not a code defect):** the seat log loss gets WORSE from 0.75 to 1.00 in all four runs (0.079 -> 0.113,
0.127 -> 0.169). At 1.00 the first-preference projection's sd drops to 0.26, so a seat whose flow is wrong (defect 2)
becomes near-certain for the wrong candidate.

## Diagnostic runs (NOT the model; scratch copies only)

To size the defects, the same replay was rerun twice from scratch copies, without editing any repo code: (A) the saved
state with `surge_h` set to 0 in every seat (defect 1 removed, crudely: it also removes the surge BEFORE the count, so the
0.00 row differs from the published forecast); (B) as A, plus `night_apply_tcp()`'s prior flow sd floored at 0.05 instead
of 0.01 (defect 2), by a scratch copy of `night_replay_json.R` that redefines that one line. These are measurements of
the defects, not a proposed model: the 0.05 floor is a guess, not a fitted value.

Seat log loss = mean -log(probability for the actual winner), lower is better; seats right out of 151 / 150, higher is
better; call fractions are the first fraction from which the probability stays at or above 0.99.

| run | log loss at 0.30 / 0.75 / 1.00 | seats right at 1.00 | Labor seats at 1.00 (actual) | Labor majority call | Labor largest-party call | Wentworth call |
|---|---|---|---|---|---|---|
| fed2022 as shipped | 0.107 / 0.079 / 0.113 | 145 | 75.1 (77) | never (0.39 at end) | 0.30 | never (0.30 at end) |
| fed2022 A: surge off | 0.064 / 0.030 / 0.055 | 149 | 75.7 (77) | never (0.54 at end) | 0.20 | 0.30 (28% counted, 7:12pm) |
| fed2022 B: surge off + flow floor | 0.064 / 0.031 / **0.014** | **151** | **77.1** (77) | never (0.91 at end) | 0.20 | 0.30 (28% counted, 7:12pm) |
| fed2025 as shipped | 0.145 / 0.127 / 0.169 | 143 | 90.6 (94) | 0.10 (9% counted, 6:24pm) | 0.02 | 0.75 (66% counted, 9:00pm) |
| fed2025 A: surge off | 0.107 / 0.071 / 0.157 | 145 | 89.8 (94) | 0.05 (4% counted, 6:12pm) | 0.02 | 0.02 (1.7% counted, 6:05pm) |
| fed2025 B: surge off + flow floor | 0.108 / 0.070 / **0.054** | **148** | 92.7 (94) | 0.05 (4% counted, 6:12pm) | 0.02 | 0.02 (1.7% counted, 6:05pm) |

With both defects patched, fed2022 ends with every seat right and Labor on 77.1 expected seats (75-79), and Wentworth is
called for Spender from 30% of the night's vote. The 2022 Labor majority is still never called at 0.99, which is the
right answer for a one-seat majority with postals out. In fed2025 the two seats still wrong at the end are Monash
(defect 3, untouched by either patch) and Bullwinkel (a new seat in 2025, Labor won; LNP 0.68). Surge-off alone made
Calwell 2025 worse (Labor 0.000 at the end: counted 54.8% Labor, model 46.9%), which is defect 2 exposed once the surge
tail stopped masking it; the flow floor fixes it.

## Files

- New: `scripts/build_night_booths_fed.R`, `scripts/night_calls_fed.R` (call points and seat movers from a replay
  folder), `output/booths-fed2019.csv`, `output/booths-fed2022.csv`, `output/booths-fed2025.csv`,
  `output/booths/fed2022-booth-tcp.csv`, `output/booths/fed2025-booth-tcp.csv`, raw AEC files under
  `external/reference/aec/booths/raw-tcp/`.
- Changed: `scripts/backtest_candidate_fed.R`, the AUSPOL_NIGHT_DUMP block only (byte-identical output when set; does
  nothing when unset).
- `scripts/score_night_replay.R` wrote `docs/reviews/night-replay-fed2022-{summary,seats}-2026-10-30.csv` and the fed2025
  pair; its numbers agree with the tables above.
- Scratch (not in the repo): the night states, replay JSON folders and per-seat detail JSONs under
  `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\d9620856-015e-4f5d-8963-ed4e84fea399\scratchpad\fed\`.

## Not verified

- Real-world call times are not compared: I did not check when broadcasters called either election or Wentworth.
- `R/night_runner.R` (the live runner) was not read closely; defect 1 is inferred to apply there from its use of
  `st$surge_h` (line ~489).
- 1,000 simulations only; the 0.99 call fractions are within a few draws of moving.
- Another session edited `night_apply_tcp()` at 7:02pm today (renormalises a seat's win probabilities when a 2CP flip
  would push them above 1; uncommitted in the working tree). Both as-shipped replays and the fed2022 surge-off run loaded
  the code before that edit; the fed2025 surge-off run and both flow-floor runs loaded it after. The edit changes a seat's probabilities by at most a few thousandths, so the comparison stands,
  but the runs are not all on byte-identical code.

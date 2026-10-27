# Live-forecast walk for the contested Victoria 2026 seats (2026-10-28)

Question: which stage of the live forecast carries the gap to the bookmakers in four eastern-suburbs seats, is the xgb
cut to the Liberal real, and how sensitive are Eureka and Narracan to One Nation's spread. Context:
`contested-seats-vic2026-2026-10-28.md`.

Method: `scripts/fit_seats_full.R` run seven times on `dev` (code unchanged, nothing edited), seed 42 in every run, one
switch changed per run, each with `AUSPOL_OUT_SUFFIX=-walk-<label>`. Started 07:15, each run about 3.3 minutes, every
run exited 0. Files read: `seat-shares-vic-2026-walk-<label>.csv` (primary vote, percent) and
`seat-probs-vic-2026-walk-<label>.csv` (win probability, 0 to 1, from the simulation). Logs and walk files were moved to
the scratchpad `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\39010bb2-4069-4b67-8612-d07117b76033\scratchpad\walk\`
and `output/` is back to its starting git status (clean, no walk files left).

The S6 line of each log shows the switch took effect: `changed: AUSPOL_XGB_PRIMARY_LIVE`, `changed: AUSPOL_SEAT_SWING_PORT`,
`changed: AUSPOL_SEAT_POLL_BLEND`, `changed: AUSPOL_ONP_CV`, `changed: AUSPOL_SEAT_SWING_PORT_3C`; the `base` S6 line has
`changed:` empty. Off values: "0" is off for all three (xgb code tests `== "1"`, port tests `== "2"`, poll blend
accepts only "1", "2", "3"). In the no-xgb log the "XG4 LIVE xgb v6 ... ON" line is absent; in the no-port log the
"SP2 ... seat-swing port" lines are absent.

Not checked: Monte Carlo noise between runs. All runs share seed 42, so untouched seats mostly do not move, but small
moves in seats a switch should not touch (Carrum -0.050 in `port3c`) are probably simulation noise. Treat win
probability moves under about 0.05 as unproven.

## Experiment 1: what each stage does to the four seats

Table: primary vote in percent and win probability (0 to 1) per run, change against `base` in brackets (percentage
points for primaries, probability points for win probability). A "no X" run removes stage X, so a stage that helps
Labor shows as Labor falling when removed. Higher P(ALP) is better for Labor. Bookmakers' Labor probabilities:
Box Hill 0.26, Ashwood 0.21, Glen Waverley 0.12, Bayswater 0.05.

| Seat | Run | ALP primary | LNP primary | ONP primary | GRN primary | P(ALP) | P(LNP) |
|---|---|---:|---:|---:|---:|---:|---:|
| Box Hill | base | 34.0 | 31.8 | 9.8 | 19.3 | 0.882 | 0.102 |
| | no xgb | 32.6 (-1.4) | 33.0 (+1.2) | 10.0 (+0.2) | 18.7 (-0.6) | 0.793 (-0.089) | 0.189 (+0.088) |
| | no port | 33.5 (-0.4) | 32.2 (+0.4) | 9.8 (0.0) | 19.3 (0.0) | 0.862 (-0.021) | 0.120 (+0.019) |
| | no poll blend | 34.0 (0.0) | 31.8 (0.0) | 9.8 (0.0) | 19.3 (0.0) | 0.882 (0.000) | 0.102 (0.000) |
| Ashwood | base | 31.5 | 33.5 | 11.7 | 18.5 | 0.696 | 0.286 |
| | no xgb | 30.4 (-1.1) | 33.9 (+0.4) | 12.1 (+0.4) | 18.7 (+0.2) | 0.619 (-0.077) | 0.361 (+0.075) |
| | no port | 31.2 (-0.3) | 33.8 (+0.3) | 11.7 (0.0) | 18.5 (0.0) | 0.675 (-0.021) | 0.307 (+0.021) |
| | no poll blend | 31.5 (0.0) | 33.5 (0.0) | 11.7 (0.0) | 18.5 (0.0) | 0.696 (0.000) | 0.286 (0.000) |
| Glen Waverley | base | 33.4 | 33.9 | 13.5 | 13.3 | 0.497 | 0.495 |
| | no xgb | 31.3 (-2.1) | 35.6 (+1.6) | 13.6 (+0.1) | 13.4 (+0.1) | 0.301 (-0.196) | 0.692 (+0.196) |
| | no port | 32.3 (-1.1) | 35.0 (+1.1) | 13.5 (0.0) | 13.3 (0.0) | 0.380 (-0.118) | 0.614 (+0.118) |
| | no poll blend | 33.4 (0.0) | 33.9 (0.0) | 13.5 (0.0) | 13.3 (0.0) | 0.497 (0.000) | 0.495 (0.000) |
| Bayswater | base | 29.8 | 30.9 | 20.3 | 11.6 | 0.224 | 0.704 |
| | no xgb | 30.5 (+0.8) | 31.0 (+0.2) | 20.0 (-0.4) | 11.1 (-0.5) | 0.254 (+0.029) | 0.684 (-0.019) |
| | no port | 28.2 (-1.6) | 32.4 (+1.6) | 20.3 (0.0) | 11.6 (0.0) | 0.122 (-0.103) | 0.818 (+0.114) |
| | no poll blend | 29.8 (0.0) | 30.9 (0.0) | 20.3 (0.0) | 11.6 (0.0) | 0.224 (0.000) | 0.704 (0.000) |

`base` P(ALP) reproduces the published 0.88, 0.70, 0.50, 0.22. The poll blend changes nothing in these seats: its log
line reads "1 of 1 polled cells applied across 1 seats ... mean |change| 0.00 points" (one seat poll in the state).

Statewide expected seats (sum of seat win probabilities): base ALP 31.6, LNP 36.2, ONP 13.9; no xgb ALP 27.2, LNP 37.5,
ONP 16.7; no port ALP 31.0, LNP 35.6, ONP 14.9.

Verdict: no single stage carries the gap to the bookmakers. Removing the xgb layer or the port lowers our Labor
probability (except xgb in Bayswater, where it costs Labor 0.8 points) but leaves it far above the bookmakers (for
example Glen Waverley without xgb 0.30 against 0.12; the two removals were not combined). The 25 Oct inference that xgb
cuts about 3 points from the Liberal is NOT supported: measured, xgb cuts the Liberal primary by 1.2 (Box Hill), 0.4
(Ashwood), 1.6 (Glen Waverley) and 0.1 (Bayswater), and raises the Labor primary by 1.4, 1.1, 2.1 and lowers it 0.8. The
rest of the gap sits in the earlier stages (base swing and One Nation fill), which were not switched off here and
remain unmeasured.

## Experiment 2: One Nation spread sensitivity

How the spread is chosen (`scripts/fit_seats_full.R` lines 774-900): with `AUSPOL_ONP_ORDER=senate_rank` the 2025
Senate One Nation vote only ORDERS the seats. The magnitudes are `sa_ratio`, the sorted South Australian 2026 One
Nation seat shares from `ecsa-2026-sa-onp-shares.csv` (line 781), quantile-mapped by rank, then rescaled to the CV
target (line 877; 0.327 before forcing). The `curve_a`/`curve_b` columns in `output/onp-senate-vic2026.csv` (`source
sa2026`, `n_fit 47`) are used only under the refused `AUSPOL_ONP_ORDER=senate`. No switch pools Queensland 2017 with
SA 2026, so I ran the CV sensitivity instead. Log lines: "CN1 One Nation concentration forced: CV 0.327 -> 0.300
(delivered 0.300)" and "CV 0.327 -> 0.430 (delivered 0.430)"; S6 shows `changed: AUSPOL_ONP_CV`.

Table: One Nation primary (percent) and win probability (0 to 1) at CV 0.30 / 0.365 (published, = base) / 0.43. A lower
CV spreads One Nation more evenly across seats. No direction is good; this is how much the answer moves.

| Seat | ONP primary: 0.30 / 0.365 / 0.43 | P(ONP): 0.30 / 0.365 / 0.43 | Other effect |
|---|---|---|---|
| Eureka | 29.4 / 31.4 / 33.3 | 0.766 / 0.870 / 0.927 | P(LNP) 0.183 / 0.102 / 0.055 |
| Narracan | 32.3 / 34.4 / 36.6 | 0.353 / 0.534 / 0.703 | P(LNP) 0.645 / 0.465 / 0.296 |
| Hastings | 28.1 / 29.8 / 31.5 | 0.483 / 0.617 / 0.749 | P(LNP) 0.491 / 0.365 / 0.239 |
| Cranbourne | 25.0 / 25.9 / 26.8 | 0.171 / 0.218 / 0.276 | P(ALP) 0.799 / 0.755 / 0.698 |
| Statewide expected ONP seats | 11.5 / 13.9 / 16.8 | | |

Verdict: Eureka stays One Nation's seat across the whole range (0.77 to 0.93), so this knob does not make it less
confident than the bookmakers' 0.46; Narracan (0.35 to 0.70) and Hastings (0.48 to 0.75) swing a lot, and even at CV
0.30 both stay above the bookmakers' 0.20 (Narracan) and 0.25 (Hastings). Pooling a second election's spread would need a code change and was
not tested.

## Experiment 3 (coordinator add-on): `AUSPOL_SEAT_SWING_PORT_3C=2`

What it is: cleans the port's transposed federal swing where the Coalition's federal line-up changed between the two
elections, with a fitted weight on the affected deviation. Table: primary (percent) and win probability (0 to 1) in
`port3c`, change against `base` in brackets.

Log lines, quoted from `walk-port3c.log`:
- S3C1 vic2026 <- fed2025: 4 Coalition line-up change(s) in its booths (bendigo LP->LP+NP, indi LP+NP->LP, nicholls LP+NP->NP, nicholls LP->NP); 9 of 88 seats touched; largest: Bendigo West 100%, Benambra 100%, Ovens Valley 100%, Shepparton 100%, Bendigo East 99%, Euroa 98%; coverage: 0 of 1846 map booths absent from the fed2025 two-party file, 0 with no votes; 6.1% of votes in booths new since the earlier election (compared by division name); 0.0% of votes with an unreadable line-up (treated unaffected); 0 of 88 seats unmatched
- S3C2 vic2026: line-up weight fitted on 9 earlier cycles: 70 affected seat rows, b_unaffected 0.459, b_affected 0.081 (se 0.427), w 0.006
- SP2 vic2026, port3c run: coef 0.451 (unshrunk 0.462), adjustment range -2.18..+4.51 (base run: coef 0.424, range -5.98..+4.41).

| Seat | Run | ALP | LNP | ONP | GRN | P(ALP) | P(LNP) | P(ONP) |
|---|---|---|---|---|---|---|---|---|
| Bendigo West | base | 23.0 | 27.2 | 23.6 | 14.3 | 0.082 | 0.544 | 0.363 |
| | port3c | 28.0 (+5.0) | 22.2 (-5.0) | 23.6 (0.0) | 14.3 (0.0) | 0.364 (+0.282) | 0.188 (-0.356) | 0.434 (+0.071) |
| Bendigo East | base | 23.0 | 29.9 | 27.6 | 11.4 | 0.013 | 0.597 | 0.387 |
| | port3c | 28.8 (+5.8) | 24.1 (-5.8) | 27.6 (0.0) | 11.4 (0.0) | 0.149 (+0.136) | 0.207 (-0.391) | 0.641 (+0.254) |
| Benambra | base | 4.0 | 39.3 | 33.2 | 7.8 | 0.000 | 0.798 | 0.201 |
| | port3c | 5.3 (+1.3) | 38.0 (-1.3) | 33.2 (0.0) | 7.8 (0.0) | 0.000 | 0.753 (-0.045) | 0.246 (+0.045) |
| Ovens Valley | base | 7.5 | 43.1 | 31.5 | 10.1 | 0.000 | 0.904 | 0.096 |
| | port3c | 8.2 (+0.7) | 42.4 (-0.7) | 31.5 (0.0) | 10.1 (0.0) | 0.000 | 0.893 (-0.010) | 0.106 (+0.010) |
| Shepparton | base | 3.3 | 43.7 | 33.2 | 5.9 | 0.000 | 0.905 | 0.095 |
| | port3c | 3.3 (0.0) | 43.7 (0.0) | 33.2 (0.0) | 5.9 (0.0) | 0.000 | 0.905 (0.000) | 0.095 (0.000) |
| Euroa | base | 14.0 | 40.1 | 32.8 | 6.5 | 0.000 | 0.824 | 0.176 |
| | port3c | 14.1 (+0.1) | 40.1 (-0.1) | 32.8 (0.0) | 6.5 (0.0) | 0.000 | 0.822 (-0.001) | 0.177 (+0.001) |
| Murray Plains | base | 6.4 | 43.8 | 34.5 | 7.4 | 0.000 | 0.859 | 0.141 |
| | port3c | 6.5 (+0.0) | 43.7 (0.0) | 34.5 (0.0) | 7.4 (0.0) | 0.000 | 0.857 (-0.002) | 0.143 (+0.002) |
| Eildon | base | 12.0 | 39.0 | 31.2 | 11.3 | 0.000 | 0.838 | 0.161 |
| | port3c | 12.4 (+0.4) | 38.6 (-0.4) | 31.2 (0.0) | 11.3 (0.0) | 0.000 | 0.828 (-0.011) | 0.172 (+0.011) |
| Macedon | base | 25.2 | 21.3 | 24.9 | 14.0 | 0.225 | 0.141 | 0.597 |
| | port3c | 25.1 (-0.2) | 21.4 (+0.2) | 24.9 (0.0) | 14.0 (0.0) | 0.217 (-0.008) | 0.148 (+0.007) | 0.598 (+0.001) |

Other seats whose winner probability (any party) moves by more than 0.05: only Carrum ALP -0.050 (0.591 to 0.541, at
the threshold; Carrum is not a touched seat, so probably simulation noise). All other moves above 0.05 are Bendigo East
(LNP -0.391, ONP +0.254, ALP +0.136) and Bendigo West (LNP -0.356, ALP +0.282, ONP +0.071). Bendigo East's most likely
winner changes from the Coalition (0.597) to One Nation (0.641); Bendigo West's from the Coalition (0.544) to One Nation
(0.434), Labor second (0.364). Statewide expected seats: ONP 13.9 to 14.2, ALP 31.6 to 31.4, LNP 36.2 to 36.0.

Check against the pre-registration (Bendigo West adjustment about -5.14 to about -0.21, w about 0.006): `w 0.006`
matches exactly (S3C2). The run did not print Bendigo West's adjustment itself. Its Labor and Coalition primaries each
moved 5.0 points (23.0 to 28.0, 27.2 to 22.2), consistent with the adjustment going from about -5.1 to about -0.2
(inferred, not read from a printed value). The state-wide minimum adjustment moved from -5.98 to -2.18.

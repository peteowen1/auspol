# Pre-registration: seat flow persistence (2026-11-08)

Pete, 8 Nov ("go", after the five-seat fed2025 walk). Committed BEFORE any arm run.

**What the change does, in plain words.** Some seats send more of their minor-party and independent votes to
Labor than the election average, and that tendency repeats: across 112 seats that were Labor v Coalition in
both 2022 and 2025, a seat's 2025 flow miss correlates 0.27 with its 2022 miss (research: 0.25-0.49 over six
federal elections, `reviews/tcp-mae-vs-aef-2026-11-07.md` section 4). The flow trees have no feature for a
seat's own past flows. This arm gives each seat a small shift toward its own history.

**Definitions (fixed now).**
- A seat's effective flow at election E, where the final two were Labor and the Coalition:
  `f = (TCP_ALP - FP_ALP) / (100 - FP_ALP - FP_LNP)`, from the AEC's own counts (`aec-fed-tcp.csv`, first
  preferences from the candidate corpus). Seats with under 3% "others" are skipped.
- Its tendency `d_E = f - mean f over that election's seats` (an election-wide swing cancels).
- Weight `w_T`: slope of `d_E` on `d_{E-1}` for the same seat name, over every federal election pair BEFORE the
  target T (time-forward). A slope below 1 is itself the shrinkage; no further tuning.
- In the target, for each seat with a `d_{T-1}`: every flow row in which both Labor and the Coalition are still
  in the count moves `w_T * d_{T-1}` of the votes going to the two of them from the Coalition to Labor (negative
  moves the other way), clamped so neither share goes below 0.

**Amendment (8 Nov, before any arm ran; the definitions above are left unedited).** `d = f - election mean` double counts: built, it persists at 0.59-0.70, but most of that is the vote mix (a seat with many Greens sends more to Labor), which the flow trees already model. The term uses instead the seat's MISS against our own prediction, the quantity the research measured (0.25-0.49): `r_E = f_actual - f_ours`, where `f_ours` uses our published-path primaries (`published-predictions.csv`) and our ALP-v-LNP TCP for that election (`backtest-fedE-ourtcp`, newest shipped run; each backtest of E uses only data before E). `w_T` is the slope of `r_E` on `r_{E-1}` over earlier pairs, and the shift is `w_T * r_{T-1}`.

**Arm:** `AUSPOL_SEAT_FLOW_PERSIST=1` (built off), federal harness only in this round. States follow only if
federal passes (their TCP histories need building).

## Metrics

1. **Primary:** pooled seat log loss over the federal pairs the screen runs, lower is better; pass if lower by
   at least 1 SE (election-clustered, as `quick_arm.R` prints it).
2. **Second:** TCP MAE on Labor v Coalition seats whose final two our model matched, fed2022 and fed2025
   (`score_tcp_arm.R`), against the research proxy (fed2022 2.680 -> 2.609, fed2025 5.084 -> 4.978).

## Guards (refuse even if the primary passes)

1. Any federal election worse by more than 1 SE of its own seat-level change.
2. Any non-federal pair not byte-identical.
3. 0 primary cells moved (the arm acts on flows only).
4. The fitted `w_T` printed for every target and between 0 and 1; outside that, the arm is broken, not tuned.

## Predicted result, written before running

Small: seat log loss -0.001 to -0.003 pooled; TCP MAE fed2022 and fed2025 each about -0.05 to -0.10. It will
not fix fed2025's worst seats (Blaxland, Dickson): their 2022 misses had the opposite sign or were small.

## RESULT

**Screen, 8 Nov ~10:30am (1k; baseline `53ba1f00cc05`, arm `97bf30ce4853`; fed2013-fed2025): REFUSED.**
w_T 0.450 / 0.424 / 0.363 / 0.377 / 0.352 (fed2013 / 16 / 19 / 22 / 25; fed2007 and fed2010 have none).
Seat log loss, lower is better: fed2013 0.3383 -> 0.3426, fed2016 0.2326 -> 0.2343, fed2019 0.2193 -> 0.2235,
fed2022 0.2392 -> 0.2361, fed2025 0.3322 -> 0.3230; pooled 752 seats 0.2722 -> 0.2718 (-0.0004, SE 0.0026):
primary NOT met. AEF-7 subset (fed2022 + fed2025, 301 seats) -0.0061 (SE 0.0030). 0 of 5,264 primary cells moved.
TCP MAE, ALP v LNP matched seats: fed2022 2.617 -> 2.494 (-0.123, SE 0.062), fed2025 5.078 -> 4.959 (-0.119, SE
0.053), better than the research proxy. Reading: the margins sharpen, but in the three older elections the
shifted flows move win probabilities the wrong way. Not shipped; the AEF-7 split goes to Pete. Built, off.

## Amendment 2: per-seat precision shrinkage (Pete, 8 Nov, after the screen; criteria above unchanged)

Pete asked whether the term is shrunk. It was only globally (w ~0.35 pulls every miss 65% toward zero). Per his
rule, a seat whose miss was measured on few minor-party votes is noisier and must be pulled harder. Variant B:
shift `w_T * n/(n + k_T) * r_{T-1}`, n = the seat's minor-party share at T-1 (percent), with (w_T, k_T) fitted
together on earlier pairs only (least squares, k over a grid 0-60). Same metrics and guards as above; judged on
the same five elections. If B is not better than the refused arm A, Pete's "ship" stands for A.

**Variant B screen (8 Nov ~11am; baseline `163170270058`, arm `c05d232e9606`): not better than A.** (w2, k) per target:
fed2013 2.681/60 (k at the grid edge: unidentified on 138 pairs), fed2016 1.449/35, fed2019 0.787/18, fed2022 0.688/13,
fed2025 0.438/4. Seat log loss change: fed2013 +0.0056, fed2016 +0.0025, fed2019 +0.0054, fed2022 -0.0040, fed2025 -0.0095;
pooled +0.0000 (SE 0.0029) against A's -0.0004; AEF-7 subset -0.0067 (SE 0.0027). Noisy seats were not what hurt the older
elections. Per the amendment, Pete's "ship" stands for A.

**SHIPPED A, 8 Nov 2026, Pete: "ship" (override of the screen refusal).** `AUSPOL_SEAT_FLOW_PERSIST="1"`, shrink variant off.
The inputs (`output/seat-flow-persistence.csv`, `-w.csv`) are frozen in git at the pre-ship model, so the term keeps meaning
"miss against the model without persistence".

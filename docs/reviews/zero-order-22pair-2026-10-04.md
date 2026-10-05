# Zero-order late vs early: 22-pair scoring output (2026-10-04)

Output of `scripts/compare_zero_order.R` (commit 95cf466, committed before this output was read). Early arm = the v61 snapshot `output/snapshots/20261003-0143-48f0233-from6/shipped`; late arm = `zero-order-late` (9197982) with `AUSPOL_NOM_ZERO_ORDER=late`, `AUSPOL_SALIENCE_EXPECTED=0`, `AUSPOL_SALIENCE_EXP_SD=0` (the shipped values), all 22 pairs, hand runs. See `docs/plans/prereg-zero-order-2026-10-03.md`.

```
compare_zero_order | early: output\snapshots\20261003-0143-48f0233-from6\shipped | late: C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\83136c64-8026-4762-b0e4-23e78d601991\scratchpad\late22
files: early summary 9 + sharedetail 9 | late summary 9 + sharedetail 9

Table R7 - seat-elections and cells scored per pair in each arm (counts; the two arms must be equal, any difference is a refusal)
    pair seats_early seats_late cells_early cells_late
 fed2007         149        149        1043       1043
 fed2010         150        150        1050       1050
 fed2013         150        150        1050       1050
 fed2016         150        150        1050       1050
 fed2019         151        151        1057       1057
 fed2022         151        151        1057       1057
 fed2025         150        150        1050       1050
 vic2014          88         88         528        528
 vic2018          88         88         528        528
 vic2022          88         88         616        616
 nsw2019          93         93         651        651
 nsw2023          93         93         651        651
 qld2020          93         93         651        651
 qld2024          93         93         651        651
  sa2022          47         47         329        329
  sa2026          47         47         329        329
  wa2001          57         57         399        399
  wa2005          46         46         322        322
  wa2008          59         59         354        354
  wa2013          59         59         295        295
  wa2017          59         59         413        413
  wa2025          59         59         413        413
pairs scored: early 22, late 22 | seat-elections: early 2120, late 2120 | cells: early 14487, late 14487
R7: PASS (same pairs, seats and cells in both arms)

Table 0 - cells whose predicted primary share differs between arms, per pair (counts; 0 everywhere means the arms are the same forecast)
    pair cells cells_differ seats seats_with_a_differing_cell max_abs_diff_pts
 fed2007  1043            0   149                           0         0.000000
 fed2010  1050            0   150                           0         0.000000
 fed2013  1050            0   150                           0         0.000000
 fed2016  1050            0   150                           0         0.000000
 fed2019  1057            0   151                           0         0.000000
 fed2022  1057            0   151                           0         0.000000
 fed2025  1050            0   150                           0         0.000000
 vic2014   528          268    88                          60         0.017605
 vic2018   528          214    88                          51         0.032130
 vic2022   616            5    88                           1         0.645461
 nsw2019   651          202    93                          47         0.051227
 nsw2023   651          459    93                          91         0.028930
 qld2020   651          276    93                          51         0.029680
 qld2024   651          242    93                          48         0.003311
  sa2022   329          112    47                          28         0.448080
  sa2026   329           32    47                           6         0.002305
  wa2001   399            0    57                           0         0.000000
  wa2005   322            0    46                           0         0.000000
  wa2008   354            0    59                           0         0.000000
  wa2013   295            0    59                           0         0.000000
  wa2017   413          162    59                          30         0.180521
  wa2025   413            0    59                           0         0.000000
total: 1972 of 14487 cells differ (13.6%) in 413 of 2120 seat-elections

Table C0 - ghost cells (class did not stand, actual share 0, but forecast share > 0) outside the by-design absent-class list (counts; the LATE column must be 0 in every pair)
    pair ghost_early ghost_late exempt_cells_late exempt_classes
 fed2007           0          0                 0               
 fed2010           0          0                 0               
 fed2013           0          0                 0               
 fed2016           0          0                 0               
 fed2019           0          0                 0               
 fed2022           0          0                 0               
 fed2025           0          0                 0               
 vic2014           0          0                 0               
 vic2018           0          0                 0               
 vic2022           1          0                 0               
 nsw2019           0          0                 0               
 nsw2023           0          0                 0               
 qld2020           0          0                 0               
 qld2024           0          0                 0               
  sa2022           1          0                 0               
  sa2026           0          0                 0               
  wa2001           0          0                 0               
  wa2005           0          0                27            OTH
  wa2008           0          0                30            ONP
  wa2013           0          0                 0               
  wa2017           0          0                 0               
  wa2025           0          0                 0               
C0: PASS - 0 late-arm ghost cell(s) (early arm: 2; exempt absent-class cells in late: 57) across 22 pair(s)

Table C2a - pooled over all scored seat-elections: seat log loss (winner probability clamped at 1e-6; lower is better), Brier (mean (1-p)^2 on the winner probability; lower is better), seats where the top pick won (higher is better)
          arm n_seats    log_loss         brier top_pick_correct pct_correct
        early    2120 0.326774239 0.08941250014             1868      88.113
         late    2120 0.326784617 0.08941332519             1868      88.113
 late - early      NA 0.000010377 0.00000082505                0       0.000
C2: PASS - unweighted mean over the 22 pairs of the per-pair log loss delta (late minus early) +0.00001 (guard: not worse than +0.0020; negative is better)
     unweighted mean of per-pair log loss: early 0.3413, late 0.3413 (the v61 headline 0.3413 is this kind of mean)
     informational: seat-weighted pooled delta +0.00001 over 2120 seat-elections; sd of the 22 per-pair deltas 0.00006; SE of their mean 0.00001

Table C3 - mean seat log loss per pair and late-minus-early delta (lower is better; delta > +0.011 is flagged)
    pair n_seats ll_early ll_late         delta worse_than_guard
 fed2007     149  0.31535 0.31535  0.0000000000            FALSE
 fed2010     150  0.42828 0.42828  0.0000000000            FALSE
 fed2013     150  0.36569 0.36569  0.0000000000            FALSE
 fed2016     150  0.28452 0.28452  0.0000000000            FALSE
 fed2019     151  0.21789 0.21789  0.0000000000            FALSE
 fed2022     151  0.25731 0.25731  0.0000000000            FALSE
 fed2025     150  0.34334 0.34334  0.0000000000            FALSE
 vic2014      88  0.23819 0.23819  0.0000035790            FALSE
 vic2018      88  0.31268 0.31259 -0.0000827246            FALSE
 vic2022      88  0.24377 0.24377  0.0000000000            FALSE
 nsw2019      93  0.32412 0.32409 -0.0000330705            FALSE
 nsw2023      93  0.22148 0.22151  0.0000291231            FALSE
 qld2020      93  0.28646 0.28667  0.0002096514            FALSE
 qld2024      93  0.27690 0.27689 -0.0000073944            FALSE
  sa2022      47  0.20524 0.20523 -0.0000114813            FALSE
  sa2026      47  0.22160 0.22160  0.0000011270            FALSE
  wa2001      57  0.88162 0.88162  0.0000000000            FALSE
  wa2005      46  0.42936 0.42936  0.0000000000            FALSE
  wa2008      59  0.70714 0.70714  0.0000000000            FALSE
  wa2013      59  0.36360 0.36360  0.0000000000            FALSE
  wa2017      59  0.35075 0.35094  0.0001865902            FALSE
  wa2025      59  0.23305 0.23305  0.0000000000            FALSE
C3: PASS - 0 pair(s) worse than +0.011; largest delta +0.00021 (qld2020), smallest -0.00008 (vic2018)

Table C2b - reliability by confidence band of the top pick: n seats, n_wrong = seats where the top pick lost (counts), said = mean stated probability, got = share that won (said and got should match; reported, not decisive)
   arm         band   n n_wrong said_pct got_pct
 early      [0,0.9] 764     215    72.94   71.86
 early   (0.9,0.95] 214      17    92.80   92.06
 early  (0.95,0.99] 616      17    97.72   97.24
 early (0.99,0.999] 526       3    99.36   99.43
 early    (0.999,1]   0       0       NA      NA
  late      [0,0.9] 763     214    72.91   71.95
  late   (0.9,0.95] 215      18    92.79   91.63
  late  (0.95,0.99] 615      17    97.71   97.24
  late (0.99,0.999] 527       3    99.36   99.43
  late    (0.999,1]   0       0       NA      NA

Table C4 - cells zeroed in the late arm, not in the early arm, whose class DID stand (actual share > 0): must be none
  (none)
C4: PASS - 0 cell(s) zeroed where the class stood, of 3267 late-arm zeroed cells (early arm already had 122 such cells; zeroed cells in early: 3265)

Table R1 - seats where the ACTUAL winner is at the probability floor (p <= 1e-4 in the file) in late but not early: must be none
  (none)
R1: PASS - 0 floor event(s) late-not-early (reverse, early-not-late: 0; seats at the floor in early: 8, in late: 8)

R2 set: 2780 cells in 413 seat-elections where any cell differs between arms
Table R2 - signed primary error (predicted minus actual, points) per class on those cells; refuse = absolute bias grew by more than 2 SE (smaller absolute bias is better)
     class n_cells bias_early bias_late abs_bias_change         se refuse
       ALP     413    -0.7003   -0.7047      0.00446073 0.00194726   TRUE
       GRN     413     0.9968    0.9989      0.00204241 0.00101207   TRUE
       IND     413    -0.3448   -0.3441     -0.00066436 0.00130163  FALSE
       LNP     413     0.9452    0.9466      0.00139649 0.00161462  FALSE
       ONP     302    -0.1616   -0.1615     -0.00009471 0.00002907  FALSE
       OTH     413    -0.3613   -0.3610     -0.00037421 0.00031386  FALSE
 OTH_RIGHT     413    -0.4175   -0.4176      0.00008600 0.00035637  FALSE
R2: FAIL - 2 class(es) flagged (n < 2 classes cannot be assessed and are flagged if bias grew)

R3: seats whose top pick differs between arms: 0 of 2120; excluded because the early leader was a class that did not stand and is zeroed in late: 0; counted: 0
R3: PASS - 0 counted flip(s) (rule: refuse if >= 8 and a two-sided binomial test at p0 = 0.5 rejects at 0.05 for some class)

SUMMARY: R7 PASS (reached here). 1 flag(s): R2: bias grew > 2 SE for ALP,GRN
Not scored here: C1 (direction only per the addendum), R4 (port shape, needs the SP2 log line), R5, R6, and the decision itself (see the prereg decision rule; clause refusals go to Pete).
```

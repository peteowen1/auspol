# vic2026 salience: live forecast with and without (12 Nov 2026)

Branch `salience-vic2026-link` (0646dbc8), worktree `C:\dev\auspol-wt-salience` with its own copy of `output/`.
Two `fit_seats_full.R` runs at the full published configuration, seed 42, 10:11pm and 10:15pm:
`AUSPOL_OUT_SUFFIX=salbase` (no vic2026 rows in `salience-v6.csv`: prints `XG5!`), then
`scripts/link_vic2026_salience.R` (663 vic2026 rows from the 11 Nov snapshot), then `salon` (prints
`XG5 salience corpus found for vic2026: 526 of 616 seat-classes matched`). Output files are named
`output/seat-probs-vic-2026salbase.csv` / `...salon.csv` (no dash before the suffix).

Decision (Pete, 12 Nov 10:40pm): ship now, fix the scale before the final 25-27 Nov snapshot. DECISIONS 2026-11-12.

## Known defect: the anchor link is coarse

A batch representative's value on the anchor scale is its rise beside Ben Carroll in one linking query, and next to
Carroll most candidates register 1-4 on Google's whole-number scale. Linked values therefore come in steps of 0.0607
(1, 2, 3, 4 steps = 0.061, 0.121, 0.182, 0.243). Of 526 linked candidates: 45% exactly zero, 193 distinct values,
largest tied block 236 (the zeros); 17 candidates share 0.182 with raw rises from 2.25 (Brett Hosking) to 32.1
(Ian Cook). Rank mapping keeps the ties, so within-state ordering is mostly lost. Fix candidates: a lower-profile
anchor, or several linking queries per representative averaged. Needs a refetch (~150 requests).

## Output (sal_walk.R, then the tie count)

Win probability is 0-1; shares are primary-vote points. W4 is the sum of win probabilities (expected seats).

```
W0 probs rows 434 / 431, seats 88 / 88; shares rows 88 / 88
W1 seats whose win probability moved >0.02 for any party: 51 of 88; max move 0.461; favourite changed: 12
Key: <seat>
           seat fav_off     p_off fav_on     p_on
         <char>  <char>     <num> <char>    <num>
 1: Albert Park     ALP 0.4883860    GRN 0.458253
 2:     Ashwood     ALP 0.5904705    LNP 0.550200
 3:    Benambra     LNP 0.7496500    ONP 0.436200
 4:   Bentleigh     ALP 0.5450185    LNP 0.513800
 5:      Carrum     ALP 0.3784515    ONP 0.371766
 6:  Cranbourne     ALP 0.6331515    ONP 0.525881
 7:      Eltham     ALP 0.5979035    LNP 0.507250
 8:   Footscray     ALP 0.5325120    GRN 0.573624
 9:   Frankston     LNP 0.4103500    ONP 0.428649
10:      Melton     ONP 0.4801495    LNP 0.504200
11:    Ringwood     ALP 0.4721960    LNP 0.543250
12:     Sunbury     ONP 0.4676325    LNP 0.544400
W2 biggest win-probability moves (probability of winning the seat, 0-1)
          seat  party   off    on   move
        <char> <char> <num> <num>  <num>
 1:   Benambra    LNP 0.750 0.288 -0.461
 2:   Hawthorn    IND 0.007 0.346  0.338
 3:   Hawthorn    LNP 0.979 0.651 -0.328
 4:   Benambra    IND 0.001 0.274  0.273
 5:   Essendon    IND 0.013 0.263  0.250
 6: Cranbourne    ONP 0.323 0.526  0.203
 7: Cranbourne    ALP 0.633 0.441 -0.193
 8:   Benambra    ONP 0.248 0.436  0.188
 9:   Narracan    ONP 0.546 0.723  0.177
10:   Narracan    LNP 0.451 0.276 -0.175
11: Mornington    LNP 0.992 0.820 -0.172
12: Mornington    IND 0.002 0.173  0.170
13:   Kororoit    ONP 0.160 0.328  0.167
14:   Kororoit    ALP 0.624 0.459 -0.165
15:   Sydenham    ONP 0.523 0.686  0.164
16:    Ashwood    LNP 0.388 0.550  0.162
17:   Sydenham    LNP 0.451 0.290 -0.161
18:   Essendon    LNP 0.374 0.216 -0.159
19:    Ashwood    ALP 0.590 0.432 -0.158
20:    Niddrie    LNP 0.552 0.695  0.143
          seat  party   off    on   move
        <char> <char> <num> <num>  <num>
W3 primary shares (points): cells moved >0.5 pts: 315 of 616; max 17.74
                  seat     party   off    on  move
                <char>    <fctr> <num> <num> <num>
 1:           Benambra       IND   9.6  27.4  17.7
 2:           Hawthorn       IND  12.2  26.7  14.5
 3:         Mornington       IND  12.3  26.1  13.8
 4:           Benambra       LNP  37.6  28.0  -9.7
 5:           Essendon       IND   8.4  16.7   8.3
 6:         Mornington       LNP  45.7  37.7  -8.0
 7:          Footscray       IND   6.3  12.2   5.9
 8:           Hawthorn       LNP  44.9  39.2  -5.8
 9:                Kew       IND  20.6  25.9   5.3
10:           Clarinda       IND   6.5  11.0   4.5
11:           Mulgrave       IND  12.3  16.7   4.4
12:           Kororoit OTH_RIGHT   5.5   9.7   4.2
13:       South Barwon       IND   4.6   8.7   4.1
14:           Narracan       ONP  35.6  39.7   4.1
15:      Murray Plains       ONP  35.0  39.0   4.0
16:           Hawthorn       GRN  18.0  14.1  -4.0
17:        Albert Park       IND   5.0   8.9   3.9
18:       Ovens Valley       IND   1.2   4.8   3.6
19:           Essendon       LNP  26.6  23.3  -3.3
20: Narre Warren South       IND   1.3   4.6   3.3
                  seat     party   off    on  move
                <char>    <fctr> <num> <num> <num>
W4 statewide expected seats by party (mean of win probabilities)
Key: <party>
       party   off    on
      <char> <num> <num>
1:       ALP 26.81 24.86
2:       GRN  6.79  7.06
3:       IND  0.10  1.30
4:       LNP 39.49 38.88
5:       ONP 14.68 15.77
6:       OTH  0.00  0.00
7: OTH_RIGHT  0.13  0.13
linked 526; exactly zero 45%; distinct values 193; largest tied block 236
        jump     N
       <num> <int>
1: 0.0000000   236
2: 0.0606586    32
3: 0.1819760    17
4: 0.1213170    14
5: 0.1681110    11
6: 0.2426340     6
               seat             keyword  party jump_raw
             <char>              <char> <char>    <num>
 1:        Mulgrave            Ian Cook    IND   32.125
 2:        Richmond Gabrielle De Vietri    GRN   31.250
 3:           Lowan          Emma Kealy    LNP   25.625
 4:     Albert Park         Adrian King    IND   24.750
 5:        Sydenham          Uros Rasic    ALP   24.500
 6:        Yan Yean          Amanda Dow    LNP   23.625
 7:        Hawthorn         Shima Ibuki    IND   16.875
 8:        Ringwood        Nick Mcgowan    LNP   14.875
 9:       Footscray          Jess Marsh    IND    7.750
10: Gippsland South        Danny Obrien    LNP    6.875
11:         Mildura          Guy Cooper    ONP    6.875
12:        Benambra     Lachie Mckeeman    IND    6.500
13:         Mildura         Jade Benham    LNP    6.125
14:    Ovens Valley      Jennifer Smith    ALP    4.875
15:    Williamstown      Paul Lindemann    LNP    4.750
16:         Morwell      Martin Cameron    LNP    2.375
17:   Murray Plains       Brett Hosking    LNP    2.250
```

# Pre-registration: a by-election is the seat's most recent result

Written 2026-09-18 late, before any run under the switch. Pete's call ("do
all three then one combined rerun"); he had tried to get another session
to scrape by-election results and it refused.

## The data

`external/reference/byelections/byelection-results.csv`: candidate-level
first preferences for 26 by-elections (Wikipedia, CC BY-SA 4.0) covering
every one between the two general elections of the pairs fed2019->2022,
fed2022->2025, nsw2019->2023, qld2020->2024, sa2022->2026, wa2021->2025
and vic2022->2026 (the live forecast). Earlier windows are not fetched
yet; their seats are unchanged.

## The rule

`byelection_prior()`: for each by-election between the pair's two
elections where BOTH majors stood, the seat's prior row in the class-share
matrix becomes the by-election's class shares (classes absent get 0). A
by-election a major skipped is not a general-election baseline (Prahran
2025, Warrandyte 2023, North West Central 2022, Cook 2024, Willoughby
2022 had no Labor candidate) and is skipped, saying so. Applied before
the candidate-identity transfers. `AUSPOL_BYELECTION_PRIOR`.

Usable in the backtest pairs: Black, Bragg, Dunstan (sa2026); Aston,
Dunkley, Fadden (fed2025); Bega, Monaro, Strathfield, Upper Hunter
(nsw2023); Callide, Inala, Ipswich West, Stretton (qld2024); Rockingham
(wa2025); Eden-Monaro, Groom (fed2022) = 17 seats. (An early smoke test
on a one-row matrix reported Bragg and Dunstan as unmatched; in the sa
harness itself both matched and were replaced.)

## Criterion, in order

1. **Primary, targeted**: mean absolute base_pred primary error over every
   class cell of the replaced seats (all six harnesses,
   `AUSPOL_XGB_PRIMARY=0`, 20,000 sims), before vs after, must fall by
   more than one clustered SE (cluster = seat, n about 17).
2. **Do-no-harm**: pooled seat log loss, 23 pairs, not worse by more than
   one SE (cluster = pair). Only the replaced seats can change.
3. **Secondary**: seat log loss on the replaced seats; Black specifically.

Unacceptable-win clause: a by-election baseline is a low-turnout contest
and often a protest vote; if the primary error falls but the replaced
seats' log loss rises (the by-election swing reverting at the general),
the rule is wrong in the direction and a blend, not a replacement, is the
next thing to test, not this one shipped.

## Result A (full replacement), 2026-09-18 23:40: REFUSED

17 seats, 119 class cells: mean abs error 2.78 -> 3.38 (+0.59, SE 0.35).
Pooled log loss 0.2945 -> 0.2951. Per seat: Bega -2.33, Black -0.99,
Monaro -0.91, Callide -0.60 better; Ipswich West +3.44, Upper Hunter
+2.94, Dunstan +1.70, Inala +1.57, Groom +1.39, Aston +1.26 worse. The
by-election protest swing reverted at the general election (Inala ALP
37 at the by-election, 47 at the general; Ipswich West LNP 40 -> 34;
Rockingham ALP 49 -> 47 from a 58 prior), exactly the unacceptable-win
shape named above. Where a seat genuinely changed hands (Black, Bega) the
by-election was the better baseline.

Declared next test, as written above: a half-and-half blend
(`AUSPOL_BYELECTION_PRIOR=blend`, weight 0.5), same criterion.

## Result B (half blend), 2026-09-19 00:20: SHIPPED

Same 17 seats (16 scored; Rockingham's wa row did not match): mean abs
error 2.78 -> 2.44 (-0.34, SE 0.24, 1.4 SE). Pooled seat log loss 0.2945
-> 0.2936, per-pair -0.0007 +/- 0.0012. Per seat: Callide -2.41, Bega
-1.37, Black -1.35, Monaro -0.99, Inala -0.83, Fadden -0.57, Dunkley -0.44
better; Upper Hunter +1.10, Ipswich West +0.91, Dunstan +0.59, Groom
+0.47 worse. 11 of 16 better. The by-election is real information and a
protest; half of it is what the data supports. `AUSPOL_BYELECTION_PRIOR =
"blend"`. Runs were done two harnesses at a time (memory), same sims.

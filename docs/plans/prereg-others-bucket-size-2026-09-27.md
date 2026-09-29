# Pre-registration: shrink the unpolled "others" bucket by its measured poll bias

Written 2026-09-27, before running.

## The defect

Every class the polls do not track (IND, OTH_RIGHT, often ONP) is folded
into one bucket with OTH. Its size is `100 - sum(polled parties)` at the
trend's endpoint, and `forecast_statewide_for()` splits it by the previous
election's ratios (`R/forecast_statewide.R:104-141`). Audit 2026-09-27
(`output/statewide-forecast-audit-base27sep.csv`, published config): the
bucket is too big in 17 of 22 elections, mean |size error| 2.01 points,
typically about +2. Polls overstate "others"; nothing corrects it.

(The split is a separate, larger error, mean 3.39, and is NOT this change:
it goes to Pete as a design question on real rows.)

## The change

A multiplicative correction `k` on the bucket, applied to every draw before
the two-party anchoring, with the share it removes returned to the polled
classes in proportion to their draw (the anchoring then re-balances Labor and
Coalition to the two-party target as now).

`k` for an election is fitted ONLY on elections held strictly before it
(`election_dates()`), from `output/others-bucket-history.csv` (bucket
forecast and actual per pair, written by the audit run with the switch
off). On log ratios `r_j = log(actual_j / forecast_j)`:

    m = mean(r_j), se = sd(r_j) / sqrt(n)
    w = m^2 / (m^2 + se^2)          # 0 when the bias is not distinguishable from noise
    k = exp(w * m)

`n < 2` gives `k = 1`. No hand-set constant. Live Victoria uses every pair
(all precede 28 Nov 2026). Behind `AUSPOL_OTHERS_SCALE` (default 0), in
`statewide_draws_as_at()` and the live path in `fit_seats_full.R`.

## Prediction

`k` around 0.87 once enough history exists. Bucket size error falls in most
of the 17 over-forecast pairs; Labor and Coalition each rise about 1 point
where the bucket shrinks. Live Victoria: OTH/IND/OTH_RIGHT fall, majors rise.

## Criterion, in order

1. **Primary (the target)**: mean |bucket size error| over the 22 pairs
   falls by at least one paired SE.
2. **Do no harm**: mean |miss| over ALP/LNP/GRN does not rise by more than
   one paired SE, and neither major's mean signed miss moves further from 0.
3. Seat smokes (`smoke_pair.sh` fed, wa) and a rebuild decide the ledger
   (seat log loss not above v42's 0.2943) before it ships.

**What would make a win unacceptable**: any `k` computed from an election on
or after the one it is applied to (each run prints the pairs and n it used);
the primary passing only because of one pair (reported with the largest
single mover removed).

## RESULT (added 2026-09-28 after running; everything above is unedited)

History `output/others-bucket-history.csv` from the switch-off audit
(`-base27sepB`); arm audit `-ob1`. Leakage condition held: every pair's `k`
used only earlier elections (printed as `OB2`, latest pair always before the
target; wa2001 n=0 and wa2005 n=1 got k=1 as specified).

1. **Primary: FAILS.** Mean |bucket size error| over 22 pairs 2.010 ->
   1.783, change -0.228, paired SE 0.238 (t -0.96); the bar was -1 SE.
   The unacceptable-win check (largest mover removed) was meant to stop a
   win carried by one pair, and is NOT used to rescue a failure: without
   fed2007 the change is -0.373, SE 0.197.
2. Do no harm: PASS. Mean |miss| ALP/LNP/GRN 1.758 -> 1.740 (SE 0.042);
   ALP signed -0.76 -> -0.55, LNP -0.68 -> -0.42.

What sank it: fed2007, k = 1.323 fitted on two WA elections (wa2001,
wa2005, both under-forecast), size error 2.02 -> 4.85. With n = 2 the
weight `w = m^2 / (m^2 + se^2)` came out 0.97 because two same-sign points
give a small `se` that is itself barely estimated. From ~12 earlier
elections on, the correction helps in every pair whose bucket was
over-forecast: nsw2023 -1.86, vic2022 -1.68, sa2022 -1.49, nsw2019 -1.22,
sa2026 -1.12, fed2019 -1.02. It hurts the three recent pairs whose bucket
was already right (fed2022 +1.31, fed2025 +1.03, wa2025 +1.39).

Verdict: stays OFF. Live `fit_seats_full.R` was NOT wired (the arm did not
pass); the switch exists in the backtest path only, registered off in
`published_flags.R`. A v2 would need a small-n weight that does not trust an
`se` from two points; that is motivated by this result and has to be
pre-registered as such, not slipped in as a fix.

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

# Pre-registration: drop `fed_aligned` from the two-party fundamentals

Written 2026-09-20 16:25, before running. From the nsw2023 walk in
`reviews/statewide-forecast-audit-2026-09-20.md`: the trend had Labor's
two-party at 54.2 (actual 54.3); the fundamentals said 46.5, of which
`fed_aligned` (state Labor punished 3.2 points because federal Labor
governed) was the largest negative term; the 0.28 weight on it moved the
anchor to 52.0 and the anchoring took 4.4 points off Labor's primary.
Pete chose this arm over the anchoring asymmetry (16:20).

## The arm

`fit_fundamentals(dat, "@TPP", features = setdiff(FUNDAMENTALS_FEATURES,
"fed_aligned"))`; leave-one-out predictions replace `fund_tpp` in the
saved `output/projection-data.csv`; `fit_projection_mix()` refits the
weights. The trend is untouched, so nothing else moves.

## Criterion, in order

1. **Primary: held-out mix MAE at horizon 1 (42 elections) falls.** Both
   mixes are refitted leave-one-out, so the number is honest on both sides.
   Tolerance: the paired difference in absolute error must be at least
   one SE of that difference in favour (n = 42).
2. **Do no harm: fundamentals LOO MAE on the 61 elections does not rise by
   more than one SE** of the paired difference. A term can be a bad
   day-before input and a good two-year prior; if it is, the answer is a
   horizon-dependent feature set, not a drop.
3. Reported, not decisive: nsw2023 and wa2017 held-out errors at horizon 1;
   the horizon-730 mix MAE (where fundamentals carry most weight).

**What would make an apparent win unacceptable**: the primary passing only
because nsw2023 itself moved (it is one of 42 rows); the paired SE is the
guard, and the result names nsw2023's own contribution.

Decision rule: 1 and 2 pass -> ship (feature list constant changes,
projection mix regenerated, rebuild v43 decides the ledger). 1 fails ->
refuse, and the anchoring asymmetry arm is next. 1 passes and 2 fails ->
propose the horizon-dependent feature set to Pete, do not ship.

# RESULT (16:35): REFUSED on both criteria

Held-out MAE, lower is better; paired differences are (without - with),
so negative favours the arm.

| | with `fed_aligned` | without | paired diff | SE |
|---|--:|--:|--:|--:|
| fundamentals LOO, 61 elections | 3.042 | 3.586 | +0.543 | 0.253 |
| mix at 1 day, 42 elections | 1.660 | 1.645 | -0.015 | 0.089 |
| mix at 30 days | 1.848 | 1.989 | +0.141 | 0.123 |
| mix at 730 days | 2.249 | 2.706 | +0.458 | 0.223 |

The day-before gain is nsw2023 alone (its error 3.12 -> 1.74); without
that row the arm is worse by 0.018. The federal-drag term is a real
predictor over the corpus (it costs half a point of fundamentals MAE and
a fifth of the mix's two-year MAE to remove it), and nsw2023 is the
election it gets wrong. Feature list unchanged. Per the decision rule,
the anchoring asymmetry arm is next.

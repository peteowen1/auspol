# Pre-registration: a departed defector's vote goes home

Written 2026-09-18 before any harness run under the new switch. Pete's go:
"go" on the Morwell rule from the worst-seat pass on ledger v32.

## The claim

When the leading candidate of a non-major class does not re-contest, and
that person earlier stood for a major party in the same seat, part of their
personal vote returns to that party. The current model releases their
vote pro-rata across every class (the `AUSPOL_HONOUR_DEPARTED` decay to a
0.38 retention rate, then row renormalisation). Morwell vic2022 is the
flagship: Russell Northe (National 2014, independent 2018 at 19.6, retired
2022) -- the Nationals went from our 27.2 to 38.4 and that 11 points is the
seat's whole log loss (2.70, the worst in the corpus).

## The rule

`route_departed_origin(mat, ea, eb, frac)` moves `frac * lead_pcv` points
from the departed leader's class to their origin party in the PRIOR matrix,
before the slopes and swing are applied. The departed class then decays as
it does today on what is left. `frac` is fitted by
`fit_departed_origin_return(target)`: leave-target-out over every other
pair, the MEDIAN of (origin party's actual vote minus its swing-only
expectation) / (departed leader's prior vote), clipped to [0, 1]. Median,
not mean, because two of the 14 offline cases are landslide artefacts of
the proportional swing (Vasse wa2017 reads 2.62).

Cases found offline (swing-adjusted, `scratchpad/depdef_cases.csv`):
n = 15, median 0.22, mean 0.57, 12 of 15 positive. Morwell itself reads
0.81. (First draft said Kavel was a name-key miss because "Cregan re-stood";
checked against the corpus before the first run: he did not, a new
independent won Kavel 2026 on 21.4, so Kavel stays in. Correction left
visible per the amendment rule.)

## Switch

`AUSPOL_DEPARTED_ORIGIN` (default "0"). Arms:
- A: `"1"`, frac = leave-target-out median (about 0.22).
- B: `"mean"`, frac = leave-target-out mean of the clipped ratios (about
  0.42). Declared now so it is not chosen after seeing A.

## Criterion, in order

1. **Primary, targeted**: mean absolute primary error on the origin-party
   cell of the ~14 target (pair, seat) cases, base_pred only
   (`AUSPOL_XGB_PRIMARY=0`), before vs after, all six harnesses. Must fall
   by more than one clustered SE (cluster = case).
2. **Do-no-harm**: pooled seat log loss over all 23 pairs at
   `AUSPOL_XGB_PRIMARY=0` must not rise by more than one SE (cluster =
   pair). Seats outside the targets should be byte-identical in the prior
   except through renormalisation, so this mostly checks nothing leaked.
3. **Secondary**: seat log loss on the target seats, and the departed
   class's own primary error (the rule takes vote from it; if that cell
   gets worse the decay rate and the route are double counting).

What would make an apparent win unacceptable: the gain coming from one
seat (Morwell) with the other 13 flat or worse -- report the per-case
table, not just the mean. If A and B split (one passes, one fails), ship
the one that passes only if the other is not worse than baseline.

If the criterion passes, the full `scripts/rebuild_forecasts.sh` decides
(the as-at xgb layer re-learns on the new base_pred); the ledger numbers
from that are what get reported, not the base_pred-only ones.

## Result, 2026-09-18 18:00 (base_pred only, 20,000 sims, all six harnesses, 15 cases)

Origin-party primary error (points, lower is better), clustered SE by case:

| arm | share | MAE before | MAE after | delta | SE | criterion (> 1 SE) |
|---|---|---|---|---|---|---|
| A median | 0.21 | 6.75 | 5.64 | -1.11 | 1.18 | **not met** (0.94 SE) |
| B mean | 0.36-0.43 | 6.75 | 5.99 | -0.76 | 1.27 | not met (0.60 SE) |

Do-no-harm passed for both: pooled seat log loss over 2,112 seat-elections
0.2979 -> 0.2976 (A) / 0.2976 (B), per-pair delta -0.0011 +/- 0.0012.

Per case the effect is real where the departed leader's vote was large
and the origin party had fallen (Morwell log loss 1.86 -> 1.03 under A,
Waite 3.25 -> 1.91, Corio, Whitsunday, Tangney, Ryan all better) and harmful
where the origin party was already over-predicted (Hughes 1.57 -> 2.02,
Lyons, Frankston, Hillarys, Nedlands, Vasse 2008 worse). 8 of 15 improve.
Not one seat carrying the mean, but not a clean win either.

**Verdict: criterion not met; `AUSPOL_DEPARTED_ORIGIN` stays "0".** The
mechanism is built, tested and wired into all seven scripts, so a later
corpus (each election adds a case or two) can re-decide it with one run.
The honest reading is that 15 cases cannot separate "some of the vote goes
home" from noise at the pooled-constant level, and the harmful cases share
a shape (origin party already high) that a rule with more data might
condition on. Not shipped; not refused as false either.

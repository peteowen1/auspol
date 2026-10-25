# Pre-registration: fill One Nation's seat gap by the statewide draw betas (`AUSPOL_ONP_FILL = "uniform_major"`)

Written 2026-10-25, before any run of the arm. Exploratory: **this arm cannot be backtested** (see "Where it can be
measured"), so it can be decided only on the live walk and on Pete's judgement.

## Why

`docs/reviews/market-disagreement-vic2026-2026-10-25.md` (main checkout, uncommitted when this was written). After
the base swing, the live forecast sets each seat's One Nation share from its ranking and then multiplies every other
cell in the seat by `(100 - One Nation) / (sum of the others)` (`scripts/fit_seats_full.R`, the fill under
`ONP_FIX == "1"`, verified at commit 37ccddf). Where One Nation is weak this hands each party back part of the gap in
proportion to its size there. In Box Hill One Nation gets 9.6 against 21.8 statewide; the factor is about 1.16, and
Labor, Liberal and Greens are all scaled up 16%. So low-One-Nation eastern seats swing 1 to 5 points two-party
against Labor while the state swings 6.9, and the bookmakers price close to a uniform swing (Box Hill Labor 0.24
market against 0.915 ours).

The statewide draws say One Nation's vote does not come proportionally from everyone: per point of One Nation, the
Coalition gives up 0.525, others 0.270, Labor 0.173, the Greens 0.033 (`output/statewide-draw-betas-vic-2026.csv`,
main checkout, as of this writing; FP2 line).

## The arm

`AUSPOL_ONP_FILL=uniform_major` (default `"prop"`, the shipped fill, untouched). `R/onp_order.R::onp_fill_betas()`:
in each seat the gap `gap = (100 - One Nation - held cells) - (sum of the free cells)` goes to class `c` in share
`w_c = max(0, -beta_c)` from the One Nation row of the betas, renormalised over the classes present (share > 0) and
not held in that seat. Classes the betas do not name (OTH, OTH_RIGHT, IND) share the OTH weight in proportion to their
size. A cell pushed below zero is floored at zero and the seat's free cells rescaled to the exact total. Departed-hold
cells keep their value, as in the shipped fill. Prints `ONF0` (mode), `ONF1` (the betas file and its modified time,
then the weights used and how many cells were floored).

The betas are the last DEFAULT run's (`output/statewide-draw-betas-<stem>.csv`, the file `AUSPOL_FORCE_FP_RULE=draws`
already reads); this run's own are computed after the seat stage. Refuses to run without the file, and refuses
`AUSPOL_ONP_FIX=0` (no fill exists there).

Illustration, arithmetic only (not a model run): Box Hill's pre-fill base reconstructed from the review (Labor 28.5,
Liberal 29.6, Greens 16.9, others 2.9; One Nation 9.6). Shipped fill: Labor 33.1, Liberal 34.3, Greens 19.6, others
3.4. This arm: Labor 30.7, Liberal 36.1, Greens 17.3, others 6.3. So Labor gives up 2.4 and Liberal gains 1.8: toward
the market, but much less than a uniform 6.9 two-party swing.

## Two things this arm gets wrong by construction (say them with any result)

1. **The weight source decides the direction.** The draw betas describe how the statewide vote co-varies across
   simulations, not where One Nation's 21.5-point rise came from. Weighting instead by each class's statewide LOSS
   since 2022 (Labor -12.4, Coalition -5.5, others -6.5, Greens +2.8) would give Labor about half the gap, so Box Hill
   Labor would RISE above the shipped 33.1. Not built; if Pete wants that reading measured, it is a third value of
   this switch.
2. **Others can more than double in a weak-One-Nation seat** (Box Hill 2.9 -> 6.3), because the OTH weight (0.27) is
   statewide and the seat's OTH cell is small. In a strong-One-Nation seat the Coalition takes 52.5% of the cut even
   where it is small (Lara, Liberal 14.6), so floors may fire. Count of floored cells is printed (`ONF1`).

## Where it can be measured

**Nowhere in the backtests.** Verified 2026-10-25 by reading the six harnesses: none has the live One Nation fill
(the Mildura trace, `docs/reviews/mildura-benambra-trace-2026-10-25.md` stage 07, says the same). The closest step is
the SA harness's BS1c concentration arm, which sets One Nation's spread and lets the row renormalisation absorb it,
which is also a proportional fill. A harness version was not built because the weights do not exist there: the
statewide draw betas are written only by `fit_seats_full.R`, and a backtest version would need a different weight
source, so it would test a different rule from the one that would ship. That is the honest reason, not a compute one.

What can be looked at instead (all reported, none decisive):

1. **Tercile miss table** (seconds, from the existing harness sharedetail): Labor and Liberal primary error in the
   lowest-One-Nation third against the highest, sa2026, qld2017, qld2020, qld2024. The review found no consistent
   pattern (SA 2026 low third under-called the Liberals 1.5 points more than Labor; Qld 2024 the opposite sign). A
   consistent "Labor over-called where One Nation is weak" pattern across all four would support the arm; the
   review's reading is that it is not there.
2. **vic2022 eastern seats.** The backtest under-called Labor in Box Hill (+5.1 Labor primary, actual minus ours),
   Ashwood +5.3, Glen Waverley +2.3, Bayswater +4.0. This arm pushes those seats further from Labor, so on vic2022's
   evidence it moves the wrong way there (One Nation was negligible in 2022, so the fill itself did not act then; this
   is evidence about the seats, not about the arm).

## Live walk (the only measurement)

```
$env:AUSPOL_ONP_FILL="uniform_major"; $env:AUSPOL_OUT_SUFFIX="-onf"; Rscript scripts/fit_seats_full.R
```

and the same with `AUSPOL_ONP_ORDER=senate_rank` added (`-onr-onf`), each against the published run. For Box Hill,
Ashwood, Glen Waverley, Niddrie, Essendon, Lara, Geelong and Bendigo West: Labor, Liberal/National, Greens, One Nation
and others primary (after the fill and published), each class's win probability, and the local two-party swing
against the statewide 6.9. Also statewide expected seats by party, and the number of floored cells.

Expected before running (arithmetic above): Box Hill, Ashwood and Glen Waverley Labor primary down about 2 to 3
points and Liberal up about 2; Lara and Niddrie (One Nation above the state level) the reverse sign on the Liberal
cell, since the Coalition then gives up most of the excess. If the eastern seats move the other way the arm is wired
wrong: stop and trace it.

## Decision rule (stated now, so it cannot be fitted to the result)

No backtest metric exists to pass. This arm ships only if Pete chooses it after seeing the live walk beside the two
caveats above and the tercile table. My recommendation in advance: do not ship it on the walk alone; treat it as a
sensitivity bound to report next to the published number (how many eastern seats change hands between the two
fills), unless a backtestable version (a harness weight source of its own, pre-registered separately) passes.

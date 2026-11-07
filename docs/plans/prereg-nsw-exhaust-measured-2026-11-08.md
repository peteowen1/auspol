# Pre-registration: NSW exhaust rates measured from NSWEC's own counts (2026-11-08, overnight)

Written and committed BEFORE any arm run. Decision is Pete's (written overnight under his
"keep working" instruction; nothing here ships without him).

**What the change does, in plain words.** NSW voters can stop numbering boxes, so some of an excluded
candidate's votes reach nobody. The shipped model (`AUSPOL_NSW_EXHAUST="1"`, time-forward since 8 Nov)
takes those rates from the anchor's hand-made `preference-estimates.csv`, which has no NSW exhaust rates
before 2019 (so nsw2019 gets no exhaustion at all) and gives Labor and the Coalition 0. This arm takes
them instead from `output/nsw-exhaust-measured.csv` (`scripts/build_nsw_exhaust_measured.R`): the share
of votes exhausted at each exclusion, pooled by excluded class, from NSWEC's distribution-of-preferences
pages, using only the latest NSW election BEFORE the target (nsw2019 <- 2015, nsw2023 <- 2019).

**Arm:** `AUSPOL_NSW_EXHAUST_SRC=measured` against the published configuration (anchor rates,
time-forward). Pairs nsw2019 and nsw2023 (nsw2011/2015 have no earlier measured year: unchanged, which is
guard 3). A class missing from the source year (One Nation did not stand in 2015) takes the source year's
OTH_RIGHT rate, the nearest class that did.

## Metrics (`scripts/score_tcp_arm.R`, `quick_arm.R`)

1. **Primary:** pooled seat log loss over nsw2019 + nsw2023, lower is better. Pass: arm lower than
   baseline by at least 1 SE (clustered on election as `quick_arm.R` prints it; with 2 elections that SE is
   crude, so also report the per-election changes).
2. **Second:** TCP mean absolute error on seats where baseline's and arm's final two both match the real
   one, per pair; and the ours+AEF-matched nsw2023 set from the 7 Nov prereg.

## Guards (refuse even if the primary passes)

1. Either election's seat log loss worse by more than 1 seat-clustered SE... reported as the per-election
   change; refuse if either election is worse at all at 20k.
2. nsw2023 TCP MAE on the ours+AEF set worse than the shipped 4.573 (20k) / 4.581 (1k).
3. Any other pair (incl. nsw2011, nsw2015) not byte-identical.
4. Predicted primary shares unchanged (exhaustion acts after primaries; any moved cell is a bug).

## Predicted result, written before running

nsw2019 improves (it goes from no exhaustion to measured 2015 rates; the leaky 7 Nov run, with similar
rates, gave 0.2711 -> 0.2647). nsw2023 roughly unchanged (2019 measured rates are close to the anchor's
2019 rates for GRN/ONP/OTH; the new part is majors' exhaust, which only moves the few seats where a major is
excluded).

## Procedure

Screen at 1,000 sims with `quick_arm.R`; if it passes, a deciding run (`deciding_run.ps1`, the two NSW
pairs, 20k). Results go below; the ship question goes to Pete.

## RESULT

(not yet run)

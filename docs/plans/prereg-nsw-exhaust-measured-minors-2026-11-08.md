# Pre-registration: measured NSW exhaust, minor parties only (2026-11-08, ~12:45am)

**Post-hoc, and said so.** This variant was found AFTER the refused screen of
`plans/prereg-nsw-exhaust-measured-2026-11-08.md`: there, measured rates for every class helped nsw2019 and
hurt nsw2023, and keeping the majors at 0 (as the anchor does) was tried once at 1k as a diagnostic. It
helped both (nsw2019 0.2711 -> 0.2643, nsw2023 0.1844 -> 0.1834). Because the variant was chosen after
seeing a result, the 20k deciding run below is the test, with these criteria fixed before it runs, and the
ship decision is Pete's.

**What the change does.** NSW exhaust rates for minor-party exclusions (Greens, One Nation, minor right,
other, independents) come from NSWEC's own distribution-of-preferences pages
(`output/nsw-exhaust-measured.csv`), latest NSW election before the target (nsw2019 <- 2015, nsw2023 <-
2019), instead of the anchor's hand-made file (no NSW exhaust before 2019). Labor and Coalition exhaust
stay 0. Arm: `AUSPOL_NSW_EXHAUST_SRC=measured AUSPOL_NSW_EXHAUST_MEAS_MAJORS=0`.

## Criteria (deciding run, 20k, nsw2019 + nsw2023)

1. **Primary:** pooled seat log loss lower than the shipped configuration's (anchor rates, time-forward).
2. **Guards:** neither election's seat log loss worse; nsw2023 TCP MAE on the ours+AEF-matched set not
   worse by more than 1 seat SE; 0 primary cells moved; any other pair untouched (only the NSW harness
   reads the switch; nsw2011/2015 have no earlier measured year).

## Screen (1k, before writing this): `62a35443fca6` -> `87df63e351ed`

Seat log loss pooled 0.2277 -> 0.2238 (-0.0039, SE 0.0029). TCP MAE matched seats: nsw2019 4.166 -> 3.582
(-0.584, SE 0.141; slope 1.111 -> 1.014); nsw2023 4.521 -> 4.533 (+0.012, SE 0.014), ours+AEF set 4.618 ->
4.630 (+0.012, SE 0.014).

## RESULT

(deciding run not yet run)

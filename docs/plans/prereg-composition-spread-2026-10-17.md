# Pre-registration: a seat's spread follows what its vote is made of (2026-10-17)

Committed BEFORE any arm below is run. Pete, 17 Oct, after the Lib/Nat split made three
Victorian independent seats worse: "is this more a systemic issue? should we fix this in a
generalised way not just for VIC?" and "rather than a hacky fix for one thing try and see what
the root bias or error or issue is and fix it for everything". He chose the general fix over a
Victoria-only arm.

## The finding (shipped model, all 35 elections, `output/published-predictions.csv` and the
## `20261017-0940-61b38df-from6` sharedetail; scratchpad `ind.R`, `diag_ind.R`, `fitcomp.R`)

- Seats where we predicted an independent at 15+: **217 seats in 33 elections, seat log loss
  0.763** against 0.301 for the other 2,714. 7% of seats, 17% of total log loss. Not a lean:
  Coalition expected 76.3 wins, won 80; independents expected 97.5, won 91. It is over-confidence
  in single seats (Kimberley wa2001 winner 0.0000, Ryan fed2010 0.0001, Morwell vic2022 0.072).
- Ratio of RMS share error to the simulator's per-cell sd (`1.10 + 8.67 sqrt(p(1-p))`; 1.00
  right, above 1 over-confident) rises with predicted IND share **within every seat-size band**
  (40k+ formal votes: 0.85 none, 0.97 IND 0-5, 1.26 IND 5-15, 1.34 IND 15-30), and on the
  Labor and Coalition cells too (0.94 none -> 1.41 IND 15-30), so the whole seat is uncertain,
  not just the independent's share.
- **It is personal-vote contests, not "a strong minor".** Seats whose largest non-major is the
  Greens sit at 0.91-1.05 at every Greens level; independent-led seats at 1.39-1.75.
- Dry-run fit (all 35, Gamma GLM of squared error with offset log sdm^2, size control, per 10
  points of each class's predicted share, SE clustered on election, w = max(0, 1 - se^2/b^2)):
  IND sd x1.125 (w 0.95), OTH_RIGHT x1.00 (w 0), OTH x1.00 (w 0), ONP x0.955 (w 0.49),
  GRN x0.892 (w 0.83). The data, not a list, picks the classes.

Root cause stated: the per-cell spread formula assumes every class's share behaves like a party
vote. A candidate's personal vote does not, and when one is in the race every class in the seat
moves with it.

## Arm

| Arm | Switch | Rule |
|---|---|---|
| A (shipped) | `AUSPOL_COMPOSITION_SD=0` | as published (split on, `AUSPOL_SIZE_SD=1`). |
| C | `AUSPOL_COMPOSITION_SD=1` | below. |

**C.** For each target, fitted TIME-FORWARD on earlier elections' published cells only
(`scripts/fit_spread_by_composition.R` -> `output/spread-by-composition.csv`, built in the
rebuild like `spread-by-size.csv`): the GLM above, one coefficient per non-major class
(GRN, IND, ONP, OTH, OTH_RIGHT; majors are the reference) plus the log-size control, each shrunk
by its own w. A seat's factor is

    factor = max(1, exp( sum_c w_c b_c s_c / 2 ))      s_c = predicted share of class c / 10

from the shares the simulator is handed (known before polling day). Fewer than 3 earlier
elections or 500 cells: factor 1. It **only widens** (the Greens' narrowing is a later,
separate question) and multiplies every class's sd in the seat, ON TOP of the size factor (the
fit controls for size, so the two do not double-count). Six harnesses, NT and live, through the
same sd-override path as `AUSPOL_SIZE_SD`, printing per target the coefficients, weights and the
number of seats widened (code `CMP1`).

## Criterion

1. **Primary:** seat log loss on the seats C widens by a factor of 1.10 or more in that election
   (set by C's own pre-election factor, never by results), all 35 elections, SE clustered on
   election. **C ships if lower by more than 1 SE.**
2. **Guard, all 2,931 seats:** C not worse than A by more than 1 SE.
3. **Reported:** the fixed set (IND predicted 15+, 217 seats), per jurisdiction, AEF-7, the
   Victorian split seats (Morwell, Shepparton, Mildura 2022), reliability by band (stated
   probability vs share won), share RMSE (unchanged by construction: centres do not move).

Expected size: an sd factor of 1.2-1.5 on the 217 seats. Their excess log loss is 0.46 a seat,
so a primary gain of a few hundredths to a tenth is plausible; the split's SE on 191 seats was
0.027, so the MDE is about the size of the effect, which is why the primary is the targeted set.

Screen: `quick_arm.R "AUSPOL_COMPOSITION_SD=1" --pairs=all --sims=1000`. Widening acts in the
tails, which a 1,000-sim screen floors at 5e-4, so **the deciding run is 20,000 sims**
(`deciding_run.ps1`) whatever the screen says, and shipping is Pete's call on its result.

## What would make an apparent win unacceptable (decided now)

- **One election:** more than half the primary gain from a single election -> refused.
- **The floor:** if more than half the primary gain comes from seats A put at the 1e-6 floor
  (one sim or none in 20,000; the Barwon nsw2019 precedent), it goes to Pete as a split result,
  gain with and without those seats, before anything ships.
- **Favourites:** if C makes the seats A called at 0.90+ that the favourite WON worse by more
  than 1 SE (summed), report it beside the primary; widening that only buys upsets by taxing
  safe calls is the failure to watch.
- **Live:** C must not move any vic2026 party's seat median (spread, not centre). Any seat whose
  favourite's probability moves more than 10 points is listed for Pete before shipping.

## What this cannot see

- Personal vote outside the IND class: a sitting member's own vote within a major (or an
  OTH_RIGHT MP) is not in the shares, so it gets no widening. If C ships, the next question is a
  candidate-level term (sitting / defecting / returning), which needs the candidacy flags.
- The large primary misses behind the worst seats (Ryan fed2010 defector carry, Kimberley
  wa2001) are centre errors. C can only stop them reaching the floor, not fix them.
- Whether the Greens' narrowing helps: separate, after this.

## Amendment 1 (2026-10-17, after the screen; Pete: "Amend: add an independent-only arm")

The original clauses above stand unedited. Screen result (`reviews/composition-spread-2026-10-17.md`): C
passes the primary (-0.030, SE 0.016) and the guard, but NSW's primary seats get worse (+0.041, SE 0.016) and
the favourites clause reports a cost (+0.0023, SE 0.0005). The diagnosis there: the independent's OWN share is
about twice too narrow and bell-shaped (robust sd 2.15), while the majors in the same seats are right in a
typical seat (0.96) and heavy-tailed. C widens every class in the seat, so it taxes the majors' clear calls.
This amendment favours a different arm, not a looser bar, and C stays in.

**Arm C2** (`AUSPOL_COMPOSITION_SD=own`): each NON-MAJOR class's own cell is widened as a function of its own
predicted share; the majors and every other cell are untouched (the draw renormalises, so a wider IND moves
the majors only when it moves). Fitted per target and class, time-forward, on that class's cells only: Gamma
GLM of the squared error, offset log sdm^2, with the centred log-size control and the class's own share per
10 points; intercept a_c and slope b_c each shrunk by its own w = max(0, 1 - se^2/b^2), SE clustered on
election. Cell factor `max(1, exp((w_a a_c + w_b b_c s_c / 10) / 2))`, multiplying the size factor. Same
table rules as C (3 earlier elections, 500 cells), written to `output/spread-by-class-own.csv`.

**Choice between C and C2, decided now:** both scored on C's 213 primary seats (the same set; C's factor
defines it, so neither arm picks its own seats). C2 goes to the 20k deciding run in C's place if, on the
1,000-sim screen, (i) its guard (all 2,931 seats) is no worse than C's and (ii) its primary gain is within
1 SE of C's or larger. Otherwise C goes. The deciding run's criterion and every refusal clause are the
original ones, applied to whichever arm goes. NSW and the favourites line are reported for both.

**Amendment 1a (2026-10-17, from the C2 table, before C2 runs):** the uncapped fit extrapolates: OTH's slope,
fitted on small shares, gives x9 to x94 at 30 points. So the class's share is capped at its 99th-percentile
predicted share in that target's training cells (`s_max`, stored in the table) before the slope is applied:
no factor is read beyond the data that fitted it. IND, the class the amendment is for, is unaffected
(x1.8-2.3 at 10-30 points before and after).

**Amendment 1b (2026-10-17, C2's first screen stopped before any result):** the screen showed CMP4 widening
the IND cell in all 150 fed2010 seats, because the intercept applied to cells at 0% (no independent standing)
and the simulator draws noise for every class, so the widening put phantom independent votes in seats with no
independent. The fit trains only on predicted shares of 2+, so by 1a's own rule (no factor read beyond the data
that fitted it) a cell under 2 gets no widening. That screen (`20261017-1403-composition-own-screen-1k`) was
stopped by hand, marked FAILED, and nothing from it was scored.
Arm C carries the same defect (it widens every cell in the seat, standing or not) and is NOT changed after
its screen; if the choice rule sends C to the deciding run, that goes to Pete first. Separately, the SHIPPED
model already draws noise (sd 1.10) for classes at 0% in every seat: a pre-existing phantom-vote issue, queued.

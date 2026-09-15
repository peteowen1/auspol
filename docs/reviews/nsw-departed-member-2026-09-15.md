# In NSW, a safe seat whose member leaves is a coin flip we call safe

Written 2026-09-15 overnight, working through the seats where we lose most log
loss to AE Forecasts. **This is a measurement, not a shipped change.** Nothing
in the model moved.

## The headline

Pooling both NSW pairs, 181 seat-elections, split by whether the member who won
the previous general election was on the ballot again. Mean seat log loss,
lower is better:

| seat's margin going in | member stood again | member GONE |
|---|--:|--:|
| under 5 points | 0.320 (n=21) | 0.786 (n=5) |
| 5 to 12 | 0.117 (n=38) | **0.943 (n=11)** |
| 12 or more | 0.059 (n=75) | **0.924 (n=31)** |

**In seats we should be most sure about, we are wrong a quarter of the time.**
Across every NSW seat held by 5 points or more: 2 wrong of 113 when the member
stands again (1.8%), **11 wrong of 42 when they are gone (26.2%)**.

Margin does not explain it. The effect is *largest* in the safest seats — a
12-point-plus NSW seat costs us **15 times** more log loss when the member has
left. That is the opposite of what a marginality confound produces.

## The eleven

Every safe NSW seat whose previous winner was absent and which we then called
wrong. `p(win)` is the probability we gave the party that actually won:

| pair | seat | margin | p(win) | we said | won | member who left |
|---|---|--:|--:|---|---|---|
| nsw2019 | Barwon | 12.9 | **0.000** | LNP | OTH_RIGHT | Kevin Humphries |
| nsw2019 | Orange | 21.7 | **0.000** | LNP | OTH_RIGHT | Andrew Gee |
| nsw2019 | Murray | 25.2 | 0.024 | LNP | OTH_RIGHT | Adrian Piccoli |
| nsw2019 | Wagga Wagga | 12.9 | 0.049 | LNP | IND | Daryl Maguire |
| nsw2023 | Monaro | 11.6 | 0.064 | LNP | ALP | John Barilaro |
| nsw2023 | Wakehurst | 21.9 | 0.111 | LNP | IND | Brad Hazzard |
| nsw2023 | Parramatta | 6.5 | 0.148 | LNP | ALP | Geoff Lee |
| nsw2023 | Riverstone | 6.2 | 0.235 | LNP | ALP | Kevin Conolly |
| nsw2023 | South Coast | 10.6 | 0.235 | LNP | ALP | Shelley Hancock |
| nsw2023 | Bega | 6.9 | 0.349 | LNP | ALP | Andrew Constance |
| nsw2023 | Holsworthy | 6.0 | 0.483 | ALP | LNP | Melanie Gibbons |

Two seats at `0.000` are seats given the log-loss floor. **All eleven were
Coalition-held**, and in ten of them we favoured the Coalition to hold on.

## What the column actually means, which is not quite "retirement"

`retire_derived` is **"the winner of the previous general election is not on
this ballot"**. That covers a retirement, a death, a resignation, and a member
who already lost the seat at a by-election. Orange had gone to the Shooters at a
2016 by-election and Wagga Wagga to an independent in 2018, so neither was a
retirement at all.

**The broader definition is the right one here**, because it is defined against
what the model actually consumes: `fit_xgb_primary_v6.R` projects forward from
the previous general election's result, so the question that matters is whether
the person whose vote is being projected is standing. It is also knowable before
polling day in every case.

It is NOT the same quantity as `load_seats()$retirement`, and the difference is
the by-election contamination `CLAUDE.md` already records under
"`load_seats(Y)$incumbent` is who holds the seat NOW".

## How this was found, including the step that nearly went wrong

The route was: rank seats by log loss lost to AEF, notice that five of the
nsw2023 losses were seats whose member had quit, then test it.

**The first test was selection bias and was discarded.** Conditioning on "the
party that won" and reporting a mean error is guaranteed to show
under-prediction of winners even from an unbiased model — the same trap that
produced the retracted Greens finding earlier the same day. The unconditioned
per-class version showed nsw2023's ALP bias is **+1.91 points**, which is around
1.75 election-level standard deviations and unremarkable, exactly as Pete said
when he pushed back on the 2-point poll miss.

**The hypothesis was then formed on nsw2023 and confirmed on nsw2019**, which
played no part in forming it:

| pair | wrong, member stood | wrong, member gone | z |
|---|--:|--:|--:|
| nsw2023 (where found) | 3 of 64 (4.7%) | 8 of 24 (33.3%) | +3.62 |
| **nsw2019 (out of sample)** | **1 of 70 (1.4%)** | **6 of 23 (26.1%)** | **+3.89** |

## MECHANISM FOUND: it is variance, not level

Added after the first draft said the mechanism was untested. It is now tested.

Signed error on the **held party's own primary** — the party that won the seat
last time — split by whether their member was on the ballot again. `sd` is the
spread a simulation has to reproduce:

| region | n stood | mean | sd | n gone | mean | sd | sd ratio |
|---|--:|--:|--:|--:|--:|--:|--:|
| **NSW** | 134 | +1.81 | 5.17 | 47 | -0.96 | **8.81** | **1.71x** |
| federal | 259 | -1.40 | 4.05 | 40 | -1.17 | 4.28 | 1.06x |
| vic/qld/wa/sa | 211 | -1.00 | 4.69 | 59 | -1.08 | 5.70 | 1.22x |

**The level shift is small and the spread shift is large.** In NSW the held
party goes from being under-predicted by 1.81 when their member stands to
over-predicted by 0.96 when they go — a personal vote worth **2.77 points**,
real but nowhere near enough to flip a seat held by twelve. The challenger's
error barely moves at all (-0.81 to -0.02).

What moves is the **spread: 5.17 to 8.81**. A departed-member NSW seat is not
biased, it is *unpredictable* — and `simulate_seat_contests()` takes **one
`seat_sd` for every seat in the chamber** (`R/seat_sim.R:288`; the vector it
builds is per-PARTY, length K, never per-seat). So every one of these seats is
simulated with the spread of an ordinary seat, the margin says safe, and the
probability comes out at 0.95 when the honest answer is nearer 0.75.

That is the whole failure, and it explains every part of the pattern: why it is
worst in SAFE seats (a wide error only changes the answer where the margin said
there was no question), why the mean-based retirement feature bought nothing
(-0.09 points, t = -0.16 — a mean correction cannot fix a variance fault), and
why margin does not explain it.

**Federal at 1.06x says this is not a general truth about departing members.**
Whatever it is, it is close to absent federally and strong in NSW.

## It is NSW, and I cannot say why

Pooled over all seven AEF elections the same split is **13.8% against 11.4%,
z = +0.74** — nothing. Per pair, the ratio of departed to stood log loss runs
0.2x to 2.6x across the other fifteen pairs, below 1 in five of them. Only the
two NSW pairs are extreme, and both are.

Two mechanisms are available and **neither is tested**:

- NSW is the only jurisdiction here with **optional preferential voting**, so a
  departing member's scattered vote exhausts rather than flowing back to their
  party. The flow model is fitted mostly on compulsory-preferential data, which
  `docs/plans/prereg-flow-fragmentation-2026-09-15.md` already lists as a known
  unmodelled error for NSW.
- NSW state members may simply carry larger personal votes than federal members.

Deciding between them needs the NSW exhaustion data that is still unparsed. I am
not guessing in a doc.

## What this does NOT support

**Filling in the missing `retirement` feature does not fix this.** That was the
first idea and it was measured and refused:

`retirement_i` comes from `load_seats()` and is **0.0% populated on eleven of
twenty-three pairs** — every federal pair to 2016, qld2020, vic2014, vic2018 and
every WA pair before 2025. That is a live defect in its own right, because a
column constant within a subgroup is a **label** for that subgroup and a tree
will split on it; `CLAUDE.md` records that shape costing pooled RMSE 3.8740 to
3.9297.

But the value of filling it is not there. On the eleven pairs the anchor cannot
cover, the effect of departure on the held party's primary residual is
**-0.09 points, t = -0.16** (151 departures against 725). On the ten it does
cover, -0.60, t = -1.13. **Neither is a signal**, and an MDE around 1.6 points
means an effect below that could hide — so this is "not detected", not "absent".

So the NSW failure is not a missing feature. The model HAS the seat's margin and
HAS whether the candidate is returning; it is wrong about how much a safe NSW
seat can move when the sitting member goes.

## Derivation, and two silent joins it survived

`scripts/build_retirement_derived.py` writes `output/retirement-derived.csv`,
1,889 seat-pairs across all 21 pairs, 8.6% to 30.4% departure rates. Validated
against the anchor column where both exist: **93% agreement over 940 seats**,
and the disagreements are mostly the derivation catching mid-term departures the
anchor cannot see — Tudge in Aston, Morrison in Cook, Robert in Fadden, Murphy
in Dunkley, all correctly marked gone.

Two joins failed silently on the way and both produced plausible numbers:

1. **Name formats differ by jurisdiction.** sa2018 writes `Rachel Sanderson`,
   sa2022 writes `SANDERSON, Rachel`, nsw2015 writes `FOLEY Luke` (surname
   FIRST), federal writes `Alan TUDGE` (surname last), and **WA stores the
   surname alone** — `PRINCE`, `WATSON`. Matching raw strings made South
   Australia **47 of 47 retired**, and reading NSW's order as "Given Surname"
   split `WILLIAMS Ray` from `WILLIAMS Raymond` and retired a sitting member.
2. **vic2010 carries zero `elected` flags**, so vic2014 had no prior winner at
   all. Falls back to the highest primary vote.

An earlier version matched WA's empty-after-parse names to each other and
reported a tidy 9-of-57 departure rate. **Every one of these failures returns a
believable percentage**, which is why the script prints the rate per pair and
flags anything outside 2-45%.

## Where this leaves the AEF gap

fed2022 was re-run under the state-swing correction that shipped earlier the
same day; it had been seven hours stale. Every WA seat improved — Tangney 3.53
to 3.11, Hasluck 1.50 to 1.24, Swan 0.62 to 0.49 — and pooled moved 0.2701 to
**0.2696 against AEF's 0.2808** over 660 seats.

The two elections where AEF still beats us:

| election | ours | AEF | gap per seat |
|---|--:|--:|--:|
| nsw2023 | 0.2695 | 0.2138 | **+0.0557** |
| fed2022 | 0.2606 | 0.2339 | +0.0267 |

And the structural fact underneath all of it: **on the 581 seats we call
correctly we beat AEF by 22.48 of total log loss, and on the 79 we call wrong we
lose 15.46.** We are sharper and they hedge. Our gap is not spread thinly — it
lives entirely in confident errors, and in NSW those are disproportionately
seats whose member walked away.

## Next: the fix this implies, and why I did not build it overnight

The correction the measurement asks for is **a per-seat multiplier on
`seat_sd` when the previous winner is not on the ballot**, around 1.7x in NSW
and 1.2x elsewhere — and, per the shrinkage rule, partial-pooled by region
rather than a hard NSW-only cliff, because the regional cells are thin (47, 40,
59) and one of them is doing all the work.

**`simulate_seat_contests()` cannot express that today.** `seat_sd` resolves to
one vector of length K — one number per PARTY, shared by every seat
(`R/seat_sim.R:575-589`) — and `seat_sim_core()` takes it as `seat_sd_vec`.
Making it per-seat changes the C++ core's signature (`src/seat_sim_core.cpp`,
`R/RcppExports.R`), which every harness and the published Victorian forecast run
through.

I stopped here deliberately. `CLAUDE.md` says a model or forecast rule gets
designed WITH Pete on real examples before it is written, and the eleven seats
in the table above are exactly those examples. A signature change to the
simulation core, made overnight and unreviewed, against a live forecast, is the
wrong way to spend that trust — and the measurement it would serve is already
banked and will not go stale.

Open questions for that conversation, in the order they matter:

1. **Is the multiplier regional or is NSW a proxy for something else?**
   Federal is 1.06x and the other states 1.22x. If the real driver is optional
   preferential voting, the correction should key on the voting system, not the
   state — and NSW is the only OPV jurisdiction in the corpus, so the two are
   indistinguishable here by construction.
2. **Does it belong on the primary or on the seat?** The measured widening is
   in the held party's own first-preference error, which argues for the primary
   model's sd rather than the simulation's `seat_sd`.
3. **Does the level shift ride along?** 2.77 points is small but real and has
   the sign a personal vote should have.

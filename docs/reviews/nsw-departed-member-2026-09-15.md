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

## Next

Not a pre-registration and not a proposal. The measured, unexplained fact is
that departed-member NSW seats need far more uncertainty than a safe margin
implies. Before anything is fitted, the OPV-exhaustion mechanism should be
tested against the personal-vote one, because they imply different corrections
and the data to separate them is the NSW preference detail that is still
unparsed.

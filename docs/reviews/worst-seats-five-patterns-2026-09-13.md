# Worst 15 seats vs AEF, post-redistribution/ret_exp: five real patterns

2026-09-13, after shipping the notional-prior redistribution fix and
`ret_exp` (see `notional-prior-redistribution-2026-09-13.md` and
`xgb-primary-retention-feature-2026-09-13.md`). Waite/Ngadjuri/Hartley
dropped off the worst-seats table entirely; this is the new top 15, reviewed
seat by seat against real candidate data (not guessed from the summary
table -- `output/candidacies.csv`, both elections, per seat).

## The current worst 15

| pair | seat | won by | our_p | aef_p | our_prim | aef_prim | actual_prim | delta |
|---|---|---|--:|--:|--:|--:|--:|--:|
| sa2026 | Black | ALP | 0.044 | 0.925 | 35.2 | 41.0 | 43.0 | 3.04 |
| qld2024 | South Brisbane | ALP | 0.022 | 0.162 | 27.2 | 25.2 | 32.0 | 1.99 |
| sa2026 | Finniss | IND | 0.083 | 0.557 | 17.0 | 23.3 | 22.2 | 1.91 |
| nsw2023 | Parramatta | ALP | 0.126 | 0.717 | 35.7 | 41.9 | 47.0 | 1.74 |
| nsw2023 | Monaro | ALP | 0.065 | 0.283 | 30.8 | 33.4 | 38.1 | 1.47 |
| fed2025 | Braddon | ALP | 0.031 | 0.130 | 23.6 | 29.4 | 39.5 | 1.44 |
| nsw2023 | Heathcote | ALP | 0.225 | 0.945 | 38.5 | 43.6 | 44.2 | 1.44 |
| vic2022 | Morwell | LNP | 0.149 | 0.571 | 23.8 | 32.6 | 38.4 | 1.34 |
| fed2025 | Flynn | LNP | 0.261 | 0.890 | 31.3 | 36.5 | 37.4 | 1.23 |
| qld2024 | Mirani | LNP | 0.123 | 0.416 | 32.8 | 32.5 | 36.7 | 1.22 |
| nsw2023 | Riverstone | ALP | 0.258 | 0.800 | 39.1 | 44.6 | 44.2 | 1.13 |
| vic2022 | Richmond | GRN | 0.261 | 0.809 | 34.6 | 43.7 | 34.7 | 1.13 |
| nsw2023 | Wakehurst | IND | 0.129 | 0.342 | 8.6 | 27.7 | 35.9 | 0.98 |
| sa2026 | Narungga | ONP | 0.035 | 0.092 | 28.3 | 18.4 | 37.5 | 0.97 |
| fed2022 | Tangney | ALP | 0.032 | 0.084 | 27.0 | 34.3 | 38.1 | 0.96 |

Note AEF also under-calls the primary in most of these (e.g. Braddon: they
say 29.4, actual 39.5) -- the win-probability gap is often bigger than the
primary gap because their model handles uncertainty around a similarly-off
point estimate better than ours does. Not purely "AEF nails the vote and we
don't."

## Five patterns, found by pulling real candidate data per seat

**A -- a SENIOR retiring MP loses more personal vote than the flat
retirement discount assumes (5 of 15).**
- Monaro: John Barilaro (NSW Deputy Premier) 52.3% -> successor 39.1%
- Braddon: Gavin Pearce (shadow minister) 44.1% -> successor 31.7%
- Riverstone: Kevin Conolly 54.1% -> successor 39.9%
- Richmond: Richard Wynne (a minister) -- ALP's own vote fell 44.4% -> 32.8%
  even though nobody beat them on primary; GRN won by standing still
- Parramatta: Geoffrey Lee 54.0% -> retired, ALP +16.8 beyond the state
  average swing

The model applies one flat retirement/MP-slope discount regardless of how
prominent the retiring member was. A Deputy Premier's personal vote is not
the same size as a first-term backbencher's.

**B -- South Australia's One Nation surge is broader than one bad seat
(3 of 15).** Finniss (ONP 4.7% -> 22.5%), Narungga (ONP 5.4% -> 37.7% under
a brand-new candidate), Black (ONP 18.9% out of nowhere alongside a right-
vote collapse). This is the already-parked "sa2026 One Nation ranking"
problem (no same-jurisdiction precedent before 2022) -- seeing it explain a
fifth of the CURRENT worst list is a reason to check whether a statewide
ONP-trend correction (rather than a seat-level one) is more tractable than
previously judged.

**C -- a defecting incumbent fragments the vote three ways, and the major
wins on a smaller swing than expected.** Black: sitting LNP member (former
party leader David Speirs) quit to run as IND, splitting the right between
IND (14.1%), the new LNP candidate (9.8%) and ONP (18.9%). ALP won
comfortably without needing a big swing at all -- the model likely still
reads "new IND" as a threat to the incumbent rather than "conservative vote
shattered three ways, the other side wins by default."

**D -- a departed independent's vote can revert to EITHER major, and we
don't reliably know which.** Morwell: Russell Northe (a former Nationals MP
turned popular local independent) retired; his voters preferenced LNP over
ALP even though ALP had the higher primary. `ret_exp` (shipped today) was
built and validated on the leftward case (Waite: IND vote reverts to ALP);
Morwell shows the same mechanism needs to handle reversion rightward too --
untested in that direction.

**E -- Queensland's optional-preferential system resolves some contests
against the primary-vote leader.** South Brisbane: Greens led on primary
(34.7%) but Labor won -- inner-Brisbane LNP preferences are known to flow
more to ALP than to GRN. Preference-flow calibration gap specific to QLD's
inner-city seats, not a primary-vote miss (`why = flow/var` in the
comparison table, consistent with this).

## Decision: build Pattern A next

Cheapest lever of the five -- a static, hand-curated feature (which
retiring MPs held a ministry/leadership position), no new data fetch, and it
directly extends machinery already proven to matter here
(`fit_defector_discount()`, the MP-slope tier in `fit_mp_slope.R`). Size it
properly (how many historical cases, effect size) before building -- next
session/turn's task.

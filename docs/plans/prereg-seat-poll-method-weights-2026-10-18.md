# Pre-registration: weight seat polls by how they were done and who paid (2026-10-18)

Committed BEFORE anything is built or run. Pete, 18 Oct: "we should check polling methodology for all these polls
and remove or downweight poor / non-rigourous methodology ... using all seats with seat polling, and assigning poll
type and seeing what weights should be".

## Why

McMahon fed2025: one Compass Polling survey (8 Apr 2025, n=1,003) had the independent at 41%; he got 9.8%. It was
an opt-in SMS-link survey with his name appearing preselected (Compass's own replies to ABC Media Watch), and our
blend weighted it like any direct poll, publishing him at 29.0 and 0.71 to win. Every seat poll is now classified
(`external/reference/polls/seat-polls/poll_methods.csv`, `reviews/seat-poll-methods-2026-10-18.md`). First read,
poll minus actual, MAE in points: media-paid direct 4.42 (48 polls); paid by a party, union, advocacy group or
industry body 5.74 (49; independents 7.81 vs 6.02); party-paid majors 15.5 (4); opt-in link 12.4 (2; independents
20.4); MRP 5.33 (940).

## What the blend does now (`R/seat_poll_blend.R`)

Each poll's weight is `0.5^(days/H) / (sampling variance + floor[group])`, the floor per group (`mrp`, `direct`,
`sponsored`) fitted on earlier elections and shrunk by `SEAT_POLL_FLOOR_K`. `sponsored` keys on the `client` column,
filled for about 35 of 1,210 polls, so stake-holder polls are almost all treated as `direct`.
`AUSPOL_SEAT_POLL_FIRM_FLOOR` (each firm's floor scaled by its own record, shrunk to 1) was built 9 Oct and never
scored on seat polls.

## Arms (switch `AUSPOL_SEAT_POLL_GROUPS`, plus the existing firm switch)

| Arm | Rule |
|---|---|
| A (shipped) | groups mrp / direct / sponsored from `client`; firm floor off. |
| G | groups from `poll_methods.csv`: `mrp`; `direct_indep` (media, pollster's own, or unknown sponsor); `direct_stake` (party, union, advocacy group, industry body, candidate campaign); `optin` (method optin_link). Floors fitted exactly as now (time-forward, shrunk to the pool by `SEAT_POLL_FLOOR_K`). A poll missing from the file keeps its old group. |
| F | firm floor on (`AUSPOL_SEAT_POLL_FIRM_FLOOR=1`), firm = `pollster_clean` from the file. |
| GF | both. |

**The opt-in prior, stated now because time-forward fitting cannot see it:** both opt-in polls are fed2025, so no
earlier election has one and G alone gives `optin` the pooled floor. `optin`'s floor prior is therefore 4x the
pooled floor (CHOSEN: an opt-in, self-selected sample has roughly twice the error sd of a panel or phone poll in the
survey-methods literature, so 4x the variance), still shrunk toward the data as elections with opt-in polls accrue.
Reported both with and without this prior (G and G0) so its effect is visible.

## Criterion

Screen on the elections with seat polls (`quick_arm.R --pairs=` fed2016 fed2019 fed2022 fed2025 nsw2015 nsw2019
nsw2023 qld2017 qld2020, 5,000 sims), then a 20,000-sim deciding run on the best arm.

1. **Primary: seat log loss on seats that had at least one seat poll**, SE clustered on election. An arm ships if it
   beats A by more than 1 SE. If more than one does, the simplest (G before F before GF) unless a fuller one is
   better by more than 1 SE again.
2. **Guard: every seat in those elections**, not worse by more than 1 SE.
3. **Reported:** McMahon fed2025 (IND share and win probability), the seat-poll share RMSE by group, fed2025 alone
   (where seat polls deserved about 0.13 and got 0.55), and each group's fitted floor per target.

## What would make an apparent win unacceptable (decided now)

- One election supplies more than half the primary gain -> refused.
- The gain is ONLY McMahon (drop it and the arm is within 1 SE) -> reported to Pete as a one-seat result.
- Live vic2026: any seat whose favourite moves more than 10 points is listed for Pete (vic2026 has few seat polls).

## What this cannot see

- 141 direct polls have no known method and 86 no known sponsor; they keep `direct_indep`.
- Method labels for non-MRP polls are mostly the agent's inference from each firm's usual practice (medium/low
  confidence); only sponsor labels backed by a "commissioned by" footnote are high confidence.

## Amendment 1 (2026-10-18, before anything is built; Pete: "maybe the assumption is weight is 0 until proven otherwise
## and this type of poll stays at weight near 0 ... not being hacky but being bayesian")

The original text stands. The opt-in prior changes from "4x the pooled floor" to an explicit error-size prior:
**an opt-in seat poll is assumed to miss by about 15 points (floor prior 225 = 15^2)** until its own record says
otherwise. CHOSEN, and stated as an error size so it can be read and argued with: at that floor its weight is roughly
a tenth of a typical direct poll's, i.e. near zero, as Pete asked. It is shrunk toward the group's observed floor by
the same `SEAT_POLL_FLOOR_K` pseudo seat-elections as every other group, so only accumulated evidence moves it.
Every other group keeps the existing prior (the pooled floor), so the rule is one rule for all groups with one
documented prior per group, not a special case. G0 (no opt-in prior) is still reported, so the prior's effect is
visible on its own.

## Amendment 2 (2026-10-18, before anything is built or run; Pete: "One Bayesian blend")

The original text and amendment 1 stand. Tracing McMahon end to end in the SHIPPED blend (scratchpad `mcmtrace.R`,
our pre-blend shares fed in) showed the groups alone cannot fix it: IND 4.9 -> 28.3 shipped, 27.5 with arm G, 29.6
with the existing precision blend. Three causes, all general:
1. **One model uncertainty per class.** `seat_poll_model_var()` gives every independent sd 14.8 points, so any poll
   outvotes the model on a 5% independent.
2. **The independent cell is overwritten by the direct-poll figure alone** (`.ind_direct_cells()`), so McMahon's
   MRPs (independent 3.9-6.6) never vote on it, and a lone direct poll is never weighed against anything.
3. **"Others" in a poll is split only over OTH_RIGHT / ONP / OTH**, so McMahon's RedBridge MRP others (17-19)
   went wholly to One Nation (actual 8.7) and none to the independent.

**Arm B (one Bayesian blend)** = all of these together, each behind its own switch so its contribution is measured:
- `AUSPOL_SEAT_POLL_PRECISION_BLEND=1` (built, off): each cell's pull is `v / (v + 1/P)`, P the summed per-poll
  precisions.
- `AUSPOL_SEAT_POLL_SIZEVAR=1` (new): the model's error variance `v` for a cell depends on the class AND our
  predicted share: per class, `v = v_c * ((pred + 1) / (ref_c + 1))^g`, `v_c` and `ref_c` the class's shrunk
  variance and median prediction on earlier elections' polled cells (as now), `g` one exponent fitted on the same
  earlier cells (least squares on log squared error), shrunk toward 0 by its SE (`w = max(0, 1 - se^2/g^2)`).
- `AUSPOL_SEAT_POLL_ALLPOLLS=1` (new): no direct-only override of the independent cell; every poll (MRP and direct)
  enters the cell with its own floor-and-recency weight.
- `AUSPOL_SEAT_POLL_GROUPS=method` (built): group floors from the method file, opt-in prior 225.
- `AUSPOL_SEAT_POLL_SPLIT_ALL=1` (new): a poll's "others" is split over EVERY class standing in the seat that the
  poll does not name (independent and Greens included), in proportion to our as-at expectation; the existing
  endorsed/sitting OTH-to-IND rule is unchanged.

**Arms screened:** A (shipped); B (all five); and B minus each one in turn (five arms). The primary, guard and
refusal clauses above apply to B; the leave-one-out arms are REPORTED, so any piece that adds nothing can be dropped
before the deciding run (a piece whose removal does not worsen B by more than 1 SE is dropped: fewer moving parts).
McMahon's end-to-end independent share and win probability are reported for every arm.

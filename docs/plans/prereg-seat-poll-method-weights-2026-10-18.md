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

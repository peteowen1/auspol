# Pre-registration: the leader-seat bonus before the seat-poll blend (`AUSPOL_LEADER_BEFORE_BLEND`)

Written 2026-11-06 ~7:10pm, before any screen. Found tracing the worst AEF-7 seat (Pete: "keep going and digging").

## What it changes

`leader_seat_bonus()` is fitted as actual minus the as-at tree prediction BEFORE the seat-poll blend (`xgb_pred_seat`).
Every script (six harnesses, NT, `fit_seats_full.R`) adds it AFTER the blend. A leader's seat with seat polls therefore
counts the leader effect twice: the polls already measure it. Melbourne fed2025: tree 49.35 Greens; the blend alone gives
45.94 (checked by calling `seat_poll_blend_apply()` on that row); +2.58 bonus, published 49.26. Bandt got 39.46; Labor won
and we gave it 0.006, the worst seat in AEF-7. Dickson fed2025 (Dutton) got the same +2.58 and is also a top-10 miss
(Labor 0.085). The switch moves the bonus before the blend; an unpolled leader seat is unchanged (the blend does not touch it).

## Known answers, stated before the screen

- Melbourne fed2025 Greens falls from 49.26 toward about 46-47 (the blend pulls part of the bonus back); Labor's win
  probability rises from 0.006.
- Every seat that is not a polled leader seat is byte-identical (common random numbers in `quick_arm.R`).
- Applied check: LS1 prints once per election, from the pre-blend call when on.

## Screen

`scripts/quick_arm.R "AUSPOL_LEADER_BEFORE_BLEND=1" --pairs=all --sims=1000`, baseline the shipped configuration.

- Primary: seat-winner log loss (lower is better) on the leader seats that have seat polls (named from the run's LS1
  lines and the seat-poll table, before reading the result), SE clustered on election.
- Guard: pooled log loss over all 35 elections not worse by more than 1 SE.
- Reported: primary share error on the leader's class in those seats.

The leader seats with polls are few (a handful per polled election), so the primary's own noise is large; a result
within 1 SE is a TIE. Decision rule (standard): primary better by more than 1 SE and the guard holds: recommend the
20k deciding run, then ship; a tie goes to Pete as a correctness fix (the bonus is fitted pre-blend, so pre-blend is
where it belongs) with the split shown; worse: to Pete with the split.

What would make a win unacceptable: the gain coming from unpolled seats (impossible by construction; if any unpolled
seat moves, the plumbing is wrong and the run is void).

## Primary set, named 7:25pm before the screen finished (`leader_seats()` x `seat_poll_shares(by_type = TRUE)`)

7 polled leader seats in 3 elections: fed2022 Grayndler (ALP, Albanese), Cook (LNP, Morrison), Melbourne (GRN, Bandt);
fed2025 Grayndler, Dickson (LNP, Dutton), Melbourne; wa2021 Dawesville (LNP, Kirkup). With 7 seats the primary is
descriptive: its SE (clustered on 3 elections) is barely estimable, so the decision leans on the correctness argument
and the guard, as stated above.

## RESULT

(not run)

### RESULT (2026-11-06 7:50pm, 1,000 sims, all 35 elections; caches e7e7a472f996 / 1a1f8d00ed95): PASSES. Recommend the 20k deciding run, then shipping.

- Guard, pooled seat-winner log loss (lower is better), 2,931 seats: 0.3042 -> 0.3039, -0.0003 (SE 0.0003), better by just
  over 1 SE; AEF-7 (681 seats) 0.2581 -> 0.2569, -0.0012 (SE 0.0011). No election worse; fed2025 -0.0054, wa2021 -0.0004.
- Primary, the 7 polled leader seats: mean -0.118 per seat. Dickson fed2025 Labor 0.072 -> 0.138 (-0.65); Melbourne fed2025
  0.006 -> 0.007 (-0.15); Dawesville wa2021 0.946 -> 0.969 (-0.02); Grayndler fed2025 0.991 -> 0.989 (+0.002); the fed2022
  three unchanged. The leader's share moved toward the actual in 5 of 7 (both Grayndlers moved away).
- Not as predicted: 25 of 35 elections are not byte-identical (10 are). Moves elsewhere are under 0.08 points except
  fed2022/fed2025: unpolled leader seats now get the bonus before the demographic step rather than after it, and in fed2025
  36 seats moved by small win probabilities, very likely through the state-poll pool (it spreads a state's poll gap over
  its seats, and Dickson's change moves Queensland's total). UNVERIFIED; check in the deciding run's per-seat files.

### RESULT, deciding run (2026-11-07 3:00am, 20,000 sims, all 35 elections; `deciding-runs/20261106-1951-leader-before-blend/`, caches 628c972c300b / 1d1236a31c81): HOLDS. SHIPPED 7 Nov (Pete).

- Guard, pooled seat-winner log loss (lower is better), 2,931 seats: 0.3125 -> 0.3123, -0.0002 (SE 0.0002); AEF-7 (681 seats)
  0.2585 -> 0.2574, -0.0010 (SE 0.0010). Share error on the 42 changed cells -18% (SE 45.5 on -111.0). No election worse
  by more than 0.0001 (sa2018 +0.0001). fed2025 -0.0048, wa2021 -0.0004.
- The void clause ("if any unpolled seat moves, the plumbing is wrong"), read strictly, trips: in fed2025, 147 seats besides
  Dickson, Melbourne and Grayndler move by at most 0.046 share points (median 0.001), net seat log loss +0.0034. The three
  polled leader seats carry -0.716. Traced 7 Nov: ALL of it is the state poll pool (`state_poll_pool_apply()`, which
  runs right after the pre-blend bonus, `backtest_candidate_fed.R:1546`). A fed2025 screen with `AUSPOL_STATE_POLL_POOL=0` in
  both arms moves exactly those 3 seats, with every other seat's shares and win probabilities identical. By state: NSW, QLD
  and Victoria move 0.02-0.05 points; every other state about 0.001, through the national mean the pool measures each
  state's gap against (`R/state_poll_pool.R:83`). The pool now reads the poll gap against a model that already has the
  leader bonus, instead of reading Dutton's personal vote as a Queensland polling miss. Pete shipped with the clause
  overridden on that trace (the clause's purpose, a gain made in unpolled seats, does not hold: they net +0.0034).

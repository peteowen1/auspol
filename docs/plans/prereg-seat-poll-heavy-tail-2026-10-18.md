# Pre-registration: a model that can be badly wrong (seat-poll blend, heavy-tailed model error) (2026-10-18)

Committed BEFORE anything is built or run. Pete, 18 Oct: "go" on the queued fix (NEXT-STEPS, "heavy-tailed model
error"). Follows `docs/PRE-REGISTRATION-RULES.md`'s standard decision rule.

## Why

Arm H (shipped 18 Oct) blends each seat-class cell as `pred + pull * (poll - pred)`, `pull = v / (v + 1/P + tau2)`, a
Gaussian compromise. When the model is badly wrong about a candidate it barely knows, a compromise is the wrong answer:

| Cell | Model | Polls | Pull | H | Actual |
|---|---|---|---|---|---|
| Goldstein 2022 IND (Daniel) | 4.3 | 33.8 (3 polls) | 0.69 | 24.5 | 34.5 |
| North Sydney 2022 IND (Tink) | 5.2 | 19.1 (4 polls) | 0.80 | 16.4 | 25.2 |

A 30-point gap is ~4 SD under the model's stated uncertainty: that the gap is so large is itself evidence the model
missed a surge. McMahon 2025 (model 5, one opt-in poll 41, actual 9.8) must stay fixed: there the dissenting poll is weak.

## The change (`AUSPOL_SEAT_POLL_HEAVY_TAIL=1`, every class, not independents only)

The model's error for a cell is a two-part mixture: with probability `1 - pi_c` the usual `v` (as arm H), with probability
`pi_c` a "badly wrong" component with variance `vbig_c`. Given the poll average and its variance `pv = 1/P + tau2`:

- each component k gives a Gaussian blend `m_k = pred + v_k / (v_k + pv) * (poll - pred)`;
- its weight is `pi_k * N(poll - pred; 0, v_k + pv)`, normalised over the two;
- the cell takes `sum_k w_k * m_k`.

`pi_c` and `vbig_c` are fitted on EARLIER elections' seat-class cells (all cells, as MODELVAR_ALL), per class: a
two-component normal mixture on the standardised errors `(actual - pred) / sqrt(v_cell)` by EM, `pi` shrunk toward the
pool over classes by `SEAT_POLL_FLOOR_K` pseudo-elections and toward a prior of 0.02, `vbig` toward a prior of 100
(sd 10 points). Salience, where on, scales `v` as now (not `pi`): one change at a time.

Nothing about the polls changes. A weak poll (large `pv`, e.g. opt-in, floor sd 15) makes both components' likelihoods
flat, so the mixture stays near the ordinary blend; several good polls far from the model make the "badly wrong"
component win.

## Arms

| Arm | Switches |
|---|---|
| H (shipped) | as published |
| T | H + `AUSPOL_SEAT_POLL_HEAVY_TAIL=1` |

Screen: quick_arm, 5,000 sims, the elections with seat polls (fed2016-fed2025, nsw2023, sa2026, wa2021 and the rest of
the nine-election list). Deciding run (20k, all 35 elections) only if the screen passes.

## Decision rule (standard rule, `PRE-REGISTRATION-RULES.md`)

1. **Primary:** seat-winner log loss on polled seats, T better than H by more than 1 SE (SE clustered on election).
2. **Guard:** every seat of every scored election, not worse by more than 1 SE.
3. **Leave-one-election-out:** primary still better by more than 1 SE with each election dropped.
4. **No election worse** by more than 2 SE of its own paired seat differences.
5. **Named targets reported:** Goldstein 2022, North Sydney 2022, Curtin 2022, Warringah 2019 (P(actual winner), IND share).
   **Must not break:** McMahon 2025 and Mayo 2025 (sitting independent): either falling below H by more than 0.10 in
   P(actual winner) goes to Pete, not silently shipped.
6. Dry run before screening: `pi`, `vbig` per class at fed2022 and fed2025, and the blended IND share for the six named
   seats against H's.

## What this cannot see

- A surge with no poll at all (Warringah 2019's only poll had Steggall at 22.3, actual 44.7): no blend can recover it.
- Whether "badly wrong" should depend on salience: deliberately left out of this arm (one change at a time).

## Amendment 1 (2026-10-18, before anything is built or run)

The mixture is fitted on STANDARDISED errors, `z = (actual - pred) / sqrt(v_cell)` (`v_cell` the class variance with the
size scaling, as arm H), per class: zero-mean two-component normal by EM, ordinary scale `s1` and "badly wrong" scale
`k * s1` with weight `pi`. In the blend the components are `v * s1` and `v * s1 * k`. Reason: a fixed absolute `vbig`
(prior 100) would give a 2% candidate the same "badly wrong" spread as a 40% one; `v` already scales with size.
`pi` shrunk toward the pool over classes by `SEAT_POLL_FLOOR_K` units and the pool toward 0.02; `k` floored at 1.5.
Everything else as written.

## RESULT (2026-10-19 00:15; quick_arm 5,000 sims, 7 polled elections, deciding-runs/heavytail-screen/) -- REFUSED

Fit (fed2025): independents ordinary scale 0.20 with 17.9% badly-wrong weight at 17x the variance; ALP 2.9%, x7.2.
Seat-winner log loss, T minus shipped H (lower is better), SE clustered on election: polled seats (314) -0.0004
(SE 0.0052), every seat (801) -0.0002 (SE 0.0021); leave-one-election-out never better by >1 SE; fed2025 -0.0091,
fed2022 +0.0015. P(actual winner) H -> T: Goldstein 2022 0.488 -> 0.687 (target), Curtin 2022 0.528 -> 0.582, Ryan 2025
0.648 -> 0.678; North Sydney 2022 0.205 -> 0.190, Warringah 2019 0.146 -> 0.093, Mayo 2016 0.078 -> 0.047; McMahon 2025
0.919 -> 0.921 and Mayo 2025 0.965 -> 0.964 (must-not-break, held). Not better than H: the switch stays "0".
The mixture follows polls harder when they are far from the model, which is right when the polls are good (Goldstein)
and wrong when the only poll is itself low (Warringah 2019, GetUp IND 22.3, actual 44.7; Mayo 2016). The lever left is
the polls' own error in a surge, not the model's.

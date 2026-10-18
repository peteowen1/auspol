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

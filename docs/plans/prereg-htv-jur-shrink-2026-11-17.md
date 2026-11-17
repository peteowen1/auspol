# Pre-registration: a per-state level in the Liberal card shares (`AUSPOL_HTV_JUR_SHRINK=1`)

Written 2026-11-17 ~10:15pm, before any screen. Pete, 17 Nov, chose "Prereg + screen it" on: the vic2026 forecast gives
Liberal preferences to Labor over the Greens at 61.7% under a Labor-above card, a share pooled over 17 elections and
pulled down by sa2026 59.7, fed2019 59.0, wa2025 57.4, while Victoria's own Labor-above elections gave 66.8 (2010) and
67.8 (2014). Starts from the standard decision rule (`docs/PRE-REGISTRATION-RULES.md`).

## What it changes

`htv_card_label_shares()` (`R/htv_flow.R`, published under `AUSPOL_HTV_LABELS=hybrid`) fits three shares (Labor-above,
Greens-above, open card) from (election, label) cells of earlier elections, each label shrunk toward the pooled mean.
`AUSPOL_HTV_JUR_SHRINK=1` adds one level: cells are grouped by (label, jurisdiction) (jurisdiction = election name
without its year: fed, vic, nsw, qld, sa, wa, nt), and the target jurisdiction's group mean pulls its label's share
by `w_j = tau_j^2 / (tau_j^2 + se_j^2)` (`htv_jur_adjust()`): `se_j^2` = pooled within-group cell variance over the
group's effective cell count, `tau_j^2` = mean squared group deviation less mean `se_j^2`, floored at 0. No `min_n`:
a one-cell group shrinks harder. Time-forward as before (`elections_before()`). `"0"` (published) is byte-identical.

Federal elections are one jurisdiction: a Victorian federal seat (Melbourne, Wills) trains `fed`, not `vic`.

## Known answers, stated before the screen (dry run 10:05pm, shares only, no score seen)

Applied check: `HTV15` prints each fit's groups, weights and adjustment; `HTV14` the shares before it.

| Target | Labor-above off -> on | Greens-above off -> on | Open off -> on |
|---|---|---|---|
| vic2026 (live) | 61.7 -> 64.0 | 38.3 -> 36.4 | 57.1 -> 57.7 |
| vic2022 | 60.3 -> 64.3 | 40.2 -> 34.7 | 52.6 -> 56.9 |
| vic2018 | 60.4 -> 65.9 | 35.6 -> 33.7 | 52.9 |
| fed2025 | 59.8 -> 60.5 | 38.2 -> 29.0 | 56.8 |
| fed2022 | 59.5 | 40.2 -> 29.8 | 52.5 |
| wa2025 | 60.4 -> 51.9 | 38.1 -> 42.1 | 56.7 |
| nsw2023 | 60.3 | 38.2 -> 47.6 | 52.4 -> 49.0 |
| sa2026, qld2024 | unchanged (no sa cells; qld -0.2 Greens-above) | | |

Only targets whose card row uses a moved share change seats (an election with no card row is byte-identical, `HTV0`).

**What this does NOT do, said now:** Melbourne fed2025 (the night replay's wrong call; 60.3 used, 79.3 actual) moves
only to ~60.5, because federal Labor-above cells before 2025 average 60.8. Melbourne is a seat-level effect (Liberal
voters where the Greens are the threat follow the card harder); this arm does not test that.

## Screen

`Rscript scripts/quick_arm.R "AUSPOL_HTV_JUR_SHRINK=1" --pairs=all --sims=1000`

- **Primary:** seat-winner log loss (lower is better) pooled over the elections with any changed seat, SE clustered on
  election; better by more than 1 SE.
- **Guard:** seat log loss over all 22 not worse by more than 1 SE.
- **No election materially worse:** no election worse by more than 2 SE of its own paired seat differences.
- **Not one election's quirk:** leave-one-election-out; each election's share of the change reported.
- **Reported, not decisive:** squared error on changed cells; the AEF-7 subset; Victoria (vic2010-2022) separately,
  since the live effect is Victorian.
- **Decision:** primary passes and guards hold: deciding run (20,000 sims, all 22, detached), then to Pete with the
  vic2026 seats that move before it ships. Within 1 SE: a tie, to Pete (a per-state level is the better-specified
  model, but it has no measured gain). Worse by more than 1 SE: refuse, to Pete with the split.

**What would make an apparent win unacceptable:** a gain carried only by non-Victorian elections while every Victorian
election is worse. The live use is Victorian, so Victoria is shown as its own split, and a Victorian loss beside an
overall win goes to Pete as a clause conflict rather than shipping.

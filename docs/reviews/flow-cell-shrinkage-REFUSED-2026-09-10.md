# Flow-cell data-weighted smoothing — REFUSED, 2026-09-10

Pre-registration: `docs/plans/prereg-flow-cell-shrinkage-2026-09-10.md`.
Implements `shrink_k` on `simulate_seat_contests()` (`R/seat_sim.R`):
replaces `distribute_preferences()`'s flat `smooth = 0.15` with
`shrink_k / (n + shrink_k)` on MATCHED conditional flow cells only (pooled
fallback untouched), where `n` is the cell's own event count from
`build_flow_matrix()$coverage`. Default `shrink_k = 0` preserves previous
behaviour exactly (verified: full existing test suite unchanged, 235+ tests
across `test-preferences.R`/`test-flow-matrix.R`/`test-seat-sim.R`/
`test-level_sd.R`/`test-seat-sd.R`).

## Dry run (pre-registered, run before the grid) — passed as designed

| example | cell | n | conditional used? | shrink_k=20 effect |
|---|---|--:|---|---|
| Ballarat, fed2007 | `GRN\|ALP+LNP` | 672 | yes | smoothing weight 0.15→0.029 |
| Kiama, nsw2023 | `LNP\|ALP+IND` | 2 | no (below min_n=3) | zero effect — falls to pooled, out of scope by design |
| MacKillop, sa2026 | `ALP\|LNP+ONP` | 1 | no | zero effect — same reason |

## Grid result — pooled seat log loss, all 22 pairs, 2,050 seat-elections

`AUSPOL_N_SIMS=2000`, one seed (exploratory grid, below this repo's usual
5,000; see pre-reg for why). **Every non-zero `k` is worse than baseline on
the primary metric, monotonically:**

| k | pooled log loss | pooled Brier |
|--:|--:|--:|
| **0 (baseline, current shipped)** | **0.33857** | 0.09547 |
| 3 | 0.33951 | 0.09507 |
| 5 | 0.34074 | 0.09515 |
| 10 | 0.34288 | 0.09548 |
| 20 | 0.34518 | 0.09626 |
| 40 | 0.34860 | 0.09740 |
| 80 | 0.35356 | 0.09911 |

**REFUSED outright** — refusal condition 1 fires immediately: there is no
`k` that beats baseline, so the "must clear the noise floor" question never
even arises. Log loss (the decisive metric per this repo's own ordering) is
unambiguous. Brier shows a small, real disagreement at `k=3` (0.09547→0.09507,
marginally better) while log loss is already worse there (0.33857→0.33951) —
per refusal condition 3, checked and not treated as grounds to override log
loss's verdict; the disagreement is real but tiny and log loss stays
decisive per this repo's stated metric ordering.

## Per-jurisdiction-group log loss by k — the mixed picture behind the pooled number

| group | k=0 | k=3 | k=20 | k=80 | direction |
|---|--:|--:|--:|--:|---|
| federal (7 pairs, 1,036 seats) | 0.3216 | 0.3256 | 0.3299 | 0.3318 | worse, monotonic |
| nsw2019 | 0.4937 | 0.4951 | 0.5029 | 0.5139 | worse, monotonic |
| nsw2023 (Kiama's election) | 0.2943 | 0.2911 | 0.3058 | 0.3329 | worse past k=3 |
| qld2020 | 0.3178 | 0.3168 | 0.3073 | 0.3029 | **better, monotonic** |
| qld2024 | 0.3390 | 0.3341 | 0.3539 | 0.3902 | worse past k=3, badly |
| sa2026 (MacKillop's election) | 0.4065 | 0.3904 | 0.3904 | 0.3865 | **better, net** |
| vic (3 pairs) | 0.2644 | 0.2610 | 0.2659 | 0.2872 | mild U-shape, worse at high k |
| wa (7 pairs, 361 seats) | 0.4035 | 0.4036 | 0.4122 | 0.4230 | worse, monotonic |

**Not a uniform failure — a real, mixed effect that nets negative.**
qld2020 and sa2026 genuinely improve; federal and WA (the two largest
jurisdiction groups, 1,397 of 2,050 seats) get worse and dominate the pooled
number. fed2007 (Ballarat's own election) improves at every tested k
(0.3097→0.2988 at k=40) — the mechanism does exactly what it was built to
do on the case that motivated it. The aggregate failure is that MOST
conditional cells across the corpus don't generalise as well out-of-sample
as Ballarat's 672-event cell did; trusting a historical rate more (less
smoothing) costs more in overconfidence-penalised log loss on cells where
this election's actual flow deviates from the historical average than it
gains on cells where it doesn't. This is the same lesson `flow_sd`
(`R/seat_sim.R`) already encodes for a different mechanism: a flow rate is
a FORECAST quantity with real election-to-election variance, not just a
historical measurement with sampling noise — reducing smoothing addresses
the latter but the corpus mostly needed protection from the former.

## Two bugs found and fixed during this session, both real, both fixed in-tree

1. **`shrink_k > 0` crashed WA for any pair with no own transfer file**
   (`wa2001` as prior for `wa2005` — WA legitimately passes `matrix = NULL`
   there, "flows fall back to uniform"). The original check demanded a
   valid `matrix$coverage` unconditionally; fixed to only require it when
   `matrix$conditional` actually has entries to look an `n` up for
   (`R/seat_sim.R`) — a `NULL` matrix has nothing for `shrink_k` to touch
   anyway. Re-ran the 6 affected WA k-values after the fix; all 7 WA pairs
   now score cleanly at every k.
2. **The results parser silently dropped Victoria, Queensland, and South
   Australia** from the first pooled table — their harnesses print a
   summary line with no pair name (`BV2 accuracy 68/73...`, not
   `BV2 vic2014: accuracy...`), and Victoria's line reads "log score" not
   "log". The first parse (fed+nsw+wa only, n=1,811 of 2,050 seats)
   happened to still show "monotonically worse" — the corrected, full
   parse (all 2,050 seats) confirms the same verdict but for the right
   reason: qld2020 and sa2026 actually improve and were invisible in the
   first pass.

## Verdict

**Do not adopt `shrink_k` at any tested value.** The diagnosis that
motivated this (Ballarat's 672-event cell over-smoothed by a flat constant)
was correct and the fix does exactly what it was built to do on that case —
but the pooled, all-22-pair, primary-metric measurement this repo requires
refuses it cleanly. `shrink_k` stays in the codebase as a working, tested,
off-by-default (`shrink_k = 0`) parameter — same shape as `fallback_smooth`/
`flow_sd`/other unshipped arms — in case a future attempt narrows scope
(e.g. per-jurisdiction, since qld2020/sa2026 genuinely improve) rather than
applying one `k` globally. That narrower question is not scoped or run
here.

## Repo state

Uncommitted, ready for review: `R/seat_sim.R` (`shrink_k` parameter),
`scripts/backtest_candidate_{fed,nsw,qld,sa,vic,wa}.R` and
`scripts/fit_seats_full.R` (new `AUSPOL_FLOW_SHRINK_K` env-gated arm,
default `"0"`, no change to `published_flags.R`), this review, and the
pre-registration. No commits made.

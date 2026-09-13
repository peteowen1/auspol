# ret_exp (v7f) measured to a decision: real but thin, not yet shipped

2026-09-13. `fit_xgb_primary_v7.R`'s `ret_exp` retention feature (built
2026-09-12 off Pete's own question, "can we use this somehow?") had never been
run to a conclusion — `output/xgb-primary-v7-arms.csv` carried only `pred_v7c`,
no review doc existed, and the shipped inference path still reads
`xgb-primary-v6-oof-predictions.csv`. This closes that gap.

## Why it was found

Working the AEF worst-seats table (Tangney/Curtin/Pearce fed2022,
Wakehurst/Parramatta/Heathcote nsw2023, Waite/Hartley/Narungga/Ngadjuri
sa2026), a corpus-wide sizing pass found 89 cases across 19 of 23 pairs where
a non-major class's leader (>=15pt prior vote) departed and the class's own
vote collapsed with them — mean absolute error on those cells 9.6 points
against a corpus-wide 2.05 for the same classes generally. Turning on the
existing-but-unused `screened_slopes(honour_departed=)` lever (now wired into
all six harnesses, see the commit) changed **nothing**, anywhere, including on
Wentworth specifically checked in isolation — `AUSPOL_XGB_PRIMARY` overrides
~99% of primary-share cells, so the slope-based mechanism that lever lives in
rarely fires. `ret_exp` is the feature that actually lives inside the model
doing the overriding.

## Primary-vote RMSE, leave-one-pair-out over 23 pairs, 13,634 cells

| arm | features | rounds | RMSE | IND-class RMSE |
|---|--:|--:|--:|--:|
| v7c (current best single-model, not shipped either) | 40 | 218 | 3.8370 | 4.804 |
| v7f (v7c + ret_exp) | 41 | 258 | **3.8210** | **4.756** |

Every class held flat or improved except ONP (+0.004) and OTH (+0.022), both
negligible. Do-no-harm check (98 genuine-collapse cells, high prior vote, low
salience) actually improved slightly (8.7 -> 7.9 against an actual 6.5); the
11 genuine-emergence cells (high salience) also improved slightly (22.0 ->
23.0 against an actual 28.7).

## Seat log loss, wiring v7f's OOF predictions into the five affected harnesses

`output/xgb-primary-v7f-oof-predictions.csv` built from the cached
`pred_v7f` column (no re-fit needed) and read via
`AUSPOL_XGB_PRIMARY_OOF`. One seed, published defaults otherwise.

| pair | n | baseline | v7f | move |
|---|--:|--:|--:|--:|
| fed2007 | 149 | 0.3090 | 0.3110 | +0.0020 |
| fed2010 | 147 | 0.2691 | 0.2657 | -0.0034 |
| fed2013 | 150 | 0.2683 | 0.2647 | -0.0036 |
| fed2016 | 147 | 0.3328 | 0.3286 | -0.0042 |
| fed2019 | 143 | 0.1868 | 0.1881 | +0.0013 |
| **fed2022** | 150 | 0.2928 | 0.2874 | **-0.0054** |
| fed2025 | 150 | 0.2627 | 0.2661 | +0.0034 |
| **federal pooled** | **1036** | **0.2749** | **0.2735** | **-0.0014** |
| nsw2023 | 88 | 0.2511 | 0.2625 | **+0.0114** |
| sa2026 | 47 | 0.4344 | 0.4206 | -0.0138 |
| qld2024 | 93 | 0.3096 | 0.3016 | -0.0080 |
| vic2022 | 78 | 0.2392 | 0.2336 | -0.0056 |
| **all 5, pooled (1342)** | | **0.2793** | **0.2775** | **-0.0017** |

fed2022 (the actual teal wave this was built for) improved. Every jurisdiction
improved except NSW, and NSW's regression is diffuse — no single broken seat
(checked Wakehurst specifically: 0.116 -> 0.114, essentially unchanged) — a
handful of seats moving a little, not one blowup.

## The seats this was actually aimed at

| pair | seat | actual | baseline p(win) | v7f p(win) | move |
|---|---|---|--:|--:|--:|
| sa2026 | Waite | ALP | 0.330 | 0.464 | **+0.134** |
| fed2022 | Curtin | IND | 0.172 | 0.385 | **+0.213** |
| sa2026 | Ngadjuri | ONP | 0.154 | 0.276 | **+0.122** |
| sa2026 | Hartley | ALP | 0.331 | 0.381 | +0.050 |
| fed2022 | Tangney | ALP | 0.015 | 0.016 | flat |
| nsw2023 | Wakehurst | IND | 0.116 | 0.114 | flat |
| nsw2023 | Heathcote | ALP | 0.302 | 0.293 | flat |
| fed2022 | Pearce | ALP | 0.302 | 0.285 | -0.017 |
| nsw2023 | Parramatta | ALP | 0.178 | 0.146 | -0.032 |
| sa2026 | Narungga | ONP | 0.032 | 0.023 | -0.009 |

Hits exactly the seats matching its mechanism (a departed independent whose
vote reverts). No effect on Tangney/Wakehurst/Heathcote, which are a different
mechanism (see below). Small cost on Pearce/Parramatta/Narungga.

## Verdict: directionally real, not yet decisive

-0.0017 pooled over 1342 seat-elections is a genuine, positive, well-targeted
effect, but it is close to this repo's own documented single-seed noise floor
(a seed can move one pair by up to ~0.01). **Not shipped** —
`AUSPOL_XGB_PRIMARY_OOF` still defaults to v6's file. Before wiring
`output/xgb-primary-v7f-oof-predictions.csv` into `published_flags.R`:
seed-average (3-5 seeds, the compiled simulator makes this minutes) and
re-check the pooled number holds.

## What this does NOT fix (found working the same table)

**Tangney, Heathcote, and likely Pearce and Hartley are a different
mechanism entirely: a sitting incumbent RECONTESTS and still loses by more
than the statewide swing.** Lee Evans (Heathcote) and Ben Morton (Tangney)
both ran again; nobody departed. Checked the actual statewide primary swing:
fed2019->fed2022 ALP moved only -0.8 nationally while Tangney swung far more;
nsw2019->nsw2023 ALP moved +3.7 statewide while Heathcote swung +9.4. This is
the state/regional-deviation problem `v7i`/`v7j` were built for
(`state_poll_dev`, `state_elec_dev` etc., fed2022 missed Hasluck by 11.4 and
Tangney by 12.9 on this exact axis) — v7i lost pooled RMSE (3.9297 vs v7c's
3.8740) because the state-deviation columns are constant 0/999 for every
non-federal cell and the tree used them as a jurisdiction label rather than a
deviation signal. v7j (jurisdiction-split models, so state-election cells
never see the federal-only block) was written to fix exactly that and, like
`ret_exp`, **has never been run to a result.** Same gap, same next step.

**Wakehurst is the genuine wave/emergence pattern** — a fresh independent
with zero personal-vote history, benefiting from a retiring long-serving
member (Hazzard). This is `docs/reviews/wave-term-blocked-2026-09-07.md`'s
territory: the Google Trends anchor (Albanese) is not comparable across
elections and the weekly series were never cached, so an absolute salience
bar cannot be built from what is on disk. Blocked, not attempted here.

**Narungga (Fraser Ellis's collapse) looks idiosyncratic** — a specific,
non-recurring campaign event, not a structural gap. Not pursued.

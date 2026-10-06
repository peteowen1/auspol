# Pre-registration: gated breakout mixture (2026-10-06)

Committed BEFORE the arm runs, with `scripts/score_arm.R` (SA3, SA5, SA6).

## Why

About 20 of the worst 30 primary rows on the published model are first-time breakouts (Steggall,
Sharkie 2016, Butler, Daniel, Habermann). A mean shift cannot fix them; a mixture can give them a
real chance (`docs/reviews/breakout-risk-design-2026-10-05.md`). Built 2026-10-06 (`R/breakout_mix.R`,
`AUSPOL_BREAKOUT_MIX`, off; byte-identical off on one pair per harness; cpp engine +3.5% time).

The UNGATED dry run on the real simulator (2,000 draws, five pairs) was mostly negative: the 30 seats
a non-major won improved (0.941 -> 0.842) but the 565 a major won leaked probability (Churchlands
0.98 -> 0.81, Bean 0.94 -> 0.85); log loss worse in fed2016, fed2019, fed2022, wa2025, better in
nsw2023 (0.2199 -> 0.2079). Thousands of small p values add up in safe seats. Pete chose (2026-10-06)
to test a GATED version.

## The change (one arm)

`AUSPOL_BREAKOUT_MIX=1`, `AUSPOL_BREAKOUT_MIX_MIN_P=0.2`: only cells whose time-forward, calibrated
breakout probability is at least 0.2 carry the mixture. Dry-run p for named cases: Wakehurst
nsw2023 0.50 (capped), Warringah fed2019 0.21 (kept), Mayo fed2016 0.03 and Goldstein fed2022 0.03
(dropped by the gate). The threshold is fixed here and not tuned after the run.

## How it runs

From stage 6 (`AUSPOL_REBUILD_FROM=6`): the mixture acts in the seat simulation only; base_pred and
the as-at models (stages 1-5) are unchanged by construction. Baseline: the shipped configuration,
`output/snapshots/20261006-0054-ff0a13d-from1`. Score:
`Rscript scripts/score_arm.R <baseline> <arm> 0.5 all`.

## Criteria

1. PRIMARY (SA6): seat-winner log loss over all 22 elections must fall by more than 1 SE (SE clustered
   on election). Dry run of the scorer on a known comparison: -0.0005, SE 0.0007, "within 1 SE".
2. GUARD (SA3): the AEF-7 ledger must not rise by more than 1 SE.
3. DISQUALIFIER: any single election's seat-winner log loss rising by more than 0.010 (the leak the
   ungated version showed: wa2025 +0.014).

Ship (`AUSPOL_BREAKOUT_MIX=1`, `MIN_P=0.2` in `published_flags.R` and as defaults) only if 1 passes, 2
holds and 3 does not fire; otherwise off, and the result goes to Pete. Named in advance: the gate
drops Mayo 2016 and Goldstein 2022 (p 0.03), so they cannot improve; the arm is judged on the whole.

## Note (2026-10-06, before any result was read)

The first stage-6 run stopped in the fed and wa harnesses: `breakout_p_for()` stopped on pairs too
early to have an as-at model (fed2007, wa2001). Fixed: a PAST election with no as-at rows gets no p and
the mixture is off for that pair (logged `BO0!`/`BO1!`); the live election still stops. No criterion
changed. The fed and wa harnesses are rerun at stage 6 with the fix; the other four ran with the arm on.

## Result (2026-10-06, `output/snapshots/20261006-1216-cbbad56-from6`) -- REFUSED

| Criterion | Result | Verdict |
|---|---|---|
| 1 PRIMARY (SA6, 22 elections) | 0.2898 -> 0.2917, change +0.0018, SE 0.0018 | FAIL (worse, within 1 SE) |
| 2 GUARD ledger | 0.2809 -> 0.2856 (SE 0.0053) | holds |
| 3 DISQUALIFIER (any election > +0.010) | fed2025 +0.0232, vic2014 +0.0121 | FIRES |

Helped where it should: nsw2023 -0.0130 (Wakehurst), fed2019 -0.0042 (Warringah). Hurt more where the
gate still let flagged non-breakouts through: fed2025 (several Voices-style independents at p >= 0.2
who did not win), vic2014, vic2022 +0.0059, wa2025 +0.0044. The classifier's top band is over-confident
(0.44 predicted vs 0.375 observed, n=16), and the signals do not separate breakouts from look-alikes
well enough for a mixture to pay. The switch stays off; the code (classifier, distribution, simulator
plumbing, gate) stays for when the inputs improve. The lever is better pre-election signals, not the
mixture: build the state Trends series already on disk, recode council mayors (council-chosen mayors
are FALSE today), add the missing seat-poll primaries (Mayo 2016, Wakehurst, Warringah 2019).

# Pre-registration: training weights for older elections (2026-10-13)

Design and decisions: `plans/weighting-design-2026-10-13.md` (Pete: training decay + completeness; scoring per
person; AEF-7 primary, 2010+ second, pre-2010 reported; single-election harms explained then Pete decides).

## Why

vic2010 as a training row for the as-at and production vote-share models made later elections worse: per person,
AEF-7 +0.0043 (beyond 1 SE), 2010+ +0.0070 (14 of 18 worse); every pre-2010 election byte-identical, so the test is
clean (`deciding-runs/pooled-backtest-bundle-skip-vic2010.csv` vs `deciding-runs/bundle-20261013/`).

## What the data says about the cause (measured before writing this)

- **Not feature completeness.** Share of non-missing features: vic2010 0.807, vic2014 0.798, vic2018 0.804; salience
  is not an input to these models. A completeness weight cannot separate vic2010 from its neighbours. It stays in as
  Pete's arm, reported honestly.
- **Election-level misses.** base_pred residual by class (actual minus base_pred): vic2010 GRN -4.37, LNP +3.05;
  vic2014 GRN -2.22, LNP +2.15; vic2018 ALP +2.15, LNP -2.98. The model learns each training election's statewide
  miss as if it were a pattern; the next election's mood differs (vic2018 is the opposite of vic2010). The statewide
  level already comes from the polls (level blend), so the vote-share model should learn within-election structure.

## Arms (all with vic2010 IN training, i.e. AUSPOL_TRAIN_SKIP_PAIRS="")

| arm | switches | idea |
|---|---|---|
| P0 | none (vic2010 in, unweighted) | the measured harm, re-run as the arms' control |
| P1 | AUSPOL_TRAIN_DECAY_H=8, AUSPOL_TRAIN_COMPLETENESS=1 | Pete's choice: decay (8-year half-life) x completeness |
| P2 | AUSPOL_TRAIN_DECAY_H=8 | decay only |
| P3 | AUSPOL_TRAIN_DEMEAN=1 | subtract each training election's mean residual per party class from the label |
| P4 | AUSPOL_TRAIN_DEMEAN=1, AUSPOL_TRAIN_DECAY_H=8 | both |

Half-life fixed at 8 years (prior, not fitted on these results); if a decay arm wins, fitting h time-forward is the
next step.

## Criterion (fixed before running)

Each arm is a rebuild from stage 4 (as-at and production vote-share models refitted, harnesses rerun), compared with
`scripts/compare_rebuild_scores.R` against the PUBLISHED configuration (vic2010 skipped, 18:20 publish,
`deciding-runs/pooled-backtest-bundle-trainskip.csv`):

1. Primary: per-person AEF-7 change. An arm qualifies if it is no worse than the published configuration (change <=
   +1 SE); the best qualifying arm by AEF-7 per person wins.
2. Second view: per-person 2010+; reported with better/worse counts; an arm worse beyond 1 SE there goes to Pete.
3. Any single election worse by more than 0.02: explained (cause traced) before Pete decides.
4. If no arm qualifies, vic2010 stays scored-not-trained (published) and the finding is reported.

Unacceptable regardless of score: an arm that changes any pre-2010 election (they cannot see vic2010; a change there
means the switch leaked into something else).

## Amendment 2026-10-13 (added before any arm's result was read; the clauses above are unedited)

The deciding weight in criterion 1 changes from per person to each election x sqrt(formal votes) (Pete,
`plans/weighting-design-2026-10-13.md` revision). Per person is still printed and reported beside it.

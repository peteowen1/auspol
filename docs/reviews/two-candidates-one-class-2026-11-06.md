# Two candidates of one class run as one: the walkthrough (6 Nov 2026)

Prepared for the model-design walk with Pete (CLAUDE.md: walk real rows before building). Read-only; nothing rerun.
Numbers from the 6 Nov published rebuild, stage-6 (shipped) files only (`output/backtest-*-{sharedetail,allprobs}-*gc3f93ff.csv`,
`xgb_primary_on = 1`); win probabilities sum to 1.000 in every seat below.

## What the model does

The seat simulation works on CLASSES (ALP, LNP, GRN, IND, ONP, OTH, OTH_RIGHT), one runner per class. When two independents
stand, their predicted shares are one IND total, and the preference count refuses duplicate names (`R/preferences.R:75`,
"Aggregate to one entry per party before distributing"). So two independents on 14% and 12% contest the seat as one candidate
on 26%. The "multiplicity" work (`plans/prereg-survivor-multiplicity.md`) conditioned preference FLOWS on candidate counts and was
refused on coverage; splitting first preferences between same-class candidates has never been built or tested.

## Four seats

| Seat | Independents (actual %) | IND predicted % (actual total) | IND win prob | Winner (%) |
|---|---|---|---|---|
| Morphett, sa2018 | McFetridge 14.2 (sitting Liberal, lost preselection), Jones 12.1 (SA-Best) | 33.0 (26.3) | 0.806 | Patterson, Liberal (41.4) |
| Waite, sa2022 | Duluk 19.7 (sitting Liberal, expelled), Holmes-Ross 14.6 | 30.2 (34.2) | 0.734 | Hutchesson, Labor (26.6) |
| Monash, fed2025 | Leonard 17.1, Broadbent 10.2 (sitting Liberal, lost preselection) | 23.9 (27.3) | 0.635 | Aldred, Liberal (31.8) |
| Calwell, fed2025 | Moore 12.0, Youhana 10.8, Moslih 6.9 | 12.5 (30.2) | 0.032 | Abdo, Labor (30.7) |

- **Waite is the clean case.** The class total was predicted well (30.2 against 34.2) and still produced the wrong favourite: the
  combined independents beat Labor's 26.6, but no single independent passed 19.7. A one-runner model must call it IND.
- **Morphett** adds a second error: the IND total was over-called (33.0 against 26.3). Split between two candidates, neither could win.
- **Monash** is the preference version. Every class level was close (LNP 32.2 against 31.8, IND 23.9 against 27.3), yet one IND
  runner on 23.9 reaches the final two and wins 64% on Labor and Green preferences. The real top independent (Leonard, 17.1) came
  third behind Labor (20.3) and was excluded before the final count.
- **Calwell** goes the other way: the IND total was badly under-called (12.5 against 30.2), so the model was right for the
  wrong reason. A split would leave it right.
- UNVERIFIED (from memory, not checked against a pre-election source): the notes in brackets on McFetridge, Duluk and Broadbent.
  `historic_elected` in candidacies.csv does mark all three as sitting members.
- Three of the four involve a sitting Liberal running as an independent, which is its own question (the vote a defector carries;
  `plans/prereg-defector-pooling-2026-09-09.md`).

## Size

84 of 3,680 seat-elections in `output/candidacies.csv` have two or more candidates of one minor class (IND, OTH, OTH_RIGHT)
on 5% or more; the class won 14 of them.

## A design to walk through (not built)

1. Split each class's simulated share between its candidates by their own predicted shares. The minor-candidate model already
   predicts each one (`output/minor-candidate-oof-resid-v2.csv`, `scripts/fit_minor_candidates.R`), time-forward.
2. Run them as separate runners in the count (IND_a, IND_b), with preferences between same-class candidates from the
   transfer data (independent to independent is a measurable flow).
3. Score on the 84 seats as the primary target, all 35 elections as the do-no-harm guard (prereg first).

### What the split would hand each candidate (added 6 Nov, from `output/minor-candidate-oof-resid-v2.csv`)

Per-candidate prediction (`pred_xgb`, %) against actual, and the class total split in proportion to those predictions:

| Seat | Candidate | Per-candidate pred | Split of class total | Actual |
|---|---|---|---|---|
| Morphett 2018 | McFetridge (sitting member) | 26.0 | 27.8 | 14.2 |
| | Jones | 4.8 | 5.2 | 12.1 |
| Waite 2022 | Duluk (sitting member) | 24.8 | 25.7 | 19.7 |
| | Holmes-Ross | 4.3 | 4.5 | 14.6 |
| Monash 2025 | Broadbent (sitting member) | 28.3 | 18.8 | 10.2 |
| | Leonard | 7.6 | 5.1 | 17.1 |
| Calwell 2025 | Moore, Youhana, Moslih, Ragupathy | 3.6-3.7 each | about 3.1 each | 12.0, 10.8, 6.9, 0.6 |

The per-candidate model gives the sitting member nearly all of it and every newcomer independent the generic 4-8%. In all
three two-candidate seats the newcomer got 12-17% and in Monash beat the sitting member. So the split stops two candidates
being added together, but it leans the wrong way between them: the newcomer surge is what the per-candidate model misses.

Questions for Pete: is a per-candidate split the right shape, or should the second independent be a separate class? How much do
we trust the minor-candidate model's split between two independents (its own RMSE ~4-9 points per candidate)?

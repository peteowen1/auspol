# Review of decision rules (2026-10-18)

Asked by Pete: "review all the rules and make sure none seem silly like that one". Read-only review of
`docs/PRE-REGISTRATION-RULES.md`, the rules sections of `CLAUDE.md`, and refusal/decision clauses across
`docs/plans/prereg-*.md` (208 files; clause types found by grep and the clause text read, not every file read
in full). Line numbers are as of this date.

Verdict key: SOUND = keep. QUESTIONABLE = defensible worry, but the test is uncalibrated or a proxy. SILLY = refuses for the wrong reason.

| Rule | Where | Verdict | Why | Replacement |
|---|---|---|---|---|
| "More than half the primary gain from one election -> refused" | Still live in prereg-composition-spread-2026-10-17.md:74, prereg-growth-ratio-features-2026-10-18.md:51, prereg-error-distribution-2026-10-17.md:62 (fired at :122), prereg-lib-nat-two-candidates-2026-10-16.md:77, prereg-leader-approval-miss-2026-10-12.md:72 | SILLY | The rule Pete rejected was replaced only in PRE-REGISTRATION-RULES.md:155-171; five recent preregs still carry it. It refused arm CE because qld2017 held 0.65 of the gain. | Leave-one-election-out (better by >1 SE with each dropped) plus no election materially worse; report shares as information. |
| "More than half the primary gain from two seats -> disqualifier" | prereg-departed-sitting-split-2026-10-07.md:50, prereg-departed-successor-flag-2026-10-07.md:121 (fired at :205, 82% from New England and Lyne; Pete overrode) | SILLY | Same flaw at seat level. A fix aimed at a handful of seats concentrates its gain in them by design, and it contradicts the "scope the metric to the change" rule (PRE-REGISTRATION-RULES.md:41-69). | Leave-two-seats-out check (gain keeps its sign) plus the do-no-harm guard on all other seats. |
| Directional side-effect refusal ("moves the same way in almost every row", the One Nation lesson) | PRE-REGISTRATION-RULES.md:25-28; prereg-departed-rate-refit-2026-10-03.md:343-346; prereg-defector-two-rate-2026-09-09.md:62 | QUESTIONABLE | A correct fix for a systematic bias moves most rows one way. The refit plan already softens it ("unless realised outcomes justify"); the rules file does not. | Report the direction count and score it against realised outcomes in those rows; refuse only if outcomes contradict the direction. |
| Absolute "any single election worse by more than X" | prereg-breakout-mix-gated-2026-10-06.md:37 (0.010), prereg-nomination-zero-2026-10-03.md:24 (0.011), prereg-level-recent-blend-2026-10-10.md:37 (0.02) | QUESTIONABLE | Fixed numbers, not scaled to the election's seat count or SE, and different in each plan. A 40-seat election moves more on noise than a 150-seat one. The intent (no election materially worse) is right. | One shared definition, e.g. worse by more than 2 SE of that election's own paired seat difference; same constant everywhere. |
| Catastrophic-break floor (jurisdiction +0.02, pooled +0.01) | prereg-defector-pooling-2026-09-09.md:104 (SA +0.0364 breached it, :181), prereg-dispersion-slope-2026-09-09.md:120, prereg-fit-conditional-slopes-2026-09-09.md:106, prereg-defector-two-rate-2026-09-09.md:55 | QUESTIONABLE | Hard cliff on a noisy quantity, same constant for fed (151 seats) and SA (few seats). Defector-pooling was refused on one SA breach. Conflicts with the shrinkage-not-cliffs rule (CLAUDE.md:264-296). | Express per jurisdiction in SE; keep the pooled bar. |
| 10-metric panel "at least 6 better and at most 3 worse" | prereg-defector-pooling-2026-09-09.md:100-102 | QUESTIONABLE | The ten metrics are heavily correlated (pooled log loss, Brier, RMSE, six per-jurisdiction log losses), so counting them as votes is not a test of anything. Also sidesteps the log-loss-first order. | Drop the vote count; log loss primary, the rest reported. |
| Ship bar varies: 2 SE vs 1 SE | 2 SE: prereg-calibration.md:65, prereg-flow-uncertainty-v2.md:63, prereg-independent-emergence-v2.md:57, prereg-ind-seat-poll-2026-10-06.md:27 (2 SE and 20%). 1 SE: prereg-composition-spread-2026-10-17.md:58, prereg-breakout-mix-gated-2026-10-06.md:34 | QUESTIONABLE | No stated rule for which applies. 2 SE on a small cell set (86 IND cells, achieved 1.2 SE) can only refuse; 1 SE one-sided passes noise about 16% of the time. The MDE rule (PRE-REGISTRATION-RULES.md:95-107) is not applied to the bar itself. | State one default ship bar (suggest >1 SE on the all-seat metric plus leave-one-out), and require the plan to compute its MDE; use 2 SE only where stated why. |
| K3 "dropping any single election must leave the result above 2 SE" | prereg-calibration.md:81-83 | QUESTIONABLE | Stricter than the new leave-one-election-out bar (>1 SE) and loses power at 10 clusters. Old plan, low priority. | Align to the new rule. |
| G3 "a confirmation resting on one SA election is refused" | prereg-gap-decay.md:98 | QUESTIONABLE | Two elections; a sign disagreement is better reported as inconclusive than refused. Old plan, low priority. | Report as split/inconclusive. |
| Placebo matches -> refuse | prereg-education-residual-correction-2026-09-15.md:156, prereg-class-concentration-v2-2026-09-15.md:116 | SOUND | Tests the real worry (feature is a proxy for something else) with a control. |
| Coef >= 2.2 SE and sign consistent in 8 of 12 cycle-pairs, no accuracy cost | prereg-cross-party-swing.md:50-58 | SOUND | Sized to the data; guard against paying accuracy for a seat. |
| Floor-seat clause: over half the gain from seats at the 1e-6 floor goes to Pete as a split | prereg-composition-spread-2026-10-17.md:75, prereg-error-distribution-2026-10-17.md:63 | SOUND | Not a refusal; reports gain with and without. Tests the clamp artefact. |
| Leverage clause (drop the 3 high-gap rows; sign flip means refuse as evidence) | prereg-departed-rate-refit-2026-10-03.md:347-350 | SOUND | A leave-out test of the actual worry (three seats, not a rate). Note it is itself a seat-level leave-out, which the two-seat clause above wrongly forbids. |
| Leakage and "run did not apply" clauses | prereg-departed-rate-refit-2026-10-03.md:351-355 | SOUND | Guard against invalid evidence, not a performance threshold. |
| Name what makes a WIN unacceptable, in advance | PRE-REGISTRATION-RULES.md:14-38 | SOUND | Real fix for criteria invented after results. Each listed item must itself pass these tests (several above do not). |
| Scope the metric to the change; size by n/k | PRE-REGISTRATION-RULES.md:41-69 | SOUND | Correct, well evidenced. |
| Metric order: log loss, Brier, reliability; slope never decisive | PRE-REGISTRATION-RULES.md:71-93 | SOUND | Backed by a measured case (-29% log loss vs -1.7% Brier). |
| MDE of the primary vs expected effect | PRE-REGISTRATION-RULES.md:95-107 | SOUND | Prevents a primary that can only refuse; just not applied everywhere. |
| Dry-run every criterion on known cases | PRE-REGISTRATION-RULES.md:109-137 | SOUND | Tests the instrument. |
| Tolerances in SE, clustered on the independent unit | PRE-REGISTRATION-RULES.md:138-165 | SOUND | The absolute-number clauses above are what breaks it. |
| Amendments visible, original unedited | PRE-REGISTRATION-RULES.md:166-169 | SOUND | Keeps pre-registration honest. |
| Leave-one-election-out plus no election materially worse | PRE-REGISTRATION-RULES.md:155-171 | SOUND | Tests the real worry. Needs a definition of "materially worse" (see absolute-threshold row) or it becomes the next arbitrary cutoff. |
| Shrinkage, never a hard min_n cliff | CLAUDE.md:264-296 | SOUND | Well argued; the cliffs it forbids survive in the floors above. |
| Screen first, ship on all 22; within 1 SE is not clearance | CLAUDE.md quick_arm section | SOUND | States its own limit (tail seats under 1/N invisible). |
| Apply every fix to all six harnesses | CLAUDE.md "A fix to one harness is a fix to ALL" | SOUND | Past incidents back it; screen removes the compute excuse. |
| Negative result only from the strongest version | CLAUDE.md "A NEGATIVE RESULT..." | SOUND | Directly prevents wrong refusals. |
| AEF-7 iterate, 22 ship | CLAUDE.md quick_arm section | SOUND | Held-out 15 guard against tuning to seven. |

## Main finding

The ruling was applied to the rules file only. Five recent preregs still copy the old one-election clause and
two copy the two-seats version. The plan template (or whatever new preregs are copied from) should carry the
new clause so it stops propagating. Not checked: whether any `scripts/` scorer hard-codes the old share test.

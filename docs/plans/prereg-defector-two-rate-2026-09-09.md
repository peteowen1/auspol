# Pre-registration: give losing defectors their OWN rate, not the pooled one

Written 2026-09-09, **before the arm is scored**. Committed before running.
Successor to `prereg-defector-pooling-2026-09-09.md`, which that plan's own
result section required ("adopting it after seeing this result still requires
a fresh criterion, and the plan must say what would make it unacceptable").

## Where this comes from

The pooled arm confirmed the mechanism and refused the magnitude:

- **Confirmed**: losing defectors given a floor instead of zero improved
  exactly the cells targeted — RMSE 10.44 → 8.99 across 12 cells, R1 passed.
- **Refused**: one pooled rate of 0.270 over-predicts losers who collapse.
  South Australia breached the catastrophic floor (+0.0364 vs 0.02), driven
  by cases like Harrison (Unley, 32.0 → 4.4) carrying a floor of 8.6.

This arm keeps each group on its own measured rate: **members 0.282, losers
0.142**.

**The honesty problem, named:** 0.142 is being adopted after 0.270 failed.
The defence is that 0.142 is the losing group's own median, computed and
written into the previous plan **before** that run — not a value tuned to the
failure. It is nonetheless less shrinkage than the pooling analysis
recommended, so the criterion below is stricter than the last one, not looser.

## Why less shrinkage is defensible here

`CLAUDE.md`'s shrinkage rule now records the limit this hit: when the
between-group variance is barely estimable, pooling under-separates groups
that genuinely differ. Wilcoxon p = 0.408 at n=12 is **absence of evidence**,
and the shrinkage weight (0.12) inherited that low power. The rule's own
corrective is an **outcome check** rather than a bigger significance test —
which is exactly what this arm is.

## The arm

`AUSPOL_DEFECT_POOLED=2`: `fit_defector_discount()` returns two rates, fitted
leave-one-election-out over cases with prior vote ≥ 10%; `personal_prior_vote()`
applies the member rate to prior sitting members and the loser rate to the
rest. `0` (off) and `1` (single pooled rate) are unchanged.

## Primary metric

Unchanged from the previous plan so the two arms are comparable: **seat-share
RMSE on the 29 named cells** in `output/defector-cases-all.csv`, paired,
clustered on the pairs they fall in. Bar 2.08 clustered SE.

## Decision rule, fixed now — stricter than last time

**Ship only if ALL FOUR:**

1. Primary improves at ≥ 2.08 clustered SE.
2. Panel: ≥ 6 of 10 better, ≤ 3 worse (as before).
3. **No catastrophic floor breach** — no jurisdiction worse by > 0.02, pooled
   by > 0.01. SA is the specific one that broke last time.
4. **It must beat BOTH baselines**: the status quo (losers get zero) AND the
   pooled 0.270 arm, on the primary. Beating only 0.270 would mean the pooled
   rate was the problem and zero was fine — a different conclusion, and not
   this one.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — the losing cells must carry it.** Same as before. Member cells barely
  move in this arm (their rate is unchanged from shipped), so if the gain is
  in member cells something is miswired.
- **R2 — SA must not breach again.** SA is where the pooled arm broke. If it
  breaches at 0.142 too, the problem is not the magnitude and the whole
  approach of a constant floor is wrong.
- **R3 — it must not be an SA-only fix.** Report the primary with SA excluded.
  If the improvement lives entirely in the jurisdiction that failed last time,
  this is tuning to the failure, which is what the honesty problem above warns
  against. Refuse.
- **R4 — Victoria's published seat totals must not move by more than 2 for
  any class.**

## Dry-run, verdicts recorded in advance

- **Harrison (Unley, 32.0 → 4.4)**: floor falls 8.6 → 4.5, near his actual
  4.4. Should improve markedly. This is the case SA broke on.
- **Key (Dandenong, 29.3 → 1.5)**: floor falls 7.9 → 4.2, still above his
  actual 1.5. Should improve but remain wrong.
- **Cupper (Mildura, 15.2 → 21.3)**: floor falls 4.1 → 2.2, further BELOW her
  actual 21.3. **Should get worse.** Recorded now so it cannot be cited later.
- **Ward (Kiama, member)**: unchanged from shipped, since the member rate does
  not move. If Kiama moves at all, the wiring is wrong.

## Prediction

Expect the losing cells to improve more than at 0.270, because most losers
collapse and only Cupper gains. Expect SA to recover. Expect the primary to
remain short of 2.08 SE — 29 cells with a spread this wide is thin — in which
case the honest outcome is "confirmed but not demonstrable", and the decision
passes to Pete on mechanism rather than on the criterion.

---

## Result, 2026-09-09: REFUSED by the rule, failing criterion 1 by 0.04 SE

| clause | value | bar | verdict |
|---|---:|---:|---|
| **R1 — losing cells carry it** | **−1.278** (10.44 → 9.16); members +0.109 | must not be members | **PASS** |
| criterion 1 — paired primary | mean −0.670, **t = −2.04**, better in 8 of 17 | ≤ −2.08 SE | **FAIL** |
| criterion 2 — panel | **4 better, 1 worse**, 4 unchanged | ≥ 6 better, ≤ 3 worse | **FAIL** |
| criterion 3 — floors | SA +0.0137, pooled −0.00067 | 0.02 / 0.01 | **pass** |
| criterion 4 — beat both baselines | primary −0.670 vs pooled arm's −0.552 | must beat both | **pass** |

**`AUSPOL_DEFECT_POOLED` stays `0`.** The rule refuses and the rule stands.

### Everything directional is favourable

- Pooled seat log loss **0.33647 → 0.33580** — the only arm today to improve it.
- Victoria (live target) **0.2693 → 0.2663**; WA 0.4103 → 0.4071.
- SA recovered from the pooled arm's **+0.0364 to +0.0137**, inside the floor.
- R1 passed cleanly: the 12 losing cells improved 1.28 while the 17 member
  cells stayed flat (+0.11), which is the correct signature — their rate is
  unchanged from shipped, so they should not move.
- The dry-run's named cases behaved as recorded: Dandenong's floor fell
  7.91 → 4.16, Harrison's 8.6 → 4.5 against an actual 4.4.

### Why it still fails, stated plainly

**t = −2.04 against a bar of 2.08.** Not a near miss to be waved through — the
bar was set before the run precisely so a result of this size could not be
argued into shipping. 29 cells with a spread this wide cannot resolve an
effect this size, which the plan predicted in its own final paragraph
("expect the primary to remain short of 2.08 SE").

Criterion 2 fails differently and more informatively: only **1 metric got
worse**, but 4 of the 9 landed inside the ±0.0005 "unchanged" band and so did
not count as improvements. A 29-cell change cannot move election-wide
aggregates enough to register — which is exactly why the primary was scoped
to the named cells, and why the panel is a guard rather than evidence.

### What would legitimately settle it

**Not** a rerun at more sims to nudge t over the bar — the criterion did not
pre-specify that, and doing it now would be choosing the answer. A clean
confirmatory arm would need to be pre-registered separately, and the honest
framing for it is a **power** question, not a fresh hypothesis: the mechanism
is confirmed twice over (R1 passed in both the pooled and two-rate arms), the
magnitude is now plausible, and what is missing is a corpus large enough to
demonstrate it at 2 SE.

Given that, the reasonable options are (a) leave it refused and revisit when
the corpus grows, or (b) Pete adopts it on mechanism, explicitly and on the
record, accepting that the criterion did not clear — which is a legitimate
call for a change whose every directional indicator is positive and whose
worst jurisdiction effect is inside the floor, but it must be recorded as a
judgement rather than a measurement.

# Pre-registration rules

Moved out of `CLAUDE.md` on 2026-09-17 (hub-slimming pass, `claude-md-improver`
skill) — self-contained content on one topic, ~13KB, that a session not
currently designing an experiment doesn't need loaded every turn. Nothing
below is edited from the original; `CLAUDE.md` keeps a one-line pointer per
rule. See it for the still-active headline list; this file is where the full
evidence lives.

## Constants

Every one is inventoried in `docs/CONSTANTS.md` with whether it can come from
data. **A constant missing from that file is a bug in that file.** Priors that
can be estimated are chosen by held-out error over a pre-registered grid —
write the grid, criterion and decision rule to `docs/plans/` and **commit it
before running**, so the criterion cannot be chosen to fit the answer.

**A decision rule must also say what would make an apparent WIN unacceptable.**
Committing the criterion first is not enough on its own, and this has now gone
wrong twice in three experiments:

- the inclusion floor (2026-08-19): floor 15 cleared the pre-registered bar
  three times over and was refused on an anchor written after the result.
- One Nation seat uncertainty (2026-08-19): every relevant criterion passed or
  was mis-specified, and the change was refused on a directional side effect —
  the party's win probability rose in 71 of 87 seats and fell in 1 — that no
  criterion covered.

Both refusals look right on the merits and both were reported honestly. That is
not the point: in each case the real decision came from something invented after
seeing the results, which is what pre-registration exists to prevent. The lesson
was written down after the first and **not applied to the second**, so it is
here rather than in a plan file.

So every plan needs a refusal section naming, in advance: the directional side
effects that would disqualify a winner, and what the criterion cannot see. If
that section is hard to write, the criterion is probably measuring the wrong
thing — which was true both times.

**Scope the metric to the change. A targeted fix is validated on its targets;
only a general change is validated election-wide.**

Name the broken cases BEFORE proposing the fix, make those the primary
criterion, and demote the election-wide metric to a do-no-harm guard. Reverse
that and a real fix cannot be seen:

- The salience gate moved the six fed2022 emergences by **18.29 points**.
  Diluted across all 368 rows that is **0.85** — a large fix wearing the
  disguise of a marginal one, because 6 cases in 151 seats barely move an
  aggregate. The pre-registration made the aggregate primary and the emergences
  secondary, which is backwards.
- Its precision criterion then failed for the same reason: an election-wide
  count of "false firings" for a change aimed at six seats scored 14 candidates
  polling 15–26% as errors, when raising them was correct.

So, before writing a criterion, ask **what question the change answers**:

| the change is… | primary metric | secondary |
|---|---|---|
| targeted (these seats/candidates are wrong) | those cases, named in advance | election-wide, as a do-no-harm guard |
| general (a decay, a variance form, a flow rate) | election-wide | slices that could hide a reversal |

The window follows the same logic. A fix for emergence is tested on elections
that CONTAIN emergences — fed2025 has none, so it can only ever be a negative
control there, never evidence the fix works.

And size it: a change affecting `k` of `n` seats needs roughly `n/k` times the
effect to clear the same aggregate bar. At 6 of 151 that is a factor of 25, so
an aggregate criterion will almost always refuse a targeted fix that works.

**The metric order for seat probabilities is LOG LOSS, then Brier, then
reliability by band. The calibration slope is reported and never decisive.**

Log loss is the only one that matches the failure this repo actually has. A seat
called 0.9997 and lost costs ~8 under log loss and ~1.0 under Brier — the same
as a seat called 0.90 and lost. Brier CAPS exactly the error that keeps hurting
us. Measured on the same change, same data, 886 federal seat-elections:

| metric | base → level_sd | move |
|---|---|---|
| log loss | 0.5398 → 0.3839 | **−29%** |
| Brier | 0.0922 → 0.0906 | −1.7% |
| calibration slope | — | ~0 |

One change; log loss saw it, Brier barely registered it, the slope missed it
entirely, because the gain sat in the overconfident tail. Both of today's bad
refusals would have been avoided by this ordering alone.

Report reliability with **tail-focused bands** (0.9, 0.95, 0.99, 0.999) and
their COUNTS, never equal-width bins — 60% of seats land in one bucket and the
only region where decisions live disappears. An empty bin is not evidence.
`scripts/compare_arms.R` does this, plus ECE and the per-subset breakdown.

**And size the PRIMARY metric's own noise against the expected effect. If its
MDE exceeds any plausible effect, it cannot be the primary.**

Chosen twice now for what a metric appears to measure rather than for whether it
can measure it. The level-dependent variance arm (2026-08-27) made the
calibration slope primary: across 17 pairs that statistic has sd 0.562, giving
an MDE of 0.419 — larger than almost any real effect on it. Brier's sd is
0.0141, MDE 0.0089, and Brier improved in 10 of 17 pairs at p = 0.028 while
calibration showed nothing. The change was refused on the metric that could not
see it, and the significant result sat in the guard.

So compute both numbers when writing the criterion: the metric's spread across
the units you will cluster on, and the effect you expect. A primary whose MDE
is larger than the effect is a criterion that can only ever refuse.

**Dry-run every criterion on cases whose answer you already know, BEFORE
committing the pre-registration.** Same rule as "prove a check fails on a
deliberately broken input", applied to the criterion instead of the code. A
criterion is a measuring instrument and gets tested like one.

C2 of `prereg-salience-emergence-gate.md` (2026-08-27) failed this twice over,
and both faults were visible without running anything:

- It counted a "false positive" as **any flagged candidate who did not WIN**,
  while the model it tested predicts **vote share**. So Nicolette Boele rising
  from 0% to 20.9% in Bradfield scored as a mistake — the very behaviour wanted,
  and she won the seat at the next election. 14 of the 73 "false positives"
  polled 15–26% against a base prediction of 6.9%, and salience cut their error
  by 5.1 points.
- It said "the gate fires" about a **continuous** coefficient with no trigger,
  so the threshold had to be invented at scoring time. The value used meant
  "salience moved the prediction by 1.25 points", which is noise. At any bar a
  forecast would notice, the same model passes.

Ten seconds against two known candidates would have caught both. So: **name two
or three cases whose verdict you already know, state what the criterion should
say about each, and check that it does.** If it cannot be dry-run because the
quantity is undefined — as "fires" was — that is the finding, and the criterion
is not ready to commit.

The cost is not just the wasted test. A criterion that fails for the wrong
reason forces a real choice between shipping on a rewritten rule and withholding
a change that works, and both are bad. Neither is recoverable after the fact,
which is why this belongs before the commit.

**And write every tolerance in standard errors, or compute its size in standard
errors when you write it.** Two criteria have now failed the same way, four days
apart, and both failures were computable from `n` before the experiment ran:

- the reliability-bin rule (2026-08-19): "no bin off by more than 15 points",
  set without checking that a decile could hold five seats, where one seat moves
  the bin by 20.
- the first-preference widening rule (2026-08-19): "within 5 points of nominal"
  at the 50%, 80% and 95% levels. Copied from a 95% rule where 5 points is 2.6
  SE; at the 50% level the same 5 points is **1.16 SE**, so it rejected a
  perfectly calibrated interval about a quarter of the time. Both candidates
  were refused by a test with no power to accept either.

**Cluster the standard error on the right unit.** In that case the 139
party-cycles were 33 independent cycles, because first preferences sum to 100
within a cycle — treating them as 139 understates the SE. Ask what the
independent observation actually is before dividing by `sqrt(n)`.

A criterion changed after seeing results is worth almost nothing, so the only
defence is to get the size right in advance. Where an amendment is unavoidable,
make it a **visible addition with the original clause left unedited**, and check
whether it favours the answer found later — if it does, it is not an amendment,
it is a rationalisation. The one amendment made so far picked the value
pre-registered *first*, which is the only reason it was allowed to stand.

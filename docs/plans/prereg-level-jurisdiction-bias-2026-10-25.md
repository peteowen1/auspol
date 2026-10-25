# Pre-registration: a time-forward jurisdiction-by-class bias correction to the statewide level

Written 2026-10-25, before any arm is built or run. Queue items: `docs/NEXT-STEPS.md`, "WA's Coalition
over-call is a statewide LEVEL miss" (finding 17 Oct, never acted on) and "MEASURED, PARKED per-class level
bias" (Greens over-predicted in 23 of 35 elections). Rules: `docs/PRE-REGISTRATION-RULES.md`, the shrinkage
rule and the leakage rules in `CLAUDE.md`.

## The question

The shipped day-before level (trend blended toward recent polls, `AUSPOL_LEVEL_RECENT=decay`, 20-day
half-life, `R/level_recent.R::level_recent_apply`) feeds every seat's primary. The 17 Oct finding: mean
Coalition primary error (ours minus actual, one-candidate seats) NT +3.61 (SE 1.08), WA +2.46 (0.34),
Qld +0.98, NSW +0.45, fed +0.05, SA -0.82, Vic -0.87; WA positive in 6 of 7 elections. If each jurisdiction's
polls miss each class in a persistent direction, the past misses predict the next one.

Does subtracting each jurisdiction's shrunk past level miss, per class, predict the primaries better?

What is already known, so it is not rediscovered: the POOLED per-class correction (no jurisdiction term) was
measured 17 Oct and lost (1.402 -> 1.426); Greens alone helped slightly (prereg-poll-level-centring arm C,
never run). This prereg adds the jurisdiction term, with partial pooling.

## The correction (fixed now)

For target election `e` in jurisdiction `j` (region: fed, nsw, nt, qld, sa, vic, wa) and class `c`:

- **Past misses.** `x_{e'} = level_ref(e', c) - actual(e', c)` for every election `e'` whose polling day is
  strictly before `e`'s (asserted in code), where `level_ref` is the shipped level as the screen recomputes
  it (`level_recent_apply`, decay arm at the shipped half-life; its k is itself fitted on elections before
  `e'`). Actual is the statewide share in `output/level-recent.csv`.
- **Primary spec, "EB toward zero".** `n_j` = past elections in `j`, `m_j` their mean miss. Within-jurisdiction
  variance `s^2` pooled over jurisdictions with `n_j >= 2` (fallback: variance of all past misses; fewer than
  2 past misses anywhere: no correction). Between-jurisdiction variance around zero
  `tau^2 = max(0, mean_j(m_j^2) - mean_j(s^2 / n_j))`. Weight `w_j = tau^2 / (tau^2 + s^2 / n_j)`;
  correction `corr = w_j * m_j`; `n_j = 0` gives 0. No `min_n`: a thin jurisdiction is shrunk, not dropped.
  Every quantity is refitted at every target from that target's past only.
- **Corrected level** = `level_ref - corr` for the corrected classes. The sum of those moves is taken from
  (or given to) the uncorrected classes pro rata to their reference level, so the level sums to 100.

Sensitivity specs, reported for every arm but **never decisive** (they cannot rescue a refused primary):
- **EB toward pooled**: shrink toward the past mean over all jurisdictions `mu`,
  `tau^2 = max(0, var_j(m_j) - mean_j(s^2/n_j))`, `corr = mu + w_j (m_j - mu)` (`n_j = 0` gives `mu`).
- **Fixed k = 3**: `corr = n_j / (n_j + 3) * m_j` (the `AUSPOL_CONSERVE_SHRINK_K` form).

## Arms (each against the shipped level, which wins ties)

1. **LNP only.** 2. **GRN only.** 3. **ALL** (ALP, LNP and GRN each corrected; OTH absorbs).
Reported, not decisive: ALP only.

## Screen and criterion

Instrument: `scripts/screen_level_share.R` (copied to the scratchpad and extended; the repo file is not
edited), baseline `output/published-predictions.csv`, reference arm the shipped `decay:20`. Every election in
both the level table and the predictions file is scored; the count is printed and must equal the baseline's.

- **Primary**: change in seat primary mean squared error over EVERY seat cell (all classes, so the absorbing
  classes count), arm minus shipped, per election, pooled over seats with the SE **clustered on election**.
  An arm **passes the screen** if the change is below zero by more than 1 clustered SE. RMSE before and after
  is printed beside it.
- **Secondary, printed**: day-before level RMSE over the statewide ALP/LNP/GRN cells (clustered SE); seat
  primary MSE change per jurisdiction; mean absolute correction per jurisdiction.

### Guards (any failure refuses, even with the primary passed)

- G1: pooled seat-winner log loss proxy (the screen's `BETA` proxy, lower is better) not worse than +1 SE at
  the fitted BETA. Also printed at 0.5x and 2x BETA.
- G2: the same on the AEF-7 ledger seats, not worse than +1 SE.
- G3: leave-one-election-out: dropping any single election, the pooled primary change stays negative. (The
  rule is "no single election makes the result", not a share-of-gain cut.)
- G4: no jurisdiction's seat primary MSE worse by more than 1 of its own clustered SE.

### What would make an apparent win unacceptable (named now)

- Any correction larger than 4 points in absolute value at any election (polls are not that biased in a
  persistent way; a 4+ correction means the fit is chasing one outlier).
- The gain in the GRN arm coming from elections where the correction moves the Greens AGAINST the direction
  of that jurisdiction's own past misses (sign error in the code).
- A gain that appears only under the sensitivity specs, or only after excluding an election.
- A gain on the level RMSE with the seat primary MSE worse (would mean the seat layer already compensates and
  the screen's pass-through 1 is wrong for this change; that needs quick_arm, not a level fix).

## Power, before reading the arms

The clustered SE of the primary is printed for each arm. Expected size: if the WA LNP level misses by about
+2.5 at its later elections and the correction removes 1.5 of it, WA LNP cells fall by about 5 pts^2, which is
under 1 pts^2 pooled over all cells. If the pooled SE is larger than the effect seen in the dry-run leaked arm
divided by 3, the screen is reported as underpowered: a refusal from it then says "not shown", not "no".

## Dry run, before any arm is scored (cases whose answer is known)

- **Zero arm**: a correction of exactly 0 everywhere must give a primary change of exactly 0 and a proxy change
  of exactly 0.
- **Leaked arm** (deliberately wrong: uses the target's OWN miss, `corr = level_ref - actual`): must give a
  large primary gain (it makes the level exact), and the same arm routed through the time-forward function must
  stop on the date assertion.
- **First elections of each jurisdiction** (fed2007 or earliest scored, nsw2011, nt2016, qld2012, sa2010,
  vic2010, wa2001): correction exactly 0 under EB toward zero.
- **WA LNP at wa2025**: the six earlier WA level misses are known in sign only from the seat-level finding; if
  the LEVEL misses are not mostly positive, the 17 Oct seat finding is not a level miss and that is reported
  as a finding before the arm verdict.

## Leakage

Only elections with polling day strictly before the target's; asserted. vic2026 and nsw2027 are never scored
(the live vic2026 correction is printed as information only). Reference level for the past elections is the
time-forward shipped level, never the actual.

## Decision rule

A passing arm (primary passes, all guards pass, nothing unacceptable) is NOT cleared: the screen can only
stop an idea. It goes to `scripts/quick_arm.R` on the AEF-7 set, then all 22 for shipping; the command is
written into the review, not run in this session. A refused arm goes back to NEXT-STEPS with its numbers.

## Amendments

(none yet; any change is added below this line with the original text left as is)

### 2026-10-25, result (no amendment to the rules above)

Run as written; result in `docs/reviews/level-jurisdiction-bias-2026-10-25.md`. All three decision arms refused.

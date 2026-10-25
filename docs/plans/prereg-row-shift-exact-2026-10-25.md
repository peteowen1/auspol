# Pre-registration: keep a moved cell exact instead of rescaling the whole row (audit F16), 2026-10-25

Committed BEFORE any screen or walk is run. Finding F16 of `reviews/pipeline-overwrite-audit-2026-10-18.md`, re-checked
in `reviews/audit-f8-f19-status-2026-10-25.md` (LIVE). Built on the worktree branch; nothing below has been run.

## The defect (verified in code, 2026-10-25)

Two post-tree steps set a few (seat, class) cells to a new value and then rescale the WHOLE row to 100, so the moved
cell is scaled with everyone else and hands part of its move back:

| step | file:line (before this change) | what it moves | reaches |
|---|---|---|---|
| salience blend `blend_salience_shares()` | `R/salience_surge.R:436-440` | each governed (seat, party) cell toward `surge_mu` by `p_hat` | `fit_seats_full.R:1578` (DS3b; `:1471` under SALIENCE_BLEND_ONCE), harnesses fed `:1830`, nsw `:1042`, qld `:1068`, sa `:1253`, vic `:928` via `blend_salience_post_xgb()` (`R/salience_surge.R:466`); also the harnesses' stage-1 base (F5). WA and NT have no salience blend. |
| seat-poll blend mode 1 (shipped) | `R/seat_poll_blend.R:1032-1033` | polled cells toward the poll | `fit_seats_full.R:1538`, all seven harnesses (fed `:1539`, nsw `:958`, qld `:941`, sa `:1126`, vic `:814`, wa `:675`, nt `:689`) |
| seat-poll blend mode 2 | `R/seat_poll_blend.R:1110-1111` | same, split weights | same call sites (not shipped) |
| seat-poll blend mode 3 | `R/seat_poll_joint.R:162` | primary cells, plus ALP/LNP from a two-party gap | same call sites (not shipped) |

A cell on `s` moved by `d` in a row on 100 ends on `(s + d) * 100 / (100 + d)`, keeping `d (100 - s) / (100 + d)`.
The fraction lost is mostly the cell's OWN share, not the size of the move.

Not changed, and why:
- Demographic correction (F7): has its own switch, `AUSPOL_DEMO_RESID_FULL` (prereg-demo-resid-full-2026-10-19.md).
- Leader-seat bonus and departed-member blend: already use `.shift_cell()` (`R/leader_seat.R:157`, `R/departed_fed.R:205`).
- Seat-swing port (`R/seat_swing_port.R:300-302`): moves ALP +adj and LNP -adj, so the row total only changes when a
  cell is clipped at 0. Nothing to keep.
- State poll pool and state deviation (`R/state_poll_pool.R:48`, `R/state_deviation.R:294`): federal harness only,
  shift two classes in every seat, and are F19's subject. Left alone so this arm changes one thing.

## Size (bounded from the 25 Oct live walk, not measured cell by cell)

The walk logs do not print the pre-blend cell or each cell's `p_hat`, so this is a bound from what they do print.
`deciding-runs/20261025-minor-additive-walk/add.log`: `DS3 surge-v2 hazard for 31 of 88 seats ... mean 0.0519 | mu
34.28` (line 124), `DS3b salience point estimate applied to 43 (seat,party) cells` (line 3606); the f12 walk
(`deciding-runs/20261025-f12-walk/fit-walk-f12base.log:139, 3626`) says the same. Final vic2026 shares
(`seat-shares-vic-2026-walk-f12base.csv`, 88 seats): One Nation min 6.2, median 22.5, max 40.2; IND median 2.3, max 25.6.

At the mean hazard (p = 0.052):

| cell | lift d (points) | kept by the rescale | lost |
|---|--:|--:|--:|
| ONP on 6.2 | +1.46 | 92.5% | 0.11 |
| ONP on 22.5 (median) | +0.61 | 77.0% | 0.14 |
| ONP on 40.2 (above mu, pulled DOWN) | -0.31 | 60.0% | 0.12 back up |
| IND on 3 | +1.63 | 95.4% | 0.07 |

So the audit's "~15% handed back" understates it for a typical One Nation cell: about 23% at the median. In points it
is small, roughly 0.1-0.15 per cell over 43 cells, because the lifts themselves are small at p = 0.05. The seat-poll
blend touches one vic2026 cell (Hawthorn LNP, `SPB ... mean |change| 0.00`, add.log:3599). The arm's own RSX1 line
prints the exact total for each run (cells, rows, lift, kept, what the rescale would have kept, fallbacks).

## The change (`AUSPOL_ROW_SHIFT_EXACT`, default "0")

`R/row_shift_exact.R`, one helper called by all four sites above. "0" returns `100 * after / rowSums(after)`, the
old expression, so nothing moves. "1": the cells the step moved (`after != before`) keep their new values exactly and
the cells it did not move are scaled in proportion to fill `100 - moved`. A row with a negative cell, moved cells
above 100, or nothing left to scale falls back to the rescale and is counted. One `RSX1` line per call. Tests:
`tests/testthat/test-row-shift-exact.R` (28 expectations: off identical and silent, moved cell exact, rows sum to
100, no negatives, downward moves, infeasible rows counted, bad switch value stops, and the three blend functions
end to end).

## Measurement

quick_arm runs the harnesses from cached stage-6 trees, so it measures the post-tree blends only. The harnesses'
stage-1 salience blend (F5) feeds `base_pred` too; the deciding run must rebuild from stage 1 if the screen passes.

1. Targeted screen (pairs where the salience blend or seat polls act, AEF-7 salience pairs first):
   `Rscript scripts/quick_arm.R "AUSPOL_ROW_SHIFT_EXACT=1" --pairs=fed2022,fed2025,nsw2023,qld2024,sa2026,vic2022`
2. AEF-7: `Rscript scripts/quick_arm.R "AUSPOL_ROW_SHIFT_EXACT=1"`
3. All elections: `Rscript scripts/quick_arm.R "AUSPOL_ROW_SHIFT_EXACT=1" --pairs=all --slots=1`
4. Deciding run, only if 3 is not WORSE and Pete agrees to a stage-1 rebuild:
   `powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_ROW_SHIFT_EXACT=1" -Label f16-exact`
5. Scored by `scripts/score_quick_targets.R <baseline cache> <arm cache> <sims>`.

Before reading any result, read the RSX1 lines: count of calls, cells and fallbacks per election. An arm whose RSX1
lines are missing for an election with a salience corpus did not run there.

## Decision (standard rule)

- Targets: seats with any cell whose predicted share moved by more than 0.05 points between baseline and arm
  (chosen from predictions, never outcomes).
- 1 Primary: target-seat log loss better by more than 1 SE (clustered on election). 2 Guard: all seats not worse by
  more than 1 SE. 3 Leave-one-election-out holds on the primary. 4 No election worse by more than 2 SE of its own
  seats. 5 Without the two largest-gain seats the target gain keeps its sign.
- Reported, not voted: squared share error on the moved cells and on the governed (salience) cells alone; the 1e-4
  floor; each election's share of the gain; AEF-7; RSX1 totals.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the floor (report at 1e-4). (b) It comes from losing surge candidates being pushed up more:
share error on the governed cells whose candidate LOST worse by more than 1 SE, while winners carry the log loss gain.
Show Pete that split even if the rule passes. (c) Fallbacks: more than 1% of moved rows falling back means the rule is
not doing what it says; stop and look. (d) The F5 lesson: the trees were trained on a base that already holds a
rescaled pull, so a 1k screen win that vanishes at 20k is the expected failure; nothing ships on the screen.

## Live walk plan

Once the screens are in (or before, to size it): run `fit_seats_full.R` twice into scratch folders (as the 25 Oct
walks did), once at the published config and once with `AUSPOL_ROW_SHIFT_EXACT=1`. Report: the RSX1 line (expect 43
salience cells and 1 seat-poll cell today), the per-cell diff of `seat-shares-vic-2026-*.csv` on those 44 cells and on
every other cell of their rows, and every seat whose winner probability moves by more than 0.01. Shown to Pete before
anything publishes.

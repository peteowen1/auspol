# Plan: iterate on model ideas in minutes, not hours (2026-10-11)

**For the next session, which ORCHESTRATES and delegates to Sonnet agents (`model: "sonnet"` on every call; no
Fable). Pete, 2026-10-11:** *"we should be able to iterate on ideas in a matter of minutes - we can use good
approximations and smoketests etc - and then maybe implement runs in the background ... when we've decided on
what to ship ... can run these in github or on cron ... waiting 2 hours for you to run something like this in
session is such a waste of time."*

## The problem, measured on 2026-10-10/11

Testing one statewide-level idea (`AUSPOL_LEVEL_RECENT`) took about 4 hours of session time across three arms:

| cost | size | why |
|---|---|---|
| one harness run | 50-110 s (fed ~100 s, WA ~45 s at 1,000 sims; 125-400 s at 20,000) | ~80% is setup and fitting identical between arm and baseline (profiled 2026-10-07: 500 sims 144 s, 20,000 sims 183 s on vic) |
| a screen touching every election | 44 runs (22 x baseline + arm) | statewide changes reach every seat, so "only the affected pairs" does not apply |
| parallelism | 1-2 slots | 3-6 GB free all day; 6 slots need ~10 GB; background jobs are reaped by Claude Code below ~4 GB |
| baseline rebuilds | ~20 min per code edit | `quick_arm.R` keys its cache on all code; reuse via a canary is now OPT-IN (`--reuse`) because one canary election cannot see edits to other harnesses (review 2026-10-11) |
| deciding 20k run | ~40 min serial in the foreground | the repo rule (CLAUDE.md) requires it before shipping |
| the share-level screen | 4 s | fast but reported only the MEAN error; the 1-day decay won on mean and lost on per-election variance (wa2013 +0.061) |

## Goal and finish line

**Done means:** a documented two-tier workflow in this repo where (1) an idea that changes primaries or the
statewide level gets a trustworthy go/no-go in **under 5 minutes** in session, and (2) the deciding 20k run for a
chosen idea runs **outside the session** (GitHub Actions or a scheduled job) and reports back, with
`CLAUDE.md`'s "Screen with quick_arm" section rewritten to match. Each tier is shown to reproduce today's known
verdicts (below) before it is trusted.

## Phase 1: investigate (parallel Sonnet agents, read-only, each with a written finish line)

1. **Profile one harness run end to end** (`backtest_candidate_vic.R`, one pair, 1,000 sims) with
   `~/.claude/lib/runtime_log.R` stage timers: which functions dominate the 80% setup, and which of them depend on
   the arm's switch at all. Finish: a ranked table of stages with seconds and "arm-dependent: yes/no".
2. **What can be cached across arms**: for each expensive stage, is its output a pure function of (code, inputs,
   switches it reads)? Propose a cache keyed on exactly those (`R/seat_poll_blend.R`'s memo and
   `.cs_cached()` in `R/cross_seat_vote.R` are the house patterns). Finish: a list of stages safe to cache with the
   key for each, and the expected saving.
3. **A delta-only re-simulation**: for an arm that changes only the statewide level or a few cells, can the
   harness re-use the baseline's fitted objects and re-run only `simulate_seat_contests()`? Read
   `scripts/backtest_candidate_*.R` and `R/seat_sim.R`. Finish: yes/no per arm type, with the code path.
4. **A better share-level screen**: extend the 4-second screen (`scratchpad decay_curve.R` pattern; inputs
   `output/level-recent.csv`, `output/published-predictions.csv`) to report per-election paired changes, the worst
   single election, and a cheap proxy for seat log loss (e.g. per-seat margin shift -> win-probability change via the
   stored allprobs). Finish: a script whose verdicts agree in sign with the three seat screens of 2026-10-11 (1-day
   decay REFUSED, 10-day decay ~tie, 28-day window better than none).
5. **Background deciding runs**: design a GitHub Actions workflow (the repo is public, so Actions minutes are free --
   memory `public-repo-actions-free`) or a local scheduled job that runs the full 20k stage 6 for a named arm across
   the 22 elections as a matrix (one job per harness/pair), pools, and posts the pre-registered criteria table as a
   comment or artifact. Inputs it needs that are not in git (candidacies, reference data, the as-at models) come
   from the `shipped-models` release. Finish: a workflow file and a dry run on one pair.
6. **Fix the canary properly** (`scripts/quick_arm.R`, currently `--reuse` opt-in): one canary per harness type,
   record the code hash per cached election, and fix the crash seen 2026-10-11 (after a "differs" verdict the scoring
   read a missing cache file). Prove it reuses on a harmless edit and refuses on a baseline-changing edit in EACH
   harness. Finish: both proofs in the commit message.

## Phase 2: build (orchestrator decides from Phase 1; Sonnet agents in worktrees for independent pieces)

Pick the tier-1 path from items 1-4 (cache vs delta re-simulation vs proxy screen), build it, and validate it on the
three known verdicts above plus one more from `docs/DECISIONS.md`. Build item 5's workflow. Review gate (Sonnet) and
`check_like_ci.R` before each PR.

## Known state to start from

- `AUSPOL_LEVEL_RECENT=decay`, half-life 20 days, ships on Pete's decision without a measured run at 20 days
  (`plans/prereg-level-recent-blend-2026-10-10.md`); the `shipped-models` scoreboard still describes an earlier run.
- `output/` holds the 10-day decay deciding run (code c633fd8); backups of the 28-day window run and the pre-blend
  run were in the session's temp folder, not committed.
- Memory: run heavy R work in the foreground or via the planned background workflow; Claude Code reaps background
  shells at low memory.

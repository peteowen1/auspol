# Pre-registration: re-screen `AUSPOL_SLOPE_SHRINK` against today's shipped model (2026-10-25)

Written before any screen. No code change: the switch already exists (`R/split_slope.R:675-699`), published `"0"`.
Pete approved removing the `min_n` cliffs in `R/split_slope.R` on 2026-10-25 (queue item "Time-forward fits still use
`min_n` cliffs", `R/split_slope.R:395,416`).

## What `AUSPOL_SLOPE_SHRINK=1` does today (read 2026-10-25)

- `fit_conditional_slopes()` (minor same/new cells): the per-cell cliff at `:416` (`if (nrow(sub) < min_n) next`,
  min_n 40) is replaced by `.shrunk_slope(sub, 1)`. The tier-pool cliff at `:395` (`tier_pool()` returns 1 below 40)
  is still computed, but every one of the four classes' cells is then overwritten by the shrunk value, so it no longer
  decides anything.
- `fit_major_conditional_slopes()` (`:512`) and `fit_major_departed_slope()` (`:762`, departed and present cells):
  the same replacement.
- The shrink (`.shrunk_slope()`): slope through the origin `b`, shrunk toward 1 by `1 + d * d^2 / (d^2 + se^2)`,
  `d = b - 1`, `se^2` the larger of the cluster-robust (by election) and ordinary variance. No `min_n`; it returns
  exactly 1 with fewer than 3 rows or fewer than 3 elections (added by the 2026-09-28 pre-measurement amendment, after
  fed2007's departed slope came out 0.313 from 6 seats in 2 elections).

So it does replace both named cliffs with shrinkage, and no code is changed here. Two differences from the
CLAUDE.md partial-pooling form are recorded, not acted on: it shrinks toward 1 (no adjustment), not toward the tier's
pooled slope; and its weight uses the cell's own squared distance from 1 in place of a between-cell variance.

**Which of these the shipped model actually runs.** `fit_conditional_slopes()` runs only under
`AUSPOL_FIT_SLOPES=1` (published `"0"`, refused 2026-09-09), and `fit_major_conditional_slopes()` only in the NSW
harness under `AUSPOL_MAJOR_SLOPES=1` (default `"0"`). The shipped harness logs carry no `FS1` line (checked: the
newest 35-election quick_arm baseline, `%TEMP%/auspol-quickarm/cache/6545b6bb8954/`). So `:395` and `:416` are off the
shipped path today, and on the shipped configuration this arm moves exactly one thing: `fit_major_departed_slope()`,
the ALP/LNP departed-member and present-member slopes (`AUSPOL_MAJOR_DEPARTED=1`, `AUSPOL_MAJOR_SLOPE=1`), read by
every harness and by `fit_seats_full.R:1116`. Live and backtests therefore get the same rule from this one switch.

Where that cliff binds today (time-forward departed cells, from the same baseline's `BF0m` lines; present cells are
all n >= 50 except wa2001):

| election | departed ALP (n) | departed LNP (n) | what the cliff does |
|---|---|---|---|
| fed2007 | 1.000 (6) | 1.000 (14) | both snapped to 1 |
| fed2010 | 1.000 (27) | 1.000 (38) | both snapped to 1 |
| sa2010 | 1.000 (20) | 1.000 (30) | both snapped to 1 |
| wa2001 | 1.000 (0) | 1.000 (0) | no rows; unchanged under the arm too |
| wa2005 | 1.000 (5) | 1.000 (5) | both snapped to 1 |
| wa2008 | 1.000 (17) | 1.000 (26) | both snapped to 1 |
| nsw2011 | 0.554 (40) | 0.777 (52) | ALP at exactly the floor, believed outright |
| vic2010 | 0.554 (40) | 0.777 (52) | same |

Numbers are slope multipliers on a seat's prior deviation from the statewide level (1 = carried in full).

## Previous result, and why a re-screen is not a re-run of the same experiment

Measured 2026-09-29 against v46 (`plans/prereg-slope-shrinkage-2026-09-28.md`): ledger seat log loss 0.2822 ->
0.2878 (+0.0056, SE by election 0.0035), **refused**. Early targets mostly improved (fed2007 -0.005, fed2010 -0.007,
vic2014 -0.009, fed2016 -0.020), recent ones got worse (wa2025 +0.025, nsw2023 +0.010). Since then the baseline moved
in ways that touch exactly this: the SHIP_* fallback became time-forward (v51), `fit_conditional_slopes()` left the
shipped path, the corpus grew from 22 to 35 elections, and the major departed/present slopes are now the only cells
the switch reaches. That 2026-09-29 refusal stands; this measures a different baseline, and an AEF-7 pass does not
overturn it without the 35-election run.

## Arms

| arm | setting | differs from baseline on |
|---|---|---|
| baseline | shipped (`AUSPOL_SLOPE_SHRINK=0`) | - |
| S1 | `AUSPOL_SLOPE_SHRINK=1` | ALP/LNP departed and present slopes in every election (a small pull toward 1 where well measured; a real estimate where the cliff snapped to 1) |

No grid: the shrink has no tuning constant.

## Criterion

1. **Primary (screen): pooled seat log loss on AEF-7** (minus log of the probability given to the actual winner;
   lower is better), SE clustered on election, `scripts/quick_arm.R`. None of the AEF-7 elections has a departed cell
   under 40 (n 188-264), so here the arm only pulls well-measured slopes slightly toward 1: this is the side effect
   that sank the 2026-09-29 run. **Not worse by more than 1 SE**; a WORSE beyond 1 SE stops the arm.
2. **Targeted: the eight elections in the table** (fed2007, fed2010, sa2010, wa2001, wa2005, wa2008, nsw2011,
   vic2010), seat log loss pooled over their seats, SE clustered on election: better than shipped by more than 1 SE.
   wa2001 must score exactly 0 (no rows either way): if it moves, something other than this switch moved.
3. **Guard, all 35:** pooled seat log loss not worse by more than 1 SE; no election worse by more than 2 SE of its own
   paired seat differences; leave-one-election-out on the targeted metric stays better by more than 1 SE with each of
   the eight dropped in turn; the targeted gain keeps its sign with the two largest-gain seats removed.
4. **It ran:** the `BF0m` line differs between arm and baseline in every election with departed n >= 3 rows in >= 3
   elections; quick_arm reports changed cells > 0.

**What would make an apparent win unacceptable, in advance:**
- the targeted gain comes with the recent elections worse beyond 1 SE pooled (the 2026-09-29 pattern): that is a
  trade, and it goes to Pete with the split, not a pass;
- the moved departed-member seats score worse on share error in most of the eight (outcomes contradict the direction:
  the arm says a retiring member's seat deviation carries LESS than in full there);
- clause 4 fails.

**What the criterion cannot see:** quick_arm's `0.5/N` probability floor (moves confined to seats under ~1/N); and
the 3-election floor inside `.shrunk_slope()` keeps fed2007 departed ALP (6 seats, 2 elections) at exactly 1, so that
cell is a cliff the arm does not remove.

## Dry run on cases with a known answer

- Rebuild J, 2026-09-29: clause 1 on the ledger (the AEF-7 elections) +0.0056 with SE 0.0035 = 1.6 SE worse: stops.
  The refusal that was made. Correct.
- `AUSPOL_CONSERVE_SHRINK_K`, 2026-10-16 (+0.0001, SE 0.0001 over 35): clause 1 not worse by more than 1 SE, passes;
  its targets were within noise, so under clause 2 here it would not clear as a gain. That arm shipped on Pete's
  no-cliff rule, not on a gain, so this criterion is stricter than that decision: it asks for a gain on the eight
  elections where the cliff binds. Stated so the difference is not found later.
- wa2001 (no rows): clause 2's exact-0 check. A check that cannot fail is caught by construction here: any code path
  that moved wa2001 would show.

## Decision rule

Clause 1 stops or continues. Clauses 2-4 on the 35-election run decide: all pass, recommend shipping. Clause 2 fails
while 1 and 3 pass (no gain, no harm): goes to Pete as "ship on the no-cliff rule, or keep the cliff", with the split
shown (standard rule 9), not decided here.

## Screen commands (after 02:15, from the main checkout)

```
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SLOPE_SHRINK=1"'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_SLOPE_SHRINK=1" --pairs=fed2007,fed2010,sa2010,wa2001,wa2005,wa2008,nsw2011,vic2010'
```

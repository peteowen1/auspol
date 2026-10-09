---
name: biggest-misses
description: Rank auspol's biggest forecast misses by primary vote, two-candidate-preferred (TCP) or seat log loss from the newest published-path backtest run, joined to the seat registry. Use whenever Pete asks for the biggest misses, worst seats, top errors, where the model is worst, or "what are we getting wrong" by any metric, and before quoting any per-seat error number.
---

# Biggest misses

Pete asks for this often and expects the newest numbers every time. On 2026-10-09
I ranked primary misses from `output/forecasts.csv`, which is the xgb layer's share
BEFORE the seat-poll blend, the surge and the simulation. Goldstein 2022 came out
as a 30-point miss when the published model had it 7.4 points under, with Daniel
a 0.52 favourite who won. **Never rank misses from `forecasts.csv`, the
`xgb-primary-*` files or `base_pred`.** Those are intermediate stages.

## Steps

1. Run the script:

   ```
   powershell.exe -Command 'Rscript scripts/biggest_misses.R'
   ```

   Flags: `--metric=primary|tcp|logloss` (default all three), `--n=30`,
   `--pairs=vic2022,fed2022`, `--aef7`. Takes about 5 seconds. It reads the run
   that `pool_backtests.R` scored for each pair, through `scripts/ledger_inputs.R`,
   so every metric comes from the same run the AEF-7 ledger uses.

2. **Read the freshness lines before the tables.** Report them to Pete when they fire:
   - `MX0!`: backtest files are newer than the pool. Run
     `powershell.exe -Command 'Rscript scripts/pool_backtests.R'` first, then rerun.
   - `MX1!`: a hand-rerun file was scored. Check it is the shipped configuration
     (memory `hand-reruns-contaminate-output`).
   - `MX2!`: model code changed since the run. The commit subjects are printed.
     Say whether any of them changes backtest numbers. If one does, the ranking
     describes the last rebuild, not HEAD. Say that plainly.

3. **State the source in the answer**: run git hash, rebuild date, pair and seat
   counts. For example: "final published path, rebuild 75dbda7 (2026-10-07), 22
   pairs, 2,120 seats".

4. **Use the `registry` column.** A verdict (`OPEN`, `PARKED`, `NOTHING TO FIX`,
   `DATA`) means the seat has been dug into. Read its entry in
   `docs/SEAT-REGISTRY.md` and quote the reason instead of re-diagnosing. `-` means
   nobody has looked at it yet. Say "not investigated" rather than guessing a cause,
   or label your reading as unverified.

5. **Keep the registry current.** Whenever a seat gets dug into, add or update its
   entry under the pair's `## pair` heading in `docs/SEAT-REGISTRY.md`, in the form
   `- **Seat** -- **VERDICT** reason, evidence file`. The script parses exactly that
   shape: the seat in bold at the start of the bullet, and one of the four verdict
   words anywhere in it. A seat mentioned only inside another seat's bullet, or under
   the cross-seat heading, is not matched.

## What each metric is

- **primary**: final predicted share for each party class against the actual
  share, in percentage points. gap = actual minus ours, so positive means we
  under-called.
- **tcp**: our two-candidate-preferred % for the final two that actually happened,
  against the official figure. AEF-7 pairs only, because that is where official
  final twos are resolved. Seats whose real final two never appeared in our
  simulations are listed by name and not scored.
- **logloss**: minus the log of the probability we gave the actual winner, floored
  at 1e-6. Lower is better. A seat at 13.82 means we gave the winner zero.

The script writes every row to `output/biggest-misses.csv` for follow-up questions.
Answer those from the file; don't rebuild the ranking by hand.

## Limits

- It ranks backtests only. The live Victorian 2026 forecast has no actuals yet.
- Early WA pairs (`wa2001`, `wa2005`, `wa2008`) have no as-at xgb model and no
  leader-seat bonus, so their misses are a known gap of the corpus, not a fresh
  finding.

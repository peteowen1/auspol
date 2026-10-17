# Pre-registration: draw each cell's error from the errors we actually make (2026-10-17)

Committed BEFORE anything is built or run. Pete, 17 Oct, on the composition spread: "Go to the skew/fat-tail
fix" (C parked as a benchmark), after asking for the root cause to be fixed for everything, not one state.

## The finding this rests on (shipped model, all 35 elections; `reviews/composition-spread-2026-10-17.md`)

Standardised error z = (actual - predicted share) / the simulator's per-cell sd, cells predicted 2+:

- **Heavy tails everywhere.** Seats with no independent at 10+: 10,945 cells, RMS z 1.05 but robust sd 0.81,
  0.57% beyond 4 sds (a bell curve gives 0.006%), kurtosis 20. The simulator draws `rnorm` for every cell
  (`R/seat_sim.R:1407`, `src/seat_sim_core.cpp:168`), so it all but rules out the misses we actually make,
  which is how winners end up at the 1e-6 floor (Kimberley, Ryan, Alfred Cove).
- **Skew for candidates.** The independent's own cell: median miss -0.4 to -2.6 points below 30% (56-67% come
  in under), mean near 0. Most fizzle a little, a few surge.
- A symmetric widening is the wrong shape for both: C (all classes in an IND seat) passed its screen but taxed
  NSW and safe favourites; C2 (IND cell only) lost.
- The 2026-10-06 breakout mixture (a classifier choosing who breaks out) was refused for weak signals, so this
  arm uses no per-seat breakout prediction at all.

## Arm

| Arm | Switch | Rule |
|---|---|---|
| A (shipped) | `AUSPOL_ERROR_DIST=0` | `rnorm` per cell. |
| E | `AUSPOL_ERROR_DIST=1` | below. |
| C (benchmark, reported) | `AUSPOL_COMPOSITION_SD=1` | the parked composition spread, from its screen. |

**E.** Each cell's noise is `sd_cell * z`, where `z` is drawn from the empirical distribution of standardised
errors from EARLIER elections only, instead of N(0, 1). The sd itself (`level_sd`, size factor, every
override) is unchanged; only its shape changes.

- **Distribution, per target:** cells from elections before the target (published path, `sharedetail`),
  predicted 2+; `z = (actual - pred) / (sdm x the size factor that target applied)`. Stored as 201 quantiles
  (0.5% steps), per GROUP, by `scripts/fit_error_distribution.R` -> `output/error-quantiles.csv`, built in the
  rebuild like the spread tables.
- **Groups:** each class separately (ALP, LNP, GRN, IND, ONP, OTH, OTH_RIGHT), each shrunk toward the pooled
  distribution by quantile averaging `q = w q_class + (1 - w) q_pooled`, `w = n / (n + 200)` (n the class's
  cells; k = 200 CHOSEN so a class needs a few hundred cells before its own tails dominate). Tails come from
  data: a class with few cells borrows the pooled tails.
- **Standardised to the shipped scale.** Each group's quantiles are rescaled so their RMS is 1 (the shipped
  rnorm's), so E changes the SHAPE (tails, skew), not the overall width. The width problem is C's question.
- **Draw:** one uniform per cell (`runif`), `z` by linear interpolation between stored quantiles; the two
  engines do the same arithmetic in the same order (tested byte-identical, like every simulator path).
- Fewer than 3 earlier elections or 2,000 cells: `rnorm`, as shipped (`ERD1` prints which).
- Six harnesses, NT and live, inside `simulate_seat_contests()`.

## Criterion

Scope matches the change: E changes every cell of every seat, so the primary is every seat.

1. **Primary, all 35 elections, 2,931 seats:** seat log loss, SE clustered on election. **E ships if lower
   than A by more than 1 SE AND its point gain is at least C's (-0.0021 on the 1k screen).**
2. **Reported:** seats where A gave the winner under 0.01 (the floor problem: count and log loss), the
   strong-IND set (217), favourites at 0.90+ who won, NSW, AEF-7, reliability by band, E minus C per election.

Screen at 1,000 sims (`deciding_run.ps1 -Sims 1000`, all 35). A tail change acts below 1/N, which a 1k screen
floors at 5e-4, so **the deciding run is 20,000 sims** before any ship, and shipping is Pete's call.

## What would make an apparent win unacceptable (decided now)

- **One election** supplies more than half the primary gain -> refused.
- **Floor seats only:** if more than half the gain is seats A gave under 1e-4, it goes to Pete as a split
  result (with and without them) before anything ships.
- **Favourites:** if the 0.90+ favourites who won get worse by more than 1 SE, reported beside the primary.
- **Live centre:** E keeps each class's mean error but not its median (the IND median sits below 0, as the data
  say). Any vic2026 party whose median seat count moves by more than 1 is listed for Pete before shipping.
- **Identity:** with the switch off, every harness is byte-identical (proved before any arm runs).

## What this cannot see

- Errors in one seat are drawn independently per cell; in reality an independent's surge comes out of the
  majors (negative correlation). Counting is scale-free, so the draw's sum not being 100 does not matter, but
  the joint shape is not modelled. If E ships, the next question is a joint (per-seat) error draw.
- Conditioning on share band beyond the per-class groups (a 30%+ independent's errors are right-skewed, a
  5% one's left): one shape per class here.
- Width: unchanged by design (RMS 1). C showed width matters for IND seats; a combined arm comes after.

## Amendment 1 (2026-10-17, first screen stopped before any result)

The original text above stands. The first screen (`20261017-1616-error-dist-screen-1k`) printed ERD1 medians
that led to a check of each class's MEAN z in the table: GRN -0.29, OTH_RIGHT +0.28, ALP -0.11 to -0.25,
ONP +0.13 to +0.21 (about -1.5 to +1.4 points at a 30% share). The quantiles carried each class's historical
bias, so E would also have moved every seat's centre: a level correction inside an arm defined as "shape, not
width", and one that belongs in base_pred and the xgb layer (CLAUDE.md), not the simulator. "E keeps each
class's mean error" above meant the shipped draw's mean (0). Fix: each class's quantiles are CENTRED to mean 0
(exact for the interpolated draw) before the RMS-1 rescaling; the skew stays (medians off zero). The screen was
stopped by PID, marked FAILED, nothing from it scored. Queued separately: the per-class mean errors are a
finding in their own right (Greens over-predicted by ~0.3 sd everywhere).

## RESULT (2026-10-17, 1k screen `deciding-runs/20261017-1628-error-dist-screen-1k-b/`, same baseline as C's byte for byte) -- REFUSED

| Scope | Seats | E - A (SE) |
|---|---|---|
| PRIMARY: every seat | 2,931 | -0.0004 (0.0017), within 1 SE: FAILS |
| C - A (benchmark) | 2,931 | -0.0021 (0.0013) |
| winners A gave < 0.01 | 21 | -0.275 (0.159) |
| winners A gave 0.01-0.5 | 324 | **+0.059 (0.011)** |
| winners A gave 0.5+ | 2,586 | -0.0057 (0.0007) |
| favourites 0.90+ who won | 1,772 | +0.0008 (0.0003) |

Refused on the primary, on one election (share 2.8 of the net gain) and on the floor clause (13 seats A gave
< 1e-4 carry more than all of it; without them +0.0003). Why: at fixed RMS, fatter tails squeeze the core, so
contested seats are called more confidently and wrongly (+0.059 on the 324). Shape alone cannot help; width (C)
and tails together is the open question. Switch stays "0".

## Amendment 2 (2026-10-17, after E's refusal; Pete: "Screen C and E together")

The refusal above stands. Both failures point the same way: C adds width in independent seats (-0.0021, but
taxes safe favourites), E adds tails at fixed width (rescues floor seats, squeezes contested ones). **Arm CE** =
`AUSPOL_COMPOSITION_SD=1 AUSPOL_ERROR_DIST=1`, both tables exactly as already built (no refit, no tuning).
Known imperfection, stated now: E's z were standardised by the shipped sd, not C's widened one, so in widened
seats CE's tails are somewhat wider than measured; and C still widens non-standing classes (composition prereg 1b).

Decided now: CE is screened at 1,000 sims on all 35 (same baseline). **CE goes to a 20k deciding run only if its
every-seat gain is larger than C's (-0.0021) AND better than A by more than 1 SE, with the one-election and floor
clauses above applied to it.** Otherwise C goes to its own 20k deciding run, as Pete chose in the same answer.

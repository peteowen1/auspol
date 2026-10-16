# Pre-registration: a Liberal and a National in the same seat count as two candidates (2026-10-16)

Committed BEFORE any code is written or any arm is run. Pete, 16 Oct, after walking Albany 2013, Kimberley 2013,
Pilbara 2017 and Murray-Wellington 2017 (and Bass fed2019 as the harmless case): **two candidates**, not an xgb
feature (`docs/PETE-ASKED-FOR.md`, 2026-10-16).

## The problem, measured

`classify_party()` files Liberal and National as one class, `LNP`. In a seat where both stand, the simulator sees
one Coalition candidate holding their combined vote, so every Coalition vote reaches the final count. In reality the
weaker of the two is excluded and its votes split.

- 191 such seats in the 35 scored elections (WA 99, fed 57, Vic 18, SA 15, NSW 2): 6.5% of seats, 9.7% of seat
  log loss; the Coalition lost 74 of them.
- **The combined Coalition primary vote is NOT the fault.** Mean error (ours minus actual), points: split seats
  +0.13 to +0.62 by history, one-candidate seats +0.42 (2,656 seats), all within SE (scratchpad `libnat2.R`). The 6-10 point
  over-calls in the walked seats were selection: they were picked as the worst losses.
- **The count is.** When a Coalition candidate is excluded and the other survives, 71.2% of its votes go to the
  other (207 exclusions, 21 elections, all transfer files; per election 57-81%, plus sa2026 37% on 3 exclusions);
  15-29% go to Labor (WA 2013-17: 27-29%). Albany 2013: Coalition 49.5 combined against Labor 39.3, Labor won.
- `prereg-wa-three-cornered.md` (Aug) treated this as contamination of the flow POOL and filtered seats. It said
  then that a negative result would mean "the survivor-set conditioning is too coarse". This prereg acts on that
  reading: give the second Coalition candidate its own cell.

## Arms

| Arm | What |
|---|---|
| A | shipped (one `LNP` cell) |
| S | split, defined below, behind `AUSPOL_COALITION_SPLIT=1` (default 0 until decided) |

**S, in a seat whose nominations include both a Liberal and a National** (from `output/candidacies.csv` `party_raw`
for backtests, the live candidate list for vic2026; never from the result):

1. **Primary vote unchanged.** Every stage up to the simulator still predicts one combined `LNP` share. S only
   divides it.
2. **The division.** In each draw, the junior candidate gets fraction `r` of the Coalition share, as a new cell
   `LNP2`; the senior keeps the rest as `LNP`. `r` has a predicted centre and a per-draw spread:
   - centre: the same seat's split at the previous election when both stood, shrunk toward the pooled mean
     junior fraction of earlier split seats, `w = tau^2 / (tau^2 + s^2)`. `tau^2` is the between-seat variance of
     the fraction; `s^2` is the variance of its change from one election to the next. Both are fitted
     time-forward (earlier elections only). With no previous split in that seat, the pooled mean.
   - spread: a Beta draw around the centre, sd = the sd of that election-to-election change, fitted time-forward.
   - "junior" means the smaller predicted fraction, not the party: the National is senior in Pilbara 2017.
3. **The count.** When one of `LNP`/`LNP2` is excluded and the other survives, fraction `f` of its votes goes to
   the survivor. The remaining `1 - f` is split by the existing `LNP`-origin flow row over the other survivors.
   `f` = the pooled Coalition-to-Coalition rate over all jurisdictions' EARLIER elections (time-forward; 71.2% on
   everything to date). Jurisdiction-specific `f` is a later arm, not this one.
4. **Scoring.** A seat won by `LNP` or `LNP2` is a Coalition win. The class the scoreboard sees does not change.

Implemented as a new share column plus flow rows in the existing class-keyed engine (`simulate_seat_contests()`),
in all six harnesses and `fit_seats_full.R` (CLAUDE.md: a fix to one harness is a fix to all).

## Before scoring: the plumbing checks (any failure stops, nothing is scored)

- **Every seat without both a Liberal and a National is byte-identical between A and S** (sharedetail and
  allprobs). One that moves is a bug.
- **Known answers** (dry run, one election each):
  - Albany wa2013: the Coalition win probability falls from 0.97.
  - Bass fed2019 (National 1.4%): the Coalition win probability moves by less than 0.01.
- Each run prints, per election, the number of split seats, `f`, and the mean `r` it applied.

## Criterion

Seat-winner log loss (-log of the probability given to the actual winner; lower is better), SE clustered on
election. Screened with `quick_arm.R` (1,000 sims) on the elections that have split seats; decided by the 20,000-sim
run (`deciding_run.ps1`), because a seat moving off the 1e-6 floor (Barwon, 16 Oct) is a tail effect a screen
cannot see.

1. **Primary: the 191 split seats.** S ships if better than A by more than 1 SE.
2. **Guard: all 35 elections.** S no worse than A by more than 1 SE. (This follows from the byte-identical check
   unless the split seats get worse.)
3. **Reported:** Coalition-won and Coalition-lost split seats separately; per jurisdiction; AEF-7.

## What would make an apparent win unacceptable (decided now)

- **One election:** more than half the primary gain from a single election -> refused.
- **WA carries it while the rest gets worse:** if the 92 non-WA split seats are worse under S by more than 1 SE,
  refused, even if the pooled primary passes. A WA-only gain with the rest flat is acceptable: WA is where the
  contests are.
- **It buys the lost seats by giving away the won ones:** if the 117 Coalition-won split seats get worse by more
  than the 74 Coalition-lost seats improve, the primary fails anyway; reported so it cannot be missed.
- **Live:** if Ripon's Coalition win probability moves by more than 15 points, stop and report before shipping.

## What this cannot see

- The combined Coalition primary vote (deliberately unchanged), and the separate lead that WA over-calls the
  Coalition everywhere (+2.49 in 284 one-candidate seats).
- Exhausted votes under optional preferential voting (NSW, Qld before 2016): `f` is measured on votes that
  transferred. NSW has 2 split seats, so this barely matters.
- Seats where the two Coalition candidates are the final two (Labor excluded earlier). S makes a Coalition win
  certain there, as A did.

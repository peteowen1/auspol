# Pre-registration: former-leader cut scaled by how safe the seat is, 25 Nov 2026

Committed before any scaled number is computed. Screened with the new seat-level quick screen
(`scripts/seat_quick.R`, built the same day), not with `quick_arm.R`.

## Why

The flat former-leader cut (`AUSPOL_LEADER_FORMER=1`, `prereg-leader-former-2026-11-25.md`) halves a real
bias (the old leader's party over-called by +2.03 points on 39 seats, to +1.07) but costs winner calls in
close seats that party HELD: Wentworth fed2019 0.337 -> 0.220, Clayfield qld2020 0.663 -> 0.484, Cottesloe
wa2021 0.645 -> 0.472. Pete's intuition: cut where the seat is safe, not where it is close.

## The variant (primary): `former_winprob`

At each former-leader seat (same `former_leader_seats()` set as the flat cut), the cut is

    cut_i  = slope * s_i,      s_i = max(0, 2 p_i - 1)

where `p_i` is the probability the BASELINE forecast gave the former leader's party to win that seat (the
harness's own allprobs for that election: an as-at quantity, nothing after polling day). `s_i` is 0 at a
coin flip or worse and 1 at certainty. `slope` is fitted time-forward exactly as `former_leader_bonus()`
fits the flat cut: `r_seat` (actual minus as-at `xgb_pred_seat`, less the class's median miss that
election) at the former-leader seats of every election before the target, regressed through the origin on
`s_i`, the slope shrunk toward 0 by `b^2 / (b^2 + se^2)` (the rule `.role_pooled_bonus()` uses for its
pooled mean). One parameter, no role split (the flat fit's tau^2 was 0). Under 3 earlier seats with s > 0,
the slope is 0. Applied with `.shift_cell()`, as the flat cut is.

Production note, said now so it is not discovered later: `p_i` is a simulation output, so shipping this
needs either a two-pass simulation or a stage-1 probability. The secondary variant below needs neither.

## Secondary (reported, never decided on): `former_margin`

The same fit with `s_i = max(0, own - best other)`, the party's PRIMARY margin in the as-at tree
predictions, in points. Expected to do worse at the motivating seats (Wentworth 2019 was safe on primaries
and close on two-candidate), which is why it is not the primary.

## How it is scored

`Rscript scripts/seat_quick.R --tweak=former_winprob --vs=former_flat --pairs=all` at 20,000 sims, every
moved seat re-simulated one seat per call on one seed (baseline, flat and scaled share each seat's random
stream: common random numbers). All 35 elections, against the cached published-config baseline.

The tweak acts on the FINAL shares (the simulation's input). In the harness the flat cut acts before the
seat-poll blend, which dilutes it in polled seats. If the flat port's `--check-arm` comparison shows that gap,
the scaled cut at each seat is multiplied by that seat's realised pass-through in the real harness arm
(final delta over intended delta, from `deciding-runs/20261125-leader-former` quick_arm caches), and the
report says so.

## Decision rule

- **PRIMARY**: paired seat-winner log loss, scaled minus flat, over the seats either moved (SQ6), SE clustered
  on election. The scaled variant is PREFERRED to flat if the paired change is below -1 SE.
- **DO-NO-HARM against the baseline** (the clause the flat cut failed): log-loss change over all seats of the
  35 elections (SQ5, quick_arm's Q3 denominator) not worse than +1 SE, and no single election worse by more
  than 0.01.
- **BIAS NOT WORSENED**: the mean signed error of the former leader's party at the seats the scaled cut moved
  (actual minus predicted, SQ3b) must be no further from 0 than the baseline's at the same cells. The scaled
  cut is smaller by design, so it is not required to remove as much of the bias as the flat cut does; the
  amount it removes is reported beside flat's.
- SHIP CANDIDATE only if all three hold; then it goes to a quick_arm run built into `leader_seat_apply()`
  before any shipping decision. A screen here is never a ship decision.

What would make an apparent win unacceptable: any seat moving that the tweak does not declare (SQ7 stops the
run); the slope's sign positive (a cut that becomes a bonus); the result resting on seats with no recorded
winner (scored 0, listed by SQ1!).

## Instrument proofs, with pass rules written before they run

1. `--prove`: every election re-simulated in full from its state is IDENTICAL to the harness's own
   `win_prob` (same seed, same sims), and the state's shares equal the run's `sharedetail.csv` to csv
   rounding (< 1e-9). Any election not identical fails the instrument.
2. `--prove-subset=vic2022,wa2025`: every seat, one per call, against the harness's full run: max |z| < 5
   over all seat-party cells and the winner-probability mean difference within 3 SE. The same command with
   `--break` (every per-seat argument rotated by one seat) must FAIL; if it passes, the check is blind.
3. Flat port against the real harness arm (`--check-arm` on the 10:37am quick_arm caches 6ac7023650e3 arm,
   b09d4d70fd65 baseline):
   - our cached baseline shares equal that run's baseline shares on every cell (< 1e-9) in every election
     (code since then touches vic2026 only); if not, the comparison is void where they differ;
   - the moved-seat sets are identical in every election;
   - at seats with no seat poll, our arm equals the harness arm on every cell (< 1e-6 points);
   - at seats where they differ, the gap is the seat-poll blend's dilution and is listed per seat. The proof
     does NOT pass if any of Wentworth fed2019, Clayfield qld2020 or Cottesloe wa2021 is among them without
     the pass-through correction described above.
   - log loss: flat at 1,000 sims (quick_arm's floor, 5e-4) over the touched seats agrees in sign with
     quick_arm's 0.1124 -> 0.1369 on those seats, and the all-seat change agrees with +0.0003 within 2 of
     quick_arm's SEs (0.0002).

## Dry run on a known answer (the instrument, before the variant)

The flat cut, scored by this screen, must reproduce the sign of quick_arm's verdict: do-no-harm WORSE
(quick_arm: +0.0003, SE 0.0002, 2,931 seats) and the cut-party mean error moving from about +2 toward +1. If
the screen reads flat as harmless, the instrument disagrees with quick_arm and the scaled variant is not
scored.

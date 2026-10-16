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

## Amendment 1 (2026-10-16, after the plumbing check failed; Pete chose "amend")

Added after seeing one plumbing result, so it is visible here and the clauses above are unedited. What failed:
Bass fed2019 moved 0.083 -> 0.026 against the 0.01 limit (`docs/reviews/lib-nat-plumbing-2026-10-16.md`). Cause:
a seat with no previous split took the pooled junior fraction (0.27), so a 1.4% token National was simulated at
about 11 points. The junior's share is two-humped (token candidate or real contest; 33% of federal split
seat-elections have the junior under 0.10), and arm S's centre could not tell them apart.

**What changes: only the centre and spread of the division (S step 2).** Everything else in S, every plumbing
check, the criterion and every refusal clause stand as written. Bass's limit stays 0.01.

The Nationals' fraction of the Coalition vote in the seat, `fn = NAT / (LIB + NAT)`, is predicted from facts
known before the election, by a ridge regression on `logit(fn)` (`glmnet`, alpha 0, lambda by cross-validation
`lambda.min`, folds = min(10, n)), fitted on split seat-elections from EARLIER years only. Features:

1. **The junior party's earlier vote in that state**: the Nationals' fraction of all Liberal + National votes in
   the same state at that jurisdiction's previous election (federal seats by their state).
2. **Each candidate's own previous vote**: the National's and the Liberal's own primary share at that
   jurisdiction's previous election (same name, any seat), 0 with an indicator when they did not stand.
3. **Sitting member**: whether the National, or the Liberal, won this seat at the previous election (by name).
4. **The seat's last split**: `fn` at the previous election when both stood, with an indicator (0 otherwise).

The junior fraction `r = min(fn_hat, 1 - fn_hat)`. Spread: a Beta around `r` with sd = the sd of the
out-of-fold residuals `fn - fn_hat` from that same cross-validation (one number per election). `fn` is clamped to
[0.005, 0.995] before the logit. Elections with fewer than 5 earlier split seat-elections get no split (as
before, an election with no earlier data is the one-candidate count). `f` is unchanged.

Not done, named so it is not mistaken for an oversight: no seat-type, region or demographic features; no
mixture for the two humps (a ridge centre plus Beta spread first, because it is the smaller change).

## Override 1 (2026-10-17, Pete): the Bass plumbing clause

The Bass clause ("moves by less than 0.01") failed twice: 0.057 under arm S as written, 0.030 under Amendment 1
(`docs/reviews/lib-nat-plumbing-2026-10-16.md`). **Pete overrode it** after seeing that no pre-election fact
separates Bass from Lyons (fed2016: no National stood in Tasmania; fed2019 from that position: Bass 1.4%, Braddon
2.4%, Lyons 15.7%), so the clause required knowing in advance that the National would be a token candidate.
The clause above is left as written. The other plumbing checks passed. Everything else stands unchanged: the
criterion (log loss on the split seats, better by more than 1 SE), the guard, and every refusal clause. This
favours the later answer, which is why it is Pete's call and recorded here, not a quiet amendment.

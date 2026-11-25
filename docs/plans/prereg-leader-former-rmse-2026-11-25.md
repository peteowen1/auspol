# Pre-registration: the former-leader correction that best reduces PRIMARY-VOTE error, 25 Nov 2026

Pete, 25 Nov (after the scaled cut was refused on log loss): *"surely if there's a bias here we can find a
version that improves primary RMSE, even if it can't improve log loss?"* Committed before any variant is
scored. Script: `scripts/former_leader_variants.R` on the seat_quick cache (`45c2997405f4`, 35 elections,
published config, final shares as the simulator receives them).

## Cases and split

The former-leader seats of `former_leader_seats()` in the 35 cached elections (33 seats in 22 elections;
the same set the flat arm moves). **Train**: elections before 2024. **Held out**, scored ONCE at the end for
the champion only: the 2024-2026 elections (qld2024, wa2025, fed2025, sa2026; nt2024 has none). Every size
or shape is fitted time-forward: for a target election, only former-leader seats of elections before it.

## Metric

- **PRIMARY**: squared error of the former leader's party's primary at its former-leader seat (one cell per
  seat), summed; change against the baseline, SE clustered on election (the cell-level SE of the mean times
  n, as `quick_share_diff()` does). Reported as RMSE before and after, with n.
- **ALSO PRIMARY, must not get worse**: squared error over EVERY cell of the moved seats (the freed share
  goes to other parties, and where it goes is one of the variants).
- **Secondary, reported**: seat-winner log loss on the moved seats and over all 2,931 seats (seat_quick, 20k
  sims, one seat per call, common random numbers). Do-no-harm is no longer a gate (Pete), but its cost is
  stated for every variant.

Fitting target: `r = actual - final baseline share` for that party in that seat, less that class's median
`r` over every seat of that election (the seat-specific part, as `former_leader_bonus()` does on the tree
prediction). The applied cut does not subtract anything for the target election.

## Rounds (one change each, against the current champion; train only)

1. flat: one pooled mean, shrunk toward 0 by `mu^2 / (mu^2 + se^2)`; freed share proportional (today's).
2. where the freed share goes: to the seat's runner-up (largest other party in the baseline shares)
   instead of proportionally.
3. size by role at the previous election (gov / opp / minor), partially pooled toward the pooled mean
   (`tau^2` by method of moments, as `.role_pooled_bonus()`).
4. size by whether the former leader is a candidate in that seat at the target election (from that
   election's nominations, `output/candidacies.csv`: known before polling day), partially pooled.
5. size by whether the seat had a by-election between the previous general election and the target
   (`external/reference/byelections/byelection-winners.csv`), partially pooled.
6. cut only where the base still carries the leader's personal vote: the leader is NOT standing there and
   there was NO by-election since; size = shrunk mean over such seats; 0 elsewhere.
7. size scaled by the leader's tenure (number of earlier same-jurisdiction elections they led the party at,
   from the leaders table), through-origin slope shrunk by `b^2 / (b^2 + se^2)`.

**Keep rule**: a round's change replaces the champion if, on TRAIN, it lowers both the targeted and the
all-moved-cell squared error against the champion, paired on the same cells. With the noise floor below,
no single round is expected to clear 2 SE; a kept round is "lower", never "shown better". After two rounds
in a row with nothing kept, stop adding and report.

What would make an apparent win unacceptable: any input dated after polling day (nominations and
by-elections before it are allowed); a group size that is an unshrunk raw mean; a variant whose cut turns
into a bonus in most seats.

## Noise floor (computed from the BASELINE residuals only, before any variant is scored)

(filled in below by `former_leader_variants.R --noise-only`, committed before the variant run)

Run 25 Nov, before any variant was scored (`--noise-only`, baseline residuals only):

- 39 former-leader seats in 27 elections; **train 33 seats in 23 elections**, held out 6 in 4. Leader still
  standing in the seat: 4. By-election since the previous general election: 21 (most departing premiers
  resign mid-term). These two flags come from table lookups (candidacies, byelection-winners.csv) and were
  not hand-checked row by row.
- Train targeted RMSE 6.07 points; mean error (actual minus predicted) -2.30 (SE 0.99, clustered on
  election): the over-call is real at about 2.3 SE.
- **The best any constant cut could do, chosen in hindsight**: squared error 1,217 -> 1,042 (-14.4%, RMSE
  6.07 -> 5.62). The SE of that change is about 151, so a 2-SE result needs about -301, which no
  constant can reach. **This set cannot SHOW any version better; it can only show which way the point
  estimate goes.** Every round is therefore read as direction plus SE, never as a verdict, and the
  held-out set (6 seats) is a sign check only.

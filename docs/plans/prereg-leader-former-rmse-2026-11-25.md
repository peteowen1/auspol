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

## Result (25 Nov 2026, about 1:20pm; `former_leader_variants.R`, cache 45c2997405f4)

Rounds on TRAIN (elections before 2024; 30 seats moved, since the time-forward fit is 0 where fewer than 3 earlier
seats exist). Squared-error change is variant minus baseline (negative is better), SE clustered on election;
"targeted" = the former leader's party's cell (n 30), "all" = every cell of the moved seats (n 197); log loss
per touched seat and over all 2,931 seats (lower is better):

| round | targeted RMSE | targeted SSE change (SE) | bias | all-cell SSE change (SE) | log loss touched (SE) | log loss all (SE) |
|---|---|---|---|---|---|---|
| 1 flat, proportional | 6.231 -> 6.127 | -38.6 (69.0) | -2.14 -> -1.47 | +0.2 (87.7) | +0.0275 (0.0152) | +0.00028 (0.00015) |
| 2 flat, to runner-up | 6.231 -> 6.127 | -38.6 (69.0) | same | +53.6 (95.5) | +0.0298 (0.0165) | +0.00031 (0.00016) |
| 3 by role | 6.231 -> 6.148 | -31.0 (71.2) | -1.44 | +12.0 (91.7) | +0.0296 | +0.00030 |
| 4 by leader standing | 6.231 -> 6.142 | -33.3 (75.8) | -1.43 | +10.3 (97.1) | +0.0307 | +0.00031 |
| 5 by by-election since | 6.231 -> 6.183 | -18.1 (72.6) | -1.51 | +20.2 (90.3) | +0.0275 | +0.00028 |
| 6 only where the base carries the vote | 6.137 -> 6.520 (n 9) | +43.7 (56.0) | -3.60 -> -3.06 | +49.8 (60.5) | +0.0234 | +0.00007 |
| 7 by tenure | 6.231 -> 6.219 | -4.7 (50.4) | -1.70 | +51.8 (85.1) | +0.0213 | +0.00022 |

Kept: round 1 only. The prereg said to stop after two rounds in a row with nothing kept (rounds 2 and 3);
rounds 4-7 were run anyway, and none of them would have been kept either, so the stop rule changed nothing.

**HELD OUT (2024-2026, 6 seats in 4 elections, scored once) for flat, proportional**: targeted RMSE 4.558 ->
4.605 (SSE +2.5, SE 31.4); bias -0.48 -> +0.60 (the over-call there was small and the cut overshoots); all
cells +2.1 (SE 38.9) over 42; log loss -0.0266 per touched seat (SE 0.0258), -0.00005 over all seats.

**vic2026**, the flat rule fitted this way on all 35 elections: Mulgrave ALP -0.89, Bulleen LNP -0.89
(Andrews: by-election since, not standing; Guy: no by-election, not standing). The shipped-code fit on the
tree residual gives -1.04 to -1.38.

**Reading.** The over-call is real (-2.30, SE 0.99), and cutting it lowers the targeted error on train in every
variant but two. But the points removed go to the other parties, and their cells get worse by about the
same amount: over every cell of those seats the primary-vote error does not move (+0.2) under the best
variant, and rises when the freed share goes to the runner-up. No variant here improves pooled primary RMSE,
and the held-out seats do not confirm even the targeted gain. Every number is inside one SE, as the noise
floor said it would be.

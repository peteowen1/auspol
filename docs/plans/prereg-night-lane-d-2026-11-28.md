# Prereg: night lane D, vote-type uncertainty (D1) and fat-tailed combine (D2), 28 Nov 2026

Written before any arm ran. Branch `night-lane-d`, off dev `aa7e272f` (A3 on by default).

## Why

Mildura, vic2022: after four small Mallee booths at 7pm (338 votes, 0.9% counted) the model gave the sitting
independent 0.98; she lost. A3 brought it to 0.92. What is left comes from things the night model treats as known.
Pete wants each uncertainty to shrink at its own rate as evidence arrives. Two are untracked:

- **D1, vote type.** An uncounted early or postal block (49% of Mildura's final votes were early, none counted by 9pm)
  is projected at the seat's all-types swing plus a pooled type gap, with no variance of its own. D1 adds, per class,
  `type_var = sum over uncounted non-ordinary units of (size_u / T)^2 * k_t^2 * p (1 - p) * (1 - c_t)` (points^2) to
  the projection variance (`sd^2 = sd^2 + type_var`, after A3). `size_u / T` is the unit's projected share of the seat's
  projected final total, `p` the class's projected share, `c_t` the counted share of that type in the seat (so it
  shrinks as the type reports and is zero once every unit of every type has). `k_t` comes from
  `scripts/fit_night_type_sd.R`: across seats, `d = (type swing) - (ordinary swing)` scaled by `sqrt(p (1 - p))`,
  vote-weighted, within-pair variance plus between-pair variance of the mean gap, on vic2010->14, vic2014->18,
  wa2008->13, wa2013->17, wa2017->21 (5,255 gaps). Every pair ends before fed2022 (21 May 2022), the earliest replayed
  night, so no screened night is in its own fit. Fitted: early 8.16, postal 9.86, absent 8.74, provisional 49.9,
  marked_as_voted 236 (a 40% candidate's early block: 8.16 x 0.49 = 4.0 points). NSW and QLD are out: their
  declaration-vote labels do not map one to one across elections.
- **D2, fat tails.** Lane C's Student-t combine (`combine_prior_projection_t()`, df 4.755 from lane C's fit), ported
  alone, without lane C's variance model. The current sd (table + A3 [+ D1]) is turned into a t scale with the SAME
  variance, `sd * sqrt((df - 2) / df)`: same spread, fatter tails, so a projection far from the prior is down-weighted.

Flags: `--type-sd=on|off|<k>` (D1), `--proj-tails=normal|t` (D2); both OFF by default (night_cycle cfg `type_sd`,
`proj_tails`; `night_loop.R --type-sd --proj-tails`).

## Screen (fixed before running)

`screen.sh` (2,000 draws, snapshots to 9pm, vic2022 + fed2022 + fed2025, the A3 base flags), arms against label `base`:

- `d1`: `--type-sd=on`
- `d2`: `--proj-tails=t`
- `d12`: `--type-sd=on --proj-tails=t`

Scored by `score_vs_base.R` (copy reading `screen/`).

**Primary:** seat-winner log loss over (seat, snapshot) cells with under 15% counted, pooled over the three nights, SE
clustered on seat. **Pass** = all of:

1. primary better (arm minus base below zero) by more than 1 SE;
2. no night's average log loss (all snapshots run) worse by more than 1 SE;
3. wrong 0.99 calls (leader at 0.99+, 10%+ counted, lost) not more than base, summed over nights.

**Named target, reported not decisive:** Mildura vic2022 at 7pm and 8pm: Cupper's win chance, and the IND and LNP
first-preference posterior sd.

**Unacceptable even if it passes:** a pass carried by one night while another is worse by more than 1 SE is already
clause 2; additionally, if D1 moves federal nights by more than vic2022 while federal nights count almost no early
votes by 9pm, check it is acting through the early units before believing it.

A pass here is a screen pass only: the main session runs the full 20k replays before shipping.

## RESULT

(pending)

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

## RESULT (28 Nov 2026, 2am; screen, 2,000 draws, code 7be04b37)

Seat-winner log loss, arm minus base (below zero is better; SE clustered on seat). Primary = cells under 15% counted
(1,382 cells, 389 seats); per night = all snapshots run (vic2022 352 cells, fed2022 1,057, fed2025 900).

| arm | primary diff (SE) | vic2022 night | fed2022 night | fed2025 night | wrong 0.99 calls base -> arm | verdict |
|---|---|---|---|---|---|---|
| d1 `--type-sd=on` | +0.0005 (0.0001) | +0.0038 (0.0016) | +0.0003 (0.0002) | +0.0006 (0.0005) | 2 -> 2 | **FAIL** (worse; vic2022 worse by 2.4 SE) |
| d2 `--proj-tails=t` | -0.0011 (0.0008) | -0.0004 (0.0016) | -0.0008 (0.0010) | -0.0016 (0.0009) | 2 -> 2 | **PASSES the screen** (1.4 SE better, no night worse) |
| d12 both | -0.0009 (0.0008) | +0.0026 (0.0015) | -0.0005 (0.0010) | -0.0014 (0.0008) | 2 -> 2 | **FAIL** (vic2022 worse by 1.7 SE) |

Seats right at the last snapshot (not a pass clause): d2 loses one on fed2022 (148 -> 147) and one on fed2025 (143 -> 142);
d1 and d12 one on fed2022.

**D1 acted mostly on vic2022** (the only night with sizeable early units uncounted in the replay at 9pm); its federal
moves are small, as expected. It helped Mildura (-0.056 summed log loss over its two cells) but widened Croydon,
Northcote, Hastings, Morwell, Mornington, where the projection was right and the extra width only cost confidence.
The vote-type spread is real on the reference pairs, but on these nights the table sd plus A3 already covers it:
adding it in quadrature over-widens.

**D2 is the reverse of the named target.** Same variance with fatter tails means a projection within about one
combined sd of the prior gets MORE weight than the normal gives, so Mildura (prior IND 38.4 sd 8.5, projection near
46) gets more confident in the wrong direction (+0.365 summed log loss over two cells). Its gain comes from seats where
the projection was far from the prior and wrong early (Fowler fed2022 -0.684, Melbourne fed2025 -0.273, Northcote
vic2022 -0.231). Also: with `proj == prior` the t posterior MEAN equals the prior (tested) but its sd is narrower than
the normal one; "reduces to normal" holds for the mean only.

**Named target, Mildura vic2022** (trace, 2,000 draws, same base flags). Cupper (IND) lost, so a lower win chance is
better; posterior sd in share points (afternoon prior: IND 38.4 sd 8.5, LNP 38.7 sd 8.3).

| arm | 7pm Cupper win | 7pm IND / LNP sd | 8pm Cupper win | 8pm IND / LNP sd |
|---|---|---|---|---|
| base (A3) | 0.921 | 5.21 / 5.34 | 0.940 | 2.33 / 2.33 |
| d1 | 0.917 | 5.32 / 5.43 | 0.927 | 2.87 / 2.84 |
| d2 | 0.946 | 4.74 / 4.85 | 0.945 | 2.25 / 2.19 |
| d12 | 0.942 | 4.84 / 4.92 | 0.932 | 2.75 / 2.65 |

D1 barely moves 7pm: at 0.9% counted the projection sd is already wide and the prior dominates, so adding the early
block's variance changes the posterior sd by 0.1. It widens 8pm by about 0.5 points and takes Cupper 0.940 -> 0.927. The
Mildura over-confidence is NOT mainly the uncounted early vote; it is the 2CP step (flow) and the prior, which lane D
does not touch.

**Verdicts:** D1 refused, D12 refused, D2 passes the screen as written but moves its named target the wrong way;
the main session should run the full 20k replays before shipping D2, and Pete should see the Mildura row.

Caveats: `k` was fitted on 5 pairs; nsw2015 -> nsw2019 also maps (prepoll, postal, absent) and ends before 2022, so add it
at any refit. D1 weights each unit by its share of the seat's projected FINAL total (the arithmetic of the seat
share), not of the votes still to come; `--type-sd=<number>` is a `k` (scaled by sqrt(p (1 - p))), not points.
`check_like_ci.R` was not run (tests for lanes A and D and the rep-sd cfg ran and pass).

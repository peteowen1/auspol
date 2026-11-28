# Prereg: night per-booth best guess (lane F), 28 Nov 2026 (election day)

Written before any arm ran, about 7:30am. Pete's design (28 Nov, 7am): "we need a best guess for every booth that
updates with all information, then we can sum up the booths".

## Why

Mildura, vic2022. The live projection gives every uncounted booth the SAME swing per class (the vote-weighted swing of
the counted booths of its type). At 8pm the 17 counted booths swung in opposite directions: the Mallee booths about 15
to 32 points away from the Coalition, the big Mildura town booths (Irymple, Mildura West, Cardross) about 8 points to
it. Pooled, that is roughly zero, applied to uncounted booths that are mostly town booths and to the early vote (16,077
votes in 2018, 40% of the seat), which swung like the towns (Coalition 37.0 to 43.8). A scratch run on the saved 8pm and
9pm Mildura data (`booth_guess.R` in the session scratchpad) cut the vote-weighted booth error on the Coalition share
from 6.5 to 4.9 points at 8pm and 4.1 to 2.7 at 9pm. A1 (one straight-line slope on the booth's own 2018 share) is a
cruder form of the same idea and failed again on top of A3 + D2 this morning (pooled +0.0012, SE 0.0018; fed2025 worse
by 2.1 SE).

## The change

`project_seat_from_booths(booth_knn = list(h, k, size_w, types))`, `NULL` (default) byte-identical. Each uncounted
ORDINARY booth with a reference gets its own swing per class:

```
sw_b(c) = base(c) + sum_j w_bj * (y_j(c) - base(c)) / (sum_j w_bj + k)
w_bj    = (votes_j / median booth) * exp(-d_bj^2 / (2 h^2))
d_bj^2  = sum over reference classes of (100 * (ref share_b - ref share_j))^2 + (size_w * (log ref votes_b - log ref votes_j))^2
```

`j` runs over the counted ordinary booths with a reference, `y_j(c)` is booth j's own swing, `base(c)` the current
ordinary swing (unchanged rule). So a booth with no similar counted booth keeps today's swing (partial pooling, no
cliff). With `types = TRUE`, an uncounted early / postal / absent / other unit whose type has NO counted unit takes,
instead of the all-types counted swing, the swing of ALL the seat's ordinary booths (counted: own swing; uncounted:
the guess above), weighted by their reference votes, plus the existing type gap. A counted type keeps its own swing.

Fixed in advance, no sweep: **h = 10 points, k = 1 median booth, size_w = 10, types = TRUE**. Cannot be combined
with A1 (`booth_reg_k`). Flag `--booth-knn=10,1,10,1` (h,k,size_w,types).

## Screen (fixed before running)

`screen.sh` (2,000 draws, snapshots to 9pm, vic2022 + fed2022 + fed2025, live flags A3 + D2), arms against `a3d2`:

- `bk`: `--booth-knn=10,1,10,1` (as above)
- `bko`: `--booth-knn=10,1,10,0` (ordinary booths only; the early vote keeps today's rule), reported to separate the parts

Scored by `score_screen_a3d2.R`. **Primary:** seat-winner log loss over (seat, snapshot) cells under 15% counted,
pooled over the three nights, SE clustered on seat. **Pass** (the `bk` arm decides) = all of:

1. primary better (arm minus base below zero) by more than 1 SE;
2. no night's average log loss (all snapshots run) worse by more than 1 SE;
3. wrong 0.99 calls (leader 0.99+, 10%+ counted, lost) not more than base, summed over nights;
4. seats right at the last snapshot not fewer than base, summed over nights.

**Named target, reported not decisive:** Mildura vic2022 at 7, 8 and 9pm (Cupper's win chance).

**Unacceptable even if it passes:** a pass that comes from Mildura alone (leave Mildura out: primary must still be
below zero), or from a night whose booths are mostly unmatched to a reference (check the arm changed cells on every
night). A pass here is a screen pass only: full 20,000-draw replays to 2am on all three nights before shipping, with
the same four clauses on the full run. Cutoff: Pete's 1pm; anything not passed by then stays off.

## RESULT (28 Nov 2026, 7:40am; screen, 2,000 draws, code 970bf419): FAIL, stays off

Seat-winner log loss, arm minus base `a3d2` (below zero is better; SE clustered on seat). Primary = cells under 15%
counted (1,382 cells, 389 seats); per night = all snapshots run (vic2022 352 cells, fed2022 1,057, fed2025 900).

| arm | primary | vic2022 | fed2022 | fed2025 | wrong 0.99 calls (base 2) | seats right (base 374) | verdict |
|---|---|---|---|---|---|---|---|
| `bk` (deciding) | -0.0004 (0.0005) | +0.0009 (0.0019) | -0.0014 (0.0010) | +0.0014 (0.0023) | 2 | 376 | **FAIL clause 1** (0.8 SE, needs > 1) |
| `bko` (reported) | -0.0004 (0.0003) | -0.0011 (0.0012) | -0.0012 (0.0007) | +0.0002 (0.0013) | 2 | 376 | (not deciding) |

Mildura (Cupper's win chance, she lost): a3d2 0.95 / 0.94 / 0.45 at 7 / 8 / 9pm; `bk` 0.95 / 0.90 / 0.49; `bko` 0.95 /
0.92 / 0.44. Seat-level traces on the saved Mildura data: the guess moves the uncounted town booths the right way
(Coalition swing +1.8 to about +6.4 at 8pm against finals of +6 to +13), but the early vote (40% of the seat, no
similar counted unit) only moves from +1.8 to +2.6 against a final +6.8, and that block decides the seat. Nothing is
worse by more than 1 SE and both arms gain 2 seats right at 9pm, so the effect is real but too small to clear the bar.
Stays OFF (`--booth-knn` absent). Pete told in conversation, 28 Nov.

## Amendment 1 (28 Nov 2026, about 8:15am): Pete's override, visible, original clauses unedited

Shown both arms and Mildura, Pete chose "Both": B1c (PR #294) and `bko` (polling booths only, `--booth-knn=10,1,10,0`) ON
for tonight, although `bk` was the arm named to decide and it failed clause 1. This is his override, not a pass.
Joint screen of B1c + `bko` against `a3d2` (2,000 draws, to 9pm, code 4cb9de21): primary -0.0010 (SE 0.0008); nights
vic2022 -0.0066 (0.0063), fed2022 -0.0014 (0.0008), fed2025 -0.0001 (0.0013); wrong 0.99 calls 2 = 2; seats right
376 vs 374 base. B1c alone was -0.0006 (0.0007). Mildura (Cupper, lost) 7 / 8 / 9pm: 0.85 / 0.86 / 0.29 (a3d2 0.95 /
0.94 / 0.45). Full 20,000-draw replays to 2am follow, before the ship.

## Amendment 2 (28 Nov 2026, about 9:10am): vote types matched to similar booths, written before the arm ran

Pete (9am): "I asked for full booth level with vote type - surely that's the best way". New mode `types = "knn"`
(flag `--booth-knn=10,1,10,2`): each uncounted early / postal / absent / other unit whose type has no counted unit keeps
its current swing (all-types counted swing + type gap) PLUS the kernel-weighted deviation of the counted polling booths
whose reference shares look most like ITS OWN reference shares (same h = 10, k = 1; no size term). Checked before the
screen on the saved Mildura data only (not scored): early swing at 8pm +1.8 -> +5.7 (final +6.8); seat 8pm Cupper /
Coalition 45.3 / 41.6 -> 44.0 / 43.2, 9pm 42.4 / 43.5 -> 41.8 / 44.4 (final 41.2 / 45.0).

Arm `bkt`: live flags (A3, D2, B1c `--tcp-cand=1`) + `--booth-knn=10,1,10,2`, against arm `both` (the live night as
shipped: same flags + `--booth-knn=10,1,10,0`). Same screen, same four clauses (primary better by more than 1 SE; no
night worse by more than 1 SE; wrong 0.99 calls not more; seats right not fewer), then full 20k runs with the same
clauses. Pass -> ON by the standing rule; fail -> Pete's call. Cutoff for changes 2:45pm (Pete: "we have 6 hours").

## Amendment 3 (28 Nov 2026, about 9:00am): `bkt` screen FAILED clause 1; ON by Pete's override

Screen of `bkt` against `both` (2,000 draws, to 9pm, code 102afb8c): primary +0.0000 (SE 0.0003), FAIL clause 1. Under
15% counted: vic2022 +0.0013, fed2022 -0.0001, fed2025 -0.0005. Night averages vic2022 -0.0013 (0.0031), fed2022 +0.0002
(0.0004), fed2025 +0.0015 (0.0016): none worse by 1 SE. Wrong 0.99 calls 2 -> 1; seats right equal. Mildura 7 / 8 / 9pm
0.85 / 0.86 / 0.29 -> 0.85 / 0.74 / 0.21; worst moves Croydon (Labor 0.21 -> 0.41 at 8-9pm, Liberal won) and
Mornington (independent 0.23 -> 0.37 at 9pm, Liberal won), both close. In the 2022 replay feed Mildura's early votes
arrive in one lump at 11pm, so the vote-type rule acts for a few hours only. Pete chose "On, your override".
`.NIGHT_BOOTH_KNN` -> "10,1,10,2"; off-switches `--loop=--booth-knn=10,1,10,0` (back to polling booths only) or `off`.
Each early voting centre as its own unit (Pete's fuller version) cannot be built: no 2022 or 2018 result by early
voting centre exists (the VEC published one early total per district), the 2026 centres are new, and no replay feed
carries early votes by centre.

## Amendment 4 (28 Nov 2026, about 9:35am): full runs of `bkt` FAIL a guard; merged by Pete's second override

Full 20,000-draw replays to 2am of `bkt` (code 102afb8c) against `ship2` (the live night, B1c + polling-booth guess):
under 15% counted +0.0000 (SE 0.0002); vic2022 +0.0013, fed2022 -0.0001, fed2025 -0.0002. Whole night: vic2022 -0.0001
(0.0016), fed2022 +0.0011 (0.0011), **fed2025 +0.0044 (0.0030), 1.5 SE worse: fails clause 2**. Wrong 0.99 calls 18 = 18;
seats right 382 = 382. Mildura 8 / 9 / 10 / 11pm 0.86 / 0.30 / 0.25 / 0.15 -> 0.74 / 0.22 / 0.17 / 0.18. Worse: Croydon,
Mornington (vic2022); Wills, Cowper, Forrest, Calwell (fed2025). Told Pete; he chose "Merge anyway". PR #295 merged
(main 882638aa). Back to polling booths only mid-count: `--loop=--booth-knn=10,1,10,0`.

## Amendment 5 (28 Nov 2026, 12:35pm): a learned strength per vote type, written before the fit or any run

**Why.** Amendment 4's full runs failed the fed2025 guard, and the trace put 11.2 of the 17.3 lost on Wills: its postal
vote (15,028) was matched with 93% weight to three Greens-surging booths, so it was projected GRN +8.0 / ALP -4.1 when
the truth was +1.4 / -0.6. Early votes followed their look-alike booths (GRN +5.0 projected and actual); absent votes
overshot (+4.1 against +0.8). So the look-alike deviation is right for some vote types and too strong for others.

**The change.** `types = "knn"` multiplies each vote-type unit's look-alike deviation by a strength `beta` for its type
(early, postal, absent, provisional, other). `beta = 1` is today's live behaviour; `beta = 0` is polling booths only.

**How beta is fitted (fixed now).** From past full counts, pairs fed2019->2022, fed2022->2025, vic2018->2022,
nsw2019->2023, qld2020->2024, sa2022->2026, wa2021->2025 (those with matched vote-type units; the count per pair and type
is printed, and a pair with none drops out visibly). For each seat, a synthetic night through the shipped
`project_seat_from_booths()`: a set of polling booths counted, every vote-type unit uncounted; the look-alike deviation
is captured from the function itself. `beta_type` is the vote-weighted slope of (actual unit swing minus the counted
booths' swing) on the deviation, with a separate mean per election x type x class, so beta does not absorb a type's
lean. Fitted at TWO count levels: every polling booth counted, and the smallest quarter of booths counted (the early
night the metric scores). The early-night beta ships if the two differ. Each type's beta is shrunk toward the pooled
beta by its precision (tau^2 / (tau^2 + se^2)), no minimum n, clipped to [0, 1].

**Leakage.** Each replayed night uses a beta fitted WITHOUT its own pair (`--knn-beta` on the replay). That is
leave-one-out, not time-forward: fed2022's fit includes fed2025 and later state pairs, and no earlier federal pair is on
disk. So beta is printed per fold; folds that agree (within 0.15) make the leak immaterial, folds that swing are a no-go.
Tonight's value is the all-pairs fit.

**Screen (2,000 draws, to 9pm, three nights), against the live config** `--rep-sd=0.0458,0 --proj-tails=t --tcp-cand=1
--booth-knn=10,1,10,2` (beta 1), plus the vic flags:
1. Primary: fed2025 seat-winner log loss on cells under 15% counted is better than the live config (the guard that failed).
2. Guards: vic2022 and fed2022 not worse by more than 1 SE (clustered on seat); wrong 0.99 calls not more; seats right not fewer.
3. Mildura (vic2022): Cupper's win chance at 9pm not above 0.26 (live 0.21) and at 8pm not above 0.80 (live 0.74).
4. Wills fed2025: the postal guess moves from GRN +8.0 toward +1.4.
5. Limiting cases, in tests: beta = 1 for every type is byte-identical to today; beta = 0 leaves vote-type units at their
   swing without the deviation.

**Not acceptable even if 1 passes:** a beta fitted to make Wills pass (the fit never sees a replay score); a pass that
needs a beta outside the fold range. **Deadline:** no passing screen by 1:45pm, or full runs not done by 2:45pm: the live
config stays `10,1,10,2`. A guard failure goes to Pete, not merged on my judgement.

### Amendment 5 RESULT (28 Nov 2026, 12:55pm): the fitted strength is 1, so nothing changes; no code, no screen run

Fit as written above (`fit_knn_beta.R`, through the shipped function): 6 pairs with matched vote-type units (sa2022 has
none and dropped out), 594 seats, 2,561 vote-type units, 25,910 unit x class rows, two count levels.

Raw beta (SE, clustered on seat), 1 = today's live behaviour:

| count level | early | postal | absent | provisional |
|---|---|---|---|---|
| smallest quarter of booths counted | 1.40 (0.16) | 1.11 (0.11) | 1.03 (0.14) | 1.33 (0.17) |
| every booth counted | 1.44 (0.10) | 0.96 (0.12) | 1.08 (0.12) | 1.48 (0.16) |

Shrunk and clipped to [0, 1], every type is 1.00, in the all-pairs fit and in every leave-one-election-out fold (lowest
0.975). By size of the deviation, postal's beta is 1.17 to 1.66 where the deviation is over 1 point: large deviations are
not over-strong either. Postal in fed2025 alone is 0.93. One election disagrees: qld2024 (postal -0.09, early 0.58).

**Reading.** Across past elections, vote-type units move with their look-alike booths about one for one, postal
included. Wills 2025 was one seat's miss, not a pattern, so a learned beta has nothing to correct and would ship as
beta = 1, which is the live config. Clauses 1 to 5 were not run: there is no arm. Live stays `--booth-knn=10,1,10,2`.
Not tried (no time before the cutoff): a beta above 1, which the raw fits point to for early votes; it is outside the
[0, 1] range fixed above and stays a post-election question.

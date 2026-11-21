# Pre-registration: One Nation's seat vote from a direct model, not rank + a forced spread (2026-11-22)

Status: BUILT BEHIND `AUSPOL_ONP_ALLOC` (default "rank"). Criteria below written before any harness arm ran.

## Why

Pete, 22 Nov: "forcing the spread is way more hacky than just modelling using features like previous senate,
previous vote, demos, using shrinkage as needed". Today a seat with no One Nation history gets a fixed shape handed
out by rank on its Senate vote and stretched to a set spread (`AUSPOL_ONP_CV` 0.365 live; a time-forward law in the
backtests). `reviews/onp-demographics-and-spread-2026-11-22.md` found that spread 1.34 to 1.44 times too wide at the
two elections like Victoria (sa2026, qld2017), and that Year 12 carries weight of its own beside the Senate share.

## Not the first Senate-value rule

`AUSPOL_ONP_ORDER=senate` (plans/prereg-onp-senate-2026-10-01.md, from Pete's chart) put each seat's Senate share
through ONE earlier election's log curve. It cut One Nation's share error (5.42 to 5.00) and was REFUSED on its
unacceptable-win clause: sa2026 seat log loss 0.2376 to 0.2641 (1.7 SE), Ngadjuri (won by One Nation) 0.695 to
0.398. The tree step was already correcting geography. What is new here: every earlier election pooled into one fit,
Year 12 beside the Senate share, and no curve borrowed from a single election. The same clause applies below.

## The change

`AUSPOL_ONP_ALLOC=model`, inside `onp_newseat_apply()` (all seven harnesses) and `fit_seats_full.R`:

    seat ratio = exp(b_s x s + b_y x y12), divided by its mean

`s` = log(Senate One Nation share + 0.5) minus the mean over the seats being allocated; `y12` = Year 12 completion
as a z-score over the same seats (a seat with no census row takes 0). `b_s`, `b_y` from `onp_model_fit(target)`: a
log-link count model (quasi-Poisson) of the seat share on election + `s` + `y12`, over every seat One Nation
contested in every election dated strictly before the target that has 10+ seats with a Senate share and a census
row. Each election keeps its own level; the two effects are shared. The spread is whatever the model gives.

Fixed before the harness runs:

- **Form.** The first build used `log(share + 1)` with elections weighted equally. Its slope depended on the level
  (0.08 fitted before qld2017, 0.41 before sa2026) because the `+1` flattens low-vote elections; replaced by the
  log link, which has no offset. Both were scored once at share level (below); no further form is tried.
- **Training elections.** No level cut. Low-vote elections stay in and weigh little (a count model weights by the
  share). The only floor is 10 usable seats, the one `onp_newseat_cv()` already uses.
- **Fallback, printed.** Fewer than 2 earlier elections, or census for under 90% of the target's seats: the rank
  rule runs and `ONM1!` says so (wa2017: census gap). In the live script either is a hard stop.
- **Pooling.** One shared slope is what a new election is predicted with under partial pooling too; the random
  slope by election (`lme4`, the screen) changes a NEW election's point prediction by nothing. It would matter for
  the simulation's uncertainty, which this arm does not change.

## Seen before the harness runs (share level, not the test)

Package functions, time-forward, all contested seats, both rules given the actual level. RMSE in points:

| Target | Level | Rank rule | Model | Spread actual / rank / model |
|---|---|---|---|---|
| sa2026 | 23.0 | 3.14 | 2.76 | 0.33 / 0.35 / 0.33 |
| qld2017 | 20.8 | 4.26 | 3.49 | 0.28 / 0.34 / 0.24 |
| nsw2023 | 9.7 | 1.91 | 1.74 | 0.31 / 0.40 / 0.22 |
| nsw2019 | 8.1 | 2.09 | 1.70 | 0.33 / 0.40 / 0.25 |
| qld2024 | 8.0 | 3.00 | 2.96 | 0.55 / 0.41 / 0.33 |
| fed2019 | 7.9 | 2.47 | 2.85 | 0.58 / 0.39 / 0.27 |
| qld2020 | 7.4 | 2.67 | 3.03 | 0.63 / 0.41 / 0.33 |
| fed2025 | 6.5 | 2.07 | 1.93 | 0.49 / 0.42 / 0.38 |
| wa2025 | 5.8 | 1.68 | 1.50 | 0.37 / 0.44 / 0.29 |
| fed2022 | 5.1 | 1.38 | 1.31 | 0.55 / 0.44 / 0.45 |

Seat-weighted 2.53 to 2.43; better in 8 of 10. (The `log + 1` form: 2.51, better in 6.) This scores the allocation
alone on every contested seat. The harness applies it only to no-history seats and then runs the trees, which is
where the 1 Oct rule lost, so none of this clears the arm. Victoria at 20.4: slope 0.577, Year 12 -0.095, spread
0.380 (the forced 0.365 delivers 0.379), top five 36.8, bottom five 9.2.

## Criteria

Screen first (`quick_arm.R`, the switch is post-xgb so the screen sees it): sa2026 alone, then the One Nation
elections, then all 35 as the deciding rebuild pair.

1. **Applied.** `ONM1` prints for the target and the changed-cell count is non-zero, read before any score.
2. **Primary**: One Nation share squared error on the seats the arm moved, arm minus base, SE clustered on
   election. PASS if lower by more than 1 SE.
3. **Guard**: pooled seat log loss not worse by more than 1 SE.
4. **Leave-one-election-out**: the primary keeps its sign with any one election dropped.
5. **Unacceptable win** (the 1 Oct clause): sa2026 or qld2024 seat log loss up by more than 1 SE (by seat), or a
   seat One Nation actually won losing more than 0.10 of its win probability. Then it goes to Pete as a split.

Stop rule for the screen: if sa2026 seat log loss worsens by more than 1 SE, stop and report before running more.

Decision: all pass on the rebuild pair, Pete decides with the live walk. Otherwise it stays "rank".

## Screen, step 1: sa2026 alone (22 Nov, 10:29am; 1,000 simulations, baseline and arm on one seed)

Applied: `ONM1 sa2026: ... 26 no-history seat(s): Senate slope 0.579, Year 12 -0.097 per sd, fitted on 784 rows / 15
earlier elections; spread sd/mean 0.319, not forced` (the rank rule's line: CV 0.371). 92 of 329 cells changed, 21
of 47 seats moved.

| sa2026, through the trees | Rank rule | Model |
|---|---|---|
| Seat log loss (lower is better) | 0.2292 | 0.2275 |
| One Nation share RMSE, all 47 seats | 4.21 | 4.26 |
| One Nation share RMSE, the 24 seats whose One Nation cell moved | 3.83 | 3.95 |
| Largest change in any win probability | | 0.062 |

The stop rule does not fire (log loss fell; no seat near the 0.10 clause). But it is a wash: the share error is a
touch worse and the log loss a touch better, both far inside noise for one election. The share-level gain (3.14 to
2.76 on all 47 seats with the actual level given) does not survive the harness, where only the 26 no-history seats
are allocated, at a level of 17.2, and the trees then correct geography themselves. That is the 1 Oct finding again,
without the harm.

Found on the way: `quick_arm.R` took 28 minutes to start because `quick_tree_sig()` called `file.info()` over
`external/reference`; now `file.size()` and `file.mtime()`, 17.5 s, digest identical.

## Screen, step 2: 12 One Nation elections (22 Nov, 10:44am) -- PRIMARY FAILS; the switch stays "rank"

`quick_arm.R "AUSPOL_ONP_ALLOC=model" --pairs=sa2026,qld2017,qld2020,qld2024,wa2017,wa2025,nsw2019,nsw2023,sa2022,fed2019,fed2022,vic2022`,
1,000 simulations, one seed. Log: `deciding-runs/20261122-onp-spread-walk/qa-onp-all.log`. `ONM1` printed for 11
elections; wa2017 printed `ONM1!` (census gap) and ran the rank rule, byte-identical to its baseline. 751 of 7,469
cells changed.

| Criterion | Result | Verdict |
|---|---|---|
| 1. Applied | 11 of 12 elections, 751 cells | yes |
| 2. Primary: squared error on the changed cells | 17,370.8 to 17,720.4, +349.5 (+2%), SE 208.7 over 11 elections | FAIL (worse by 1.7 SE) |
| 3. Guard: seat log loss, 1,067 seats | 0.2664 to 0.2679, +0.0015 (SE 0.0016) | within 1 SE |
| 5. Unacceptable win | sa2026 -0.0017, qld2024 0.0000; largest win-probability change 0.089 (qld2017) | not tripped |

By election, squared-error change on changed cells then seat log loss change: qld2017 -60.3, +0.0184; fed2019
+179.6, +0.0005; nsw2019 +65.0, 0; sa2026 +50.6, -0.0017; qld2020 +27.6, -0.0006; nsw2023 +24.6, 0; qld2024 +24.1,
0; wa2025 +20.3, +0.0001; fed2022 +12.4, -0.0004; sa2022 +5.2, 0; vic2022 +0.5, 0. Worse on shares in 10 of 11.

Reading: the allocation scored by itself favours the model (2.53 to 2.43, better in 8 of 10). Through the full
model it does not, because the tree step already moves One Nation's seats toward where the Senate vote and the seat's
history say they belong; a second, different statement of the same geography in front of it adds error. This is the
1 Oct result again with a better-specified model. No rebuild pair is run and no further form is tried (fixed above).

What was given to it: 2 features (Senate share, Year 12) chosen from 7 census columns and 4 Senate class shares
after the 7-column version did worse at share level (3.99 against 3.85); linear on the log scale; one pooled fit;
no simulation uncertainty. NOT tried, and the honest next version if this is picked up after the election: the
Senate share and within-election Year 12 as inputs to the tree step itself, which is where the geography is
actually decided.

Caveat for Victoria: backtests allocate only the no-history seats (26 of 46 in sa2026), Victoria all 88, so the
backtests under-test the live case; the live walk was not run because the arm failed its primary.

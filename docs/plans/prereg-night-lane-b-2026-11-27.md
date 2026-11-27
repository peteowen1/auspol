# Pre-registration: night lane B, the two-candidate step (27 Nov 2026, before any replay is scored)

Lane B of [overnight-2026-11-27-night-fixes.md](overnight-2026-11-27-night-fixes.md). Pete asked (27 Nov, ~9:15pm) for
same-class candidates as their own candidates (item 1), flows by vote type (item 4, flow side), and flows learned on
the night with a Bayesian update (item 5). Written and committed before any replay of these switches was scored. The
only runs before this file were one-seat traces of Mildura vic2022 and Melbourne fed2025 (the two cases in the brief),
so those two are **development seats**, and the primary is also reported without them.

## What each switch does (all OFF by default; off, the code path is the one before them)

**B1 `same_class`** (`--same-class=1`; `night_run_update(same_class = TRUE)`; `R/night_flow.R`).
The simulator counts each class as one candidate except for ONE split per seat, and the Coalition split takes that
slot. In Mildura vic2022 the state carries a Coalition split (Liberal r 0.27, f 0.72), so the night class split's
independent junior was skipped, and Milne and Brymer (1,001 of the 5,128 independent votes counted by 9pm) were
assumed to hand Cupper every vote: the Liberal's votes leaked away from Benham, the independents' leaked nowhere.
Two parts:
1. `night_same_class_shift()`: for every seat with 2+ counted candidates of one class the simulator did NOT split
   (Coalition-split seats' minor juniors, and every third or later candidate), each draw whose final pair holds that
   class moves by `j (1 - g)`: `j` = the class's updated share times the counted junior fraction; `g` = the share of
   such votes that end with the class's senior candidate when only the two final classes remain, fitted from the
   transfers files of elections BEFORE the night (`night_same_class_params()`, shrunk by jurisdiction as
   `coalition_f()`). Juniors' exclusion order and the pair itself are left as each draw had them (an approximation).
2. `night_tcp_obs(cand_level = TRUE)`: the counted two-candidate flow is read against each finalist class's SENIOR
   candidate, so the juniors' votes are part of the others whose flow is measured. Class level, a counted pair below
   the class's first preferences clamps the flow at 0 (Mildura 9pm: Cupper's 5,211 two-candidate votes against the
   independents' 5,128 primaries).

**B2 `flow_pool`** (`--flow-pool=1`; `night_flow_pool()`). For each seat with a counted pair, the residual
`d = counted flow - median draw flow`. Normal hierarchy by final-pair type T (sorted classes, e.g. `ALP|GRN`):
`d_s = mu_T + e_s + noise`, `e_s ~ N(0, tau^2)`, noise sd = the count's own `flow_se`, `mu_T ~ N(0, sigma^2)`.
`tau^2` and `sigma^2` are method-of-moments estimates from the night's own residuals (within-type spread less sampling;
mean squared type mean less its variance), so `sigma = 0`, and nothing moves, when the counts show no common error.
Every seat's draws holding a counted pair type shift by the posterior mean of `mu_T` from the OTHER seats (its own
count is applied afterwards by `night_apply_tcp()`, not twice). Northcote's count informs Richmond; Wills, Cooper and
Macnamara inform Melbourne fed2025. Difference from the refused 0.065 flow-sd floor: that changed the WEIGHT of a
seat's own count; this moves the CENTRE of every seat of the type, from other seats' counts.

**B3 `tcp_by_type`** (`--tcp-by-type=1`; `night_tcp_obs(by_type = ref)`). The seat's flow becomes the mix of
per-vote-type flows (ordinary, and each declaration type the commission reports as one unit), weighted by each type's
share of the others' votes at the reference election. A type's flow = the seat's ordinary flow plus a gap: the seat's
own counted gap partial-pooled toward the night's mean gap for that type, or the mean gap alone where uncounted.

**No constant in B2 or B3 is fitted on any night**: their terms come from the night's counts as they arrive. B1's `g`
is fitted only on elections before the scored night (`night_same_class_params()`, test "time-forward"). So the
leave-one-night-out rule is satisfied by construction; nothing here is refitted on the scored nights.

## Scored data

The three real-night replays: vic2022 (VEC hourly feed, `scripts/night_replay_vec.R`), fed2022 and fed2025 (AEC feed,
`scripts/night_replay_feed.R`). Base = the live night settings these scripts can express: `--pair-cal=0.945244,0.681490
--class-split=1` (cand-ref off on the feed, proj-sd old). Full sims (the states' 20,000).

**B3 is scored on vic2022 only**: the federal replays count no declaration vote (`night_replay_feed.R` header), so
`tcp_by_type` sees ordinary booths only there and is near-identical to base. It therefore cannot be checked on a second
night, which is a stated weakness: a vic2022-only pass is reported to Pete as such, not switched on by Claude.

## Named seats (primary), from the data before any scoring

`scripts/night_lane_b_seats.R`: seats whose final two has a same-class candidate beside a finalist (another candidate
of a finalist's class on 3%+ of first preferences) or a third candidate of consequence (third place on 15%+).

- vic2022 (25): Albert Park, Bass, Caulfield, Essendon, Euroa, Footscray, Geelong, Hawthorn, Ivanhoe, Kew, Malvern,
  Melbourne, Mildura, Mornington, Morwell, Mulgrave, Oakleigh, Pascoe Vale, Polwarth, Prahran, Preston, Richmond,
  Ringwood, Shepparton, Williamstown.
- fed2022 (45): Adelaide, Berowra, Bonner, Boothby, Bradfield, Brisbane, Calare, Canberra, Clark, Cooper,
  Corangamite, Cunningham, Durack, Fenner, Fowler, Franklin, Fraser, Fremantle, Gellibrand, Grayndler, Griffith, Groom,
  Higgins, Hume, Indi, Jagajaga, Kennedy, Kingsford Smith, Lilley, Macnamara, Maribyrnong, Mayo, McPherson, Melbourne,
  Moreton, Newcastle, Nicholls, North Sydney, Perth, Richmond, Ryan, Sturt, Sydney, Wannon, Wills.
- fed2025 (51): Adelaide, Barton, Bean, Bendigo, Blaxland, Boothby, Bradfield, Brisbane, Bullwinkel, Calare, Calwell,
  Canberra, Capricornia, Cooper, Corio, Cunningham, Durack, Farrer, Fenner, Fisher, Flinders, Forrest, Franklin,
  Fraser, Fremantle, Gellibrand, Grey, Griffith, Groom, Hunter, Jagajaga, Kennedy, Lalor, Lilley, Lyne, Macnamara,
  Maribyrnong, Mayo, Melbourne, Monash, Moreton, Newcastle, O'Connor, Page, Perth, Richmond, Ryan, Sturt, Swan,
  Sydney, Wright.

## Metric, criterion, decision rule

`scripts/score_night_lane_b.R --dir=<out> --base=lbbase --arm=<label>`. Seat-winner log loss = -log(probability given
to the party that won), floored at 1e-6, lower is better; per seat averaged over the night's replay times
("night-average"); SE = sd of the per-seat arm-minus-base difference over sqrt(seats) (the seat is the unit).

- **Primary**: pooled over the three nights' named seats (121 seat-nights; vic2022 only for B3), the arm's mean
  night-average log loss minus base's is **below 0 by more than 1 SE** (SLB3 line).
- **Guard 1**: on each night, the all-seat night-average log loss is not worse by more than 1 SE (SLB2 `guard`).
- **Guard 2**: wrong 0.99 calls (top party at 0.99+, did not win, seat 10%+ counted; counted in seat-times) not more
  than base, each night.
- **Guard 3**: seats right at the night's last replay time not fewer than base, each night.
- **Unacceptable win**: a pass carried only by the two development seats (the SLB3 "without" figure has the wrong
  sign) is reported as a fail.
- Pass on all: Claude may switch it on (Pete's 27 Nov rule); borderline or failed: off, reported to Pete with the split.
  Each switch is judged alone against base; `all` (B1+B2) is run for information only.

## Commands for the main session (from C:\dev\auspol, one at a time, detached; `AUSPOL_CODE_DIR` = this branch)

```
$env:AUSPOL_CODE_DIR = "C:\dev\auspol\.claude\worktrees\agent-a2b55b6989e65010c"
$D = "deciding-runs/20261111-0900-night-pair-cal"; $O = "deciding-runs/20261128-lane-b/replay"
$L = "--pair-cal=0.945244,0.681490 --class-split=1"
# base, then each arm: label lbbase / lbb1 (--same-class=1) / lbb2 (--flow-pool=1) / lbb3 (--tcp-by-type=1, vic2022 only) / lbb12 (--same-class=1 --flow-pool=1)
Rscript scripts/night_replay_vec.R  --state=$D/state-vic2022.rds --setup=$D/setup --out=$O --label=lbbase $L
Rscript scripts/night_replay_feed.R --state=$D/state-fed2022.rds --out=$O --label=lbbase $L
Rscript scripts/night_replay_feed.R --state=$D/state-fed2025.rds --out=$O --label=lbbase $L
Rscript scripts/night_replay_vec.R  --state=$D/state-vic2022.rds --setup=$D/setup --out=$O --label=lbb1 $L --same-class=1
Rscript scripts/night_replay_feed.R --state=$D/state-fed2022.rds --out=$O --label=lbb1 $L --same-class=1
Rscript scripts/night_replay_feed.R --state=$D/state-fed2025.rds --out=$O --label=lbb1 $L --same-class=1
Rscript scripts/night_replay_vec.R  --state=$D/state-vic2022.rds --setup=$D/setup --out=$O --label=lbb2 $L --flow-pool=1
Rscript scripts/night_replay_feed.R --state=$D/state-fed2022.rds --out=$O --label=lbb2 $L --flow-pool=1
Rscript scripts/night_replay_feed.R --state=$D/state-fed2025.rds --out=$O --label=lbb2 $L --flow-pool=1
Rscript scripts/night_replay_vec.R  --state=$D/state-vic2022.rds --setup=$D/setup --out=$O --label=lbb3 $L --tcp-by-type=1
Rscript scripts/score_night_lane_b.R --dir=$O --base=lbbase --arm=lbb1
Rscript scripts/score_night_lane_b.R --dir=$O --base=lbbase --arm=lbb2
Rscript scripts/score_night_lane_b.R --dir=$O --base=lbbase --arm=lbb3 --nights=vic2022
```

Check every run's `NRCODE` line names the worktree, and its `NRV1` / `NRF1` "lane B" line shows the arm's switch on
(and off for base) before reading a score.

## Amendment 1 (27 Nov, ~10:20pm; still before ANY replay or switch-on trace was run or scored)

Added below; the text above is left as written. Four things above were wrong or changed:

1. **The commands above do not run as written**: `$L` is one PowerShell string, so both flags reach R as one argument
   (`--pair-cal` would read `0.681490 --class-split=1`). Use an array and splat it, checked with a script printing
   `commandArgs()`: `$L = @("--pair-cal=0.945244,0.681490", "--class-split=1")`, then `... --label=lbbase @L`.
2. **"Clamps the flow at 0 (Mildura 9pm)" is false.** A first-preference-only check (no simulation) of Mildura's
   counted 2CP at 9pm gave a class-level flow of 0.444 (se 0.060) and a candidate-level flow of 0.358 (se 0.02, the
   floor), projected final Cupper 48.6 class-level and 47.0 candidate-level against 48.7 actual (on the prior shares,
   not the night's updated ones). So the candidate-level read is NOT obviously better there and it gives the count
   about nine times the weight. **It is split off as its own switch, B1c `tcp_cand`** (`--tcp-cand=1`,
   `night_run_update(tcp_cand =)`, cfg `tcp_cand`), so B1 `same_class` is now the pre-count shift alone and each is
   judged alone. New arm label `lbb1c`.
3. **B1's `g` changed after the prereg commit, after seeing its values** (no replay had been run): the fit found only
   2 final-pair independent exclusions before 2022 against 78 Coalition ones, so the all-class fallback handed every
   minor class the Coalition's 0.80. Now each class's rate is shrunk toward ITS OWN prior `f + (1 - f)/2` (`f` its
   one-step same-class rate, as the night class split's) with a pseudo-count of 10 exclusions (`.NIGHT_SC_K`; both the
   10 and the 1/2 are judgement, in `docs/CONSTANTS.md`).
4. **B2's `tau`**: estimated only from seats whose `flow_se` was measured (3+ counted booths), because the 0.25
   placeholder for fewer booths would swamp the subtraction, set `tau` to 0 and pass one seat's residual whole to its
   type. Changed before any run.
5. "The only runs before this file were one-seat traces" was wrong: no switch-on trace had run when it was written.
   Traces, if they run, run after this amendment and do not change any criterion.

Added lines, declared now: B1's primary is diluted (it moves only seats with an unsplit same-class candidate, about 5
of vic2022's 25 named seats), so the scorer's SLB2 line is also read on the seats where `same_class` actually moved
anything (`r$same_class` / the replay's seats with a non-empty shift); that subset is reported, not decisive.
Off-identity is proven in unit tests at `night_tcp_obs()` and by construction in `night_run_update()` (the off path
is the old call); a base run under dev code against this branch, compared with `identical()` on `win_prob`, is the
real proof and has NOT been run.

Corrected commands (PowerShell, from C:\dev\auspol):

```
$env:AUSPOL_CODE_DIR = "C:\dev\auspol\.claude\worktrees\agent-a2b55b6989e65010c"
$D = "deciding-runs/20261111-0900-night-pair-cal"; $O = "deciding-runs/20261128-lane-b/replay"
$L = @("--pair-cal=0.945244,0.681490", "--class-split=1")
foreach ($arm in @(@("lbbase"), @("lbb1", "--same-class=1"), @("lbb1c", "--tcp-cand=1"), @("lbb2", "--flow-pool=1"))) {
  $lab = $arm[0]; $x = @($arm | Select-Object -Skip 1)
  Rscript scripts/night_replay_vec.R  "--state=$D/state-vic2022.rds" "--setup=$D/setup" "--out=$O" "--label=$lab" @L @x
  Rscript scripts/night_replay_feed.R "--state=$D/state-fed2022.rds" "--out=$O" "--label=$lab" @L @x
  Rscript scripts/night_replay_feed.R "--state=$D/state-fed2025.rds" "--out=$O" "--label=$lab" @L @x
}
Rscript scripts/night_replay_vec.R "--state=$D/state-vic2022.rds" "--setup=$D/setup" "--out=$O" "--label=lbb3" @L "--tcp-by-type=1"
foreach ($a in @("lbb1", "lbb1c", "lbb2")) { Rscript scripts/score_night_lane_b.R "--dir=$O" "--base=lbbase" "--arm=$a" }
Rscript scripts/score_night_lane_b.R "--dir=$O" "--base=lbbase" "--arm=lbb3" "--nights=vic2022"
```

Scorer dry run (on the 11 Nov pair-cal replays, `pair` vs `base`): its per-night differences match that run's
`results-cal.txt` (fed2022 -0.0019 against -0.0020, fed2025 -0.0047 against -0.0043); its levels differ (fed2022 base
0.0847 against 0.0744; the older scorer's time set or floor differ, UNVERIFIED which), and its wrong-call count is in
seat-times, not seats. The older replay files have no `counted` column, so on them the 10% rule is skipped.

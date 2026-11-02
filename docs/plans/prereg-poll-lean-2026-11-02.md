# Pre-registration: treat statewide polls differently by company, sponsor, method and age, and size the day-0 anchor

Written 2026-11-02, before any arm is built or run. Pete, 1 Nov 8:30pm: *"we 100% should be treating different polls
differently based on the poll type and company and how old it is"*. Register: `docs/PETE-ASKED-FOR.md` (1 Nov row).
Trigger evidence: `docs/reviews/s7-onp-anchor-2026-11-02.md`. Starts from the standard decision rule
(`docs/PRE-REGISTRATION-RULES.md`); departures are named where they occur.

## What the published trend does today, so the arms are measured against the real thing

`trend_as_at()` (`R/projection.R:64`), `sigmas = "default"`, `weights = "equal"`, through `fit_cycle_trends()`
(`R/trend.R`):

- **Company: within-cycle house effect per firm per party**, prior sd `sigma_house_pts`, centred by a soft
  poll-count-weighted sum-to-zero. Firms with few polls pool into "(other firms)". So each company is measured
  against the other companies IN THIS CYCLE, never against results.
- **Age: a random walk** (`sigma_rw` 0.0044/day in logit for Victorian One Nation). Older polls count less because the
  walk lets the level move away from them. No campaign-period change in the walk.
- **Noise: equal per poll** (fixed 1.7 points). Sample size, record-based noise and estimated noise were refused
  9 Oct (`plans/prereg-statewide-poll-sample-weights-2026-10-09.md`): those arms changed the WIDTH a poll gets, not
  its LEAN. This prereg is about lean.
- **Day-0 anchor:** the previous election's result at the strong sd (5 points translated at the observed level).
  `ANCHOR_K = 0`, so a 0.28% result anchors as strongly as a 37% one. On Victoria 2026 this anchor holds One Nation
  1.90 points under its polls (S7 breach, 2 Nov).
- **Not used: sponsor, method (phone / online panel / SMS / robopoll / MRP), or any company's record against
  results.**

## The arms (each a switch, published value off; the strongest version is arm FULL)

All signed lean terms are on the model scale (logit), estimated per party class (ALP, LNP, GRN, ONP, OTH), and
applied as a fixed offset to each poll before the trend is fitted, so the existing within-cycle house effect then
centres on what is left.

1. **REC: company lean against results** (`AUSPOL_POLL_LEAN_FIRM`). For each firm and party: the poll minus the
   result at earlier elections, minus that election's recency-weighted mean miss across all firms (the shared miss is
   not one company's lean). Recency weight halves every 30 days before polling day (as `POLL_RECORD_HALFLIFE`).
   Shrunk to zero by `w = tau^2 / (tau^2 + se_i^2)`, with `tau^2` from DerSimonian-Laird over firms. Firms are
   matched through `firm_alias.csv`; method variants of one company (SMS Morgan, Morgan Phone) count as separate firms.
2. **SPN: sponsor lean** (`AUSPOL_POLL_LEAN_SPONSOR`). Three classes: commissioned by a party or advocacy group;
   media (any listed media client, and an unlisted client on a firm's regular media series); unknown. Signed lean per
   class and party against results, same shared-miss removal, shrunk the same way. Sponsor labels cover 76 of 1,176
   matched 2010+ polls (6%; `reviews/statewide-poll-samples-2026-10-09.md` section 3). Expected to shrink nearly to
   zero; it is included because shrinkage makes a thin term safe to include (CLAUDE.md shrinkage rule).
3. **MOD: method lean** (`AUSPOL_POLL_LEAN_MODE`). Classes from `mode_raw` and the firm alias: phone (live), robopoll
   (IVR), online panel, SMS, mixed, MRP, unknown. Same estimation. A method class confounded with one firm is reported
   as such.
4. **ANC: day-0 anchor strength** (`AUSPOL_ANCHOR_SD_MULT`). Grid of multipliers on the strong anchor sd:
   **{1 (today), 2, 4, no anchor (first-poll start at the weak sd)}**, plus one continuous form: the anchor sd
   scaled by `sqrt(1 + (gap / g)^2)`, where `gap` = |logit(first poll) - logit(previous result)|, with `g` from the
   grid **{0.5, 1, 2}**. No threshold anywhere (no-cliff rule). The setting is chosen time-forward: for a target
   election, the value with the lowest day-before level error over elections held before it.
5. **AGE: campaign walk** (`AUSPOL_TREND_CAMPAIGN_RW`). The walk sd multiplied by `m` in the final 60 days, `m` from
   the grid **{1, 1.5, 2}**, chosen time-forward. 60 days is a fixed window, but it applies a multiplier, not a
   cut-off. This arm is the one "how old it is" asks for beyond what the walk already does.
6. **FULL: REC + SPN + MOD + ANC + AGE together**, each term estimated time-forward as above, plus the 9 Oct
   `weights = "record"` noise factors (the noise half, refused alone, rides along in case it helps beside lean).

## Data gate (step 0; stop and report before building arms if it fails)

- Coverage, printed per region: polls with a firm resolved by `firm_alias.csv`, a method class, a sponsor class.
  Gate: firm resolved on 95% of 2010+ polls, or REC is not built and the gap goes to Pete.
- Earlier-election support: for each scored target, the number of earlier elections with polls and a result in
  its region and in all regions. REC uses ALL regions' earlier elections (firms poll across regions).
- MDE: before any arm, the per-election day-before level error on the incumbent, and the 1-SE MDE of the
  primary (clustered on election) printed. If the MDE exceeds 0.10 points the primary is too noisy to resolve
  plausible effects, and the plan goes back to Pete before arms run.

## Scored elections and metrics

- **Statewide stage, all 35 scored elections** (every one with day-before polls; the 10 Oct registry lists which
  have none, and those are reported as unscored, not dropped silently). Script: a new `scripts/screen_poll_lean.R`,
  which refits `trend_as_at()` at each election's day-before date under each arm.
- **Primary (clause 1): day-before statewide primary level error**: mean absolute error of the trend endpoint against the
  actual statewide primary, over ALP, LNP, GRN, ONP and OTH, weighted equally per party-election, SE clustered on
  election. Better than the incumbent by more than 1 SE. Reported at 30, 90 and 180 days out too; those are
  reported, not deciding (alternating signs across horizons are noise).
- **Seat stage, the arms that pass the statewide stage**: `quick_arm.R --pairs=all` (every scored election),
  `scripts/screen_level_share.R` first as the cheap stop. **Guard (clause 2): seat log loss on every seat, not worse
  by more than 1 SE.** Seat log loss decides between arms that pass (clause 7).
- **Clauses 3-6 as standard**: leave-one-election-out on the primary; no election worse on seat log loss by more
  than 2 SE of its own paired seat differences; for ANC, the gain keeps its sign with the two largest-gain elections
  removed; moved-row direction counted and reported.

## Leakage rules

- Every lean, anchor setting and campaign multiplier for target election E uses only elections whose polling day
  is before E's first poll. An assertion fails if any training election's date is on or after E's cycle start, and
  a test feeds it a deliberately leaked record and must fail.
- The shared-miss removal uses only polls of the training election.
- vic2026 and nsw2027 are never scored. Their arms are walked, not measured.

## What would make an apparent win unacceptable (named now)

- **A gain that exists only because One Nation is pushed DOWN everywhere** while REC, SPN and MOD are all
  inert. The 10-cycle record (polls over-stated One Nation in 8 of 10) predicts the ANC arm may win this way.
  Then ANC is judged on its own, and sa2026 (the only completed case the size of Victoria, where the polls were
  exact) is reported separately. A win that makes sa2026 worse by more than 2 SE of its own seats goes to Pete
  (clause 9), not straight to shipping.
- Any lean term estimated from one company's single election (n of 1 election) that moves a vic2026 party by more
  than 1 point after shrinkage: printed and walked with Pete before shipping.
- Pre-xgb only: the arm must be measured on the published path (`fit_seats_full.R` reads the trend for
  `state_mean`), and the live walk (vic2026 with and without the arm, per party, per seat) is shown before any ship.

## Not criteria

That company leans "should" exist. That the S7 breach goes away. That the trend looks closer to the polls on the
chart. S7's bound is a check on the fit, not an objective; an arm that cures S7 and loses on the primary is refused.

## Expectation, stated before running

Within-cycle house effects already absorb most of what REC can find, and the 9 Oct record arm found that a
company accurate last time is not reliably accurate next time. **I expect REC, SPN and MOD to move the primary by
less than its MDE.** ANC is the arm with a visible mechanism (1.90 points on vic2026, 1.38 on wa2017); its sign
is unknown: the 10-cycle record leans toward keeping the anchor (MAE 2.01 against 2.12 without it), and sa2026 points
the other way.

## Order of work

1. Step 0 gate and MDE (one script, under a minute).
2. ANC alone at the statewide stage (cheap: one refit per election per grid value).
3. REC, SPN, MOD, AGE builds, each behind its switch with a test that the switch at its default is byte-identical
   to today's trend.
4. FULL.
5. Seat stage for every arm that passed step 2-4, then the deciding 20k run for one winner via
   `scripts/deciding_run.ps1`.

## Amendments

(none yet; any change is added below this line with the original text left as it is)

## RESULT, step 0 (2026-11-02, `scripts/screen_poll_lean.R`, before any arm)

- **Firm gate as written: FAIL.** 2010+ Wikipedia statewide poll rows with a firm resolved by `firm_alias.csv`:
  4,288 of 5,220 (82.1%, bar 95%). The misses are firms missing from the alias table, not unnamed polls:
  RedBridge/Accent 171, ReachTEL 136, DemosAU 127, Fox & Hedgehog 106, EMRS 94, DemosAU/Premier National 89.
- **The rows the trend fits** (`load_polls()`, 2010+): firm named on **2,968 of 2,968 (100%)**, 15-31 distinct firm
  labels per region. REC estimates on these rows, so the gate as written measured the wrong table. Not amended:
  a gate failure goes to Pete (gate clause).
- **Method labels: federal only.** 961 of 3,883 federal rows (24.7%); **0% in every state table**. MOD on labels
  alone is a federal-only arm; for states it needs a firm-and-era method table.
- **Sponsor (client):** 1,330 of 5,220 rows (25.5%); vic 49.1%, nsw 37.0%, wa and sa 0%.
- **Primary on the incumbent:** 38 scored elections (not 35: wa1996 and the 2006-2010 state cycles have day-before
  polls), day-before MAE mean **1.800 points**, sd 1.026 across elections. Worst: sa2018 5.04, wa2017 4.17, wa2013 3.54.
- **Noise floor (MDE gate): PASS.** A placebo arm (one random poll dropped per election, seed 20261102) moves the
  primary by a paired SE of **0.0076 points** (n 38; bar 0.10). A real arm meets more noise than this; it is a lower bound.
- **Earlier-election support:** 0 earlier elections for wa1996, 2 for fed2004/nsw2007/vic2006/sa2006, rising to 32 for
  fed2025. REC and SPN fall back to zero lean (full shrinkage) where support is 0.

**Correction (2026-11-02, same session, before any arm): the firm gate PASSES as written; the FAIL above was a bug in
the screen.** `firm_alias.csv` patterns are regular expressions (`red ?bridge|accent`, `demos|premier national`) and
`screen_poll_lean.R` matched them as fixed text. With regex matching: **5,051 of 5,220 (96.8%, bar 95%)**. Still
unresolved: EMRS 94 and MediaReach 11 (Tasmania and NT, neither scored here), and non-firm labels (NT News,
Sky News, "Internal polling", "Unnamed"). `firm_alias.csv` is not changed.

## RESULT, arm ANC at the statewide stage (2026-11-02, `scripts/screen_poll_lean_anc.R` (check codes PLA0-PLA4)): NOT PASSED, not taken to the seat stage

266 fits (38 elections x 7 settings), 1.2 minutes. Primary = day-before mean absolute error in points (lower is better);
change = arm minus published, SE over elections.

- **Time-forward pick (the arm as registered): +0.0104 points worse, SE 0.0149** (n 38). Clause 1 NOT PASSED. Leave-one-out:
  better by > 1 SE in 0 of 38 drops. Moved 36 elections, 20 better and 16 worse. The pick wanders (none 13, gap:0.5 12,
  gap:1 11, published 2) because no setting is reliably better on earlier elections.
- Fixed settings, reported only: 2 -0.0061 (SE 0.0134), 4 -0.0073 (0.0169), none -0.0062 (0.0182), gap:0.5 -0.0031 (0.0143),
  gap:1 -0.0025 (0.0132), gap:2 -0.0016 (0.0097). All within 1 SE of zero; a fixed setting chosen after seeing this table
  would be the cherry-pick the time-forward rule exists to prevent.
- Biggest single moves under the pick: qld2017 -0.409 (One Nation's 2017 return, error -1.02 -> +0.08), nsw2019 +0.275 and
  wa2017 0.000/+1.38 on One Nation (the small surges the polls over-stated), fed2010 +0.129, wa2005 +0.115.
- Named in advance: mean |One Nation error| 1.676 published vs 1.754 under the pick (18 elections); sa2026 -0.059 better
  (One Nation -2.22 -> -2.07). So loosening the pin helps the big-surge case and hurts the small-surge cases, and nets to nothing.

**`AUSPOL_ANCHOR_SD_MULT` stays "1".** The 2 Nov S7 breach (Vic One Nation 19.52 vs 22.03) is therefore the published
model behaving as measured, not a defect to patch; per "Not criteria" above, curing S7 is not a reason to ship.
Next arms: REC, SPN, MOD, AGE (order of work step 3).

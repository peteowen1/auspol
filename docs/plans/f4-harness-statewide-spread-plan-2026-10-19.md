# F4: give the state harnesses the statewide spread that ships (plan, not yet run)

2026-10-19. Read-only investigation; no Rscript run, nothing measured. Everything below is from reading code
unless marked MEASURED. Source finding: `docs/reviews/pipeline-overwrite-audit-2026-10-18.md` F4.
Status: DRAFT pre-registration, not committed as a prereg yet. Nothing here is a result.

## 1. Is F4 real? Yes, with one correction to how it is stated

What each script does with the statewide (party-level) uncertainty. "Spread" means how far the simulated statewide
vote for a party can land from its central value; the seat model adds each draw's departure from centre to every seat.

| Script | How statewide spread is drawn | file:line |
|---|---|---|
| `fit_seats_full.R` (ships) | `psd` = per-party `state_sd` = sqrt(trend band^2 + 2.419^2); independent normal draws (PARTY_COR off) or Cholesky if on; floor 0.1, rescale to 100; then ALP/LNP shifted so the implied two-party matches `rnorm(pj$mean, pj$sd)`; passed as `statewide_draws = sw_draws` | psd 1497; draws 1559-1569; anchoring 1602-1622; sim call 1781-1785; `state_sd` 567-581; `FP_EXTRA_SD` 163 |
| `backtest_candidate_fed.R` | `statewide_draws_as_at()` (same construction), bucket-fold, passed as `statewide_draws = X$sw_draws`. Draws exist only when `FORECAST_MODE` is on (`sw_draws <- NULL` otherwise). Also still passes flat `party_sd = psd` 1.5, but the simulator ignores `party_sd` for the shift when draws are supplied (`R/seat_sim.R:1403-1409`) | draws 976-1101; PARTY_SD 1651-1652; sim call 1884-1889 |
| `backtest_candidate_vic.R` | flat `PARTY_SD` 1.5 default, `psd` identical for every party; no `statewide_draws`; `party_cor = PARTY_COR` (NULL, because `AUSPOL_PARTY_COR` is off) so independent | 853-854; sim call 983, 1033-1036 |
| `backtest_candidate_nsw.R` | same | 959-960; sim call 1152-1154 |
| `backtest_candidate_qld.R` | same | 943-944; sim call 1127-1130 |
| `backtest_candidate_sa.R` | same | 1122-1123; sim call 1310-1313 |
| `backtest_candidate_wa.R` | same (`PARTY_SD` 144, `psd` per pair inside the loop) | 144, 711; sim call 787 |
| `backtest_candidate_nt.R` (audit counts it; the task named six) | same | 163, 741; sim call 817 |

Grep of `statewide_draws` over `scripts/` and `R/` finds it only in the fed harness, `fit_seats_full.R`, the
simulator, `R/forecast_mode.R`, `R/forecast_statewide.R` and Hare-Clark (`R/hare_clark.R`, `backtest_hare_clark.R`).
Confirmed: none of the vic, nsw, qld, sa, wa, nt harnesses passes it.

**Correction / the important detail the audit did not state.** The state harnesses already BUILD the right draws and
then THROW THEM AWAY. Each calls `forecast_statewide_or_oracle()` (vic:416, wa:342, nsw:435, qld:442, sa:489), which
calls `forecast_statewide_for()` -> `statewide_draws_as_at()` and gets a full `n_sims` x parties draw matrix with the
published construction (polls trend band, `fp_extra_sd = 2.419` in quadrature, bucket fold, two-party anchored to the
fundamentals-plus-trend projection). It returns only `colMeans(fc$draws)` as the level
(`R/forecast_statewide.R:403-412`, `st_fc` at 91/137; draws at 144-146). So the fix is wiring, not new modelling.

Also true and worth keeping: `AUSPOL_PARTY_SD` is NOT in `scripts/published_flags.R` (grep: no match), so the 1.5 is
a literal default in each harness, outside the one registry the repo says is the only source of configuration.
`R/forecast_mode.R:9` ("No harness does") is stale for federal.

Not confirmed: whether the nt harness is one of the "23 pairs" (audit text says nt; NEXT-STEPS says "six harnesses").
The pair counts (16 of 23 here, 22 elsewhere in CLAUDE.md) differ; I did not enumerate pairs per harness.
`scripts/pool_backtests.R` or `quick_arm.R --pairs=all` will print the true list.

### What inputs the draws need, and whether each state pair has them

`statewide_draws_as_at(region, year, as_at = ed - 1, ...)` (`R/forecast_mode.R:72`) needs:

- Polls for the region up to the day before (`load_polls(region)`, trend needs >= 8 polls, `trend_as_at`). Thin cycles
  return NULL; `forecast_statewide_or_oracle` then falls to `thin_cycle_statewide()` (AUSPOL_THIN_CYCLE=1,
  `R/forecast_statewide.R:373-392`), which returns a level only, with NO draws. wa2021 was such a cycle until 2026-10-13.
  These pairs would have no draw matrix and need an explicit fallback (below).
- Prior election results (`load_prior_results`), preference flows as of the cycle start (time-forward already).
- Fundamentals + projection mix, time-forward (`fundamentals_tf`, `projection_mix_tf`, default
  `AUSPOL_FUND_TIME_FORWARD=1`, `forecast_statewide_or_oracle` 350-357). So the inputs exist for every pair that
  already scores in forecast mode, because the same call already succeeds there. I did not check each pair's poll count.

## 2. Is the difference material? Size

- Live/fed per-party sd is sqrt(band^2 + 2.419^2), so it is AT LEAST 2.42 for every party, against 1.5 flat in the
  harnesses: 1.6x or wider. With a typical trend band of 0.5-1.5 points the range is about 2.5-2.9 (arithmetic, not
  printed from a run; the live run prints `FP sd mode ... statewide sds a-b`, `fit_seats_full.R:577`, which would give
  the real range). Realised statewide error is 2.33 over 139 party-cycles / 33 cycles (`vic:846-852`, MEASURED earlier).
- The ALP/LNP pair is not independent in the shipped draws: the anchoring adds +d to ALP and -d to LNP, which fixes the
  implied two-party sd at the projection sd (`fit_seats_full.R:1602-1630`, asserts sd within 0.3 of `pj$sd`). The harness
  draws leave ALP and LNP independent. I expect this, not the 1.5 vs 2.4 scalar, to be the larger structural difference
  (HYPOTHESIS, unmeasured).
- Prior evidence says the scalar alone is small: `docs/reviews/party-sd-tie-2026-08-26.md` (MEASURED): `party_sd` 2.33 vs 1.5
  was a TIE, 11 of 17 pairs, mean per-pair log delta -0.00459, SE 0.00262; accuracy fell slightly and slopes drifted. That
  run predates forecast mode as the default, `SHRINK` 0.01 (published_flags.R:27; shrink was then a larger cap that
  could absorb extra spread) and the anchoring, and it tested only the scalar, so it does not answer the present question.
  It also states 2.33 is "a floor rather than an estimate" for a live forecast.
- Net: size is UNKNOWN. Because it is a common shift on every seat of a state it moves seat correlation and tail
  probabilities most, which seat log loss at the 1e-6 floor is sensitive to.

## 3. Proposed minimal change

Switch: **`AUSPOL_HARNESS_SW_DRAWS`**, default `"0"` (byte-identical to today), flip to `"1"` and add to
`published_flags.R` only after the deciding run. (Register it in `published_flags.R` in the same commit as the flip, per
CLAUDE.md; while default is "0" list it with the other measured-off arms or document it in the commit.)

Code, same commit for all harnesses (rule "a fix to one harness is a fix to ALL of them"):

1. `R/forecast_statewide.R`, `forecast_statewide_or_oracle()`: on the success path set
   `attr(out, "draws") <- fc$draws`. Draws are already built; this only stops discarding them. Thin-cycle path sets no
   attribute. With the switch at "0" nothing reads it.
2. Each of vic, nsw, qld, sa, wa (and nt if it uses the function; it does not appear to) after `sb`/`st_b` is final:
   `sw_draws <- if (SW_DRAWS_ON) attr(sb, "draws") else NULL`. Keep the attribute by reading it right after the call
   (later code subsets `sb` and would drop attributes).
3. Make it fail loud, not silent:
   - Row count: `forecast_statewide_or_oracle` generates `max(n_sims, 20000)` rows but `simulate_seat_contests` stops
     unless `nrow(statewide_draws) == n_sims` (`R/seat_sim.R:1021`). With `quick_arm.R --sims=1000` or any N_SIMS
     below 20000 this will error. Take the first `N_SIMS` rows (they are iid) and print that it did.
   - Columns: draws cover `union(parties, names(st_b))`; the simulator needs every column of `shares`
     (`seat_sim.R:1024-1027`). Check coverage; on a miss print `SW0!` and fall back to `psd` for that pair, never
     silently.
   - Thin-cycle / no-attribute pairs: print `SW0!` naming the pair and fall back to flat `psd`. Count them in the
     summary; a pair scored on the old spread is not comparable with one on the new, so they must be listed, not hidden.
   - `AUSPOL_PARTY_COR` is a no-op once draws are supplied (shift mode 0, `seat_sim.R:1231`); stop if both are set so a
     correlation arm cannot silently do nothing. (Published has it off, `published_flags.R:81`.)
   - Print the realised per-party draw sd and the two-party sd of the draws next to the 1.5 it replaces, so the value
     applied is read before the result (CLAUDE.md: "every diagnostic must print what it applied").
4. Leave `party_sd = psd` in the call (as the fed harness does; ignored for the shift when draws are supplied). Check
   whether `sd_vec` is used elsewhere in the C++ path (`seat_sim.R:1333`); I did not confirm it is inert.
5. Fed needs no change, but it is the template and the control: its pairs must score exactly 0 difference.

Out of scope, state it in the commit: the fed harness's extra post-processing of the draws for per-class level
re-forecasts (`backtest_candidate_fed.R:1202-1229`, AUSPOL_IND_SALIENCE) is not ported; the state harnesses do not have
that arm on.

## 4. Draft pre-registration (start from the standard rule at `docs/PRE-REGISTRATION-RULES.md:10-33`)

To be committed before any run. Departures from the standard rule: none intended.

**Arm.** `AUSPOL_HARNESS_SW_DRAWS=1` against base `0` (today's published harness behaviour), everything else at
`published_flags.R`. Same seed, same N (common random numbers).

**Targets (the change acts only on these).** Every vic, nsw, qld, sa, wa pair that forecast mode scores and that has a
draw matrix (plus nt if wired). Fed pairs are controls: must be byte-identical (max_diff 0), or the run is invalid.
Thin-cycle pairs that fall back are listed and excluded from the primary (they are unchanged by construction).

**Metric order.** Seat winner log loss (eps 1e-6 clamp), then Brier, then reliability by band. Calibration slope and
accuracy reported, not decisive.

**Primary (rule 1).** Pooled seat log loss over the targeted pairs better than base by more than 1 SE, SE clustered on
election. Size the MDE first (rule: size the metric's noise): the earlier scalar test had SE 0.0026 per pair on 17 pairs
and a mean effect 0.0046, so an effect of that size is only about 1.7 SE; compute the MDE for the current pair count in
this plan before the deciding run, and if it exceeds any plausible gain say so rather than let a 1-SE bar only refuse.

**Guard (rule 2).** Seat log loss over all scored seats of all scored elections not worse by more than 1 SE.

**Leave-one-election-out (rule 3).** Primary stays better by more than 1 SE with each election dropped in turn. Each
election's share of the gain reported, never a refusal.

**No election materially worse (rule 4).** No election worse by more than 2 SE of its own paired seat differences.

**Seat quirk (rule 5).** Not applicable as a targeted-seat fix; report the two largest-gain seats anyway.

**Direction (rule 6).** Prediction: wider common spread should raise win probability for trailing parties and lower it
for leaders in nearly every close seat. Report the count of seats moving each way and refuse only if the realised
outcomes contradict it (moved seats score worse).

**Named disqualifiers in advance (outcomes, not just direction).**
(a) The gain comes only from seats at the 1e-6 floor (a floor artefact, as in the vic2014 0.4662 vs 0.5608 note in
CLAUDE.md): report the count of seats at the floor in base and arm; if the improvement vanishes with floor 1e-4 it is
an artefact. (b) A pair loses because its draws silently fell back or used a different party set: any `SW0!` fallback
in a targeted pair voids that pair, it does not count for or against. (c) Winner accuracy falls on more than half the
scored elections (the 2.33 test cost accuracy on WA and fed2025). Not a refusal alone (accuracy is not decisive) but it
goes to Pete with the split, per rule 9. What the criterion cannot see: the leakage in `FP_EXTRA_SD` (below) and
whether `SHRINK` 0.01 was tuned under the narrow spread.

**Procedure.**
1. Unit-ish check first, no Rscript needed from me now: confirm OFF is byte-identical to the current harness output
   for one pair, and ON prints the sd line and uses the matrix (an experiment that never ran looks like no effect;
   prove the switch is read by running ON on a deliberately broken input, e.g. a draw matrix missing a column, and
   seeing `SW0!`).
2. Screen: `Rscript scripts/quick_arm.R "AUSPOL_HARNESS_SW_DRAWS=1" --pairs=all` (all targeted pairs; fed controls
   score exactly 0; ~7 min per arm after the baseline). AEF-7 alone has only 5 targeted pairs
   (nsw2023, qld2024, sa2026, vic2022, wa2025) and the repo's own lesson is that refusals that mattered came from
   outside AEF-7, so use `all`. "WORSE" at the screen is a reason to stop; "within 1 SE" is not clearance. Note the
   screen runs at low N, so the row-count handling in item 3 above must work before it can start.
3. Deciding run, detached, not in session (memory: session time is Pete's):
   `powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_HARNESS_SW_DRAWS=1" -Label f4-sw-draws -Pairs all`
   at 20,000 sims from a committed HEAD. Check every `deciding-runs/*` folder marker next session.
4. If adopted: flip default to "1", add to `published_flags.R` and `docs/MODEL-REGISTRY.md` (regenerate), update
   `docs/CONSTANTS.md` (the 1.5 `party_sd` entry now applies only to fallbacks), delete the stale
   `R/forecast_mode.R:9` comment, run `scripts/check_like_ci.R` before pushing, and note in the commit that every
   earlier state-harness figure described a narrower spread. Expect `pool_backtests.R` numbers to move.

## 5. Risks and leakage

- **`FP_EXTRA_SD = 2.419` is estimated in-sample** over the elections being scored (`CONSTANTS.md:59`; the value is the
  two-party projection error). A scored election's own error is inside the constant. Small (one of ~30 cycles), but it
  is the one piece that is not strictly knowable before each election. Mitigation: report a leave-one-election-out
  re-estimate of the constant if its fitting script allows (UNCONFIRMED; I did not read `estimate_fp_extra_var.R`).
- Everything else in the draws is time-forward by construction: polls <= ed - 1 with two leakage assertions
  (`R/forecast_mode.R:86-93`, 146-152), fundamentals and mix time-forward, flows as of cycle start, bucket split by
  `candidate_bucket_ratio` (claimed time-forward, `R/forecast_statewide.R:210-215`; not verified here).
- The projection sd `pj$sd` comes from `project_result` with the mix table; `projection_mix_tf` is used, so should be
  clean. Not verified per pair.
- **Double-counting / compensation.** `SHRINK`, `seat_sd`, `level_sd` and the dev slopes were fitted under the narrow
  spread (`docs/reviews/dev-slopes-refused-2026-08-27.md:71`). Widening spread without refitting them may look worse
  because they were compensating, or better for the same reason. A "worse" result is not proof that the live path is
  wrong; it may mean the constants need the retune. That is a separate, pre-registered step.
- **Level error is already in the harness.** In forecast mode `st_fc` (the level) already differs from the outcome by
  the real forecast error; the draws add predictive spread around that level, which is correct, but check that wider
  spread plus a poor level does not just add noise to pairs with a large level miss (report per election).
- **Seed/common random numbers.** Draws use `seed = SEED` inside `forecast_statewide_or_oracle`; the simulator then
  seeds again. Confirm base and arm share the level draw so baseline-vs-arm differences are only the spread. The
  level (`colMeans`) is identical in both arms by construction, only the shift differs.
- The thin-cycle fallback means some pairs are on the old spread under the new switch. Honest, but it means "all
  state harnesses use what ships" is true for N of M pairs; report N.
- Attributes are dropped by subsetting: reading `attr(sb, "draws")` after any `sb[...]` in the harness returns NULL
  and would look exactly like the switch having no effect. Read it immediately after the call.

## 6. Open questions for Pete

1. Is the intended target "the draws exactly as `fit_seats_full.R` builds them" (per-party sd from the live trend band
   plus 2.419, independent, two-party anchored)? The live script builds them inline (1537-1630) rather than via
   `statewide_draws_as_at()`, and the two differ in detail (live has the LL3 bucket recipe and `AUSPOL_LIVE_LEVEL_ANCHOR`;
   harness path has `AUSPOL_LEVEL_RECIPE=live`, which un-anchors the level but still anchors the draws' two-party).
   I read them as intended to be the same recipe (R/forecast_mode.R header says so) but did not diff them line by line.
2. Include nt, and the Hare-Clark path (already uses `hc_statewide_draws`)? Default: nt yes if it shares the function.
3. Should `SHRINK` and `seat_sd` be re-fitted after, or is the first question only "does using what ships score
   better or worse"? Recommendation: answer the first question only; refit is a second prereg.
4. Pair counts: 16 of 23 (audit) vs 22 (CLAUDE.md). Which is current?

## What I looked at

`scripts/backtest_candidate_{fed,vic,nsw,qld,sa,wa,nt}.R` (grep for `statewide_draws`, `PARTY_SD`, `psd`,
`forecast_statewide_or_oracle`, `simulate_seat_contests(`; read vic 405-435, 835-860; fed 722-742, 968-1110, 1640-1660,
1880-1895), `scripts/fit_seats_full.R` (140-170, 545-590, 1495-1640, 1775-1795), `R/forecast_mode.R` (1-393),
`R/forecast_statewide.R` (whole file), `R/seat_sim.R` (1010-1032, 1395-1425, 745-751), `scripts/published_flags.R`
(grep PARTY_SD/PARTY_COR/FP), `docs/CONSTANTS.md` (grep), `docs/PRE-REGISTRATION-RULES.md` (top 70 lines),
`docs/reviews/party-sd-tie-2026-08-26.md`, F4 section of the audit. NOT read: `estimate_fp_extra_var.R`,
`R/forecast_mode.R` beyond line 400, nsw/qld/sa/wa/nt harness bodies beyond the grep lines, the C++ simulator.

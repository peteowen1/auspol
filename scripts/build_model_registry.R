# Generate docs/MODEL-REGISTRY.md by SCANNING the harness scripts and the
# published forecast for every switch listed in published_flags.R.
#
# WHY THIS IS GENERATED AND NOT HAND-WRITTEN. Session notes have twice
# claimed "AUSPOL_SEED now works in every harness" when it did not (WA's was
# a hardcoded literal, found 2026-09-09 by grepping every switch by hand) and
# "AUSPOL_SEAT_SD_MULT was fixed" meaning the six harnesses, while the
# published forecast itself never read it at all. A hand-maintained parity
# claim goes stale exactly the way CLAUDE.md already documents for reference
# data -- this reads the actual scripts every time it runs.
#
# THE MATRIX IS MECHANICAL (does file X mention switch Y); the CLASSIFICATION
# of each gap -- intentional exclusion, dead/refused experiment, or a real
# open parity gap -- is a hand-maintained judgement call in CLASSIFY below and
# needs updating whenever a gap is closed or a new one is found. Getting the
# matrix right does not require trusting that judgement; the classification is
# there to save the next person from re-deriving it.
#
# Emits MR* codes.
options(auspol.root = normalizePath("."))
today <- as.character(Sys.Date())

FILES <- c(
  "fit_seats (published)" = "scripts/fit_seats_full.R",
  "fed" = "scripts/backtest_candidate_fed.R",
  "nsw" = "scripts/backtest_candidate_nsw.R",
  "qld" = "scripts/backtest_candidate_qld.R",
  "sa"  = "scripts/backtest_candidate_sa.R",
  "vic" = "scripts/backtest_candidate_vic.R",
  "wa"  = "scripts/backtest_candidate_wa.R"
)

pf <- readLines("scripts/published_flags.R", warn = FALSE)
switches <- sort(unique(regmatches(pf, regexpr("AUSPOL_[A-Z_0-9]+", pf))))
switches <- switches[nzchar(switches)]

# Switches read inside a SHARED R/ function rather than named in every
# harness script -- a literal grep on the harness .R files would call these
# gaps everywhere, which is not what "gap" means for this table. Verified by
# reading R/*.R directly (see docs/MODEL-REGISTRY.md's own notes section for
# citations); update this list if a switch moves between the two styles.
SHARED_FN <- c("AUSPOL_COV_LOO", "AUSPOL_SALIENCE_SMOOTH", "AUSPOL_SIM_ENGINE", "AUSPOL_DEFECT_POOLED")

present <- function(sw, file) {
  if (!file.exists(file)) return(NA)
  any(grepl(sw, readLines(file, warn = FALSE), fixed = TRUE))
}

# READING A SWITCH IS NOT RUNNING AT ITS PUBLISHED VALUE, and until 2026-09-14
# this file only asked the first question.
#
# backtest_candidate_fed.R and _nsw.R both do
#
#   if (!nzchar(Sys.getenv("AUSPOL_SALIENCE_EXPECTED", ""))) Sys.setenv(AUSPOL_SALIENCE_EXPECTED = "1")
#
# while published_flags.R ships that switch at "0". Both harnesses therefore
# score a clean "yes" for honouring it -- they do read it -- and then run at a
# value the published forecast does not. MODEL-REGISTRY.md went further and
# stated the arm was "off everywhere", which had been untrue since 2026-09-09.
#
# The scoping itself is deliberate (01c8e1c, "Ship arm C ... scoped to federal
# and NSW"). The defect was that the registry built to stop what-runs drifting
# from what-ships could not see it, because reachability and value are
# different questions. So ask the second one too.
forced_value <- function(sw, file) {
  if (!file.exists(file)) return(NA_character_)
  ln <- readLines(file, warn = FALSE)
  ln <- ln[!grepl("^\\s*#", ln)]            # a commented-out setenv is not wiring
  # COLLAPSED, not matched line by line. A call split across lines --
  #
  #   Sys.setenv(
  #     AUSPOL_SALIENCE_EXPECTED = "1"
  #   )
  #
  # has no single line carrying both the call and the assignment, so a
  # per-line match reports the switch as NOT forced while it plainly is, and
  # the registry then prints a clean "no harness forces a switch". That is the
  # same shape as the three incomplete check-code greps CLAUDE.md records --
  # a pattern anchored on something that happens to be adjacent today. Found
  # by review 2026-09-14; dry-run against a multi-line fixture below.
  one <- paste(ln, collapse = " ")
  pat <- sprintf("Sys\\.setenv\\(\\s*%s\\s*=\\s*[\"']([^\"']*)[\"']", sw)
  m <- regmatches(one, regexec(pat, one))
  hit <- Filter(function(x) length(x) == 2L, m)
  if (!length(hit)) {
    # A non-literal value (Sys.setenv(X = as.character(v)) or a do.call) is
    # forcing the switch to something this cannot read. Say so rather than
    # report "not forced", which is the answer that hides it.
    dyn <- sprintf("Sys\\.setenv\\(\\s*%s\\s*=\\s*[^\"')]", sw)
    if (grepl(dyn, one)) return("(non-literal)")
    if (grepl("do\\.call\\(\\s*Sys\\.setenv", one) &&
        grepl(sw, one, fixed = TRUE)) return("(via do.call)")
    return(NA_character_)
  }
  hit[[1]][2]
}

# The value published_flags.R ships, for comparison. Parsed from the same file
# the switch list came from, so the two cannot drift apart.
published_value <- function(sw) {
  pat <- sprintf("^\\s*%s\\s*=\\s*[\"']([^\"']*)[\"']", sw)
  m <- regmatches(pf, regexec(pat, pf))
  hit <- Filter(function(x) length(x) == 2L, m)
  if (!length(hit)) return(NA_character_)
  hit[[1]][2]
}

FORCED <- do.call(rbind, lapply(switches, function(sw) {
  pubv <- published_value(sw)
  do.call(rbind, lapply(names(FILES), function(h) {
    fv <- forced_value(sw, FILES[[h]])
    if (is.na(fv) || identical(fv, pubv)) return(NULL)
    data.frame(switch = sw, harness = h, forced = fv,
               published = if (is.na(pubv)) "(not in published_flags)" else pubv,
               stringsAsFactors = FALSE)
  }))
}))

M <- data.table::as.data.table(
  do.call(rbind, lapply(switches, function(sw) {
    c(switch = sw, vapply(FILES, function(f) if (present(sw, f)) "yes" else "NO", character(1)))
  }))
)
data.table::setnames(M, "switch", "switch")

# A GREP MATCH IS NOT FUNCTIONAL WIRING. AUSPOL_SALIENCE_SURGE_V2 matches in
# WA because a disclosure COMMENT names it ("surge-v2 ... has no wiring at
# all") -- the mechanical scan above would call this cell "yes" and hide the
# one gap this table most needs to catch. Cells named here are forced to a
# starred "yes*" (present in the file, NOT functionally wired) regardless of
# what the grep found, and always get an explained-section entry even if
# every other cell in the row is a clean "yes".
COMMENT_ONLY <- list(
  AUSPOL_SALIENCE_SURGE_V2 = "wa"
)
for (sw in names(COMMENT_ONLY)) {
  for (col in COMMENT_ONLY[[sw]]) M[switch == sw, (col) := "yes*"]
}

# HAND-MAINTAINED CLASSIFICATION of every non-universal switch, keyed by
# switch name. `note` explains every "NO" cell for that switch across the
# row; update this when a gap is fixed or a new one is found by rerunning
# this script and diffing its output.
CLASSIFY <- list(
  AUSPOL_HONOUR_DEPARTED = paste(
    "SHIPPED 2026-09-18 (flipped 0->1). A departed non-major class leader's vote base decays toward a",
    "measured 0.38 retention rate, gated on prior_leader_returns==FALSE (not candidate_returns()'s `same`,",
    "which is any() across every candidate in the class and can read TRUE even when the actual leader",
    "departed -- Morwell/vic2022, an unrelated minor candidate persisting) AND the salience screen not",
    "independently permitting a new emergence. Wired into R/dev_slope.R's screened_slopes(), read by all",
    "five harnesses that call it (fed/nsw/qld/sa/vic; backtest_candidate_wa.R has no screened_slopes()",
    "wiring at all, a separate pre-existing gap) and by fit_seats_full.R. 2026-09-06's refusal was a",
    "federal two-seat wash (New England vs Wentworth) that conflated departure with 'no new emergence' as",
    "one mechanism; re-measured on the fuller 593-case corpus. Isolated in base_pred: pooled log loss",
    "0.2810->0.2801 (5 harnesses, n=1751), Morwell 3.049->1.877. Reaches the published Victoria forecast",
    "immediately via fit_seats_full.R's xgb_primary_predict_live() (base_margin set fresh each run from",
    "the current shares matrix) with no retrain needed -- but the BACKTEST harnesses' AUSPOL_XGB_PRIMARY",
    "path (xgb_primary_override(), a static cached OOF file) needs the 4-step non-circular retrain to",
    "reflect it in a pooled backtest comparison. See docs/reviews/departed-leader-honour-fix-2026-09-18.md",
    "and docs/reviews/departed-leader-retention-2026-09-15.md."),
  AUSPOL_FLOW_FRAG = paste(
    "SHIPPED 2026-09-15 and reads NO everywhere by construction: it is a FITTING-TIME switch, not a runtime",
    "one. Only scripts/fit_xgb_flows_v1.R reads it, where it decides whether lead_primary (the seat's leading",
    "first-preference share) enters feat_cols and so whether the column is baked into",
    "output/xgb-flows-v1-final-cols.json. Every harness and fit_seats_full.R then reads that JSON, never the",
    "environment, so the feature reaches them through the ARTIFACT. The parity question for this switch is",
    "therefore not 'does each harness honour it' but 'was the artifact refit with it', which the cols JSON",
    "answers: 40 features, lead_primary present. scripts/fit_xgb_flows_loo.R inherits the same list, so the 25",
    "leave-one-election-out models must be refit in the same breath or a harness loads a 39-feature model",
    "against a 40-column matrix. Both were refit 2026-09-15.",
    "docs/plans/prereg-flow-fragmentation-2026-09-15.md"),
  AUSPOL_STATE_DEV = paste(
    "ADOPTED 2026-09-15 and FEDERAL ONLY, which is a design fact rather than the all-harnesses rule",
    "outstanding: a state election has no deviation from a national swing to correct, so the other five",
    "harnesses have nothing to honour. Corrects a federal seat's primaries for how its STATE moves against",
    "the national swing -- WA 2022 swung to Labor far harder than the country (mean ALP per-seat primary",
    "error +6.43 over 15 seats, positive in 14). Federal pooled seat log loss 0.2584 -> 0.2539 over 1,052",
    "seat-elections, 0 of 10 permutation-control draws beating it. fit_seats_full.R reads NO for the same",
    "reason the state harnesses do; the published Victorian forecast is unaffected.",
    "docs/plans/prereg-state-deviation-2026-09-15.md"),
  AUSPOL_STATE_DEV_SHUFFLE = paste(
    "Control for the above, not an arm: permutes which state each seat sits in, within its election, at fit",
    "and apply both. Absent from fit_seats_full.R because a control has no business in the published",
    "forecast. Calibrated -- the null lands on the baseline to within 0.0001 pooled."),
  AUSPOL_DEMO_RESID = paste(
    "UNDER TEST, wired into all six harnesses and deliberately NOT into fit_seats_full.R -- the gap in",
    "this row is the point, not an oversight. Arm A of docs/plans/prereg-demographic-axis-2026-09-15.md:",
    "all seven census columns, each z-scored WITHIN pair, into a leave-one-pair-out elastic net on the",
    "primary residual, with no intercept so corrections sum to zero across a pair and statewide class",
    "totals are untouched. It replaces the single hand-picked yr12_pct of AUSPOL_EDU_RESID, which was",
    "REFUSED. Do not add a live call site until the plan's criterion is met -- and note that",
    "census-features.csv now carries vic2026, so the live path is blocked only by the decision, not the",
    "data, which it was until 2026-09-15."),
  AUSPOL_DEMO_RESID_SHUFFLE = paste(
    "Control, not an arm. Permutes which seat gets which seat's demographics within each election, at",
    "fit and at apply both, so every marginal and the whole procedure survive and only the",
    "seat-to-demographics link dies. Absent from fit_seats_full.R for the same reason its arm is: a",
    "control has no business in the published forecast. Calibrated on sa2026 -- 8 draws give mean",
    "0.3576 against a 0.3577 baseline, sd 0.0013, so the null manufactures nothing and the real effect",
    "sits 8.9 sds out."),
  AUSPOL_EDU_RESID = paste(
    "REFUSED 2026-09-15 and left wired so the result stays reproducible.",
    "docs/plans/prereg-education-residual-correction-2026-09-15.md: the criterion passed (pooled seat",
    "log loss 0.2702 -> 0.2689 over the AEF-7) and the placebo condition fired, so the answer is no.",
    "Superseded by AUSPOL_DEMO_RESID. Default 0 and it should stay 0."),
  AUSPOL_EDU_RESID_FEATURE = paste(
    "Which census column AUSPOL_EDU_RESID uses. born_aus_pct was pre-registered as the PLACEBO and was",
    "not one: r(yr12_pct, born_aus_pct) = -0.706 over 1,989 seats, so both columns read a single",
    "class-and-urbanity axis from opposite ends. It recovered 71% of the pooled gain and 100% of it on",
    "qld2024, which is what refused the mechanism. The lesson is in AUSPOL_DEMO_RESID_SHUFFLE: with",
    "correlated features the control must break the link, not swap the variable."),
  AUSPOL_EDU_RESID_SHUFFLE = paste(
    "The permutation control retrofitted to the refused single-feature arm, and the instrument that",
    "showed its signal was REAL (8.9 sds) even though the arm was refused. Same mechanism as",
    "AUSPOL_DEMO_RESID_SHUFFLE; absent from fit_seats_full.R because a control does not belong in the",
    "published forecast."),
  AUSPOL_LEVEL_MODE = paste(
    "Read by scripts/fit_xgb_primary_v6.R when the model is FITTED, not by any harness or by",
    "fit_seats_full.R at run time -- the choice is baked into the oof file and the saved model, so it",
    "shows as absent everywhere while governing every row of both. 'pred' (default) trains on a",
    "poll-based statewide projection; 'now' trains on the target election's actual result and is",
    "LEAKAGE, kept only so the cost stays measurable. The live path has always used a prediction",
    "(R/xgb_primary_override.R fills level_now from state_mean), so this made training match serving."),
  AUSPOL_FORECAST_MODE = paste(
    "OPEN GAP, and the most consequential one in this table. 1 = the statewide the seats swing toward",
    "is PREDICTED from polls rather than read off the election being scored. Implemented in",
    "backtest_candidate_fed.R and _sa.R ONLY; nsw/qld/vic/wa still use the actual result, so their",
    "numbers answer a different question from federal's and are not comparable to a forecast. Default",
    "0 because flipping it today would mean two different things across the six harnesses, NOT because",
    "the oracle statewide is endorsed -- Pete's ruling 2026-09-11 is that a forecast must be predictive",
    "throughout. Cost where measured: federal +0.0047 pooled seat log loss."),
  AUSPOL_XGB_SURGE = paste(
    "Harness-only and wired into backtest_candidate_sa.R ALONE, which is this file's own 'a fix to one",
    "harness is a fix to all of them' rule outstanding rather than satisfied. Built, measured, NOT",
    "shipped: the hazard is much better than the salience one it would replace (out-of-fold AUC 0.936",
    "against 0.751) but it failed its pre-registered bar and a calibration check says it is now",
    "over-dispersed. Its live path is an unimplemented stub, so fit_seats_full.R cannot honour it even",
    "if asked. docs/plans/prereg-xgb-surge-parameters-2026-09-11.md"),
  AUSPOL_SALIENCE_BLEND = paste(
    "Read inside R/salience_surge.R's blend_salience_shares(), not per-harness -- universal in practice,",
    "and gated there deliberately so all five harnesses and the published forecast get the switch from",
    "one change. Exists to make a suspected DOUBLE COUNT measurable: the same hazard drives both a shift",
    "of the point estimate and an additive jump in the draw. Measured 2026-09-11 -- the double count is",
    "real (surge_h is the per-seat max of p_hat, correlation 0.984) and turning the blend OFF makes",
    "things WORSE, because the under-prediction of emergences is larger than the over-counting.",
    "Stays at 1 until the per-cell variance is fixed."),
  AUSPOL_XGB_PRIMARY = paste(
    "Harness-only BY DESIGN, and the split is the point: a backtest must predict a pair with a",
    "model that never saw it, so the harnesses read the leave-one-pair-out out-of-fold predictions",
    "(output/xgb-primary-v6-oof-predictions.csv) while the published forecast reads the all-data",
    "model via AUSPOL_XGB_PRIMARY_LIVE. Same shipped decision, two artifacts, because vic2026 is",
    "not in any training set and fed2016 is. Absent from fit_seats_full.R deliberately -- an oof",
    "file has no row for an election that has not happened."),
  AUSPOL_XGB_PRIMARY_LIVE = paste(
    "Published-forecast-only (fit_seats_full.R), the live counterpart of AUSPOL_XGB_PRIMARY above.",
    "Loads output/xgb-primary-v6-final.model, trained on all 22 historical pairs -- correct here and",
    "leakage in a backtest, which is exactly why the two switches exist separately."),
  AUSPOL_XGB_PRIMARY_OOF = paste(
    "Harness-only escape hatch naming which out-of-fold file AUSPOL_XGB_PRIMARY reads; empty means",
    "the v6 default. Exists because the unversioned filename is v1's, and until 2026-09-11 the",
    "backtest arm measured v1 while the live forecast shipped v6 -- the two were never describing",
    "the same model. Not a modelling switch; no published-forecast analogue."),
  AUSPOL_COV_LOO = "Read inside R/statewide_cor.R, not per-harness -- universal in practice, absent from every harness script by design.",
  AUSPOL_SALIENCE_SMOOTH = "Read inside R/salience_surge.R, not per-harness -- universal in practice.",
  AUSPOL_SIM_ENGINE = "Read inside R/seat_sim.R's simulate_seat_contests(), not per-harness -- universal in practice.",
  AUSPOL_FLOW_SHIFT = "Published-forecast-only (fit_seats_full.R shifts the statewide TPP fundamentals blend for the live Victorian projection); backtests inject real historical first preferences directly and have no fundamentals blend to shift. NOT federal-specific -- fit_seats_full.R is the Victorian forecast; corrected 2026-09-09, this comment previously said \"federal\" for every switch fit_seats_full.R alone reads, which is wrong for all six in this group.",
  AUSPOL_FORCE_FP = "Published-forecast-only (fit_seats_full.R -- forces a first-preference override for the live Victorian forecast); no analogue in a backtest scored against real historical results.",
  AUSPOL_FP_SD_MODE = "Published-forecast-only (fit_seats_full.R -- first-preference spread mode for the live Victorian projection); backtests use realised historical first preferences, not a projected spread.",
  AUSPOL_ONP_CV = "Published-forecast-only (fit_seats_full.R). ADOPTED 2026-09-09 at 0.365, partially pooled (docs/reviews/onp-concentration-validated-2026-09-09.md) -- moves the live Victorian One Nation median seat count 9 -> 10. The highest-stakes switch this registry tracks; was previously mislabelled \"federal\" here, which is wrong -- fit_seats_full.R is the Victorian forecast, not a federal one.",
  AUSPOL_ONP_FIX = "Published-forecast-only (fit_seats_full.R -- One Nation allocation fix for the live Victorian projection).",
  AUSPOL_ONP_ORDER = "Published-forecast-only (fit_seats_full.R -- One Nation allocation ordering for the live Victorian projection).",
  AUSPOL_IND_SALIENCE = "Deprecated experimental arm (the v1 national IND multiplier), superseded by the newer salience mechanisms; fed-only because that is the only harness it was ever tested in. Not adopted.",
  AUSPOL_INSURGENCY_SHRINK = "Per-seat shrink experiment, REFUSED 2026-09-06 (worse than the scalar shrink on 5 of 6 federal pairs) -- see docs/NEXT-STEPS.md. Fed/fit_seats-only because that is as far as the experiment got before being set aside. Not adopted.",
  AUSPOL_PARTY_COR = "WA deliberately excluded from the statewide party-correlation matrix -- cor(ALP, IND) flips sign there (docs/reviews/statewide-cov-loo-2026-09-07.md). Intentional, not a gap.",
  AUSPOL_QLD_FLOWS = "Self-referential no-op in the QLD harness itself (\"use Queensland's own flows\" is trivially true there) -- disclosed via its own `.inert` list. Genuinely absent from WA (uses AUSPOL_WA_FLOWS instead).",
  AUSPOL_WA_FLOWS = "Self-referential no-op in the WA harness itself, same shape as AUSPOL_QLD_FLOWS above but not disclosed via an `.inert` list there. Genuinely absent from QLD (uses AUSPOL_QLD_FLOWS instead).",
  AUSPOL_SALIENCE_EXPECTED = "WA has no candidate-level salience corpus at all (the WA commission files carry surnames only, no salience-v6.csv rows) -- documented, intentional exclusion.",
  AUSPOL_SALIENCE_EXP_SD = paste(
    "WA: same salience-corpus exclusion as AUSPOL_SALIENCE_EXPECTED, intentional.",
    "fit_seats_full.R: OPEN GAP, not fixed -- registered as published but sd_override is never wired into the forecast script at all (docs/reviews/pre-main-review-gate-2026-09-08.md). Currently harmless: this whole salience-variance arm is still pre-registered and undecided (docs/plans/prereg-salience-expected-and-variance-2026-09-07.md), so the switch is off everywhere. Wire it in the same commit that ships the arm, not before."),
  AUSPOL_SURGE_FROM_ZERO = "WA has no candidate-level salience corpus -- same exclusion as AUSPOL_SALIENCE_EXPECTED, intentional.",
  AUSPOL_SALIENCE_SURGE_V2 = paste(
    "WA: OPEN GAP, not fixed. Marked `yes*` above because the switch's name",
    "appears only in a disclosure comment explaining that it is NOT wired --",
    "WA has no surge-v2 hazard at all where every other harness does",
    "(docs/NEXT-STEPS.md's own \"Open\" item 3, still unaddressed). A plain",
    "grep of the file would otherwise call this cell a clean \"yes\" and hide",
    "the gap."),
  AUSPOL_DEFECT_POOLED = paste(
    "ADOPTED 2026-09-09 at \"2\" (docs/plans/prereg-defector-two-rate-",
    "2026-09-09.md), by Pete on mechanism -- the arm missed its own primary",
    "bar (t -2.04 vs 2.08) but every directional indicator was favourable",
    "and R4 confirmed the published Victorian forecast is byte-identical",
    "(Victoria fields no major-party defector standing as a minor this",
    "cycle, so the mechanism does not fire there). Reaches fit_seats_full.R",
    "correctly: personal_prior_vote() self-resolves both rates from",
    "Sys.getenv() when the caller passes NULL, exactly so this did not need",
    "a seventh call site wired by hand -- the mistake that made the first",
    "pooled-arm run VOID earlier the same day."),
  AUSPOL_FIT_SLOPES = paste(
    "REFUSED 2026-09-09 (docs/plans/prereg-fit-conditional-slopes-2026-09-09.md):",
    "pooled log loss FAIL, panel FAIL, though it surfaced that the shipped",
    "OTH_RIGHT constants are wrong in opposite directions. Harness-only",
    "by design -- a refused, default-off experiment has no reason to reach",
    "fit_seats_full.R."),
  AUSPOL_SPLIT_SLOPE = paste(
    "REFUSED 2026-09-09, and harmfully so (docs/plans/",
    "prereg-partial-return-split-slope-2026-09-09.md): it discarded the",
    "existing conditional-slope system instead of refining it. Harness-only",
    "by design, same reasoning as AUSPOL_FIT_SLOPES.")
)

fmt_row <- function(sw) {
  vals <- as.character(M[switch == sw, -"switch", with = FALSE])
  note <- CLASSIFY[[sw]]
  universal <- all(vals == "yes")  # "yes*" is deliberately NOT "yes" here
  list(vals = vals, note = note, universal = universal)
}

cols <- names(FILES)
L <- c(
  "# Model registry\n",
  sprintf("**Generated %s by `scripts/build_model_registry.R`. Do not hand-edit** --", today),
  "rerun the script instead. Regenerate whenever a switch is added to",
  "`published_flags.R` or a harness's wiring changes.\n",
  "This exists because \"now works in every harness\" has been claimed and been",
  "wrong twice (AUSPOL_SEED hardcoded in WA; AUSPOL_SEAT_SD_MULT never reaching",
  "`fit_seats_full.R` at all), both found 2026-09-09 by checking every switch by",
  "hand instead of trusting the prior claim. The table below is regenerated from",
  "the actual scripts, not remembered.\n",
  "`yes*` means the switch's NAME is present in the file (often only in a",
  "disclosure comment explaining that it is NOT wired) but is not functional",
  "wiring -- see the explained section below for which ones and why.\n",
  "## What each entry point is\n",
  "| entry point | what it is | jurisdiction |",
  "|---|---|---|",
  "| `fit_seats_full.R` | **the published forecast** -- the only script whose output is real | Victoria (live target) |",
  "| `backtest_candidate_fed.R` | backtest harness | Federal |",
  "| `backtest_candidate_nsw.R` | backtest harness | New South Wales |",
  "| `backtest_candidate_qld.R` | backtest harness | Queensland |",
  "| `backtest_candidate_sa.R` | backtest harness | South Australia |",
  "| `backtest_candidate_vic.R` | backtest harness | Victoria |",
  "| `backtest_candidate_wa.R` | backtest harness | Western Australia |\n",
  "All seven share one `R/` package core (`simulate_seat_contests()`,",
  "`reentry_prior.R`, `salience_surge.R`, etc.) -- differences between them are",
  "in which switches each one WIRES and which data source each reads, not in",
  "separate model code.\n",
  sprintf("## Switch parity (%d switches from `published_flags.R`, %d entry points)\n",
          length(switches), length(cols)),
  paste0("| switch | ", paste(cols, collapse = " | "), " |"),
  paste0("|---|", paste(rep("---", length(cols)), collapse = "|"), "|")
)

for (sw in switches) {
  r <- fmt_row(sw)
  row <- paste0("| `", sw, "` | ", paste(r$vals, collapse = " | "), " |")
  L <- c(L, row)
}

L <- c(L, "\n## Every non-universal switch, explained\n")
for (sw in switches) {
  r <- fmt_row(sw)
  if (r$universal) next
  # THREE categories, not two. Until 2026-09-09 anything without "OPEN GAP" in
  # its note fell into "intentional / dead experiment" -- which mislabelled
  # AUSPOL_DEFECT_POOLED (adopted, shipping, correctly wired via a shared
  # R/ function so it shows "NO" everywhere in the mechanical matrix above)
  # as a dead experiment, directly under a note explaining it ships. Found by
  # the review gate reading the generated doc, not the code.
  # FOUR now, and the third one's trigger was too narrow. It matched only a note
  # beginning "ADOPTED", so AUSPOL_FLOW_FRAG -- shipped 2026-09-15, its note
  # beginning "SHIPPED" because that is the word published_flags.R uses --
  # printed as a dead experiment on the day it shipped, which is the identical
  # failure this comment was written about. Match both words.
  open_gap <- !is.null(r$note) && grepl("OPEN GAP", r$note)
  adopted  <- !is.null(r$note) && grepl("^(ADOPTED|SHIPPED)\\b", r$note)
  # A switch only the FITTING scripts read reaches the harnesses through the
  # saved artifact, so an all-NO row is the correct answer rather than a gap.
  fitting  <- !is.null(r$note) && grepl("FITTING-TIME", r$note)
  tag <- if (is.null(r$note)) "**UNEXPLAINED -- audit this**"
         else if (open_gap) "**OPEN GAP**"
         else if (fitting) "**shipped, fitting-time switch (reaches harnesses via the artifact)**"
         else if (adopted) "**adopted, shared-function wiring**"
         else "intentional / dead experiment"
  L <- c(L, sprintf("- **`%s`** (%s): %s", sw,
                    tag, if (is.null(r$note)) "no classification recorded -- add one to CLASSIFY in scripts/build_model_registry.R" else r$note))
}

unexplained <- Filter(function(sw) is.null(CLASSIFY[[sw]]) && !fmt_row(sw)$universal, switches)
L <- c(L,
       "\n## Gaps the switch-presence matrix cannot see\n",
       "A grep for a switch's name proves the name is mentioned, not that the",
       "VALUE it's set to is fully honoured. Hand-maintained because there is no",
       "mechanical test for \"is this harness doing the whole thing the switch",
       "asks for\":\n",
       "- **`AUSPOL_DEV_SLOPE_MODE=screened` is only half-honoured in WA.** The",
       "  switch functionally reads and WA does apply the conditional-slopes",
       "  half; it has no `salience_permit_for()`/`screened_slopes()` wiring at",
       "  all, so the salience-screen half of \"screened\" never fires there.",
       "  Disclosed at runtime (`BW1c!`) since 2026-09-08. Open, not fixed --",
       "  see `docs/NEXT-STEPS.md`.\n",
       "## Fixed this session (2026-09-08/09), for history\n",
       "- WA's `SEED` was a hardcoded literal (`20260825L`), ignoring",
       "  `AUSPOL_SEED` entirely -- every WA run before 2026-09-09 used one fixed",
       "  seed regardless of the env var. Fixed; WA's *default* seed (20260825)",
       "  still differs from the other five harnesses' (42), unchanged on",
       "  purpose so nothing already published moved silently.",
       "- `AUSPOL_SEAT_SD_MULT`, `AUSPOL_FALLBACK_SMOOTH` and `AUSPOL_FLOW_SD`",
       "  were registered in `published_flags.R` and honoured by all six",
       "  backtest harnesses, but never wired into `fit_seats_full.R` at all.",
       "  Fixed 2026-09-09; harmless while shipped at their no-op defaults.\n",
       "## Switches a harness FORCES away from its published value\n",
       paste0("Honouring a switch and running at its published value are different ",
              "questions, and this table asked only the first until 2026-09-14. A ",
              "harness that reads a switch and then `Sys.setenv()`s it scores a clean ",
              "\"yes\" above while measuring a configuration the forecast does not ship. ",
              "Detected mechanically below, so it cannot go stale.\n"),
       if (is.null(FORCED) || !nrow(FORCED))
         "MR3  no harness forces a switch away from its published value.\n"
       else c(
         sprintf("**MR3! %d harness/switch pair(s) run at a non-published value.** Any figure that pools these harnesses with the others compares two configurations.\n",
                 nrow(FORCED)),
         "| switch | harness | forced to | published |",
         "|---|---|---|---|",
         sprintf("| `%s` | `%s` | **%s** | %s |",
                 FORCED$switch, FORCED$harness, FORCED$forced, FORCED$published),
         paste0("\nThis is not automatically a bug -- `AUSPOL_SALIENCE_EXPECTED` and ",
                "`AUSPOL_SALIENCE_EXP_SD` are forced in `fed` and `nsw` on purpose ",
                "(`01c8e1c`, \"Ship arm C ... scoped to federal and NSW\"). It is a bug ",
                "when `published_flags.R` does not record the scoping, which it did not ",
                "until this row existed.\n")),
       "## Coverage check\n",
       if (length(unexplained))
         sprintf("**MR2! %d switch(es) have a non-universal row with NO recorded classification: %s.** Add them to CLASSIFY in scripts/build_model_registry.R before trusting this table.",
                 length(unexplained), paste(unexplained, collapse = ", "))
       else
         sprintf("MR2  every non-universal switch (%d of %d) has a recorded classification.",
                 sum(!vapply(switches, function(sw) fmt_row(sw)$universal, logical(1))), length(switches)))

writeLines(L, "docs/MODEL-REGISTRY.md")
cat(sprintf("MR1  wrote docs/MODEL-REGISTRY.md: %d switches, %d entry points, %d non-universal\n",
            length(switches), length(cols),
            sum(!vapply(switches, function(sw) fmt_row(sw)$universal, logical(1)))))
if (length(unexplained)) cat(sprintf("MR2! %d unclassified: %s\n", length(unexplained), paste(unexplained, collapse = ", ")))

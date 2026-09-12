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
  AUSPOL_LEVEL_MODE = paste(
    "Read by scripts/fit_xgb_primary_v6.R when the model is FITTED, not by any harness or by",
    "fit_seats_full.R at run time -- the choice is baked into the oof file and the saved model, so it",
    "shows as absent everywhere while governing every row of both. 'pred' (default) trains on a",
    "poll-based statewide projection; 'now' trains on the target election's actual result and is",
    "LEAKAGE, kept only so the cost stays measurable. The live path has always used a prediction",
    "(R/xgb_primary_override.R fills level_now from state_mean), so this made training match serving."),
  AUSPOL_FORECAST_MODE = paste(
    "WIRED EVERYWHERE, MEASURED IN TWO PLACES. 1 = the statewide the seats swing toward is PREDICTED",
    "from polls rather than read off the election being scored. It was fed and _sa.R only until",
    "2026-09-12, when nsw/qld/vic/wa were wired onto the same shared core (forecast_statewide_replace()",
    "in R/forecast_statewide.R). THE PORT IS UNRUN: it was written in a container with neither the",
    "election data nor the anchor clone, so no nsw/qld/vic/wa figure exists in either mode and the four",
    "new cells below say the switch is HONOURED, not that it has been exercised. Default 0 for that",
    "reason, NOT because the oracle statewide is endorsed -- Pete's ruling 2026-09-11 is that a",
    "forecast must be predictive throughout. Cost where measured: federal +0.0047 pooled seat log loss;",
    "sa2026 0.3640 -> 0.4756 with the xgb primary off. The published forecast is excluded because it",
    "never had the leak: fit_seats_full.R predicts the statewide from polls and fundamentals already.",
    "NOT closed by the port: WA still takes its PARTY LIST from the target election (union with",
    "names(sb)), so its class membership is target-derived even in forecast mode."),
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
  #
  # FOUR categories since 2026-09-12, for the same reason there are three. A
  # switch that is wired in every harness but has never been RUN in any of them
  # is not an open gap (nothing is missing) and it is certainly not a dead
  # experiment (nothing has been tried). Calling it either would let "it is in
  # all six harnesses" read as "it has been measured in all six", which is the
  # built-flagged-called-done failure CLAUDE.md exists to stop. Keyed on a note
  # opening "WIRED", which is a claim about code and not about evidence.
  open_gap <- !is.null(r$note) && grepl("OPEN GAP", r$note)
  adopted  <- !is.null(r$note) && grepl("^ADOPTED\\b", r$note)
  unrun    <- !is.null(r$note) && grepl("^WIRED\\b", r$note)
  tag <- if (is.null(r$note)) "**UNEXPLAINED -- audit this**"
         else if (open_gap) "**OPEN GAP**"
         else if (adopted) "**adopted, shared-function wiring**"
         else if (unrun) "**WIRED EVERYWHERE, NOT YET MEASURED**"
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

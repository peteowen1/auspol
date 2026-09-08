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
SHARED_FN <- c("AUSPOL_COV_LOO", "AUSPOL_SALIENCE_SMOOTH", "AUSPOL_SIM_ENGINE")

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
  AUSPOL_COV_LOO = "Read inside R/statewide_cor.R, not per-harness -- universal in practice, absent from every harness script by design.",
  AUSPOL_SALIENCE_SMOOTH = "Read inside R/salience_surge.R, not per-harness -- universal in practice.",
  AUSPOL_SIM_ENGINE = "Read inside R/seat_sim.R's simulate_seat_contests(), not per-harness -- universal in practice.",
  AUSPOL_FLOW_SHIFT = "Federal-forecast-only concept (shifts the statewide TPP fundamentals blend); backtests inject real historical first preferences directly and have no fundamentals blend to shift.",
  AUSPOL_FORCE_FP = "Federal-forecast-only (forces a first-preference override for the live forecast); no analogue in a backtest scored against real historical results.",
  AUSPOL_FP_SD_MODE = "Federal-forecast-only (first-preference spread mode for the live projection); backtests use realised historical first preferences, not a projected spread.",
  AUSPOL_ONP_CV = "Federal-forecast-only (One Nation allocation coefficient of variation for the live projection).",
  AUSPOL_ONP_FIX = "Federal-forecast-only (One Nation allocation fix for the live projection).",
  AUSPOL_ONP_ORDER = "Federal-forecast-only (One Nation allocation ordering for the live projection).",
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
    "the gap.")
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
  open_gap <- !is.null(r$note) && grepl("OPEN GAP", r$note)
  tag <- if (is.null(r$note)) "**UNEXPLAINED -- audit this**" else if (open_gap) "**OPEN GAP**" else "intentional / dead experiment"
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

# Run what CI runs, the way CI runs it.
#
# This script was named check_like_ci.R while doing only HALF of what CI does:
# the test suite with no anchor data. CI also runs
# `rcmdcheck(args = "--as-cran", error_on = "warning")`, and on 2026-08-16 that
# is what failed on a PR this script had just declared clean -- an undocumented
# `...` (a WARNING, and CI errors on warnings) and two data.table NSE variables
# read as undefined globals (a NOTE).
#
# A guard named after a thing it does not do is worse than no guard: it gets
# trusted. Both halves now run here.
#
# Every developer machine that has ever worked on this package has a populated
# `external/aus-polling-analyser/` clone. CI does not: `check.yaml` runs
# `R CMD check` with no anchor data at all, so every test guarded by
# `skip_if_no_anchor()` skips there and runs here. That gap is invisible until
# it isn't -- on 2026-08-16 a change gave `flows_for()` a new dependency on the
# election calendar, six tests started needing anchor data they had never
# needed, the suite passed locally, and the PR opened red.
#
# So: point the package at an empty directory and run everything. A test that
# fails here rather than skipping is a test that will fail on CI.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/check_like_ci.R"'

suppressMessages(devtools::load_all(quiet = TRUE))

empty <- file.path(tempdir(), "auspol-no-anchor")
dir.create(empty, showWarnings = FALSE, recursive = TRUE)
options(auspol.root = empty)

cat("=== running the suite with NO anchor data ===\n")
cat("auspol.root =", empty, "\n\n")

res <- testthat::test_dir("tests/testthat", stop_on_failure = FALSE,
                          reporter = testthat::SummaryReporter$new())

df <- as.data.frame(res)
n_fail <- sum(df$failed) + sum(df$error)
n_skip <- sum(df$skipped)
n_pass <- sum(df$passed)

cat(sprintf("\n=== %d passed, %d skipped, %d failed/errored ===\n",
            n_pass, n_skip, n_fail))

if (n_fail > 0) {
  stop(sprintf("%d test(s) fail without anchor data and will fail on CI. ",
               n_fail),
       "A test that needs the anchor must call skip_if_no_anchor(); a test ",
       "that should not need it has picked up a dependency by accident.")
}

# A suite where everything skipped would pass this check vacuously, which is
# the same shape as every other guard in this package that had to learn not to
# pass on an empty set.
if (n_pass < 100) {
  stop(sprintf("Only %d assertions ran without anchor data (expected 100+). ",
               n_pass),
       "Either the suite is mostly anchor-dependent now, or something is ",
       "skipping that should not be.")
}

cat("OK: nothing depends on anchor data that should not.\n")

# ---- Half one-and-a-half: a script's own default vs what ships --------------
#
# WHY. scripts/published_flags.R is meant to be the single source of truth for
# every AUSPOL_* switch. The six harnesses honour it by sourcing
# harness_defaults.R, which calls apply_published_flags(). The FITTING scripts
# did not: each carried its own `Sys.getenv("AUSPOL_X", "default")` literal,
# and two of them disagreed with what ships.
#
# fit_xgb_flows_v1.R defaulted AUSPOL_FLOW_FRAG to "0" while published_flags.R
# ships "1" and calls it "SHIPPED 2026-09-15 ON PETE'S CALL". So refitting the
# flow model the obvious way -- `Rscript scripts/fit_xgb_flows_v1.R`, clean
# environment -- dropped the lead_primary feature, wrote a normal-looking
# model file, and said nothing. Downstream reads only the artifact's column
# list, never the switch, so no consumer could tell. Found by the review gate
# 2026-09-16, along with the same shape in build_candidacies.R.
#
# NOTE ON SCOPE. The first version of this check asked whether every published
# switch appears in each harness's CAL_TAG fingerprint. That premise was wrong
# -- only 1 of 66 does, because CAL_TAG fingerprints switches you SWEEP, not
# published constants -- and it fired on 343 pairs. This version asks a
# question with an unambiguous right answer, which is why it finds 0 rather
# than 343 once the two real cases are fixed.
drift <- local({
  ex <- new.env()
  sys.source("scripts/published_flags.R", envir = ex)
  PF <- get("PUBLISHED_FLAGS", envir = ex)
  fs <- setdiff(c(Sys.glob("scripts/fit_*.R"), Sys.glob("scripts/build_*.R")),
                "scripts/fit_seats_full.R")  # applies the flags itself
  pat <- 'Sys\\.getenv\\(\\s*"(AUSPOL_[A-Z0-9_]+)"\\s*,\\s*"([^"]*)"\\s*\\)'
  out <- list()
  for (f in fs) {
    src <- readLines(f, warn = FALSE)
    # a switch named in a COMMENT is documentation, not behaviour
    src <- src[!grepl("^\\s*#", src)]
    # A script that applies the published flags cannot drift from them.
    # KNOWN WEAKNESS, stated rather than hidden: this is a grep, so a call
    # that is present but disabled -- commented out, or inside `if (FALSE)`
    # -- still exempts the file. Found while trying to break this check:
    # the first attempt disabled the call that way and the check stayed
    # quiet. Proving it fires needed a file with no call at all, which is
    # what the real pre-fix fit_xgb_flows_v1.R was.
    if (any(grepl("apply_published_flags|harness_defaults", src))) next
    for (hit in unlist(regmatches(src, gregexpr(pat, src)))) {
      g <- regmatches(hit, regexec(pat, hit))[[1]]
      if (!g[2] %in% names(PF)) next
      if (!identical(g[3], PF[[g[2]]])) {
        out[[length(out) + 1L]] <- sprintf(
          "  %-28s %-34s own default %-6s but ships %s",
          basename(f), g[2], dQuote(g[3], FALSE), dQuote(PF[[g[2]]], FALSE))
      }
    }
  }
  unique(unlist(out))
})
if (length(drift)) {
  cat(paste(drift, collapse = "\n"), "\n")
  stop("A script's own Sys.getenv() default disagrees with the value ",
       "scripts/published_flags.R ships, and the script never applies the ",
       "published flags. Running it plainly produces the NON-shipped ",
       "behaviour and prints nothing to say so. Either source ",
       "published_flags.R and call apply_published_flags(), or change the ",
       "inline default to match what ships.")
}
cat("OK: no fitting script's default disagrees with what published_flags.R ships.\n")

# ---- Half two: R CMD check --as-cran, warnings as errors --------------------
#
# The half this script was missing. Slower (a full build and check), so it runs
# second: a broken test suite should fail in seconds rather than after a build.
# Skippable with --tests-only while iterating, but never before opening a PR --
# that is exactly when it caught something.
if (!"--tests-only" %in% commandArgs(trailingOnly = TRUE)) {
  cat("\n=== R CMD check --as-cran (warnings are errors, as in CI) ===\n")
  if (!requireNamespace("rcmdcheck", quietly = TRUE)) {
    stop("rcmdcheck is not installed, so the half of CI that checks the ",
         "package cannot run here. Install it, or pass --tests-only and ",
         "accept that CI may still fail.")
  }
  res <- rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"),
                              build_args = "--no-manual",
                              error_on = "warning", quiet = TRUE)
  cat(sprintf("errors %d   warnings %d   notes %d\n",
              length(res$errors), length(res$warnings), length(res$notes)))
  if (length(res$notes)) {
    # Notes do not fail CI today, but they are how a warning starts: an
    # undefined global is a note until the same slip lands somewhere check
    # treats as an error. Print them rather than let them accumulate unseen.
    cat("\nNOTES (not fatal, but do not let them pile up):\n")
    for (x in res$notes) cat("  - ", gsub("\n", "\n    ", x), "\n", sep = "")
  }
  cat("\nOK: package checks clean the way CI checks it.\n")
}

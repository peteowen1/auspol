# Run the whole pipeline, in the one order that works.
#
# The stages are not independent: fit_projection.R writes the mix table that
# fit_seats.R and build_page.R both read, so running them out of order silently
# uses whatever was left in output/ from last time. That is exactly the class of
# error this package spends its pre-registered checks guarding against, and it
# was previously prevented only by remembering.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/run_all.R"'
#
#   --quick     skip the two slowest stages (federal and NSW cycles)
#   --stale-ok  proceed even if the poll data is old (for historical reruns)

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
quick <- "--quick" %in% args
stale_ok <- "--stale-ok" %in% args

cat("=== auspol pipeline ===\n")

# ---- Freshness first, before spending any time computing ----
cat("\nChecking poll data freshness:\n")
check_poll_freshness(c("vic", "fed", "nsw"), strict = !stale_ok)

STAGES <- list(
  list(f = "scripts/fit_vic.R",        what = "Victoria (live target)",  slow = FALSE),
  list(f = "scripts/fit_federal.R",    what = "federal cycles",          slow = TRUE),
  list(f = "scripts/fit_nsw.R",        what = "NSW cycles",              slow = TRUE),
  list(f = "scripts/fit_projection.R", what = "fundamentals + mix",      slow = FALSE),
  list(f = "scripts/fit_seats.R",      what = "seat simulation",         slow = FALSE),
  list(f = "scripts/fit_scorecard.R",  what = "pollster scorecard",      slow = FALSE),
  list(f = "scripts/build_page.R",     what = "public page",             slow = FALSE)
)

run <- function(stage) {
  cat(sprintf("\n--- %s (%s) ---\n", stage$what, stage$f))
  t0 <- Sys.time()
  # Each stage runs in a fresh R process. They set options and load data
  # globally, and a stage inheriting a previous one's environment would make
  # results depend on run order in ways nothing would surface.
  res <- system2("Rscript", stage$f, stdout = TRUE, stderr = TRUE)
  ok <- is.null(attr(res, "status")) || attr(res, "status") == 0
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (!ok) {
    cat(paste(utils::tail(res, 25), collapse = "\n"), "\n")
    stop(sprintf("STAGE FAILED: %s after %.0f s", stage$f, secs))
  }
  # Surface each stage's own checks rather than hiding them: these lines are
  # the whole point of the pre-registered discipline.
  keep <- grep("^(A[0-9]|N[0-9]|V[0-9]|H[0-9]|L[0-9]|P[0-9]|B[0-9]|C[0-9]|S[0-9]|R[0-9]|F1|O1)",
               res, value = TRUE)
  if (length(keep)) cat(paste(keep, collapse = "\n"), "\n")
  cat(sprintf("    ok (%.0f s)\n", secs))
  invisible(secs)
}

t_start <- Sys.time()
for (s in STAGES) {
  if (quick && s$slow) {
    cat(sprintf("\n--- %s: SKIPPED (--quick) ---\n", s$what))
    next
  }
  run(s)
}

cat(sprintf("\n=== pipeline complete in %.0f s ===\n",
            as.numeric(difftime(Sys.time(), t_start, units = "secs"))))
cat("Outputs in output/. Publish output/victoria-2026.html.\n")

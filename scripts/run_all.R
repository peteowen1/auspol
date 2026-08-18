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

# `target = FALSE` marks a stage that VALIDATES the model on a cycle nobody
# publishes. Those must not stop the live Victorian forecast: on 2026-08-17 the
# NSW 2027 cycle failed its L3 structural check -- first preferences summing to
# 94.1 against a 100 +/- 5 bound, because party trends are fitted independently
# and only sum to 100 by luck -- and that halted the whole run, so the Victoria
# page stopped refreshing for an election 102 days away over a validation cycle
# for one in 2027.
#
# A validation failure is still a FAILURE. It is reported prominently, and the
# run exits non-zero at the end so CI goes red and somebody looks. What changes
# is that a failure here no longer HALTS the run: the stages after it still run,
# so the Victorian forecast is still built and published. The order below is
# unchanged.
STAGES <- list(
  # Before anything that consumes a flow. Three seconds, and it is the only
  # thing standing between us and quietly running yesterday's winner after a
  # new election changes the ranking.
  list(f = "scripts/backtest_flows.R",  what = "preference-flow estimator", slow = FALSE),
  list(f = "scripts/fit_vic.R",        what = "Victoria (live target)",  slow = FALSE),
  list(f = "scripts/fit_federal.R",    what = "federal cycles",          slow = TRUE,  target = FALSE),
  list(f = "scripts/fit_nsw.R",        what = "NSW cycles",              slow = TRUE,  target = FALSE),
  list(f = "scripts/fit_projection.R", what = "fundamentals + mix",      slow = FALSE),
  list(f = "scripts/fit_seats.R",      what = "seat simulation (two-party)", slow = FALSE),
  # Candidate-level seats. Runs AFTER fit_seats.R because its S5 check compares
  # the two, and needs the election data fetched into external/elections --
  # it exits cleanly with instructions when that is absent, so a developer
  # without it still gets the rest of the pipeline.
  list(f = "scripts/fit_seats_full.R", what = "seat simulation (per seat)", slow = TRUE),
  list(f = "scripts/fit_scorecard.R",  what = "pollster scorecard",      slow = FALSE),
  list(f = "scripts/build_page.R",     what = "public page",             slow = FALSE)
)

run <- function(stage) {
  cat(sprintf("\n--- %s (%s) ---\n", stage$what, stage$f))
  t0 <- Sys.time()
  # Each stage runs in a fresh R process. They set options and load data
  # globally, and a stage inheriting a previous one's environment would make
  # results depend on run order in ways nothing would surface.
  #
  # stdout and stderr are captured SEPARATELY, and the stage runs under
  # options(warn = 1). Merging the streams (system2's stdout = TRUE, stderr =
  # TRUE) interleaves them unpredictably, and R's default deferred warnings
  # print "Warning message:" on one line with the text on the next — so any
  # attempt to pick warnings out of the merged text either finds the header
  # with no message, or swallows unrelated output that happened to follow it.
  # warn = 1 emits each warning complete on its own line as it happens.
  wrapper <- tempfile(fileext = ".R")
  # Forward slashes: on Windows normalizePath() returns backslashes, and
  # "C:\dev\..." inside an R string is read as the escape sequence \d.
  writeLines(c("options(warn = 1)",
               sprintf("source(%s)",
                       shQuote(normalizePath(stage$f, winslash = "/")))), wrapper)
  out_f <- tempfile(); err_f <- tempfile()
  status <- system2("Rscript", shQuote(wrapper), stdout = out_f, stderr = err_f)
  res <- if (file.exists(out_f)) readLines(out_f, warn = FALSE) else character(0)
  err <- if (file.exists(err_f)) readLines(err_f, warn = FALSE) else character(0)
  unlink(c(wrapper, out_f, err_f))
  ok <- identical(as.integer(status), 0L)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  # Surface each stage's own checks rather than hiding them: these lines are
  # the whole point of the pre-registered discipline.
  # {1,2} letters, because codes carry a REGION prefix: L3 is Victoria's
  # endpoint-sum check, FL3 the federal one, NL3 the NSW one. The first
  # version of this listed each family as a single letter followed by a
  # digit, so EVERY renamed code was dropped here -- before the extractor
  # below ever saw it. The summary lost them and, worse, the duplicate-code
  # guard could not see them either, so the guard the rename exists to serve
  # passed vacuously. That is the "incomplete grep for check codes" hazard
  # this repo has now hit four times; see CLAUDE.md.
  keep <- grep("^[A-Z]{1,2}[0-9]+[a-c]?[ ]", res, value = TRUE)

  if (length(keep)) cat(paste(keep, collapse = "\n"), "\n")

  # Check codes are hand-maintained identifiers spread across seven scripts,
  # and nothing was stopping two stages from claiming the same one. That is
  # not hypothetical: the page check shipped as B1, which fit_projection.R
  # already used for the bias-correction result, so the run summary carried
  # two different "B1" lines meaning different things. Record which stage
  # emits each code and report any code claimed twice.
  # Environments are reference objects, so assigning into them from inside
  # this function needs no <<- and mutates the one the caller checks.
  # [A-Z]+ not [A-Z]: codes carry a REGION prefix where the same structural
  # check runs on more than one cycle -- FL3 is the federal endpoint-sum
  # check, NL3 the NSW one, L3 Victoria's. Without the plus these parse to
  # nothing and the summary silently loses them.
  # NOTE the coupling: this pattern allows a longer letter run than the
  # filter above does, but it only ever sees lines the filter already let
  # through, so the FILTER is the binding constraint. A future three-letter
  # prefix would be dropped up there and never reach this line -- widen
  # both together or not at all.
  codes <- unique(sub("^([A-Z]+[0-9]+[a-c]?).*$", "\\1", keep))
  for (cd in codes) {
    # CODE_OWNER holds every stage that has claimed this code, not just the
    # most recent one. Storing a single owner made a three-way collision
    # report only the last pair, dropping the first stage from the message
    # that exists to say where to look.
    prev <- if (exists(cd, envir = CODE_OWNER, inherits = FALSE)) {
      get(cd, envir = CODE_OWNER)
    } else character(0)
    owners <- unique(c(prev, stage$f))
    if (length(owners) > 1L) {
      assign(cd, sprintf("%s (%s)", cd, paste(owners, collapse = " and ")),
             envir = CODE_CLASHES)
    }
    assign(cd, owners, envir = CODE_OWNER)
  }

  # WARNINGS TOO. A warning() exits 0, so `ok` stays TRUE, and its text does not
  # start with a check code — so filtering to check lines alone silently drops
  # every "parsed only N rows", "FP sums far from 100", "did not converge" and
  # "imputed share exceeds the OTH line" this package emits. Those are exactly
  # the messages that mean a human should look, and this was the one place they
  # went dark.
  # Under warn = 1 each warning is a complete "Warning in f(x) : text" line on
  # stderr, so this needs no block reassembly and cannot swallow neighbouring
  # output. The data.table build-version notice fires on every stage and means
  # nothing; reporting it six times would train the reader to ignore the one
  # column that exists to be noticed.
  # When the call is long R still breaks after "Warning in f(a, b) :" and puts
  # the message on the following indented line — so take that continuation,
  # otherwise the report names the function but never says what it complained
  # about, which is the half-useful version of not reporting at all.
  idx <- grep("^Warning", err)
  warns <- vapply(idx, function(i) {
    line <- trimws(err[i])
    if (grepl(":$", line) && i < length(err)) {
      line <- paste(line, trimws(err[i + 1]))
    }
    line
  }, character(1))
  warns <- unique(warns)
  warns <- warns[nzchar(warns) & !grepl("built under R version", warns)]
  if (length(warns)) {
    cat("    WARNINGS from this stage:\n")
    cat(paste0("      ", utils::head(warns, 12), collapse = "\n"), "\n")
    if (length(warns) > 12) cat(sprintf("      ...and %d more\n", length(warns) - 12))
  }
  # Failure is reported HERE rather than straight after the exit status, so a
  # failing stage still gets its check codes registered and its warnings shown.
  # The old placement returned early, which is why a collision involving a
  # stage that fails was invisible to the duplicate-code guard.
  if (!ok) {
    cat(paste(utils::tail(c(res, err), 25), collapse = "\n"), "\n")
    # A stage that exited non-zero having emitted NO check line never
    # reached its checks at all -- a missing anchor clone, a parse error,
    # an OOM kill. That needs a different reaction from "the model failed
    # a check we wrote down in advance", so do not let the summary call
    # the two the same thing.
    kind <- if (length(keep)) "CHECK FAILED" else "CRASHED before any check ran"
    stop(sprintf("%s: %s (exit %s) after %.0f s",
                 kind, stage$f, status, secs))
  }
  cat(sprintf("    ok (%.0f s)%s\n", secs,
              if (length(warns)) sprintf("  [%d warnings]", length(warns)) else ""))
  invisible(secs)
}

# Which stage emitted each check code, so a code claimed by two stages is
# reported rather than left ambiguous in the summary.
CODE_OWNER <- new.env(parent = emptyenv())
CODE_CLASHES <- new.env(parent = emptyenv())

t_start <- Sys.time()
FAILED_VALIDATION <- character(0)
for (s in STAGES) {
  if (quick && s$slow) {
    cat(sprintf("\n--- %s: SKIPPED (--quick) ---\n", s$what))
    next
  }
  if (is.null(s$target) || isTRUE(s$target)) {
    run(s)                     # a target failure still halts, as before
  } else {
    ok_msg <- ""
    ok <- tryCatch({ run(s); TRUE }, error = function(e) {
      ok_msg <<- conditionMessage(e)
      cat(sprintf("\n!! VALIDATION STAGE FAILED: %s\n   %s\n",
                  s$what, ok_msg))
      cat("   The live forecast continues; this run still exits non-zero.\n")
      FALSE
    })
    if (!isTRUE(ok)) FAILED_VALIDATION <- c(FAILED_VALIDATION, stats::setNames(ok_msg, s$what))
  }
}

if (length(FAILED_VALIDATION)) {
  cat("\n=== VALIDATION FAILURES ===\n")
  # The cause, not just the stage name: a reader who sees only this block
  # otherwise cannot tell a crash from a check that failed on the merits.
  for (i in seq_along(FAILED_VALIDATION)) {
    cat("   ", names(FAILED_VALIDATION)[i], "--", FAILED_VALIDATION[[i]],
        "\n")
  }
  cat("The Victorian forecast above was built and is publishable. These",
      "stages validate the model on cycles nobody publishes, and one of",
      "them is broken.\n")
}

clashes <- ls(CODE_CLASHES)
if (length(clashes)) {
  cat("\nDUPLICATE CHECK CODES -- the summary cannot say which is which:\n")
  for (cd in clashes) cat("   ", get(cd, envir = CODE_CLASHES), "\n")
  cat("   -> ", length(clashes),
      " check code(s) claimed by two stages. Renumber one of each pair.\n")
}

if (length(FAILED_VALIDATION) || length(clashes)) {
  stop("Run finished with problems: ",
       if (length(FAILED_VALIDATION))
         paste0(length(FAILED_VALIDATION), " validation stage(s) [",
                paste(names(FAILED_VALIDATION), collapse = ", "), "] ") else "",
       if (length(clashes))
         paste0(length(clashes), " duplicate check code(s)") else "")
}

cat(sprintf("\n=== pipeline complete in %.0f s ===\n",
            as.numeric(difftime(Sys.time(), t_start, units = "secs"))))
cat("Outputs in output/. Publish output/victoria-2026.html.\n")


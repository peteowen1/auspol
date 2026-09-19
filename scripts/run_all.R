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
  # The statewide party covariance fit_seats_full.R draws from. It writes to
  # output/, which is NOT cached between CI runs the way external/elections is,
  # so it has to be a pipeline stage rather than a fetch step -- and it was
  # neither, which is why the nightly run died on a bare gzfile() error for
  # output/statewide-cov.rds. Reads ten election pairs' first preferences and
  # nothing else; seconds, not minutes.
  list(f = "scripts/estimate_statewide_cov.R", what = "statewide covariance", slow = FALSE),
  # Candidate-level seats. Runs AFTER fit_seats.R because its S5 check compares
  # the two, and needs the election data fetched into external/elections --
  # it exits cleanly with instructions when that is absent, so a developer
  # without it still gets the rest of the pipeline.
  list(f = "scripts/fit_seats_full.R", what = "seat simulation (per seat)", slow = TRUE),
  list(f = "scripts/fit_scorecard.R",  what = "pollster scorecard",      slow = FALSE),
  list(f = "scripts/build_page.R",     what = "public page",             slow = FALSE),
  # The forecast as one JSON document + a history row, for the ITG page
  # (release-as-data-bus). Reads fit_seats_full.R's outputs only.
  list(f = "scripts/build_forecast_json.R", what = "forecast JSON",       slow = FALSE)
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
  #
  # [ !] NOT JUST [ ], AND {1,3} NOT {1,2} -- the FIFTH instance, found
  # 2026-09-13 review-gating an unrelated fix. Two separate gaps, both
  # silently dropping real check lines from the summary:
  #
  #   1. This codebase's own convention for "this check fired / something is
  #      wrong" is "CODE!" with the bang directly against the digit -- S5!,
  #      CV0!, PS0!, MP0p! and this file's own new CV1! all follow it -- and
  #      every one of them failed this regex, because the character after the
  #      optional [a-c] had to be a literal space. "CV0! fed2004: File does
  #      not exist" was invisible in run.log's summary in every CI run before
  #      this fix; only trailing "wrote output/..." lines (two spaces, no
  #      bang) ever surfaced.
  #   2. estimate_statewide_cov.R's own CVR1/CVR1! (a THREE-letter prefix --
  #      inconsistent with the rest of that file's CV0-CV7, but real,
  #      pre-existing, and not renamed here given CLAUDE.md's own record of
  #      renames silently breaking a grep elsewhere) needed one more letter of
  #      headroom than {1,2} allowed. Widened rather than renaming the code.
  keep <- grep("^[A-Z]{1,3}[0-9]+[a-c]?[ !]", res, value = TRUE)

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
    # Classify on the error text, via classify_stage_failure() in the package
    # so it can be tested -- CI has no anchor clone and cannot run a stage.
    # Two earlier versions of this logic were wrong in OPPOSITE directions:
    # keying on "did any check line print" called a crashed fit_federal.R a
    # failed check, and keying on "is not TRUE" would have called S5, G2, G3
    # and G7 -- bare stop() calls, this repo's most substantive checks --
    # crashes. It now needs positive evidence either way and says
    # "unclassified" rather than guessing a third time.
    err_lines <- grep("^Error", c(res, err), value = TRUE)
    last_err <- if (length(err_lines)) utils::tail(err_lines, 1) else ""
    kind <- stage_failure_label(classify_stage_failure(last_err))
    stop(sprintf("%s: %s (exit %s) after %.0f s%s",
                 kind, stage$f, status, secs,
                 if (nzchar(last_err)) paste0(" -- ", last_err) else ""))
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

# A breach recorded by fit_vic.R. That stage deliberately does NOT halt -- it
# is the target, and halting means the Victorian forecast never publishes --
# so it writes the breach here instead and the run fails on it AFTER the page
# has been built.
#
# Without this the run went red only because fit_nsw.R happened to breach the
# same check on the same party. NSW is accruing polls; when its gap closes,
# a live breach on the PUBLISHED forecast would have gone green with nothing
# to notice. A guard whose alarm depends on an unrelated guard also firing is
# not a guard.
L3_MARKER <- file.path("output", "L3-BREACH.txt")
l3_breach <- if (file.exists(L3_MARKER)) readLines(L3_MARKER, warn = FALSE) else character(0)
l3_breach <- l3_breach[nzchar(trimws(l3_breach))]
if (length(l3_breach)) {
  cat("\n=== L3 BREACH ON THE PUBLISHED CYCLE ===\n")
  for (b in l3_breach) cat("   ", b, "\n")
  cat("The forecast above was still built and published: the gap is recorded\n",
      "   and explained beside the trend chart, not hidden. This run exits\n",
      "   non-zero so it cannot pass unnoticed.\n")
}

# S7 is the same check as L3, on the fit that is actually PUBLISHED.
#
# L3 asserts on fit_vic.R's per-cycle-sigma fit; fit_seats_full.R publishes a
# trend_as_at() fit with the DEFAULTS, and until 2026-09-14 nothing asserted on
# that one at all. The two are not interchangeable: they give different answers
# for the same party on the same polls, and on data four weeks old they sat on
# OPPOSITE SIDES of the bound -- One Nation 2.44 off its polls in the fit L3
# checks and 2.85 off in the fit that ships. On current data it is 2.44 against
# 2.47, both inside. Which side of 2.5 the published fit lands on is decided by
# a couple of polls, so "L3 is green" has never been evidence about it.
#
# DELIBERATELY NOT GATED ON `quick`, and that is the opposite of NL3.
#
# The first version of this block was gated on `!quick`, copied from NL3, under
# a comment claiming it was not gated and that --quick "also skips the page".
# Both halves were wrong, and the second one is the bug: build_page.R is
# `slow = FALSE`, so --quick SKIPS fit_seats_full.R AND STILL PUBLISHES THE
# PAGE, from the seat-probs files already on disk. Found by review, 2026-09-14.
#
# That inverts NL3's reasoning. NL3's gate is right because fit_nsw.R validates
# a cycle nobody publishes, so declining to read its marker loses nothing live.
# S7's marker describes the statewide trend behind the seat-probs files that
# build_page.R publishes FROM -- so it applies to the page whenever the page
# was built, whether or not the stage ran this invocation. A --quick run after
# a breaching full run would republish the breaching page and exit 0, with no
# message anywhere saying S7 had not been looked at.
#
# So: read it whenever it exists, and let the marker's own header say whether
# it describes the published configuration.
S7_MARKER <- file.path("output", "S7-BREACH.txt")
s7_raw <- if (file.exists(S7_MARKER)) readLines(S7_MARKER, warn = FALSE) else character(0)
s7_hdr <- grep("^#run ", s7_raw, value = TRUE)
s7_breach <- s7_raw[!startsWith(s7_raw, "#") & nzchar(trimws(s7_raw))]
# A run on a non-default configuration measures something nobody publishes, so
# its breaches are reported and NOT failed on. Absent a header the file predates
# this format; treat it as default rather than silently discounting a breach.
s7_default <- !length(s7_hdr) || !grepl("default_run=FALSE", s7_hdr[1], fixed = TRUE)
if (length(s7_breach) && !s7_default) {
  cat("\nS7  breach(es) recorded, but by a NON-DEFAULT run:\n")
  for (b in s7_breach) cat("   ", b, "\n")
  cat("   ", s7_hdr[1], "\n")
  cat("   This describes a configuration that is not published, so the run is\n",
      "   NOT failed on it. The published config has not been checked since.\n")
  s7_breach <- character(0)
}
if (!file.exists(S7_MARKER)) {
  # Missing is NOT the same as clean: the stage writes this file on every run,
  # breach or not. Absent means it never got here.
  cat("\nS7  no marker: fit_seats_full.R has not recorded a poll-tracking\n",
      "    verdict for the published trend. It was skipped or died before S7.\n")
} else if (length(s7_breach)) {
  cat("\n=== S7 BREACH ON THE PUBLISHED FORECAST'S OWN TREND ===\n")
  for (b in s7_breach) cat("   ", b, "\n")
  if (length(s7_hdr)) cat("   ", s7_hdr[1], "\n")
  if (quick) {
    cat("   RECORDED BY AN EARLIER RUN -- this one was --quick, so\n",
        "   fit_seats_full.R did not re-check. build_page.R is NOT a slow\n",
        "   stage, so the page WAS rebuilt from the seat-probs these lines\n",
        "   describe.\n")
  }
  cat("   This is the statewide level that fit_seats_full.R feeds to every\n",
      "   seat, so the gap is not confined to the trend chart. The page was\n",
      "   still built -- it is the target -- and this run exits non-zero.\n")
}

# The same treatment for NSW, in its OWN marker file and under its own
# heading. fit_nsw.R stopped halting on NL3 once two pre-registered experiments
# aborted on whether its One Nation breach is the fit or the check; it reports
# and continues, exactly as fit_vic.R does, and the run still fails here.
#
# Kept separate from L3_MARKER on purpose. NSW's breach must never be able to
# stand in for -- or overwrite -- one on the published cycle, which is the
# failure the block above was written to prevent.
#
# GATED ON WHETHER fit_nsw.R ACTUALLY RAN. It is a `slow` stage, so --quick
# skips it -- and the marker is only refreshed (unlinked and rewritten) by the
# stage itself. Reading it after a skip reports a PREVIOUS run's verdict for a
# stage this run never checked, which is a stale-state bug in the same family
# as the one the separation above prevents. It can only ever add a failure,
# never remove one, but "cried wolf about a fixed problem" and "looks like NSW
# was checked when it wasn't" are both wrong.
#
# fit_vic.R needs no such gate: it is not `slow`, so it runs on every
# invocation and always freshens L3-BREACH.txt.
NL3_MARKER <- file.path("output", "NL3-BREACH.txt")
nsw_ran <- !quick
nl3_breach <- if (nsw_ran && file.exists(NL3_MARKER)) {
  readLines(NL3_MARKER, warn = FALSE)
} else character(0)
nl3_breach <- nl3_breach[nzchar(trimws(nl3_breach))]
if (!nsw_ran && file.exists(NL3_MARKER)) {
  cat("\nNL3  not checked this run (--quick skipped fit_nsw.R); a marker from\n",
      "     an earlier run is present and is deliberately NOT being read.\n")
}
if (length(nl3_breach)) {
  cat("\n=== NL3 BREACH ON AN NSW CYCLE (not the published forecast) ===\n")
  for (b in nl3_breach) cat("   ", b, "\n")
  cat("   NSW 2027's One Nation has very few polls in the 90-day window and\n",
      "   two pre-registered experiments aborted on whether this is the fit or\n",
      "   the check -- see docs/plans/prereg-poll-tracking-bound-scaling.md.\n",
      "   The stage was NOT halted, so its other output still built. This run\n",
      "   exits non-zero so it cannot pass unnoticed.\n")
}

clashes <- ls(CODE_CLASHES)
if (length(clashes)) {
  cat("\nDUPLICATE CHECK CODES -- the summary cannot say which is which:\n")
  for (cd in clashes) cat("   ", get(cd, envir = CODE_CLASHES), "\n")
  cat("   -> ", length(clashes),
      " check code(s) claimed by two stages. Renumber one of each pair.\n")
}

if (length(FAILED_VALIDATION) || length(clashes) || length(l3_breach) ||
    length(s7_breach) || length(nl3_breach)) {
  stop("Run finished with problems: ",
       if (length(FAILED_VALIDATION))
         paste0(length(FAILED_VALIDATION), " validation stage(s) [",
                paste(names(FAILED_VALIDATION), collapse = ", "), "] ") else "",
       if (length(clashes))
         paste0(length(clashes), " duplicate check code(s)") else "",
       if (length(l3_breach))
         paste0(" ", length(l3_breach), " L3 breach(es) on the published cycle") else "",
       if (length(s7_breach))
         paste0(" ", length(s7_breach),
                " S7 breach(es) on the published forecast's own trend") else "",
       if (length(nl3_breach))
         paste0(" ", length(nl3_breach), " NL3 breach(es) on an NSW cycle") else "")
}

cat(sprintf("\n=== pipeline complete in %.0f s ===\n",
            as.numeric(difftime(Sys.time(), t_start, units = "secs"))))
cat("Outputs in output/. Publish output/victoria-2026.html.\n")


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
  fs <- setdiff(c(Sys.glob("scripts/fit_*.R"), Sys.glob("scripts/build_*.R"), Sys.glob("R/*.R")),
                "scripts/fit_seats_full.R")  # applies the flags itself
  # R/ added 2026-10-02: package functions cannot apply the published flags, so
  # their inline defaults ARE the behaviour of any run outside the rebuild. 18
  # defaulted "off" for switches that ship on (AUSPOL_LEVEL_RECIPE "anchored"
  # vs "live", ...), and stage 3 built the model's training features under
  # them -- a train/serve mismatch in v56-v57.
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
    if (!startsWith(f, "R/") && any(grepl("apply_published_flags|harness_defaults", src))) next
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
#
# SKIPPED WHEN THE PACKAGE IS BYTE-IDENTICAL TO THE LAST CLEAN CHECK (Pete,
# 2026-09-30: four checks that day cost ~40 minutes, and two touched only
# scripts/, web/, docs and workflows, which R CMD build never sees). The
# fingerprint covers every file the build would include -- tracked and
# untracked, .Rbuildignore applied the way R applies it (case-insensitive,
# to every parent directory) -- plus the R version. Same fingerprint, same
# tarball, same result. --force-check always runs it.
.pkg_fingerprint <- function() {
  f <- unique(c(system2("git", "ls-files", stdout = TRUE),
                system2("git", c("ls-files", "--others", "--exclude-standard"), stdout = TRUE)))
  f <- f[file.exists(f)]
  ign <- trimws(readLines(".Rbuildignore", warn = FALSE)); ign <- ign[nzchar(ign) & !startsWith(ign, "#")]
  ignored <- vapply(f, function(p) {
    parts <- strsplit(p, "/", fixed = TRUE)[[1]]
    anc <- vapply(seq_along(parts), function(i) paste(parts[seq_len(i)], collapse = "/"), character(1))
    any(vapply(ign, function(re) any(grepl(re, anc, perl = TRUE, ignore.case = TRUE)), logical(1)))
  }, logical(1))
  keep <- sort(f[!ignored])
  # Installed versions of everything DESCRIPTION depends on: an upgraded
  # dependency can change the check's result with no file here changing.
  d <- read.dcf("DESCRIPTION", fields = c("Depends", "Imports", "Suggests", "LinkingTo"))
  deps <- unique(trimws(sub("\\(.*$", "", unlist(strsplit(paste(d[!is.na(d)], collapse = ","), ",")))))
  deps <- sort(setdiff(deps[nzchar(deps)], "R"))
  ver <- vapply(deps, function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) "missing"), character(1))
  tf <- tempfile(); on.exit(unlink(tf))
  # The version bump that follows every merged PR (DESCRIPTION's Version line
  # and its NEWS.md section) forced a full ~5-minute check on the next push
  # every time, though neither can change what check reports (2026-10-09;
  # scripts/ was already outside the build, so it was never the cause). So
  # DESCRIPTION is hashed without its Version line and NEWS.md is not hashed.
  # CI still checks both on every PR.
  hashed <- setdiff(keep, "NEWS.md")
  md5 <- unname(tools::md5sum(hashed))
  if ("DESCRIPTION" %in% hashed) {
    dl <- readLines("DESCRIPTION", warn = FALSE)
    td <- tempfile(); writeLines(dl[!startsWith(dl, "Version:")], td)
    md5[hashed == "DESCRIPTION"] <- unname(tools::md5sum(td)); unlink(td)
  }
  # .Rbuildignore excludes itself from `keep`, but it decides what is built, so hash it too.
  writeLines(c(R.version.string, paste(deps, ver), paste(hashed, md5), readLines(".Rbuildignore", warn = FALSE)), tf)
  list(hash = unname(tools::md5sum(tf)), n = length(keep), files = keep)
}
.fp_file <- file.path("output", ".check-like-ci-last-clean.txt")
.args <- commandArgs(trailingOnly = TRUE)
.fp <- if (!"--tests-only" %in% .args) .pkg_fingerprint() else NULL
.last <- if (file.exists(.fp_file)) readLines(.fp_file, warn = FALSE) else character(0)
if (!is.null(.fp) && !"--force-check" %in% .args && length(.last) && identical(.last[1], .fp$hash)) {
  cat(sprintf("\n=== R CMD check SKIPPED: the %d files the package build includes are byte-identical to the last clean check (%s, %s). --force-check runs it anyway. ===\n",
              .fp$n, substr(.fp$hash, 1, 10), if (length(.last) > 1) .last[2] else "?"))
  cat("\nOK: package checks clean the way CI checks it (unchanged since the last clean check).\n")
} else if (!"--tests-only" %in% .args) {
  cat(sprintf("\n=== R CMD check --as-cran (warnings are errors, as in CI; %d package files, fingerprint %s) ===\n",
              .fp$n, substr(.fp$hash, 1, 10)))
  if (!requireNamespace("rcmdcheck", quietly = TRUE)) {
    stop("rcmdcheck is not installed, so the half of CI that checks the ",
         "package cannot run here. Install it, or pass --tests-only and ",
         "accept that CI may still fail.")
  }
  # Check a CLEAN COPY holding only the files the build includes (the same list
  # the fingerprint hashed). R CMD build copies the WHOLE directory before it
  # applies .Rbuildignore: output/, external/ and .claude/worktrees/ (agent
  # worktrees with full rebuild snapshots) made that copy take ~7 minutes, and on
  # 2026-10-07 a snapshot path past Windows' 260-character limit failed it outright
  # ("copying to build directory failed"). The checked files are identical; only
  # the discarded bulk is skipped.
  .src <- file.path(tempfile("check-like-ci-"), "auspol")
  for (d in unique(dirname(.fp$files))) dir.create(file.path(.src, d), recursive = TRUE, showWarnings = FALSE)
  .ok <- file.copy(.fp$files, file.path(.src, .fp$files), copy.date = TRUE)
  if (!all(.ok)) stop("check_like_ci: could not copy ", sum(!.ok), " package file(s) to ", .src, ": ",
                      paste(utils::head(.fp$files[!.ok], 5), collapse = ", "), call. = FALSE)
  file.copy(".Rbuildignore", .src)
  cat(sprintf("checking a clean copy of %d files in %s\n", length(.fp$files), .src))
  res <- rcmdcheck::rcmdcheck(path = .src, args = c("--no-manual", "--as-cran"),
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
  # Only a clean check is recorded: error_on = "warning" above has already
  # stopped the script on anything worse.
  dir.create(dirname(.fp_file), showWarnings = FALSE)
  writeLines(c(.fp$hash, format(Sys.time(), "%Y-%m-%d %H:%M")), .fp_file)
}

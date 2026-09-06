# PUBLISHED DEFAULTS FOR THE FIVE BACKTEST HARNESSES.
#
# Sourced by scripts/backtest_candidate_{fed,vic,nsw,sa,wa}.R immediately after
# load_all() and before the first Sys.getenv("AUSPOL_...") read. Every switch
# the caller has NOT set takes the value in scripts/published_flags.R, so a
# harness launched with no environment measures the configuration that ships.
# A switch the caller DID set is left alone, so every experimental arm still
# works exactly as before -- it just has to name what it changes.
#
# The federal harness additionally runs in forecast mode (statewide input from
# polls as at election day, the way the published forecast is built) unless
# told otherwise; the state harnesses have no forecast mode and inject the
# actual result, which is documented in docs/plans/plan-miss-patterns-2026-09-06.md.
#
# AUSPOL_HARNESS_RAW=1 skips all of this and reproduces the pre-2026-09-06
# behaviour (everything off) for comparison with old output files. The arm
# fingerprint in each harness's CAL_TAG hashes every set AUSPOL_* variable, so
# a run at published defaults and an old bare run cannot share a filename.
#
# Prints HD0/HD1 so the log says what was applied and what the caller chose.
source("scripts/published_flags.R")
if (identical(Sys.getenv("AUSPOL_HARNESS_RAW", "0"), "1")) {
  cat("HD0  AUSPOL_HARNESS_RAW=1: published defaults NOT applied; unset switches are off\n")
} else {
  .caller_set <- names(PUBLISHED_FLAGS)[nzchar(Sys.getenv(names(PUBLISHED_FLAGS), unset = ""))]
  .applied <- apply_published_flags()
  if (exists(".harness_forecast_mode") && isTRUE(.harness_forecast_mode) &&
      !nzchar(Sys.getenv("AUSPOL_FORECAST_MODE", ""))) {
    Sys.setenv(AUSPOL_FORECAST_MODE = "1")
    .applied <- c(.applied, "AUSPOL_FORECAST_MODE")
  }
  cat(sprintf("HD0  published defaults applied to %d unset switch(es): %s\n",
              length(.applied),
              paste(sprintf("%s=%s", .applied, Sys.getenv(.applied)), collapse = " ")))
  cat(sprintf("HD1  caller set %d switch(es): %s\n", length(.caller_set),
              if (length(.caller_set)) paste(sprintf("%s=%s", .caller_set, Sys.getenv(.caller_set)), collapse = " ") else "(none -- this run measures what ships)"))
  rm(.caller_set, .applied)
}

# THE CODE VERSION GOES INTO THE OUTPUT FILENAME. The arm fingerprint hashes
# the environment only, so on 2026-09-06 an arm run with changed CODE and the
# same switches wrote over the baseline's per-party tables under the same
# name. Every harness appends this to CAL_TAG: the short git commit, with an
# "x" when R/ or scripts/ carry uncommitted changes.
.code_tag <- local({
  sha <- tryCatch(suppressWarnings(system2("git", c("rev-parse", "--short=7", "HEAD"), stdout = TRUE, stderr = FALSE)),
                  error = function(e) character(0))
  dirty <- tryCatch(length(suppressWarnings(system2("git", c("status", "--porcelain", "--", "R", "scripts"), stdout = TRUE, stderr = FALSE))) > 0,
                    error = function(e) FALSE)
  if (!length(sha) || !nzchar(sha[1])) "" else sprintf("-g%s%s", sha[1], if (dirty) "x" else "")
})
cat(sprintf("HD2  code %s\n", if (nzchar(.code_tag)) sub("^-g", "", .code_tag) else "(not a git checkout)"))

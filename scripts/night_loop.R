# ELECTION-NIGHT LOOP: poll the snapshot source every N seconds, run a cycle when a new snapshot appears.
#
#   Rscript scripts/night_loop.R --every=60 [--max-cycles=0] [--retries=3] <the same flags as scripts/night_runner.R>
#
# A bad snapshot is archived (raw), logged, retried up to --retries times (it may be half written), then skipped
# until a NEWER one lands. The last good JSON is never touched by a failed cycle (night_publish_json writes a temp
# file and renames, only after the document reads back). The prior state and reference table are read once.
# Stop the loop with Ctrl+C (or --max-cycles=N for tests). One R process; it never starts others.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")   # the published configuration, as night_replay.R and the harnesses apply it
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
need <- function(n) { v <- flag(n); if (is.null(v)) stop("NR2! --", n, "= is required"); v }
cfg <- list(source = need("source"), archive = need("archive"), setup = flag("setup", need("source")), state = need("state"), ref = need("ref"),
            out = need("out"), base_json = flag("base-json"), gap_k = as.numeric(flag("gap_k", "5")),
            sims = if (!is.null(flag("sims"))) as.integer(flag("sims")) else NULL,
            use_tcp = identical(flag("tcp", "1"), "1"), allow_stub = identical(flag("allow-stub", "0"), "1"), cache = new.env())
every <- as.numeric(flag("every", "60")); max_cycles <- as.integer(flag("max-cycles", "0")); retries <- as.integer(flag("retries", "3"))
log_f <- file.path(cfg$archive, "night-loop.log")
dir.create(cfg$archive, recursive = TRUE, showWarnings = FALSE)
say <- function(...) { l <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ", ...); cat(l, "\n"); cat(l, "\n", file = log_f, append = TRUE) }
last_ok <- NULL; fails <- 0L; last_try <- NULL; cycles <- 0L
say("loop start: every ", every, "s, source ", cfg$source)
repeat {
  newest <- night_snapshot_stamp(night_fetch_snapshot(cfg$source))
  skip <- identical(newest, last_ok) || (identical(newest, last_try) && fails >= retries)
  if (!is.na(newest) && !skip) {
    r <- tryCatch(night_cycle(cfg), error = function(e) list(status = "failed", stamp = newest, summary = paste("FAILED (uncaught):", conditionMessage(e))))
    say(r$summary)
    cycles <- cycles + 1L
    if (identical(r$status, "ok")) { last_ok <- newest; fails <- 0L; last_try <- NULL }
    else { fails <- if (identical(newest, last_try)) fails + 1L else 1L; last_try <- newest
           if (fails >= retries) say("giving up on ", newest, " after ", fails, " attempts; waiting for a newer snapshot (last good JSON untouched)") }
  }
  if (max_cycles > 0L && cycles >= max_cycles) break
  Sys.sleep(every)
}
say("loop end")

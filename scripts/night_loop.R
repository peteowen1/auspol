# ELECTION-NIGHT LOOP: poll the snapshot source every N seconds, run a cycle when a new snapshot appears.
#
#   Rscript scripts/night_loop.R --every=60 [--max-cycles=0] [--retries=3] [--stale-min=20] <the same flags as scripts/night_runner.R> [--upload-key=auspol/night/vic2026.json]
#
# A bad snapshot is archived (raw), logged, retried up to --retries times (it may be half written), then skipped
# until a NEWER one lands. The last good JSON is never touched by a failed cycle (night_publish_json writes a temp
# file and renames, only after the document reads back). The prior state and reference table are read once.
# Stop the loop with Ctrl+C (or --max-cycles=N for tests). One R process; with --upload-key it also runs scripts/night_publish_r2.sh (bash + wrangler) after each good cycle.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")   # the published configuration, as night_replay.R and the harnesses apply it
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
need <- function(n) { v <- flag(n); if (is.null(v)) stop("NWL1! --", n, "= is required"); v }
cfg <- list(source = need("source"), archive = need("archive"), setup = flag("setup", need("source")), state = need("state"), ref = need("ref"),
            out = need("out"), base_json = flag("base-json"), gap_k = as.numeric(flag("gap_k", "5")),
            sims = if (!is.null(flag("sims"))) as.integer(flag("sims")) else NULL,
            use_tcp = identical(flag("tcp", "1"), "1"), allow_stub = identical(flag("allow-stub", "0"), "1"),
            turnout = flag("turnout"), council_lean = flag("council-lean"), early_partial = identical(flag("early-partial", "0"), "1"), allow_unmatched = identical(flag("allow-unmatched", "0"), "1"), allow_projected = identical(flag("allow-projected", "0"), "1"),
            surge_fade = !identical(flag("surge-fade", "1"), "0"), tcp_center = flag("tcp-center", "median"), tcp_flow_floor = as.numeric(flag("tcp-flow-floor", "0.01")), tcp_own_fp = identical(flag("tcp-own-fp", "0"), "1"), tcp_pair_cal = flag("tcp-pair-cal", "fitted"), source_type = flag("source-type", "feed"), enrolment = flag("enrolment"), places = flag("places"), cand_ref = flag("cand-ref"), class_split = flag("class-split"), cache = new.env())
upload_key <- flag("upload-key")   # e.g. auspol/night/vic2026.json: after each good cycle, scripts/night_publish_r2.sh uploads --out there
every <- as.numeric(flag("every", "60")); max_cycles <- as.integer(flag("max-cycles", "0")); retries <- as.integer(flag("retries", "3"))
# --stale-min: warn (NWL3, once per quiet spell) when no new snapshot has appeared for this many minutes; 0 turns it off.
stale_min <- as.numeric(flag("stale-min", "20")); stale <- NULL
log_f <- file.path(cfg$archive, "night-loop.log")
dir.create(cfg$archive, recursive = TRUE, showWarnings = FALSE)
say <- function(...) { l <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "  ", ...); cat(l, "\n"); cat(l, "\n", file = log_f, append = TRUE) }
last_ok <- NULL; fails <- 0L; last_try <- NULL; cycles <- 0L
say("loop start: every ", every, "s, source ", cfg$source)
repeat {
  # the website source's snapshots are folders (night_web_latest()); the feed's are files (night_fetch_snapshot()).
  # Before 11 Nov 2026 this read the feed only, so a --source-type=web loop waited forever (dress rehearsal).
  newest <- night_snapshot_stamp(if (identical(cfg$source_type, "web")) night_web_latest(cfg$source) else night_fetch_snapshot(cfg$source))
  stale <- night_stale_check(stale, newest, Sys.time(), stale_min)
  if (!is.null(stale$message)) say(stale$message)
  skip <- identical(newest, last_ok) || (identical(newest, last_try) && fails >= retries)
  if (!is.na(newest) && !skip) {
    r <- tryCatch(night_cycle(cfg), error = function(e) list(status = "failed", stamp = newest, summary = paste("FAILED (uncaught):", conditionMessage(e))))
    say(r$summary)
    cycles <- cycles + 1L
    if (identical(r$status, "ok")) { last_ok <- newest; fails <- 0L; last_try <- NULL
      # a failed upload leaves the site on the previous file; logged loudly, retried with the next snapshot
      if (!is.null(upload_key)) { up <- suppressWarnings(system2("bash", c("scripts/night_publish_r2.sh", shQuote(cfg$out), shQuote(upload_key)), stdout = TRUE, stderr = TRUE))
        say(if (length(up)) paste(up, collapse = " | ") else "NWL2! upload produced no output", if (!is.null(attr(up, "status"))) paste0("  (exit ", attr(up, "status"), ")") else "") } }
    else { fails <- if (identical(newest, last_try)) fails + 1L else 1L; last_try <- newest
           if (fails >= retries) say("giving up on ", newest, " after ", fails, " attempts; waiting for a newer snapshot (last good JSON untouched)") }
  }
  if (max_cycles > 0L && cycles >= max_cycles) break
  Sys.sleep(every)
}
say("loop end")

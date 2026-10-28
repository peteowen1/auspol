# ELECTION-NIGHT RUNNER, ONE CYCLE (map #148). See R/night_runner.R.
#
#   Rscript scripts/night_runner.R --source=<folder of snapshot ZIPs> --archive=<raw archive folder> \
#     --setup=<folder holding the set-up Candidates XML> --state=<state.rds> --ref=<output/booths-vicYYYY.csv> \
#     --out=<forecast-night.json> [--base-json=<published forecast json>] [--gap_k=5] [--sims=N] [--tcp=1] [--allow-stub=0]
#
# --state is the afternoon forecast saved with AUSPOL_NIGHT_DUMP (scripts/night_replay.R header);
# --ref is the booth table of the election BEFORE the one being counted (the state's `from`).
# No credential is read or written here: the snapshot source is night_fetch_snapshot() (R/night_runner.R).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")   # the published configuration, as night_replay.R and the harnesses apply it
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
need <- function(n) { v <- flag(n); if (is.null(v)) stop("NR2! --", n, "= is required"); v }
cfg <- list(source = need("source"), archive = need("archive"), setup = flag("setup", need("source")), state = need("state"), ref = need("ref"),
            out = need("out"), base_json = flag("base-json"), gap_k = as.numeric(flag("gap_k", "5")),
            sims = if (!is.null(flag("sims"))) as.integer(flag("sims")) else NULL,
            use_tcp = identical(flag("tcp", "1"), "1"), allow_stub = identical(flag("allow-stub", "0"), "1"))
r <- night_cycle(cfg)
cat(r$summary, "\n")
quit(status = if (r$status == "failed") 1L else 0L)

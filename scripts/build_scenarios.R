# What-if slider, step 1 of 2: run the forecast with one party's statewide
# first preference forced to each of nine levels, 10 points either side of
# today in 2.5-point steps (plans/scenario-tool-scoping-2026-10-03.md; Pete's
# decisions 2026-10-04 and 2026-10-08).
#
#   Rscript scripts/build_scenarios.R [--target=vic2026] [--parties=ONP,ALP,LNP,GRN]
#                                     [--modes=exact,polled] [--offsets=-10,-7.5,...,10]
#
# exact  = AUSPOL_FORCE_FP_RULE=draws: the party gets exactly X% in every simulation.
# polled = AUSPOL_FORCE_FP_RULE=draws-polled: X% is where it is expected to land.
#
# Needs a default run of fit_seats_full.R first: it writes the levels
# (output/statewide-level-<stem>.csv) and the regression betas the forced runs
# read. Each scenario is a separate fit_seats_full.R process writing suffixed
# files (-scn-<mode>-<party>-<offset>), so a killed batch keeps every scenario
# it finished, and a rerun skips any whose outputs are newer than today's
# levels. scripts/combine_scenarios.R turns the lot into one JSON.

suppressMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
TARGETS <- c(vic2026 = "vic-2026", nsw2027 = "nsw-2027")
TARGET  <- arg("target", Sys.getenv("AUSPOL_TARGET", "vic2026"))
if (!TARGET %in% names(TARGETS)) stop("SC0! unknown --target ", TARGET)
STEM    <- TARGETS[[TARGET]]
PARTIES <- strsplit(arg("parties", "ONP,ALP,LNP,GRN"), ",")[[1]]
MODES   <- strsplit(arg("modes", "exact,polled"), ",")[[1]]
OFFSETS <- as.numeric(strsplit(arg("offsets", "-10,-7.5,-5,-2.5,0,2.5,5,7.5,10"), ",")[[1]])
RULE    <- c(exact = "draws", polled = "draws-polled")
if (!all(MODES %in% names(RULE))) stop("SC0! --modes must be exact and/or polled")
if (anyNA(OFFSETS)) stop("SC0! --offsets did not parse as numbers")

lvl_f <- sprintf("output/statewide-level-%s.csv", STEM)
bet_f <- sprintf("output/statewide-draw-betas-%s.csv", STEM)
for (f in c(lvl_f, bet_f)) if (!file.exists(f) || file.size(f) == 0)
  stop("SC0! ", f, " missing -- run fit_seats_full.R (AUSPOL_TARGET=", TARGET, ") with no switches first")
lvl <- fread(lvl_f, showProgress = FALSE)
today <- setNames(lvl$level, lvl$party)
if (!all(PARTIES %in% names(today))) stop("SC0! no level for ", paste(setdiff(PARTIES, names(today)), collapse = ", "))
cat(sprintf("SC1  %s: today %s\n", TARGET, paste(sprintf("%s %.2f", names(today), today), collapse = ", ")))

suffix <- function(mode, party, off) sprintf("-scn-%s-%s-%s", mode, party, formatC(off, format = "f", digits = 1, flag = "+"))
outs   <- function(sfx) sprintf("output/%s-%s%s.csv", c("seat-sims-full", "seat-probs"), STEM, sfx)
dir.create("output/scenario-logs", showWarnings = FALSE)
plan <- CJ(mode = MODES, party = PARTIES, off = OFFSETS, sorted = FALSE)
lvl_time <- file.mtime(lvl_f)
done <- 0L; skipped <- 0L; failed <- character(0)
for (i in seq_len(nrow(plan))) {
  m <- plan$mode[i]; p <- plan$party[i]; o <- plan$off[i]
  x <- today[[p]] + o
  sfx <- suffix(m, p, o)
  if (x < 0.5) { cat(sprintf("SC2  %s %s %+.1f -> %.2f is below 0.5%%, not run\n", m, p, o, x)); next }
  of <- outs(sfx)
  if (all(file.exists(of)) && all(file.size(of) > 0) && all(file.mtime(of) > lvl_time)) {
    skipped <- skipped + 1L; next
  }
  Sys.setenv(AUSPOL_TARGET = TARGET, AUSPOL_FORCE_FP = sprintf("%s=%.12f", p, x),
             AUSPOL_FORCE_FP_RULE = RULE[[m]], AUSPOL_OUT_SUFFIX = sfx)
  log_f <- sprintf("output/scenario-logs/%s%s.log", STEM, sfx)
  t0 <- Sys.time()
  status <- system2("Rscript", "scripts/fit_seats_full.R", stdout = log_f, stderr = log_f)
  Sys.unsetenv(c("AUSPOL_FORCE_FP", "AUSPOL_FORCE_FP_RULE", "AUSPOL_OUT_SUFFIX"))
  log <- readLines(log_f, warn = FALSE)
  ok <- identical(status, 0L) && all(file.exists(of)) && all(file.mtime(of) > t0)
  cat(sprintf("SC3  [%d/%d] %s %s %+.1f (%.2f%%): %s in %.0fs | %s\n", i, nrow(plan), m, p, o, x,
              if (ok) "ok" else "FAILED", as.numeric(difftime(Sys.time(), t0, units = "secs")),
              paste(grep("^FP[13] ", log, value = TRUE), collapse = " | ")))
  if (ok) done <- done + 1L else failed <- c(failed, sfx)
}
cat(sprintf("SC4  %s: %d run, %d already current, %d failed\n", TARGET, done, skipped, length(failed)))
if (length(failed)) stop("SC4! failed scenarios (logs in output/scenario-logs): ", paste(failed, collapse = ", "))

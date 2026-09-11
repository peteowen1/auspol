# PROMOTE AN ARM: make "we shipped X" mean one repeatable set of actions.
#
# WHY THIS EXISTS. On 2026-09-11 the xgb primary and the xgb preference flows
# were both shipped -- the flags were flipped, the forecast was wired, the
# review was written -- and NONE of the artifacts moved. Afterwards:
#
#   - output/pooled-backtest.csv still said 0.3316, a day old, describing the
#     pre-xgb model, while the shipped configuration scores 0.3001. It is built
#     newest-per-pair, and the 2x2 had left four arms of every pair on disk;
#   - output/pooled-sharedetail.csv had the same problem, so any question about
#     a seat's predicted primary answered for a mixture of configurations;
#   - the published Victorian forecast had not been re-run at all -- its
#     outputs were from 21-22 August;
#   - and the models it depends on (xgb-primary-v6-final.model plus 25
#     xgb-flows-v1-loo-*.model) existed only on one machine, because output/
#     is gitignored and this repo has no release bus.
#
# Every one of those is the same failure the repo keeps hitting from a
# different angle: the DECISION was recorded and the ARTIFACT was not, so the
# two drift and the stale one gets quoted. published_flags.R fixed it for
# configuration; this fixes it for outputs.
#
# WHAT IT DOES
#   1. refuses unless the environment matches PUBLISHED_FLAGS exactly;
#   2. resolves the named arm's own output files from its harness logs;
#   3. copies them to stable names under output/shipped/ so nothing downstream
#      has to guess which -a<fingerprint> was the shipped one;
#   4. regenerates the pooled tables FROM THAT ARM, not newest-per-pair;
#   5. writes output/shipped/MANIFEST.json -- git SHA, every flag value, every
#      model file with its size and SHA-256, and the pooled scores -- so a
#      published number can always be traced back to the bytes that produced it.
#
# It does NOT re-run any simulation and does NOT publish anywhere. Running the
# forecast and uploading a release are separate, deliberate acts.
#
# Usage: AUSPOL_PROMOTE_RUNDIR='output/_pfrun/p1f1_s*' Rscript scripts/promote_arm.R
#
# Emits PA* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

OUT <- "output"
SHIP <- file.path(OUT, "shipped")
EPS <- 1e-6
RUNDIR <- Sys.getenv("AUSPOL_PROMOTE_RUNDIR", "")
if (!nzchar(RUNDIR)) stop("set AUSPOL_PROMOTE_RUNDIR, e.g. output/_pfrun/p1f1_s*")

# ---- 1. the arm must BE the published configuration -------------------------
# Promoting an arm that is not what published_flags.R describes would put a
# non-shipped model's numbers behind the shipped name, which is precisely the
# 2026-09-06 incident. So check, and refuse rather than warn.
source("scripts/published_flags.R")
dirs <- Sys.glob(RUNDIR)
if (!length(dirs)) stop("no directory matches ", RUNDIR)
arm <- sub("_s[0-9]+$", "", basename(dirs[1]))
want_prim <- PUBLISHED_FLAGS[["AUSPOL_XGB_PRIMARY"]]
want_flow <- PUBLISHED_FLAGS[["AUSPOL_XGB_FLOWS"]]
got <- regmatches(arm, regexec("^p([01])f([01])$", arm))[[1]]
if (length(got) != 3L) stop("cannot read an arm name from ", arm)
if (!identical(got[2], want_prim) || !identical(got[3], want_flow)) {
  stop(sprintf(paste0("REFUSING to promote %s: published_flags.R says ",
                      "AUSPOL_XGB_PRIMARY=%s and AUSPOL_XGB_FLOWS=%s, this arm is %s/%s. ",
                      "Promote the arm that matches what ships, or change the flags first."),
               arm, want_prim, want_flow, got[2], got[3]))
}
cat(sprintf("PA1  arm %s matches published_flags.R (xgb primary %s, xgb flows %s), %d seed dir(s)\n",
            arm, want_prim, want_flow, length(dirs)))

# ---- 2. this arm's own files, from its logs --------------------------------
# Returns file -> seed. A "seed" is a SET of eight harness files, not one file
# (the federal harness writes all 7 of its pairs into one), so the seed has to
# come from the run directory that named the file, never from the filename.
arm_files <- function() {
  rbindlist(lapply(dirs, function(d) {
    sd_seed <- as.integer(sub(".*_s([0-9]+)$", "\\1", basename(d)))
    logs <- list.files(d, pattern = "[.]log$", full.names = TRUE)
    fs <- unlist(lapply(logs, function(lg) {
      ln <- readLines(lg, warn = FALSE)
      hit <- unique(regmatches(ln, regexpr("output/backtest-[^ ]+[.]csv", ln)))
      if (length(hit)) return(hit)
      reg <- sub("[0-9]*[.]log$", "", basename(lg))
      cand <- list.files(OUT, pattern = sprintf("^backtest-%s.*[.]csv$", reg), full.names = TRUE)
      cand <- cand[!grepl("sharedetail|allprobs|totals|-seatsd|-diag", cand)]
      m <- cand[abs(as.numeric(difftime(file.mtime(cand), file.mtime(lg), units = "secs"))) <= 2]
      if (length(m) == 1L) m else character(0)
    }))
    if (!length(fs)) NULL else data.table(file = fs, seed = sd_seed)
  }), fill = TRUE)
}
AF <- unique(arm_files())
AF <- AF[!grepl("sharedetail|allprobs|totals|-seatsd|-diag", file) & file.exists(file)]
if (!nrow(AF)) stop("no output files found for ", RUNDIR)
FS <- unique(AF$file)
# MATCH ON THE FULL TAG, fingerprint AND code version. Matching on the arm
# fingerprint `-a<hash>` alone is not unique: the same flags run against a
# different commit produce the same fingerprint with a different `-g<sha>`, so
# a stale run of the same configuration was being copied in alongside the real
# one -- and because the pooled table averages by (pair, seat, party), the two
# were silently AVERAGED. Caught 2026-09-11: Wentworth's IND primary read 22.1,
# the classical model's value, when the xgb primary this arm ran had predicted
# 14.4. Every primary column downstream, including the AEF comparison's, was
# reading a blend of two runs.
#
# The sharedetail sits next to its main file with the identical tail, so derive
# it by name rather than by pattern-matching a fragment.
# The prefix is the harness stem INCLUDING any year, because the year-suffixed
# harnesses name theirs backtest-nsw2019-sharedetail-... while the multi-pair
# ones use backtest-fed-sharedetail-... . Splitting on [a-z]+ alone produced
# "backtest-nsw-sharedetail2019-", which matches nothing, and silently dropped
# half the files.
SD <- unique(vapply(FS, function(f) {
  b <- basename(f)
  stem <- sub("^(backtest-[a-z]+[0-9]*)-.*$", "\\1", b)
  cand <- file.path(OUT, sub(sprintf("^%s-", stem),
                             sprintf("%s-sharedetail-", stem), b))
  if (file.exists(cand)) cand else NA_character_
}, character(1)))
SD <- SD[!is.na(SD)]
if (length(SD) < length(FS))
  cat(sprintf("PA2! %d of %d output files have no sharedetail sibling -- their primaries will be absent, not stale\n",
              length(FS) - length(SD), length(FS)))
cat(sprintf("PA2  %d win file(s), %d sharedetail file(s) matched by exact name\n",
            length(FS), length(SD)))

# ---- 3. stable copies ------------------------------------------------------
dir.create(SHIP, showWarnings = FALSE, recursive = TRUE)
unlink(list.files(SHIP, pattern = "^backtest-", full.names = TRUE))
for (f in c(FS, SD)) file.copy(f, file.path(SHIP, basename(f)), overwrite = TRUE)
cat(sprintf("PA3  copied %d file(s) to %s/\n", length(FS) + length(SD), SHIP))

# ---- 4. pooled tables, from THIS arm ---------------------------------------
rows <- rbindlist(lapply(FS, function(f) {
  d <- fread(f, showProgress = FALSE)
  pcol <- if ("prob" %in% names(d)) "prob" else if ("p" %in% names(d)) "p" else NA_character_
  if (is.na(pcol) || !all(c("pred","actual") %in% names(d))) {
    cat(sprintf("PA4! %s: missing prob/pred/actual -- dropped\n", basename(f))); return(NULL)
  }
  if (!"pair" %in% names(d)) {
    m <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
    if (!length(m)) { cat(sprintf("PA4! %s: no pair -- dropped\n", basename(f))); return(NULL) }
    d[, pair := m]
  }
  d[, .(seed = AF$seed[match(f, AF$file)][1], pair = as.character(pair),
        seat = as.character(seat),
        p = pmin(pmax(get(pcol), EPS), 1), hit = as.integer(pred == actual))]
}), fill = TRUE)

# Average the seeds per (pair, seat) before scoring: seeds are simulation
# noise, and a pooled table that carries three copies of every seat would
# understate its own standard errors.
# TWO DEFENSIBLE STATISTICS, AND THEY DIFFER -- so compute both and label them,
# rather than emitting one number that silently disagrees with the arm table.
#
#   pool_pf_arms.R scores each seed separately and averages the LOG LOSSES.
#     That is the right comparison between arms: it keeps each seed a complete
#     independent run.
#   Here we average the PROBABILITIES across seeds first, then take the log.
#     That is the better estimate of what the shipped model actually predicts,
#     because 3 seeds x 5,000 sims is a 15,000-sim estimate of the same
#     probability and averaging is straight variance reduction.
#
# By Jensen's inequality the second is always <= the first, so it will look
# like a small improvement that never happened. Quoting one against the other
# is a fake result; the manifest carries both under distinct names.
logloss_seedwise <- mean(rows[, .(ll = -mean(log(p))), by = seed]$ll)
rows <- rows[, .(p = mean(p), hit = mean(hit), seeds = .N), by = .(pair, seat)]
known <- vapply(all_election_pairs(), `[[`, character(1), "election")
missing <- setdiff(known, unique(rows$pair))
if (length(missing)) {
  # REFUSE, do not warn. This script overwrites output/pooled-backtest.csv and
  # pooled-sharedetail.csv -- the two files every other question in the repo
  # treats as ground truth -- and then prints "now describe the shipped arm",
  # a completeness claim it was not checking. A cat() here meant a partial arm
  # could become the canonical answer with nothing in the artifact to show it,
  # which is the same failure as the stale 0.3316 this script was written to
  # stop, arriving by a different route. Found by the review gate 2026-09-11.
  cat(sprintf("PA4!! %d known pair(s) absent from this arm: %s\n",
              length(missing), paste(missing, collapse = ", ")))
  if (!identical(Sys.getenv("AUSPOL_ALLOW_PARTIAL_PROMOTE", "0"), "1"))
    stop("refusing to promote a partial arm over the canonical tables. ",
         "Re-run the missing pair(s), or set AUSPOL_ALLOW_PARTIAL_PROMOTE=1 deliberately.")
}
# Same check as scripts/pool_pf_arms.R: an override that failed open leaves the
# arm inert while its output looks identical to a real run.
.inert <- unlist(lapply(list.files(dirs, pattern = "[.]log$", full.names = TRUE), function(lg) {
  grep("^(XG1!|XF9!|XS9!).*(ignored|unchanged|FAILED|missing)", readLines(lg, warn = FALSE), value = TRUE)
}))
if (length(.inert)) {
  cat(sprintf("PA4!! %d override(s) did not apply in this arm:\n", length(.inert)))
  for (m in unique(.inert)) cat(sprintf("PA4!!   %s\n", substr(m, 1, 150)))
  if (!identical(Sys.getenv("AUSPOL_ALLOW_INERT_ARM", "0"), "1"))
    stop("refusing to promote an arm whose own overrides did not run.")
}

per <- rows[, .(n = .N, accuracy = mean(hit), brier = mean((1 - p)^2),
                logloss = -mean(log(p))), by = pair]
setorder(per, pair)
pooled_ll <- -mean(log(rows$p))
cat(sprintf("PA5  %d pairs, %d seat-elections. Pooled seat log loss, LOWER IS BETTER:\n",
            nrow(per), nrow(rows)))
cat(sprintf("PA5    seed-averaged probabilities  %.4f  <- the shipped model's own best estimate\n", pooled_ll))
cat(sprintf("PA5    mean of per-seed log losses  %.4f  <- compare arms on THIS one (pool_pf_arms.R)\n", logloss_seedwise))
cat("PA5    They differ by Jensen's inequality, not by any model change. Never quote one against the other.\n")
fwrite(per, file.path(SHIP, "pooled-backtest.csv"))

sdrows <- unique(rbindlist(lapply(SD, function(f) {
  x <- fread(f, showProgress = FALSE)
  need <- c("pair","seat","party","pred_share","actual_share")
  if (!all(need %in% names(x))) return(NULL)
  x[, ..need]
}), fill = TRUE))
sdrows <- sdrows[, .(pred_share = mean(pred_share), actual_share = mean(actual_share)),
                 by = .(pair, seat, party)]
fwrite(sdrows, file.path(SHIP, "pooled-sharedetail.csv"))
cat(sprintf("PA5  %d (pair, seat, party) primary rows\n", nrow(sdrows)))

# OVERWRITE THE CANONICAL TABLES TOO. output/pooled-backtest.csv and
# pooled-sharedetail.csv are what every downstream question reads -- "what did
# we predict for seat X", the AEF comparison, the review tables -- and leaving
# them at whatever pool_backtests.R last happened to glob is the entire problem
# this script exists for. After promotion they describe the shipped arm.
#
# pool_backtests.R / pool_sharedetail.R will overwrite them again with
# newest-per-pair, which is correct for exploratory work and WRONG as a
# published answer. So re-run this script after any exploring, and read
# output/shipped/ when you need the promoted numbers specifically -- that copy
# is only ever written here.
fwrite(per, file.path(OUT, "pooled-backtest.csv"))
fwrite(sdrows[, .(pair, seat, party, pred_share, actual_share)],
       file.path(OUT, "pooled-sharedetail.csv"))
cat("PA5  canonical output/pooled-backtest.csv and output/pooled-sharedetail.csv now describe the shipped arm\n")

# ---- 5. manifest -----------------------------------------------------------
# The point of the checksums: a model file is the one artifact that cannot be
# regenerated identically (xgboost is not bit-reproducible across versions), so
# "which bytes produced this number" has to be recorded at promotion time or it
# is gone.
sha <- function(p) if (file.exists(p)) as.character(tools::md5sum(p)) else NA_character_
models <- c(list.files(OUT, pattern = "^xgb-primary-v6-final[.]model$", full.names = TRUE),
            list.files(OUT, pattern = "^xgb-primary-v6-oof-predictions[.]csv$", full.names = TRUE),
            list.files(OUT, pattern = "^xgb-flows-v1-loo-.*[.]model$", full.names = TRUE),
            list.files(OUT, pattern = "^xgb-flows-v1-final-cols[.]json$", full.names = TRUE),
            list.files(OUT, pattern = "^xgb-flows-v1-features[.]csv$", full.names = TRUE))
gitsha <- tryCatch(trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
                   error = function(e) NA_character_)
man <- list(
  promoted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  arm = arm, rundir = RUNDIR, seeds = length(dirs),
  git_sha = gitsha,
  pooled_seat_logloss_seed_averaged = round(pooled_ll, 6),
  pooled_seat_logloss_mean_of_seeds = round(logloss_seedwise, 6),
  pairs = nrow(per), seat_elections = nrow(rows),
  missing_pairs = missing,
  flags = as.list(PUBLISHED_FLAGS),
  per_pair = lapply(seq_len(nrow(per)), function(i)
    list(pair = per$pair[i], n = per$n[i], logloss = round(per$logloss[i], 6),
         brier = round(per$brier[i], 6), accuracy = round(per$accuracy[i], 6))),
  models = lapply(models, function(p)
    list(file = basename(p), bytes = as.numeric(file.size(p)), md5 = sha(p)))
)
writeLines(jsonlite::toJSON(man, auto_unbox = TRUE, pretty = TRUE),
           file.path(SHIP, "MANIFEST.json"))
cat(sprintf("PA6  wrote %s/MANIFEST.json: git %s, %d model file(s) checksummed\n",
            SHIP, substr(gitsha, 1, 8), length(models)))
cat("PA7  NOT done here, on purpose: re-running the published forecast, and publishing\n")
cat("PA7  models/results off this machine. Both are deliberate acts -- see docs/NEXT-STEPS.md.\n")

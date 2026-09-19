# PROMOTE THE LAST rebuild_forecasts.sh RUN: the production models it trained
# and the backtests it scored become the shipped set, with a manifest that
# names the git SHA and the pooled number. scripts/publish_shipped_release.R
# then uploads them to the `shipped-models` GitHub release, which the daily
# forecast workflow (.github/workflows/forecast.yaml) downloads.
#
# WHY (2026-09-19): the daily live forecast was found running on models
# promoted 2026-09-11 while the code on main was eight days and ~40 commits
# ahead -- every fix shipped through the AEF-7 ledger that week (as-at models,
# major-party slope tiers, how-to-vote cards, by-elections) was in the code
# and not in the models the job downloaded. scripts/promote_arm.R promotes
# the OLD `_pfrun/p1f1_s*` arm layout; the rebuild driver is the production
# recipe now, so this is its promotion step. Same MANIFEST.json shape.
#
# Refuses when: pooled-backtest.csv is older than the newest model file
# (the numbers would not describe these models), a known pair is missing, or
# a model file is absent. Emits PA* codes like promote_arm.R.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))
OUT <- "output"; SHIP <- file.path(OUT, "shipped")
source("scripts/published_flags.R")

# candidacies.csv ships with the models: build_candidacies.R needs raw
# commission files CI never fetches, so without this asset the live forecast
# on CI ran with EVERY candidate-identity mechanism off (found 2026-09-19 in
# the failed daily run's log: "candidate_returns() needs output/candidacies.csv").
models <- c("xgb-primary-v6-final.model", "xgb-primary-v6-final-cols.json",
            "xgb-flows-v1-final.model", "xgb-flows-v1-final-cols.json", "xgb-flows-v1-features.csv",
            "candidacies.csv")
mf <- file.path(OUT, models)
miss <- models[!file.exists(mf)]
if (length(miss)) stop("model file(s) missing -- run scripts/rebuild_forecasts.sh first: ", paste(miss, collapse = ", "))
pb_f <- file.path(OUT, "pooled-backtest.csv")
if (!file.exists(pb_f)) stop("output/pooled-backtest.csv missing -- run scripts/rebuild_forecasts.sh first")
newest_model <- max(file.mtime(mf))
if (file.mtime(pb_f) < newest_model)
  stop(sprintf("pooled-backtest.csv (%s) is OLDER than the newest model (%s): the scoreboard does not describe these models. Rerun the rebuild.",
               format(file.mtime(pb_f), "%Y-%m-%d %H:%M"), format(newest_model, "%Y-%m-%d %H:%M")))
per <- fread(pb_f, showProgress = FALSE)
known <- vapply(all_election_pairs(), `[[`, character(1), "election")
missing <- setdiff(known, per$pair)
if (length(missing) && !identical(Sys.getenv("AUSPOL_ALLOW_PARTIAL_PROMOTE", "0"), "1"))
  stop("refusing to promote: pair(s) absent from the scoreboard: ", paste(missing, collapse = ", "))
cat(sprintf("PA1  rebuild promotion: %d pairs scored, models newest %s\n", nrow(per), format(newest_model, "%Y-%m-%d %H:%M")))

# The scored win files and their sharedetail siblings, by the same rule the
# ledger uses (scripts/ledger_inputs.R): one harness run per pair.
source("scripts/ledger_inputs.R")
dir.create(SHIP, showWarnings = FALSE, recursive = TRUE)
unlink(list.files(SHIP, pattern = "^backtest-", full.names = TRUE))
copied <- 0L
for (pr in per$pair) for (kind in c("", "sharedetail")) {
  f <- tryCatch(run_file(pr, kind), error = function(e) NULL)
  if (!is.null(f) && file.exists(f)) { file.copy(f, file.path(SHIP, basename(f)), overwrite = TRUE); copied <- copied + 1L }
}
cat(sprintf("PA3  copied %d backtest file(s) to %s/\n", copied, SHIP))
file.copy(pb_f, file.path(SHIP, "pooled-backtest.csv"), overwrite = TRUE)
psd <- file.path(OUT, "pooled-sharedetail.csv")
if (file.exists(psd)) file.copy(psd, file.path(SHIP, "pooled-sharedetail.csv"), overwrite = TRUE)

ledger <- file.path(OUT, "aef7-ledger-summary.json")
ledger_summary <- if (file.exists(ledger)) jsonlite::fromJSON(ledger) else NULL
pooled_ll <- with(per, sum(logloss * n) / sum(n))
cat(sprintf("PA5  pooled seat log loss over %d seat-elections: %.4f (lower is better)%s\n", sum(per$n), pooled_ll,
            if (!is.null(ledger_summary)) sprintf(" | AEF-7 ledger: ours %.4f vs AEF %.4f", ledger_summary$seat_logloss$our, ledger_summary$seat_logloss$aef) else ""))
gitsha <- tryCatch(trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE)), error = function(e) NA_character_)
man <- list(
  promoted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  arm = "rebuild", rundir = "scripts/rebuild_forecasts.sh", seeds = 1L,
  git_sha = gitsha,
  pooled_seat_logloss_seed_averaged = round(pooled_ll, 6),
  pooled_seat_logloss_mean_of_seeds = round(mean(per$logloss), 6),
  pairs = nrow(per), seat_elections = sum(per$n), missing_pairs = missing,
  aef7 = ledger_summary,
  flags = as.list(PUBLISHED_FLAGS),
  per_pair = lapply(seq_len(nrow(per)), function(i) list(pair = per$pair[i], n = per$n[i], logloss = round(per$logloss[i], 6), file = per$file[i])),
  models = data.frame(file = models, md5 = vapply(mf, function(p) as.character(tools::md5sum(p)), character(1)),
                      mtime = format(file.mtime(mf), "%Y-%m-%dT%H:%M:%S"), stringsAsFactors = FALSE))
writeLines(jsonlite::toJSON(man, auto_unbox = TRUE, pretty = TRUE, null = "null"), file.path(SHIP, "MANIFEST.json"))
cat(sprintf("PA6  wrote %s (git %s)\n", file.path(SHIP, "MANIFEST.json"), substr(gitsha, 1, 8)))

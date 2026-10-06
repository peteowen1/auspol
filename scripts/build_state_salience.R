# Build state-election Google Trends salience from the cached raw weekly series.
# NO fetching: reads external/reference/trends/v6_AU_<STATE>_* only.
#
# Writes (default to output/, override with AUSPOL_STATE_SALIENCE_OUT):
#   state-salience-v1.csv        one row per state candidacy (all statistics,
#                                has_series flag; NA where no series)
#   state-salience-features.csv  one row per (pair, seat, party): the ss_*
#                                columns state_salience_features() reads
#   state-salience-coverage.csv  per-election coverage and checks
#
# Env: AUSPOL_TRENDS_DIR, AUSPOL_CANDIDACIES, AUSPOL_SALIENCE_V6 (for the
# anchor check), AUSPOL_STATE_SALIENCE_OUT.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

trends <- Sys.getenv("AUSPOL_TRENDS_DIR", file.path("external", "reference", "trends"))
cand_f <- Sys.getenv("AUSPOL_CANDIDACIES", file.path("output", "candidacies.csv"))
v6_f   <- Sys.getenv("AUSPOL_SALIENCE_V6", file.path("output", "salience-v6.csv"))
OUT    <- Sys.getenv("AUSPOL_STATE_SALIENCE_OUT", "output")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

cand <- fread(cand_f, showProgress = FALSE)
cat(sprintf("SSB1 candidacies %s: %d rows, %d elections\n", cand_f, nrow(cand), uniqueN(cand$election)))
stopifnot(dir.exists(trends))

res <- build_state_salience(trends, cand)
pop <- res$pop; dg <- res$diag

# ANCHOR CHECK: the rebuilt jump must reproduce output/salience-v6.csv's jump
# for the same keyword + election. If it does not, the scale was not rebuilt
# the way the fetcher built it and nothing downstream can be trusted.
if (file.exists(v6_f)) {
  v6 <- fread(v6_f, showProgress = FALSE)[, .(election, keyword, jump_v6 = jump)]
  v6 <- v6[, .(jump_v6 = jump_v6[1]), by = .(election, keyword)]
  cmp <- merge(pop[!is.na(jump), .(election, keyword, jump)], v6, by = c("election", "keyword"))
  cmp[, ok := abs(jump - jump_v6) < 1e-6 * pmax(1, abs(jump_v6))]
  cat(sprintf("SSB2 anchor check vs salience-v6.csv: %d keywords compared, %d reproduce exactly (%.1f%%)\n",
              nrow(cmp), sum(cmp$ok), 100 * mean(cmp$ok)))
  bad <- cmp[ok == FALSE]
  if (nrow(bad)) {
    cat("SSB2! non-reproducing keywords by election:\n"); print(bad[, .N, by = election])
    fwrite(bad, file.path(OUT, "state-salience-anchor-mismatch.csv"))
  }
  dg <- merge(dg, cmp[, .(compared = .N, reproduce = sum(ok)), by = election], by = "election", all.x = TRUE)
}

# Time-forward assertion: no point on/after polling day was used.
cat(sprintf("SSB3 future points dropped (should be 0 for these caches): %d\n", sum(dg$future_points_dropped)))

pop_out <- copy(pop)
fwrite(pop_out, file.path(OUT, "state-salience-v1.csv"))
cls <- state_salience_class_table(pop_out)
fwrite(cls, file.path(OUT, "state-salience-features.csv"))
fwrite(dg, file.path(OUT, "state-salience-coverage.csv"))
print(dg)
cat(sprintf("SSB4 candidacies %d | with series %d (%.1f%%) | non-NA ss_level class rows %d of %d\n",
            nrow(pop), sum(pop$has_series), 100 * mean(pop$has_series),
            sum(!is.na(cls$ss_level)), nrow(cls)))
# Coverage, not presence: a feature column that lands 100% NA must fail.
for (cc in c("ss_level", "ss_rise", "ss_peak", "ss_share8", "ss_jump_pctile", "ss_level_pctile")) {
  cov <- mean(!is.na(cls[[cc]]))
  cat(sprintf("SSB5 coverage %-16s %.1f%% of %d class rows\n", cc, 100 * cov, nrow(cls)))
  if (cov == 0) stop(cc, " is 100% NA -- the build is broken")
}

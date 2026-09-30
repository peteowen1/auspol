# THE FORECASTS TABLE. Pete, 2026-09-18: "save data and save forecasts and
# save models as we go so it's quick and we can quickly query data and it's
# the same as production ... forecasts are as at the start of each election
# and should be saved into a forecasts table where one row is a candidate in
# a given election".
#
# Two tables, both CSV (never RDS -- ~/.claude/CLAUDE.md):
#
#   output/forecasts.csv        one row per (election, seat, party class),
#       the PRIMARY-VOTE forecast as at the day before that election, with the
#       leading candidate of that class named. ~13.7k rows over 23 pairs; the
#       AEF-7 subset is `election %in% AEF7`. Columns:
#         election, election_date, region, seat, party, candidate,
#         n_candidates, base_pred (shipped-model baseline), xgb_pred (the
#         as-at XGBoost model's prediction -- what the seat simulation is
#         handed), actual_share, err_base, err_xgb, model (as-at model file),
#         cutoff_date, n_train_pairs, built_at.
#       The model is party-CLASS based (see classify_party()), so the row is a
#       class in a seat; `candidate` is the class's leading candidate by actual
#       primary vote, `n_candidates` says how many shared the class.
#
#   output/forecasts-seats.csv  one row per (election, seat, party class) with
#       the WIN PROBABILITY from the seat simulation, pooled newest-file-per-
#       pair from the harnesses' allprobs output, plus who actually won.
#
# Sources: output/xgb-primary-asat-predictions.csv + -manifest.csv
# (scripts/fit_xgb_primary_asat.R), output/candidacies.csv, and the newest
# backtest-*-allprobs*.csv per pair. Run after scripts/rebuild_forecasts.sh's
# harness stage so the seat table reflects the same vintage as the primary
# table. Emits FT* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
AEF7 <- c("fed2022","fed2025","nsw2023","qld2024","sa2026","vic2022","wa2025")

pf <- file.path(OUT, "xgb-primary-asat-predictions.csv")
mf <- file.path(OUT, "xgb-primary-asat-manifest.csv")
if (!file.exists(pf) || !file.exists(mf)) stop("FT0! run scripts/fit_xgb_primary_asat.R first")
P <- fread(pf, na.strings = c("NA", ""), showProgress = FALSE)
M <- fread(mf, na.strings = c("NA", ""), showProgress = FALSE)
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)

# Leading candidate per (election, seat, class): highest actual primary. A
# class with several candidates (two independents, two minor-right parties)
# is one modelled row, so the name is the leader's and the count says so.
lead <- C[is.finite(pcv), .SD[which.max(pcv)], by = .(election, seat, party)][
  , .(election, seat, party, candidate = name, n_candidates = NA_integer_)]
ncand <- C[, .(n_candidates = .N), by = .(election, seat, party)]
lead[, n_candidates := NULL]
lead <- merge(lead, ncand, by = c("election", "seat", "party"), all.x = TRUE)

F <- merge(P, lead, by.x = c("pair", "seat", "party"), by.y = c("election", "seat", "party"), all.x = TRUE)
F <- merge(F, M[, .(pair = target, model = basename(model_file), cutoff_date, n_train_pairs, built_at)],
           by = "pair", all.x = TRUE)
F[, election_date := election_dates(pair)[pair]]
F[, region := sub("[0-9]+$", "", pair)]
F[, err_base := abs(base_pred - actual_share)]
F[, err_xgb  := abs(xgb_pred - actual_share)]
# xgb_pred is the RAW model output; each seat's row does not sum to 100 (mean
# 97.8, range 78.7-113.2 on 2026-09-28), and both prediction paths rescale it
# to 100 before the simulation. An analysis of xgb_pred reads a ~1-point
# under-call of both majors that is not in the forecast. Use xgb_pred_seat.
F[, xgb_pred_seat := 100 * xgb_pred / sum(xgb_pred), by = .(pair, seat)]
setnames(F, "pair", "election")
setcolorder(F, c("election", "election_date", "region", "seat", "party", "candidate", "n_candidates",
                 "base_pred", "xgb_pred", "xgb_pred_seat", "actual_share", "err_base", "err_xgb",
                 "model", "cutoff_date", "n_train_pairs", "built_at"))
F <- F[, .(election, election_date, region, seat, party, candidate, n_candidates,
           base_pred, xgb_pred, xgb_pred_seat, actual_share, err_base, err_xgb, model, cutoff_date, n_train_pairs, built_at)]
setorder(F, election_date, seat, party)
fwrite(F, file.path(OUT, "forecasts.csv"), na = "NA")
cat(sprintf("FT1  wrote output/forecasts.csv: %d rows, %d elections, %d with a named candidate (%.1f%%)\n",
            nrow(F), uniqueN(F$election), sum(!is.na(F$candidate)), 100 * mean(!is.na(F$candidate))))
A7 <- F[election %in% AEF7]
wr <- function(e, a) sqrt(sum(a * e^2) / sum(a))   # weighted by actual share -- the headline (Pete, 2026-09-18)
cat(sprintf("FT1  AEF-7 subset: %d rows | primary RMSE WEIGHTED by actual share: base %.4f -> as-at xgb %.4f  (unweighted %.4f -> %.4f)\n",
            nrow(A7), wr(A7$err_base, A7$actual_share), wr(A7$err_xgb, A7$actual_share),
            sqrt(mean(A7$err_base^2)), sqrt(mean(A7$err_xgb^2))))

# ---- seat-level win probabilities: newest allprobs file per pair ------------
files <- list.files(OUT, pattern = "^backtest-.*allprobs.*[.]csv$", full.names = TRUE)
# The NSW, Queensland and SA harnesses write allprobs WITHOUT a pair column,
# and until 2026-09-30 every such file was dropped here silently: this table
# held federal, Victorian and WA seats only, so a change acting in NSW/QLD/SA
# scored as "no seat moved". The pair comes from the sibling sharedetail
# (same -a...-g... suffix), which always carries it (the SA file name has no
# election in it); a file with neither is dropped, loudly.
.pair_from_sibling <- function(f) {
  suf <- regmatches(basename(f), regexpr("-a[0-9a-f]+-g[0-9a-f]+x?[.]csv$", basename(f)))
  if (!length(suf)) return(NA_character_)
  sib <- list.files(dirname(f), pattern = paste0("sharedetail.*", gsub("[.]", "[.]", suf), "$"), full.names = TRUE)
  if (length(sib) != 1L) return(NA_character_)
  p <- unique(fread(sib, select = "pair", showProgress = FALSE)$pair)
  if (length(p) == 1L) as.character(p) else NA_character_
}
.dropped <- character(0)
rows <- rbindlist(lapply(files, function(f) {
  d <- tryCatch(fread(f, showProgress = FALSE), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL)
  if (!"pair" %in% names(d)) {
    p <- .pair_from_sibling(f)
    if (is.na(p)) { .dropped <<- c(.dropped, basename(f)); return(NULL) }
    d[, pair := p]
  }
  if (!all(c("seat", "party", "prob", "actual", "pair") %in% names(d))) { .dropped <<- c(.dropped, basename(f)); return(NULL) }
  d[, .(file = f, mtime = file.mtime(f), pair = as.character(pair), seat, party, win_prob = prob,
        actual_winner = actual)]
}), fill = TRUE)
if (length(.dropped)) cat(sprintf("FT1! %d allprobs file(s) dropped (no pair column and no single-pair sibling sharedetail, or missing columns): %s\n",
                                  length(.dropped), paste(head(.dropped, 10), collapse = ", ")))
# PAIRS DELIBERATELY NOT SCORED THIS RUN (AUSPOL_SKIP_PAIRS, comma-separated).
# A harness that skips a pair writes nothing for it, so "newest file per pair"
# would silently pick up a STALE run of a different vintage -- wa2021 under
# forecast mode (no fittable trend, 2026-09-19) surfaced the old oracle-mode,
# xgb-on file here and stopped the pool. Dropped loudly instead.
.skip <- trimws(strsplit(Sys.getenv("AUSPOL_SKIP_PAIRS", ""), ",")[[1]]); .skip <- .skip[nzchar(.skip)]
if (length(.skip)) {
  cat(sprintf("%s! AUSPOL_SKIP_PAIRS: dropping %s (%d row(s)) -- not scored this run\n", "FT0",
              paste(.skip, collapse = ", "), sum(rows$pair %in% .skip)))
  rows <- rows[!rows$pair %in% .skip]
}
# SIMS FLOOR (review gate 2026-09-20): stage 1 now runs at 2,000 sims and its
# files are tagged -n2000-; win/allprobs/totals ARE sim-dependent, so a
# stage-1 file must never be scored here even if it is the newest for its
# pair (stage 6 failed or was skipped). Files under the floor are dropped
# loudly; the default floor is the deciding run's 20,000.
.floor <- as.integer(Sys.getenv("AUSPOL_POOL_MIN_SIMS", "20000"))
# No backslashes: this line used sub(..., "\\1") written with ONE backslash,
# which R reads as the control character \001, so every tagged file parsed to
# NA and this floor never fired (found 2026-09-30).
.b <- basename(rows$file); .tok <- regexpr("-n[0-9]+-", .b)
.nsims <- rep(20000L, length(.b))
.nsims[.tok > 0] <- as.integer(gsub("[^0-9]", "", regmatches(.b, .tok)))
if (any(.nsims < .floor, na.rm = TRUE)) {
  cat(sprintf("%s! %d row(s) from %d file(s) under the %d-sim floor dropped: %s
", "FT0", sum(.nsims < .floor, na.rm = TRUE),
              length(unique(rows$file[.nsims < .floor])), .floor, paste(unique(basename(rows$file[.nsims < .floor])), collapse = ", ")))
  rows <- rows[!(.nsims < .floor)]
}
if (nrow(rows)) {
  pick <- rows[, .(mtime = max(mtime)), by = pair]
  rows <- merge(rows, pick, by = c("pair", "mtime"))
  keep <- rows[, .(file = file[1]), by = pair]
  rows <- merge(rows, keep, by = c("pair", "file"))
  S <- rows[, .(election = pair, seat, party, win_prob, actual_winner, is_winner = party == actual_winner,
                source_file = basename(file), source_mtime = format(mtime, "%Y-%m-%d %H:%M"))]
  S[, election_date := election_dates(election)[election]]
  setorder(S, election_date, seat, -win_prob)
  fwrite(S, file.path(OUT, "forecasts-seats.csv"), na = "NA")
  cat(sprintf("FT2  wrote output/forecasts-seats.csv: %d rows, %d elections\n", nrow(S), uniqueN(S$election)))
  cat("FT2  source file per pair (check these are the vintage you expect):\n")
  print(unique(S[, .(election, source_file, source_mtime)])[order(election)])
} else {
  cat("FT2! no allprobs files found -- forecasts-seats.csv not written\n")
}

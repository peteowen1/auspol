# XGBoost challenger for candidate-class primary vote share, compared against
# the shipped model's own prediction on the same (pair, seat, party) cells.
# Leave-one-PAIR-out throughout -- xgb.cv's folds are grouped by pair, so
# nrounds is chosen the same way the six harnesses are scored, not by a
# random split that would leak rows from the same election across folds.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
SD <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)  # pred_share = current model

PAIRS <- list(
  list(election = "fed2007", prev = "fed2004", region = "fed"),
  list(election = "fed2010", prev = "fed2007", region = "fed"),
  list(election = "fed2013", prev = "fed2010", region = "fed"),
  list(election = "fed2016", prev = "fed2013", region = "fed"),
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "fed2025", prev = "fed2022", region = "fed"),
  list(election = "nsw2019", prev = "nsw2015", region = "nsw"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "qld2020", prev = "qld2017", region = "qld"),
  list(election = "qld2024", prev = "qld2020", region = "qld"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa"),
  list(election = "vic2014", prev = "vic2010", region = "vic"),
  list(election = "vic2018", prev = "vic2014", region = "vic"),
  list(election = "vic2022", prev = "vic2018", region = "vic"),
  list(election = "wa2001",  prev = "wa1996",  region = "wa"),
  list(election = "wa2005",  prev = "wa2001",  region = "wa"),
  list(election = "wa2008",  prev = "wa2005",  region = "wa"),
  list(election = "wa2013",  prev = "wa2008",  region = "wa"),
  list(election = "wa2017",  prev = "wa2013",  region = "wa"),
  list(election = "wa2021",  prev = "wa2017",  region = "wa"),
  list(election = "wa2025",  prev = "wa2021",  region = "wa")
)

state_level <- function(el) {
  d <- C[C$election == el]
  if (!nrow(d) || !all(c("votes","tot") %in% names(d))) return(NULL)
  d <- d[is.finite(d$votes)]
  st <- unique(d[, list(seat, tot)]); den <- sum(st$tot, na.rm = TRUE)
  if (!is.finite(den) || den <= 0) return(NULL)
  d[, list(level = 100 * sum(votes, na.rm = TRUE) / den), by = party]
}

cat("=== building feature matrix across all 22 pairs ===\n")
rows <- list()
for (pr in PAIRS) {
  lp <- state_level(pr$prev); ln <- state_level(pr$election)
  if (is.null(lp) || is.null(ln)) { cat(sprintf("XG0! no state level for %s -> skip\n", pr$election)); next }
  prevc <- C[C$election == pr$prev][, list(x = sum(pcv, na.rm = TRUE), n_cand_prev = .N), by = list(seat, party)]
  nowc  <- C[C$election == pr$election][, list(n_cand_now = .N), by = list(seat, party)]
  ret <- tryCatch(candidate_returns(pr$prev, pr$election), error = function(e) NULL)
  sd_pair <- SD[pair == pr$election]
  if (!nrow(sd_pair)) { cat(sprintf("XG0! no sharedetail rows for %s -> skip\n", pr$election)); next }
  m <- merge(sd_pair, prevc, by = c("seat","party"), all.x = TRUE)
  m <- merge(m, nowc, by = c("seat","party"), all.x = TRUE)
  m <- merge(m, lp[, list(party, level_prev = level)], by = "party", all.x = TRUE)
  m <- merge(m, ln[, list(party, level_now  = level)], by = "party", all.x = TRUE)
  if (!is.null(ret)) m <- merge(m, ret, by = c("seat","party"), all.x = TRUE)
  m[, `:=`(pair = pr$election, prev_pair = pr$prev, region = pr$region)]
  rows[[pr$election]] <- m
}
ALL <- rbindlist(rows, fill = TRUE)

# missing-history semantics: no prior candidacy = 0 prior vote, not NA (a real
# absence, matching how dev_slope()/split_slope treat a class's first outing)
ALL[, x := ifelse(is.na(x), 0, x)]
ALL[, n_cand_prev := ifelse(is.na(n_cand_prev), 0L, n_cand_prev)]
ALL[, n_cand_now  := ifelse(is.na(n_cand_now), 1L, n_cand_now)]
ALL[, dev_prev := x - level_prev]
ALL[, same := ifelse(is.na(same), FALSE, same)]
ALL[, same_mp := ifelse(is.na(same_mp), FALSE, same_mp)]
ALL[, is_major := party %in% c("ALP","LNP","NAT")]

cat(sprintf("built %d rows across %d pairs, %d cols\n", nrow(ALL), length(unique(ALL$pair)), ncol(ALL)))
cat("coverage check -- NA counts per feature column:\n")
feat_cols_check <- c("pred_share","actual_share","x","level_prev","level_now","dev_prev","n_cand_prev","n_cand_now")
print(sapply(ALL[, ..feat_cols_check], function(v) sum(is.na(v))))

fwrite(ALL, file.path(OUT, "xgb-primary-features.csv"))
cat(sprintf("wrote %s\n", file.path(OUT, "xgb-primary-features.csv")))

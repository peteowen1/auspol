# xgb flows v1 -- see docs/plans/prereg-xgb-flows-v1-2026-09-10.md and
# docs/plans/xgb-flows-variable-inventory-2026-09-10.md for the design and
# the three worked examples (Ballarat/Kiama/MacKillop) this is built around.
#
# One row per (event = election,seat,round,from) x (destination = to),
# predicting that destination's SHARE of the excluded pot. Renormalised per
# event at inference, mirroring fit_xgb_primary_final.R's row-per-cell shape.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

EL <- election_data_path()
OUT <- "output"

# ---- 1. load every jurisdiction's raw transfer file, tag region -----------
files <- list(
  list(file = "aec-fed-transfers.csv",       region = "fed"),
  list(file = "nswec-nsw-transfers.csv",     region = "nsw"),
  list(file = "ecq-qld-transfers.csv",       region = "qld"),
  list(file = "ecsa-2026-sa-transfers.csv",  region = "sa"),
  list(file = "waec-wa-transfers.csv",       region = "wa")
)
vic_files <- list.files(EL, pattern = "^vec-[0-9]{4}-vic-transfers\\.csv$")
for (vf in vic_files) files[[length(files) + 1L]] <- list(file = vf, region = "vic")

TX <- rbindlist(lapply(files, function(f) {
  p <- file.path(EL, f$file)
  if (!file.exists(p)) { cat(sprintf("XF0! missing %s -- skipped\n", p)); return(NULL) }
  d <- fread(p, showProgress = FALSE)
  d[, region := f$region]
  d[, .(election, seat, round, from, to, votes, region)]
}), fill = TRUE)
TX <- TX[is.finite(votes) & votes > 0]
cat(sprintf("XF1  %d transfer rows loaded, %d elections, regions: %s\n",
            nrow(TX), uniqueN(TX$election), paste(unique(TX$region), collapse = ",")))

# ---- 2. build EVENTS: (election,seat,round,from) -> destinations, shares --
TX[, event_id := paste(election, seat, round, from, sep = "|")]
ev_surv <- TX[, .(surv = paste(sort(unique(to)), collapse = "+")), by = event_id]
TX <- merge(TX, ev_surv, by = "event_id")
ev_tot <- TX[, .(event_votes = sum(votes)), by = event_id]
TX <- merge(TX, ev_tot, by = "event_id")
TX[, y := votes / event_votes]
cat(sprintf("XF2  %d events, %d event-rows (event x destination)\n", uniqueN(TX$event_id), nrow(TX)))

# ---- 3. historical rate + confidence (n), LEAVE-ONE-ELECTION-OUT ----------
# Conditional (exact from|survivor-set) AND pooled (from only) rates, both
# fed in as FEATURES (not a hard fallback branch) -- xgb learns how much to
# trust each from its own n, the more principled version of the flat-15%-
# smoothing fix this session already tried and refused as a standalone rule.
# Built on the UNIQUE (from,surv,to[,election]) aggregate tables, never by
# re-summing an already row-duplicated column -- a real bug caught here
# first via the Ballarat dry-run (base_pred came out ~0.08 against a true
# ~0.74, because summing loo_cell_votes at the TX row level counted each
# historical cell once per (seat,round) that happened to share it within an
# election, multiplying the denominator).
cell_by_el <- TX[, .(el_votes = sum(votes), el_n = uniqueN(event_id)), by = .(from, surv, to, election)]
cell_all   <- TX[, .(all_votes = sum(votes)), by = .(from, surv, to)]
cell_n_all <- TX[, .(all_n = uniqueN(event_id)), by = .(from, surv, to)]

cell_loo <- merge(cell_by_el, cell_all, by = c("from","surv","to"), all.x = TRUE)
cell_loo <- merge(cell_loo, cell_n_all, by = c("from","surv","to"), all.x = TRUE)
cell_loo[, `:=`(loo_cell_votes = all_votes - el_votes, loo_cell_n = all_n - el_n)]
cell_loo_tot <- cell_loo[, .(loo_cell_tot = sum(loo_cell_votes), loo_cell_tot_n = sum(loo_cell_n)),
                          by = .(from, surv, election)]
cell_loo <- merge(cell_loo, cell_loo_tot, by = c("from","surv","election"), all.x = TRUE)
cell_loo[, `:=`(cond_rate = ifelse(loo_cell_tot > 0, loo_cell_votes / loo_cell_tot, NA_real_),
                cond_n = loo_cell_n)]
TX <- merge(TX, cell_loo[, .(from, surv, to, election, cond_rate, cond_n)],
            by = c("from","surv","to","election"), all.x = TRUE)

pool_by_el <- TX[, .(el_votes_p = sum(votes), el_n_p = uniqueN(event_id)), by = .(from, to, election)]
pool_all   <- TX[, .(all_votes_p = sum(votes)), by = .(from, to)]
pool_n_all <- TX[, .(all_n_p = uniqueN(event_id)), by = .(from, to)]

pool_loo <- merge(pool_by_el, pool_all, by = c("from","to"), all.x = TRUE)
pool_loo <- merge(pool_loo, pool_n_all, by = c("from","to"), all.x = TRUE)
pool_loo[, `:=`(loo_pool_votes = all_votes_p - el_votes_p, loo_pool_n = all_n_p - el_n_p)]
pool_loo_tot <- pool_loo[, .(loo_pool_tot = sum(loo_pool_votes)), by = .(from, election)]
pool_loo <- merge(pool_loo, pool_loo_tot, by = c("from","election"), all.x = TRUE)
pool_loo[, `:=`(pool_rate = ifelse(loo_pool_tot > 0, loo_pool_votes / loo_pool_tot, NA_real_),
                pool_n = loo_pool_n)]
TX <- merge(TX, pool_loo[, .(from, to, election, pool_rate, pool_n)],
            by = c("from","to","election"), all.x = TRUE)

TX[, cond_rate := ifelse(is.na(cond_rate), 0, cond_rate)]
TX[, cond_n := ifelse(is.na(cond_n), 0L, cond_n)]
TX[, pool_rate := ifelse(is.na(pool_rate), 0, pool_rate)]
TX[, pool_n := ifelse(is.na(pool_n), 0L, pool_n)]
cat("XF3  historical rate + n features built (leave-one-election-out)\n")

# SANITY CHECK, printed and asserted -- not just hoped for. Ballarat's
# GRN-exclusion cell should sum close to 1 across its two survivors and land
# near the known 78.7%/21.3% conditional rate before any smoothing is
# applied. A silent regression here would poison every downstream number.
.chk <- TX[election == "fed2007" & seat == "Ballarat" & from == "GRN"]
if (nrow(.chk)) {
  cat(sprintf("XF3chk Ballarat GRN cell: cond_rate sums to %.3f (want close to 1), n=%s\n",
              sum(.chk$cond_rate), paste(.chk$cond_n, collapse=","))); print(.chk[, .(to, y, cond_rate, cond_n)])
  if (abs(sum(.chk$cond_rate) - 1) > 0.05) stop("XF3chk FAILED: cond_rate does not sum to ~1 for a 2-survivor cell -- fix before trusting anything downstream")
}

# ---- 4. survivors' own current primary shares, from actual results -------
sd_all <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)
setnames(sd_all, "pair", "election")
TX <- merge(TX, sd_all[, .(election, seat, to_party = party, to_primary = actual_share)],
            by.x = c("election","seat","to"), by.y = c("election","seat","to_party"), all.x = TRUE)
TX <- merge(TX, sd_all[, .(election, seat, from_party = party, from_primary = actual_share)],
            by.x = c("election","seat","from"), by.y = c("election","seat","from_party"), all.x = TRUE)
TX[, `:=`(to_primary = ifelse(is.na(to_primary), 0, to_primary),
          from_primary = ifelse(is.na(from_primary), 0, from_primary))]
cat(sprintf("XF4  primary-share join: %d of %d rows matched for destination party\n",
            sum(!is.na(TX$to_primary) & TX$to_primary > 0), nrow(TX)))

# ---- 5. identity/personal-vote signal for the DESTINATION party ----------
# Simplification, noted in the pre-registration: candidate_returns() is
# per-party (same person, same party), so it cannot directly represent
# "Ward switched from LNP to IND" -- it CAN represent "this destination's own
# candidate is a returning/sitting member here", which is a real if partial
# proxy for personal-vote strength driving an unusual flow toward them.
PAIRS <- list(
  list(election="fed2007",prev="fed2004"), list(election="fed2010",prev="fed2007"),
  list(election="fed2013",prev="fed2010"), list(election="fed2016",prev="fed2013"),
  list(election="fed2019",prev="fed2016"), list(election="fed2022",prev="fed2019"),
  list(election="fed2025",prev="fed2022"), list(election="nsw2019",prev="nsw2015"),
  list(election="nsw2023",prev="nsw2019"), list(election="qld2020",prev="qld2017"),
  list(election="qld2024",prev="qld2020"), list(election="sa2026", prev="sa2022"),
  list(election="vic2014",prev="vic2010"), list(election="vic2018",prev="vic2014"),
  list(election="vic2022",prev="vic2018"), list(election="wa2005", prev="wa2001"),
  list(election="wa2008", prev="wa2005"),  list(election="wa2013",prev="wa2008"),
  list(election="wa2017", prev="wa2013"),  list(election="wa2021",prev="wa2017"),
  list(election="wa2025", prev="wa2021"))

ret_rows <- rbindlist(lapply(PAIRS, function(p) {
  r <- tryCatch(candidate_returns(p$prev, p$election), error = function(e) NULL)
  if (is.null(r) || !nrow(r)) return(NULL)
  as.data.table(r)[, election := p$election]
}), fill = TRUE)
if (nrow(ret_rows)) {
  ret_rows <- ret_rows[, .(election, seat, party, same, same_mp)]
  TX <- merge(TX, ret_rows, by.x = c("election","seat","to"), by.y = c("election","seat","party"), all.x = TRUE)
  TX[, `:=`(dest_same = ifelse(is.na(same), 0L, as.integer(same)),
            dest_same_mp = ifelse(is.na(same_mp), 0L, as.integer(same_mp)))]
  TX[, c("same","same_mp") := NULL]
} else {
  TX[, `:=`(dest_same = 0L, dest_same_mp = 0L)]
}
cat(sprintf("XF5  identity features: %d rows with a matched returning destination candidate\n",
            sum(TX$dest_same == 1)))

# ---- 6. survivor-set composition (multi-hot over the 7-class system) -----
CLASSES <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
surv_list <- strsplit(TX$surv, "+", fixed = TRUE)
for (cl in CLASSES) TX[[paste0("surv_", cl)]] <- vapply(surv_list, function(s) as.integer(cl %in% s), integer(1))
TX[, n_survivors := lengths(surv_list)]
for (cl in CLASSES) TX[[paste0("from_", cl)]] <- as.integer(TX$from == cl)
for (cl in CLASSES) TX[[paste0("to_",   cl)]] <- as.integer(TX$to   == cl)
region_levels <- sort(unique(TX$region))
for (r in region_levels) TX[[paste0("region_", r)]] <- as.integer(TX$region == r)

feat_cols <- c("cond_rate","cond_n","pool_rate","pool_n","to_primary","from_primary",
               "dest_same","dest_same_mp","n_survivors",
               paste0("surv_", CLASSES), paste0("from_", CLASSES), paste0("to_", CLASSES),
               paste0("region_", region_levels))
cat(sprintf("XF6  %d rows, %d features\n", nrow(TX), length(feat_cols)))
fwrite(TX, file.path(OUT, "xgb-flows-v1-features.csv"))

# ============================== fit + CV =====================================
X <- as.matrix(TX[, ..feat_cols])
y <- TX$y
pairs_ <- sort(unique(TX$election))
fold_id <- match(TX$election, pairs_)
dtrain <- xgb.DMatrix(data = X, label = y, missing = NA)

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
                subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)

cat("\nrunning xgb.cv, grouped folds by election (leave-one-election-out)...\n")
set.seed(42)
cv <- xgb.cv(params = params, data = dtrain, nrounds = 1000, folds = split(seq_len(nrow(X)), fold_id),
             early_stopping_rounds = 30, prediction = TRUE, verbose = 0)
best_n <- cv$early_stop$best_iteration
oof_pred <- pmax(0, cv$cv_predict$pred[, 1])
cat(sprintf("best nrounds: %d\n", best_n))

# baseline: what the CURRENT shipped mechanism (conditional -> pooled -> 15%
# uniform smoothing) would predict for this exact row's share, so the
# comparison is apples to apples at the ROW level before any seat-sim run.
n_surv <- TX$n_survivors
base_rate <- ifelse(TX$cond_n >= 3L, TX$cond_rate, ifelse(TX$pool_n > 0, TX$pool_rate, 1 / n_surv))
base_pred <- 0.85 * base_rate + 0.15 * (1 / n_surv)
base_rmse <- sqrt(mean((base_pred - y)^2))
xgb_rmse  <- sqrt(mean((oof_pred - y)^2))
cat(sprintf("\nROW-LEVEL RMSE (share of pot, 0-1 scale): shipped-equivalent %.4f | xgb %.4f | improvement %.1f%%\n",
            base_rmse, xgb_rmse, 100 * (base_rmse - xgb_rmse) / base_rmse))

final <- xgb.train(params = params, data = dtrain, nrounds = max(best_n, 50L), verbose = 0)
xgb.save(final, file.path(OUT, "xgb-flows-v1-final.model"))
writeLines(jsonlite::toJSON(feat_cols), file.path(OUT, "xgb-flows-v1-final-cols.json"))
imp <- xgb.importance(feature_names = feat_cols, model = final)
cat("\ntop 15 features by gain:\n"); print(head(imp, 15))

TX[, xgb_pred := oof_pred]
fwrite(TX[, .(election, seat, round, from, to, surv, y, base_pred, xgb_pred, cond_n, pool_n)],
       file.path(OUT, "xgb-flows-v1-oof-predictions.csv"))

cat("\n--- Named dry-run checks ---\n")
bal <- TX[election == "fed2007" & seat == "Ballarat" & from == "GRN"]
if (nrow(bal)) print(bal[, .(to, y, base_pred, xgb_pred, cond_n)])
kia <- TX[election == "nsw2023" & seat == "Kiama"]
if (nrow(kia)) print(kia[, .(from, to, surv, y, base_pred, xgb_pred, cond_n, dest_same_mp)])
mck <- TX[election == "sa2026" & seat == "MacKillop"]
if (nrow(mck)) print(mck[, .(from, to, surv, y, base_pred, xgb_pred, cond_n)])

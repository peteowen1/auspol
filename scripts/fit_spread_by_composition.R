# Seat-composition spread table for AUSPOL_COMPOSITION_SD (default "0" = off;
# docs/plans/prereg-composition-spread-2026-10-17.md). 2026-10-17: seats with a strong predicted independent are
# called far too confidently in every jurisdiction (217 seats at IND 15+: seat log loss 0.763 vs 0.301), and the
# share error relative to the simulator's per-cell sd rises with the predicted IND share within every seat-size
# band, on the major cells too. Greens-led seats do not show it: it is the personal vote, not "a strong minor".
#
# For each target election, fitted TIME-FORWARD on every earlier election's published cells (pairs whose polling
# day is before the target's): a Gamma GLM (log link) of the squared share error, offset log(sdm^2) with
# sdm = 1.10 + 8.67 sqrt(p(1-p)), on the seat's centred log formal votes (a size control, so this does not
# re-fit AUSPOL_SIZE_SD) and each non-major class's predicted share in the seat per 10 points. Each class
# coefficient b is shrunk by w = max(0, 1 - se^2 / b^2), se clustered on election. R/size_sd.R widens a seat by
#   factor = max(1, exp(sum_c w_c b_c s_c / 2))     (s_c = predicted share of class c / 10)
# Writes output/spread-by-composition.csv: one row per target x class (target, class, b, se, w, n_cells, n_pairs).
#   Rscript scripts/fit_spread_by_composition.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
OUT <- "output"; source("scripts/ledger_inputs.R")
pb <- fread(file.path(OUT, "pooled-backtest.csv"))
S <- rbindlist(lapply(pb$pair, function(pr) { d <- tryCatch(run_table(pr, "sharedetail"), error = function(e) NULL)
  if (is.null(d) || !nrow(d)) return(NULL); if (!"pair" %in% names(d)) d[, pair := pr]; d[pair == pr] }), fill = TRUE)
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
fm <- C[, list(formal = sum(as.numeric(votes), na.rm = TRUE)), by = list(pair = election, seat)]
S <- merge(S, fm, by = c("pair", "seat"))
CLS <- composition_sd_classes()
W <- dcast(S, pair + seat ~ party, value.var = "pred_share", fun.aggregate = sum, fill = 0)
for (k in CLS) if (!k %in% names(W)) W[, (k) := 0]
sc <- paste0("s_", CLS)
setnames(W, CLS, sc)
S <- merge(S, W[, c("pair", "seat", sc), with = FALSE], by = c("pair", "seat"))
S <- S[is.finite(pred_share) & is.finite(actual_share) & pred_share >= 2 & formal > 0]
S[, p := pred_share / 100][, e2 := (actual_share - pred_share)^2][, sdm2 := (1.10 + 8.67 * sqrt(p * (1 - p)))^2]
S[, lf := log(formal)]
for (k in sc) S[, (k) := get(k) / 10]
S <- S[S$e2 > 0]
ed <- election_dates()
S[, day := as.Date(unname(ed[pair]))]
cat(sprintf("CMP0  %d cells, %d elections, %d seats (published path, pooled-backtest.csv runs)\n",
            nrow(S), uniqueN(S$pair), uniqueN(S[, paste(pair, seat)])))
if (anyNA(S$day)) stop("CMP0! no election date for: ", paste(unique(S$pair[is.na(S$day)]), collapse = ", "))

fit_one <- function(tr) {
  tr <- copy(tr)
  tr[, lfc := lf - stats::median(lf)]
  live <- sc[vapply(sc, function(k) stats::var(tr[[k]]) > 0, TRUE)]
  fo <- stats::as.formula(paste("e2 ~ lfc", if (length(live)) paste("+", paste(live, collapse = " + ")), "+ offset(log(sdm2))"))
  f <- stats::glm(fo, family = stats::Gamma(link = "log"), data = tr, control = stats::glm.control(maxit = 100))
  X <- stats::model.matrix(f); r <- stats::residuals(f, type = "working") * f$weights
  bread <- solve(crossprod(X * sqrt(f$weights)))
  meat <- Reduce(`+`, lapply(split(seq_len(nrow(X)), tr$pair), function(i) tcrossprod(colSums(X[i, , drop = FALSE] * r[i]))))
  G <- uniqueN(tr$pair)
  V <- bread %*% meat %*% bread * G / (G - 1)
  # coef and se kept under names that are NOT columns of `out`: inside out[...] a bare `b` binds to the
  # column (the data.table NSE trap; it zeroed every coefficient on this script's first run, 2026-10-17)
  cf_all <- stats::coef(f); se_all <- sqrt(diag(V))
  hit <- match(paste0("s_", CLS), names(cf_all))
  bv <- ifelse(is.na(hit), 0, unname(cf_all[hit])); sv <- ifelse(is.na(hit), NA_real_, unname(se_all[hit]))
  bv[!is.finite(bv)] <- 0
  wv <- ifelse(is.finite(bv) & is.finite(sv) & bv != 0, pmax(0, 1 - sv^2 / bv^2), 0)
  data.table(class = CLS, b = bv, se = sv, w = wv)
}

targets <- unique(c(pb$pair, "vic2026", "nsw2027", "fed2028"))
res <- rbindlist(lapply(targets, function(tg) {
  tday <- as.Date(unname(ed[tg])); if (is.na(tday)) return(NULL)
  tr <- S[S$day < tday]
  if (uniqueN(tr$pair) < 3L || nrow(tr) < 500L)
    return(data.table(target = tg, class = CLS, b = 0, se = NA_real_, w = 0, n_cells = nrow(tr), n_pairs = uniqueN(tr$pair)))
  o <- fit_one(tr)
  o[, `:=`(target = tg, n_cells = nrow(tr), n_pairs = uniqueN(tr$pair))]
  setcolorder(o, c("target", "class", "b", "se", "w", "n_cells", "n_pairs"))
  o
}))
# The sd factor per 10 points of each class, after shrinkage (1 = no widening).
show <- dcast(res[, list(target, n_pairs, class, f = round(exp(pmax(0, w * b) / 2), 3))], target + n_pairs ~ class, value.var = "f")
print(show[order(n_pairs)], nrows = 60)
fwrite(res, file.path(OUT, "spread-by-composition.csv"))
cat(sprintf("CMP2  wrote output/spread-by-composition.csv (%d targets x %d classes)\n", uniqueN(res$target), length(CLS)))

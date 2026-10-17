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

# ---- Arm C2 (AUSPOL_COMPOSITION_SD=own; prereg amendment 1): each non-major class's OWN cells only ----------
# Gamma GLM of e2 on class-c cells: offset log sdm^2, centred log size, and the class's own share per 10 points.
# Intercept a and slope b each shrunk by its own w. Cell factor max(1, exp((w_a a + w_b b min(s, s_max)/10) / 2)),
# s_max the class's 99th-percentile predicted share in the training cells.
S[, own := pred_share / 10]
.own_failed <- character(0)
fit_own <- function(tr, k) {
  x <- copy(tr[tr$party == k])
  if (nrow(x) < 50L || uniqueN(x$pair) < 3L) return(data.table(class = k, a = 0, se_a = NA_real_, w_a = 0, b = 0, se_b = NA_real_, w_b = 0, n_cls = nrow(x), s_max = NA_real_))
  x[, lfc := lf - stats::median(tr$lf)]
  # started at the class's overall error ratio with both slopes 0: from the default start IRLS overflows on
  # some targets (qld2012 IND, fed2019 IND and OTH_RIGHT, 2026-10-17). A fit that still fails is NOT dropped
  # silently: it widens nothing and is counted in CMP3.
  f <- tryCatch(stats::glm(e2 ~ lfc + own + offset(log(sdm2)), family = stats::Gamma(link = "log"), data = x,
                           start = c(log(mean(x$e2 / x$sdm2)), 0, 0), control = stats::glm.control(maxit = 100)),
                error = function(e) NULL)
  if (is.null(f) || !isTRUE(f$converged)) {
    .own_failed <<- c(.own_failed, k)
    return(data.table(class = k, a = 0, se_a = NA_real_, w_a = 0, b = 0, se_b = NA_real_, w_b = 0, n_cls = nrow(x), s_max = NA_real_))
  }
  X <- stats::model.matrix(f); r <- stats::residuals(f, type = "working") * f$weights
  bread <- solve(crossprod(X * sqrt(f$weights)))
  meat <- Reduce(`+`, lapply(split(seq_len(nrow(X)), x$pair), function(i) tcrossprod(colSums(X[i, , drop = FALSE] * r[i]))))
  G <- uniqueN(x$pair)
  V <- bread %*% meat %*% bread * G / (G - 1)
  cf_all <- stats::coef(f); se_all <- sqrt(diag(V))
  sh <- function(v, s) if (is.finite(v) && is.finite(s) && v != 0) max(0, 1 - s^2 / v^2) else 0
  av <- unname(cf_all["(Intercept)"]); bv <- unname(cf_all["own"]); sa <- unname(se_all["(Intercept)"]); sb <- unname(se_all["own"])
  data.table(class = k, a = ifelse(is.finite(av), av, 0), se_a = sa, w_a = sh(av, sa),
             b = ifelse(is.finite(bv), bv, 0), se_b = sb, w_b = sh(bv, sb), n_cls = nrow(x),
             s_max = unname(stats::quantile(x$pred_share, 0.99)))
}
own <- rbindlist(lapply(targets, function(tg) {
  tday <- as.Date(unname(ed[tg])); if (is.na(tday)) return(NULL)
  tr <- S[S$day < tday]
  o <- if (uniqueN(tr$pair) < 3L || nrow(tr) < 500L)
    data.table(class = CLS, a = 0, se_a = NA_real_, w_a = 0, b = 0, se_b = NA_real_, w_b = 0, n_cls = 0L, s_max = NA_real_)
  else rbindlist(lapply(CLS, function(k) fit_own(tr, k)))
  o[, `:=`(target = tg, n_cells = nrow(tr), n_pairs = uniqueN(tr$pair))]
  setcolorder(o, c("target", "class"))
  o
}))
# The own-cell sd factor at 10 and 30 points of the class's own share, after shrinkage.
# the share is capped at the class's 99th-percentile training share: an exponential slope fitted on small
# shares must not be extrapolated (OTH ran to x94 at 30 points uncapped, 2026-10-17)
own[, f10 := pmax(1, exp((w_a * a + w_b * b * pmin(1, s_max / 10)) / 2))][, f30 := pmax(1, exp((w_a * a + w_b * b * pmin(3, s_max / 10)) / 2))]
print(dcast(own[, list(target, n_pairs, class, v = sprintf("%.2f/%.2f", f10, f30))], target + n_pairs ~ class, value.var = "v")[order(n_pairs)], nrows = 60)
fwrite(own[, !c("f10", "f30")], file.path(OUT, "spread-by-class-own.csv"))
cat(sprintf("CMP3  wrote output/spread-by-class-own.csv (%d targets x %d classes; cells shown as factor at 10/30 points); %d target-class fit(s) did not converge and widen nothing%s\n",
            uniqueN(own$target), length(CLS), length(.own_failed),
            if (length(.own_failed)) paste0(": ", paste(names(table(.own_failed)), table(.own_failed), sep = " x", collapse = ", ")) else ""))

# Retest: drop `fed_aligned` from the two-party fundamentals, time-forward.
# docs/plans/prereg-fundamentals-drop-fed-aligned-tf-2026-09-29.md
# Mirrors fundamentals_tf() / projection_mix_tf() with the feature list as the
# only difference between arms. Statewide only; writes
# output/retest-fed-aligned-tf.csv (one row per target and arm).
suppressMessages({ devtools::load_all(quiet = TRUE); library(data.table) })

fd <- build_fundamentals_data()
tpp <- fd[fd$party == "@TPP", ]
tpp_lab <- paste0(tpp$region, tpp$year)
cat(sprintf("RF0 %d two-party elections in the fundamentals data\n", nrow(tpp)))

ARMS <- list(base = FUNDAMENTALS_FEATURES,
             drop = setdiff(FUNDAMENTALS_FEATURES, "fed_aligned"))
stopifnot(length(ARMS$drop) == length(ARMS$base) - 1L)

fund_tf <- function(lab, feats) {
  i <- which(tpp_lab == lab)
  if (length(i) != 1L) return(list(fund = NA_real_, coef = NA_real_))
  tr <- fd[which(elections_before(paste0(fd$region, fd$year), lab)), ]
  if (sum(tr$party == "@TPP") < 10L) return(list(fund = NA_real_, coef = NA_real_))
  m <- fit_fundamentals(tr, "@TPP", features = feats)
  k <- match("fed_aligned", m$features)
  list(fund = predict_fundamentals(m, tpp[i, ]),
       coef = if (is.na(k)) NA_real_ else m$beta[k] / m$scale[k])
}

# Every election's time-forward fundamentals, per arm.
ft <- rbindlist(lapply(names(ARMS), function(a) rbindlist(lapply(tpp_lab, function(l) {
  r <- fund_tf(l, ARMS[[a]])
  data.table(lab = l, arm = a, fund = r$fund, coef = r$coef)
}))))
ft <- merge(ft, data.table(lab = tpp_lab, actual = tpp$actual), by = "lab")
cat(sprintf("RFA1 time-forward fundamentals: %d of %d elections fitted per arm\n",
            sum(is.finite(ft$fund[ft$arm == "base"])), length(tpp_lab)))

pd <- fread(out_path("projection-data.csv"), showProgress = FALSE)
pd[, lab := paste0(region, year)]

# Projection at horizon h for one target and arm: mix refitted on earlier
# elections carrying their own time-forward fundamentals (this arm's).
proj <- function(lab_t, a, h) {
  row <- pd[which(pd$lab == lab_t & pd$horizon == h), ]
  f_t <- ft$fund[ft$lab == lab_t & ft$arm == a]
  if (nrow(row) != 1L || !length(f_t) || !is.finite(f_t)) return(NA_real_)
  p <- pd[which(elections_before(pd$lab, lab_t)), ]
  fa <- ft[ft$arm == a, list(lab, fund_a = fund)]
  p <- merge(p, fa, by = "lab")
  p$fund_tpp <- p$fund_a
  mix <- fit_projection_mix(p)
  if (!nrow(mix) || !h %in% mix$horizon) return(NA_real_)
  project_result(row$trend_tpp, f_t, mix, horizon = h)$mean - row$actual_tpp
}

targets <- unique(pd$lab)
res <- rbindlist(lapply(c(1L, 730L), function(h) rbindlist(lapply(targets, function(l)
  data.table(lab = l, horizon = h,
             err_base = proj(l, "base", h), err_drop = proj(l, "drop", h))))))
fwrite(res, out_path("retest-fed-aligned-tf.csv"))

paired <- function(x, y, label) {
  ok <- is.finite(x) & is.finite(y)
  d <- abs(y[ok]) - abs(x[ok])
  cat(sprintf("%-44s n %2d  base %.3f  drop %.3f  diff %+.3f  SE %.3f\n", label, sum(ok),
              mean(abs(x[ok])), mean(abs(y[ok])), mean(d), sd(d) / sqrt(length(d))))
  invisible(d)
}
w <- dcast(ft, lab + actual ~ arm, value.var = "fund")
cat("\nRFA2 absolute error, lower is better; diff = drop - base (negative favours dropping)\n")
paired(w$base - w$actual, w$drop - w$actual, "fundamentals, time-forward")
r1 <- res[horizon == 1L]
paired(r1$err_base, r1$err_drop, "PRIMARY projection @1 day")
paired(r1$err_base[r1$lab != "nsw2023"], r1$err_drop[r1$lab != "nsw2023"], "projection @1 day without nsw2023")
r7 <- res[horizon == 730L]
paired(r7$err_base, r7$err_drop, "projection @730 days")
cat("\nRFA3 nsw2023:\n"); print(r1[lab == "nsw2023"]); print(ft[lab == "nsw2023"])
cat("\nRFA4 fed_aligned coefficient (points of Labor 2PP per unit) by cutoff, state elections:\n")
print(ft[arm == "base" & !grepl("^fed", lab) & is.finite(coef), list(lab, coef = round(coef, 2))])

# Ad-hoc reporting only (not part of any pre-registration): refits the
# surge-v2 hazard on the widened 9-pair governed population (already on disk
# at output/salience-surge-v2-population.csv, built by fit_salience_surge_v2.R)
# and prints p_hat for every governed WINNER next to the highest-jump governed
# LOSERS, so the model's discrimination is visible by name rather than only as
# a log-loss summary. Answers Pete's "show examples" request directly.
#
# Emits SVE* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

POP <- fread("output/salience-surge-v2-population.csv", showProgress = FALSE)

build_X <- function(d, party_levels) {
  pm <- model.matrix(~ party - 1, data = data.frame(party = factor(d$party, levels = party_levels)))
  colnames(pm) <- paste0("party_", party_levels)
  cbind(jump_pctile = d$jump_pctile, prev_party = d$prev_party, prev_ind = d$prev_ind, pm)
}
fit_ridge_std <- function(train_d, party_levels, lambda) {
  X <- build_X(train_d, party_levels)
  center <- colMeans(X); scale <- apply(X, 2, sd); scale[scale == 0] <- 1
  Xs <- sweep(sweep(X, 2, center, "-"), 2, scale, "/")
  list(beta = ridge_logistic(Xs, train_d$elected, lambda), center = center, scale = scale)
}
log_loss <- function(y, p_hat, eps = 1e-6) -mean(y*log(pmax(p_hat,eps)) + (1-y)*log(pmax(1-p_hat,eps)))

LAMBDA_GRID <- c(0.5, 1, 2, 5, 10, 20, 50)
party_levels <- sort(unique(POP$party))
pick_lambda <- function(train_pairs) {
  scores <- sapply(LAMBDA_GRID, function(lam) {
    inner <- sapply(train_pairs, function(held_in) {
      tr <- POP[pair %in% setdiff(train_pairs, held_in)]
      te <- POP[pair == held_in]
      if (!nrow(tr) || !nrow(te)) return(NA_real_)
      fit <- fit_ridge_std(tr, party_levels, lam)
      p_hat <- predict_ridge(fit$beta, build_X(te, party_levels), fit$center, fit$scale)
      log_loss(te$elected, p_hat)
    })
    mean(inner, na.rm = TRUE)
  })
  LAMBDA_GRID[which.min(scores)]
}
full_lambda <- pick_lambda(unique(POP$pair))
full_fit <- fit_ridge_std(POP, party_levels, full_lambda)
POP$p_hat <- predict_ridge(full_fit$beta, build_X(POP, party_levels), full_fit$center, full_fit$scale)
cat(sprintf("SVE1 full-population lambda: %.1f | n=%d | winners=%d\n", full_lambda, nrow(POP), sum(POP$elected)))

cat("\nSVE2  every governed WINNER, all 9 pairs, ranked by p_hat:\n")
W <- POP[elected == TRUE][order(-p_hat)]
print(W[, .(pair, seat, keyword, party, jump_pctile = round(jump_pctile,2),
            prev_party = round(prev_party,1), pcv = round(pcv,1), p_hat = round(p_hat,3))])

cat("\nSVE3  top 15 governed LOSERS by jump_pctile (loud, but did not win):\n")
L <- POP[elected == FALSE][order(-jump_pctile)][1:15]
print(L[, .(pair, seat, keyword, party, jump_pctile = round(jump_pctile,2),
            prev_party = round(prev_party,1), pcv = round(pcv,1), p_hat = round(p_hat,3))])

cat("\nSVE4  top 15 governed LOSERS by p_hat (the model's own highest false-alarm risk):\n")
L2 <- POP[elected == FALSE][order(-p_hat)][1:15]
print(L2[, .(pair, seat, keyword, party, jump_pctile = round(jump_pctile,2),
             prev_party = round(prev_party,1), pcv = round(pcv,1), p_hat = round(p_hat,3))])

cat(sprintf("\nSVE5  discrimination: mean p_hat winners %.3f vs mean p_hat losers %.3f | AUC %.3f\n",
            mean(W$p_hat), mean(POP[elected==FALSE]$p_hat),
            { y <- POP$elected; s <- POP$p_hat
              r <- rank(s); n1 <- sum(y==1); n0 <- sum(y==0)
              (sum(r[y==1]) - n1*(n1+1)/2) / (n1*n0) }))

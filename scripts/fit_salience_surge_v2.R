# Validation run for the multi-feature surge hazard: LOO-by-election plus a
# dry-run on known high-jump governed LOSERS, against
# docs/plans/prereg-salience-surge-v2.md.
#
# The reusable pieces (ridge_logistic(), predict_ridge(), surge_training_population(),
# surge_hazard_for()) live in R/salience_surge.R -- this script is validation
# reporting only, not a second copy of the fit.
#
# WHY THIS FORM. A raw linear regression of vote share on salience jump was
# pre-registered and REFUSED on 2026-08-26
# (docs/reviews/salience-regression-refused-2026-08-26.md): it beat baseline on
# fed2022 (the teal wave) and then predicted Adam Bandt at 66.2% on an actual
# 39.5%, because a linear term in jump cannot tell "loud because emerging" from
# "loud because famous incumbent" -- and it was applied to every non-major
# candidate, sitting members included.
#
# This version is gated to the GOVERNED population only (governed_population(),
# R/salience_screen.R) -- prev_party < 15, not a surging class, not personally
# returning -- which excludes every declining-incumbent case that broke the
# refused attempt BY CONSTRUCTION. Bandt (23.7% prior) and 2025-Ryan (34% prior)
# both fail `prev_party < 15` and are never in this population at all.
#
# A first attempt with plain glm() and all 4 features (jump_pctile, prev_party,
# prev_ind, party class) quasi-separated: only 8 winners across 687 governed
# candidates over 4 elections, against 4-7 effective parameters. LOO log loss
# was WORSE than a naive base-rate baseline in 3 of 4 elections, and the dry-run
# check scored Ian Cook (18% actual, lost) at p_hat=0.619 -- reproducing the
# exact overconfident-decliner failure this design exists to avoid, via
# overfitting instead of an ungated population. Fixed two ways, per Pete's
# direction: (1) fed2019 fetched and pooled in as a 5th election -- it is no
# longer available as an untouched blind holdout after this, which is a real
# cost, accepted deliberately; (2) fit with an L2 (ridge) penalty instead of
# plain glm(), penalty chosen by NESTED leave-one-election-out (never using the
# true held-out election to choose it) so lambda selection cannot leak into the
# outer score.
#
# A second bug, caught by this script's own dry-run: Andrew Wilkie's Denison
# (2016, 44.1%) renamed to Clark for 2019 -- seat-name matching only strips
# case/punctuation, not genuine redistribution renames, so he scored as a
# fresh governed candidate with prev_party near 0 and contaminated the surge-
# size estimate. Fixed via a small SEAT_RENAMES lookup in governed_population().
#
# Emits FS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

PAIRS <- list(
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "vic2022", prev = "vic2018", region = "vic"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa")
)

POP <- surge_training_population(PAIRS)
if (!nrow(POP)) stop("no governed candidates found -- has fed2019 salience been fetched? (output/salience-v6.csv)")
cat(sprintf("FS1  governed population: %d candidates across %d elections | %d winners\n",
            nrow(POP), uniqueN(POP$pair), sum(POP$elected)))
print(POP[, .(n = .N, winners = sum(elected)), by = pair])

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
log_loss <- function(y, p_hat, eps = 1e-6) {
  -mean(y * log(pmax(p_hat, eps)) + (1 - y) * log(pmax(1 - p_hat, eps)))
}

# ---- nested LOO: pick lambda WITHOUT the true held-out election -------------
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

outer_pairs <- unique(POP$pair)
LOO <- rbindlist(lapply(outer_pairs, function(held) {
  train_pairs <- setdiff(outer_pairs, held)
  lam <- pick_lambda(train_pairs)
  train <- POP[pair %in% train_pairs]
  test  <- POP[pair == held]
  fit <- fit_ridge_std(train, party_levels, lam)
  p_hat <- predict_ridge(fit$beta, build_X(test, party_levels), fit$center, fit$scale)
  base_rate <- mean(train$elected)
  data.table(pair = held, n = nrow(test), winners = sum(test$elected), lambda = lam,
            ll = log_loss(test$elected, p_hat),
            ll_base = log_loss(test$elected, rep(base_rate, nrow(test))))
}))
cat("\nFS2  nested-LOO by election, ridge-penalised, governed population only:\n")
print(LOO)
cat(sprintf("\nFS2  mean log loss: model %.4f vs base-rate-only %.4f\n",
            mean(LOO$ll), mean(LOO$ll_base)))

# ---- dry-run: known high-jump governed LOSERS must not run away -------------
cat("\nFS3  dry-run: known high-jump governed candidates who LOST\n")
full_lambda <- pick_lambda(outer_pairs)
full_fit <- fit_ridge_std(POP, party_levels, full_lambda)
dry <- POP[keyword %in% c("Ian Cook", "David Speirs")]
if (nrow(dry)) {
  dry$p_hat <- predict_ridge(full_fit$beta, build_X(dry, party_levels), full_fit$center, full_fit$scale)
  print(dry[, .(pair, seat, keyword, party, jump_pctile = round(jump_pctile, 2),
               prev_party = round(prev_party, 1), pcv = round(pcv, 1), p_hat = round(p_hat, 3))])
} else {
  cat("FS3  neither found in the governed population -- check keyword spelling/coverage\n")
}
cat(sprintf("FS3  full-population lambda chosen (nested LOO): %.1f\n", full_lambda))

winners <- POP[elected == TRUE]
cat(sprintf("\nFS4  pooled surge size from %d governed winners: mean pcv %.2f | sd pcv %.2f\n",
            nrow(winners), mean(winners$pcv), sd(winners$pcv)))

fwrite(POP, "output/salience-surge-v2-population.csv")
cat(sprintf("\nFS9  wrote output/salience-surge-v2-population.csv: %d rows\n", nrow(POP)))

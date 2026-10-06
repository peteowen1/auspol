# scripts/quick_arm.R's scoring helpers (R/quick_arm.R). The orchestration (processes,
# junctions, cache) is exercised by running the script; these pin the numbers it prints,
# and each check is shown to FAIL on a deliberately broken input.

mk_ap <- function(p_win = c(0.8, 0.6, 0.3), pair = c("a1", "a1", "a2")) {
  # one seat per row of p_win: a winner party "ALP" and a loser "LNP"
  n <- length(p_win)
  pair <- rep_len(pair, n)
  data.frame(pair = rep(pair, each = 2), seat = rep(paste0("s", seq_len(n)), each = 2),
             party = rep(c("ALP", "LNP"), n), prob = as.vector(rbind(p_win, 1 - p_win)),
             actual = "ALP", stringsAsFactors = FALSE)
}
mk_sd <- function(pred = c(40, 30, 20, 10), actual = c(42, 28, 20, 12)) {
  data.frame(pair = "a1", seat = paste0("s", seq_along(pred)), party = "ALP",
             pred_share = pred, actual_share = actual, stringsAsFactors = FALSE)
}

test_that("quick_parse_env accepts assignments and refuses anything else", {
  expect_equal(quick_parse_env("AUSPOL_X=1  AUSPOL_Y=0"), c(AUSPOL_X = "1", AUSPOL_Y = "0"))
  expect_length(quick_parse_env(""), 0L)
  expect_length(quick_parse_env(NULL), 0L)
  expect_error(quick_parse_env("AUSPOL_X=1 oops"), "not an AUSPOL_NAME=value")
  expect_error(quick_parse_env("X=1"), "not an AUSPOL_NAME=value")          # a typo'd prefix would be an arm that never ran
  expect_error(quick_parse_env("AUSPOL_X=1 AUSPOL_X=0"), "set twice")
})

test_that("quick_units is the 22 scored elections, one harness run each, ids unique", {
  u <- quick_units()
  expect_equal(nrow(u), 22L)
  expect_false(anyDuplicated(u$id) > 0)
  expect_false("wa2021" %in% u$id)                               # no fittable poll trend; the rebuild skips it too
  expect_setequal(unique(u$harness), c("fed", "wa", "vic", "nsw", "qld", "sa"))
  expect_equal(u$var[u$id == "vic2022"], "AUSPOL_VIC_PAIR")
})

test_that("quick_winner_prob reads the probability of the actual winner, 0 when it was never drawn", {
  ap <- mk_ap(c(0.8, 0.6))
  expect_equal(quick_winner_prob(ap)$p, c(0.8, 0.6))
  ap2 <- ap[ap$party == "LNP" | ap$seat == "s2", ]               # seat s1's winner has no row at all
  w <- quick_winner_prob(ap2)
  expect_equal(w$p[w$seat == "s1"], 0)
  expect_error(quick_winner_prob(ap[, c("pair", "seat", "party", "prob")]), "missing actual")
})

test_that("quick_clustered reproduces the score_arm.R formula and has no SE with one cluster", {
  d <- c(0.1, 0.3, -0.2, 0.0, 0.5); cl <- c("a", "a", "b", "b", "c")
  r <- quick_clustered(d, cl)
  s <- c(a = 0.4, b = -0.2, c = 0.5); n <- c(a = 2, b = 2, c = 1)
  m <- sum(s) / sum(n)
  expect_equal(r$mean, m)
  expect_equal(r$se, sqrt(3 / 2 * sum((s - n * m)^2)) / sum(n))
  expect_true(is.na(quick_clustered(d, rep("a", 5))$se))
  expect_error(quick_clustered(c(d[1:4], NA), cl), "anyNA")
})

test_that("quick_seat_ll: identical runs score exactly zero; a worse arm scores positive", {
  ap <- mk_ap()
  same <- quick_seat_ll(ap, ap)
  expect_equal(same$overall$mean, 0)
  expect_true(all(same$per_pair$seats_changed == 0))
  worse <- ap; worse$prob[worse$seat == "s1" & worse$party == "ALP"] <- 0.4
  worse$prob[worse$seat == "s1" & worse$party == "LNP"] <- 0.6
  r <- quick_seat_ll(ap, worse)
  expect_equal(r$seats$dd[r$seats$seat == "s1"], -log(0.4) + log(0.8))
  expect_equal(sum(r$per_pair$seats_changed), 1L)
  expect_gt(r$overall$mean, 0)
})

test_that("quick_seat_ll floors the winner probability and refuses mismatched seat sets", {
  ap <- mk_ap(c(0.8, 0))
  r <- quick_seat_ll(ap, ap, eps = 0.01)
  expect_equal(r$seats$ll_base[2], -log(0.01))
  # BROKEN INPUT: the arm lost a seat. Silently comparing the overlap would shrink the scored set.
  expect_error(quick_seat_ll(ap, ap[ap$seat != "s2", ]), "seat sets differ")
})

test_that("quick_share_diff: no movement means no changed cells; a move toward the result lowers squared error", {
  b <- mk_sd()
  r0 <- quick_share_diff(b, b)
  expect_equal(sum(r0$per_pair$changed), 0L)
  expect_true(is.na(r0$primary$se))                              # fewer than 2 changed cells: not assessable, never a pass
  a <- b; a$pred_share[1:3] <- a$pred_share[1:3] + c(1, -1, 0.01)   # third move is under the 0.05 tolerance
  r <- quick_share_diff(b, a)
  expect_equal(r$primary$n, 2L)
  expect_equal(r$primary$change, ((42 - 41)^2 - (42 - 40)^2) + ((28 - 29)^2 - (28 - 30)^2))
  expect_lt(r$primary$change, 0)
})

test_that("quick_share_diff refuses runs that are not the same cells or the same election", {
  b <- mk_sd()
  expect_error(quick_share_diff(b, b[-1, ]), "cell sets differ")
  a <- b; a$actual_share[2] <- 99
  expect_error(quick_share_diff(b, a), "not scoring the same election")
  dup <- rbind(b, b[1, ])
  expect_error(quick_share_diff(dup, dup), "duplicate")
})

test_that("quick_ledger_ll reports its own coverage and only counts ledger seats", {
  ap <- mk_ap(c(0.8, 0.6, 0.3))
  worse <- ap; worse$prob[worse$seat == "s3" & worse$party == "ALP"] <- 0.1
  worse$prob[worse$seat == "s3" & worse$party == "LNP"] <- 0.9
  ll <- quick_seat_ll(ap, worse)
  L <- quick_ledger_ll(ll, data.frame(pair = c("a1", "a2", "zz"), seat = c("s1", "s3", "s9")))
  expect_equal(L$n, 2L); expect_equal(L$rows, 3L)               # s9 is not scored: the shortfall is visible
  expect_gt(L$ll_arm, L$ll_base)
  expect_equal(quick_ledger_ll(ll, data.frame(pair = "no", seat = "no"))$n, 0L)
})

test_that("quick_word reads a change against its SE", {
  expect_match(quick_word(-0.02, 0.01), "BETTER")
  expect_match(quick_word(0.02, 0.01), "WORSE")
  expect_match(quick_word(0.005, 0.01), "within")
  expect_match(quick_word(0.1, NA), "no SE")
})

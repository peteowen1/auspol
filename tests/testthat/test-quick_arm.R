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

# ---- review fixes (2026-10-07) ----------------------------------------------------

test_that("Q2's SE is clustered on election, not on cells; one election is NOT ASSESSABLE", {
  # 6 changed cells; 3 elections, each contributing one big and one small cell. The cell-level SE
  # (old) treats the 6 as independent; the clustered SE is the spread of election totals.
  b <- data.frame(pair = rep(c("e1", "e2", "e3"), each = 2), seat = paste0("s", 1:6), party = "ALP",
                  pred_share = 40, actual_share = c(44, 43, 45, 44, 38, 37), stringsAsFactors = FALSE)
  a <- b; a$pred_share <- b$pred_share + c(1, 1, 2, 2, -1, -1)
  r <- quick_share_diff(b, a)
  expect_equal(r$primary$n, 6L); expect_equal(r$primary$clusters, 3L)
  d <- r$cells$d
  expect_equal(r$primary$se, quick_clustered(d, r$cells$pair)$se * 6)
  expect_false(isTRUE(all.equal(r$primary$se, stats::sd(d) * sqrt(6))))   # differs from the old cell-level SE
  # all changed cells in ONE election: no clustered SE, so no verdict (the old code gave a PASS/WORSE here)
  one <- b[b$pair == "e1", ]; one$pair <- "e1"; one <- rbind(one, transform(one, seat = c("s7", "s8")))
  a1 <- one; a1$pred_share <- one$pred_share + c(1, 2, 1, 2)
  r1 <- quick_share_diff(one, a1)
  expect_equal(r1$primary$n, 4L); expect_true(is.na(r1$primary$se))
  expect_match(quick_q2_verdict(r1$primary), "NOT ASSESSABLE")
  expect_match(quick_q2_verdict(list(se = 1, change = 5, base = 10, n = 9, clusters = 3)), "WORSE")
  expect_match(quick_q2_verdict(list(se = 1, change = -5, base = 10, n = 9, clusters = 3)), "PASS")
  expect_match(quick_q2_verdict(list(se = 1, change = -0.5, base = 10, n = 9, clusters = 3)), "FAIL")
})

test_that("quick_max_diff is exactly 0 only when every share and every win probability matches", {
  sd0 <- mk_sd(); sd0 <- rbind(sd0, transform(sd0[3, ], pair = "a2")); ap0 <- mk_ap()   # elections a1 and a2 on both levels
  z <- quick_max_diff(sd0, sd0, ap0, ap0)
  expect_equal(z$max_diff, c(0, 0))
  # a 0.01-point share move is under the 0.05 'changed cell' tolerance, so the old Q1 called the election untouched
  sd1 <- sd0; sd1$pred_share[2] <- sd1$pred_share[2] + 0.01
  expect_equal(sum(quick_share_diff(sd0, sd1)$per_pair$changed), 0L)
  m1 <- quick_max_diff(sd0, sd1, ap0, ap0)
  expect_equal(m1$max_share_diff, c(0.01, 0)); expect_equal(m1$max_prob_diff, c(0, 0)); expect_equal(m1$max_diff > 0, c(TRUE, FALSE))
  # a win-probability-only change (the winner log loss moves by < 1e-12, the old test): still not identical
  ap1 <- ap0; ap1$prob[1] <- ap1$prob[1] + 1e-13; ap1$prob[2] <- ap1$prob[2] - 1e-13
  expect_equal(quick_seat_ll(ap0, ap1)$per_pair$seats_changed, c(0L, 0L))
  expect_gt(quick_max_diff(sd0, sd0, ap0, ap1)$max_prob_diff[1], 0)
  # a party present in one allprobs and not the other counts as probability 0 there
  ap2 <- ap0[!(ap0$seat == "s1" & ap0$party == "LNP"), ]
  expect_equal(quick_max_diff(sd0, sd0, ap0, ap2)$max_prob_diff, c(0.2, 0))
  # a share missing in one run is never 'identical'
  expect_true(is.infinite(quick_max_diff(sd0, sd0[-1, ], ap0, ap0)$max_share_diff[1]))
})

test_that("switch validation: unregistered names stop, and HD1 must list every switch named", {
  reg <- c("AUSPOL_NEW_IND_SHRINK", "AUSPOL_SHRINK", "AUSPOL_XGB_PRIMARY")
  expect_silent(quick_check_registered(c("AUSPOL_NEW_IND_SHRINK"), reg))
  expect_error(quick_check_registered("AUSPOL_NEW_IND_SHRNK", reg), "AUSPOL_NEW_IND_SHRNK")   # deliberate misspelling
  hd1 <- "HD1  caller set 2 switch(es): AUSPOL_NEW_IND_SHRINK=0 AUSPOL_XGB_PRIMARY=1"
  expect_true(quick_hd1_check(hd1, c("AUSPOL_NEW_IND_SHRINK", "AUSPOL_XGB_PRIMARY"), "AUSPOL_NEW_IND_SHRINK")$ok)
  # named but never applied
  r <- quick_hd1_check("HD1  caller set 1 switch(es): AUSPOL_XGB_PRIMARY=1", "AUSPOL_XGB_PRIMARY", c("AUSPOL_NEW_IND_SHRINK"))
  expect_false(r$ok); expect_equal(r$missing, "AUSPOL_NEW_IND_SHRINK")
  # leaked from an earlier task
  r <- quick_hd1_check(hd1, "AUSPOL_XGB_PRIMARY", character(0))
  expect_false(r$ok); expect_equal(r$foreign, "AUSPOL_NEW_IND_SHRINK")
  expect_true(quick_hd1_check(NA_character_, "A", character(0))$no_hd1)
  expect_false(quick_hd1_check(NA_character_, "A", character(0))$ok)
})

test_that("quick_tree_sig changes with any file, recursively, and never matches when unreadable", {
  d <- tempfile("sig"); dir.create(file.path(d, "sub"), recursive = TRUE)
  writeLines("a", file.path(d, "sub", "f.txt"))
  s1 <- quick_tree_sig(d)
  expect_equal(quick_tree_sig(d), s1)
  writeLines("a longer file", file.path(d, "sub", "f.txt"))              # same name, deeper level, new size
  expect_false(identical(quick_tree_sig(d), s1))
  expect_false(identical(quick_tree_sig(file.path(d, "nope")), quick_tree_sig(file.path(d, "nope"))))
  unlink(d, recursive = TRUE)
})

test_that("the scratch-root guards refuse unmarked directories and surviving junctions", {
  d <- tempfile("root")
  expect_error(quick_check_root(d, create = FALSE), "nothing to clean")
  quick_check_root(d, create = TRUE)                                      # new: created and marked
  expect_true(file.exists(file.path(d, ".quick-arm-root")))
  expect_silent(quick_check_root(d, create = FALSE))
  other <- tempfile("real"); dir.create(other); writeLines("x", file.path(other, "keep.txt"))
  expect_error(quick_check_root(other, create = TRUE), "no .quick-arm-root marker")   # a real tree is not adopted
  expect_error(quick_check_root(other, create = FALSE), "no .quick-arm-root marker")
  expect_true(file.exists(file.path(other, "keep.txt")))
  slot <- file.path(d, "slot1"); dir.create(file.path(slot, "R"), recursive = TRUE)   # a 'junction' that did not go away
  expect_error(quick_assert_no_links(slot, c("R", "src")), "junction.s. still present")
  unlink(file.path(slot, "R"), recursive = TRUE)
  expect_silent(quick_assert_no_links(slot, c("R", "src")))
  unlink(c(d, other), recursive = TRUE)
})

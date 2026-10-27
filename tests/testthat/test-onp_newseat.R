# AUSPOL_ONP_NEWSEAT_RULE (R/onp_newseat.R). docs/plans/prereg-onp-newseat-rule-2026-10-25.md

seats <- c("A", "B", "C", "D", "E", "F")
house <- data.frame(region = "qld", cycle = 2020L, fed = 2019L,
                    district = seats, house_pct = c(2, 9, 5, 12, 0, 7))
senate <- data.frame(region = "qld", cycle = 2020L, fed = 2019L,
                     district = seats, senate_pct = c(4, 3, 8, 6, 5, 9))
mk_shares <- function() {
  m <- cbind(ALP = c(40, 35, 30, 38, 33, 36), LNP = c(35, 40, 38, 30, 37, 34),
             ONP = c(12, 6, 6, 6, 6, 6), OTH = c(13, 19, 26, 26, 24, 24))
  rownames(m) <- seats
  m
}
hist <- c(A = TRUE, B = FALSE, C = FALSE, D = FALSE, E = FALSE, F = FALSE)

test_that("onp_rank_ratio and onp_cv_force reproduce the live allocation's old inline code exactly", {
  set.seed(7)
  n <- 88; seats88 <- paste0("s", seq_len(n)); idx <- runif(n, 1, 12)
  sa_ratio <- sort(rlnorm(47, 0, 0.35)); sa_ratio <- sort(sa_ratio / mean(sa_ratio))
  ord <- order(idx)
  old <- numeric(n); names(old) <- seats88
  for (r in seq_along(ord)) {                       # the loop as it stood in fit_seats_full.R
    q <- (r - 1) / (length(ord) - 1)
    pos <- q * (length(sa_ratio) - 1)
    lo <- floor(pos) + 1; hi <- min(lo + 1, length(sa_ratio))
    old[seats88[ord[r]]] <- sa_ratio[lo] + (pos - (lo - 1)) * (sa_ratio[hi] - sa_ratio[lo])
  }
  new <- onp_rank_ratio(ord, sa_ratio, seats88)
  expect_identical(new, old)
  cur <- stats::sd(old) / mean(old)
  expect_identical(onp_cv_force(new, 0.365), pmax(1 + (0.365 / cur) * (old - 1), 0.02))
  expect_identical(names(onp_cv_force(new, 0.365)), seats88)
  expect_error(onp_rank_ratio(ord, rev(sa_ratio), seats88), "sorted")
})

test_that("the rule touches only no-history seats, keeps their level, and ranks them on the key", {
  sh <- mk_shares()
  k6 <- structure(stats::setNames(senate$senate_pct, seats), source = "fed2019 SENATE", fed = 2019L)
  # the check line must print, with its source (a subset that dropped the attribute once made it print nothing)
  expect_output(out <- onp_newseat_apply(sh, "qld2020", hist, order = "senate_rank", lookup = seats, cv = 0.3, key = k6),
                "ONN1  qld2020: 5 seat\\(s\\) .*fed2019 SENATE.*level 6\\.00 kept")
  expect_identical(attr(out, "onp_newseat")$fed, 2019L)
  nh <- seats[!hist]
  expect_identical(out["A", ], sh["A", ])                      # the history seat is untouched
  expect_equal(mean(out[nh, "ONP"]), mean(sh[nh, "ONP"]))      # level kept over the no-history seats
  key <- stats::setNames(senate$senate_pct, seats)[nh]
  expect_identical(order(out[nh, "ONP"]), order(key))         # ranked on the key
  expect_equal(stats::sd(out[nh, "ONP"]) / mean(out[nh, "ONP"]), 0.3, tolerance = 1e-8)
  expect_identical(out[, c("ALP", "LNP", "OTH")], sh[, c("ALP", "LNP", "OTH")])   # refill "none"
  pr <- onp_newseat_apply(sh, "qld2020", hist, order = "senate_rank", cv = 0.3, refill = "prop",
                          key = stats::setNames(senate$senate_pct, seats))
  expect_equal(unname(rowSums(pr)), unname(rowSums(sh)))       # refill "prop" keeps row totals
})

test_that("a deliberately broken input fails: wrong ranking is detected, missing history and bad switch error", {
  sh <- mk_shares()
  nh <- seats[!hist]
  bad <- onp_newseat_apply(sh, "qld2020", hist, order = "senate_rank", cv = 0.3,
                           key = stats::setNames(-senate$senate_pct, seats))
  # the ranking check above would FAIL on a reversed key
  expect_false(identical(order(bad[nh, "ONP"]), order(senate$senate_pct[!hist])))
  expect_error(onp_newseat_apply(sh, "qld2020", hist[-2], order = "senate_rank", cv = 0.3,
                                 key = stats::setNames(senate$senate_pct, seats)), "no history flag")
  expect_error(onp_newseat_apply(sh, "qld2020", hist, order = "greens", cv = 0.3), "House|Senate")
  withr::with_envvar(c(AUSPOL_ONP_NEWSEAT_RULE = "yes"), expect_error(onp_newseat_rule(), "must be"))
  withr::with_envvar(c(AUSPOL_ONP_NEWSEAT_RULE = NA), expect_true(onp_newseat_rule()))   # shipped 2026-10-26
  withr::with_envvar(c(AUSPOL_ONP_NEWSEAT_RULE = "0"), expect_false(onp_newseat_rule()))
  withr::with_envvar(c(AUSPOL_ONP_NEWSEAT_RULE = "1"), expect_true(onp_newseat_rule()))
})

test_that("standing limits the rule to seats One Nation contests; too few seats leaves the matrix alone", {
  sh <- mk_shares()
  out <- onp_newseat_apply(sh, "qld2020", hist, order = "senate_rank", cv = 0.3, standing = c("A", "B", "C", "D"),
                           key = stats::setNames(senate$senate_pct, seats))
  expect_identical(out[c("E", "F"), ], sh[c("E", "F"), ])
  expect_equal(mean(out[c("B", "C", "D"), "ONP"]), mean(sh[c("B", "C", "D"), "ONP"]))
  same <- onp_newseat_apply(sh, "qld2020", hist, order = "senate_rank", cv = 0.3, standing = c("A", "B"),
                            key = stats::setNames(senate$senate_pct, seats))
  expect_identical(same, sh)
})

test_that("onp_federal_key: House zero is no information, and a later federal table is refused (leakage)", {
  k <- onp_federal_key(c("a", "E", "Nowhere"), "qld2020", order = "federal", house = house)
  expect_equal(as.numeric(k), c(2, NA, NA))
  expect_equal(attr(k, "fed"), 2019L)
  late <- house; late$fed <- 2021L
  expect_error(onp_federal_key("A", "qld2020", order = "federal", house = late), "leakage")
  late_s <- senate; late_s$fed <- 2021L
  expect_error(onp_federal_key("A", "qld2020", order = "senate_rank", senate = late_s), "leakage")
  none <- onp_federal_key("A", "sa2026", order = "federal", house = house)
  expect_true(is.list(none) && !length(none) && nzchar(attr(none, "why")))
})

test_that("a federal target: no House key; Senate key from the latest EARLIER federal election only", {
  div <- data.frame(fed = c(2019L, 2019L, 2022L, 2022L), state = "QLD", division = c("Alpha", "Beta", "Alpha", "Beta"),
                    cls = "ONP", v = 1, senate_pct = c(3, 7, 30, 70))
  expect_true(is.list(onp_federal_key("Alpha", "fed2022", order = "federal", division = div)))
  k <- onp_federal_key(c("Alpha", "Beta"), "fed2022", order = "senate_rank", division = div)
  expect_equal(as.numeric(k), c(3, 7))
  expect_equal(attr(k, "fed"), 2019L)
})

test_that("onp_newseat_cv is fitted on earlier elections only", {
  mk <- function(el, n, mu, sdv) data.frame(election = el, seat = paste0(el, seq_len(n)), party = "ONP",
                                            pcv = mu + sdv * stats::qnorm(((seq_len(n)) - 0.5) / n))
  cand <- rbind(mk("qld2017", 40, 14, 6), mk("fed2019", 40, 5, 3), mk("wa2017", 30, 6, 3))
  a <- onp_newseat_cv("qld2020", 8, cand = cand)
  later <- rbind(cand, mk("qld2024", 40, 8, 40))           # a LATER election with a huge spread
  b <- onp_newseat_cv("qld2020", 8, cand = later)
  expect_identical(a, b)
  expect_setequal(a$sources, c("qld2017", "fed2019", "wa2017"))
  expect_null(onp_newseat_cv("wa2001", 8, cand = cand))     # nothing earlier
  expect_true(a$cv > 0 && a$cv < 1)
})

test_that("onp_newseat_prepare adds a zero One Nation column only when absent and standing", {
  m <- cbind(ALP = c(50, 60), LNP = c(50, 40)); rownames(m) <- c("X", "Y")
  p <- onp_newseat_prepare(m, c(ALP = 55, LNP = 45), standing = "X", target = "nsw2019")
  expect_true("ONP" %in% colnames(p$mat))
  expect_equal(unname(p$mat[, "ONP"]), c(0, 0))
  expect_equal(p$prev_level[["ONP"]], 0)
  expect_false(any(p$history))
  q <- onp_newseat_prepare(m, c(ALP = 55, LNP = 45), standing = character(0), target = "nsw2019")
  expect_identical(q$mat, m)
  m2 <- cbind(m, ONP = c(5, 0))
  r <- onp_newseat_prepare(m2, c(ALP = 55, LNP = 45, ONP = 2.5), standing = "X", target = "nsw2023")
  expect_identical(r$mat, m2)
  expect_equal(unname(r$history), c(TRUE, FALSE))
})

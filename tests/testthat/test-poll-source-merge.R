# .ps_same_poll_far(): one poll dated differently by two sources (Resolve's two-month Victorian polls sat 14-29
# days apart across Wikipedia, AE and BludgerTrack and were counted twice until 2026-10-13).
# .ps_merge_own(): Wikipedia + BludgerTrack, one row per poll, BludgerTrack's kept, origin recorded.

mk <- function(date, firm, alp, lnp, grn, onp = NA_real_, check = "ok")
  data.table::data.table(date = as.Date(date), end = as.Date(date), firm_raw = firm, tpp_published = NA_real_,
                         ALP = alp, LNP = lnp, GRN = grn, ONP = onp, OTH = 100 - alp - lnp - grn, und = 0, check = check)

test_that("same primaries up to 31 days apart are one poll; different primaries or 40 days are not", {
  a <- mk(c("2025-03-01", "2025-03-01", "2025-03-01"), "Resolve", c(24, 24, 24), c(41, 41, 41), c(14, 14, 14))
  b <- mk(c("2025-03-30", "2025-03-30", "2025-04-10"), "Resolve", c(24, 26, 24), c(41, 41, 41), c(14, 14, 14))
  dd <- as.integer(a$date - b$date)
  expect_equal(.ps_same_poll_far(dd, a, b, 1:3, 1:3), c(TRUE, FALSE, FALSE))
})

test_that("merge keeps one row per poll, prefers BludgerTrack, and adds BludgerTrack-only polls", {
  alias <- data.table::data.table(pattern = "resolve", canonical = "resolve")
  wiki <- mk(c("2025-03-30", "2025-06-01"), "Resolve", c(24, 30), c(41, 35), c(14, 12))
  bt   <- mk(c("2025-03-10", "2025-08-01"), "Resolve Strategic", c(24, 28), c(41, 36), c(14, 13))
  mo <- .ps_merge_own(wiki, bt, alias)
  expect_equal(nrow(mo$ours), 3L)
  expect_setequal(mo$ours$origin, c("bludgertrack+wiki", "wiki", "bludgertrack"))
  expect_equal(mo$ours$date[mo$ours$origin == "bludgertrack+wiki"], as.Date("2025-03-10"))
  # a BludgerTrack row failing its own two-party check loses to Wikipedia's
  bt$check[1] <- "suspect"
  mo2 <- .ps_merge_own(wiki, bt, alias)
  expect_equal(mo2$ours$origin[mo2$ours$date == as.Date("2025-03-30")], "wiki+bludgertrack")
  expect_equal(nrow(mo2$ours), 3L)
})

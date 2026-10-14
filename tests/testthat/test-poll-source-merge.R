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

test_that("same-poll test uses the parties both rows report (WA Galaxy 2018: One Nation blank in AE's copy)", {
  a <- mk("2018-08-03", "Galaxy", 40, 32, 11)                 # ONP NA
  b <- mk("2018-08-12", "YouGov-Galaxy", 40, 32, 11, onp = 5)
  expect_true(.ps_same_poll_far(-9L, a, b, 1L, 1L))
  # deliberately broken: a genuinely different poll must NOT merge
  expect_false(.ps_same_poll_far(-9L, a, mk("2018-08-12", "x", 43, 32, 11, onp = 5), 1L, 1L))   # Labor 3 points apart
  expect_false(.ps_same_poll_far(-9L, mk("2018-08-03", "x", 40, 32, 11, onp = 8), b, 1L, 1L))   # One Nation both given, 3 apart
  expect_false(.ps_same_poll_far(-9L, mk("2018-08-03", "x", 40, 32, NA), b, 1L, 1L))            # Greens on one row only
  expect_false(.ps_same_poll_far(-40L, a, b, 1L, 1L))                                           # too far apart
  expect_true(.ps_same_poll_far(-9L, mk("2018-08-03", "x", 40, 32, NA), mk("2018-08-12", "y", 40, 32, NA), 1L, 1L))  # no Greens in either
})

test_that("the same pollster under two names pairs only on matching primaries", {
  a <- mk(c("2018-08-03", "2018-08-03"), "Galaxy", c(40, 40), c(32, 32), c(11, 11), onp = c(NA, NA)); a$canon <- "galaxy"
  b <- mk(c("2018-08-05", "2018-08-05"), "YouGov-Galaxy", c(40, 44), c(32, 30), c(11, 11), onp = c(5, 5)); b$canon <- "yougov"
  cand <- .ps_pair_candidates(a, b, 4L)
  expect_equal(unique(cand$bi), 1L)                      # the 44/30 row is a different poll even 2 days apart
  expect_true(all(c(1L, 2L) %in% cand$ai))
})

test_that(".ps_month_range reads quarter and cross-year month ranges, nothing else", {
  r <- .ps_month_range(c("Apr–Jun 2017", "Nov 2016–Jan 2017", "Oct-Dec 2017", "10 Mar – 2 Apr 2017", "May 2017", NA))
  expect_equal(r$start, as.Date(c("2017-04-01", "2016-11-01", "2017-10-01", NA, NA, NA)))
  expect_equal(r$end, as.Date(c("2017-06-30", "2017-01-31", "2017-12-31", NA, NA, NA)))
})

test_that("wiki_polls keeps a long month-range poll but still refuses long day-level fieldwork", {
  w <- data.table::data.table(
    row_type = "poll", table_type = "primary", region = "wa", section = "Voting intention",
    date_raw = c("Apr–Jun 2017", "10 Mar – 20 May 2017", "Nov 2016–Jan 2017"),
    firm_raw = "Essential", footnote_raw = "",
    fieldwork_start = c("2017-04-01", "2017-03-10", NA), fieldwork_end = c("2017-06-30", "2017-05-20", NA),
    alp_fp = 44, lnp_fp = NA_real_, lib_fp = 33, nat_fp = 4, alp_tpp = NA_real_, pv_GRN = "9%", pv_ONP = "5%")
  f <- tempfile(fileext = ".csv"); data.table::fwrite(w, f)
  out <- wiki_polls("wa", c("ALP", "LNP", "NAT", "GRN", "ONP", "OTH"), f)
  expect_equal(sort(out$date), as.Date(c("2016-12-16", "2017-05-16")))   # midpoints of the two month ranges only
})

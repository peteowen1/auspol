# thin_cycle_statewide(): previous result moved by precision-weighted polls.
# Synthetic corpus and polls, so it runs without any data on disk.

thin_fixture <- function() {
  # Swings between consecutive elections in two regions, all before 2020.
  corpus <- data.table::data.table(
    election = rep(c("wa2005", "wa2008", "wa2013", "fed2007", "fed2010", "fed2013"), each = 3),
    party = rep(c("ALP", "LNP", "OTH"), 6),
    votes = c(45, 40, 15,  40, 45, 15,  35, 50, 15,  43, 42, 15,  38, 44, 18,  33, 45, 22))
  corpus
}
thin_polls <- function(dates, alp, lnp) {
  p <- data.table::data.table(date = as.Date(dates), firm = "X", tpp_published = NA_real_,
                              ALP = alp, LNP = lnp, OTH = 100 - alp - lnp)
  data.table::setattr(p, "parties", c("ALP", "LNP", "OTH"))
  p
}

test_that("no polls in the cycle returns the previous result", {
  st_a <- c(ALP = 40, LNP = 45, OTH = 15)
  out <- suppressWarnings(capture.output(r <- thin_cycle_statewide(
    "wa", 2017, "2017-03-11", c("ALP", "LNP", "OTH"), st_a,
    polls = thin_polls(character(0), numeric(0), numeric(0)), corpus = thin_fixture())))
  expect_equal(unname(r[c("ALP", "LNP", "OTH")]), c(40, 45, 15), tolerance = 1e-9)
  expect_equal(attr(r, "n_polls"), 0L)
})

test_that("more polls move the level further toward them, and recent ones count more", {
  st_a <- c(ALP = 40, LNP = 45, OTH = 15)
  one <- function(dates) suppressWarnings({ capture.output(r <- thin_cycle_statewide(
    "wa", 2017, "2017-03-11", c("ALP", "LNP", "OTH"), st_a,
    polls = thin_polls(dates, rep(50, length(dates)), rep(35, length(dates))), corpus = thin_fixture())); r })
  r2  <- one(c("2017-02-01", "2017-02-15"))
  r20 <- one(seq(as.Date("2016-12-01"), by = "3 days", length.out = 20))
  old <- one("2014-01-01")
  new <- one("2017-03-01")
  expect_gt(r2[["ALP"]], 40); expect_lt(r2[["ALP"]], 50)
  expect_gt(r20[["ALP"]], r2[["ALP"]])
  expect_gt(attr(r20, "w_polls")[["ALP"]], attr(r2, "w_polls")[["ALP"]])
  expect_gt(new[["ALP"]], old[["ALP"]])
  expect_equal(sum(r20), 100, tolerance = 1e-9)
})

test_that("tau is time-forward: pairs at or after the target are never used", {
  st_a <- c(ALP = 40, LNP = 45, OTH = 15)
  co <- thin_fixture()
  none <- thin_polls(character(0), numeric(0), numeric(0))
  # wa2013 (2013-03-09): wa2005->wa2008 and fed2007->fed2010 end before it; fed2010->fed2013 (Sept 2013)
  # and wa2008->wa2013 (the target itself) must not count.
  lines <- capture.output(suppressWarnings(thin_cycle_statewide("wa", 2013, "2013-03-09", c("ALP", "LNP", "OTH"), st_a,
    polls = none, corpus = co)))
  expect_true(any(grepl("tau from 2 earlier election pairs", lines)))
  # wa2008: no pair ends before it (fed2004 and wa2001 are not in the corpus) -- refuse, never look ahead
  expect_error(suppressWarnings(capture.output(thin_cycle_statewide("wa", 2008, "2008-09-06", c("ALP", "LNP", "OTH"),
    st_a, polls = none, corpus = co))), "no earlier election pairs")
})

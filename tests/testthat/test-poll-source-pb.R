# .ps_pb_confirm(): a Poll Bludger post replaces AE's numbers only when it is stated, of the same firm, inside the
# date window, and agrees within 2 points on every major party.

test_that("Poll Bludger confirms agreeing AE rows and leaves the rest alone", {
  alias <- data.table::data.table(pattern = c("newspoll", "morgan"), canonical = c("newspoll", "roymorgan"))
  ae <- data.table::data.table(date = as.Date(c("2010-03-01", "2010-03-01", "2010-03-01", "2010-03-01")),
                               firm = c("Newspoll", "Morgan", "Newspoll", "Newspoll"),
                               ALP = c(40, 40, 40, 40), LNP = c(42, 42, 42, 42), GRN = c(10, 10, 10, 10),
                               OTH = c(8, 8, 8, 8), .origin = "ae", .fill = "")
  ae$date[3] <- as.Date("2009-12-01"); ae$date[4] <- as.Date("2009-06-01")
  pb <- data.table::data.table(region = "fed", stated = c("TRUE", "TRUE", "FALSE", "TRUE"),
                               pollster = c("Newspoll", "Roy Morgan", "Newspoll", "Newspoll"),
                               post_date = c("2010-03-04", "2010-03-04", "2009-12-04", "2009-09-01"),
                               alp_n = c(41, 45, 40, 40), coalition_n = c(41, 37, 42, 42), greens_n = c(10, 10, 10, 10),
                               one_nation_n = NA, undecided_n = NA)
  f <- tempfile(fileext = ".csv"); data.table::fwrite(pb, f)
  r <- .ps_pb_confirm(data.table::copy(ae), "fed", c("ALP", "LNP", "GRN", "OTH"), f, alias)
  # row 1 agrees within 2: takes Poll Bludger's numbers
  expect_equal(r$ae$.origin[1], "pollbludger"); expect_equal(r$ae$ALP[1], 41); expect_equal(r$ae$OTH[1], 8)
  # row 2 disagrees by 5: AE kept, counted
  expect_equal(r$ae$.origin[2], "ae"); expect_equal(r$ae$ALP[2], 40)
  # row 3: the only post is inferred (stated FALSE): ignored
  expect_equal(r$ae$.origin[3], "ae")
  # row 4: post 92 days after the midpoint: outside the window
  expect_equal(r$ae$.origin[4], "ae")
  expect_equal(unname(r$log[c("confirmed", "disagree")]), c(1L, 1L))
})

test_that("a post inside two polls' windows goes to the nearer poll, not the closer numbers (review of 45df511)", {
  alias <- data.table::data.table(pattern = "newspoll", canonical = "newspoll")
  ae <- data.table::data.table(date = as.Date(c("2010-03-01", "2010-03-15")), firm = "Newspoll",
                               ALP = c(40, 41), LNP = c(42, 41), GRN = 10, OTH = c(8, 8), .origin = "ae", .fill = "")
  pb <- data.table::data.table(region = "fed", stated = "TRUE", pollster = "Newspoll", post_date = "2010-03-17",
                               alp_n = 40.1, coalition_n = 41.9, greens_n = 10, one_nation_n = NA, undecided_n = NA)
  f <- tempfile(fileext = ".csv"); data.table::fwrite(pb, f)
  r <- .ps_pb_confirm(data.table::copy(ae), "fed", c("ALP", "LNP", "GRN", "OTH"), f, alias)
  expect_equal(r$ae$.origin, c("ae", "pollbludger"))
})

test_that("AUSPOL_PB_COALITION_COMBINED: a combined Coalition figure confirms on Liberal + National, keeps the split, and is off by default", {
  alias <- data.table::data.table(pattern = "westpoll", canonical = "westpoll")
  ae <- data.table::data.table(date = as.Date(rep("2008-03-01", 2)), firm = "Westpoll", ALP = 36, LNP = 40, NAT = 5, GRN = 9,
                               OTH = 10, .origin = "ae", .fill = "")
  ae$date[2] <- as.Date("2007-03-01")
  # row 1: combined 45 vs Liberal 40 + National 5 = 45 (agrees); row 2: combined 48 vs 45 (off by 3: must not confirm)
  pb <- data.table::data.table(region = "wa", stated = "FALSE", stated_combined = "TRUE", pollster = "Westpoll",
                               post_date = c("2008-03-03", "2007-03-03"), alp_n = 36, coalition_n = NA, coalition_combined_n = c(45, 48),
                               greens_n = 9, one_nation_n = NA, undecided_n = NA)
  f <- tempfile(fileext = ".csv"); data.table::fwrite(pb, f)
  parties <- c("ALP", "LNP", "NAT", "GRN", "OTH")
  withr::with_envvar(c(AUSPOL_PB_COALITION_COMBINED = "0"), r0 <- .ps_pb_confirm(data.table::copy(ae), "wa", parties, f, alias))
  expect_equal(r0$ae$.origin, c("ae", "ae"))
  withr::with_envvar(c(AUSPOL_PB_COALITION_COMBINED = "1"), r1 <- .ps_pb_confirm(data.table::copy(ae), "wa", parties, f, alias))
  expect_equal(r1$ae$.origin, c("pollbludger+split", "ae"))
  expect_equal(c(r1$ae$LNP[1], r1$ae$NAT[1]), c(40, 5))
  expect_equal(unname(r1$log[c("confirmed", "disagree")]), c(1L, 1L))
})

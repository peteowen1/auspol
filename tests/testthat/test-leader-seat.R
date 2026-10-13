test_that("leaders carry the right seat, class and role", {
  f <- file.path(pkg_root(), "external", "reference", "leaders", "leaders.csv")
  skip_if_not(file.exists(f), "no leaders file")
  ls <- leader_seats()
  k <- ls[ls$pair == "nsw2023"]
  expect_equal(k$role[k$seat == "Kogarah"], "opp")
  expect_equal(k$party[k$seat == "Kogarah"], "ALP")
  expect_equal(k$role[k$seat == "Epping"], "gov")
  # Liberals for Forests (wa2001, Janet Woollard) is not the Liberal Party.
  expect_false(any(ls$pair == "wa2001" & ls$seat == "Alfred Cove" & ls$party == "LNP"))
  expect_equal(anyDuplicated(ls[, c("pair", "seat", "party")]), 0L)
})

test_that("the bonus lands on the leader's class and keeps the seat total", {
  skip_if_not(file.exists(out_path("forecasts.csv")), "no forecasts table")
  sh <- matrix(c(48, 38, 8, 6, 30, 50, 12, 8), nrow = 2, byrow = TRUE,
               dimnames = list(c("Kogarah", "Epping"), c("ALP", "LNP", "GRN", "OTH")))
  off <- withr::with_envvar(c(AUSPOL_LEADER_SEAT = "0"), leader_seat_apply(sh, "nsw2023"))
  expect_identical(off, sh)
  on <- withr::with_envvar(c(AUSPOL_LEADER_SEAT = "1"), leader_seat_apply(sh, "nsw2023"))
  expect_gt(on["Kogarah", "ALP"], sh["Kogarah", "ALP"])
  expect_gt(on["Epping", "LNP"], sh["Epping", "LNP"])
  expect_equal(unname(rowSums(on)), unname(rowSums(sh)))
  # The bonus must come only from earlier elections: nsw2023's own leaders
  # cannot be in its training set.
  b <- leader_seat_bonus("nsw2023")
  expect_lt(attr(b, "pooled")$n, nrow(leader_seats()[elections_before(leader_seats()$pair, "nsw2024")]))
})

test_that(".shift_cell moves the cell by exactly delta and keeps the row total", {
  row <- c(ALP = 45, LNP = 35, GRN = 20)
  r <- auspol:::.shift_cell(row, 1, 2.45)
  expect_equal(unname(r["ALP"]), 47.45)                  # the full bonus, not 45 + 2.45 * 55 / 102.45
  expect_equal(sum(r), 100)
  expect_equal(unname(r["LNP"] / r["GRN"]), 35 / 20)     # the others pay in proportion
  expect_equal(unname(auspol:::.shift_cell(row, 3, -30)["GRN"]), 0)    # floored at zero
  expect_equal(unname(auspol:::.shift_cell(row, 1, 80)), c(100, 0, 0))  # capped at the row total
})

test_that("leaders-supplement.csv fills elections leaders.csv lacks, and leaders.csv wins on overlap", {
  root <- withr::local_tempdir()
  d <- file.path(root, "external", "reference", "leaders"); dir.create(d, recursive = TRUE)
  cols <- c("election", "slot", "leader_clean", "party_clean", "leaders_seat_clean", "head_of_govt")
  mk <- function(e, who, party, seat, hog) data.frame(election = e, slot = 1L, leader_clean = who, party_clean = party,
                                                     leaders_seat_clean = seat, head_of_govt = hog)
  data.table::fwrite(rbind(mk("xx2010", "Real Premier", "Australian Labor Party", "Realseat", "Real Premier")), file.path(d, "leaders.csv"))
  sup <- rbind(mk("xx2010", "Overlap Loser", "Australian Labor Party", "Wrongseat", "Overlap Loser"),
               mk("xx2001", "Old Premier", "Australian Labor Party", "Oldseat", "Old Premier"))
  sup$source_url <- "u"; sup$source_date <- "2001-01-01"; sup$note <- "n"
  sp <- file.path(d, "leaders-supplement.csv")
  data.table::fwrite(sup, sp)
  testthat::local_mocked_bindings(pkg_root = function() root)

  ls <- suppressMessages(leader_seats())
  expect_equal(ls$seat[ls$pair == "xx2001"], "Oldseat")            # (a) supplement fills a missing election
  expect_equal(ls$role[ls$pair == "xx2001"], "gov")
  expect_equal(ls$seat[ls$pair == "xx2010"], "Realseat")           # (b) leaders.csv wins on overlap
  expect_false("Wrongseat" %in% ls$seat)
  expect_output(read_leaders(), "1 rows used for 1 elections")

  # (c) control: with no supplement the extra election is absent, so (a) can only pass through the merge.
  file.remove(sp)
  expect_false("xx2001" %in% leader_seats()$pair)

  # A malformed supplement stops the run rather than being skipped.
  data.table::fwrite(sup[, setdiff(names(sup), "note")], sp)
  expect_error(read_leaders(), "columns differ")
})

test_that("fetch_leaders.R never writes the supplement file", {
  src <- readLines(file.path(pkg_root(), "scripts", "fetch_leaders.R"), warn = FALSE)
  src <- src[!grepl("^[[:space:]]*#", src)]
  expect_false(any(grepl("supplement", src)))
})

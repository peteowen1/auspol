# Parser for the VEC upper-house "Results by Voting Centre" workbooks
# (scripts/fetch_council_results.R, ticket #156). A tiny synthetic sheet in the
# real layout; the broken copies must STOP, so the sum checks are shown to fail
# before they are trusted to pass. Needs scripts/ from a source checkout.

load_council_lib <- function() {
  f <- testthat::test_path("..", "..", "scripts", "fetch_council_results.R")
  testthat::skip_if_not(file.exists(f), "scripts/ not shipped in the check build")
  withr::local_envvar(AUSPOL_COUNCIL_LIB_ONLY = "1", .local_envir = parent.frame())
  e <- new.env(); sys.source(f, envir = e); e
}

# rows: label, stats text, ATL, BTL, Total  (columns 1, 2, 3, 4, 5 as in the real file)
council_sheet <- function(vc2_a_atl = 4) {
  r <- function(l, a = NA, b = NA, t = NA, x = NA) c(l, x, a, b, t)
  rows <- list(
    r("Region Result (Consolidated)"), r("Print Date/Time: 14/12/2022"), r("State Election 2022"),
    r("Test Region (Recheck)"), r(NA),
    r("Alpha District"), r("Enrolment         :    500"), r("Formal Votes    :    28"),
    r("Informal Votes  :    3", x = "9.68% of total votes"), r("Total Votes       :    31"), r(NA),
    r("Booth One - Ordinary", "ATL", "BTL", "Total"),
    r("GROUP A - Alpha Party", 10, 2, 12), r("GROUP B", 3, NA, 3), r("UNGROUPED - SOLO, Sam", NA, 1, 1),
    r("Informal", "---", "---", 2), r(NA, 13, 3, 18),
    r("Booth Two - Ordinary", "ATL", "BTL", "Total"),
    r("GROUP A - Alpha Party", vc2_a_atl, NA, vc2_a_atl), r("GROUP B", 6, 2, 8), r("UNGROUPED - SOLO, Sam", NA, NA, NA),
    r("Informal", "---", "---", 1), r(NA, vc2_a_atl + 6, 2, vc2_a_atl + 9),
    r("Alpha District Total", "ATL", "BTL", "Total"),
    r("GROUP A - Alpha Party", 14, 2, 16), r("GROUP B", 9, 2, 11), r("UNGROUPED - SOLO, Sam", NA, 1, 1),
    r("Informal", "---", "---", 3), r(NA, 23, 5, 31))
  list(do.call(rbind, rows))
}

test_that("a well-formed sheet parses and every sum check holds", {
  e <- load_council_lib()
  p <- e$parse_rbvc(council_sheet(), "2022", "Test")
  d <- p$data
  expect_equal(sort(unique(d$voting_centre)), c("Alpha District Total", "Booth One - Ordinary", "Booth Two - Ordinary"))
  expect_equal(d$total[d$voting_centre == "Booth One - Ordinary" & d$group == "A" & d$row_kind == "group"], 12)
  expect_equal(unique(d$vote_type[d$block_kind == "voting_centre"]), "ordinary")
  expect_equal(p$stats$formal, 28 + 0)       # stated Formal Votes on the page
  expect_true(all(c("atl", "btl", "total", "group_name", "vote_type_raw") %in% names(d)))
})

test_that("a voting centre that does not sum to its block total stops", {
  e <- load_council_lib()
  s <- council_sheet(); m <- s[[1]]
  i <- which(m[, 1] == "GROUP A - Alpha Party")[1]; m[i, 5] <- "13"; m[i, 3] <- "11"   # group row now 11 + 2 != 13
  expect_error(e$parse_rbvc(list(m), "2022", "Test"), "UH4")
})

test_that("voting centres that do not sum to the district block stop", {
  e <- load_council_lib()
  expect_error(e$parse_rbvc(council_sheet(vc2_a_atl = 5), "2022", "Test"), "UH5")   # booth two edited consistently, district block not
})

test_that("the wrong election vintage or region is refused", {
  e <- load_council_lib()
  expect_error(e$parse_rbvc(council_sheet(), "2018", "Test"), "UH2")
  expect_error(e$parse_rbvc(council_sheet(), "2022", "Other"), "UH2")
})

test_that("a non-numeric cell is a failure, not a zero", {
  e <- load_council_lib()
  expect_error(e$tonum(c("12", "1,234", "x9")), "UH1")
  expect_equal(e$tonum(c("12", "1,234", "---", NA)), c(12, 1234, NA, NA))
})

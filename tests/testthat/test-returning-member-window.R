# The by-election window of returning_member_flags(), the winner-name coverage the
# builder stops on, and the default of the AUSPOL_RETURNING_MEMBER_RULE switch.

mk <- function(year, seat, sur, giv, region = "vic")
  data.table::data.table(region = region, year = year, seat = seat, sur = sur, giv = giv)

.ref_dir <- function() {
  for (d in c(file.path("external", "reference", "byelections"),
              file.path("..", "..", "external", "reference", "byelections")))
    if (file.exists(file.path(d, "byelection-winner-names.csv"))) return(d)
  NULL
}

test_that("a by-election is placed by full date, not calendar year", {
  # A by-election in March 2018 comes before the 24 Nov 2018 general election, so
  # it belongs to the PREVIOUS parliament and is not in the 2022 window; one on
  # 1 Dec 2018 is after it and is.
  w <- rbind(mk(2018, "Aseat", "OLD", "Alan"), mk(2018, "Bseat", "OLD", "Bob"))
  c2 <- rbind(mk(2018, "Aseat", "OLD", "Alan"), mk(2022, "Aseat", "EARLY", "Eve"),
              mk(2022, "Bseat", "LATE", "Lou"), mk(2022, "Bseat", "OLD", "Bob"),
              mk(2022, "Aseat", "OLD", "Alan"))
  b <- data.table::data.table(region = "vic", date = as.Date(c("2018-03-10", "2018-12-01")),
                              seat = c("Aseat", "Bseat"), sur = c("EARLY", "LATE"), giv = c("EVE", "LOU"))
  d <- c(vic2018 = as.Date("2018-11-24"), vic2022 = as.Date("2022-11-26"))
  f <- returning_member_flags(c2, w, b, d)
  names(f) <- paste(c2$year, c2$seat, c2$sur)
  expect_false(f[["2022 Aseat EARLY"]])
  expect_true(f[["2022 Aseat OLD"]])
  expect_true(f[["2022 Bseat LATE"]])
  expect_false(f[["2022 Bseat OLD"]])
})

test_that("Lidia Thorpe is the sitting member at vic2018 (Northcote 2017 by-election)", {
  w <- rbind(mk(2014, "Northcote", "RICHARDSON", "Fiona"), mk(2014, "Brunswick", "PULFORD", "Jane"))
  c2 <- rbind(mk(2014, "Northcote", "RICHARDSON", "Fiona"),
              mk(2018, "Northcote", "THORPE", "Lidia"), mk(2018, "Northcote", "RICHARDSON", "Fiona"),
              mk(2018, "Northcote", "THEOPHANOUS", "Kat"))
  b <- data.table::data.table(region = "vic", date = as.Date("2017-11-18"), seat = "Northcote",
                              sur = "THORPE", giv = "LIDIA")
  d <- c(vic2014 = as.Date("2014-11-29"), vic2018 = as.Date("2018-11-24"))
  f <- returning_member_flags(c2, w, b, d)
  names(f) <- paste(c2$year, c2$sur)
  expect_true(f[["2018 THORPE"]])
  expect_false(f[["2018 RICHARDSON"]])
  expect_false(f[["2018 THEOPHANOUS"]])
})

test_that("the tracked name file holds the real Northcote 2017 winner", {
  rd <- .ref_dir()
  skip_if(is.null(rd), "external/reference/byelections not present")
  nm <- data.table::fread(file.path(rd, "byelection-winner-names.csv"), showProgress = FALSE)
  r <- nm[nm$region == "vic" & nm$seat == "Northcote"]
  expect_equal(nrow(r), 1L)
  expect_equal(r$surname, "Thorpe")
  expect_equal(r$given, "Lidia")
})

test_that("a by-election seat with no previous winner row says so loudly", {
  w <- mk(2022, "Other", "SOME", "One")
  c2 <- rbind(mk(2022, "Other", "SOME", "One"), mk(2026, "Narracan", "FARNHAM", "Wayne"))
  b <- data.table::data.table(region = "vic", date = as.Date("2023-01-28"), seat = "Narracan",
                              sur = "FARNHAM", giv = "WAYNE")
  d <- c(vic2022 = as.Date("2022-11-26"), vic2026 = as.Date("2026-11-28"))
  out <- testthat::capture_output(f <- returning_member_flags(c2, w, b, d))
  expect_match(out, "RMF1! vic2026: by-election in Narracan has no vic2022 winner row", fixed = TRUE)
  expect_true(f[2])
})

test_that("a by-election window without winner names is reported", {
  all_b <- data.table::data.table(region = "vic", seat = c("Northcote", "Lyndhurst"),
                                  date = as.Date(c("2017-11-18", "2013-04-27")))
  nm <- data.table::data.table(region = "vic", seat = "Lyndhurst", date = as.Date("2013-04-27"))
  d <- c(vic2010 = as.Date("2010-11-27"), vic2014 = as.Date("2014-11-29"),
         vic2018 = as.Date("2018-11-24"))
  labs <- c("vic2010", "vic2014", "vic2018")
  miss <- missing_byelection_names(labs, all_b, nm, d)
  expect_equal(nrow(miss), 1L)
  expect_equal(miss$seat, "Northcote")
  expect_equal(miss$label, "vic2018")
  nm2 <- rbind(nm, data.table::data.table(region = "vic", seat = "Northcote", date = as.Date("2017-11-18")))
  expect_equal(nrow(missing_byelection_names(labs, all_b, nm2, d)), 0L)
})

test_that("the tracked name file covers every state by-election in every window", {
  rd <- .ref_dir()
  skip_if(is.null(rd), "external/reference/byelections not present")
  nm <- data.table::fread(file.path(rd, "byelection-winner-names.csv"), showProgress = FALSE)
  all_b <- data.table::fread(file.path(rd, "byelection-winners.csv"), showProgress = FALSE)
  all_b <- all_b[all_b$region != "fed"]
  ed <- election_dates()
  labs <- names(ed)[grepl("^(nsw|qld|sa|vic|wa|nt)[0-9]{4}$", names(ed))]
  expect_equal(nrow(missing_byelection_names(labs, all_b, nm, ed)), 0L)
  expect_true(all(nzchar(nm$surname)))
})

test_that("the builder keeps the legacy flag as its default (rule 0)", {
  # BC9 itself needs external/ inputs that CI and worktrees do not have, so it
  # cannot run here. This only guards the two places that set the default.
  root <- if (file.exists("scripts/build_candidacies.R")) "." else file.path("..", "..")
  skip_if(!file.exists(file.path(root, "scripts", "build_candidacies.R")), "scripts/ not present")
  bc <- readLines(file.path(root, "scripts", "build_candidacies.R"), warn = FALSE)
  expect_true(any(grepl('Sys.getenv("AUSPOL_RETURNING_MEMBER_RULE", "0")', bc, fixed = TRUE)))
  pf <- readLines(file.path(root, "scripts", "published_flags.R"), warn = FALSE)
  expect_true(any(grepl('^\\s*AUSPOL_RETURNING_MEMBER_RULE = "0",', pf)))
})

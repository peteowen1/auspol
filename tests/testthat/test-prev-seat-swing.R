# prev_seat_swing() / derived_seat_spread() / harness_seat_spread() --
# the leak fix of 2026-10-16 (R/prev_seat_swing.R). All fixtures are built in a
# temp dir; nothing here reads external/.

# Twelve seats in two regions, all ALP v LNP, plus an ALP-v-IND seat and a seat
# with a missing swing, which must both be dropped.
make_fixture <- function(later_prev_swing = NULL) {
  root <- tempfile("spread-fixture-")
  arch <- file.path(root, "archive")
  anchor <- file.path(root, "anchor")
  dir.create(arch, recursive = TRUE)
  dir.create(file.path(anchor, "analysis", "seats"), recursive = TRUE)
  dir.create(file.path(anchor, "analysis", "Data"), recursive = TRUE)

  seats <- sprintf("Seat %02d", 1:12)
  sw <- c(1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15)      # ALP swing, points
  tcp <- rbind(
    data.frame(election = "nsw2015", seat = seats, party = "ALP", votes = 100, swing = sw),
    data.frame(election = "nsw2015", seat = seats, party = "LNP", votes = 90, swing = -sw),
    # ALP v independent: a TCP swing that is NOT a two-party swing
    data.frame(election = "nsw2015", seat = "Indyland", party = c("ALP", "IND"), votes = c(80, 90), swing = c(40, -40)),
    # ALP v LNP but no swing (no earlier result on the same footing)
    data.frame(election = "nsw2015", seat = "Newseat", party = c("ALP", "LNP"), votes = c(80, 90), swing = NA_real_),
    # a seat that lists LNP twice: not an ALP-v-LNP contest
    data.frame(election = "nsw2015", seat = "Dupe", party = c("LNP", "LNP"), votes = c(80, 90), swing = c(1, -1)))
  utils::write.csv(tcp, file.path(arch, "2015nsw-tcp.csv"), row.names = FALSE)

  block <- function(seat, region, prev) paste0("#", seat, "\nsIncumbent=ALP\nsChallenger=LNP\nsRegion=", region,
                                              "\nfTppMargin=5\nfPreviousTppSwing=", prev)
  region <- rep(c("North", "South"), each = 6)
  # the TARGET-year file (2019) carries prev_swing values that differ wildly
  # from the archive's: derived mode must never see them
  prev19 <- if (is.null(later_prev_swing)) rep(0, 12) else later_prev_swing
  writeLines(unlist(Map(block, toupper(seats), region, prev19)), file.path(anchor, "analysis", "seats", "2019nsw.txt"))
  list(archive = arch, anchor = anchor, sw = sw, region = region)
}

test_that("prev_seat_swing keeps only ALP-v-Coalition seats with a swing and says what it dropped", {
  fx <- make_fixture()
  old <- options(auspol.anchor_dir = fx$anchor); on.exit(options(old))
  ps <- prev_seat_swing("nsw", 2015, label_year = 2019, archive_dir = fx$archive)
  expect_equal(nrow(ps), 12L)
  expect_setequal(ps$seat, sprintf("Seat %02d", 1:12))
  expect_equal(ps$prev_swing[match(sprintf("Seat %02d", 1:12), ps$seat)], fx$sw)   # ALP's row, not LNP's
  expect_false(any(c("Indyland", "Newseat", "Dupe") %in% ps$seat))
  cov <- attr(ps, "coverage")
  expect_equal(unname(cov[c("n_seats", "n_alp_lnp", "n_swing", "n_labelled")]), c(15L, 13L, 12L, 12L))
  # region labels are matched on a normalised name ("Seat 01" vs "SEAT 01")
  expect_equal(ps$seat_region[match("Seat 01", ps$seat)], "North")
  expect_equal(ps$seat_region[match("Seat 12", ps$seat)], "South")
})

test_that("derived_seat_spread equals a hand calculation of within-region SD", {
  fx <- make_fixture()
  old <- options(auspol.anchor_dir = fx$anchor); on.exit(options(old))
  sp <- derived_seat_spread("nsw", 2015, 0, label_year = 2019, archive_dir = fx$archive)
  by <- split(fx$sw, fx$region)
  hand <- sqrt(sum(vapply(by, function(v) sum((v - mean(v))^2), numeric(1))) / 12)
  expect_equal(sp$sd_within, hand)
  expect_equal(sp$n_swing, 12L)
  expect_equal(sp$n_unlabelled, 0L)
})

test_that("the derived spread never reads the target election's anchor file (the leak)", {
  a <- make_fixture(later_prev_swing = rep(0, 12))
  b <- make_fixture(later_prev_swing = c(50, -40, 30, -20, 10, 0, 60, -50, 40, -30, 20, -10))
  oa <- options(auspol.anchor_dir = a$anchor)
  sa <- derived_seat_spread("nsw", 2015, 0, label_year = 2019, archive_dir = a$archive)$sd_within
  options(auspol.anchor_dir = b$anchor)
  sb <- derived_seat_spread("nsw", 2015, 0, label_year = 2019, archive_dir = b$archive)$sd_within
  options(oa)
  expect_identical(sa, sb)
  # and the OLD path does see it: same fixtures, anchor mode, different answers
  options(auspol.anchor_dir = a$anchor)
  utils::capture.output(ya <- harness_seat_spread("nsw", 2015, 2019, 0, src = "anchor")$sd_within)
  options(auspol.anchor_dir = b$anchor)
  utils::capture.output(yb <- harness_seat_spread("nsw", 2015, 2019, 0, src = "anchor")$sd_within)
  options(oa)
  expect_false(isTRUE(all.equal(ya, yb)))
})

test_that("checks FAIL on deliberately broken input", {
  fx <- make_fixture()
  old <- options(auspol.anchor_dir = fx$anchor); on.exit(options(old))
  # no archive file for that election
  expect_error(prev_seat_swing("nsw", 1999, archive_dir = fx$archive), "No archived seat results")
  # archive file without a swing column
  bad <- tempfile("bad-archive-"); dir.create(bad)
  utils::write.csv(data.frame(election = "nsw2015", seat = "A", party = "ALP", votes = 1),
                   file.path(bad, "2015nsw-tcp.csv"), row.names = FALSE)
  expect_error(prev_seat_swing("nsw", 2015, archive_dir = bad), "lacks column")
  # every swing missing: too few seats to measure a spread, so it stops rather than returning NA
  allna <- tempfile("na-archive-"); dir.create(allna)
  d <- data.table::fread(file.path(fx$archive, "2015nsw-tcp.csv")); d$swing <- NA_real_
  utils::write.csv(d, file.path(allna, "2015nsw-tcp.csv"), row.names = FALSE)
  expect_error(derived_seat_spread("nsw", 2015, 0, label_year = 2019, archive_dir = allna), "too few")
  # seats with no region label are dropped and counted, never zero-filled
  d2 <- data.table::fread(file.path(fx$archive, "2015nsw-tcp.csv"))
  d2$seat[d2$seat == "Seat 01"] <- "Renamed Seat"
  nolab <- tempfile("nolab-archive-"); dir.create(nolab)
  utils::write.csv(d2, file.path(nolab, "2015nsw-tcp.csv"), row.names = FALSE)
  sp <- derived_seat_spread("nsw", 2015, 0, label_year = 2019, archive_dir = nolab)
  expect_equal(sp$n_unlabelled, 1L)
  expect_equal(sp$n, 11L)
  # switch value
  withr::with_envvar(c(AUSPOL_SEAT_SPREAD_SRC = "bogus"), expect_error(seat_spread_src(), "must be"))
  withr::with_envvar(c(AUSPOL_SEAT_SPREAD_SRC = NA), expect_identical(seat_spread_src(), "derived"))
})

test_that("real archive: nsw2015 swing for Goulburn is the vote-share swing, and counts are stable", {
  skip_if_not(file.exists(election_data_path("archive/2015nsw-tcp.csv")), "no archive")
  skip_if_not(file.exists(anchor_data_path("", must_exist = FALSE)), "no anchor clone")
  ps <- prev_seat_swing("nsw", 2015, label_year = 2019)
  expect_equal(ps$prev_swing[ps$seat == "Goulburn"], 20.2)
  expect_true(all(is.finite(ps$prev_swing)))
  expect_gt(nrow(ps), 70)
})

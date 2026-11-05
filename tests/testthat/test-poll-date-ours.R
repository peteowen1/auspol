# AUSPOL_POLL_DATE_OURS (shipped "1" 2026-11-05): a poll matched between AE's file and ours takes OUR date, the
# fieldwork midpoint. The case is real: Resolve's Victorian poll fielded 9 Sep-12 Oct 2025, which AE dates 1 Sep.
# The test runs poll_layer() end to end on a one-poll fixture and must fail with the switch off.

fixture_dir <- function() {
  d <- tempfile("pdo"); dir.create(d)
  w <- data.table::data.table(
    row_type = "poll", table_type = "primary", region = "vic", section = "Voting intention > Legislative Assembly",
    date_raw = "9 Sep - 12 Oct 2025", firm_raw = "Resolve Strategic", footnote_raw = "", firm = "Resolve Strategic",
    fieldwork_start = "2025-09-09", fieldwork_end = "2025-10-12",
    alp_fp = 30, lnp_fp = 33, lib_fp = NA_real_, nat_fp = NA_real_, alp_tpp = 51, pv_GRN = "12%", pv_ONP = "")   # published two-party, so the row passes its own check
  data.table::fwrite(w, file.path(d, "statewide_polls_wiki.csv"))
  data.table::fwrite(data.table::data.table(pattern = "resolve", canonical = "resolve", note = ""), file.path(d, "firm_alias.csv"))
  d
}
ae_fixture <- function() {
  ae <- data.table::data.table(date = as.Date("2025-09-01"), firm = "ResolvePM", tpp_published = NA_real_,
                               ALP = 30, LNP = 33, GRN = 12, ONP = NA_real_, OTH = 25)
  # every layered region's AE file has a One Nation column; without one the row self-check returns NA (latent, 5 Nov)
  data.table::setattr(ae, "parties", c("ALP", "LNP", "GRN", "ONP", "OTH"))
  ae
}
layer <- function(switch_value) {
  withr::local_envvar(AUSPOL_POLL_DATE_OURS = switch_value, AUSPOL_POLL_BT = "0", AUSPOL_POLL_ARCHIVE = "0", AUSPOL_POLL_PB = "0")
  suppressMessages(poll_layer(ae_fixture(), "vic", path = file.path(fixture_dir(), "statewide_polls_wiki.csv")))
}

test_that("the matched poll takes our fieldwork midpoint with the switch on, AE's date with it off", {
  on <- layer("1"); off <- layer("0")
  expect_equal(nrow(on), 1L); expect_equal(nrow(off), 1L)        # one poll, matched, not counted twice
  expect_equal(attr(on, "layer_log")$matched, 1L)
  mid <- as.Date("2025-09-09") + (as.integer(as.Date("2025-10-12") - as.Date("2025-09-09")) %/% 2L)
  expect_equal(on$date, mid)                                     # 2025-09-25
  expect_equal(off$date, as.Date("2025-09-01"))                  # AE's date: the behaviour before 5 Nov
  expect_equal(on$firm, "ResolvePM")                             # AE's label is kept either way
  expect_equal(on$ALP, 30)
  expect_identical(attr(on, "provenance")$source, "ours")         # our row was kept, not AE's
})

test_that("the shipped default is on", {
  withr::local_envvar(AUSPOL_POLL_DATE_OURS = NA, AUSPOL_POLL_BT = "0", AUSPOL_POLL_ARCHIVE = "0", AUSPOL_POLL_PB = "0")
  d <- suppressMessages(poll_layer(ae_fixture(), "vic", path = file.path(fixture_dir(), "statewide_polls_wiki.csv")))
  expect_equal(d$date, as.Date("2025-09-25"))
})

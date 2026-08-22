# The one rule in this repo that must never be wrong: a backtest may only use
# data that existed before the election it predicts. CLAUDE.md records three
# leakage bugs, one introduced while fixing another, so these tests exercise
# the filter on a synthetic pool rather than trusting a run to look sensible.

fake_pool <- function(dir, file, elections, seats = 2L) {
  dt <- data.table::CJ(election = elections, seat = paste0("S", seq_len(seats)),
                       round = 1L)
  dt[, `:=`(from = "ONP", to = "LNP", votes = 100)]
  data.table::fwrite(dt, file.path(dir, file))
  dt
}

test_that("only source elections held before the predicted one are admitted", {
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  fake_pool(d, "waec-wa-transfers.csv",
            c("wa1996", "wa2005", "wa2008", "wa2013", "wa2017", "wa2021", "wa2025"))
  base <- data.table::data.table(election = "vic2018", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)

  # Victoria 2018 is November 2018: everything up to 2017 is admissible, 2021
  # and 2025 are not. Getting this backwards is the entire failure mode.
  got <- pool_external_flows(base, "2018-11-24", "wa", quiet = TRUE)
  expect_setequal(setdiff(unique(got$election), "vic2018"),
                  c("wa1996", "wa2005", "wa2008", "wa2013", "wa2017"))

  # WA 2025 was 8 March; the 2025 federal election was 3 May. It is therefore
  # admissible there, which is the boundary most likely to be got wrong.
  got <- pool_external_flows(base, "2025-05-03", "wa", quiet = TRUE)
  expect_true("wa2025" %in% got$election)
})

test_that("an election on the same day as the predicted one is excluded", {
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  fake_pool(d, "waec-wa-transfers.csv", c("wa2025"))
  base <- data.table::data.table(election = "x", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  # Strictly before. A result is not knowable on polling day itself.
  expect_identical(pool_external_flows(base, "2025-03-08", "wa", quiet = TRUE), base)
  expect_true("wa2025" %in%
                pool_external_flows(base, "2025-03-09", "wa", quiet = TRUE)$election)
})

test_that("nothing admissible returns the input untouched", {
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  fake_pool(d, "ecq-qld-transfers.csv", c("qld2020", "qld2024"))
  base <- data.table::data.table(election = "fed2010", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  expect_identical(pool_external_flows(base, "2010-08-21", "qld", quiet = TRUE), base)
})

test_that("an election in the file with no date aborts rather than vanishing", {
  # The failure this guards is silent: an undated election is simply filtered
  # out, leaving a smaller pool that still produces a plausible number.
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  fake_pool(d, "ecq-qld-transfers.csv", c("qld2020", "qld2017"))
  base <- data.table::data.table(election = "x", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  expect_error(pool_external_flows(base, "2026-01-01", "qld", quiet = TRUE),
               "qld2017")
})

test_that("a missing pool names the script that builds it", {
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  base <- data.table::data.table(election = "x", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  expect_error(pool_external_flows(base, "2026-01-01", "wa", quiet = TRUE),
               "fetch_preferences_wa")
  expect_error(pool_external_flows(base, "2026-01-01", "nowhere", quiet = TRUE),
               "Unknown flow source")
})

test_that("every hand-entered date agrees with the year in its own key", {
  # These dates cannot come from either commission's data, so this is the only
  # check standing between a mistyped year and a leak.
  for (s in names(EXTERNAL_FLOWS)) {
    d <- as.Date(EXTERNAL_FLOWS[[s]]$dates)
    expect_false(anyNA(d), info = s)
    expect_equal(unname(format(d, "%Y")),
                 sub("^[a-z]+", "", names(EXTERNAL_FLOWS[[s]]$dates)), info = s)
  }
})

test_that("the cutoff can hold everything out, which is control W1", {
  # WA's earliest election predates every backtest election, so unlike
  # Queensland there is no naturally-empty admission to use as a control. This
  # is the substitute: it tests the filter, not the data.
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  fake_pool(d, "waec-wa-transfers.csv", c("wa1996", "wa2017", "wa2025"))
  base <- data.table::data.table(election = "x", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  expect_identical(
    pool_external_flows(base, "2026-11-28", "wa", not_after = "1990-01-01",
                        quiet = TRUE), base)
  # And with no cutoff the same call admits all three, so the control is not
  # passing merely because nothing was ever going to be added.
  expect_length(setdiff(unique(
    pool_external_flows(base, "2026-11-28", "wa", quiet = TRUE)$election), "x"), 3L)
})

test_that("both sources default off and the env switches them on", {
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  fake_pool(d, "waec-wa-transfers.csv", c("wa2017"))
  fake_pool(d, "ecq-qld-transfers.csv", c("qld2020"))
  base <- data.table::data.table(election = "x", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  withr::local_envvar(AUSPOL_QLD_FLOWS = "", AUSPOL_WA_FLOWS = "",
                      AUSPOL_WA_CUTOFF = "", AUSPOL_QLD_CUTOFF = "")
  expect_identical(pool_configured_flows(base, "2026-11-28", quiet = TRUE), base)

  withr::local_envvar(AUSPOL_WA_FLOWS = "1")
  expect_true("wa2017" %in% pool_configured_flows(base, "2026-11-28", quiet = TRUE)$election)

  withr::local_envvar(AUSPOL_QLD_FLOWS = "1")
  got <- pool_configured_flows(base, "2026-11-28", quiet = TRUE)
  expect_true(all(c("wa2017", "qld2020") %in% got$election))

  # The cutoff is PER SOURCE. Capping WA must hold WA out and leave Queensland
  # alone -- a single shared cutoff removed both, which made the control arm
  # differ from its baseline for a reason that had nothing to do with WA.
  withr::local_envvar(AUSPOL_WA_CUTOFF = "1990-01-01")
  only_qld <- pool_configured_flows(base, "2026-11-28", quiet = TRUE)
  expect_false("wa2017" %in% only_qld$election)
  expect_true("qld2020" %in% only_qld$election)

  withr::local_envvar(AUSPOL_QLD_CUTOFF = "1990-01-01")
  expect_identical(pool_configured_flows(base, "2026-11-28", quiet = TRUE), base)
})

test_that("the three-cornered filter drops only marked seats, and says so", {
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  dt <- data.table::data.table(
    election = "wa2017", seat = c("A", "A", "B", "B"), round = 1L,
    from = "ONP", to = "LNP", votes = 100,
    three_cornered = c(TRUE, TRUE, FALSE, FALSE))
  data.table::fwrite(dt, file.path(d, "waec-wa-transfers.csv"))
  base <- data.table::data.table(election = "vic2022", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  withr::local_envvar(AUSPOL_QLD_FLOWS = "", AUSPOL_WA_FLOWS = "1",
                      AUSPOL_WA_CUTOFF = "", AUSPOL_QLD_CUTOFF = "",
                      AUSPOL_WA_DROP_LNP = "0", AUSPOL_WA_DROP_3C = "1")
  got <- pool_configured_flows(base, "2026-11-28", quiet = TRUE)
  expect_setequal(got[election == "wa2017", seat], "B")
  # The marker belongs to one source only, so it must not survive into a table
  # the flow matrix reads.
  expect_false("three_cornered" %in% names(got))
})

test_that("the three-cornered arm refuses to be a copy of the unfiltered one", {
  # Both failures are silent by nature: the arm would run, score, and differ
  # from its comparator by nothing at all.
  d <- withr::local_tempdir()
  withr::local_options(auspol.elections_dir = d)
  base <- data.table::data.table(election = "vic2022", seat = "X", round = 1L,
                                 from = "GRN", to = "ALP", votes = 5)
  withr::local_envvar(AUSPOL_QLD_FLOWS = "", AUSPOL_WA_FLOWS = "1",
                      AUSPOL_WA_CUTOFF = "", AUSPOL_WA_DROP_LNP = "0",
                      AUSPOL_WA_DROP_3C = "1")

  # No marker column at all -- an old transfers file.
  fake_pool(d, "waec-wa-transfers.csv", c("wa2017"))
  expect_error(pool_configured_flows(base, "2026-11-28", quiet = TRUE),
               "no.*three_cornered marker")

  # Marker present but nothing marked.
  dt <- data.table::data.table(election = "wa2017", seat = "A", round = 1L,
                               from = "ONP", to = "LNP", votes = 100,
                               three_cornered = FALSE)
  data.table::fwrite(dt, file.path(d, "waec-wa-transfers.csv"))
  expect_error(pool_configured_flows(base, "2026-11-28", quiet = TRUE),
               "byte-identical copy")
})

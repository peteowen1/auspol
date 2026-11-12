test_that("a hand-keyed seat poll the scraped file also carries is counted once", {
  d <- file.path(tempdir(), "sphk"); dir.create(d, showWarnings = FALSE); unlink(list.files(d, full.names = TRUE))
  cols <- c("election", "seat", "pollster", "client", "fieldwork_start", "fieldwork_end", "date_raw", "published",
            "sample_n", "party", "fp", "tcp_party_a", "tcp_party_b", "tcp_a", "source_url", "row_type", "seat_name")
  row <- function(seat, pollster, fe, party, fp) {
    x <- stats::setNames(as.list(rep("", length(cols))), cols)
    x[c("election", "seat", "pollster", "fieldwork_end", "date_raw", "sample_n", "party", "fp", "row_type", "seat_name")] <-
      list("vic2026", seat, pollster, fe, fe, "484", party, fp, "poll", seat)
    data.table::as.data.table(x)
  }
  hand <- data.table::rbindlist(list(row("Pakenham", "DemosAU", "2026-11-08", "ONP", "40"),
                                     row("Pakenham", "DemosAU", "2026-11-08", "LNP", "24")))
  hand$source <- "test"
  data.table::fwrite(hand, file.path(d, "hand_keyed_primaries.csv"))
  f <- file.path(d, "seat_polls.csv")
  withr::local_envvar(AUSPOL_SEAT_POLL_HANDKEYED = "1", AUSPOL_SEAT_POLL_CORRECTIONS = "1", AUSPOL_SEAT_POLL_COALITION_DEDUP = "1")

  # not scraped yet: the hand-keyed rows are appended
  data.table::fwrite(row("Hawthorn", "Freshwater", "2025-08-16", "LNP", "41"), f)
  out <- .read_seat_polls_file_impl(f)
  expect_equal(sum(out$seat_name == "Pakenham"), 2L)

  # scraped too, under a longer pollster label and a day's difference in the end date: counted once
  data.table::fwrite(data.table::rbindlist(list(row("Hawthorn", "Freshwater", "2025-08-16", "LNP", "41"),
                                                row("Pakenham", "DemosAU/TKW Research", "2026-11-07", "ONP", "40"),
                                                row("Pakenham", "DemosAU/TKW Research", "2026-11-07", "LNP", "24"))), f)
  expect_output(out <- .read_seat_polls_file_impl(f), "SPHK2!")
  expect_equal(sum(out$seat_name == "Pakenham"), 2L)
  expect_true(all(out$pollster[out$seat_name == "Pakenham"] == "DemosAU/TKW Research"))

  # a different pollster in the same seat and week is a different poll: both kept
  data.table::fwrite(data.table::rbindlist(list(row("Hawthorn", "Freshwater", "2025-08-16", "LNP", "41"),
                                                row("Pakenham", "Redbridge", "2026-11-08", "ONP", "35"))), f)
  out <- .read_seat_polls_file_impl(f)
  expect_equal(sum(out$seat_name == "Pakenham"), 3L)
})

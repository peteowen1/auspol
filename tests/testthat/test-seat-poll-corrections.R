# .seat_poll_apply_corrections(): published figures replace a source page's wrong ones (2026-10-18, Melbourne RedBridge)
test_that("a correction replaces exactly the wrong figure, and one that no longer matches stops the run", {
  d <- withr::local_tempdir()
  data.table::fwrite(data.table::data.table(election = "fed2025", seat_name = "Melbourne", pollster = "P", fieldwork_end = "2024-11-20",
                                            party = c("GRN", "LIB"), fp_wrong = c(27, 44), fp_right = c(44, 21),
                                            source = "test PDF", note = ""), file.path(d, "seat_poll_corrections.csv"))
  s <- data.table::data.table(election = "fed2025", seat_name = "Melbourne", pollster = "P", fieldwork_end = as.Date("2024-11-20"),
                              party = c("GRN", "ALP", "LIB"), fp = c(27, 21, 44), row_type = "poll")
  out <- NULL; utils::capture.output(out <- .seat_poll_apply_corrections(data.table::copy(s), file.path(d, "seat_polls.csv")))
  expect_equal(out$fp, c(44, 21, 21))
  s2 <- data.table::copy(s); s2$fp[1] <- 30   # the scrape changed: the correction must not silently stop applying
  expect_error(utils::capture.output(.seat_poll_apply_corrections(s2, file.path(d, "seat_polls.csv"))), "SPCX!")
  withr::local_envvar(AUSPOL_SEAT_POLL_CORRECTIONS = "0")
  expect_equal(.seat_poll_apply_corrections(data.table::copy(s), file.path(d, "seat_polls.csv"))$fp, s$fp)
})

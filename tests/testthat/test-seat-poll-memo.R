# The seat-poll memo must never serve a result computed under different
# settings or older files: its key holds every AUSPOL_* variable and each
# input file's stamp (R/seat_poll_blend.R, 2026-10-10).
test_that("seat-poll memo key changes with any AUSPOL_* variable and with the arguments", {
  k0 <- .seat_poll_memo_key("vic2022", 90, TRUE, FALSE, FALSE)
  withr::with_envvar(c(AUSPOL_SEAT_POLL_DECAY = "0"), {
    expect_false(identical(k0, .seat_poll_memo_key("vic2022", 90, TRUE, FALSE, FALSE)))
  })
  withr::with_envvar(c(AUSPOL_SOME_SWITCH_ADDED_LATER = "1"), {
    expect_false(identical(k0, .seat_poll_memo_key("vic2022", 90, TRUE, FALSE, FALSE)))
  })
  expect_false(identical(k0, .seat_poll_memo_key("vic2022", 90, FALSE, FALSE, FALSE)))
  expect_false(identical(k0, .seat_poll_memo_key("fed2022", 90, TRUE, FALSE, FALSE)))
  expect_identical(k0, .seat_poll_memo_key("vic2022", 90, TRUE, FALSE, FALSE))
})

test_that("the seat-poll file memo sees a rewritten file and replays printed lines on a hit", {
  withr::local_envvar(AUSPOL_SEAT_POLL_HANDKEYED = "0")
  withr::local_options(auspol.seat_poll_memo = TRUE)
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,2"), f)
  expect_equal(nrow(.read_seat_polls_file(f)), 1L)
  Sys.sleep(1.1)   # a later mtime even on a coarse clock
  writeLines(c("a,b", "1,2", "3,4", "5,6"), f)
  # Before the fix the key stamped only the repo files, so this returned 1 row.
  expect_equal(nrow(.read_seat_polls_file(f)), 3L)
  k <- paste0("memo-test-", as.numeric(Sys.time()))
  n <- 0L
  first <- capture.output(v1 <- .seat_poll_memoised(k, function() { n <<- n + 1L; cat("XX1 computed\n"); data.table::data.table(x = 1) }))
  again <- capture.output(v2 <- .seat_poll_memoised(k, function() { n <<- n + 1L; data.table::data.table(x = 2) }))
  expect_identical(n, 1L)
  expect_identical(first, again)
  expect_identical(v1, v2)
})

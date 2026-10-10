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

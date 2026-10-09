test_that("a seat poll's weight halves every half-life and MRP carries no sampling variance", {
  p <- list(H = 30, floor = c(mrp = 25, direct = 16, sponsored = 36), n_fill = 800)
  pp <- data.table::data.table(fp = c(40, 40, 40, 40, 40), n_seat = c(600, 600, NA, NA, 600),
                               mrp = c(FALSE, FALSE, FALSE, TRUE, FALSE), days = c(0, 30, 0, 0, 0),
                               group = c("direct", "direct", "direct", "mrp", "sponsored"))
  w <- .seat_poll_cell_weights(pp, p)
  expect_equal(w[2] / w[1], 0.5)                                  # 30 days at H = 30
  expect_equal(w[1], 1 / (40 * 60 / 600 + 16))                    # sampling + direct floor
  expect_equal(w[3], 1 / (40 * 60 / 800 + 16))                    # missing n takes n_fill
  expect_equal(w[4], 1 / 25)                                      # MRP: floor only
  expect_true(w[5] < w[1])                                        # sponsored floor is wider here
})

test_that("the decay switches refuse values they do not know", {
  withr::local_envvar(AUSPOL_SEAT_POLL_DECAY = "yes")
  expect_error(.seat_poll_decay_on(), "must be")
  withr::local_envvar(AUSPOL_SEAT_POLL_DECAY = "0", AUSPOL_SEAT_POLL_MRP_NAME = "2")
  expect_error(.seat_poll_mrp_name_on(), "must be")
})

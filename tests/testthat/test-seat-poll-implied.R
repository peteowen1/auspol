test_that("a poll's catch-all Others is compared with the sum of our unnamed classes", {
  # Kennedy 2022: YouGov's MRP names LNP, ALP, GRN and lumps Katter (our
  # OTH_RIGHT) into "OTH"; UAP 6 is also a catch-all here.
  pp <- data.table::data.table(seat = "Kennedy", poll_id = "p1",
                               class = c("LNP", "ALP", "GRN", "REST"),
                               fp = c(27, 17, 7, 49), mrp = TRUE)
  our <- data.table::data.table(seat = "Kennedy",
                                class = c("LNP", "ALP", "GRN", "OTH_RIGHT", "OTH", "ONP"),
                                share = c(23.4, 18.8, 5, 46.3, 4, 2.5))
  v <- seat_poll_implied(pp, our)
  x <- stats::setNames(v$poll, v$class)
  expect_equal(unname(x[c("LNP", "ALP", "GRN")]), c(27, 17, 7))
  # REST 49 split over OTH_RIGHT, OTH, ONP in our proportions: Katter keeps
  # most of it rather than being pulled to UAP's 6.
  expect_equal(unname(x["OTH_RIGHT"]), 49 * 46.3 / (46.3 + 4 + 2.5))
  expect_equal(sum(x), 100)
  # A poll naming ONP keeps ONP out of REST.
  pp2 <- data.table::data.table(seat = "Kennedy", poll_id = "p2",
                                class = c("LNP", "ALP", "GRN", "ONP", "REST"),
                                fp = c(27, 17, 7, 9, 40), mrp = TRUE)
  x2 <- seat_poll_implied(pp2, our)
  expect_equal(x2$poll[x2$class == "ONP"], 9)
  expect_equal(x2$poll[x2$class == "OTH_RIGHT"], 40 * 46.3 / (46.3 + 4))
  # Two polls average per class; n_polls counts both.
  both <- seat_poll_implied(rbind(pp, pp2), our)
  expect_equal(both$n_polls[both$class == "LNP"], 2L)
  expect_equal(both$poll[both$class == "ONP"], (9 + 49 * 2.5 / 52.8) / 2)
})

test_that("an unknown match mode is refused", {
  expect_error(withr::with_envvar(c(AUSPOL_SEAT_POLL_MATCH = "per_poll"),
                                  .seat_poll_cells("fed2025", data.table::data.table())))
})

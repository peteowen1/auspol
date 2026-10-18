# .seat_poll_named_only(): a poll votes only on classes it names fully (prereg amendment 3, 2026-10-18)
test_that("named single-candidate classes vote, the others lump and a part-named pooled class do not", {
  cand <- data.table::data.table(election = "fed2022", seat = "Kennedy",
                                 party = c("OTH_RIGHT", "OTH_RIGHT", "LNP", "ALP", "GRN"))
  s <- data.table::data.table(poll_id = "p1", seat_name = "Kennedy", class = c("LNP", "ALP", "GRN", "OTH_RIGHT", "OTH"),
                              fp = c(27, 17, 7, 6, 43), .bucket = c(FALSE, FALSE, FALSE, FALSE, TRUE))
  out <- NULL; utils::capture.output(out <- .seat_poll_named_only(s, "fed2022", cand))
  expect_setequal(out$class, c("LNP", "ALP", "GRN"))
})
test_that("a pooled class counts as measured when every candidate of it is named", {
  cand <- data.table::data.table(election = "fed2022", seat = "Curtin", party = c("IND", "LNP"))
  s <- data.table::data.table(poll_id = "p1", seat_name = "Curtin", class = c("IND", "LNP", "OTH"),
                              fp = c(32, 38, 4), .bucket = c(FALSE, FALSE, TRUE))
  out <- NULL; utils::capture.output(out <- .seat_poll_named_only(s, "fed2022", cand))
  expect_setequal(out$class, c("IND", "LNP"))
})
test_that("a part-named pooled class is measured when the poll's others is zero", {
  cand <- data.table::data.table(election = "fed2022", seat = "X", party = c("IND", "IND", "LNP"))
  s <- data.table::data.table(poll_id = "p1", seat_name = "X", class = c("IND", "LNP"),
                              fp = c(30, 70), .bucket = c(FALSE, FALSE))
  out <- NULL; utils::capture.output(out <- .seat_poll_named_only(s, "fed2022", cand))
  expect_setequal(out$class, c("IND", "LNP"))
})
test_that("a direct poll's named independent votes though another independent stands; an MRP's does not under IND_DIRECT", {
  withr::local_envvar(AUSPOL_SEAT_POLL_IND_DIRECT = "ind")
  cand <- data.table::data.table(election = "fed2025", seat = "Warringah", party = c("IND", "IND", "LNP"))
  s <- data.table::data.table(poll_id = c("d", "d", "d", "m", "m", "m"), seat_name = "Warringah",
                              class = c("IND", "LNP", "OTH", "IND", "LNP", "OTH"), fp = c(33, 41, 12, 40, 30, 1),
                              .bucket = c(FALSE, FALSE, TRUE, FALSE, FALSE, TRUE), is_mrp = c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE))
  out <- NULL; utils::capture.output(out <- .seat_poll_named_only(s, "fed2025", cand))
  expect_equal(nrow(out[class == "IND"]), 1L)
  expect_equal(out[class == "IND", poll_id], "d")
  expect_setequal(out[poll_id == "m", class], "LNP")
})

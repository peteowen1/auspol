# docs/plans/prereg-reentry-personal-vote-priority-2026-09-08.md

test_that("a cell own_prev has informed is dropped from reentry_cells", {
  rc <- data.frame(seat = c("Kiama", "Traeger"), party = c("IND", "ONP"),
                    value = c(13.1, 79.2), n = c(392, 339), path = c("glm", "glm"))
  op <- data.frame(seat = "Kiama", party = "IND", own_prev_pcv = 15.1,
                    prev_party = "LNP", transfer = 38.0)
  out <- protect_personal_vote_cells(rc, op)
  expect_equal(nrow(out), 1L)
  expect_equal(out$seat, "Traeger")
})

test_that("own_prev's own NA own_prev_pcv rows are not protected", {
  rc <- data.frame(seat = "Kiama", party = "IND", value = 13.1, n = 392, path = "glm")
  op <- data.frame(seat = "Kiama", party = "IND", own_prev_pcv = NA_real_,
                    prev_party = NA_character_, transfer = NA_real_)
  out <- protect_personal_vote_cells(rc, op)
  expect_equal(nrow(out), 1L)
})

test_that("NULL or empty own_prev is a no-op", {
  rc <- data.frame(seat = "Kiama", party = "IND", value = 13.1, n = 392, path = "glm")
  expect_identical(protect_personal_vote_cells(rc, NULL), rc)
  expect_equal(nrow(protect_personal_vote_cells(rc, data.frame())), 1L)
})

test_that("NULL or empty reentry_cells passes through unchanged", {
  op <- data.frame(seat = "Kiama", party = "IND", own_prev_pcv = 15.1,
                    prev_party = "LNP", transfer = 38.0)
  expect_null(protect_personal_vote_cells(NULL, op))
  empty <- data.frame(seat = character(0), party = character(0), value = numeric(0))
  expect_equal(nrow(protect_personal_vote_cells(empty, op)), 0L)
})

test_that("a seat/party not in own_prev is untouched", {
  rc <- data.frame(seat = c("Kiama", "Traeger"), party = c("IND", "ONP"),
                    value = c(13.1, 79.2), n = c(392, 339), path = c("glm", "glm"))
  op <- data.frame(seat = "Traeger", party = "IND", own_prev_pcv = 20,
                    prev_party = "LNP", transfer = 20)  # different party, no match
  out <- protect_personal_vote_cells(rc, op)
  expect_equal(nrow(out), 2L)
})

test_that("flows_tilt_to_estimate moves the ALP share of ALP+LNP to the estimate and nothing else", {
  tx <- data.frame(
    election = "fed2013", seat = "A", round = 2L,
    from = c("GRN", "GRN", "GRN", "ONP", "ONP"),
    to   = c("ALP", "LNP", "ONP", "ALP", "LNP"),
    votes = c(800, 100, 100, 300, 700), stringsAsFactors = FALSE)
  est <- data.table::data.table(party = "GRN", a = 60)
  out <- utils::capture.output(res <- flows_tilt_to_estimate(tx, est))
  g <- res[res$from == "GRN", ]
  # ALP share of (ALP + LNP) is now the estimate's 60%, from 800/900 = 88.9%
  expect_equal(g$votes[g$to == "ALP"] / (g$votes[g$to == "ALP"] + g$votes[g$to == "LNP"]), 0.60)
  # a destination that is neither ALP nor LNP, and a class with no estimate, are untouched
  expect_equal(g$votes[g$to == "ONP"], 100)
  expect_equal(res$votes[res$from == "ONP"], c(300, 700))
  expect_true(any(grepl("88.9% -> estimate  60.0%", out, fixed = TRUE)))
})

test_that("flows_tilt_to_estimate says so, and changes nothing, for a class with no ALP or LNP rows", {
  tx <- data.frame(election = "fed2013", seat = "A", round = 2L, from = "IND", to = "ALP", votes = 50)
  out <- utils::capture.output(res <- flows_tilt_to_estimate(tx, data.table::data.table(party = "IND", a = 30)))
  expect_equal(res$votes, 50)
  expect_true(any(grepl("left unchanged", out)))
})

test_that("state_blend_flows refuses a row that is not strictly before the target (the leak)", {
  f <- tempfile(fileext = ".csv")
  data.table::fwrite(data.frame(
    election = c("qld2012", "qld2015"), party = "GRN", flow_alp = c(54, 70), exhaust = c(28, 16)), f)
  ok <- state_blend_flows("qld2012", target = "qld2015", path = f)
  expect_equal(ok$a, 100 * 54 / (100 - 28))          # conditional on not exhausting
  # the target's own row, and a later row, are refused: broken inputs that must fail
  expect_error(state_blend_flows("qld2015", target = "qld2015", path = f), "LEAK")
  expect_error(state_blend_flows("qld2015", target = "qld2012", path = f), "LEAK")
  expect_error(state_blend_flows("qld2012", target = "qld2015", path = tempfile()), "missing")
})

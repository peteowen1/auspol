test_that("tcp_scenarios keeps a final two of one class (LNP v LNP) as a row", {
  # 4 draws in one seat: 2 ALP v LNP, 2 Liberal v National (both LNP class).
  w <- matrix(c("LNP", "ALP", "LNP", "LNP"), ncol = 1, dimnames = list(NULL, "Seat A"))
  r <- matrix(c("ALP", "LNP", "LNP", "LNP"), ncol = 1, dimnames = list(NULL, "Seat A"))
  s <- matrix(c(0.55, 0.52, 0.60, 0.58), ncol = 1, dimnames = list(NULL, "Seat A"))
  out <- tcp_scenarios(list(tcp_winner = w, tcp_runnerup = r, tcp_share = s))
  expect_equal(nrow(out), 2L)
  expect_equal(sum(out$freq), 1)
  same <- out[out$f1 == "LNP" & out$f2 == "LNP"]
  expect_equal(nrow(same), 1L)
  expect_equal(same$freq, 0.5)
  expect_equal(same$f1_tcp_pct, 59)
  mixed <- out[out$f2 != out$f1]
  expect_setequal(c(mixed$f1, mixed$f2), c("ALP", "LNP"))
})

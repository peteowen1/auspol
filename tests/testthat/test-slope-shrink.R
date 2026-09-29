test_that(".shrunk_slope returns 1 below three elections and keeps a clear slope", {
  set.seed(1)
  mk <- function(p, n, b) { x <- rnorm(n, 0, 5); data.table::data.table(pair = p, dev = x, yy = b * x + rnorm(n, 0, 0.5)) }
  two <- rbind(mk("a", 10, 0.5), mk("b", 10, 0.5))
  expect_equal(auspol:::.shrunk_slope(two, 1), 1)                  # 2 elections: not trusted
  clear <- rbind(mk("a", 30, 0.5), mk("b", 30, 0.5), mk("c", 30, 0.5), mk("d", 30, 0.5))
  s <- auspol:::.shrunk_slope(clear, 1)
  expect_gt(s, 0.45); expect_lt(s, 0.6)                            # a well-measured 0.5 survives
  noisy <- rbind(mk("a", 3, 0.2), mk("b", 3, 1.8), mk("c", 3, 0.9))
  noisy$yy <- noisy$yy + rnorm(9, 0, 20)
  expect_lt(abs(auspol:::.shrunk_slope(noisy, 1) - 1), 0.5)       # noise shrinks toward 1
})

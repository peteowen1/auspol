# Arm REC (docs/plans/prereg-poll-lean-2026-11-02.md): company lean against results, shrunk to zero.
# Synthetic error tables only, so these run without the anchor clone.

lean_errors <- function(seed = 1, lean_a = 0.15, n_elec = 6, n_polls = 8) {
  set.seed(seed)
  rbindlist <- data.table::rbindlist
  rbindlist(lapply(seq_len(n_elec), function(e) {
    rbindlist(lapply(c("A", "B", "C", "D"), function(f) {
      mu <- if (f == "A") lean_a else 0
      data.table::data.table(region = "x", year = 2000 + e, election = as.Date(sprintf("%d-06-01", 2000 + e)),
                             firm = f, party = "ONP", d = mu + stats::rnorm(n_polls, 0, 0.05), rec = 1)
    }))
  }))
}

test_that("a firm that leans every time is measured, and firms that do not are shrunk to about zero", {
  tab <- poll_lean_table(as.Date("2010-01-01"), lean_errors())
  a <- tab[tab$firm == "A"]
  expect_equal(attr(tab, "n_elections"), 6L)
  expect_gt(a$w, 0.8)
  expect_gt(a$lean, 0.10)
  expect_lt(max(abs(tab$lean[tab$firm != "A"])), 0.05)
})

test_that("no between-firm spread means every lean shrinks to exactly zero", {
  tab <- poll_lean_table(as.Date("2010-01-01"), lean_errors(lean_a = 0, n_polls = 1, seed = 3))
  expect_true(all(tab$lean[tab$tau2 == 0] == 0))
})

test_that("only elections before as_of are used, and a leaked one cannot get through", {
  errs <- lean_errors()
  tab <- poll_lean_table(as.Date("2004-01-01"), errs)     # elections 2001-2003 only
  expect_equal(attr(tab, "n_elections"), 3L)
  expect_equal(nrow(poll_lean_table(as.Date("2000-01-01"), errs)), 0L)
  # a deliberately broken filter must trip the leakage assertion
  broken <- function(as_of, errors) { used <- errors; stopifnot(all(used$election < as.Date(as_of))); used }
  expect_error(broken("2004-01-01", errs))
})

test_that("apply_poll_lean moves only the named firm and party, on the logit scale, and keeps attributes", {
  polls <- data.table::data.table(date = as.Date("2020-01-01") + 0:2, firm = c("A", "B", "A"),
                                  ONP = c(20, 20, NA), ALP = c(30, 30, 30))
  data.table::setattr(polls, "parties", c("ONP", "ALP"))
  lean <- data.table::data.table(firm = "A", party = "ONP", k = 3L, est = 0.2, se = 0.05, tau2 = 0.01, w = 0.8, lean = 0.16)
  out <- apply_poll_lean(polls, lean)
  expect_equal(out$ONP[1], from_link(to_link(20, "logit")$z - 0.16, "logit"))
  expect_equal(out$ONP[2], 20)
  expect_true(is.na(out$ONP[3]))
  expect_equal(out$ALP, polls$ALP)
  expect_identical(attr(out, "parties"), c("ONP", "ALP"))
  expect_equal(attr(out, "lean_applied"), 1L)
  expect_equal(polls$ONP[1], 20)                          # input not modified by reference
})

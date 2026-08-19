# seat_sd may now be per-party, because One Nation's seat share is constructed
# rather than measured and should not carry a measured share's certainty. The
# hazard is pairing a party's sd with a different party's column, which would be
# invisible in the output -- so the matching is by NAME and these tests check it.

mk_shares <- function() {
  m <- rbind(A = c(40, 35, 25), B = c(45, 30, 25))
  colnames(m) <- c("ALP", "LNP", "ONP")
  m
}
mk_fm <- function() {
  # The shape build_flow_matrix() returns: a list of named destination vectors,
  # NOT a table. (A first draft built a data.table with a column called `key`,
  # which collides with data.table()'s own key= argument and errors naming your
  # data -- the hazard CLAUDE.md records, walked into while writing a test.)
  list(
    conditional = list(
      "ONP|ALP+LNP" = c(ALP = 0.5, LNP = 0.5),
      "LNP|ALP+ONP" = c(ALP = 0.5, ONP = 0.5),
      "ALP|LNP+ONP" = c(LNP = 0.5, ONP = 0.5)),
    pooled = list(
      ONP = c(ALP = 0.5, LNP = 0.5),
      LNP = c(ALP = 0.5, ONP = 0.5),
      ALP = c(LNP = 0.5, ONP = 0.5)))
}

test_that("a single seat_sd still applies to every party", {
  s <- simulate_seat_contests(mk_shares(), mk_fm(), party_sd = c(ALP = 1, LNP = 1, ONP = 1),
                              seat_sd = 3.5, n_sims = 50, seed = 1)
  expect_true(is.list(s) || is.data.frame(s))
})

test_that("an unnamed multi-value seat_sd is REFUSED", {
  # Positional matching is the trap. Refuse rather than guess.
  expect_error(
    simulate_seat_contests(mk_shares(), mk_fm(),
                           party_sd = c(ALP = 1, LNP = 1, ONP = 1),
                           seat_sd = c(3.5, 3.5, 5.5), n_sims = 10, seed = 1),
    "no names")
})

test_that("a named seat_sd missing a party is REFUSED", {
  expect_error(
    simulate_seat_contests(mk_shares(), mk_fm(),
                           party_sd = c(ALP = 1, LNP = 1, ONP = 1),
                           seat_sd = c(ALP = 3.5, LNP = 3.5), n_sims = 10, seed = 1),
    "missing an entry for: ONP")
})

test_that("a negative or NA seat_sd is REFUSED", {
  expect_error(
    simulate_seat_contests(mk_shares(), mk_fm(),
                           party_sd = c(ALP = 1, LNP = 1, ONP = 1),
                           seat_sd = c(ALP = 3.5, LNP = -1, ONP = 5.5),
                           n_sims = 10, seed = 1),
    "non-negative")
  expect_error(
    simulate_seat_contests(mk_shares(), mk_fm(),
                           party_sd = c(ALP = 1, LNP = 1, ONP = 1),
                           seat_sd = c(ALP = 3.5, LNP = NA, ONP = 5.5),
                           n_sims = 10, seed = 1),
    "non-negative")
})

test_that("a per-party sd is matched by NAME, not by position", {
  # The decisive test. Give ONP a huge sd and everyone else none, supplied in an
  # order that does NOT match the share columns. If matching were positional,
  # the large sd would land on ALP and ONP's outcomes would be identical to the
  # zero-sd case.
  shares <- mk_shares(); fm <- mk_fm()
  psd <- c(ALP = 0, LNP = 0, ONP = 0)
  wide <- simulate_seat_contests(shares, fm, party_sd = psd,
                                 seat_sd = c(ONP = 40, LNP = 0.001, ALP = 0.001),
                                 n_sims = 400, seed = 7)
  tight <- simulate_seat_contests(shares, fm, party_sd = psd,
                                  seat_sd = c(ONP = 0.001, LNP = 0.001, ALP = 0.001),
                                  n_sims = 400, seed = 7)
  # `totals` is a draws-by-party matrix of seats won.
  onp_wide <- mean(wide$totals[, "ONP"])
  onp_tight <- mean(tight$totals[, "ONP"])
  # A 40-point sd on ONP must change how often it wins; a 0.001 sd cannot. If
  # the sds were matched positionally the 40 would land on ALP and these two
  # would be identical.
  expect_false(isTRUE(all.equal(onp_wide, onp_tight)))
})

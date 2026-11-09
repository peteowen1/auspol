# AUSPOL_NEW_IND_LIFT: signal first-timers get an additive lift fitted time-forward on earlier
# PUBLISHED shares (R/new_ind_lift.R). Synthetic data only.

.nl_nm <- function(pre, el, i) paste0(pre, chartr("0123456789", "abcdefghij", paste0(el, i)))
.nl_election <- function(el, n) {
  do.call(rbind, lapply(seq_len(n), function(i) {
    s <- paste0("A", i)
    data.frame(election = el, region = sub("[0-9]{4}$", "", el), seat = s, party = c("ALP", "LNP", "IND"),
               name = paste(toupper(c(.nl_nm("alp", el, i), .nl_nm("lnp", el, i), .nl_nm("ind", el, i))), "Cat"),
               surname = toupper(c(.nl_nm("alp", el, i), .nl_nm("lnp", el, i), .nl_nm("ind", el, i))),
               given = "Cat", votes = c(50, 40, 10), stringsAsFactors = FALSE)
  }))
}

test_that("the lift is the mean published residual of earlier signal cells, and only signal cells move", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1", AUSPOL_NEW_IND_LIFT = "1")
  C <- data.table::as.data.table(rbind(.nl_election("vic2014", 4), .nl_election("vic2018", 4), .nl_election("vic2022", 4)))
  be <- data.frame(region = character(0), date = character(0), candidate = character(0))
  # vic2018: A1, A2 carry a signal (published 6 and 8, actual 10 and 12 -> residual +4 each); A3, A4 none.
  # vic2022 rows are the target's own and must never be read.
  FT <- data.frame(pair = c(rep("vic2018", 4), "vic2022"), seat = c(paste0("A", 1:4), "A1"), party = "IND",
                   actual_share = c(10, 12, 30, 30, 99), base_pred = 5,
                   c200 = c(1, 0, 0, 0, 1), voices = 0, council_elected = c(0, 1, 0, NA, 0), council_mayor = 0)
  PB <- data.frame(pair = c(rep("vic2018", 4), "vic2022"), seat = c(paste0("A", 1:4), "A1"), party = "IND",
                   ours = c(6, 8, 5, 5, 1))
  out <- utils::capture.output(f <- new_ind_lift_fit("vic2022", corpus = C, byelection = be, features = FT,
                                                     published = PB, tau2 = 0))
  expect_equal(f$shift, 4)
  expect_equal(nrow(f$train), 2L)
  expect_true(all(f$train$election == "vic2018"))
  # apply: A1 has a signal at the target, A2 does not
  local_mocked_bindings(endorsement_features = function(keys, tab = NULL) { k <- data.table::copy(data.table::as.data.table(keys))
                          k[, `:=`(c200 = as.numeric(seat == "A1"), voices = 0)]; k },
                        council_features = function(keys, hist = NULL) { k <- data.table::copy(keys)
                          k[, `:=`(council_elected = 0, council_mayor = 0)]; k })
  m <- matrix(c(50, 40, 10, 50, 40, 10), 2, byrow = TRUE, dimnames = list(c("A1", "A2"), c("ALP", "LNP", "IND")))
  run <- function() { r <- NULL; utils::capture.output(r <- new_ind_lift_apply(m, "vic2022", corpus = C, byelection = be,
                                                                               features = FT, published = PB, tau2 = 0)); r }
  r <- run()
  expect_equal(r["A1", "IND"], 14)
  expect_equal(unname(r["A1", c("ALP", "LNP")]), c(50, 40) * 86 / 90)   # others give up share pro rata
  expect_equal(r["A2", ], m["A2", ])
  expect_equal(unname(rowSums(r)), unname(rowSums(m)))
  # a signal cell with no published share is an error, not a silent skip
  expect_error(utils::capture.output(new_ind_lift_fit("vic2022", corpus = C, byelection = be, features = FT,
                                                      published = PB[-1, ], tau2 = 0)), "no published share")
  withr::local_envvar(AUSPOL_NEW_IND_LIFT = "0")
  expect_identical(run(), m)
  withr::local_envvar(AUSPOL_NEW_IND_LIFT = "2")
  expect_error(new_ind_lift_mode(), "must be")
})

test_that("the scorer writes the pre-lift share, and the fit reads it in place of the lifted one", {
  m <- matrix(c(50, 40, 10, 45, 41, 14), 2, byrow = TRUE, dimnames = list(c("A1", "A2"), c("ALP", "LNP", "IND")))
  av <- data.frame(seat = rep(c("A1", "A2"), each = 3), party = rep(c("ALP", "LNP", "IND"), 2), votes = c(50, 40, 10, 45, 40, 15))
  expect_false("pred_share_prelift" %in% names(seat_share_rmse(m, av)$detail))          # lift off: format unchanged
  d <- seat_share_rmse(m, av, prelift = data.frame(seat = "A2", old = 10, new = 14, shift = 4))$detail
  expect_equal(d$pred_share_prelift[d$seat == "A2" & d$party == "IND"], 10)
  expect_equal(d$pred_share_prelift[d$party != "IND" | d$seat != "A2"], d$pred_share[d$party != "IND" | d$seat != "A2"])
  expect_error(seat_share_rmse(m, av, prelift = data.frame(seat = c("A2", "A2"), old = 1)), "twice")
  # reader: ours_prelift wins when the file has it
  root <- withr::local_tempdir()
  writeLines("Package: x", file.path(root, "DESCRIPTION")); dir.create(file.path(root, "output"))
  withr::local_options(auspol.root = root)
  data.table::fwrite(data.frame(pair = "vic2018", seat = "A1", party = "IND", ours = 14, ours_prelift = 10),
                     file.path(root, "output", "published-predictions.csv"))
  expect_equal(auspol:::.nl_read_published()$ours, 10)
  data.table::fwrite(data.frame(pair = "vic2018", seat = "A1", party = "IND", ours = 14),
                     file.path(root, "output", "published-predictions.csv"))
  expect_equal(auspol:::.nl_read_published()$ours, 14)
})

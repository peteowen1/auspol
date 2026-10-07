# AUSPOL_NEW_IND_SHRINK: the base share of a nameless first-time sole
# independent is multiplied by a factor fitted time-forward. Synthetic data
# only; real-data checks live in the review notes.

# match_key() keeps letters only, so a name with digits would collapse; spell them as letters
.ni_nm <- function(pre, el, i) paste0(pre, chartr("0123456789", "abcdefghij", paste0(el, i)))

.ni_row <- function(el, seat, party, sur, giv, votes) {
  data.frame(election = el, region = sub("[0-9]{4}$", "", el), seat = seat, party = party,
             name = paste(toupper(sur), giv), surname = toupper(sur), given = giv, votes = votes,
             stringsAsFactors = FALSE)
}

# One election: n seats A1..An, each ALP 50 / LNP 40 / one brand-new IND of `ind` votes.
.ni_election <- function(el, n, ind = 10) {
  do.call(rbind, lapply(seq_len(n), function(i) {
    s <- paste0("A", i)
    rbind(.ni_row(el, s, "ALP", .ni_nm("alp", el, i), "Ann", 50),
          .ni_row(el, s, "LNP", .ni_nm("lnp", el, i), "Bob", 40),
          .ni_row(el, s, "IND", .ni_nm("ind", el, i), "Cat", ind))
  }))
}

test_that("the cell set excludes returning, cross-seat, defector, by-election, multiple and departed-leader independents", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1")
  C <- rbind(
    .ni_election("vic2018", 7, ind = 2),
    # vic2022 target: the seven seats
    .ni_row("vic2022", "A1", "IND", "fresh", "Dan", 5),        # in
    .ni_row("vic2022", "A2", "IND", .ni_nm("ind", "vic2018", 1), "Cat", 5),   # 2018's A1 independent, now in A2: cross-seat
    .ni_row("vic2022", "A3", "IND", .ni_nm("ind", "vic2018", 3), "Cat", 5),   # same person, same seat
    .ni_row("vic2022", "A4", "IND", "newa", "Eve", 5),
    .ni_row("vic2022", "A4", "IND", "newb", "Fay", 5),          # two new INDs: out
    .ni_row("vic2022", "A5", "IND", "bye", "Gus", 5),           # by-election candidate: out
    .ni_row("vic2022", "A6", "IND", .ni_nm("alp", "vic2018", 6), "Ann", 5),   # was the ALP candidate: out
    .ni_row("vic2022", "A7", "IND", "fresh2", "Hal", 5))
  C <- data.table::as.data.table(C)
  # departed leader: raise A7's class share at vic2018 above the statewide + 10
  C$votes[C$election == "vic2018" & C$seat == "A7" & C$party == "IND"] <- 60
  be <- data.frame(region = "vic", date = "2020-05-01", candidate = "Gus Bye")
  out <- utils::capture.output(cl <- new_ind_cells("vic2022", corpus = C, byelection = be))
  expect_setequal(cl$seat, c("A1"))
  cnt <- attr(cl, "counts")
  expect_equal(unname(cnt[["single"]]), 6L)   # A4 has two
  expect_equal(unname(cnt[["returning"]]), 3L)   # A2 (cross-seat), A3, A6
  expect_equal(unname(cnt[["byelection"]]), 1L)
  expect_equal(unname(cnt[["prior"]]), 1L)
  expect_true(any(grepl("1 of 6 single-IND", out)))   # the count is printed per target
})

test_that("only elections strictly before the target are read, and tau2 = 0 gives the pooled factor", {
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "1")
  C <- data.table::as.data.table(rbind(
    .ni_election("fed2016", 6), .ni_election("fed2019", 6),
    .ni_election("vic2014", 6), .ni_election("vic2018", 6), .ni_election("vic2022", 6)))
  mk <- function(pair, base, act) {
    # actuals jitter around `act` (summing to 6 * act) so every SE is above zero
    do.call(rbind, lapply(1:6, function(i) data.frame(pair = pair, seat = paste0("A", i), party = "IND",
                                                      actual_share = act + c(-1, 1, -2, 2, -0.5, 0.5)[i],
                                                      base_pred = base)))
  }
  FT <- rbind(mk("fed2019", 10, 5),    # fed k = 0.5
              mk("vic2018", 10, 8),    # vic k = 0.8
              mk("vic2022", 10, 1))    # the TARGET's own rows: must not be read
  out <- utils::capture.output(fit <- new_ind_fit("vic2022", corpus = C, byelection = data.frame(region = character(0), date = character(0), candidate = character(0)),
                                                  features = FT, tau2 = 0))
  expect_true(all(fit$train$election < "vic2022"))
  expect_false("vic2022" %in% fit$train$election)
  pooled <- sum(fit$train$a) / sum(fit$train$b)
  expect_equal(pooled, 0.65, tolerance = 1e-9)            # (30 + 48) / (60 + 60)
  expect_equal(fit$factor, pooled)                        # complete pooling: Victoria gets the pooled k
  expect_true(all(fit$table$w == 0))
  # an estimated tau2 moves the Victorian factor toward its own k (0.8) but never above 1
  out2 <- utils::capture.output(fit2 <- new_ind_fit("vic2022", corpus = C, features = FT, tau2 = 1e6,
                                                    byelection = data.frame(region = character(0), date = character(0), candidate = character(0))))
  expect_equal(fit2$factor, 0.8, tolerance = 1e-3)
  expect_lte(fit2$factor, 1)
  # a target dated before the poisoned rows never sees them either
  out3 <- utils::capture.output(fit3 <- new_ind_fit("vic2018", corpus = C, features = FT, tau2 = 0,
                                                    byelection = data.frame(region = character(0), date = character(0), candidate = character(0))))
  expect_false(any(c("vic2018", "vic2022") %in% fit3$train$election))
})

test_that("apply scales the cell, keeps row totals and rescales the other classes pro rata", {
  withr::local_envvar(AUSPOL_NEW_IND_SHRINK = "1", AUSPOL_TIME_FORWARD_FITS = "1")
  C <- data.table::as.data.table(rbind(.ni_election("vic2014", 3), .ni_election("vic2018", 3), .ni_election("vic2022", 3)))
  FT <- do.call(rbind, lapply(1:3, function(i) data.frame(pair = "vic2018", seat = paste0("A", i), party = "IND",
                                                          actual_share = 4, base_pred = 8)))
  be <- data.frame(region = character(0), date = character(0), candidate = character(0))
  m <- matrix(c(50, 40, 10,   46, 40, 14,   100, 0, 0), 3, byrow = TRUE,
              dimnames = list(c("A1", "A2", "A3"), c("ALP", "LNP", "IND")))
  out <- utils::capture.output(r <- new_ind_shrink_apply(m, "vic2022", corpus = C, byelection = be, features = FT, tau2 = 0))
  f <- 0.5
  expect_equal(r["A1", "IND"], f * 10)
  expect_equal(r["A2", "IND"], f * 14)
  expect_equal(unname(rowSums(r)), unname(rowSums(m)))
  expect_equal(r["A1", "ALP"] / r["A1", "LNP"], 50 / 40)       # others stay proportional
  expect_identical(r["A3", ], m["A3", ])                        # no IND share: untouched
  expect_equal(nrow(attr(r, "new_ind")), 2L)
})

test_that("switch 0 returns the matrix itself without reading anything", {
  withr::local_envvar(AUSPOL_NEW_IND_SHRINK = "0")
  m <- matrix(c(50, 40, 10), 1, dimnames = list("A1", c("ALP", "LNP", "IND")))
  expect_identical(new_ind_shrink_apply(m, "vic2022", corpus = stop("must not be touched")), m)
  withr::local_envvar(AUSPOL_NEW_IND_SHRINK = NA)
  expect_identical(new_ind_mode(), "1")   # the shipped value
  withr::local_envvar(AUSPOL_NEW_IND_SHRINK = "")
  expect_identical(new_ind_mode(), "1")   # the shipped value
  withr::local_envvar(AUSPOL_NEW_IND_SHRINK = "yes")
  expect_error(new_ind_mode(), "must be")
})

test_that("post_xgb_switches lists every active post-xgb switch", {
  withr::local_envvar(AUSPOL_REENTRY = "0", AUSPOL_NEW_IND_SHRINK = "0", AUSPOL_DEPARTED_SUCCESSOR = "0")
  expect_length(post_xgb_switches(), 0L)
  withr::local_envvar(AUSPOL_NEW_IND_SHRINK = "1")
  expect_identical(names(post_xgb_switches()), "AUSPOL_NEW_IND_SHRINK")
  withr::local_envvar(AUSPOL_REENTRY = "majors")
  expect_setequal(names(post_xgb_switches()), c("AUSPOL_REENTRY", "AUSPOL_NEW_IND_SHRINK"))
  # The successor rate is post-xgb too: stage 1 must never train the trees on it.
  withr::local_envvar(AUSPOL_DEPARTED_SUCCESSOR = "1")
  expect_true("AUSPOL_DEPARTED_SUCCESSOR" %in% names(post_xgb_switches()))
})

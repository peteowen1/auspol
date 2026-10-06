# AUSPOL_DEFECTOR_STATE (R/defector_state.R): no min_n cliff, cross-seat person match,
# old seat's class gives up the carried vote. Default OFF; switch-0 behaviour is pinned here
# and, on the real corpus, by scratch dry runs recorded in the PR notes.

with_env <- function(vars, code) {
  nms <- names(vars)
  old <- vapply(nms, function(n) Sys.getenv(n, unset = NA_character_), "")
  do.call(Sys.setenv, as.list(vars))
  on.exit({
    for (i in seq_along(nms)) {
      if (is.na(old[[i]])) Sys.unsetenv(nms[i]) else do.call(Sys.setenv, stats::setNames(list(old[[i]]), nms[i]))
    }
  })
  force(code)
}

mk_case <- function(prev_el, el, seat, sur, giv, prior, now, was_mp = TRUE, party_prev = "LNP", party_now = "IND", state = NA_character_) {
  data.table::data.table(
    election = c(prev_el, el), seat = seat, party = c(party_prev, party_now),
    surname = sur, given = giv, pcv = c(prior, now), elected = c(was_mp, FALSE),
    name = NA_character_, state = state)
}

# four STATE cases at ratio 0.5 (earlier pair wa2005 -> wa2008), nothing else
four_state <- function(ratio = 0.5) {
  data.table::rbindlist(lapply(seq_len(4), function(i)
    mk_case("wa2005", "wa2008", paste0("seat", i), paste0("SUR", i), "Alan", 50, 50 * ratio)))
}

test_that("OFF: n = 4 is below the min_n cliff and returns no rate (pins the old behaviour)", {
  with_env(c(AUSPOL_DEFECTOR_STATE = "0"), {
    r <- fit_defector_discount("wa2013", corpus = four_state(),
                               pairs = list(list(election = "wa2008", prev = "wa2005")))
    expect_null(r$discount)
    expect_null(r$discount_mp)
    expect_equal(r$n, 4L)
  })
})

test_that("ON: n = 4 gives a shrunk rate, not NULL; weight is n/(n+3)", {
  with_env(c(AUSPOL_DEFECTOR_STATE = "1"), {
    # 4 state cases at 0.6 plus 4 FEDERAL cases at 0.2: pooled median 0.4, state median 0.6
    d <- data.table::rbindlist(c(
      lapply(1:4, function(i) mk_case("wa2005", "wa2008", paste0("s", i), paste0("ST", i), "Alan", 50, 30)),
      lapply(1:4, function(i) mk_case("fed2007", "fed2010", paste0("f", i), paste0("FD", i), "Alan", 50, 10, state = "wa"))))
    prs <- list(list(election = "wa2008", prev = "wa2005"), list(election = "fed2010", prev = "fed2007"))
    r <- fit_defector_discount("wa2013", corpus = d, pairs = prs)
    expect_equal(r$n, 8L)
    expect_equal(r$defector_state$n_level, 4L)
    expect_equal(r$defector_state$n_pooled, 8L)
    expect_equal(r$defector_state$w, 4 / 7)
    expect_equal(r$discount_mp, 0.4 + 4 / 7 * (0.6 - 0.4))
    # and a FEDERAL target reads the federal level
    rf <- fit_defector_discount("fed2013", corpus = d, pairs = prs)
    expect_equal(rf$defector_state$level, "fed")
    expect_equal(rf$defector_state$n_level, 4L)
    expect_equal(rf$discount_mp, 0.4 + 4 / 7 * (0.2 - 0.4))
  })
})

test_that("ON: no cases at the target level gives the pooled rate; no cases at all stays NULL", {
  with_env(c(AUSPOL_DEFECTOR_STATE = "1"), {
    d <- data.table::rbindlist(lapply(1:3, function(i)
      mk_case("fed2007", "fed2010", paste0("f", i), paste0("FD", i), "Alan", 50, 10, state = "wa")))
    prs <- list(list(election = "fed2010", prev = "fed2007"))
    r <- fit_defector_discount("wa2013", corpus = d, pairs = prs)   # state target, federal evidence only
    expect_equal(r$defector_state$n_level, 0L)
    expect_equal(r$defector_state$w, 0)
    expect_equal(r$discount_mp, 0.2)
    # nothing earlier than the target: NULL, no constant invented (Pilbara wa2001)
    r0 <- fit_defector_discount("wa2001", corpus = d, pairs = prs)
    expect_null(r0$discount)
    expect_equal(r0$n, 0L)
  })
})

test_that("ON: time-forward -- a case dated at or after the target never enters the rate", {
  with_env(c(AUSPOL_DEFECTOR_STATE = "1"), {
    early <- four_state(0.5)
    late <- mk_case("wa2008", "wa2013", "late", "LATE", "Alan", 50, 45)   # ratio 0.9, AT the target
    d <- data.table::rbindlist(list(early, late))
    prs <- list(list(election = "wa2008", prev = "wa2005"), list(election = "wa2013", prev = "wa2008"))
    r <- fit_defector_discount("wa2013", corpus = d, pairs = prs)
    expect_equal(r$n, 4L)
    expect_equal(r$discount_mp, 0.5)
  })
})

cross_corpus <- function(prev_given = "John", now_given = "John", prev_state = NA, now_state = NA,
                         el_prev = "wa2005", el = "wa2008", extra = NULL) {
  p <- data.table::data.table(
    election = el_prev, seat = c("OldSeat", "Other"), party = c("ALP", "LNP"),
    surname = c("BOWLER", "ZZ"), given = c(prev_given, "Q"), pcv = c(50, 60), elected = TRUE,
    name = NA_character_, state = prev_state)
  n <- data.table::data.table(
    election = el, seat = c("NewSeat", "OldSeat", "Other"), party = c("IND", "ALP", "LNP"),
    surname = c("BOWLER", "NEWALP", "ZZ"), given = c(now_given, "Pat", "Q"), pcv = c(30, 45, 58), elected = FALSE,
    name = NA_character_, state = now_state)
  data.table::rbindlist(c(list(p, n), extra), fill = TRUE)
}

quiet_ppv <- function(...) { out <- NULL; res <- NULL; out <- utils::capture.output(res <- personal_prior_vote(...)); res }
cross_env <- c(AUSPOL_DEFECT_POOLED = "0", AUSPOL_CROSS_SEAT_VOTE = "0", AUSPOL_BYELEC_LEVEL = "0",
               AUSPOL_MINOR_DEFECT_CONSERVE = "0", AUSPOL_DEFECT_CONSERVE = "1")

test_that("ON: a sitting member of another seat who stands IND here is carried, and the old seat's class gives it up", {
  with_env(c(cross_env, AUSPOL_DEFECTOR_STATE = "1"), {
    d <- cross_corpus()
    r <- quiet_ppv("wa2005", "wa2008", corpus = d, major_discount = 0.5)
    ind <- r[seat == "NewSeat" & party == "IND"]
    expect_equal(ind$own_prev_pcv, 25)               # 50 x 0.5, class base 0
    expect_equal(ind$own_prev_source, "cross_seat")
    expect_true(is.na(ind$prev_party) && is.na(ind$transfer))   # nothing taken from NewSeat's own old class
    # OldSeat is contested at the target; the carried vote leaves its ALP class
    rm1 <- r[seat == "OldSeat" & party == "IND"]
    expect_equal(nrow(rm1), 1L)
    expect_equal(rm1$prev_party, "ALP")
    expect_equal(rm1$transfer, 25)
    expect_true(is.na(rm1$own_prev_pcv))
    m <- matrix(c(40, 40, 0, 0), nrow = 2,dimnames = list(c("NewSeat", "OldSeat"), c("ALP", "IND")))
    m2 <- remove_transferred_votes(m, r)
    expect_equal(m2["OldSeat", "ALP"], 15)           # 40 - 25
    expect_equal(m2["NewSeat", "ALP"], 40)           # untouched
    # the credit RAISES a class, it never replaces a stronger one
    expect_equal(own_prev_substitute(r, "IND", c("NewSeat", "OldSeat"), c(10, 7)), c(25, 7))
    expect_equal(own_prev_substitute(r, "IND", "NewSeat", 31), 31)
  })
})

test_that("OFF: the same planted case is not matched (switch-0 identity for the new path)", {
  with_env(c(cross_env, AUSPOL_DEFECTOR_STATE = "0"), {
    r <- quiet_ppv("wa2005", "wa2008", corpus = cross_corpus(), major_discount = 0.5)
    expect_true(is.na(r[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
    expect_false("own_prev_source" %in% names(r))
    expect_equal(nrow(r[seat == "OldSeat" & party == "IND"]), 0L)
  })
})

test_that("ON: ambiguous or different people are refused, and the refusal is logged", {
  with_env(c(cross_env, AUSPOL_DEFECTOR_STATE = "1"), {
    # different first name (Brad v Bruce): same surname, first two letters agree
    r1 <- quiet_ppv("wa2005", "wa2008", corpus = cross_corpus(prev_given = "Bruce", now_given = "Brad"), major_discount = 0.5)
    expect_true(is.na(r1[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
    lg <- utils::capture.output(personal_prior_vote("wa2005", "wa2008", corpus = cross_corpus(prev_given = "Bruce", now_given = "Brad"), major_discount = 0.5))
    expect_true(any(grepl("DFS2!.*given names differ", lg)))
    # a second sitting major candidate with the same name in another seat at the previous election
    dup <- data.table::data.table(election = "wa2005", seat = "ThirdSeat", party = "LNP", surname = "BOWLER",
                                  given = "John", pcv = 40, elected = TRUE, name = NA_character_, state = NA_character_)
    r2 <- quiet_ppv("wa2005", "wa2008", corpus = cross_corpus(extra = list(dup)), major_discount = 0.5)
    expect_true(is.na(r2[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
    # a person who also stands for a major party in the target election
    other <- data.table::data.table(election = "wa2008", seat = "ThirdSeat", party = "LNP", surname = "BOWLER",
                                    given = "John", pcv = 10, elected = FALSE, name = NA_character_, state = NA_character_)
    r3 <- quiet_ppv("wa2005", "wa2008", corpus = cross_corpus(extra = list(other)), major_discount = 0.5)
    expect_true(is.na(r3[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
    # a losing (not sitting) major candidate is never carried across seats
    nm <- cross_corpus(); nm[election == "wa2005" & surname == "BOWLER", elected := FALSE]
    r4 <- quiet_ppv("wa2005", "wa2008", corpus = nm, major_discount = 0.5)
    expect_true(is.na(r4[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
  })
})

test_that("ON: a federal match must stay in one state", {
  with_env(c(cross_env, AUSPOL_DEFECTOR_STATE = "1"), {
    same <- cross_corpus(prev_state = "wa", now_state = "wa", el_prev = "fed2016", el = "fed2019")
    diff <- cross_corpus(prev_state = "wa", now_state = "vic", el_prev = "fed2016", el = "fed2019")
    expect_equal(quiet_ppv("fed2016", "fed2019", corpus = same, major_discount = 0.5)[seat == "NewSeat" & party == "IND"]$own_prev_pcv, 25)
    expect_true(is.na(quiet_ppv("fed2016", "fed2019", corpus = diff, major_discount = 0.5)[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
    nost <- cross_corpus(prev_state = NA, now_state = NA, el_prev = "fed2016", el = "fed2019")
    expect_true(is.na(quiet_ppv("fed2016", "fed2019", corpus = nost, major_discount = 0.5)[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
  })
})

test_that("ON: a bare surname (no given name) matches only when the surname is unique across every candidate", {
  with_env(c(cross_env, AUSPOL_DEFECTOR_STATE = "1"), {
    ok <- cross_corpus(prev_given = "", now_given = "")
    expect_equal(quiet_ppv("wa2005", "wa2008", corpus = ok, major_discount = 0.5)[seat == "NewSeat" & party == "IND"]$own_prev_pcv, 25)
    namesake <- data.table::data.table(election = "wa2005", seat = "ThirdSeat", party = "GRN", surname = "BOWLER",
                                       given = "", pcv = 3, elected = FALSE, name = NA_character_, state = NA_character_)
    expect_true(is.na(quiet_ppv("wa2005", "wa2008", corpus = cross_corpus(prev_given = "", now_given = "", extra = list(namesake)),
                                major_discount = 0.5)[seat == "NewSeat" & party == "IND"]$own_prev_pcv))
  })
})

test_that("ON: cross-seat cases also enter the carry fit, under the same guards", {
  with_env(c(AUSPOL_DEFECTOR_STATE = "1"), {
    d <- cross_corpus()
    prs <- list(list(election = "wa2008", prev = "wa2005"))
    r <- fit_defector_discount("wa2013", corpus = d, pairs = prs)
    expect_equal(r$n, 1L)
    expect_equal(r$discount_mp, 30 / 50)
    bad <- cross_corpus(prev_given = "Bruce", now_given = "Brad")
    expect_equal(fit_defector_discount("wa2013", corpus = bad, pairs = prs)$n, 0L)
  })
})

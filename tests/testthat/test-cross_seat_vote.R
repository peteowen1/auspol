# AUSPOL_CROSS_SEAT_VOTE: a personal vote earned in another seat / jurisdiction is credited,
# a namesake, another state, a major-party vote and a LATER result are not.
# R/cross_seat_vote.R, docs/reviews/cross-seat-personal-vote-2026-10-05.md.

cs_corpus <- function() {
  r <- function(e, seat, given, sur, party, pcv, state = NA_character_, el = FALSE)
    data.frame(election = e, seat = seat, name = paste(given, toupper(sur)), surname = toupper(sur), given = given,
               party = party, pcv = pcv, state = state, elected = el, stringsAsFactors = FALSE)
  maj <- function(e, seats, st = NA_character_) do.call(rbind, lapply(seats, function(s)
    rbind(r(e, s, "Al", paste0("Alp", s), "ALP", 45, st), r(e, s, "Lee", paste0("Lnp", s), "LNP", 40, st))))
  rbind(
    maj("nsw2015", c("S1", "S2")), maj("nsw2019", c("S1", "S2")),
    maj("nsw2023", c("S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "S11", "S12")),
    maj("fed2016", c("F1", "F2", "FV"), "NSW")[1:4, ], maj("fed2025", "F9", "NSW"),
    r("nsw2015", "S1", "Sam", "Roe", "IND", 20),
    r("nsw2019", "S1", "Sam", "Roe", "IND", 20),            # same-seat returner: ratio 1
    r("fed2016", "F2", "Pat", "Lee", "IND", 20, "NSW"),     # earned in a federal NSW seat
    r("nsw2019", "S2", "Pat", "Lee", "IND", 10),            # cross case for the carry fit: 10 / 20
    r("fed2016", "F1", "Jane", "Smith", "IND", 30, "NSW"),  # the credited person
    r("fed2016", "FV", "Kim", "Voss", "IND", 30, "VIC"),    # earned in Victoria
    r("fed2016", "F1", "Max", "Orr", "ALP", 40, "NSW"),     # a major-party vote
    r("fed2025", "F9", "Rae", "King", "IND", 40, "NSW"),    # LATER than nsw2023
    r("nsw2023", "S3", "Jane", "Smith", "IND", 25),
    r("nsw2023", "S4", "Jack", "Smith", "IND", 3),          # namesake: Jack is not Jane
    r("nsw2023", "S5", "Kim", "Voss", "IND", 4),            # Victorian record, NSW target
    r("nsw2023", "S6", "Max", "Orr", "IND", 5),             # prior was ALP
    r("nsw2023", "S7", "Rae", "King", "IND", 6),            # only a later result exists
    r("nsw2023", "S8", "Pat", "Lee", "IND", 2),             # a second real cross-seat person
    r("fed2016", "F3", "Dana", "Boyd", "IND", 30, "NSW"),   # an unambiguous independent
    r("nsw2023", "S9", "Dana", "Boyd", "IND", 25),
    r("fed2016", "F10", "Dean", "Boyd", "ONP", 2, "NSW"),   # irrelevant namesake: party-label prior only, so Dana is still credited
    r("fed2016", "F6", "Jack", "Smith", "IND", 12, "NSW"),  # a namesake WITH a personal prior: Jane Smith becomes ambiguous
    r("fed2016", "F7", "Jim", "Cole", "IND", 30, "NSW"),    # matched only through the Jim/James fold ...
    r("fed2016", "F8", "Joe", "Cole", "ONP", 1, "NSW"),     # ... and a different-first-name namesake exists
    r("nsw2023", "S12", "James", "Cole", "IND", 5),
    r("fed2016", "F4", "Ona", "Party", "ONP", 30, "NSW"),   # a party-label share as a NON-member
    r("nsw2023", "S10", "Ona", "Party", "ONP", 3),
    r("fed2016", "F5", "Sid", "Hill", "OTH_RIGHT", 30, "NSW", el = TRUE),   # a non-major SITTING MEMBER
    r("nsw2023", "S11", "Sid", "Hill", "OTH_RIGHT", 4))
}

own <- function(res, seat, party = "IND") res$own_prev_pcv[res$seat == seat & res$party == party]

test_that("switch OFF credits nobody; the unset variable means ON (shipped 2026-10-06)", {
  C <- cs_corpus()
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "0")
  off <- suppressMessages(utils::capture.output(a <- personal_prior_vote("nsw2019", "nsw2023", corpus = C)))
  expect_true(all(is.na(a$own_prev_pcv)))
  expect_false(any(grepl("CSV1", off)))
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "1")
  utils::capture.output(on <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = NA)
  utils::capture.output(b <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  expect_identical(on, b)
})

test_that("a candidate who won 30% as IND in a federal NSW seat is credited carry x 30 in a state seat", {
  C <- cs_corpus()
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "1")
  lg <- utils::capture.output(res <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  car <- fit_cross_seat_carry("nsw2023", corpus = C)
  expect_equal(car$n, 1L)                       # the single earlier cross-seat case (Pat Lee)
  expect_equal(car$r_cross, 0.5); expect_equal(car$r_same, 1)
  expect_equal(car$w, 0)                        # one case has no standard error: all weight on the same-seat ratio
  expect_equal(own(res, "S9"), car$carry * 30)   # Dana Boyd
  expect_equal(own(res, "S8"), car$carry * 20)  # Pat Lee's best prior (20, fed2016), credited again at nsw2023
  expect_true(any(grepl("CSV1 nsw2019 -> nsw2023", lg)) && any(grepl("dana boyd", lg)))
  # the credited row leaves the other columns alone
  expect_true(is.na(res$prev_party[res$seat == "S3" & res$party == "IND"]) && is.na(res$transfer[res$seat == "S3" & res$party == "IND"]))
})

test_that("a namesake, another state, a major-party vote and a later result are NOT credited (same run as the credit)", {
  C <- cs_corpus()
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "1")
  utils::capture.output(res <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  expect_true(own(res, "S9") > 0)                # control: the check CAN fire on this corpus
  expect_true(is.na(own(res, "S4")))             # Jack SMITH is not Jane SMITH (same surname, same initial)
  expect_true(is.na(own(res, "S3")))             # and Jane is REFUSED too: the person match is ambiguous
  expect_equal(nrow(auspol:::.cs_env$refused), 3L)   # Jane and Jack Smith (each is the other's namesake with a personal prior) and James Cole (fold + namesake)
  expect_true(is.na(own(res, "S12")))
  expect_true(is.na(own(res, "S5")))             # Kim VOSS earned it in Victoria
  expect_true(is.na(own(res, "S6")))             # Max ORR's 40 was an ALP vote
  expect_true(is.na(own(res, "S7")))             # Rae KING's 40 comes AFTER nsw2023
  expect_true(is.na(own(res, "S10", "ONP")))     # a party-label (non-member) 30 stays with the party
  expect_equal(own(res, "S11", "OTH_RIGHT"), auspol::fit_cross_seat_carry("nsw2023", corpus = C)$carry * 30)   # a non-major sitting member's 30 follows them
})

test_that("a later result never changes the carry fitted for an earlier target", {
  C <- cs_corpus()
  a <- fit_cross_seat_carry("nsw2023", corpus = C)
  later <- C[C$election == "fed2025", ]
  later$name <- "Pat LEE"; later$surname <- "LEE"; later$given <- "Pat"; later$party <- "IND"; later$pcv <- 1; later$state <- "NSW"
  b <- fit_cross_seat_carry("nsw2023", corpus = rbind(C, later))
  expect_identical(a$carry, b$carry); expect_identical(a$n, b$n)
})

test_that("the given-name rule: prefixes and nickname folds match, different first names and initials do not", {
  ok <- auspol:::.cs_given_ok
  expect_true(ok("rob", "robert")); expect_true(ok("alex", "alexander")); expect_true(ok("jim", "james"))
  expect_false(ok("kate", "katherine"))   # refused on purpose: not a prefix, so the cross-seat rule never guesses
  expect_false(ok("jack", "jane")); expect_false(ok("trevor", "tony")); expect_false(ok("j", "john")); expect_false(ok("", "john"))
})

test_that("an unknown state refuses the match (fed row without a state)", {
  C <- cs_corpus()
  C$state[C$election == "fed2016"] <- NA_character_
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "1")
  utils::capture.output(res <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  expect_true(is.na(own(res, "S3")))
})

# ---- never lower a class -----------------------------------------------------
test_that("own_prev_substitute: a cross-seat credit can only RAISE the class base; a same-seat value replaces it", {
  op <- data.table::data.table(seat = c("A", "B", "C", "D"), party = "IND",
                               own_prev_pcv = c(21.9, 21.9, 10, 7),
                               own_prev_source = c("cross_seat", "cross_seat", NA, "cross_seat"))
  x <- c(A = 25.0, B = 5.0, C = 30, D = NA, E = 12)
  r <- own_prev_substitute(op, "IND", names(x), x)
  expect_equal(unname(r), c(25.0, 21.9, 10, 7, 12))   # A not lowered; B raised; C same-seat replaces (as before); D NA base takes the credit
  expect_equal(own_prev_substitute(NULL, "IND", names(x), x), x)
  expect_equal(own_prev_substitute(op, "GRN", names(x), x), x)
  # without the source column (switch off) it is the old wholesale replacement, even downward
  op2 <- op[, !"own_prev_source"]
  expect_equal(unname(own_prev_substitute(op2, "IND", names(x), x))[1:2], c(21.9, 21.9))
})

test_that("a cross-seat credit is marked own_prev_source = cross_seat; the column is absent with the switch off", {
  C <- cs_corpus()
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "0", AUSPOL_CROSS_SEAT_CACHE_DIR = withr::local_tempdir())
  utils::capture.output(off <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  expect_false("own_prev_source" %in% names(off))
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "1")
  utils::capture.output(on <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  expect_equal(on$own_prev_source[on$seat == "S9" & on$party == "IND"], "cross_seat")
  expect_true(all(is.na(on$own_prev_source[is.na(on$own_prev_pcv)])))
})

# ---- memoisation ------------------------------------------------------------
test_that("the carry cache: a hit returns the identical result, and changing the corpus invalidates it", {
  clear_cross_seat_cache()
  d <- withr::local_tempdir()
  withr::local_envvar(AUSPOL_CROSS_SEAT_CACHE_DIR = d, AUSPOL_CROSS_SEAT_VOTE = "1")
  C <- cs_corpus()
  nf <- function() length(list.files(d, pattern = "\\.rds$"))
  a <- auspol:::.cs_carry_cached("nsw2023", C)
  expect_identical(nf(), 1L)
  expect_identical(auspol:::.cs_carry_cached("nsw2023", C), a)        # session hit
  clear_cross_seat_cache()
  expect_identical(auspol:::.cs_carry_cached("nsw2023", C), a)        # disk hit in a "new session"
  expect_identical(nf(), 1L)                                          # nothing recomputed or rewritten
  expect_equal(a, fit_cross_seat_carry("nsw2023", corpus = C))        # cached == uncached
  # a different corpus (one earlier result changed) is a new key and a new fit
  C2 <- C; C2$pcv[C2$election == "fed2016" & C2$surname == "LEE" & C2$party == "IND"] <- 40
  b <- auspol:::.cs_carry_cached("nsw2023", C2)
  expect_identical(nf(), 2L)
  expect_false(isTRUE(all.equal(a$cases$prior, b$cases$prior)))
  # a different target election and a different AUSPOL_ switch are different keys too
  auspol:::.cs_carry_cached("nsw2019", C)
  expect_identical(nf(), 3L)
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "0")
  auspol:::.cs_carry_cached("nsw2023", C)
  expect_identical(nf(), 4L)
})

test_that("a corrupt cache file is recomputed, not trusted", {
  clear_cross_seat_cache()
  d <- withr::local_tempdir()
  withr::local_envvar(AUSPOL_CROSS_SEAT_CACHE_DIR = d)
  C <- cs_corpus()
  a <- auspol:::.cs_carry_cached("nsw2023", C)
  f <- list.files(d, full.names = TRUE, pattern = "\\.rds$"); writeLines("garbage", f)
  clear_cross_seat_cache()
  expect_equal(auspol:::.cs_carry_cached("nsw2023", C), a)
})

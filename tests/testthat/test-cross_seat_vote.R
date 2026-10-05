# AUSPOL_CROSS_SEAT_VOTE: a personal vote earned in another seat / jurisdiction is credited,
# a namesake, another state, a major-party vote and a LATER result are not.
# R/cross_seat_vote.R, docs/reviews/cross-seat-personal-vote-2026-10-05.md.

cs_corpus <- function() {
  r <- function(e, seat, given, sur, party, pcv, state = NA_character_)
    data.frame(election = e, seat = seat, name = paste(given, toupper(sur)), surname = toupper(sur), given = given,
               party = party, pcv = pcv, state = state, elected = FALSE, stringsAsFactors = FALSE)
  maj <- function(e, seats, st = NA_character_) do.call(rbind, lapply(seats, function(s)
    rbind(r(e, s, "Al", paste0("Alp", s), "ALP", 45, st), r(e, s, "Lee", paste0("Lnp", s), "LNP", 40, st))))
  rbind(
    maj("nsw2015", c("S1", "S2")), maj("nsw2019", c("S1", "S2")),
    maj("nsw2023", c("S3", "S4", "S5", "S6", "S7", "S8")),
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
    r("nsw2023", "S8", "Pat", "Lee", "IND", 2))             # a second real cross-seat person
}

own <- function(res, seat, party = "IND") res$own_prev_pcv[res$seat == seat & res$party == party]

test_that("switch OFF (the default) credits nobody and matches the unset variable", {
  C <- cs_corpus()
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "0")
  off <- suppressMessages(utils::capture.output(a <- personal_prior_vote("nsw2019", "nsw2023", corpus = C)))
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = NA)
  utils::capture.output(b <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  expect_identical(a, b)
  expect_true(all(is.na(a$own_prev_pcv)))
  expect_false(any(grepl("CSV1", off)))
})

test_that("a candidate who won 30% as IND in a federal NSW seat is credited carry x 30 in a state seat", {
  C <- cs_corpus()
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "1")
  lg <- utils::capture.output(res <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  car <- fit_cross_seat_carry("nsw2023", corpus = C)
  expect_equal(car$n, 1L)                       # the single earlier cross-seat case (Pat Lee)
  expect_equal(car$r_cross, 0.5); expect_equal(car$r_same, 1)
  expect_equal(car$w, 0)                        # one case has no standard error: all weight on the same-seat ratio
  expect_equal(own(res, "S3"), car$carry * 30)
  expect_equal(own(res, "S8"), car$carry * 20)  # Pat Lee's best prior (20, fed2016), credited again at nsw2023
  expect_true(any(grepl("CSV1 nsw2019 -> nsw2023", lg)) && any(grepl("Jane Smith|jane smith", lg)))
  # the credited row leaves the other columns alone
  expect_true(is.na(res$prev_party[res$seat == "S3" & res$party == "IND"]) && is.na(res$transfer[res$seat == "S3" & res$party == "IND"]))
})

test_that("a namesake, another state, a major-party vote and a later result are NOT credited (same run as the credit)", {
  C <- cs_corpus()
  withr::local_envvar(AUSPOL_CROSS_SEAT_VOTE = "1")
  utils::capture.output(res <- personal_prior_vote("nsw2019", "nsw2023", corpus = C))
  expect_true(own(res, "S3") > 0)                # control: the check CAN fire on this corpus
  expect_true(is.na(own(res, "S4")))             # Jack SMITH is not Jane SMITH (same surname, same initial)
  expect_true(is.na(own(res, "S5")))             # Kim VOSS earned it in Victoria
  expect_true(is.na(own(res, "S6")))             # Max ORR's 40 was an ALP vote
  expect_true(is.na(own(res, "S7")))             # Rae KING's 40 comes AFTER nsw2023
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

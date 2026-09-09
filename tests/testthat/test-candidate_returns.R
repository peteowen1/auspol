mk <- function() data.table::data.table(
  election = c(rep("e1", 4), rep("e2", 5)),
  seat  = c("A", "A", "B", "B",  "A", "A", "B", "B", "C"),
  party = c("IND", "ALP", "IND", "ALP",  "IND", "ALP", "IND", "ALP", "IND"),
  surname = c("SMITH", "JONES", "BROWN", "LEE",
              "SMITH", "JONES", "TAYLOR", "LEE", "NEW"),
  given = c("Jane", "Bob", "Ann", "Kim",  "Jane", "Bob", "Ray", "Kim", "Zoe"),
  name = NA_character_)

test_that("a returning candidate is found and a replacement is not", {
  r <- candidate_returns("e1", "e2", mk())
  expect_true(r[seat == "A" & party == "IND"]$same)   # Jane Smith, both
  expect_false(r[seat == "B" & party == "IND"]$same)  # Brown -> Taylor
})

test_that("a seat with no prior election of that class reads FALSE, not NA", {
  # There is nobody to return, which is the correct reading and must not be
  # missing -- an NA would propagate into a slope and silently produce NA shares.
  r <- candidate_returns("e1", "e2", mk())
  expect_false(r[seat == "C" & party == "IND"]$same)
  expect_false(anyNA(r$same))
})

test_that("every seat/class at the target election is present", {
  r <- candidate_returns("e1", "e2", mk())
  expect_equal(nrow(r), 5L)
})

test_that("a candidate switching PARTY in the same seat still counts as returning", {
  # Philip Donato held Orange with 49.1% as a Shooter in 2019 and 53.1% as an
  # independent in 2023. Matching within (seat, party) made a five-year sitting
  # member read as a NEW independent -- and as the only failure of the salience
  # screen in an election where it otherwise had none.
  d <- mk()
  d[election == "e2" & seat == "A" & party == "IND", `:=`(surname = "JONES", given = "Bob")]
  r <- candidate_returns("e1", "e2", d)
  expect_true(r[seat == "A" & party == "IND"]$same)   # Bob Jones stood in A as ALP at e1
})

test_that("a DIFFERENT person in the same seat is still new", {
  d <- mk()
  d[election == "e2" & seat == "A" & party == "IND", `:=`(surname = "NOBODY", given = "Zed")]
  r <- candidate_returns("e1", "e2", d)
  expect_false(r[seat == "A" & party == "IND"]$same)
})

test_that("a missing corpus column is an error rather than a silent FALSE", {
  expect_error(candidate_returns("e1", "e2", data.table::data.table(x = 1)), "lacks")
})

test_that("an unknown election label is an error, not an empty result", {
  expect_error(candidate_returns("nope", "e2", mk()), "no rows for election nope")
})

test_that("seat names are matched across differing conventions", {
  # The corpus stores vic2018 as "albertpark" and vic2022 as "Albert Park".
  # An exact join matched ZERO of 508 seat-classes and read as "nobody
  # re-stands in Victoria", which is false and would make arm C a silent no-op
  # in the live target state.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = c("albertpark", "Albert Park"),
    party = "IND", surname = "SMITH", given = "Jane", name = NA_character_)
  r <- candidate_returns("e1", "e2", d)
  expect_true(r$same)
  expect_equal(r$seat, "Albert Park")   # the TARGET election's spelling
})

test_that("leading_candidate_returns follows the TOP candidate, not any candidate", {
  # A minor candidate matches a prior name; the actual front-runner is new.
  # Class-level candidate_returns() would say TRUE; the leader-level fact is
  # what a slope should key on.
  d <- data.table::data.table(
    election = c(rep("e1", 2), rep("e2", 2)),
    seat = "A", party = "IND",
    surname = c("MINOR", "OTHER", "FRONTRUNNER", "MINOR"),
    given = c("Pat", "Sam", "Alex", "Pat"),
    pcv = c(3, 20, 40, 2), name = NA_character_)
  cr <- candidate_returns("e1", "e2", d)
  expect_true(cr[seat == "A" & party == "IND"]$same)   # class-level: TRUE (Pat Minor matches)
  lr <- leading_candidate_returns("e1", "e2", d)
  expect_false(lr[seat == "A" & party == "IND"]$leader_same)  # leader Frontrunner is new
})

test_that("leading_candidate_returns matches candidate_returns when there is one candidate", {
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "A", party = "IND",
    surname = "SMITH", given = "Jane", pcv = c(30, 32), name = NA_character_)
  expect_equal(leading_candidate_returns("e1", "e2", d)$leader_same,
               candidate_returns("e1", "e2", d)$same)
})

test_that("leading_candidate_returns is robust to the seat-naming mismatch that broke a debug script", {
  # vic2018 stores "mildura" lower-case, vic2022 "Mildura" -- the fault
  # candidate_returns() already normalises. An ad-hoc verification script that
  # skipped this normalisation produced a false misattribution for Ali Cupper,
  # who genuinely stood in both elections.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = c("mildura", "Mildura"), party = "IND",
    surname = "CUPPER", given = "Ali", pcv = c(32.7, 33.9), name = NA_character_)
  expect_true(leading_candidate_returns("e1", "e2", d)$leader_same)
})

test_that("personal_prior_vote recovers a party-switcher's own history, not the class's", {
  # Philip Donato held Orange with 49.1% as a Shooter (OTH_RIGHT) in 2019 and
  # 53.1% as an independent in 2023. The seat's IND-class prior vote in 2019
  # is 0% -- nobody was registered IND there -- so a slope applied to that
  # class-level base still projects him near zero even though
  # candidate_returns() correctly flags him as the same person. This is what
  # makes the base itself carry his real 49.1%.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "Orange", party = c("OTH_RIGHT", "IND"),
    surname = "DONATO", given = "Philip", pcv = c(49.1, 53.1), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d)
  expect_equal(r[seat == "Orange" & party == "IND"]$own_prev_pcv, 49.1)
})

test_that("personal_prior_vote excludes a prior MAJOR-party registration", {
  # Nick McBride won MacKillop as LNP with 62.3% in 2022, then re-contested as
  # IND in 2026 and got only 14.8% -- his LNP-era vote was mostly the party
  # machine, not personal support, and using it as the base badly
  # overestimated him (measured: SA backtest log loss got WORSE, 0.6541 ->
  # 0.7392, after this function first shipped without the exclusion). Gareth
  # Ward (LNP 53.6% -> IND 38.8%, still won) is the counter-case this
  # deliberately gives up, for lack of a way to tell the two apart from two
  # examples.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "MacKillop", party = c("LNP", "IND"),
    surname = "MCBRIDE", given = "Nick", pcv = c(62.3, 14.8), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d)
  expect_true(is.na(r[seat == "MacKillop" & party == "IND"]$own_prev_pcv))
})

test_that("personal_prior_vote is NA for a genuinely new candidate", {
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "A", party = "IND",
    surname = c("OLD", "NEW"), given = c("Sam", "Zoe"), pcv = c(10, 15), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d)
  expect_true(is.na(r[seat == "A" & party == "IND"]$own_prev_pcv))
})

test_that("personal_prior_vote follows the LEADING candidate, not any candidate in the class", {
  # KNOWN LIMITATION, not an oversight -- see the long comment above `lead`
  # in personal_prior_vote() itself, dated 2026-09-09. A "sum every matched
  # returner" version was tried and reverted the same day: it measurably
  # WORSENED fed2019/fed2025 pooled log loss, because the far more common
  # real shape is a class with several PRIOR candidates where only one
  # returns (Rankin/OTH_RIGHT fed2016->2019, three candidates, one returns) --
  # summing there REPLACES the class's true prior total with just the
  # returner's own share, discarding the other candidates' real prior vote.
  # Frontrunner (the leader at e2) never stood at e1 -- Minor did, but Minor
  # is not the leader, so this must read NA, not Minor's 3%.
  d <- data.table::data.table(
    election = c(rep("e1", 2), rep("e2", 2)),
    seat = "A", party = "IND",
    surname = c("MINOR", "OTHER", "FRONTRUNNER", "MINOR"),
    given = c("Pat", "Sam", "Alex", "Pat"),
    pcv = c(3, 20, 40, 2), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d)
  expect_true(is.na(r[seat == "A" & party == "IND"]$own_prev_pcv))
})

test_that("personal_prior_vote is NA, not an error, when the leader is not on the prior ballot at all", {
  # Michael Regan won Wakehurst in a 2021 by-election, so he was never a
  # nsw2019 candidate. There is genuinely no prior-election history to
  # recover here -- a separate, undocumented-by-this-fix problem -- and this
  # must read NA rather than 0 or crash.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = c("A", "Wakehurst"), party = "IND",
    surname = c("OTHER", "REGAN"), given = c("Sam", "Michael"),
    pcv = c(10, 35.9), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d)
  expect_true(is.na(r[seat == "Wakehurst" & party == "IND"]$own_prev_pcv))
})

test_that("candidate_returns matches a person across a genuine seat rename", {
  # Andrew Wilkie held Denison (2016, 44.1%) continuously into its 2019
  # rename to Clark (50.0%). Found 2026-09-04 building a candidate-
  # performance feature: normalise_seat() alone doesn't equate "denison" and
  # "clark", so he read as a brand-new IND candidate -- the same fault
  # governed_population() (R/salience_screen.R) was fixed for the same day,
  # not carried into this sibling function until now.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = c("Denison", "Clark"), party = "IND",
    surname = "WILKIE", given = "Andrew", pcv = c(44.1, 50.0), name = NA_character_)
  r <- candidate_returns("e1", "e2", d)
  expect_true(r[seat == "Clark" & party == "IND"]$same)
})

test_that("personal_prior_vote follows a person's own vote across a genuine seat rename", {
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = c("Denison", "Clark"), party = "IND",
    surname = "WILKIE", given = "Andrew", pcv = c(44.1, 50.0), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d)
  expect_equal(r[seat == "Clark" & party == "IND"]$own_prev_pcv, 44.1)
})

test_that("candidate_returns and personal_prior_vote are unaffected by a rename that HASN'T happened yet", {
  # A pair entirely BEFORE Denison -> Clark took effect (both elections still
  # call it Denison). An unconditional rename of PREVT's seat key would map
  # "denison" to "clark" here too, failing to match NOWT's own still-
  # "denison" spelling -- the exact bug governed_population() had before its
  # 2026-09-04 fix, reproduced here and fixed the same way: match against
  # BOTH spellings, never rename unconditionally.
  d <- data.table::data.table(
    election = c("e0", "e1"), seat = "Denison", party = "IND",
    surname = "WILKIE", given = "Andrew", pcv = c(21.3, 38.1), name = NA_character_)
  ret <- candidate_returns("e0", "e1", d)
  expect_true(ret[seat == "Denison" & party == "IND"]$same)
  ppv <- personal_prior_vote("e0", "e1", d)
  expect_equal(ppv[seat == "Denison" & party == "IND"]$own_prev_pcv, 21.3)
})

test_that("major_discount gives a SITTING member's defection a personal-vote floor", {
  # Gareth Ward's shape: LNP MP, wins, defects to IND next time. No test
  # exercised major_discount at all before 2026-09-09 despite it being a
  # published-default-active mechanism.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "Kiama", party = c("LNP", "IND"),
    surname = "WARD", given = "Gareth", pcv = c(53.6, 38.8),
    elected = c(TRUE, FALSE), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d, major_discount = 0.282)
  expect_equal(r[seat == "Kiama" & party == "IND"]$own_prev_pcv, 53.6 * 0.282)
  expect_equal(r[seat == "Kiama" & party == "IND"]$prev_party, "LNP")
})

test_that("major_discount gives a LOSING member's defection NOTHING -- deliberate, not a gap", {
  # Same defection shape, but Ward LOST in e1 (elected = FALSE). Checked
  # 2026-09-09: the non-member analogue of this discount has 5 corpus cases,
  # mean retention 2.32, sd 4.38 -- unusable, so this stays a documented
  # exclusion rather than a fitted number. candidate_returns() still reports
  # the identity match correctly; only the vote FLOOR is withheld.
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "Kiama", party = c("LNP", "IND"),
    surname = "WARD", given = "Gareth", pcv = c(53.6, 38.8),
    elected = c(FALSE, FALSE), name = NA_character_)
  r <- personal_prior_vote("e1", "e2", d, major_discount = 0.282)
  expect_true(is.na(r[seat == "Kiama" & party == "IND"]$own_prev_pcv))
  same <- candidate_returns("e1", "e2", d)
  expect_true(same[seat == "Kiama" & party == "IND"]$same)
})

test_that("prior_leader_returns says whether last time's leading candidate is back, under any label", {
  d <- mk()
  d[, pcv := c(40, 35, 30, 45,  38, 36, 20, 44, 5)]
  r <- candidate_returns("e1", "e2", d)
  expect_true(r[seat == "A" & party == "IND"]$prior_leader_returns)    # Jane Smith stood again
  expect_false(r[seat == "B" & party == "IND"]$prior_leader_returns)   # Ann Brown departed; Taylor is new
  expect_true(r[seat == "C" & party == "IND"]$prior_leader_returns)    # no prior candidate: nothing departed
  # A prior leader who returns under ANOTHER label still counts as returning.
  d2 <- mk(); d2[, pcv := c(40, 35, 30, 45,  38, 36, 20, 44, 5)]
  d2[election == "e2" & seat == "B" & party == "IND", `:=`(surname = "BROWN", given = "Ann")]
  d2[election == "e2" & seat == "B" & party == "IND", party := "OTH_RIGHT"]
  r2 <- candidate_returns("e1", "e2", d2)
  expect_true(r2[seat == "B" & party == "OTH_RIGHT"]$prior_leader_returns)
  # Without pcv there is no way to name a leader: TRUE everywhere (old behaviour).
  r3 <- candidate_returns("e1", "e2", mk())
  expect_true(all(r3$prior_leader_returns))
})

test_that("personal_prior_vote names the class the vote came from and how much moves", {
  # Bob Jones stood as ALP (a major) at e1 -- excluded -- so make him a
  # minor-party switcher: ONP at e1, IND at e2, 21.6% of the seat.
  d <- mk()
  d[, pcv := c(40, 21.6, 30, 45,  38, 36, 20, 44, 5)]
  d[election == "e1" & seat == "A" & surname == "JONES", party := "ONP"]
  d[election == "e2" & seat == "A" & party == "IND", `:=`(surname = "JONES", given = "Bob")]
  r <- personal_prior_vote("e1", "e2", d)
  x <- r[seat == "A" & party == "IND"]
  expect_equal(x$own_prev_pcv, 21.6)
  expect_equal(x$prev_party, "ONP")
  expect_equal(x$transfer, 21.6)
  # A candidate returning under the SAME label moves nothing.
  y <- personal_prior_vote("e1", "e2", mk()[, pcv := c(40, 35, 30, 45, 38, 36, 20, 44, 5)])
  expect_true(is.na(y[seat == "A" & party == "IND"]$transfer))
  expect_true(is.na(y[seat == "A" & party == "IND"]$prev_party))
})

test_that("remove_transferred_votes takes the moved vote out of the old class, once, floored at zero", {
  mat <- matrix(c(30, 21.6, 2, 46.4,   50, 0, 5, 45), nrow = 2, byrow = TRUE,
                dimnames = list(c("A", "B"), c("ALP", "ONP", "IND", "LNP")))
  op <- data.table::data.table(seat = c("A", "B"), party = c("IND", "IND"),
                               own_prev_pcv = c(21.6, NA), prev_party = c("ONP", NA), transfer = c(21.6, NA))
  out <- remove_transferred_votes(mat, op)
  expect_equal(unname(out["A", "ONP"]), 0)
  expect_equal(unname(out["A", "IND"]), 2)        # substitution is the caller's job, not this function's
  expect_equal(out["B", ], mat["B", ])            # nothing moved in B
  expect_identical(remove_transferred_votes(mat, NULL), mat)
  # Larger than what the class held: floored, not negative.
  op2 <- data.table::data.table(seat = "A", party = "IND", own_prev_pcv = 30, prev_party = "ONP", transfer = 30)
  expect_equal(unname(remove_transferred_votes(mat, op2)["A", "ONP"]), 0)
  # Coverage travels with the result: applied and skipped are counted and named.
  tr <- attr(out, "transfers"); expect_equal(tr$applied, 1L); expect_length(tr$skipped, 0)
  op3 <- data.table::data.table(seat = c("A", "Ghost"), party = "IND", own_prev_pcv = 5, prev_party = c("ONP", "ONP"), transfer = 5)
  tr3 <- attr(remove_transferred_votes(mat, op3), "transfers")
  expect_equal(tr3$applied, 1L); expect_equal(tr3$skipped, "Ghost/ONP")
})

test_that("fit_defector_discount excludes the target election's own cases", {
  # Two defector cases in e1->e2 (ratio 0.5) and one in e3->e4 (ratio 0.8).
  # Fitting with e2 as the target must use only the e3->e4 case.
  d <- data.table::data.table(
    election = c("e1", "e2", "e1", "e2", "e3", "e4"),
    seat = c("A", "A", "B", "B", "C", "C"),
    party = c("LNP", "IND", "ALP", "OTH_RIGHT", "NAT", "IND"),
    surname = c("ONE", "ONE", "TWO", "TWO", "THREE", "THREE"),
    given = c("X", "X", "Y", "Y", "Z", "Z"),
    pcv = c(50, 25, 40, 20, 60, 48),
    elected = c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE),
    name = NA_character_)
  synthetic_pairs <- list(list(election = "e2", prev = "e1"),
                           list(election = "e4", prev = "e3"))
  r <- fit_defector_discount("e2", corpus = d, min_n = 1L, pairs = synthetic_pairs)
  expect_equal(r$n, 1L)
  expect_equal(r$discount, 0.8)
})

test_that("fit_defector_discount refuses below min_n", {
  d <- data.table::data.table(
    election = c("e1", "e2"), seat = "A", party = c("LNP", "IND"),
    surname = "ONE", given = "X", pcv = c(50, 25),
    elected = c(TRUE, FALSE), name = NA_character_)
  synthetic_pairs <- list(list(election = "e2", prev = "e1"))
  r <- fit_defector_discount("zzz", corpus = d, min_n = 5L, pairs = synthetic_pairs)
  expect_null(r$discount)
  expect_equal(r$n, 1L)
})

test_that("fit_defector_discount pooled mode includes LOSING defectors, default excludes them", {
  # docs/plans/prereg-defector-pooling-2026-09-09.md. Default keeps the
  # sitting-member-only rate; pooled adds the losing candidates the corpus
  # has 12 of, whose median retention is about half a member's.
  mk <- function(el0, el1, seat, prior, now, was_mp) data.table::data.table(
    election = c(el0, el1), seat = seat, party = c("LNP", "IND"),
    surname = toupper(seat), given = "A", pcv = c(prior, now),
    elected = c(was_mp, FALSE), name = NA_character_)
  d <- data.table::rbindlist(list(
    mk("e1","e2","alpha", 50, 15, TRUE),  mk("e1","e2","bravo", 40, 12, TRUE),
    mk("e1","e2","charlie", 60, 18, TRUE), mk("e1","e2","delta", 45, 13, TRUE),
    mk("e1","e2","echo",  30,  9, TRUE),
    mk("e1","e2","foxtrot", 40,  2, FALSE), mk("e1","e2","golf", 35, 2, FALSE)))
  prs <- list(list(election = "e2", prev = "e1"))
  base <- fit_defector_discount("zzz", corpus = d, pairs = prs, min_n = 1L, pooled = FALSE)
  pool <- fit_defector_discount("zzz", corpus = d, pairs = prs, min_n = 1L, pooled = TRUE)
  expect_equal(base$n, 5L)                 # members only
  expect_equal(pool$n, 7L)                 # members + losers
  # The rate is a MEDIAN, so two low losers among seven do not move it. That is
  # the point of using a median, and it is why the real corpus (12 losers in 29)
  # moves only 0.2821 -> 0.2697. Assert the population changed, not the number.
  expect_true(pool$discount <= base$discount)
  expect_true(all(pool$cases$ratio %in% c(base$cases$ratio, 0.05, 2/35)) ||
                nrow(pool$cases) > nrow(base$cases))
})

test_that("a loser-heavy corpus DOES pull the pooled defector rate down", {
  mk <- function(seat, prior, now, was_mp) data.table::data.table(
    election = c("e1","e2"), seat = seat, party = c("LNP","IND"),
    surname = toupper(seat), given = "A", pcv = c(prior, now),
    elected = c(was_mp, FALSE), name = NA_character_)
  d <- data.table::rbindlist(c(
    lapply(c("a","b","c"), function(x) mk(x, 50, 15, TRUE)),      # members, 0.30
    lapply(c("d","e","f","g"), function(x) mk(x, 40, 4, FALSE)))) # losers,  0.10
  prs <- list(list(election = "e2", prev = "e1"))
  base <- fit_defector_discount("zzz", corpus=d, pairs=prs, min_n=1L, pooled=FALSE)
  pool <- fit_defector_discount("zzz", corpus=d, pairs=prs, min_n=1L, pooled=TRUE)
  expect_equal(base$discount, 0.30)
  expect_true(pool$discount < base$discount)
})

test_that("fit_defector_discount's min_prior floor drops a ratio on a meaningless denominator", {
  # Preece (Schubert sa2026) went 2.1% -> 21.7%, a ratio of 10.14 that
  # destroyed the mean and was used to call the whole losing group unusable.
  mk <- function(seat, prior, now) data.table::data.table(
    election = c("e1","e2"), seat = seat, party = c("LNP","IND"),
    surname = toupper(seat), given = "A", pcv = c(prior, now),
    elected = c(TRUE, FALSE), name = NA_character_)
  d <- data.table::rbindlist(list(mk("alpha",50,15), mk("bravo",40,12),
                                   mk("tiny", 2.1, 21.7)))
  prs <- list(list(election = "e2", prev = "e1"))
  kept    <- fit_defector_discount("zzz", corpus=d, pairs=prs, min_n=1L, min_prior=0)
  dropped <- fit_defector_discount("zzz", corpus=d, pairs=prs, min_n=1L, min_prior=10)
  expect_equal(kept$n, 3L)
  expect_equal(dropped$n, 2L)
  # The MEDIAN is unmoved by the 10.14 outlier -- which is the whole reason the
  # rate is a median. The MEAN is not: it is what produced the claim that the
  # losing group was "unusable, mean 2.32", a claim built on exactly this shape
  # of case. Assert both, so the distinction cannot rot.
  expect_equal(dropped$discount, kept$discount)
  expect_gt(mean(kept$cases$ratio), 3 * mean(dropped$cases$ratio))
})

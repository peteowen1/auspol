test_that("a governed silent candidate is refused and a firing one permitted", {
  j <- c(0, 5, 0, 3, 2, 1, 4, 6, 0, 7)      # 70% register
  g <- rep(TRUE, 10)
  expect_equal(salience_screen(j, g), c(FALSE, TRUE, FALSE, rep(TRUE, 5), FALSE, TRUE))
})

test_that("an UNGOVERNED candidate is always permitted, silent or not", {
  # The screen says nothing about a sitting member or a party surge. Geoff Brock
  # held Stuart on a 48.5% prior and was silent; refusing him would be wrong.
  j <- c(0, 0, 5, 3, 2, 1, 4, 6, 0, 7)
  g <- c(FALSE, TRUE, rep(TRUE, 8))
  s <- salience_screen(j, g)
  expect_true(s[1])    # ungoverned, silent -> permitted
  expect_false(s[2])   # governed, silent   -> refused
})

test_that("a field below the registration threshold makes the screen INERT", {
  # South Australia: 7 of 111 fired. Treating silence as evidence there would
  # refuse four One Nation winners riding a 19.9-point party surge.
  j <- c(rep(0, 95), 1, 2, 3, 4, 5)          # 5% register
  expect_true(all(salience_screen(j, rep(TRUE, 100))))
})

test_that("the threshold is a boundary, not an approximation", {
  j <- c(rep(1, 10), rep(0, 90))             # exactly 10%
  expect_false(all(salience_screen(j, rep(TRUE, 100), min_fire = 0.10)))
  expect_true(all(salience_screen(j, rep(TRUE, 100), min_fire = 0.11)))
})

test_that("a non-finite jump is treated as silence, not propagated", {
  # An NA reaching a probability would poison the seat, and a missing series is
  # exactly what a candidate with no search presence produces.
  j <- c(NA_real_, 1, 2, 3, 4, 5, 6, 7, 8, 9)
  s <- salience_screen(j, rep(TRUE, 10))
  expect_false(s[1])
  expect_false(anyNA(s))
})

test_that("mismatched lengths are an error rather than recycled", {
  expect_error(salience_screen(c(1, 2, 3), c(TRUE, TRUE)), "same length")
})

test_that("registration is reported as a share and survives NA", {
  expect_equal(salience_registration(c(0, 0, 1, 1)), 0.5)
  expect_equal(salience_registration(c(NA, NA, 1, 1)), 0.5)
  expect_equal(salience_registration(numeric(0)), 0)
})

test_that("salience_permit_for returns NULL when the file has no such election", {
  # Isolated in its own temp dir so this never touches the real
  # output/salience-v6.csv, which case 21ddafb onward this test suite must not
  # clobber.
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(election = "x", seat = "A", party = "IND",
    jump = 1, prev_party = 0), "output/salience-v6.csv")
  expect_null(salience_permit_for("nope", "nope0", "xx"))
})

test_that("salience_permit_for finds a matching election", {
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(election = "x", seat = "A", party = "IND",
    jump = 1, prev_party = 0), "output/salience-v6.csv")
  r <- salience_permit_for("x", "x0", "xx")
  expect_equal(nrow(r), 1L)
  expect_true(r$permit)   # governed (no returns/surge data) and fired
})

test_that("returning is matched PER CANDIDATE, not broadcast to the whole class", {
  # Two IND candidates share (seat, party) at the target election. One of them
  # personally stood at the prior election and should be treated as returning
  # (governed = FALSE, so silence says nothing); the other is genuinely new
  # and should not inherit that verdict just because they share a class with
  # someone who returns. This is the bug fixed 2026-08-27: a (seat, party)
  # join broadcast one class-level "returning" flag to every candidate sharing
  # it. A third, unrelated firing candidate lifts registration above the 10%
  # floor so the screen is not inert and the distinction is observable.
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(
    election = "x0", seat = "A", party = "IND",
    name = "Smith, John", surname = "Smith", given = "John", pcv = 50),
    "output/candidacies.csv")
  data.table::fwrite(data.table::data.table(
    election = "x", seat = c("A", "A", "Z"), party = c("IND", "IND", "OTH"),
    keyword = c("John Smith", "Amy Jones", "Someone Else"),
    jump = c(0, 0, 5), prev_party = c(0, 0, 0)),
    "output/salience-v6.csv")
  r <- salience_permit_for("x", "x0", "xx")
  expect_equal(nrow(r), 3L)
  # John Smith personally returns -> ungoverned -> permitted even though silent
  expect_true(r$permit[r$seat == "A"][1])
  # Amy Jones is genuinely new -> governed, silent, and registration is 33% ->
  # refused, which is exactly the distinction the class-level bug erased
  expect_false(r$permit[r$seat == "A"][2])
})

test_that("a candidacies row with a missing seat name does not poison other rows to NA", {
  # ns(NA) is NA, which used to flow into `any(sk[i] == pk & sseat[i] == pseat)`
  # and return NA rather than FALSE whenever no TRUE match existed -- corrupting
  # `governed` (and therefore `permit`) for candidates with no relation to the
  # NA row at all. Regression test for that specific failure.
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(
    election = "x0", seat = c(NA_character_, "B"), party = c("IND", "IND"),
    name = c("Unknown, Person", "Baker, Tom"), surname = c("Unknown", "Baker"),
    given = c("Person", "Tom"), pcv = c(10, 20)),
    "output/candidacies.csv")
  data.table::fwrite(data.table::data.table(
    election = "x", seat = "C", party = "IND",
    keyword = "New Person", jump = 5, prev_party = 0),
    "output/salience-v6.csv")
  r <- salience_permit_for("x", "x0", "xx")
  expect_false(anyNA(r$permit))
})

test_that("a renamed seat does not turn a landslide incumbent into a fresh emergence", {
  # Andrew Wilkie held Denison (2016, 44.1%) continuously into its 2019 rename
  # to Clark (50.0%) -- ns() only strips case/punctuation, so "denison" and
  # "clark" never matched, and he was scored as a brand-new governed
  # candidate with prev_party near zero. That directly overstated a fitted
  # surge-size estimate (his 50% pulled the mean of "what a governed winner
  # gets" up alongside genuine emergences in the 25-44% range). Regression
  # test using the exact real-world case, via the SEAT_RENAMES lookup.
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(
    election = "x0", seat = "Denison", party = "IND",
    name = "Wilkie, Andrew", surname = "Wilkie", given = "Andrew", pcv = 44.1),
    "output/candidacies.csv")
  data.table::fwrite(data.table::data.table(
    election = "x", seat = "Clark", party = "IND",
    keyword = "Andrew Wilkie", jump = 3, prev_party = 0, elected = TRUE, pcv = 50.0),
    "output/salience-v6.csv")
  g <- governed_population("x", "x0", "xx")
  expect_equal(g$prev_party, 44.1)
  expect_false(g$governed)   # high prior vote alone should already exclude him
})

test_that("a new major-party candidate in their own party's safe seat is not governed", {
  # Found widening the surge-v2 training pairs 2026-09-04: with majors in
  # output/salience-v6.csv (added 2026-08-28, one day after this file's own
  # logic), a brand-new LNP candidate replacing a retiring MP in a seat safe
  # for LNP reads prev_party (THIS PERSON's own prior vote here) near zero --
  # exactly like a genuine emergence, by construction, for every safe-seat
  # succession in the corpus. governed_population() had no filter to stop it.
  # Reproduced on the pre-existing 5-pair surge-v2 training set too, not
  # introduced by the widening: a week-old silent regression nothing had
  # re-validated against since the majors fetch landed.
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(
    election = "x0", seat = "Safeseat", party = "LNP",
    name = "Retiring, Member", surname = "Retiring", given = "Member", pcv = 60.0),
    "output/candidacies.csv")
  data.table::fwrite(data.table::data.table(
    election = "x", seat = "Safeseat", party = "LNP",
    keyword = "New Candidate", jump = 8, prev_party = 0, elected = TRUE, pcv = 55.0),
    "output/salience-v6.csv")
  g <- governed_population("x", "x0", "xx")
  expect_false(g$governed)   # a new candidate in their own party's held seat, not an emergence
})

test_that("a returning member is excluded even when neither election crosses a seat rename", {
  # Found 2026-09-04 fixing the IND/OTH person-level prev_party override
  # below: apply_renames() maps denison->clark UNCONDITIONALLY, but the
  # rename only actually took effect for fed2019+. A pair entirely BEFORE
  # it -- both elections still calling the seat "Denison" -- renamed the
  # PREVIOUS election's seat to "clark" anyway, so the returning-member key
  # became "clark andrew wilkie" instead of "denison andrew wilkie" and
  # never matched his own prior row. `ret` came back FALSE and he read as a
  # fresh governed candidate with (once prev_party became person-level)
  # prev_party = 0 in his own held seat. Previously invisible because the
  # OLD class-level prev_party threshold excluded him anyway, by accident,
  # for an unrelated reason.
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(
    election = "x0", seat = "Denison", party = "IND",
    name = "Wilkie, Andrew", surname = "Wilkie", given = "Andrew", pcv = 21.3),
    "output/candidacies.csv")
  data.table::fwrite(data.table::data.table(
    election = "x", seat = "Denison", party = "IND",
    keyword = "Andrew Wilkie", jump = 3, prev_party = 21.3, elected = TRUE, pcv = 38.1),
    "output/salience-v6.csv")
  g <- governed_population("x", "x0", "xx")
  expect_false(g$governed)   # returning in the same seat, same name, no rename involved
})

test_that("prev_party for IND is this candidate's own prior vote, not another IND's", {
  # "IND" is not a party brand with continuity -- it is a label for
  # unrelated individuals. governed_population() previously read prev_party
  # as max(pcv) by (seat, party), so a brand-new independent in a seat a
  # DIFFERENT independent had previously done well in inherited that
  # stranger's result and failed the prev_party < 15 gate. Found asking why
  # Allegra Spender (Wentworth 2022) -- a first-time candidate -- was
  # excluded from the governed population: her recorded prev_party was
  # Kerryn Phelps' 32.4% from 2019, not her own (genuinely 0).
  td <- withr::local_tempdir()
  withr::local_dir(td)
  dir.create("output")
  data.table::fwrite(data.table::data.table(
    election = "x0", seat = "Someseat", party = "IND",
    name = "Prior, Candidate", surname = "Prior", given = "Candidate", pcv = 32.4),
    "output/candidacies.csv")
  data.table::fwrite(data.table::data.table(
    election = "x", seat = "Someseat", party = "IND",
    keyword = "New Person", jump = 9, prev_party = 32.4, elected = TRUE, pcv = 35.8),
    "output/salience-v6.csv")
  g <- governed_population("x", "x0", "xx")
  expect_equal(g$prev_party, 0)   # her own prior vote, not the previous IND's
  expect_true(g$governed)
})

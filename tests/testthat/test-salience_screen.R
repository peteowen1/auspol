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

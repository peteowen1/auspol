# A by-election is the seat's most recent result -- docs/plans/prereg-byelection-prior-2026-09-18.md
tab <- data.frame(
  region = "sa", seat = c(rep("Black", 3), rep("Prahran", 2), rep("Old", 2)),
  date = as.Date(c(rep("2024-11-16", 3), rep("2025-02-08", 2), rep("2021-01-01", 2))),
  candidate = "x",
  party_raw = c("Labor", "Liberal", "Greens", "Liberal", "Greens", "Labor", "Liberal"),
  votes = 1, pct = c(48, 34, 18, 50, 50, 60, 40), source = "test", stringsAsFactors = FALSE)

test_that("byelections_between keeps only by-elections inside the window and flags a missing major", {
  s <- byelections_between("sa2022", "sa2026", table = tab)
  expect_setequal(unique(s$seat), c("Black", "Prahran"))     # "Old" (2021) is before sa2022
  expect_true(all(s[seat == "Black"]$both_majors)); expect_false(any(s[seat == "Prahran"]$both_majors))
  expect_equal(sum(s[seat == "Black"]$share), 100)
  expect_equal(nrow(byelections_between("vic2022", "vic2026", table = tab)), 0L)   # wrong region
})

test_that("byelection_prior replaces only usable seats present in the matrix, and names the rest", {
  m <- matrix(c(50, 38, 12, 40, 30, 30), 2, byrow = TRUE, dimnames = list(c("Black", "Elsewhere"), c("LNP", "ALP", "GRN")))
  r <- byelection_prior(m, "sa2022", "sa2026", table = tab)
  expect_equal(unname(r["Black", ]), c(34, 48, 18))
  expect_equal(unname(r["Elsewhere", ]), c(40, 30, 30))
  a <- attr(r, "byelection")
  expect_equal(a$applied, "Black")
  expect_match(a$skipped, "Prahran")
  expect_identical(unclass(byelection_prior(m, "vic2022", "vic2026", table = tab))[1:6], unclass(m)[1:6])
})

test_that("byelection_winner_rows names the by-election winner as an elected candidacy row", {
  res <- data.frame(region = "sa", seat = "Black", date = as.Date("2024-11-16"), candidate = c("Alex Dighton", "Amanda Wilson"),
                    party_raw = c("Labor", "Liberal"), votes = c(10248, 7300), pct = c(47.9, 34.1), source = "t", stringsAsFactors = FALSE)
  win <- data.frame(region = "sa", seat = "Black", date = as.Date("2024-11-16"), winner_party_raw = "Labor", prev_party_raw = "Liberal", source = "t", stringsAsFactors = FALSE)
  b <- byelection_winner_rows("sa2022", "sa2026", results = res, winners = win)
  expect_equal(nrow(b), 1L); expect_equal(b$party, "ALP"); expect_equal(b$surname, "DIGHTON"); expect_true(b$elected)
  expect_equal(nrow(byelection_winner_rows("vic2022", "vic2026", results = res, winners = win)), 0L)
})

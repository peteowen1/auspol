# historic_elected for state elections: "the same person held this seat when the
# election was called". Regression for the 2026-10-25 vic2026 audit, where a
# surname + first-initial key over ANY earlier election flagged Jess KENNEDY
# (Bayswater) and Reece CLARK (Werribee) as sitting members.

# The rule that shipped until 2026-10-25, kept here so the test can prove it
# was wrong: surname + first initial, any earlier election in the region.
.legacy_returning <- function(cand, winners) {
  key <- function(s, g) paste0(toupper(s), "|", toupper(substr(g, 1, 1)))
  vapply(seq_len(nrow(cand)), function(i)
    key(cand$sur[i], cand$giv[i]) %in%
      key(winners$sur[winners$region == cand$region[i] & winners$year < cand$year[i]],
          winners$giv[winners$region == cand$region[i] & winners$year < cand$year[i]]),
    logical(1))
}

mk <- function(year, seat, sur, giv, region = "vic")
  data.table::data.table(region = region, year = year, seat = seat, sur = sur, giv = giv)

winners <- rbind(
  mk(2010, "Box Hill", "CLARK", "Robert"),
  mk(2014, "Box Hill", "CLARK", "Robert"),
  mk(2018, "Hawthorn", "KENNEDY", "John Ormond"),
  mk(2018, "Mildura", "CUPPER", "Ali"),
  mk(2022, "Mildura", "BENHAM", "Jade"),
  mk(2022, "Werribee", "PALLAS", "Tim"),
  mk(2022, "Clarinda", "TAK", "Meng Heang"),
  mk(2022, "Bayswater", "TAYLOR", "Jackson"),
  mk(2022, "Hawthorn", "PESUTTO", "John")
)
byel <- data.table::data.table(
  region = "vic", year = c(2023L, 2025L), seat = c("Narracan", "Werribee"),
  sur = c("FARNHAM", "LISTER"), giv = c("WAYNE", "JOHN"))

cand <- rbind(
  mk(2022, "Bayswater", "TAYLOR", "Jackson"),   # placeholder so 2022 exists as an election
  mk(2026, "Bayswater", "KENNEDY", "Jess"),     # NOT sitting: only John Kennedy ever won
  mk(2026, "Werribee", "CLARK", "Reece"),       # NOT sitting: only Robert Clark ever won
  mk(2026, "Werribee", "PALLAS", "Tim"),        # resigned; Lister replaced him
  mk(2026, "Werribee", "LISTER", "John"),       # by-election winner, sitting
  mk(2026, "Narracan", "FARNHAM", "Wayne"),     # supplementary-election winner, sitting
  mk(2026, "Mildura", "CUPPER", "Ali"),         # won 2018, lost 2022: former member
  mk(2026, "Mildura", "BENHAM", "Jade"),        # sitting
  mk(2026, "Clarinda", "HEANG TAK", "Meng"),    # compound surname, sitting
  mk(2026, "Hawthorn", "PESUTTO", "John"),      # sitting
  mk(2026, "Hawthorn", "KENNEDY", "Jim")        # Jim/John: not the 2018 member either (2018 is not the previous election)
)
cand <- cand[cand$year == 2026 | cand$seat == "Bayswater" & cand$year == 2022]

test_that("the legacy rule flagged the two people the audit found wrong", {
  # This is the failure the fix removes: it must hold for the legacy rule, or the
  # tests below prove nothing.
  old <- .legacy_returning(cand, winners)
  names(old) <- paste(cand$year, cand$seat, cand$sur)
  expect_true(old[["2026 Bayswater KENNEDY"]])
  expect_true(old[["2026 Werribee CLARK"]])
  expect_true(old[["2026 Mildura CUPPER"]])
})

test_that("a different first name at the same surname is a different person", {
  f <- returning_member_flags(cand, winners, byel)
  names(f) <- paste(cand$year, cand$seat, cand$sur, cand$giv)
  expect_false(f[["2026 Bayswater KENNEDY Jess"]])
  expect_false(f[["2026 Werribee CLARK Reece"]])
  expect_false(f[["2026 Hawthorn KENNEDY Jim"]])
})

test_that("only the previous general election and later by-elections count", {
  f <- returning_member_flags(cand, winners, byel)
  names(f) <- paste(cand$year, cand$seat, cand$sur, cand$giv)
  expect_false(f[["2026 Mildura CUPPER Ali"]])      # won 2018, not 2022
  expect_true(f[["2026 Mildura BENHAM Jade"]])
  expect_true(f[["2026 Hawthorn PESUTTO John"]])
})

test_that("a by-election winner is sitting and supersedes the member they replaced", {
  f <- returning_member_flags(cand, winners, byel)
  names(f) <- paste(cand$year, cand$seat, cand$sur, cand$giv)
  expect_true(f[["2026 Werribee LISTER John"]])
  expect_false(f[["2026 Werribee PALLAS Tim"]])
  expect_true(f[["2026 Narracan FARNHAM Wayne"]])   # seat absent from the 2022 corpus
})

test_that("a compound surname written two ways is still one person", {
  f <- returning_member_flags(cand, winners, byel)
  names(f) <- paste(cand$year, cand$seat, cand$sur, cand$giv)
  expect_true(f[["2026 Clarinda HEANG TAK Meng"]])
})

test_that("surname-only sources (WA) still join on the surname", {
  expect_true(same_person("PRINCE", "", "Prince", "Peter"))
  expect_false(same_person("KENNEDY", "Jess", "KENNEDY", "John Ormond"))
  expect_false(same_person("CLARK", "Reece", "CLARK", "Robert"))
  expect_true(same_person("SMITH", "Mike", "SMITH", "Michael"))
})

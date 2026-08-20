test_that("the majors classify from names as published", {
  expect_equal(classify_party("Australian Labor Party - Victorian Branch"), "ALP")
  expect_equal(classify_party("Labor SA"), "ALP")
  expect_equal(classify_party("Liberal"), "LNP")
  expect_equal(classify_party("The Nationals"), "LNP")
  expect_equal(classify_party("Australian Greens"), "GRN")
  expect_equal(classify_party("Pauline Hanson's One Nation"), "ONP")
})

test_that("parties that LOOK like a major but are not", {
  # Each of these would land in the wrong class under a naive substring match,
  # and each changes measured preference flows if misfiled.
  expect_equal(classify_party("Liberal Democrats"), "OTH_RIGHT")
  expect_equal(classify_party("Labour DLP"), "OTH_RIGHT")
  expect_equal(classify_party("Democratic Labour Party"), "OTH_RIGHT")
})

test_that("independents are their own class, however recorded", {
  # Commissions leave the party blank for independents rather than labelling
  # them. Folding them into OTH averages a 61% flow to Labor with a 35% one.
  expect_equal(classify_party(""), "IND")
  expect_equal(classify_party(NA_character_), "IND")
  expect_equal(classify_party("Independent"), "IND")
})

test_that("the minor right is separated from the general minor field", {
  expect_equal(classify_party("Family First Victoria"), "OTH_RIGHT")
  expect_equal(classify_party("Freedom Party of Victoria"), "OTH_RIGHT")
  expect_equal(classify_party("Shooters, Fishers and Farmers"), "OTH_RIGHT")
  expect_equal(classify_party("Legalise Cannabis Victoria"), "OTH")
  expect_equal(classify_party("Animal Justice Party"), "OTH")
  expect_equal(classify_party("Victorian Socialists"), "OTH")
})

test_that("codes are used in preference to names where supplied", {
  expect_equal(classify_party("Something Unrecognised", code = "ON"), "ONP")
  expect_equal(classify_party("Something Unrecognised", code = "LP"), "LNP")
  # an unrecognised code falls through to the name
  expect_equal(classify_party("Australian Greens", code = "ZZZ"), "GRN")
})

test_that("it is vectorised and length-checked", {
  expect_equal(classify_party(c("Liberal", "Australian Greens", "")),
               c("LNP", "GRN", "IND"))
  expect_error(classify_party(c("a","b"), code = "X"), "same length")
})

test_that("the NT Country Liberals are Coalition however the AEC spells them", {
  # Three spellings across seven federal elections; only one contains "liberal".
  # The other two fell through to OTH, so Lingiari and Solomon recorded the
  # Coalition's whole vote as "other" in 2007, 2022 and 2025.
  expect_equal(classify_party("Country Liberals (NT)", "CLP"), "LNP")
  expect_equal(classify_party("NT CLP", "CLP"), "LNP")
  expect_equal(classify_party("C.L.P.", "CLP"), "LNP")
})

test_that("CLP means the opposite thing in New South Wales", {
  # The same acronym is the Country LABOR Party in NSW. This is why the fix
  # above matches on the NAME and never on the code.
  expect_equal(classify_party("Country Labor Party", "CLP"), "ALP")
})

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

test_that("Centre Alliance / NXT / SA-BEST classify as IND, not OTH", {
  # Mayo has returned Rebekha Sharkie under this banner since 2016. It fits
  # none of ALP/LNP/GRN/ONP/OTH_RIGHT and would otherwise fall through to the
  # OTH wastebasket alongside genuinely unaligned minor parties.
  expect_equal(classify_party("Centre Alliance"), "IND")
  expect_equal(classify_party("Nick Xenophon Team"), "IND")
  expect_equal(classify_party("SA-BEST"), "IND")
  expect_equal(classify_party("SA Best"), "IND")
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

test_that("codes that no name rule can reach are classified", {
  # Western Australia publishes a party CODE and no name, so these arrive as
  # bare abbreviations. Every one below previously fell through to OTH: in
  # 2025 alone that was 27 independents, the Shooters in 26 districts and the
  # Nationals' six won seats.
  expect_equal(classify_party("IND", "IND"), "IND")
  expect_equal(classify_party("SFF", "SFF"), "OTH_RIGHT")
  expect_equal(classify_party("NATS", "NATS"), "LNP")
  expect_equal(classify_party("", "NATS"), "LNP")
  # And the full names the same commission publishes must agree with them.
  expect_equal(classify_party("The Nationals WA"), "LNP")
  expect_equal(classify_party("WA Labor"), "ALP")
  expect_equal(classify_party("The Greens (WA)"), "GRN")
  expect_equal(classify_party("Australian Christians"), "OTH_RIGHT")
  expect_equal(classify_party("Legalise Cannabis Party WA"), "OTH")
})

test_that("a bare DLP is not read as Labor", {
  # The rule for this spelled the word boundary "\b", which in an R string is
  # the BACKSPACE character rather than a regex escape, so the alternative
  # matched a control code and could never fire.
  expect_equal(classify_party("DLP"), "OTH_RIGHT")
  expect_equal(classify_party("Labour DLP"), "OTH_RIGHT")
  expect_equal(classify_party("Democratic Labour Party"), "OTH_RIGHT")
  # A word CONTAINING dlp is not the DLP; that is what the boundary is for.
  expect_equal(classify_party("Australian Labor Party"), "ALP")
})

test_that("a party is not made Coalition by the word liberal in its name", {
  # Liberals For Climate ran against the Liberals in two WA seats in 2021.
  expect_equal(classify_party("Liberals For Climate"), "OTH")
  expect_equal(classify_party("Liberal Party"), "LNP")
  expect_equal(classify_party("Liberal Democrats"), "OTH_RIGHT")
  # Call to Australia is Fred Nile's party, which became the Christian
  # Democrats; nothing in its name said so, so it read as OTH.
  expect_equal(classify_party("Call To Australia (WA)"), "OTH_RIGHT")
})

test_that("a minor party is not filed as OTH because of word order", {
  # These two are the same movement under the same man. Only the second used to
  # match, and Palmer United took 5.56% of the 2013 federal vote and won
  # Fairfax -- a seat whose winner therefore read as "OTH".
  expect_equal(classify_party("Palmer United Party"), "OTH_RIGHT")
  expect_equal(classify_party("United Australia Party"), "OTH_RIGHT")
  expect_equal(classify_party("Clive Palmer's United Australia Party"), "OTH_RIGHT")
  expect_equal(classify_party("Rise Up Australia Party"), "OTH_RIGHT")
  # Not a licence to catch anything with "united" or "australia" in it.
  expect_equal(classify_party("Australian Democrats"), "OTH")
  expect_equal(classify_party("Sustainable Australia Party"), "OTH")
})

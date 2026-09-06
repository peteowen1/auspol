# normalise_name() and search_form() exist because the same bug was fixed twice
# and broke a third time: the AEC records "Kylea Jane TINK", people search
# "Kylea Tink", and querying the legal form returns ZERO. That produced two
# published-and-wrong conclusions on 2026-08-26.

test_that("titles and post-nominals are removed", {
  expect_equal(normalise_name("Dr Monique RYAN"), "Monique Ryan")
  expect_equal(normalise_name("Rebekha SHARKIE AM"), "Rebekha Sharkie")
  expect_equal(normalise_name("The Hon Tony ABBOTT MP"), "Tony Abbott")
})

test_that("hyphens become spaces and punctuation is dropped", {
  expect_equal(normalise_name("Max CHANDLER-MATHER"), "Max Chandler Mather")
  expect_false(grepl("'", normalise_name("Michael O'BRIEN")))
})

test_that("a plain name is unchanged apart from case", {
  expect_equal(normalise_name("Zali STEGGALL"), "Zali Steggall")
})

test_that("search_form drops the middle name", {
  # The exact case that returned 0.0 twice.
  expect_equal(search_form("Kylea Jane", "TINK", NA_character_), "Kylea Tink")
  expect_equal(search_form("Clive Frederick", "PALMER", NA_character_), "Clive Palmer")
})

test_that("search_form does NOT truncate a two-word surname", {
  # Stripping the middle WORD would give "Dominic Kanak", which is a different
  # person as far as a search engine is concerned. This is why the fields are
  # used rather than a heuristic.
  expect_equal(search_form("Dominic", "WY KANAK", NA_character_), "Dominic Wy Kanak")
})

test_that("search_form falls back when the fields are missing", {
  # State commissions supply one `name` column, not given/surname.
  expect_equal(search_form(NA_character_, NA_character_, "Zoe DANIEL"), "Zoe Daniel")
})

test_that("state layouts are turned round into a searchable name", {
  # Every state commission supplies one combined field, and the previous version
  # fell through to it raw -- sending Google "Hood, Lucy" and "Clancy Justin".
  # 7,505 of 14,953 rows. South Australia returned 104 of 109 candidates at
  # exactly zero as a result.
  expect_equal(search_form(NA, NA, "HOOD, Lucy"), "Lucy Hood")
  expect_equal(search_form(NA, NA, "GREENWICH Alex"), "Alex Greenwich")
  expect_equal(search_form(NA, NA, "ENOCH, Leeanne"), "Leeanne Enoch")
})

test_that("the federal path is unchanged", {
  expect_equal(search_form("Kate", "ELLIS", "Kate Ellis"), "Kate Ellis")
  expect_equal(search_form("Adam", "BANDT", "Adam Bandt"), "Adam Bandt")
})

test_that("only a first given name is used, never a middle one", {
  expect_equal(search_form("Kylea Jane", "TINK", NA), "Kylea Tink")
  expect_equal(search_form(NA, NA, "SMITH, Mary Jane"), "Mary Smith")
})

test_that("a surname-only record returns the surname, not an empty string", {
  # Western Australia publishes bare surnames. Best available is still usable.
  expect_equal(search_form(NA, NA, "PRINCE"), "Prince")
})

test_that("a two-word surname survives", {
  expect_equal(search_form("Dominic", "WY KANAK", NA), "Dominic Wy Kanak")
})

test_that("all three combined-name layouts are read correctly", {
  expect_equal(search_form(NA, NA, "HOOD, Lucy"), "Lucy Hood")        # comma
  expect_equal(search_form(NA, NA, "GREENWICH Alex"), "Alex Greenwich") # surname first
  expect_equal(search_form(NA, NA, "Zoe DANIEL"), "Zoe Daniel")       # surname last
  expect_equal(search_form(NA, NA, "Kate Ellis"), "Kate Ellis")       # no case signal
})

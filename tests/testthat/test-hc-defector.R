# hc_defector_cases(): sitting members who change ticket, matched on the PERSON.
mk <- function() data.frame(
  region = "tas", year = c(2018, 2018, 2018, 2021, 2021, 2021, 2021),
  electorate = c("Clark", "Clark", "Bass", "Clark", "Clark", "Bass", "Clark"),
  candidate = c("Sue Hickey", "Ann Other", "Pat Same", "Sue Hickey", "Ann Other", "Pat Same", "New Person"),
  votes = c(7000, 3000, 5000, 6000, 3000, 5000, 1000), elected = c(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE),
  unit = c("LNP", "ALP", "ALP", "GRP: Sue Hickey", "ALP", "ALP", "IND: New Person"),
  class = c("LNP", "ALP", "ALP", "IND", "ALP", "ALP", "IND"), stringsAsFactors = FALSE)

test_that("only the sitting member who changed ticket is a case, on a data.frame and a data.table", {
  for (x in list(mk(), data.table::as.data.table(mk()))) {
    cs <- hc_defector_cases(x, "tas", 2021, 2018)
    expect_equal(nrow(cs), 1L)
    expect_equal(cs$person, "Sue Hickey")
    expect_equal(c(cs$from_cls, cs$to_cls), c("LNP", "OTH"))
    expect_true(cs$same_electorate)
    expect_equal(cs$prev_pv, 100 * 7000 / 10000)
  }
})

test_that("a different region or year gives no case", {
  expect_null(hc_defector_cases(mk(), "act", 2021, 2018))
  expect_null(hc_defector_cases(mk(), "tas", 2018, 2015))
})

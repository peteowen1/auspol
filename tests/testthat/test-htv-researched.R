# The researched Coalition card order (AUSPOL_HTV_TABLE=researched). plans/prereg-htv-researched-2026-11-06.md

test_that("the researched table maps card orders, splits seat lists, keeps open cards as NA and drops unknown and low-confidence cards", {
  f <- withr::local_tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(
    election = c("x2019", "x2019", "x2022", "x2022", "x2023", "x2024", "x2025"),
    seat = c("ALL", "Fremantle", "ALL", "A;B", "ALL", "ALL", "ALL"),
    party = c("LIB", "LIB", "LIB", "LIB", "LIB", "NAT", "LIB"),
    order = c("ALP_ABOVE_GRN", "GRN_ABOVE_ALP", "OPEN", "ALP_ABOVE_GRN", "GRN_ABOVE_ALP", "ALP_ABOVE_GRN", "UNKNOWN"),
    confidence = c("HIGH", "MED", "HIGH", "HIGH", "LOW", "HIGH", "LOW"),
    source_url = paste0("u", 1:7)), f)
  t <- htv_researched_table(f)
  data.table::setorderv(t, c("election", "seat"))
  expect_equal(t$election, c("x2019", "x2019", "x2022", "x2022", "x2022"))
  expect_equal(t$seat, c("ALL", "Fremantle", "A", "ALL", "B"))
  expect_equal(t$greens_above_labor, c(FALSE, TRUE, FALSE, NA, FALSE))   # x2022 ALL is the OPEN card
})

test_that("a seat-level OPEN card is kept as NA and that seat keeps its learned flows (Brunswick vic2026)", {
  f <- withr::local_tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(
    election = c("x2026", "x2026", "x2027"), seat = c("ALL", "Brunswick", "ALL"), party = "LIB",
    order = c("ALP_ABOVE_GRN", "OPEN", "OPEN"), confidence = "HIGH", source_url = "u"), f)
  t <- htv_researched_table(f)
  expect_equal(nrow(t), 3L)                                       # the statewide OPEN row (x2027) is kept as NA too
  expect_identical(t[t$seat == "Brunswick"]$greens_above_labor, NA)
  expect_false(t[t$election == "x2026" & t$seat == "ALL"]$greens_above_labor)
  t <- t[t$election == "x2026"]
  cond <- list("LNP|ALP,GRN" = c(ALP = 0.3, GRN = 0.7))
  fm <- list(conditional = cond)
  rows <- list(greens_above = 38, labor_above = 62)
  out <- htv_flow_override(NULL, fm, "x2026", c("Brunswick", "Richmond"), table = t, rows = rows)
  expect_null(out[["Brunswick"]])                                 # no override: the caller's learned flows stand
  expect_equal(out[["Richmond"]][["LNP|ALP,GRN"]][["ALP"]], 0.62)
  expect_equal(attr(out, "htv")$applied, 1L)
  # only open seat cards and no ALL row (vic2018): nothing applies, and a NULL override must come back NULL
  only_open <- t[t$seat == "Brunswick"]
  expect_null(htv_flow_override(NULL, fm, "x2026", c("Brunswick", "Richmond"), table = only_open, rows = rows))
})

test_that("AUSPOL_HTV_TABLE selects the table, and a bad value stops", {
  withr::local_envvar(AUSPOL_HTV_TABLE = "nonsense")
  expect_error(htv_order_table(), "shipped or researched")
  withr::local_envvar(AUSPOL_HTV_TABLE = "shipped")
  f <- withr::local_tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(election = "x2019", seat = "ALL", greens_above_labor = TRUE, source = "s"), f)
  expect_true(htv_order_table(f)$greens_above_labor)
})

test_that("two kept rows for one election and seat are refused", {
  f <- withr::local_tempfile(fileext = ".csv")
  data.table::fwrite(data.table::data.table(election = c("x2019", "x2019"), seat = c("ALL", "ALL"), party = "LIB",
                                            order = c("ALP_ABOVE_GRN", "GRN_ABOVE_ALP"), confidence = "HIGH", source_url = "u"), f)
  expect_error(htv_researched_table(f), "two kept rows")
})

test_that("card labels train the shares from the card table, with an open share, time-forward and shrunk", {
  sp <- data.table::data.table(
    election = c("x2010", "x2010", "x2014", "x2018", "x2018", "x2022", "x2026"),
    seat     = c("A", "B", "A", "A", "B", "A", "A"),
    alp      = c(60, 70, 65, 57, 40, 35, 99),
    tot      = 100)
  tab <- data.table::data.table(
    election = c("x2010", "x2014", "x2018", "x2022", "x2026"),
    seat     = c("ALL", "ALL", "A", "ALL", "ALL"),
    greens_above_labor = c(FALSE, FALSE, NA, TRUE, FALSE))
  r <- htv_card_label_shares("x2026", sp, tab, hl = 0)
  expect_setequal(r$n$label, c("labor_above", "open", "greens_above"))
  expect_false(any(r$n$election == "x2026"))                      # time-forward: the target never trains
  expect_false("x2018 B" %in% paste(r$n$election, r$n$label))     # x2018 seat B has no card row: left out
  expect_equal(r$n[r$n$election == "x2018"]$alp_share, 57)         # only the open seat A
  raw_lab <- (60 + 70 + 65) / 3
  expect_true(r$labor_above <= max(raw_lab, r$shrink$m[r$shrink$label == "labor_above"]) + 1e-9)
  expect_true(all(r$shrink$wt >= 0 & r$shrink$wt <= 1))
  expect_true(r$labor_above > r$open && r$open > r$greens_above)   # ordering survives the shrinkage here
})

test_that("an open card takes the open share only when one is fitted", {
  tab <- data.table::data.table(election = "x2026", seat = c("ALL", "B"), greens_above_labor = c(FALSE, NA))
  fm <- list(conditional = list("LNP|ALP,GRN" = c(ALP = 0.3, GRN = 0.7)))
  with_open <- htv_flow_override(NULL, fm, "x2026", c("A", "B"), table = tab, rows = list(greens_above = 35, labor_above = 63, open = 57))
  expect_equal(with_open[["B"]][["LNP|ALP,GRN"]][["ALP"]], 0.57)
  expect_equal(with_open[["A"]][["LNP|ALP,GRN"]][["ALP"]], 0.63)
  no_open <- htv_flow_override(NULL, fm, "x2026", c("A", "B"), table = tab, rows = list(greens_above = 35, labor_above = 63, open = NA_real_))
  expect_null(no_open[["B"]])
  # seat rows only, no ALL row (vic2018): a seat the table does not name is NOT an open card and is left alone
  seat_only <- data.table::data.table(election = "x2018", seat = "B", greens_above_labor = NA)
  o <- htv_flow_override(NULL, fm, "x2018", c("A", "B"), table = seat_only, rows = list(greens_above = 35, labor_above = 63, open = 57))
  expect_equal(o[["B"]][["LNP|ALP,GRN"]][["ALP"]], 0.57)
  expect_null(o[["A"]])
  expect_equal(attr(o, "htv")$applied, 1L)
})

test_that("AUSPOL_HTV_LABELS refuses an unknown value", {
  withr::local_envvar(AUSPOL_HTV_LABELS = "results")
  expect_error(htv_labels_mode(), "outcome, card or hybrid")
})

test_that("hybrid labels seats with no card by their election's pooled result; carded seats keep the card", {
  sp <- data.table::data.table(election = c("x2006", "x2006", "x2018", "x2018", "x2018"), seat = c("A", "B", "A", "B", "C"),
                               alp = c(30, 28, 57, 60, 40), tot = 100)
  tab <- data.table::data.table(election = "x2018", seat = "A", greens_above_labor = NA)   # only x2018 seat A has a card (open)
  card <- htv_card_label_shares("x2026", sp, tab, hl = 0)
  expect_equal(sort(unique(paste(card$n$election, card$n$label))), "x2018 open")
  hyb <- htv_card_label_shares("x2026", sp, tab, hl = 0, fallback_outcome = TRUE)
  lab <- setNames(hyb$n$label, paste(hyb$n$election, hyb$n$alp_share))
  expect_equal(unname(lab["x2006 29"]), "greens_above")             # no card anywhere: its result labels it
  expect_equal(unname(lab["x2018 50"]), "labor_above")              # seats B and C pooled: 50.0, not under 50
  expect_equal(unname(lab["x2018 57"]), "open")                     # the carded seat keeps its card
})

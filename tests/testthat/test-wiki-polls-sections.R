# wiki_polls() must take statewide lower-house voting intention only. Until 2026-10-13 sub-state tables
# (Inner Melbourne, Regional SA) and Legislative Council tables on the vic2026 / sa2026 pages entered the
# poll set as statewide polls (DemosAU Inner Melbourne: Greens 23 read as a statewide Greens 23).

test_that("wiki_polls keeps statewide rows and drops sub-state and upper-house tables", {
  secs <- c("Voting intention > Legislative Assembly > 2026",
            "Sub-state results > Inner Melbourne",
            "Voting intention > Legislative Council",
            "Sub-state polling > Regional South Australia",
            "Voting consideration",
            "Graphical summary > Leader satisfaction > Only English spoken at home")
  n <- length(secs)
  w <- data.table::data.table(
    row_type = "poll", table_type = "primary", region = "vic", section = secs,
    firm_raw = "DemosAU", footnote_raw = "", fieldwork_start = "2026-02-01", fieldwork_end = "2026-02-10",
    alp_fp = 23 + seq_len(n), lnp_fp = 29, lib_fp = NA_real_, nat_fp = NA_real_, alp_tpp = 47,
    pv_GRN = "15%", pv_ONP = "21%", `tpp_L/NP` = 53)
  f <- tempfile(fileext = ".csv"); data.table::fwrite(w, f)
  out <- wiki_polls("vic", c("ALP", "LNP", "GRN", "ONP", "OTH"), f)
  expect_equal(nrow(out), 1L)
  expect_equal(out$ALP, 24)
})

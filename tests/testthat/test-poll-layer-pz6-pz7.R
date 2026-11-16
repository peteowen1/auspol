# PZ6 / PZ7 (review 2026-11-15, Issue 8): poll_layer() pairs one firm's polls within a 4-day window whatever
# their numbers, so two different polls can be paired and one lost. PZ6 names every such pair differing by more
# than 3 points; PZ7 lists our rows whose numbers the trend does not read. Log lines only.

pz_fixture_dir <- function(alp_ours) {
  d <- tempfile("pz6"); dir.create(d)
  w <- data.table::data.table(
    row_type = "poll", table_type = "primary", region = "vic", section = "Voting intention > Legislative Assembly",
    date_raw = "25 Sep 2025", firm_raw = "Resolve Strategic", footnote_raw = "", firm = "Resolve Strategic",
    fieldwork_start = "2025-09-25", fieldwork_end = "2025-09-25",
    alp_fp = alp_ours, lnp_fp = 33, lib_fp = NA_real_, nat_fp = NA_real_, alp_tpp = NA_real_, pv_GRN = "12%", pv_ONP = "")
  data.table::fwrite(w, file.path(d, "statewide_polls_wiki.csv"))
  data.table::fwrite(data.table::data.table(pattern = "resolve", canonical = "resolve", note = ""), file.path(d, "firm_alias.csv"))
  d
}
pz_ae <- function() {
  ae <- data.table::data.table(date = as.Date("2025-09-22"), firm = "ResolvePM", tpp_published = NA_real_,
                               ALP = 30, LNP = 33, GRN = 12, ONP = NA_real_, OTH = 25)
  data.table::setattr(ae, "parties", c("ALP", "LNP", "GRN", "ONP", "OTH"))
  ae
}
pz_layer <- function(alp_ours) {
  withr::local_envvar(AUSPOL_POLL_BT = "0", AUSPOL_POLL_ARCHIVE = "0", AUSPOL_POLL_PB = "0")
  msgs <- character(0)
  out <- withCallingHandlers(
    poll_layer(pz_ae(), "vic", path = file.path(pz_fixture_dir(alp_ours), "statewide_polls_wiki.csv")),
    message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") })
  list(out = out, msgs = msgs)
}

test_that("two polls of one firm 3 days apart and 5 points different are named by PZ6, and PZ7 lists the lost row", {
  r <- pz_layer(35)                                     # ours ALP 35 vs AE's 30, 3 days apart
  expect_equal(attr(r$out, "layer_log")$matched, 1L)    # still paired: the line reports, it does not change pairing
  pz6 <- grep("^PZ6", r$msgs, value = TRUE)
  expect_length(pz6, 1L)
  expect_match(pz6, "differ by 5.0, kept AE")
  pz7 <- grep("^PZ7", r$msgs, value = TRUE)
  expect_length(pz7, 1L)
  expect_match(pz7, "lost a disputed pair")
  expect_equal(r$out$ALP, 30)                           # AE's copy is what the trend reads, as before
})

test_that("a matched pair with the same numbers gives neither line", {
  r <- pz_layer(30)
  expect_length(grep("^PZ6", r$msgs), 0L)
  expect_length(grep("^PZ7", r$msgs), 0L)
  expect_equal(r$out$ALP, 30)
})

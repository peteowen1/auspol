test_that("zero_unnominated zeroes a class with no candidate and renormalises", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  sh <- matrix(c(40, 35, 25,
                 50, 30, 20), nrow = 2, byrow = TRUE,
               dimnames = list(c("Narracan", "Morwell"), c("ALP", "LNP", "IND")))
  tg <- data.table::data.table(seat = c("Narracan", "Narracan", "Morwell", "Morwell", "Morwell"),
                               party = c("LNP", "IND", "ALP", "LNP", "IND"),
                               votes = c(100, 50, 10, 10, 10))
  out <- zero_unnominated(sh, tg, "test")
  expect_equal(unname(out["Narracan", "ALP"]), 0)
  expect_equal(unname(rowSums(out)), c(100, 100))
  expect_equal(out["Morwell", ], sh["Morwell", ])          # everyone stood: untouched
  expect_equal(unname(out["Narracan", "LNP"]), 35 / 60 * 100)
})

test_that("zero_unnominated never zeroes a class the result table does not use, or an unknown seat", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  sh <- matrix(c(40, 35, 25), nrow = 1, dimnames = list("Nowhere-Not-A-Seat", c("ALP", "NAT", "LNP")))
  tg <- data.table::data.table(seat = "Elsewhere", party = c("ALP", "LNP"), votes = c(1, 1))
  expect_equal(zero_unnominated(sh, tg, "test"), sh)     # seat absent from the table
  sh2 <- matrix(c(40, 35, 25), nrow = 1, dimnames = list("Elsewhere", c("ALP", "NAT", "LNP")))
  out <- zero_unnominated(sh2, tg, "test")
  expect_gt(out[1, "NAT"], 0)                             # NAT never appears in the result table
})

test_that("zero_unnominated is a no-op when the switch is off", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "0")
  sh <- matrix(c(40, 60), nrow = 1, dimnames = list("A", c("ALP", "LNP")))
  expect_identical(zero_unnominated(sh, data.table::data.table(seat = "A", party = "LNP", votes = 1), "t"), sh)
})

test_that("mode 2 sends the freed share where the flow matrix says, conditional first", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "2")
  sh <- matrix(c(40, 40, 10, 10), nrow = 1, dimnames = list("Richmond", c("ALP", "GRN", "LNP", "OTH")))
  # Kew carries an LNP candidate, so LNP is a class the result table uses
  tg <- data.table::data.table(seat = c("Richmond", "Richmond", "Richmond", "Kew"),
                               party = c("ALP", "GRN", "OTH", "LNP"), votes = 1)
  fl <- list(conditional = list("LNP|ALP+GRN+OTH" = c(ALP = 20, GRN = 70, OTH = 10)),
             pooled = list(LNP = c(ALP = 90, GRN = 10)))
  out <- zero_unnominated(sh, tg, "test", flows = fl)
  expect_equal(unname(out[1, "LNP"]), 0)
  expect_equal(unname(out[1, c("ALP", "GRN", "OTH")]), c(42, 47, 11))
  fl2 <- list(conditional = list(), pooled = list(LNP = c(ALP = 90, GRN = 10)))
  out2 <- zero_unnominated(sh, tg, "test", flows = fl2)   # pooled fallback, OTH gets none
  expect_equal(unname(out2[1, c("ALP", "GRN", "OTH")]), c(49, 41, 10))
  expect_equal(sum(out2), 100)
})

.live_fixture <- function() {
  seats <- c("Richmond", "Kew", "Narracan")
  prior <- data.table::data.table(election = "vic2022", seat = rep(seats, each = 4),
                                  party = rep(c("ALP", "LNP", "GRN", "IND"), 3))
  # vic2026: Narracan has no GRN candidate; everything else stands. 11 of 12 = 92%.
  now <- data.table::data.table(election = "vic2026", seat = rep(seats, each = 4),
                                party = rep(c("ALP", "LNP", "GRN", "IND"), 3))
  now <- now[!(now$seat == "Narracan" & now$party == "GRN")]
  list(seats = seats, corpus = rbind(prior, now))
}
.live_shares <- function(seats) {
  matrix(c(40, 30, 20, 10), nrow = 3, ncol = 4, byrow = TRUE,
         dimnames = list(seats, c("ALP", "LNP", "GRN", "IND")))
}
.live_flows <- list(conditional = list(), pooled = list(GRN = c(ALP = 50, LNP = 50)))

test_that("a seat left with no standing class is kept unchanged, never NaN (review, both modes)", {
  sh <- matrix(c(50, 50, 0, 60, 40, 0), nrow = 2, byrow = TRUE,
               dimnames = list(c("A", "B"), c("ALP", "LNP", "IND")))
  tg <- data.table::data.table(seat = c("A", "B", "B"), party = c("IND", "ALP", "LNP"), votes = 1)
  fl <- list(conditional = list(), pooled = list(ALP = c(LNP = 100), LNP = c(ALP = 100)))
  for (m in c("1", "2")) {
    withr::local_envvar(AUSPOL_NOM_ZERO = m)
    out <- zero_unnominated(sh, tg, "test", flows = fl)
    expect_true(all(is.finite(out)))
    expect_equal(out["A", ], sh["A", ])
    expect_equal(out["B", ], sh["B", ])
  }
})

.nz_run <- function(sh, corpus, today = as.Date("2026-11-10")) {
  txt <- paste(capture.output(out <- zero_unnominated_live(sh, .live_flows, "vic2026", corpus = corpus, today = today)), collapse = "\n")
  list(out = out, txt = txt)
}
.nz_err <- function(sh, corpus, today = as.Date("2026-11-10")) {
  tryCatch({ capture.output(zero_unnominated_live(sh, .live_flows, "vic2026", corpus = corpus, today = today)); NA_character_ },
           error = function(e) conditionMessage(e))
}

test_that("live: =1 with a complete list zeroes the non-standing party and sends its share by flows", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  r <- .nz_run(sh, fx$corpus)
  expect_equal(unname(r$out["Narracan", "GRN"]), 0)
  expect_equal(unname(r$out["Narracan", c("ALP", "LNP", "IND")]), c(50, 40, 10))   # GRN 20 split 50/50 ALP/LNP
  expect_equal(r$out["Richmond", ], sh["Richmond", ])
  expect_match(r$txt, "applied: 3 cells changed, 1 zeroed (GRN 1)", fixed = TRUE)   # per-class zeroed counts
  expect_false(grepl("ALP has no candidacy", r$txt, fixed = TRUE))
})

test_that("live: auto never opens, even long after nominations closed; 0 stays shut", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  r <- .nz_run(sh, fx$corpus, today = as.Date("2027-01-01"))
  expect_match(r$txt, "provisional list, set AUSPOL_NOM_LIVE=1 after loading the VEC final list")
  expect_identical(r$out, sh)
  withr::local_envvar(AUSPOL_NOM_LIVE = "0")
  r0 <- .nz_run(sh, fx$corpus)
  expect_match(r0$txt, "NOT applied")
  expect_identical(r0$out, sh)
})

test_that("live: =1 with Labor absent in some seats and the count above the floor APPLIES, and names the seats", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  extra <- data.table::data.table(election = "vic2026", seat = rep("Kew", 3), party = c("IND", "OTH", "ONP"))
  c2 <- fx$corpus[!(fx$corpus$election == "vic2026" & fx$corpus$seat == "Kew" & fx$corpus$party == "ALP")]
  c2 <- rbind(c2, extra)
  expect_gt(sum(c2$election == "vic2026") / sum(c2$election == "vic2022"), 0.85)
  r <- .nz_run(sh, c2)
  expect_match(r$txt, "ALP has no candidacy in 1 of 3 forecast seats; any predicted ALP share there will be ZEROED: kew")
  expect_equal(unname(r$out["Kew", "ALP"]), 0)
  expect_match(r$txt, "applied:")
})

test_that("live: a seat with no candidacy at all is left untouched and is not named as 'zeroed'", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  pad <- data.table::data.table(election = "vic2026", seat = rep("Richmond", 4), party = c("OTH", "ONP", "OTH_RIGHT", "OTH"))
  c2 <- rbind(fx$corpus[!(fx$corpus$election == "vic2026" & fx$corpus$seat == "Kew")], pad)
  expect_gt(sum(c2$election == "vic2026") / sum(c2$election == "vic2022"), 0.85)
  r <- .nz_run(sh, c2)
  expect_match(r$txt, "1 forecast seat(s) have no candidacy at all and are left untouched: kew", fixed = TRUE)
  expect_false(grepl("share there will be ZEROED: kew", r$txt, fixed = TRUE))
  expect_equal(r$out["Kew", ], sh["Kew", ])
})

test_that("live: =1 with a list under the count floor, or no rows, or no baseline, or no csv, STOPS", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  p22 <- fx$corpus[fx$corpus$election == "vic2022"]
  part <- rbind(p22, fx$corpus[fx$corpus$election == "vic2026"][1])
  expect_match(.nz_err(sh, part), "NZL!! list too small")
  expect_match(.nz_err(sh, p22), "no vic2026 candidacies")
  expect_match(.nz_err(sh, fx$corpus[fx$corpus$election == "vic2026"]), "no vic2022 candidacies")
  withr::local_dir(withr::local_tempdir())
  expect_match(tryCatch(zero_unnominated_live(sh, .live_flows, "vic2026"), error = function(e) conditionMessage(e)),
               "candidacies.csv is missing")
})

test_that("live: an unrecognised AUSPOL_NOM_LIVE STOPS rather than running without zeroing", {
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  for (v in c("true", "yes", "1 ", "2")) {
    withr::local_envvar(AUSPOL_NOM_LIVE = v, AUSPOL_NOM_ZERO = "2")
    expect_true(nom_zero_requested())
    expect_match(.nz_err(sh, fx$corpus), "not recognised", info = v)
  }
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto"); expect_false(nom_zero_requested())
  withr::local_envvar(AUSPOL_NOM_LIVE = "0");    expect_false(nom_zero_requested())
})

test_that("live: a share matrix without rownames STOPS", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats); rownames(sh) <- NULL
  expect_match(.nz_err(sh, fx$corpus), "no rownames")
})

test_that("live: =1 before the nomination-close date warns loudly but does not block", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  early <- .nz_run(sh, fx$corpus, today = as.Date("2026-11-09"))
  expect_match(early$txt, "WARNING AUSPOL_NOM_LIVE=1 set on 2026-11-09, before 2026-11-10")
  expect_equal(unname(early$out["Narracan", "GRN"]), 0)
  late <- .nz_run(sh, fx$corpus, today = as.Date("2026-11-10"))
  expect_false(grepl("before 2026-11-10", late$txt, fixed = TRUE))
})

test_that("live: per-class seat counts are printed and a class far below vic2022 is warned about", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  r <- .nz_run(sh, fx$corpus)
  expect_match(r$txt, "candidacies per class, seats now/vic2022: ALP 3/3 GRN 2/3 IND 3/3 LNP 3/3", fixed = TRUE)
  expect_match(r$txt, "GRN stands in 2 seats against 3 at vic2022", fixed = TRUE)
  expect_false(grepl("LNP stands in", r$txt, fixed = TRUE))
})

test_that("live: AUSPOL_NOM_LIVE=1 with AUSPOL_NOM_ZERO off (0, or any non-1/2) STOPS", {
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  for (z in c("0", "3", "off")) {
    withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = z)
    expect_match(.nz_err(sh, fx$corpus), "NZL!! AUSPOL_NOM_LIVE=1 asked for nomination zeroing but AUSPOL_NOM_ZERO", fixed = FALSE, info = z)
  }
})

test_that("harness-style zero_unnominated() with AUSPOL_NOM_ZERO=0 stays a quiet no-op, and the auto/0 gate does too", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "auto", AUSPOL_NOM_ZERO = "0")
  fx <- .live_fixture(); sh <- .live_shares(fx$seats)
  tg <- data.table::data.table(seat = c("Richmond", "Kew"), party = c("ALP", "ALP"), votes = 1)
  expect_no_error(out <- zero_unnominated(sh, tg, "harness"))
  expect_identical(out, sh)
  expect_identical(.nz_run(sh, fx$corpus)$out, sh)             # auto gate shut: no error with NOM_ZERO=0
  withr::local_envvar(AUSPOL_NOM_LIVE = "0")
  expect_identical(.nz_run(sh, fx$corpus)$out, sh)
})

test_that("live: a class absent from the nomination table is reported as skipped", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture()
  sh <- cbind(.live_shares(fx$seats), NAT = 5)
  sh[, "ALP"] <- 35
  expect_match(.nz_run(sh, fx$corpus)$txt, "absent from the nomination table: NAT")
})

# The ordering defect found in review: the seat-swing port does
# shares[, "ALP"] <- pmax(0, ALP + adj) (R/seat_swing_port.R:131), which revives a
# zeroed Labor cell when adj > 0. This mimics that step on a synthetic matrix.
.port_like <- function(sh, adj) {
  sh[, "ALP"] <- pmax(0, sh[, "ALP"] + adj)
  sh[, "LNP"] <- pmax(0, sh[, "LNP"] - adj)
  100 * sh / rowSums(sh)
}

test_that("the end-of-run assertion fails when a step after the zeroing revives a zeroed cell", {
  withr::local_envvar(AUSPOL_NOM_LIVE = "1", AUSPOL_NOM_ZERO = "2")
  fx <- .live_fixture()
  adj <- c(0, 0, 2)                                             # positive swing toward ALP in Narracan (third seat)
  # Labor does not stand in Narracan (nor does the Greens): the cells the port can revive are ALP and LNP.
  corpus_noalp <- fx$corpus[!(fx$corpus$election == "vic2026" & fx$corpus$seat == "Narracan" & fx$corpus$party == "ALP")]
  extra <- data.table::data.table(election = "vic2026", seat = rep("Kew", 2), party = c("OTH", "ONP"))
  corpus_noalp <- rbind(corpus_noalp, extra)
  base <- .live_shares(fx$seats)
  capture.output(zeroed_first <- zero_unnominated_live(base, .live_flows, "vic2026", corpus = corpus_noalp, today = as.Date("2026-11-10")))
  cells <- nomination_zeroed_cells(base, zeroed_first)
  expect_true(any(cells$seat == "Narracan" & cells$class == "ALP"))
  wrong <- .port_like(zeroed_first, adj)                         # port AFTER zeroing: revives Narracan ALP
  expect_gt(unname(wrong["Narracan", "ALP"]), 0)
  expect_error(assert_nomination_zeros(wrong, cells), "no longer 0")
  expect_error(assert_nomination_zeros(wrong, cells), "Narracan ALP")
  # RIGHT ORDER (port, then zeroing): the cell stays 0 and the assertion passes
  capture.output(right <- zero_unnominated_live(.port_like(base, adj), .live_flows, "vic2026", corpus = corpus_noalp, today = as.Date("2026-11-10")))
  cells2 <- nomination_zeroed_cells(.port_like(base, adj), right)
  expect_equal(unname(right["Narracan", "ALP"]), 0)
  expect_silent(assert_nomination_zeros(right, cells2))
  expect_silent(assert_nomination_zeros(wrong, NULL))
})

# ---- as-at forecasts table (build_forecasts_table.R) -------------------------
.asat_fixture <- function() {
  # raw xgb rows: do NOT sum to 100 (74 here, like Narracan's real 73.96).
  # Narracan: Labor did not stand. Richmond: everyone stood, so untouched.
  data.table::data.table(
    election = "vic2022",
    seat = c(rep("Narracan", 4), rep("Richmond", 3)),
    party = c("ALP", "LNP", "GRN", "IND", "ALP", "LNP", "GRN"),
    xgb_pred = c(24, 38, 4, 8, 40, 20, 30),
    actual_share = c(0, 50, 15, 35, 33, 30, 37))
}

test_that("zero_unnominated_asat zeroes the absent class, keeps each raw seat total, leaves other seats alone", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "1")
  f <- .asat_fixture()
  out <- suppressMessages(utils::capture.output(r <- zero_unnominated_asat(f, allow_proportional = TRUE)))
  expect_equal(r[seat == "Narracan" & party == "ALP", xgb_pred], 0)
  expect_equal(r[seat == "Narracan", sum(xgb_pred)], 74)           # raw total, not 100
  expect_equal(r[seat == "Narracan" & party == "LNP", xgb_pred], 38 / 50 * 74)
  expect_identical(r[seat == "Richmond", xgb_pred], f[seat == "Richmond", xgb_pred])
  expect_equal(r$xgb_pred_prezero, f$xgb_pred)
})

test_that("zero_unnominated_asat is byte-identical with the switch off", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "0")
  f <- .asat_fixture()
  expect_identical(zero_unnominated_asat(f), f)
})

test_that("zero_unnominated_asat does nothing when every class stood (a broken target must not zero)", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "2")
  f <- .asat_fixture(); f$actual_share <- pmax(f$actual_share, 1)
  utils::capture.output(r <- zero_unnominated_asat(f, allow_proportional = TRUE))
  expect_equal(r$xgb_pred, f$xgb_pred)
})

test_that("zero_unnominated_asat STOPS at mode 2 when an election has no flow matrix", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "2")
  expect_error(zero_unnominated_asat(.asat_fixture()), "NZA!!.*vic2022")
  expect_error(zero_unnominated_asat(.asat_fixture(), flows = list(fed2022 = list())), "NZA!!.*vic2022")
})

test_that("harness-saved flows round-trip, and a missing file stops", {
  d <- withr::local_tempdir()
  fl <- list(conditional = list(), pooled = list(ALP = c(GRN = 1)))
  nom_zero_save_flows(fl, "vic2022", dir = d)
  nom_zero_save_flows(NULL, "wa2025", dir = d)
  utils::capture.output(got <- nom_zero_load_flows(c("vic2022", "wa2025"), dir = d))
  expect_identical(got$vic2022, fl)
  expect_true("wa2025" %in% names(got)); expect_null(got$wa2025)
  expect_error(nom_zero_load_flows("nsw2023", dir = d), "NZA!!")
})

test_that("zero_unnominated_asat uses the flow matrix when one is given", {
  withr::local_envvar(AUSPOL_NOM_ZERO = "2")
  f <- .asat_fixture()
  fl <- list(vic2022 = list(conditional = list(), pooled = list(ALP = c(GRN = 0.9, LNP = 0.1))))
  utils::capture.output(r <- zero_unnominated_asat(f, flows = fl))
  expect_equal(r[seat == "Narracan" & party == "GRN", xgb_pred], 4 + 24 * 0.9)
  expect_equal(r[seat == "Narracan" & party == "LNP", xgb_pred], 38 + 24 * 0.1)
  expect_equal(r[seat == "Narracan", sum(xgb_pred)], 74)
})

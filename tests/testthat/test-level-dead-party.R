# AUSPOL_LEVEL_DEAD_PARTY: a party that stood last time and does not stand now gives up the share the level
# would carry forward (R/level_dead_party.R). docs/plans/prereg-level-dead-party-2026-10-25.md.
# Synthetic corpus only: nothing here reads output/.

dp_quiet <- function(expr) { out <- NULL; utils::capture.output(out <- expr); out }

# Previous election x2020 (10 seats) and target x2024 (10 seats). Territory Alliance (OTH) took 14 points and
# does not stand; "Family First Victoria" stands as "Family First"; "Animal Justice Party" as "AJP" in 5 seats;
# the Liberal Democrats stand as "Libertarian" with the same people; independents never count as a party.
dp_corpus <- function(ta_stands = FALSE) {
  seats <- sprintf("Seat %d", 1:10)
  mk <- function(el, yr, party, raw, v, seat = seats, given = "Alex", surname = NULL) {
    n <- length(seat)
    data.frame(election = el, region = "xx", year = yr, seat = seat, party = party, party_raw = raw,
               party_ab = NA_character_, votes = v, pcv = NA_real_,
               given = given, surname = if (is.null(surname)) paste0(gsub("[^A-Za-z]", "", raw), seq_len(n)) else surname,
               name = NA_character_, stringsAsFactors = FALSE)
  }
  prev <- rbind(
    mk("xx2020", 2020, "ALP", "Labor", 400), mk("xx2020", 2020, "LNP", "Liberal", 300),
    mk("xx2020", 2020, "OTH", "Territory Alliance", 140), mk("xx2020", 2020, "OTH_RIGHT", "Family First Victoria", 60),
    mk("xx2020", 2020, "OTH", "Animal Justice Party", 40), mk("xx2020", 2020, "OTH_RIGHT", "Liberal Democrats", 30),
    mk("xx2020", 2020, "IND", "Independent", 30))
  tgt <- rbind(
    mk("xx2024", 2024, "ALP", "Labor", 1), mk("xx2024", 2024, "LNP", "Liberal", 1),
    mk("xx2024", 2024, "OTH_RIGHT", "Family First", 1),
    mk("xx2024", 2024, "OTH", "AJP", 1, seat = sprintf("Seat %d", 1:5)),
    # the same ten people as the Liberal Democrats, under a new label
    mk("xx2024", 2024, "OTH_RIGHT", "Libertarian", 1, surname = paste0("LiberalDemocrats", 1:10)),
    mk("xx2024", 2024, "IND", "Independent", 1, seat = "Seat 1"))
  if (ta_stands) tgt <- rbind(tgt, mk("xx2024", 2024, "OTH", "Territory Alliance", 1))
  rbind(prev, tgt)
}
dp_st_a <- c(ALP = 40, LNP = 30, OTH = 18, OTH_RIGHT = 9, IND = 3)

test_that("the switch validates and is listed as a post-xgb switch", {
  withr::local_envvar(AUSPOL_LEVEL_DEAD_PARTY = "")
  expect_identical(level_dead_party_mode(), "0")
  withr::local_envvar(AUSPOL_LEVEL_DEAD_PARTY = "yes")
  expect_error(level_dead_party_mode(), "must be")
  withr::local_envvar(AUSPOL_LEVEL_DEAD_PARTY = "flow")
  expect_identical(level_dead_party_mode(), "flow")
  expect_true("AUSPOL_LEVEL_DEAD_PARTY" %in% names(post_xgb_switches()))
})

test_that("off, both steps are the identity (byte-identical default)", {
  lv <- c(ALP = 30, LNP = 40, OTH = 15, GRN = 15)
  expect_identical(dead_party_prior(dp_st_a, "xx2024", corpus = dp_corpus(), mode = "0"), dp_st_a)
  expect_identical(dead_class_keep(lv, c("ALP", "LNP", "GRN"), mode = "0"), lv[c("ALP", "LNP", "GRN")])
})

test_that("a party that does not stand is found; renamed, abbreviated and partial ones are judged right", {
  D <- dead_party_table("xx2024", corpus = dp_corpus())
  get <- function(p) D[D$party == p]
  expect_equal(get("Territory Alliance")$dead_share, 14)          # 140 of 1000 votes, stands nowhere
  expect_equal(get("Family First Victoria")$dead_share, 0)        # name variant
  expect_equal(get("Animal Justice Party")$contest, 0.5)          # "AJP" in 5 of its 10 seats
  expect_equal(get("Animal Justice Party")$dead_share, 2)
  expect_identical(get("Liberal Democrats")$successor, "Libertarian")   # same people, new name
  expect_equal(get("Liberal Democrats")$dead_share, 0)
  expect_false(any(D$party == "Independent"))                      # individuals are not parties
  # IND as a class still stands (one seat): judged at the class level only when nobody stands
  expect_equal(get("ALP")$dead_share, 0)
  # DELIBERATELY BROKEN: when TA does stand, its dead share must go to zero -- the check above is not vacuous
  D2 <- dead_party_table("xx2024", corpus = dp_corpus(ta_stands = TRUE))
  expect_equal(D2$dead_share[D2$party == "Territory Alliance"], 0)
})

test_that("pro rata: the dead share leaves its class and the total is kept", {
  r <- dp_quiet(dead_party_prior(dp_st_a, "xx2024", corpus = dp_corpus(), mode = "pro"))
  expect_equal(sum(r), sum(dp_st_a))
  # OTH corpus share 18 of which TA 14 and AJP 2 are dead -> 16/18 of st_a's 18 removed
  removed <- 18 * 16 / 18
  expect_equal(unname(attr(r, "moved")[["OTH"]]), removed)
  base <- dp_st_a; base[["OTH"]] <- base[["OTH"]] - removed
  # OTH still stands (AJP in five seats), so it takes its pro rata part back
  expect_equal(unname(r[["ALP"]]), 40 + removed * 40 / sum(base))
  expect_lt(r[["OTH"]], 18)
})

test_that("flows: the dead share goes where the class's preferences went, standing classes only", {
  fl <- list(pooled = list(OTH = c(LNP = 60, ALP = 30, GRN = 10)))   # GRN does not stand at the target
  r <- dp_quiet(dead_party_prior(dp_st_a, "xx2024", corpus = dp_corpus(), flows = fl, mode = "flow"))
  removed <- 16
  expect_equal(unname(r[["LNP"]]), 30 + removed * 60 / 90)
  expect_equal(unname(r[["ALP"]]), 40 + removed * 30 / 90)
  expect_false("GRN" %in% names(r))
  expect_equal(sum(r), sum(dp_st_a))
  # no flow row for the class: falls back to pro rata and says so
  log <- utils::capture.output(dead_party_prior(dp_st_a, "xx2024", corpus = dp_corpus(), flows = list(pooled = list()), mode = "flow"))
  expect_true(any(grepl("pro rata \\(no flow row\\)", log)))
})

test_that("a class with no candidate anywhere gives its level to the standing classes instead of being dropped", {
  lv <- c(ALP = 30, LNP = 40, OTH = 15, GRN = 15)
  r <- dp_quiet(dead_class_keep(lv, c("ALP", "LNP", "GRN"), flows = list(pooled = list(OTH = c(LNP = 75, ALP = 25))), mode = "flow"))
  expect_equal(sum(r), 100)
  expect_equal(unname(r[c("ALP", "LNP", "GRN")]), c(30 + 15 * 0.25, 40 + 15 * 0.75, 15))
  p <- dp_quiet(dead_class_keep(lv, c("ALP", "LNP", "GRN"), mode = "pro"))
  expect_equal(unname(p), unname(lv[c("ALP", "LNP", "GRN")] * 100 / 85))
})

test_that("no nomination evidence: nothing is judged dead and DPL0! says so", {
  C <- dp_corpus(); C <- C[C$election != "xx2024", ]
  log <- utils::capture.output(r <- dead_party_prior(dp_st_a, "xx2024", corpus = C, mode = "flow"))
  expect_identical(r, dp_st_a)
  expect_true(any(grepl("^DPL0!", log)))
  # a target listed with zero votes and no pcv (a provisional list, as vic2026 is) is not evidence either
  C2 <- dp_corpus(); C2$votes[C2$election == "xx2024"] <- 0
  log2 <- utils::capture.output(r2 <- dead_party_prior(dp_st_a, "xx2024", corpus = C2, mode = "flow"))
  expect_identical(r2, dp_st_a)
})

test_that("the live forecast does nothing until the final nomination list is opened", {
  withr::local_envvar(AUSPOL_LEVEL_DEAD_PARTY = "flow", AUSPOL_NOM_LIVE = "auto")
  log <- utils::capture.output(s <- dead_party_live_standing(sprintf("Seat %d", 1:10), "xx2024", "xx2020", corpus = dp_corpus()))
  expect_null(s)
  expect_true(any(grepl("^DPL0!.*no final nomination list", log)))
  withr::local_envvar(AUSPOL_LEVEL_DEAD_PARTY = "0")
  expect_null(dead_party_live_standing(sprintf("Seat %d", 1:10), "xx2024", "xx2020", corpus = dp_corpus()))
})

test_that("party-name matching: variants match, different parties do not", {
  expect_true(dead_party_same("Family First Victoria Inc.", "Family First"))
  expect_true(dead_party_same("Animal Justice Party", "AJP"))
  expect_true(dead_party_same("CA", "Australian Country Alliance"))
  expect_true(dead_party_same("Christian Democratic Party (Fred Nile Group)", "Christian Democratic Party"))
  expect_false(dead_party_same("Territory Alliance", "Socialist Alliance"))
  expect_false(dead_party_same("Palmer United Party", "United Australia Party"))
  expect_false(dead_party_same("Liberal Democrats", "Libertarian"))   # caught by the candidates, not the name
})

test_that("a carried level loses only the carried part of its dead share; a polled level keeps it", {
  lv <- c(ALP = 40, LNP = 30, OTH = 18, OTH_RIGHT = 9, IND = 3)
  expect_identical(dead_party_level(lv, "xx2024", corpus = dp_corpus(), mode = "0"), lv)
  # fully carried (no polls): OTH loses 16/18 of its level
  r1 <- dp_quiet(dead_party_level(lv, "xx2024", carried = c(OTH = 1), corpus = dp_corpus(), mode = "pro"))
  expect_equal(unname(attr(r1, "moved")[["OTH"]]), 16)
  expect_equal(sum(r1), 100)
  # fully polled: nothing moves (the polls already know who stands)
  r0 <- dp_quiet(dead_party_level(lv, "xx2024", carried = c(OTH = 0, ALP = 0, LNP = 0, OTH_RIGHT = 0, IND = 0),
                                  corpus = dp_corpus(), mode = "pro"))
  expect_equal(as.numeric(r0), as.numeric(lv))
  # half carried: half of it
  rh <- dp_quiet(dead_party_level(lv, "xx2024", carried = c(OTH = 0.5), corpus = dp_corpus(), mode = "pro"))
  expect_equal(unname(attr(rh, "moved")[["OTH"]]), 8)
})

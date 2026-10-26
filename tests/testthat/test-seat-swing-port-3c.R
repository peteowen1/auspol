# AUSPOL_SEAT_SWING_PORT_3C: the port's federal swing cleaned where the
# Coalition's federal candidate line-up changed.
# docs/plans/prereg-seat-swing-port-3c-2026-10-25.md

test_that("both switches parse strictly and default off", {
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = NA, AUSPOL_SEAT_SWING_PORT_3C_W = NA)
  expect_identical(seat_swing_port_3c_mode(), "0")
  expect_identical(seat_swing_port_3c_w(), 0)
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = "3")
  expect_error(seat_swing_port_3c_mode(), "must be")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = "yes")
  expect_error(seat_swing_port_3c_mode(), "must be")
  for (bad in c("-0.1", "1.5", "half")) {
    withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C_W = bad)
    expect_error(seat_swing_port_3c_w(), "must be a number")
  }
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C_W = "0.5")
  expect_identical(seat_swing_port_3c_w(), 0.5)
})

test_that("a line-up change is a different count, or a different single party; the merged LNP is neither", {
  now  <- c("LP+NP", "NP", "LP",  "LP", "LP+NP", "",   "LP", "LP+NP", NA,   "LNP",   "LNP", "")
  prev <- c("LP",    "LP", "LNP", "LP", "LNP",   "LP", "",   "LP+NP", "LP", "LP+NP", "",    "LNP")
  expect_identical(coalition_lineup_changed(now, prev),
                   c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, NA, FALSE, TRUE, TRUE))
  # The 2010 Queensland merger: a 2007 LP+NP contest against a 2010 LNP one is unchanged.
})

test_that("fed_coalition_lineup counts Coalition candidates per division and keeps divisions with none", {
  cand <- data.table::data.table(
    region = c("fed", "fed", "fed", "fed", "fed", "vic"),
    year = c(2025L, 2025L, 2025L, 2010L, 2025L, 2025L),
    seat = c("Bendigo", "Bendigo", "Bendigo", "Ryan", "Kennedy", "Bendigo West"),
    party = c("LNP", "LNP", "ALP", "LNP", "IND", "LNP"),
    party_ab = c("NP", "LP", "ALP", "LNQ", "KAP", "NP"))
  ly <- fed_coalition_lineup(cand)
  expect_equal(nrow(ly), 3L)                                # the state row is not federal
  expect_identical(ly$lineup[ly$division == normalise_seat("Bendigo")], "LP+NP")
  expect_identical(ly$lineup[ly$division == normalise_seat("Ryan")], "LNP")   # LNQ is the LNP
  expect_identical(ly$n_coal[ly$division == normalise_seat("Kennedy")], 0L)
})

# 30 booths, one per seat; seats 1-10 in division d1, 11-20 in d2, 21-30 in d3.
mk_share_inputs <- function() {
  bm <- data.table::data.table(district = sprintf("seat%02d", 1:30), place_id = 1:30)
  now <- data.table::data.table(place_id = 1:30, division = normalise_seat(rep(c("d1", "d2", "d3"), each = 10)), tot = 1000)
  ly <- data.table::data.table(year = rep(c(2022L, 2025L), each = 3), division = rep(c("d1", "d2", "d3"), 2),
                               n_coal = 1L, lineup = c("LP", "LP", "LP", "LP+NP", "LP", "LP"))
  list(bm = bm, now = now, prev = data.table::copy(now), ly = ly)
}

test_that("the affected share is the vote share of booths whose own earlier contest had another line-up", {
  z <- mk_share_inputs()
  sh <- seat_swing_port_3c_share("vic", 2026, 2025, z$ly, z$bm, z$now, z$prev)
  expect_equal(sh$frac[sh$s %in% sprintf("seat%02d", 1:10)], rep(1, 10))
  expect_equal(sh$frac[sh$s %in% sprintf("seat%02d", 11:30)], rep(0, 20))
  expect_equal(nrow(attr(sh, "changed")), 1L)
  # Deliberately broken: the same booths with an UNCHANGED line-up must give
  # zero everywhere -- the check is not just flagging every booth.
  ly0 <- data.table::copy(z$ly); ly0$lineup[4] <- "LP"
  expect_true(all(seat_swing_port_3c_share("vic", 2026, 2025, ly0, z$bm, z$now, z$prev)$frac == 0))
  # A booth redistributed INTO d1 from d2 compares with d2's earlier contest.
  prev <- data.table::copy(z$prev); prev$division[1] <- normalise_seat("d2")
  ly2 <- data.table::copy(z$ly); ly2$lineup[2] <- "LP+NP"   # d2 was three-cornered in 2022
  sh2 <- seat_swing_port_3c_share("vic", 2026, 2025, ly2, z$bm, z$now, prev)
  expect_equal(sh2$frac[sh2$s == "seat01"], 0)              # LP+NP then (d2) and LP+NP now (d1): no change
  expect_equal(sh2$frac[sh2$s == "seat02"], 1)
  expect_true(all(sh2$frac[sh2$s %in% sprintf("seat%02d", 11:20)] == 1))
  # Vote weighting: two booths in one seat, one affected with 3x the votes.
  bm <- data.table::data.table(district = c("x", "x"), place_id = c(1L, 11L))
  sh3 <- seat_swing_port_3c_share("vic", 2026, 2025, z$ly, bm, transform(z$now, tot = ifelse(place_id == 1L, 3000, 1000)), z$prev)
  expect_equal(sh3$frac, 0.75)
  # No earlier federal election in the corpus is an error, not a silent zero.
  expect_error(seat_swing_port_3c_share("vic", 2026, 2025, z$ly[z$ly$year == 2025L], z$bm, z$now, z$prev), "no federal election before")
})

test_that("booths the share cannot weigh or compare are counted, and over the limit stop the run", {
  z <- mk_share_inputs()
  sh <- seat_swing_port_3c_share("vic", 2026, 2025, z$ly, z$bm, z$now, z$prev)
  expect_identical(attr(sh, "n_booths"), 30L)
  expect_identical(attr(sh, "n_not_in_now"), 0L)
  expect_identical(attr(sh, "n_no_votes"), 0L)
  expect_equal(attr(sh, "new"), 0)
  # (a) Map booths absent from the federal two-party file: the old code gave
  # them tot = NA and dropped them from both sides of the share, unreported.
  # 1 of 30 (3.3%) is over the 2% limit.
  expect_error(seat_swing_port_3c_share("vic", 2026, 2025, z$ly, z$bm, z$now[z$now$place_id != 5L], z$prev),
               "not_in_now 3.3% > 2%")
  # Under the limit it is reported, not hidden: 1 of 60 booths.
  bm60 <- rbind(z$bm, data.table::data.table(district = sprintf("seat%02d", 1:30), place_id = 101:130))
  now60 <- rbind(z$now, data.table::data.table(place_id = 101:130, division = z$now$division, tot = 1000))
  sh60 <- seat_swing_port_3c_share("vic", 2026, 2025, z$ly, bm60, now60[now60$place_id != 105L], now60)
  expect_identical(attr(sh60, "n_not_in_now"), 1L)
  # Zero-vote booths: counted, and 2 of 30 (6.7%) is over the 5% limit.
  nv <- data.table::copy(z$now); nv$tot[1:2] <- 0
  expect_error(seat_swing_port_3c_share("vic", 2026, 2025, z$ly, z$bm, nv, z$prev), "no_votes 6.7% > 5%")
  # (c) Booths with no earlier-election match: their vote share is reported,
  # and above 30% the run stops.
  sh_new <- seat_swing_port_3c_share("vic", 2026, 2025, z$ly, z$bm, z$now, z$prev[z$prev$place_id > 3L])
  expect_equal(attr(sh_new, "new"), 0.1)
  expect_error(seat_swing_port_3c_share("vic", 2026, 2025, z$ly, z$bm, z$now, z$prev[z$prev$place_id > 15L]), "new 50.0% > 30%")
})

test_that("(d) a state seat missing from the share table stops the cleaning instead of getting frac 0", {
  fs <- data.table::data.table(seat = c("a", "b", "Seat C"), fed_swing = c(1, 2, 3), region = "vic", cycle = 2026L, fed = 2025L)
  share <- function(rg, cy, fy, ly) {
    out <- data.table::data.table(s = c("a", "b"), frac = c(1, 0), divisions = c("x", ""))
    attr(out, "changed") <- data.table::data.table(prev_division = "x", division = "x", prev = "LP", now = "LP+NP")
    attr(out, "unknown") <- 0
    out
  }
  expect_error(seat_swing_port_3c_clean(fs, w = 0, lineup = data.table::data.table(), share_fun = share),
               "1 of 3 seats have no booth in the line-up share table \\(Seat C\\)")
})

test_that("cleaning moves an affected seat to the cycle mean at w = 0, halves it at 0.5, leaves it at 1", {
  fs <- data.table::data.table(seat = c("a", "b", "c", "d"), fed_swing = c(10, 0, 2, 4), region = "vic", cycle = 2026L, fed = 2025L)
  share <- function(rg, cy, fy, ly) {
    out <- data.table::data.table(s = c("a", "b", "c", "d"), frac = c(1, 0.5, 0, 0), divisions = c("x", "x", "", ""))
    attr(out, "changed") <- data.table::data.table(prev_division = "x", division = "x", prev = "LP", now = "LP+NP")
    attr(out, "unknown") <- 0
    out
  }
  m <- mean(fs$fed_swing)
  log <- utils::capture.output(c0 <- seat_swing_port_3c_clean(fs, w = 0, lineup = data.table::data.table(), share_fun = share))
  expect_match(log, "^S3C1 vic2026 <- fed2025: 1 Coalition line-up change.*x LP->LP\\+NP.*2 of 4 seats touched; largest: a 100%, b 50%")
  expect_equal(c0$fed_swing, c(m, m + 0.5 * (0 - m), 2, 4))
  expect_equal(c0$fed_swing_raw, fs$fed_swing)
  utils::capture.output(c5 <- seat_swing_port_3c_clean(fs, w = 0.5, lineup = data.table::data.table(), share_fun = share))
  expect_equal(c5$fed_swing[1], m + 0.5 * (10 - m))
  utils::capture.output(c1 <- seat_swing_port_3c_clean(fs, w = 1, lineup = data.table::data.table(), share_fun = share))
  expect_equal(c1$fed_swing, fs$fed_swing)
  expect_error(seat_swing_port_3c_clean(fs[, !"fed"], w = 0, lineup = data.table::data.table(), share_fun = share), "no `fed` column")
})

test_that("the fitted weight is near 0 when the affected part does not carry over and near 1 when it does", {
  set.seed(11)
  mk <- function(b_a) {
    data.table::rbindlist(lapply(1:6, function(g) {
      dev <- stats::rnorm(80, 0, 3); frac <- rep(c(0, 1), c(60, 20))
      data.table::data.table(pair = paste0("c", g), dev = dev, frac = frac,
                             yy = 0.5 * (1 - frac) * dev + b_a * frac * dev + stats::rnorm(80, 0, 0.5))
    }))
  }
  none <- seat_swing_port_3c_fit_w(mk(0))
  full <- seat_swing_port_3c_fit_w(mk(0.5))
  expect_lt(none$w, 0.1)
  expect_gt(full$w, 0.85)
  expect_equal(none$n_aff, 120L)
  # No affected rows: nothing to fit, exclusion by default.
  expect_equal(seat_swing_port_3c_fit_w(mk(0)[frac == 0])$w, 0)
  # Every row fully affected: the unaffected column is all zero (rank 1), so 0,
  # whatever the scale of the deviations (the old det() test depended on it).
  all_aff <- mk(0.5); all_aff$frac <- 1
  expect_equal(seat_swing_port_3c_fit_w(all_aff)$w, 0)
  tiny <- mk(0.5); tiny$dev <- tiny$dev * 1e-4; tiny$yy <- tiny$yy * 1e-4
  expect_gt(seat_swing_port_3c_fit_w(tiny)$w, 0.85)   # det(XtX) ~ 1e-9 here, but the fit is fine
})

# ---- end to end through seat_swing_port_coef / _table on a synthetic disk ----
# vic2018 <- fed2016 (d1 changed LP -> LP+NP) and vic2022 <- fed2022 (d2 changed
# LP -> NP). The planted state swing carries 0.5 of the unaffected deviation and
# none of the affected one, so cleaning must move the fitted slope toward 0.5.
local_3c_fixture <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  for (d in c("output", "elections", file.path("external", "reference", "aec", "booths")))
    dir.create(file.path(root, d), recursive = TRUE)
  writeLines("Package: fixture", file.path(root, "DESCRIPTION"))
  withr::local_options(auspol.root = root, auspol.elections_dir = file.path(root, "elections"), .local_envir = env)
  set.seed(5)
  seats <- sprintf("seat%02d", 1:30)
  divs <- rep(c("d1", "d2", "d3"), each = 10)
  fs <- data.table::data.table(seat = rep(seats, 2), fed_swing = stats::rnorm(60, 2, 3), region = "vic",
                               cycle = rep(c(2018L, 2022L), each = 30), fed = rep(c(2016L, 2022L), each = 30))
  aff <- list("vic2018" = divs == "d1", "vic2022" = divs == "d2")
  tpp <- data.table::rbindlist(lapply(c("vic2014", "vic2018", "vic2022"), function(e) data.table::data.table(s = seats, tpp = 50, election = e)))
  for (z in list(c("vic2018", "vic2014"), c("vic2022", "vic2018"))) {
    f <- fs[paste0(fs$region, fs$cycle) == z[1]]
    dev <- f$fed_swing - mean(f$fed_swing)
    tpp$tpp[tpp$election == z[1]] <- tpp$tpp[tpp$election == z[2]] + 0.5 * dev * (1 - aff[[z[1]]]) + stats::rnorm(30, 0, 0.3)
  }
  data.table::fwrite(tpp, file.path(root, "output", "seat-tpp-estimates.csv"))
  data.table::fwrite(fs, file.path(root, "elections", "fed-swing-transposed.csv"))
  data.table::fwrite(data.table::data.table(region = "vic", cycle = rep(c(2018L, 2022L), each = 30), fed = rep(c(2016L, 2022L), each = 30),
                                            district = rep(seats, 2), place_id = rep(1:30, 2)),
                     file.path(root, "elections", "fed-booth-map.csv"))
  for (y in c(2013L, 2016L, 2019L, 2022L)) {
    f <- file.path(root, "external", "reference", "aec", "booths", sprintf("tpp-fed%d.csv", y))
    writeLines("Fixture two-party by polling place", f)
    data.table::fwrite(data.table::data.table(DivisionNm = divs, PollingPlaceID = 1:30, TotalVotes = 1000), f, append = TRUE, col.names = TRUE)
  }
  lu <- c("2013" = "LP", "2016" = "LP+NP", "2019" = "LP", "2022" = "NP")
  cand <- data.table::rbindlist(lapply(names(lu), function(y) data.table::rbindlist(lapply(c("d1", "d2", "d3"), function(d) {
    ab <- if ((y == "2016" && d == "d1") || (y == "2022" && d == "d2")) strsplit(lu[[y]], "+", fixed = TRUE)[[1]] else "LP"
    data.table::data.table(region = "fed", year = as.integer(y), seat = d, party = c(rep("LNP", length(ab)), "ALP"), party_ab = c(ab, "ALP"))
  }))))
  data.table::fwrite(cand, file.path(root, "output", "candidacies.csv"))
  invisible(root)
}

test_that("off is byte-identical to unset; on, the fit and the target are both cleaned", {
  local_3c_fixture()
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_NOCLIFF = "1", AUSPOL_SEAT_SWING_PORT_WA = "0", AUSPOL_SEAT_SWING_PORT_3C = NA)
  unset <- seat_swing_port_coef("vic2022"); t_unset <- seat_swing_port_table("vic2022")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = "0")
  expect_identical(seat_swing_port_coef("vic2022"), unset)
  expect_identical(seat_swing_port_table("vic2022"), t_unset)
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = "1")
  log <- utils::capture.output(on <- seat_swing_port_coef("vic2022"))
  expect_true(any(grepl("^S3C1 vic2018 <- fed2016: 1 Coalition line-up change.*d1 LP->LP\\+NP.*10 of 30 seats touched", log)))
  expect_gt(on$b, unset$b)                          # the planted 0.5 is closer once affected seats stop diluting it
  expect_lt(abs(on$b - 0.5), abs(unset$b - 0.5))
  expect_identical(on$w3c, 0)
  utils::capture.output(tb <- seat_swing_port_table("vic2022"))
  raw <- t_unset$fed_swing
  expect_equal(tb$fed_swing[11:20], rep(mean(raw), 10))   # target's affected seats (d2) sit at the cycle mean
  expect_equal(tb$fed_swing[-(11:20)], raw[-(11:20)])
  # Mode 2 fits a weight on the same earlier cycle and reports it.
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = "2")
  log2 <- utils::capture.output(m2 <- seat_swing_port_coef("vic2022"))
  expect_true(any(grepl("^S3C2 vic2022: line-up weight fitted on 1 earlier cycles: 10 affected seat rows", log2)))
  expect_lt(m2$w3c, 0.2)
})

test_that("a shipped table written under one 3C setting refuses to be read under another", {
  root <- local_3c_fixture()
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_NOCLIFF = "1", AUSPOL_SEAT_SWING_PORT_WA = "0", AUSPOL_SEAT_SWING_PORT_3C = "1")
  utils::capture.output(src <- seat_swing_port_table("vic2022", write = TRUE))
  withr::local_options(auspol.elections_dir = file.path(root, "no-elections"))
  utils::capture.output(back <- seat_swing_port_table("vic2022"))
  expect_equal(back$fed_swing, src$fed_swing)
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = "0")
  expect_error(seat_swing_port_table("vic2022"), "AUSPOL_SEAT_SWING_PORT_3C=1 but this run has 0")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_3C = "1", AUSPOL_SEAT_SWING_PORT_3C_W = "0.5")
  expect_error(seat_swing_port_table("vic2022"), "AUSPOL_SEAT_SWING_PORT_3C_W=0 but this run has 0.5")
})

# ---- the real data: federal Bendigo 2025 (skips on CI) ----
test_that("vic2026: federal Bendigo's 2025 three-cornered contest puts Bendigo West wholly in the affected share", {
  skip_if_not(file.exists(out_path("candidacies.csv")), "no candidate corpus")
  skip_if_not(file.exists(election_data_path("fed-booth-map.csv")), "no booth map")
  skip_if_not(file.exists(file.path(pkg_root(), "external", "reference", "aec", "booths", "tpp-fed2025.csv")), "no booth file")
  ly <- fed_coalition_lineup()
  expect_identical(ly$lineup[ly$year == 2025L & ly$division == normalise_seat("Bendigo")], "LP+NP")
  expect_identical(ly$lineup[ly$year == 2022L & ly$division == normalise_seat("Bendigo")], "LP")
  sh <- seat_swing_port_3c_share("vic", 2026, 2025, ly)
  bw <- sh[sh$s == normalise_seat("Bendigo West")]
  expect_equal(bw$frac, 1)
  expect_match(bw$divisions, "bendigo")
  expect_gt(sh$frac[sh$s == normalise_seat("Bendigo East")], 0.9)
  # Queensland's 2008 merger is not a candidate change.
  expect_true(all(seat_swing_port_3c_share("qld", 2024, 2022, ly)$frac == 0))
})

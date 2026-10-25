# Audit F8 arms: AUSPOL_POSTXGB_RESID_NET and AUSPOL_SEAT_SWING_PORT_RESID.
# docs/plans/prereg-postxgb-resid-net-2026-10-25.md

fake_preds <- function() {
  mk <- function(el, seat, alp, lnp, oth, a_alp, a_lnp, a_oth) {
    data.table::data.table(election = el, seat = seat, party = c("ALP", "LNP", "OTH"),
                           xgb_pred_seat = c(alp, lnp, oth), actual_share = c(a_alp, a_lnp, a_oth))
  }
  data.table::rbindlist(list(
    mk("fed2022", "Aston", 40, 45, 15, 42, 43, 15),
    mk("vic2018", "Kew", 30, 55, 15, 35, 50, 15),
    mk("vic2018", "Bendigo East", 50, 35, 15, 48, 37, 15),
    mk("wa2017", "Albany", 45, 40, 15, 50, 35, 15)
  ))
}

test_that("both switches parse strictly and default off", {
  withr::local_envvar(AUSPOL_POSTXGB_RESID_NET = NA, AUSPOL_SEAT_SWING_PORT_RESID = NA)
  expect_false(postxgb_resid_net_on())
  expect_false(seat_swing_port_resid_on())
  withr::local_envvar(AUSPOL_POSTXGB_RESID_NET = "1", AUSPOL_SEAT_SWING_PORT_RESID = "1")
  expect_true(postxgb_resid_net_on())
  expect_true(seat_swing_port_resid_on())
  withr::local_envvar(AUSPOL_POSTXGB_RESID_NET = "yes", AUSPOL_SEAT_SWING_PORT_RESID = "2")
  expect_error(postxgb_resid_net_on(), "must be")
  expect_error(seat_swing_port_resid_on(), "must be")
})

test_that("seat_swing_port_on is the gate seat_swing_port_apply used before the refactor", {
  old_gate <- function(t) {
    if (sub("[0-9]{4}$", "", t) == "wa") return(!identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT_WA", "2"), "0"))
    identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "2"), "2")
  }
  for (p in c(NA, "0", "1", "2")) for (w in c(NA, "0", "1", "2", "3")) {
    withr::local_envvar(AUSPOL_SEAT_SWING_PORT = p, AUSPOL_SEAT_SWING_PORT_WA = w)
    for (t in c("vic2022", "wa2017", "nt2020", "nsw2023"))
      expect_identical(seat_swing_port_on(t), old_gate(t), info = paste(p, w, t))
  }
})

test_that("postxgb_net_port moves Labor and Coalition by adj in state seats only", {
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "2", AUSPOL_SEAT_SWING_PORT_WA = "2")
  called <- character(0)
  adj_fun <- function(el, seats) { called <<- c(called, el); rep(2, length(seats)) }
  x <- fake_preds()
  out <- NULL
  log <- utils::capture.output(out <- postxgb_net_port(x, adj_fun))
  expect_match(log, "^PXN1 .*2 state elections checked, 2 with a non-zero port \\(vic2018,wa2017\\), 3 seats netted, mean \\|adj\\| 2.000; 0 seats skipped")
  # Every election is netted with ITS OWN port (fitted on cycles before it), never fed's.
  expect_setequal(called, c("vic2018", "wa2017"))
  fed_in <- x[x$election == "fed2022"]; fed_out <- out[out$election == "fed2022"]
  expect_identical(fed_out$xgb_pred_seat, fed_in$xgb_pred_seat)
  kew <- out[out$seat == "Kew"]
  expect_equal(kew$xgb_pred_seat, c(32, 53, 15))
  expect_equal(out[, sum(xgb_pred_seat), by = c("election", "seat")]$V1, rep(100, 4))
  expect_identical(out$actual_share, x$actual_share)
  expect_identical(x$xgb_pred_seat[x$seat == "Kew"], c(30, 55, 15))   # input not modified
})

test_that("postxgb_net_port leaves WA alone when the WA port is off, and clips at zero", {
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "2", AUSPOL_SEAT_SWING_PORT_WA = "0")
  out <- NULL
  utils::capture.output(out <- postxgb_net_port(fake_preds(), function(el, seats) rep(-60, length(seats))))
  expect_identical(out[out$election == "wa2017"]$xgb_pred_seat, c(45, 40, 15))
  kew <- out[out$seat == "Kew"]                     # ALP 30 - 60 clips to 0, LNP 115, renormalised
  expect_equal(kew$xgb_pred_seat, 100 * c(0, 115, 15) / 130)
})

test_that("postxgb_net_port refuses an adjustment that is not one finite number per seat", {
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "2")
  expect_error(utils::capture.output(postxgb_net_port(fake_preds(), function(el, s) rep(NA_real_, length(s)))),
               "not one finite number per seat")
  expect_error(utils::capture.output(postxgb_net_port(fake_preds(), function(el, s) 1)),
               "not one finite number per seat")
})

test_that("postxgb_net_port counts a seat with no Coalition row as skipped, not netted", {
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "2", AUSPOL_SEAT_SWING_PORT_WA = "0")
  x <- fake_preds()
  x <- x[!(x$seat == "Kew" & x$party == "LNP")]
  out <- NULL
  log <- utils::capture.output(out <- postxgb_net_port(x, function(el, s) rep(1, length(s))))
  expect_match(log, "1 state elections checked, 1 with a non-zero port \\(vic2018\\), 1 seats netted.*1 seats skipped")
  expect_identical(out[out$seat == "Kew"]$xgb_pred_seat, c(30, 15))
})

test_that("a zero port adjustment leaves the rows exactly as they were (no renormalisation noise)", {
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT = "2", AUSPOL_SEAT_SWING_PORT_WA = "2")
  x <- fake_preds()
  x$xgb_pred_seat[x$seat == "Kew"] <- c(30.1, 55.2, 14.7) / 1.0000001   # not summing to exactly 100
  out <- NULL
  log <- utils::capture.output(out <- postxgb_net_port(x, function(el, s) rep(0, length(s))))
  expect_identical(out$xgb_pred_seat, x$xgb_pred_seat)
  expect_match(log, "0 with a non-zero port \\(\\), 0 seats netted")
})

test_that("seat_swing_port_resid_table is the two-party miss, in the port's units", {
  rt <- seat_swing_port_resid_table(fake_preds())
  # Kew: ALP missed by +5, LNP by -5 -> (5 - -5) / 2 = 5; Bendigo East (-2 - 2) / 2 = -2.
  expect_equal(rt$resid[rt$s == "kew"], 5)
  expect_equal(rt$resid[rt$s == "bendigoeast"], -2)
  expect_equal(nrow(rt), 4L)
})

test_that("seat_swing_port_resid_table fails on broken input instead of summing it", {
  x <- fake_preds()
  expect_error(seat_swing_port_resid_table(rbind(x, x[1])), "duplicate")
  expect_error(seat_swing_port_resid_table(x[, !"actual_share"]), "lack actual_share")
  expect_error(seat_swing_port_resid_table(NULL), "as-at seat predictions")
})

test_that(".port_resid_rows demeans within the cycle and needs five seats", {
  rt <- data.table::data.table(election = "vic2018", s = letters[1:6], resid = c(1, 2, 3, 4, 5, NA))
  fs <- data.table::data.table(seat = LETTERS[1:6], fed_swing = c(2, 2, 2, 4, 4, 4), label = "vic2018")
  m <- .port_resid_rows(rt, fs, "vic2018", "vic")
  expect_equal(nrow(m), 5L)                          # the NA residual is dropped
  expect_equal(mean(m$yy), 0)
  expect_equal(mean(m$dev), 0)
  expect_null(.port_resid_rows(rt[1:4], fs, "vic2018", "vic"))
  expect_null(.port_resid_rows(rt, fs, "vic2022", "vic"))
})

test_that("current_seat_predictions at the default is the un-netted table (byte-identical)", {
  skip_if_not(file.exists(out_path("xgb-primary-asat-predictions.csv")), "no rebuild outputs")
  withr::local_envvar(AUSPOL_POSTXGB_RESID_NET = NA)
  expect_identical(current_seat_predictions(), .current_seat_predictions_raw())
})

test_that("the residual port fit stays time-forward and differs from the default", {
  skip_if_not(file.exists(out_path("seat-tpp-estimates.csv")), "no seat TPP estimates")
  skip_if_not(file.exists(out_path("xgb-primary-asat-predictions.csv")), "no rebuild outputs")
  skip_if_not(file.exists(file.path(election_data_path(), "fed-swing-transposed.csv")),
              "no transposed federal swing")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_RESID = "0", AUSPOL_SEAT_SWING_PORT_NOCLIFF = "1")
  def <- seat_swing_port_coef("nsw2023")
  withr::local_envvar(AUSPOL_SEAT_SWING_PORT_RESID = "1")
  log <- utils::capture.output(res <- seat_swing_port_coef("nsw2023"))
  expect_match(log, "^PXR1 nsw2023")
  used <- strsplit(sub(".*predictions \\(([^)]*)\\).*", "\\1", log), ",")[[1]]
  expect_true(length(used) > 0)
  expect_true(all(elections_before(used, "nsw2023")))
  expect_false(isTRUE(all.equal(res$b, def$b)))
})

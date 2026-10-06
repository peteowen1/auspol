has_polls <- function() file.exists(file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv"))

# A throwaway package root holding a candidate list and (optionally) as-at predictions.
fake_root <- function(preds = NULL) {
  r <- withr::local_tempdir(.local_envir = parent.frame())
  writeLines("Package: x", file.path(r, "DESCRIPTION"))
  dir.create(file.path(r, "output"))
  data.table::fwrite(data.table::data.table(
    election = "fedT", seat = c("Aaa", "Bbb", "Ccc", "Ddd"), party = c("IND", "IND", "IND", "ALP")),
    file.path(r, "output", "candidacies.csv"))
  # Aaa and Bbb's independents are endorsed (the credible-contender rule, Amendment 1); Ccc's is not.
  data.table::fwrite(data.table::data.table(pair = "fedT", seat = c("Aaa", "Bbb"), party = "IND", c200 = 1L, voices = 0L),
                     file.path(r, "output", "endorsement-features.csv"))
  if (!is.null(preds)) data.table::fwrite(preds, file.path(r, "output", "forecasts.csv"))
  withr::local_options(auspol.root = r, .local_envir = parent.frame())
  r
}
polls <- function(seat, id, parties, fps) {
  data.table::data.table(seat_name = seat, poll_id = id, party = parties, class = parties, fp = fps)
}

test_that("IND map moves a big OTH to IND only where the poll leaves IND blank and the seat has an IND candidate", {
  fake_root()
  s <- rbind(
    polls("Aaa", "a", c("ALP", "LNP", "IND", "OTH"), c(30, 30, NA, 24)),   # blank IND, big OTH, IND candidate: move
    polls("Bbb", "b", c("ALP", "LNP", "IND", "OTH"), c(30, 30, 20, 8)),    # poll reports IND: leave
    polls("Bbb", "c", c("ALP", "LNP", "OTH"), c(40, 40, 5)),               # small OTH: leave
    polls("Ddd", "d", c("ALP", "LNP", "OTH"), c(30, 30, 24)),              # no IND candidate: leave
    polls("Ccc", "e", c("ALP", "LNP", "IND", "OTH"), c(30, 30, NA, 24)))   # IND neither endorsed nor sitting: leave
  out <- capture.output(r <- .seat_poll_ind_map(s, "fedT"))
  expect_equal(r$class[which(r$poll_id == "a" & r$fp == 24)], "IND")
  expect_equal(r$class[r$poll_id == "e"], s$class[s$poll_id == "e"])
  expect_true(any(grepl("Ccc .*not endorsed and not sitting", out)))
  expect_equal(r$class[r$poll_id == "b"], s$class[s$poll_id == "b"])
  expect_equal(r$class[r$poll_id == "c"], s$class[s$poll_id == "c"])
  expect_equal(r$class[r$poll_id == "d"], s$class[s$poll_id == "d"])
  expect_equal(sum(grepl("^SPIM fedT Aaa .* OTH 24.0 -> IND", out)), 1L)
  # a different election label finds no candidates, so nothing moves (the check can fail)
  expect_identical(suppressWarnings(utils::capture.output(r2 <- .seat_poll_ind_map(s, "fedZ"))), character(0))
  expect_identical(r2$class, s$class)
})

test_that("IND map leaves a seat alone when a known non-major class already explains the OTH (Katter in Kennedy)", {
  fake_root(preds = data.table::data.table(election = "fedT", seat = c("Aaa", "Bbb"), party = "OTH_RIGHT",
                                           xgb_pred_seat = c(40, 4), actual_share = c(45, 3)))
  s <- rbind(polls("Aaa", "a", c("ALP", "LNP", "OTH"), c(30, 30, 40)),
             polls("Bbb", "b", c("ALP", "LNP", "OTH"), c(30, 30, 24)))
  out <- capture.output(r <- .seat_poll_ind_map(s, "fedT"))
  expect_equal(r$class[r$poll_id == "a" & r$fp == 40], "OTH")
  expect_equal(r$class[r$poll_id == "b" & r$fp == 24], "IND")
  expect_true(any(grepl("Aaa .*NOT remapped", out)))
})

test_that("the three switches reject anything but 0/1 and are no-ops at 0", {
  withr::local_envvar(AUSPOL_SEAT_POLL_IND_WEIGHT = "yes")
  expect_error(.ind_weight_on(), "must be")
  withr::local_envvar(AUSPOL_SEAT_POLL_IND_WEIGHT = "0", AUSPOL_SEAT_POLL_HANDKEYED = "2")
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,2"), f)
  expect_error(.read_seat_polls_file(f), "must be")
  withr::local_envvar(AUSPOL_SEAT_POLL_HANDKEYED = "0")
  expect_identical(.read_seat_polls_file(f), data.table::fread(f, showProgress = FALSE))
})

test_that("hand-keyed primaries add Mayo fed2016 and Wakehurst nsw2023 only when asked", {
  skip_if_not(has_polls(), "no seat polls")
  hf <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "hand_keyed_primaries.csv")
  skip_if_not(file.exists(hf), "no hand-keyed file")
  withr::local_envvar(AUSPOL_SEAT_POLL_HANDKEYED = "0")
  off <- seat_poll_shares("fed2016")
  expect_false("Mayo" %in% off$seat)
  withr::local_envvar(AUSPOL_SEAT_POLL_HANDKEYED = "1")
  out <- capture.output(on <- seat_poll_shares("fed2016"))
  m <- on[on$seat == "Mayo"]
  expect_equal(m$poll[m$class == "IND"], 23.5)
  expect_equal(m$poll[m$class == "LNP"], 40)
  expect_true(any(grepl("^SPHK", out)))
  capture.output(nsw <- seat_poll_shares("nsw2023"))
  expect_equal(nsw$poll[nsw$seat == "Wakehurst" & nsw$class == "IND"], 37)
  h <- data.table::fread(hf, showProgress = FALSE)
  expect_true(all(nzchar(h$source)))
  expect_true(all(h$election %in% c("fed2016", "nsw2023")))
})

test_that("IND weight is time-forward, lies between the class-blind weight and 1, and equals it with no IND history", {
  skip_if_not(has_polls() && file.exists(out_path("forecasts.csv")), "no seat polls or forecasts")
  withr::local_envvar(AUSPOL_SEAT_POLL_IND_MAP = "0", AUSPOL_SEAT_POLL_HANDKEYED = "0")
  a <- seat_poll_ind_weight("fed2022")
  expect_equal(a$w, a$w0)   # fed2019's one IND cell cannot support a class-specific weight
  b <- seat_poll_ind_weight("fed2025")
  expect_gte(b$w, 0); expect_lte(b$w, 1)
  expect_gt(b$n, 1L)
  # no peeking: nothing after 2022 is in the fed2025 fit's IND history other than fed2022
  expect_equal(b$k, 1L)
})

test_that("IND weight switch changes only cells with a direct IND poll", {
  skip_if_not(has_polls() && .has_seat_predictions(), "no seat polls or predictions")
  f <- current_seat_predictions()
  d <- f[f$election == "fed2025"]
  m <- data.table::dcast(d, seat ~ party, value.var = "xgb_pred_seat", fill = 0)
  mm <- as.matrix(m[, -1]); rownames(mm) <- m$seat
  withr::local_envvar(AUSPOL_SEAT_POLL_BLEND = "1", AUSPOL_SEAT_POLL_IND_MAP = "0", AUSPOL_SEAT_POLL_HANDKEYED = "0",
                      AUSPOL_SEAT_POLL_IND_WEIGHT = "0")
  capture.output(off <- seat_poll_blend_apply(mm, "fed2025"))
  withr::local_envvar(AUSPOL_SEAT_POLL_IND_WEIGHT = "1")
  out <- capture.output(on <- seat_poll_blend_apply(mm, "fed2025"))
  expect_true(any(grepl("^SPIW fed2025", out)))
  tb <- seat_poll_shares("fed2025", by_type = TRUE)
  dseats <- unique(normalise_seat(tb$seat[tb$class == "IND" & tb$type == "direct"]))
  moved <- rownames(mm)[rowSums(abs(on - off)) > 1e-12]
  expect_gt(length(moved), 0L)
  expect_true(all(normalise_seat(moved) %in% dseats))
})

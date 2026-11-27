# FIT THE ELECTION-NIGHT PROJECTION SD from the three real replayed nights (vic2022 VEC feed, fed2022 and fed2025 AEC feed).
#
#   Rscript scripts/fit_night_projection_sd.R [--data=<repo root holding output/ external/ deciding-runs/>]
#       [--runs=deciding-runs/20261111-0900-night-pair-cal] [--out=<dir for the tables>] [--extract=1] [--cand-ref=copy[,off]]
#       [--nights=vic2022,fed2022,fed2025] [--extract-only=1]
#
# Step 1 (extract; one file per night, <out>/night-proj-errors-<night>.csv, reused unless --extract=1): every snapshot of
# each night goes through the replay scripts' own conversion (night_replay_vec.R: vec_feed_read_lh -> night_booth_table,
# expected votes from the previous election's night turnout; night_replay_feed.R: the AEC polling places reported by each
# clock time), then night_booth_update(keep_proj = TRUE) with reported = the units in, total = "expected" (the live
# night's denominator), gap_k = 5, cand_ref "copy" (the live website setting). No seat is simulated. The federal replay
# script runs total = "projected", which over-states the count; here federal is put on "expected" too (enrolment from the
# AEC feed's division progress, times the previous election's night votes over that enrolment), so all three nights share
# the live definition of counted share. The truth is each seat's final first-preference share by class from the final
# booth table (classify_party()).
#
# Step 2 (fit): projection error sd as a smooth function of counted share, per class group, by Gaussian likelihood:
#   sd^2 = a + (b + c p (1 - p)) / max(cs, 0.002)     (p the projected share as a fraction, cs the counted share)
# with a, b, c >= 0, so the curve falls monotonically with cs and has no cliff. Leave-one-night-out: fit on two nights,
# report the share of the third's errors inside +-1.96 sd. Check codes NPSD1-NPSD7. The fitted constants are copied by
# hand into R/booth_projection.R (.booth_proj_sd_fit) and docs/CONSTANTS.md.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(Sys.getenv("AUSPOL_CODE_DIR", "."), quiet = TRUE) })
cat(sprintf("NRCODE code from %s (data from %s)\n", normalizePath(Sys.getenv("AUSPOL_CODE_DIR", ".")), normalizePath(".")))   # AUSPOL_CODE_DIR: run a branch's code against this checkout's data
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
DR <- flag("data", "."); runs <- file.path(DR, flag("runs", "deciding-runs/20261111-0900-night-pair-cal"))
out_dir <- flag("out", file.path("output", "night-feed", "proj-sd")); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dp <- function(...) file.path(DR, ...)
CR <- strsplit(flag("cand-ref", "copy"), ",")[[1]]   # "copy,off" also records cand_ref off (doubles the time)
NIGHTS <- strsplit(flag("nights", "vic2022,fed2022,fed2025"), ",")[[1]]
redo <- identical(flag("extract", "0"), "1")
# --max-time=HH:MM: stop each night's extraction after this clock time (snapshots grow costlier as booths come in;
# the low-count end the fit is about is all before 9pm)
max_time <- flag("max-time", "99:99")
cat(sprintf("NPSD0 snapshots up to %s, cand_ref %s, nights %s\n", max_time, paste(CR, collapse = ","), paste(NIGHTS, collapse = ",")))
night_f <- function(nm) file.path(out_dir, sprintf("night-proj-errors-%s.csv", nm))   # one per night: a killed run keeps the nights done

truth_of <- function(booths, seats) {
  B <- data.table::copy(booths); B[is.na(votes), votes := 0]
  B[, district := .night_seat_names(district, seats)]
  B[, cls := classify_party(party)]
  T <- B[, list(v = sum(votes)), by = c("district", "cls")]
  T[, final := 100 * v / sum(v), by = "district"]
  T[, final_votes := sum(v), by = "district"]
  T[, list(seat = district, cls, final, final_votes)]
}
# votes in the units already counted, per seat (the same unit key as night_booth_update(): booth for ordinary, else type)
counted_votes <- function(live, reported) {
  L <- data.table::as.data.table(live)[, list(district, unit = ifelse(booth_type == "ordinary", booth, booth_type), v = ifelse(is.na(votes), 0, votes))]
  R0 <- unique(data.table::as.data.table(reported)[, list(district, unit)])
  merge(L, R0, by = c("district", "unit"))[, list(cv = sum(v)), by = "district"]
}
# Lane A switches (docs/plans/prereg-night-lane-a-2026-11-27.md), all off by default: --booth-reg=<k> (A1 booth-level
# swing), --type-pool=<k> (A2 vote-type pooling), --rep-diag=1 (diag columns in the output, no change to projections)
num_or_null <- function(x) if (is.null(x)) NULL else as.numeric(x)
BREG <- num_or_null(flag("booth-reg")); TPOOL <- num_or_null(flag("type-pool")); RDIAG <- identical(flag("rep-diag", "0"), "1")
cat(sprintf("NPSD0A lane A: booth_reg_k %s, type_pool_k %s, proj_diag %s\n", if (is.null(BREG)) "off" else BREG, if (is.null(TPOOL)) "off" else TPOOL, RDIAG))
one_update <- function(st, live, ref, reported, expected, cr) {
  shares <- st$shares
  nu <- night_booth_update(shares, night_prior_sd(shares, st$level_sd, st$level_mult, st$sdo), 1, live, ref,
                           gap_k = 5, reported = reported, total = "expected", expected = expected, cand_ref = cr, keep_proj = TRUE,
                           booth_reg_k = BREG, type_pool_k = TPOOL, proj_diag = RDIAG)
  nu$proj_detail
}
fin <- function(X, tr) {
  X <- merge(X, tr, by = c("seat", "cls"), all.x = TRUE)
  X[is.na(final), final := 0]
  X[, err := proj - final]
  X[, true_cs := cv / final_votes]   # counted votes over the seat's FINAL votes (all types): what was really in
  X
}

# ---- vic2022 (night_replay_vec.R's conversion) ---------------------------------------------------------------------------
if ("vic2022" %in% NIGHTS && (redo || !file.exists(night_f("vic2022")))) {
  t0 <- proc.time()[["elapsed"]]; rows <- list()
  st <- readRDS(file.path(runs, "state-vic2022.rds")); seats <- rownames(st$shares)
  ref <- fread(dp(sprintf("output/booths-vic%d.csv", st$from)), showProgress = FALSE)
  turn <- fread(dp(sprintf("output/council-district-stats-%d.csv", st$from)), showProgress = FALSE)
  ref$district <- .night_seat_names(ref$district, seats); turn$district <- .night_seat_names(turn$district, seats)
  setup <- file.path(runs, "setup"); pl <- night_polling_places(setup); lk <- night_party_lookup(setup)
  if (!is.null(pl) && "district" %in% names(pl)) pl$district <- .night_seat_names(pl$district, seats)
  tr <- truth_of(fread(dp(sprintf("output/booths-vic%d.csv", st$to)), showProgress = FALSE), seats)
  files <- list.files(dp("external/reference/vec/2026/feed-docs/inner22"), pattern = "verboselh_[0-9]{8}_[0-9]{6}\\.xml$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  stamp <- sub(".*verboselh_([0-9]{8}_[0-9]{6})\\.xml$", "\\1", basename(files), ignore.case = TRUE)
  clk <- ifelse(substr(stamp, 1, 8) > "20221126", sprintf("%02d:%s", 24L + as.integer(substr(stamp, 10, 11)), substr(stamp, 12, 13)),
                sprintf("%s:%s", substr(stamp, 10, 11), substr(stamp, 12, 13)))
  keep <- substr(stamp, 1, 8) <= "20221127" & clk <= max_time; files <- files[keep][order(stamp[keep])]; stamp <- sort(stamp[keep])
  cat(sprintf("NPSD1 vic2022: %d seats, %d snapshots %s to %s, cand_ref %s\n", length(seats), length(files), stamp[1], stamp[length(stamp)], paste(CR, collapse = ",")))
  for (k in seq_along(files)) {
    feed <- vec_feed_read_lh(files[k]); feed$contests$district <- .night_seat_names(feed$contests$district, seats)
    conv <- suppressMessages(night_booth_table(feed, lk, pl))
    enr <- stats::setNames(feed$contests$enrolment, sub(" District$", "", feed$contests$district))
    expected <- night_expected_votes(enr, night_turnout_table(turn, ref), "night")
    cvt <- counted_votes(conv$live, conv$counted)
    n_s <- 0L
    for (cr in CR) {
      pd <- one_update(st, conv$live, ref, conv$counted, expected, if (cr == "off") FALSE else cr)
      if (is.null(pd) || !nrow(pd)) next
      pd[, `:=`(night = "vic2022", time = stamp[k], cand_ref = cr)]
      rows[[length(rows) + 1L]] <- merge(pd, cvt, by.x = "seat", by.y = "district", all.x = TRUE)
      n_s <- data.table::uniqueN(pd$seat)
    }
    cat(sprintf("NPSD2 vic2022 %s: %d seats projected (%.0f s so far)\n", stamp[k], n_s, proc.time()[["elapsed"]] - t0))
  }
  VR <- fin(rbindlist(rows), tr)
  fwrite(VR, night_f("vic2022")); cat(sprintf("NPSD3 wrote %s: %d rows\n", night_f("vic2022"), nrow(VR)))
}

# ---- fed2022, fed2025 (night_replay_feed.R's reported places) --------------------------------------------------------------
for (nm in intersect(c("fed2022", "fed2025"), NIGHTS)) {
  if (!redo && file.exists(night_f(nm))) next
  t0 <- proc.time()[["elapsed"]]; rows <- list()
  st <- readRDS(file.path(runs, sprintf("state-%s.rds", nm))); yr <- st$to; seats <- rownames(st$shares)
  day <- as.Date(c(`2022` = "2022-05-21", `2025` = "2025-05-03")[[as.character(yr)]])
  tm <- c(sprintf("%02d:%02d", rep(18:23, each = 4), c(0, 15, 30, 45)), "24:00", "25:00", "26:00", "27:00")
  tm <- tm[tm <= max_time]
  at <- vapply(tm, function(x) { p <- as.integer(strsplit(x, ":")[[1]]); as.numeric(as.POSIXct(day, tz = "UTC") + p[1] * 3600 + p[2] * 60) }, numeric(1))
  L <- fread(dp(sprintf("output/booths-fed%d.csv", yr)), showProgress = FALSE); R0 <- fread(dp(sprintf("output/booths-fed%d.csv", st$from)), showProgress = FALSE)
  B <- fread(dp(sprintf("output/night-feed/booth-returns-fed%d.csv", yr)), showProgress = FALSE)
  D <- fread(dp(sprintf("output/night-feed/division-progress-fed%d.csv", yr)), showProgress = FALSE)
  tsec <- function(x) as.numeric(as.POSIXct(x, tz = "UTC"))
  B[, t_fp := tsec(ifelse(!is.na(fp_exact) & fp_exact_flag == 1, fp_exact, fp_first_seen))]
  pp <- B[!grepl("^declaration", classification) & !is.na(t_fp)]
  # expected night votes: the feed's enrolment (last value per division) x the previous election's night votes (ordinary +
  # early + postal) over that same enrolment -- the previous roll is not in the booth file, so the rate is one roll apart;
  # a division new since (no previous votes) takes the national rate inside night_expected_votes()
  en <- D[!is.na(enrolment) & enrolment > 0, list(enrolment = enrolment[.N]), by = "division"]
  prevb <- data.table::copy(R0); prevb[, night := booth_type %in% c("ordinary", "early", "postal")]
  prevv <- prevb[, list(total_votes = sum(votes, na.rm = TRUE), night_votes = sum(votes[night], na.rm = TRUE)), by = "district"]
  prev <- merge(en[, list(district = division, enrolment)], prevv, by = "district")
  expected <- night_expected_votes(stats::setNames(en$enrolment, en$division), prev, "night")
  tr <- truth_of(L, seats)
  cat(sprintf("NPSD1 %s: %d seats, %d places with a night return, %d with an expected total (%d on the national rate); booth types %s\n", nm,
              length(seats), nrow(pp), sum(is.finite(expected)), length(setdiff(en$division, prev$district)), paste(sort(unique(L$booth_type)), collapse = " ")))
  for (k in seq_along(at)) {
    rep_pp <- pp[pp$t_fp <= at[k], list(district = division, unit = polling_place)]
    if (!nrow(rep_pp)) next
    cvt <- counted_votes(L, rep_pp); n_s <- 0L
    for (cr in CR) {
      pd <- one_update(st, L, R0, rep_pp, expected, if (cr == "off") FALSE else cr)
      if (is.null(pd) || !nrow(pd)) next
      pd[, `:=`(night = nm, time = tm[k], cand_ref = cr)]
      rows[[length(rows) + 1L]] <- merge(pd, cvt, by.x = "seat", by.y = "district", all.x = TRUE)
      n_s <- data.table::uniqueN(pd$seat)
    }
    cat(sprintf("NPSD2 %s %s: %d places, %d seats projected (%.0f s so far)\n", nm, tm[k], nrow(rep_pp), n_s, proc.time()[["elapsed"]] - t0))
  }
  FR <- fin(rbindlist(rows, fill = TRUE), tr)
  fwrite(FR, night_f(nm)); cat(sprintf("NPSD3 wrote %s: %d rows\n", night_f(nm), nrow(FR)))
}
if (identical(flag("extract-only", "0"), "1")) quit(save = "no", status = 0)

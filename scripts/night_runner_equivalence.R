# Does the runner's live-feed path (counted-unit table) reproduce scripts/night_replay.R at the same fraction?
#
#   Rscript scripts/night_runner_equivalence.R --state=<state-vic2022.rds> [--frac=0.5] [--replay-csv=<night_replay.R output with --tcp=1 --gap_k=5>]
#
# (A) EXACT: the whole 2022 booth table plus the list of units counted at `frac`, denominator "table": must equal
#     the replay (win probabilities and every posterior share) to numerical identity.
# (B) LIVE-LIKE: the votes of every uncounted unit set to 0 (what a real feed shows) and the "projected" denominator:
#     not expected to be identical (the final total is unknown live); the gap is reported.
# Check codes: NEQ1 (inputs), NEQ2 (verdict).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")   # the published configuration, as night_replay.R and the harnesses apply it
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
st <- readRDS(flag("state")); fr <- as.numeric(flag("frac", "0.5"))
L <- fread(sprintf("output/booths-vic%d.csv", st$to), showProgress = FALSE); R <- fread(sprintf("output/booths-vic%d.csv", st$from), showProgress = FALSE)
Tc <- fread(sprintf("output/booths/vic%d-booth-tcp.csv", st$to), showProgress = FALSE)
cat(sprintf("NEQ1  %s: %d seats, live rows %d, reference rows %d, 2CP rows %d, frac %.2f\n", st$pair, nrow(st$shares), nrow(L), nrow(R), nrow(Tc), fr))

# which units the replay counts at this fraction (the same function night_replay.R calls)
nu0 <- night_booth_update(st$shares, night_prior_sd(st$shares, st$level_sd, st$level_mult, st$sdo), fr, L, R, gap_k = 5, early = "last")
cnt <- rbindlist(lapply(names(nu0$units), function(s) data.table(district = s, unit = nu0$units[[s]])))
cat(sprintf("NEQ1  replay counts %d units in %d seats\n", nrow(cnt), nrow(cnt[, .N, by = "district"])))

full <- copy(L)[, list(district, booth, booth_type, party, votes)]
conv_a <- list(live = full, counted = cnt, tcp = Tc[, list(district, booth, vote_type, party_raw, votes)], unmapped = character())
ra <- night_run_update(st, conv_a, R, gap_k = 5, total = "table")

un <- ifelse(L$booth_type == "ordinary", L$booth, L$booth_type)
is_c <- paste(L$district, un) %in% paste(cnt$district, cnt$unit)
zer <- copy(full); zer[!is_c, votes := 0]
conv_b <- list(live = zer, counted = cnt, tcp = conv_a$tcp, unmapped = character())
rb <- night_run_update(st, conv_b, R, gap_k = 5, total = "projected")

# (C) as B but with the live denominator: this election's enrolment x the previous election's turnout rate per seat
S_prev <- fread(sprintf("output/council-district-stats-%d.csv", st$from), showProgress = FALSE)
S_now <- fread(sprintf("output/council-district-stats-%d.csv", st$to), showProgress = FALSE)
enr <- setNames(S_now$enrolment, sub(" District$", "", S_now$district))
PT <- night_turnout_table(S_prev, R)                                  # Assembly totals of the previous election / enrolment
ex_final <- night_expected_votes(enr, PT, "final"); ex_night <- night_expected_votes(enr, PT, "night")
ex_old <- (function() { r <- S_prev$rbvc_formal / S_prev$enrolment; nm <- sub(" District$", "", S_prev$district)
  x <- enr * r[match(names(enr), nm)]; x[is.na(x)] <- enr[is.na(x)] * sum(as.numeric(S_prev$rbvc_formal)) / sum(as.numeric(S_prev$enrolment)); x })()
tt <- L[, list(final = sum(votes), night = sum(votes[booth_type %in% c("ordinary", "early", "postal")])), by = "district"]
err <- function(ex, tr) { e <- ex[tt$district] / tr - 1; c(n = sum(!is.na(e)), mean = 100 * mean(e, na.rm = TRUE), mae = 100 * mean(abs(e), na.rm = TRUE)) }
f <- function(lbl, x) cat(sprintf("NEQ1  %-62s n=%d  mean error %+.2f%%  mean abs error %.2f%%\n", lbl, x[["n"]], x[["mean"]], x[["mae"]]))
f("(a) expected-final vs the replay's NIGHT total (ord+early+postal)", err(ex_final, tt$night))
f("(b) expected-final vs the FINAL all-type Assembly total", err(ex_final, tt$final))
f("(c) expected-night vs the replay's NIGHT total", err(ex_night, tt$night))
f("(old) upper-house base (rbvc_formal) vs the FINAL all-type total", err(ex_old, tt$final))
rc_old <- night_run_update(st, conv_b, R, gap_k = 5, total = "expected", expected = ex_old)
rc_fin <- night_run_update(st, conv_b, R, gap_k = 5, total = "expected", expected = ex_final)
rc_late <- night_run_update(st, conv_b, R, gap_k = 5, total = "expected", expected = ex_night)   # night base but late types still counted/projected (before the fix)
late <- c("absent", "provisional", "marked_as_voted")
conv_n <- list(live = zer[!zer$booth_type %in% late], counted = cnt[!cnt$unit %in% late], tcp = conv_a$tcp, unmapped = character())
rc <- night_run_update(st, conv_n, R, gap_k = 5, total = "expected", expected = ex_night)       # night base, late types out of numerator and units
pt <- rc$nu$proj_total; ee <- ex_night[names(pt)]
cat(sprintf("NEQ1  C2 sum(counted + projected uncounted) vs expected-night, per updated seat: n=%d  mean error %+.2f%%  mean abs error %.2f%%\n",
            length(pt), 100 * mean(pt / ee - 1, na.rm = TRUE), 100 * mean(abs(pt / ee - 1), na.rm = TRUE)))
ptl <- rc_late$nu$proj_total; eel <- ex_night[names(ptl)]
cat(sprintf("NEQ1  (before fix, late types in) same quantity: n=%d  mean error %+.2f%%  mean abs error %.2f%%\n",
            length(ptl), 100 * mean(ptl / eel - 1, na.rm = TRUE), 100 * mean(abs(ptl / eel - 1), na.rm = TRUE)))

csv <- flag("replay-csv")
if (is.null(csv)) stop("NEQ1! --replay-csv= is required (run night_replay.R --fracs=<frac> --tcp=1 --gap_k=5 first)")
rp <- fread(csv); rp <- rp[abs(frac - fr) < 1e-9]
if (!nrow(rp)) stop("NEQ1! replay csv has no rows at frac ", fr)
cmp <- function(res, label) {
  w <- as.data.table(res$sim$win_prob)
  m <- merge(rp[, list(seat, party, p_replay = prob)], w[, list(seat, party, p_run = prob)], by = c("seat", "party"), all = TRUE)
  m[is.na(p_replay), p_replay := 0]; m[is.na(p_run), p_run := 0]
  d <- max(abs(m$p_replay - m$p_run))
  sd_diff <- max(abs(res$shares - ra$shares))
  cat(sprintf("NEQ2  %s: %d (seat, party) pairs, max |win prob difference| %.6f, max |posterior share difference vs A| %.6f, mean counted %.3f\n",
              label, nrow(m), d, sd_diff, mean(res$nu$counted)))
  invisible(d)
}
ll <- function(res) {
  w <- as.data.table(res$sim$win_prob); eps <- 0.5 / st$n_sims
  pa <- merge(data.table(seat = st$keep, actual = unname(st$truth[st$keep])), w, by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]; mean(-log(pmax(pa$prob, eps)))
}
da <- cmp(ra, "A exact (full table + counted list, table denominator)")
db <- cmp(rb, "B live-like (uncounted votes zeroed, projected denominator)")
dc0 <- cmp(rc_old, "C0 expected, OLD base (upper-house rbvc_formal)")
dc1 <- cmp(rc_fin, "C1 expected-FINAL (Assembly all-type total)")
dcl <- cmp(rc_late, "C2-before expected-night, late types still in")
dc <- cmp(rc, "C2 expected-NIGHT, late types out of numerator and units")
cat(sprintf("NEQ2  seat log loss over %d seats (lower is better): replay/A %.4f, B projected %.4f, C0 old %.4f, C1 final %.4f, C2-before %.4f, C2 night %.4f\n", length(st$keep), ll(ra), ll(rb), ll(rc_old), ll(rc_fin), ll(rc_late), ll(rc)))
cat(sprintf("NEQ2  replay mean counted %.3f\n", mean(nu0$counted)))
cat(sprintf("NEQ2  VERDICT A: %s\n", if (da < 1e-9) "EQUAL to night_replay.R" else "DIFFERENT"))
quit(status = if (da < 1e-9) 0L else 1L)

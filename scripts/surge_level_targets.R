# AUSPOL_SURGE_LEVEL pre-registration: freeze the target seats, then score an arm on them.
# docs/plans/prereg-surge-level-2026-10-25.md.
#
#   Rscript <checkout>/scripts/surge_level_targets.R list      (working directory: a checkout WITH output/)
#       Writes docs/plans/prereg-surge-level-targets-2026-10-25.csv: every (election, seat) whose
#       surge recipient has a point share >= 10 before the simulation and a hazard >= 0.02. The
#       hazard and recipient come from surge_hazard_for() fitted on the earlier elections of the
#       nine-pair salience list (scripts/fit_salience_surge_v2.R), the way the four harnesses that
#       use it (fed, vic, nsw, qld, sa) do; the point share is the newest harness sharedetail
#       `pred_share` for that election. WA and NT are left out: neither harness fits a salience
#       hazard (published AUSPOL_SURGE_H = "0", AUSPOL_XGB_SURGE = "0"), so nothing fires there and
#       the switch cannot act. Reads output/ only.
#
#   Rscript scripts/surge_level_targets.R score --base=<quick_arm cache dir> --arm=<quick_arm cache dir> --sims=N
#       Each dir holds <election>/allprobs.csv (quick_arm's cache/<key>/, key printed by quick_arm).
#       Prints the primary (target-seat winner log loss), the all-seat guard, the per-election
#       2-SE clause, leave-one-election-out, the two-largest-gain clause and the two named
#       unacceptable outcomes. Winner probabilities are floored at 0.5 / N as quick_arm does.
# The CODE is the checkout this script sits in; the DATA is the working directory (the salience
# corpus reads output/ relative to it, R/salience_surge.R), so a worktree with no outputs can run
# from the main checkout and still write its frozen list into its own docs/plans/.
.f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
CODE <- normalizePath(file.path(dirname(.f), ".."), winslash = "/")
suppressMessages(devtools::load_all(CODE, quiet = TRUE))
options(auspol.root = normalizePath(getwd(), winslash = "/"))
library(data.table)
args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[1] else "list"
opt <- function(name, default = NULL) {
  a <- grep(sprintf("^--%s=", name), args, value = TRUE)
  if (length(a)) sub(sprintf("^--%s=", name), "", a[1]) else default
}
TARGETS <- file.path(CODE, "docs/plans/prereg-surge-level-targets-2026-10-25.csv")
HAZARDS <- file.path(CODE, "docs/plans/prereg-surge-level-hazards-2026-10-25.csv")   # every seat with hazard > 0
OUT_DIR <- file.path(getwd(), "output")
if (!dir.exists(OUT_DIR)) stop("run from a checkout with outputs: no ", OUT_DIR)
V2 <- list(
  list(election = "fed2010", prev = "fed2007", region = "fed"),
  list(election = "fed2013", prev = "fed2010", region = "fed"),
  list(election = "fed2016", prev = "fed2013", region = "fed"),
  list(election = "fed2019", prev = "fed2016", region = "fed"),
  list(election = "fed2022", prev = "fed2019", region = "fed"),
  list(election = "vic2022", prev = "vic2018", region = "vic"),
  list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
  list(election = "sa2026",  prev = "sa2022",  region = "sa"),
  list(election = "wa2008",  prev = "wa2005",  region = "wa"))
YEARS <- list(fed = c(2004, 2007, 2010, 2013, 2016, 2019, 2022, 2025), nsw = c(2007, 2011, 2015, 2019, 2023),
              qld = c(2009, 2012, 2015, 2017, 2020, 2024), sa = c(2006, 2010, 2014, 2018, 2022, 2026),
              vic = c(2006, 2010, 2014, 2018, 2022))

if (mode == "list") {
  files <- list.files(OUT_DIR, pattern = "^backtest-.*-sharedetail-.*\\.csv$", full.names = TRUE)
  out <- list(); allh <- list(); n_haz <- 0L
  for (reg in names(YEARS)) for (y in YEARS[[reg]][-1]) {
    p <- paste0(reg, y); prev <- paste0(reg, YEARS[[reg]][match(y, YEARS[[reg]]) - 1L])
    tr <- V2[elections_before(vapply(V2, `[[`, character(1), "election"), p)]
    h <- NULL
    invisible(utils::capture.output(h <- tryCatch(surge_hazard_for(p, prev, reg, tr), error = function(e) { message("SLT1! ", p, ": ", conditionMessage(e)); NULL })))
    if (is.null(h)) { cat(sprintf("SLT1 %-8s no hazard (no salience corpus or no earlier training pair)\n", p)); next }
    hz <- merge(as.data.table(h$seat_hazard), as.data.table(h$seat_recipient), by = "seat")
    f <- files[grepl(sprintf("^backtest-(%s|%s)-sharedetail-", p, reg), basename(files))]
    f <- f[order(-as.numeric(file.mtime(f)))]
    sd <- NULL; used <- NA_character_
    for (ff in f) { d <- fread(ff); if ("pair" %in% names(d)) d <- d[d$pair == p]; if (nrow(d)) { sd <- d; used <- ff; break } }
    if (is.null(sd)) stop("no sharedetail for ", p, " -- cannot fix its targets")
    sd[, skey := normalise_seat(seat)]; hz[, skey := normalise_seat(seat)]
    m <- merge(hz, sd[, .(skey, party, pred_share, actual_share)], by = c("skey", "party"), all.x = TRUE)
    n_haz <- n_haz + sum(m$surge_h >= 0.02)
    miss <- sum(m$surge_h >= 0.02 & !is.finite(m$pred_share))
    if (miss) stop(sprintf("%s: %d hazard >= 0.02 seat(s) have no recipient share in %s", p, miss, basename(used)))
    t <- m[surge_h >= 0.02 & pred_share >= 10, .(pair = p, seat, recipient = party, surge_h, pred_share, actual_share)]
    cat(sprintf("SLT1 %-8s %3d seats with a hazard, %3d at >= 0.02, %3d targets | shares from %s\n",
                p, sum(m$surge_h > 0), sum(m$surge_h >= 0.02), nrow(t), basename(used)))
    out[[p]] <- t
    allh[[p]] <- m[surge_h > 0, .(pair = p, seat, surge_h = signif(surge_h, 4))]
  }
  T <- rbindlist(out)
  stopifnot(nrow(T) > 0, !anyDuplicated(T[, .(pair, seat)]))
  fwrite(T, TARGETS); fwrite(rbindlist(allh), HAZARDS)
  cat(sprintf("SLT2 %d target seats in %d elections (of %d seat-elections with hazard >= 0.02) -> %s\n",
              nrow(T), uniqueN(T$pair), n_haz, TARGETS))
  print(T[, .(targets = .N, mean_h = round(mean(surge_h), 3), mean_share = round(mean(pred_share), 1)), by = pair])
  print(T[, .N, by = recipient][order(-N)])
} else if (mode == "score") {
  base_dir <- opt("base"); arm_dir <- opt("arm"); sims <- as.numeric(opt("sims", NA))
  if (is.null(base_dir) || is.null(arm_dir) || !is.finite(sims)) stop("score needs --base=, --arm= and --sims=")
  T <- fread(TARGETS)
  rd <- function(dir) rbindlist(lapply(list.dirs(dir, recursive = FALSE), function(dir_i) {
    f <- file.path(dir_i, "allprobs.csv"); if (!file.exists(f)) return(NULL); d <- fread(f); if (!"pair" %in% names(d)) d[, pair := basename(dir_i)]; d }), fill = TRUE)
  B <- rd(base_dir); A <- rd(arm_dir)
  cat(sprintf("SLS0 base %d rows / %d elections, arm %d rows / %d elections, floor %.2g\n",
              nrow(B), uniqueN(B$pair), nrow(A), uniqueN(A$pair), 0.5 / sims))
  S <- as.data.table(quick_seat_ll(as.data.frame(B), as.data.frame(A), eps = 0.5 / sims)$seats)
  S[, key := paste(pair, normalise_seat(seat))]
  T[, key := paste(pair, normalise_seat(seat))]
  scored_pairs <- unique(S$pair)
  Tin <- T[pair %in% scored_pairs]
  miss <- setdiff(Tin$key, S$key)
  if (length(miss)) stop(length(miss), " target seat(s) are not in the scored allprobs: ", paste(head(miss, 5), collapse = "; "))
  S[, target := key %in% Tin$key]
  cat(sprintf("SLS1 target seats scored: %d of %d frozen, in %d elections\n", sum(S$target), nrow(T), uniqueN(S$pair[S$target])))
  if (sum(S$target) < 10) cat("SLS1! fewer than 10 target seats: NOT MEASURABLE, not a negative (prereg)\n")
  pr <- quick_clustered(S$dd[S$target], S$pair[S$target])
  gd <- quick_clustered(S$dd, S$pair)
  cat(sprintf("SLS2 PRIMARY target-seat log loss change %+.4f (SE %.4f, %d seats, %d elections) -> %s\n",
              pr$mean, pr$se, pr$n, pr$clusters, if (is.finite(pr$se) && pr$mean < -pr$se) "PASS" else "NOT PASSED"))
  cat(sprintf("SLS3 GUARD all-seat log loss change %+.4f (SE %.4f, %d seats) -> %s\n",
              gd$mean, gd$se, gd$n, if (is.finite(gd$se) && gd$mean > gd$se) "FAIL" else "holds"))
  per <- S[, .(n = .N, change = mean(dd), se = sd(dd) / sqrt(.N)), by = pair]
  per[, worse_2se := change > 2 * se & se > 0]
  cat("SLS4 per election (all seats; change = arm - base, lower is better):\n"); print(per[order(-change)])
  lo <- vapply(unique(S$pair[S$target]), function(p) mean(S$dd[S$target & S$pair != p]), 0)
  cat(sprintf("SLS5 leave-one-election-out primary: range %+.4f to %+.4f; sign kept: %s\n",
              min(lo), max(lo), all(sign(lo) == sign(pr$mean))))
  tg <- S[target == TRUE][order(dd)]
  cat(sprintf("SLS6 primary without the two largest-gain targets (%s): %+.4f\n",
              paste(tg$seat[1:2], collapse = ", "), mean(tg$dd[-(1:2)])))
  # Unacceptable 1: a target recipient who actually WON loses more than 0.10 win probability.
  Tw <- merge(Tin, unique(B[, .(pair, key = paste(pair, normalise_seat(seat)), actual)]), by = c("pair", "key"))
  Tw <- Tw[recipient == actual]
  Tw <- merge(Tw, S[, .(key, p_base, p_arm)], by = "key")
  bad1 <- Tw[p_base - p_arm > 0.10]
  cat(sprintf("SLS7 actual-winner recipients among targets: %d; losing > 0.10 win prob: %d -> %s\n",
              nrow(Tw), nrow(bad1), if (nrow(bad1)) "UNACCEPTABLE" else "ok"))
  if (nrow(bad1)) print(bad1[, .(pair, seat, recipient, p_base, p_arm)])
  # Unacceptable 2: a seat with no hazard moves by more than 0.001. Hazard 0 = absent from the frozen
  # hazard table, which leaves out every WA and NT seat and every election with no salience fit.
  H <- fread(HAZARDS); hkey <- paste(H$pair, normalise_seat(H$seat))
  mv <- S[!(key %in% hkey) & abs(p_arm - p_base) > 0.001]
  cat(sprintf("SLS8 hazard-0 seats moving > 0.001 win prob: %d -> %s\n", nrow(mv), if (nrow(mv)) "UNACCEPTABLE" else "ok"))
  if (nrow(mv)) print(head(mv[order(-abs(p_arm - p_base)), .(pair, seat, p_base, p_arm)], 30))
} else stop("mode must be list or score")

# Compare our shipped model against AE Forecasts, per-election and worst
# seats. Reads only pooled outputs and the newest backtest file per pair --
# no fresh sim. Emits AEF* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
eps <- 1e-6

bt_all <- fread(file.path(OUT, "pooled-backtest.csv"), showProgress = FALSE)
aef_primary <- fread(file.path(OUT, "aef-primary-all.csv"), showProgress = FALSE)
aef_scores  <- fread(file.path(OUT, "aef-seat-scores.csv"), showProgress = FALSE)

MAP <- data.table(
  pair = c("fed2022","nsw2023","vic2022","qld2024","fed2025","wa2025","sa2026"),
  aef_code = c("2022fed","2023nsw","2022vic","2024qld","2025fed","2025wa","2026sa")
)

# WHICH ARM'S FILES? "Newest per pair" was fine when one arm existed at a time.
# It is NOT fine now: the 2026-09-11 2x2 left four arms of every pair on disk
# minutes apart (output/_pfrun/p0f0|p0f1|p1f0|p1f1), so "newest" silently
# builds a table from a MIXTURE of configurations, and the AEF comparison is
# the one table most likely to be quoted at face value.
#
# So: AUSPOL_AEF_RUNDIR names a run directory (e.g. output/_pfrun/p1f1_s1) and
# every file is resolved from THAT arm's own harness logs, which name what each
# run wrote. Seeds are averaged when several directories match the same arm,
# because a single seed's RNG moves an individual seat's probability more than
# most model changes do. Unset = the old newest-per-pair behaviour, which is
# still right when only one arm is in play.
RUNDIR <- Sys.getenv("AUSPOL_AEF_RUNDIR", "")
JURIS_PREFIX <- c(sa2026 = "sa", wa2025 = "wa", vic2022 = "vic")

arm_files <- function(rundir_glob) {
  dirs <- Sys.glob(rundir_glob)
  if (!length(dirs)) stop("AUSPOL_AEF_RUNDIR matched no directory: ", rundir_glob)
  fs <- unlist(lapply(dirs, function(d) {
    logs <- list.files(d, pattern = "[.]log$", full.names = TRUE)
    unlist(lapply(logs, function(lg) {
      ln <- readLines(lg, warn = FALSE)
      hit <- unique(regmatches(ln, regexpr("output/backtest-[^ ]+[.]csv", ln)))
      if (length(hit)) return(hit)
      # backtest_candidate_vic.R only started naming its output on 2026-09-11;
      # for logs written before that, fall back to the file whose mtime matches.
      reg <- sub("[0-9]*[.]log$", "", basename(lg))
      cand <- list.files(OUT, pattern = sprintf("^backtest-%s.*[.]csv$", reg), full.names = TRUE)
      cand <- cand[!grepl("sharedetail|allprobs|totals|-seatsd|-diag", cand)]
      m <- cand[abs(as.numeric(difftime(file.mtime(cand), file.mtime(lg), units = "secs"))) <= 2]
      if (length(m) == 1L) m else character(0)
    }))
  }))
  unique(fs[!grepl("sharedetail|allprobs|totals|-seatsd|-diag", fs)])
}
ARM_FILES <- if (nzchar(RUNDIR)) arm_files(RUNDIR) else character(0)
if (nzchar(RUNDIR))
  cat(sprintf("AEF1  arm %s: %d output file(s) across %d seed dir(s)\n",
              RUNDIR, length(ARM_FILES), length(Sys.glob(RUNDIR))))

# THE PRIMARY-SHARE COLUMNS MUST COME FROM THE SAME ARM. pooled-sharedetail.csv
# is built newest-per-pair like everything else, so reading it here would pair
# this arm's win probabilities with some other arm's predicted primaries -- and
# the xgb primary changes those by design, so the mismatch would be large and
# invisible. Each harness writes its sharedetail alongside its main file with
# the SAME -a<fingerprint> tag, so match on that rather than on time.
sharedetail_for_arm <- function(main_files) {
  all_sd <- list.files(OUT, pattern = "-sharedetail.*[.]csv$", full.names = TRUE)
  tags <- unique(unlist(regmatches(basename(main_files),
                                    gregexpr("-a[0-9a-f]+", basename(main_files)))))
  if (!length(tags)) return(character(0))
  all_sd[vapply(basename(all_sd), function(b) any(vapply(tags, grepl, logical(1), x = b)), logical(1))]
}
if (length(ARM_FILES)) {
  sd_files <- sharedetail_for_arm(ARM_FILES)
  cat(sprintf("AEF1  matched %d sharedetail file(s) to this arm by fingerprint\n", length(sd_files)))
  if (!length(sd_files)) stop("no sharedetail files carry this arm's fingerprint -- refusing to mix arms")
  sd_all <- unique(rbindlist(lapply(sd_files, function(f) {
    x <- fread(f, showProgress = FALSE)
    if (!all(c("pair","seat","party","pred_share","actual_share") %in% names(x))) return(NULL)
    x[, .(pair = as.character(pair), seat, party, pred_share, actual_share)]
  }), fill = TRUE))
  # Several seeds write the same (pair, seat, party); the primary point
  # estimate does not depend on the seed, so average and assert they agree.
  sd_all <- sd_all[, .(pred_share = mean(pred_share), actual_share = mean(actual_share),
                       spread = diff(range(pred_share))), by = .(pair, seat, party)]
  if (max(sd_all$spread, na.rm = TRUE) > 1e-6)
    cat(sprintf("AEF1! predicted primaries differ across seeds by up to %.4f -- they should not\n",
                max(sd_all$spread, na.rm = TRUE)))
  sd_all[, spread := NULL]
} else {
  sd_all <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)
}

newest_win_file <- function(pr) {
  # The federal harness names its file backtest-fed-p<year>- only when
  # AUSPOL_FED_PAIRS restricts it to one pair; a full 7-pair run writes ONE
  # backtest-fed-... file with an internal `pair` column. Matching only the
  # per-pair form silently dropped fed2022 and fed2025 from this table -- the
  # two biggest AEF-comparable elections -- with just an AEF0! line to show
  # for it. Match both, and let read_win() filter on the `pair` column.
  pat <- if (pr %in% names(JURIS_PREFIX)) sprintf("^backtest-%s-", JURIS_PREFIX[[pr]])
         else if (grepl("^fed", pr)) sprintf("^backtest-fed-(p%s-)?", sub("fed","",pr))
         else sprintf("^backtest-%s-", pr)
  f <- if (length(ARM_FILES)) ARM_FILES[grepl(pat, basename(ARM_FILES))]
       else {
         g <- list.files(OUT, pattern = pat, full.names = TRUE)
         g <- g[!grepl("sharedetail|allprobs|totals", g)]
         if (!length(g)) return(NULL) else g[which.max(file.mtime(g))]
       }
  if (!length(f)) return(NULL)
  f
}

read_win <- function(pr) {
  fs <- newest_win_file(pr)
  if (is.null(fs) || !length(fs)) return(NULL)
  d <- rbindlist(lapply(fs, function(f) {
    x <- fread(f, showProgress = FALSE)
    if ("pair" %in% names(x)) x <- x[x$pair == pr]
    if ("p" %in% names(x)) setnames(x, "p", "our_p")
    if ("prob" %in% names(x)) setnames(x, "prob", "our_p")
    if (!nrow(x)) return(NULL)
    x[, .(seat, actual, our_pred = pred, our_p = pmin(pmax(our_p, eps), 1))]
  }), fill = TRUE)
  if (!nrow(d)) return(NULL)
  # Average the seeds. `actual` is a fact and must be identical across them --
  # assert rather than silently take the first, because a mismatch would mean
  # the files are not the same pair.
  chk <- d[, .(u = uniqueN(actual)), by = seat]
  if (any(chk$u > 1L)) stop("seat(s) disagree on the winner across seeds for ", pr)
  d[, .(actual = actual[1], our_pred = names(sort(table(our_pred), decreasing = TRUE))[1],
        our_p = mean(our_p), seeds = .N), by = seat]
}

all_rows <- list()
for (i in seq_len(nrow(MAP))) {
  pr <- MAP$pair[i]; ac <- MAP$aef_code[i]
  win <- read_win(pr)
  if (is.null(win)) { cat(sprintf("AEF0! no win file for %s\n", pr)); next }
  a <- aef_scores[election == ac]
  a[, aef_p := pmin(pmax(prob, eps), 1)]
  setnames(a, "pred", "aef_pred")
  m <- merge(win, a[, .(seat, aef_pred, aef_p)], by = "seat")
  m[, delta := (-log(our_p)) - (-log(aef_p))]
  sd_p <- sd_all[pair == pr]
  ap_p <- aef_primary[election == ac]
  m <- merge(m, sd_p[, .(seat, party, our_primary = pred_share, actual_primary = actual_share)],
             by.x = c("seat","actual"), by.y = c("seat","party"), all.x = TRUE)
  m <- merge(m, ap_p[, .(seat, party, aef_primary = aef_pcv)],
             by.x = c("seat","actual"), by.y = c("seat","party"), all.x = TRUE)
  m[, pair := pr]
  all_rows[[pr]] <- m
}
ALL <- rbindlist(all_rows, fill = TRUE)

cat("\n=== PER-ELECTION: our seat log loss vs AEF's (lower is better) ===\n")
per <- ALL[, .(n = .N,
               our_ll = mean(-log(our_p)),
               aef_ll = mean(-log(aef_p)),
               our_acc = mean(our_pred == actual),
               delta  = mean(-log(our_p)) - mean(-log(aef_p))),
           by = pair]
setorder(per, pair)
print(per[, .(pair, n, our_acc = round(our_acc,3), our_ll = round(our_ll,4),
              aef_ll = round(aef_ll,4), delta = round(delta,4))])
# The all-22 number: prefer this arm's own pooled table (scripts/pool_pf_arms.R)
# over pooled-backtest.csv, which is newest-per-pair and therefore mixed.
# COMPUTE THE ALL-PAIRS FIGURE FROM THIS ARM'S OWN FILES, never from a stored
# summary. pf-arms-pooled.csv is written by a different script at a different
# time, and on 2026-09-11 it was left holding the LEAKED arm's 0.3001 while
# this arm's files had been re-run leakage-free -- so this line printed a
# number from one model under another model's name, captioned "ALL 22
# elections" without ever checking the pair count. Flagged by the review gate;
# both faults fixed by reading the arm directly and stating the real coverage.
.allf <- if (length(ARM_FILES)) ARM_FILES else character(0)
if (length(.allf)) {
  .allr <- unique(rbindlist(lapply(.allf, function(f) {
    d <- fread(f, showProgress = FALSE)
    pc <- if ("prob" %in% names(d)) "prob" else if ("p" %in% names(d)) "p" else NA_character_
    if (is.na(pc) || !all(c("seat", "actual") %in% names(d))) return(NULL)
    if (!"pair" %in% names(d)) {
      mm <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
      if (!length(mm)) return(NULL)
      d[, pair := mm]
    }
    d[, .(pair = as.character(pair), seat = as.character(seat),
          p = pmin(pmax(get(pc), eps), 1))]
  }), fill = TRUE))
  .allr <- .allr[, .(p = mean(p)), by = .(pair, seat)]
  .known <- length(vapply(all_election_pairs(), `[[`, character(1), "election"))
  cat(sprintf("\nPooled seat log loss, %d of %d known pairs, THIS arm (%s, seed-averaged): %.4f%s\n",
              uniqueN(.allr$pair), .known, RUNDIR, -mean(log(.allr$p)),
              if (uniqueN(.allr$pair) < .known) "  <- PARTIAL, not the full backtest" else ""))
} else {
  cat(sprintf("\nPooled seat log loss, ALL 22 elections (newest-per-pair, MAY MIX ARMS): %.4f\n",
              sum(bt_all$logloss * bt_all$n) / sum(bt_all$n)))
}
cat(sprintf("Pooled seat log loss on the %d AEF-comparable elections: ours %.4f vs AEF %.4f (delta %+.4f)\n",
            nrow(per), mean(-log(ALL$our_p)), mean(-log(ALL$aef_p)),
            mean(-log(ALL$our_p)) - mean(-log(ALL$aef_p))))

N_WORST <- as.integer(Sys.getenv("AUSPOL_AEF_WORST", "20"))
# IS IT THE PRIMARY OR THE FLOWS? Pete's question, 2026-09-11, and the table
# could not answer it before: it showed our primary and AEF's side by side and
# left the subtraction to the reader.
#
# `prim_gap` is OUR absolute primary error on the winner minus AEF's. Positive
# means we predicted that candidate's vote WORSE than AEF did. `why` reads it:
#
#   "primary"   we are >=2 points worse on the winner's primary -- the vote
#               estimate is the problem and better flows cannot rescue it.
#   "flow/var"  our primary is within 2 points of AEF's (or better) and we
#               still gave a much lower win probability -- so we had roughly
#               the right vote and turned it into the wrong answer, which is
#               preferences or the spread around the point estimate.
#   "both"      worse on primary AND the probability gap is larger than the
#               primary gap explains.
ALL[, our_pe := abs(our_primary - actual_primary)]
ALL[, aef_pe := abs(aef_primary - actual_primary)]
ALL[, prim_gap := our_pe - aef_pe]
ALL[, why := fifelse(is.na(prim_gap), "no primary data",
             fifelse(prim_gap >= 2 & delta > 2 * prim_gap / 10, "both",
             fifelse(prim_gap >= 2, "primary", "flow/var")))]
cat(sprintf("\n=== WORST %d SEATS (our log loss minus AEF's, worst first) ===\n", N_WORST))
cat("our_prim/aef_prim/actual are the WINNER's primary vote. prim_gap = our error minus AEF's,\n")
cat("so positive means we called that candidate's vote worse. why: is the miss the primary or not.\n")
setorder(ALL, -delta)
worst <- ALL[seq_len(min(N_WORST, .N)),
             .(pair, seat, won = actual, our_p = round(our_p, 3), aef_p = round(aef_p, 3),
               our_prim = round(our_primary, 1), aef_prim = round(aef_primary, 1),
               actual = round(actual_primary, 1), prim_gap = round(prim_gap, 1),
               why, delta = round(delta, 2))]
print(worst)
cat("\n=== SO WHICH IS IT? worst 20, and all 659 comparable seats ===\n")
cat(sprintf("worst %d: %s\n", N_WORST,
            paste(sprintf("%s=%d", names(table(worst$why)), as.integer(table(worst$why))), collapse = "  ")))
.sc <- ALL[!is.na(prim_gap)]
cat(sprintf("all %d scored seats: %s\n", nrow(.sc),
            paste(sprintf("%s=%d", names(table(.sc$why)), as.integer(table(.sc$why))), collapse = "  ")))
cat(sprintf("mean primary error on the winner: ours %.2f, AEF %.2f (we are %s by %.2f points)\n",
            mean(.sc$our_pe), mean(.sc$aef_pe),
            if (mean(.sc$our_pe) > mean(.sc$aef_pe)) "WORSE" else "better",
            abs(mean(.sc$our_pe) - mean(.sc$aef_pe))))
cat("\n=== the same split, by who won the seat ===\n")
print(.sc[, .(seats = .N, our_prim_err = round(mean(our_pe), 2), aef_prim_err = round(mean(aef_pe), 2),
              prim_gap = round(mean(prim_gap), 2), ll_damage = round(sum(delta), 2)),
          by = .(won = actual)][order(-ll_damage)])
fwrite(ALL, file.path(OUT, "aef-comparison-full.csv"))
cat(sprintf("\nwrote %s\n", file.path(OUT, "aef-comparison-full.csv")))

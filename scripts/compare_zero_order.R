# Read-only scoring for docs/plans/prereg-zero-order-2026-10-03.md: the clauses the partial result
# marked NOT EVALUATED (C0, C2, C3, C4, R1, R2, R3, R7) plus the cells-differing count per pair.
# Written and committed BEFORE its output is read; do not edit it after the first look at a result.
# It runs no model, writes nothing, and reads only the per-harness CSVs named below.
#
# Usage (from C:\dev\auspol):
#   Rscript scripts/compare_zero_order.R <dir_early> <dir_late> [pair1,pair2,...]
# Default pairs: the 22 (fed 7, vic 3, nsw 2, qld 2, sa 2, wa 6).
#
# Files read in each directory (names matched by harness and pair, never by position):
#   summary      backtest-<h>[<yyyy>]-<tags>.csv
#     fed/vic/qld/sa : seat,actual,prob,pred,pred_p,pair
#     wa             : seat,actual,prob,pred,pred_p,pair,coverage
#     nsw            : seat,p,pred,pred_p,actual,bin   (NO pair column: pair comes from the file name)
#     prob / p = probability the model gave the ACTUAL winner; pred / pred_p = its top pick and that
#     pick's probability; actual = the winning class.
#   sharedetail  backtest-<h>[<yyyy>]-sharedetail-<tags>.csv : seat,party,pred_share,actual_share,pair,xgb_primary_on
#   ignored      allprobs / totals / ourtcp files.
# Any file with unexpected columns, a missing or duplicated pair, a pair outside the requested list,
# a seat set that differs between summary and sharedetail or between arms, or actual outcomes that
# differ between arms STOPS the script. A comparison of mismatched files is not a result.
#
# Definitions fixed here (not chosen after seeing output):
#   EPS 1e-6 clamps the winner probability before the log. The files hold probabilities to 4-5
#   decimals, so "at the floor" is read as p <= 1e-4.
#   cell = (pair, seat, party) in sharedetail. Shares are in points. A cell DIFFERS between arms when
#   |late - early| > 1e-9.
#   ghost cell = actual_share == 0 and pred_share > 0 (strict: C0 fails on a single one).
#   by-design exempt class = a (pair, party) whose actual_share is 0 in EVERY seat of the pair: that
#   class is absent from the result table, and zero_unnominated() leaves such classes untouched
#   (R/nomination_zero.R: `skipped <- setdiff(colnames(shares), classes_known)`).
#   zeroed cell = pred_share < 1e-9.
#   winner = `pred` in the summary file (the seat's most probable class). R3 excludes a flip when the
#   early winner's cell is a class that did not stand (actual_share 0) and is zero in late.
#   R2 SE = sd(late error - early error)/sqrt(n) over the cells of that class on seats where any cell
#   differs; a class with n < 2 cannot be assessed and is flagged if its absolute bias grew.
EPS <- 1e-6; FLOOR_P <- 1e-4; TOL <- 1e-9
GUARD_C2 <- 0.0020; GUARD_C3 <- 0.011
PAIRS_ALL <- c(paste0("fed", c(2007, 2010, 2013, 2016, 2019, 2022, 2025)), paste0("vic", c(2014, 2018, 2022)),
               paste0("nsw", c(2019, 2023)), paste0("qld", c(2020, 2024)), paste0("sa", c(2022, 2026)),
               paste0("wa", c(2001, 2005, 2008, 2013, 2017, 2025)))
HARNESSES <- c("fed", "vic", "nsw", "qld", "sa", "wa")
COLS_SUMMARY <- list(fed = c("seat", "actual", "prob", "pred", "pred_p", "pair"),
                     vic = c("seat", "actual", "prob", "pred", "pred_p", "pair"),
                     qld = c("seat", "actual", "prob", "pred", "pred_p", "pair"),
                     sa  = c("seat", "actual", "prob", "pred", "pred_p", "pair"),
                     wa  = c("seat", "actual", "prob", "pred", "pred_p", "pair", "coverage"),
                     nsw = c("seat", "p", "pred", "pred_p", "actual", "bin"))
COLS_DETAIL <- c("seat", "party", "pred_share", "actual_share", "pair", "xgb_primary_on")

die <- function(...) stop(paste0("compare_zero_order: ", ...), call. = FALSE)
flags <- character(0)
flag <- function(x) flags <<- c(flags, x)
show <- function(d, digits = 4) { if (!nrow(d)) cat("  (none)\n") else print(format(d, digits = digits, scientific = FALSE), row.names = FALSE) }

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L || length(args) > 3L) die("usage: Rscript scripts/compare_zero_order.R <dir_early> <dir_late> [pairs, comma-separated]")
dirs <- c(early = args[1], late = args[2])
for (d in dirs) if (!dir.exists(d)) die("not a directory: ", d)
pairs <- if (length(args) == 3L) trimws(strsplit(args[3], ",", fixed = TRUE)[[1]]) else PAIRS_ALL
if (anyDuplicated(pairs) || !all(grepl("^(fed|vic|nsw|qld|sa|wa)[0-9]{4}$", pairs))) die("bad or duplicated pair list: ", paste(pairs, collapse = ","))
harness_of <- function(p) sub("[0-9]{4}$", "", p)
need_h <- unique(harness_of(pairs))

rd <- function(f) {
  d <- tryCatch(utils::read.csv(f, stringsAsFactors = FALSE), error = function(e) die("cannot read ", f, ": ", conditionMessage(e)))
  if (!nrow(d)) die("empty file ", f)
  d
}

# ---- load one arm ---------------------------------------------------------------------------
load_arm <- function(dir, arm) {
  fs <- list.files(dir, pattern = "^backtest-.*\\.csv$", full.names = FALSE)
  if (!length(fs)) die(arm, ": no backtest-*.csv files in ", dir)
  summ <- list(); det <- list()
  for (b in fs) {
    m <- regmatches(b, regexec("^backtest-(fed|vic|nsw|qld|sa|wa)([0-9]{0,4})-(.*)\\.csv$", b))[[1]]
    if (!length(m)) die(arm, ": cannot classify file ", b, " (not backtest-<harness>[yyyy]-...csv)")
    h <- m[2]; yr <- m[3]; rest <- m[4]
    if (grepl("^(allprobs|totals|ourtcp)-", rest)) next
    if (!h %in% need_h) next
    fpair <- if (nzchar(yr)) paste0(h, yr) else NA_character_
    if (!is.na(fpair) && !fpair %in% pairs) next   # a per-pair file for a pair we were not asked about
    if (grepl("^sharedetail-", rest)) {
      d <- rd(file.path(dir, b))
      if (!setequal(names(d), COLS_DETAIL)) die(arm, ": ", b, " has columns {", paste(names(d), collapse = ","), "}, expected {", paste(COLS_DETAIL, collapse = ","), "}")
      d$file <- b; d$fpair <- fpair; det[[b]] <- d
    } else {
      d <- rd(file.path(dir, b))
      want <- COLS_SUMMARY[[h]]
      if (!setequal(names(d), want)) die(arm, ": ", b, " has columns {", paste(names(d), collapse = ","), "}, expected {", paste(want, collapse = ","), "} for ", h)
      if (h == "nsw") {
        if (is.na(fpair)) die(arm, ": nsw summary ", b, " has no pair column and no yyyy in its name")
        names(d)[names(d) == "p"] <- "prob"; d$pair <- fpair; d$bin <- NULL
      }
      if (!"coverage" %in% names(d)) d$coverage <- NA_real_
      d$file <- b; d$fpair <- fpair; summ[[b]] <- d
    }
  }
  S <- do.call(rbind, lapply(summ, function(d) d[, c("seat", "actual", "prob", "pred", "pred_p", "pair", "coverage", "file", "fpair")]))
  D <- do.call(rbind, det)
  if (is.null(S) || is.null(D)) die(arm, ": no summary or no sharedetail files found for harnesses ", paste(need_h, collapse = ","))
  rownames(S) <- NULL; rownames(D) <- NULL
  for (nm in c("seat", "actual", "pred", "pair")) if (anyNA(S[[nm]]) || any(!nzchar(S[[nm]]))) die(arm, ": NA/empty ", nm, " in summary files")
  for (nm in c("prob", "pred_p")) if (anyNA(S[[nm]]) || any(S[[nm]] < 0 | S[[nm]] > 1)) die(arm, ": NA or out-of-range ", nm, " in summary files")
  for (nm in c("seat", "party", "pair")) if (anyNA(D[[nm]]) || any(!nzchar(D[[nm]]))) die(arm, ": NA/empty ", nm, " in sharedetail files")
  for (nm in c("pred_share", "actual_share")) if (anyNA(D[[nm]]) || !is.numeric(D[[nm]]) || any(D[[nm]] < 0)) die(arm, ": NA, non-numeric or negative ", nm, " in sharedetail files")
  for (X in list(list("summary", S), list("sharedetail", D))) {
    nm <- X[[1]]; d <- X[[2]]
    if (!all(d$pair %in% pairs)) die(arm, ": ", nm, " holds pairs not requested: ", paste(setdiff(unique(d$pair), pairs), collapse = ","))
    miss <- setdiff(pairs, d$pair)
    if (length(miss)) die(arm, ": ", nm, " is MISSING pair(s): ", paste(miss, collapse = ","))
    nf <- tapply(d$file, d$pair, function(x) length(unique(x)))
    if (any(nf != 1L)) die(arm, ": ", nm, " DUPLICATE: pair(s) ", paste(names(nf)[nf != 1L], collapse = ","), " appear in more than one file: ",
                           paste(unique(d$file[d$pair %in% names(nf)[nf != 1L]]), collapse = " | "))
    bad <- !is.na(d$fpair) & d$fpair != d$pair
    if (any(bad)) die(arm, ": ", nm, " file name says ", paste(unique(d$fpair[bad]), collapse = ","), " but its pair column says ", paste(unique(d$pair[bad]), collapse = ","))
    if (any(harness_of(d$pair) != sub("^backtest-(fed|vic|nsw|qld|sa|wa).*", "\\1", d$file))) die(arm, ": ", nm, " pair/harness disagree with file name")
  }
  S$sk <- paste(S$pair, S$seat, sep = "|"); D$sk <- paste(D$pair, D$seat, sep = "|"); D$ck <- paste(D$sk, D$party, sep = "|")
  if (anyDuplicated(S$sk)) die(arm, ": duplicate (pair, seat) in summary: ", paste(head(S$sk[duplicated(S$sk)], 5), collapse = "; "))
  if (anyDuplicated(D$ck)) die(arm, ": duplicate (pair, seat, party) in sharedetail: ", paste(head(D$ck[duplicated(D$ck)], 5), collapse = "; "))
  if (!setequal(S$sk, unique(D$sk))) die(arm, ": summary seats and sharedetail seats differ (", length(setdiff(S$sk, D$sk)), " only in summary, ",
                                         length(setdiff(unique(D$sk), S$sk)), " only in sharedetail)")
  # winner label must exist as a class in the seat's detail rows, else lookups below would silently miss
  list(S = S, D = D)
}

E <- load_arm(dirs[["early"]], "early"); L <- load_arm(dirs[["late"]], "late")
cat(sprintf("compare_zero_order | early: %s | late: %s\n", dirs[["early"]], dirs[["late"]]))
cat(sprintf("files: early summary %d + sharedetail %d | late summary %d + sharedetail %d\n",
            length(unique(E$S$file)), length(unique(E$D$file)), length(unique(L$S$file)), length(unique(L$D$file))))

# ---- R7: pairs and seats scored per arm, and identical across arms ---------------------------
r7 <- data.frame(pair = pairs, seats_early = as.integer(table(factor(E$S$pair, pairs))), seats_late = as.integer(table(factor(L$S$pair, pairs))),
                 cells_early = as.integer(table(factor(E$D$pair, pairs))), cells_late = as.integer(table(factor(L$D$pair, pairs))))
cat("\nTable R7 - seat-elections and cells scored per pair in each arm (counts; the two arms must be equal, any difference is a refusal)\n")
show(r7)
cat(sprintf("pairs scored: early %d, late %d | seat-elections: early %d, late %d | cells: early %d, late %d\n",
            sum(r7$seats_early > 0), sum(r7$seats_late > 0), sum(r7$seats_early), sum(r7$seats_late), sum(r7$cells_early), sum(r7$cells_late)))
if (!identical(r7$seats_early, r7$seats_late) || !identical(r7$cells_early, r7$cells_late) || !setequal(E$D$ck, L$D$ck) || !setequal(E$S$sk, L$S$sk))
  die("R7 FAIL: the arms do not score the same pairs, seats and cells. Nothing below is comparable.")
cat("R7: PASS (same pairs, seats and cells in both arms)\n")

# ---- merge arms; check what must be identical between arms ----------------------------------
S <- merge(E$S[, c("sk", "pair", "seat", "actual", "prob", "pred", "pred_p")], L$S[, c("sk", "actual", "prob", "pred", "pred_p")],
           by = "sk", suffixes = c("_e", "_l"))
D <- merge(E$D[, c("ck", "sk", "pair", "seat", "party", "pred_share", "actual_share", "xgb_primary_on")],
           L$D[, c("ck", "pred_share", "actual_share", "xgb_primary_on")], by = "ck", suffixes = c("_e", "_l"))
if (nrow(S) != nrow(E$S) || nrow(D) != nrow(E$D)) die("merge lost rows (summary ", nrow(S), "/", nrow(E$S), ", detail ", nrow(D), "/", nrow(E$D), ")")
if (any(S$actual_e != S$actual_l)) die("the ACTUAL winner differs between arms in ", sum(S$actual_e != S$actual_l), " seat(s), e.g. ", paste(head(S$sk[S$actual_e != S$actual_l], 3), collapse = "; "), " (swapped files?)")
if (any(abs(D$actual_share_e - D$actual_share_l) > TOL)) die("actual_share differs between arms in ", sum(abs(D$actual_share_e - D$actual_share_l) > TOL), " cell(s) (swapped files?)")
if (any(D$xgb_primary_on_e != D$xgb_primary_on_l)) die("xgb_primary_on differs between arms: the arms differ in more than the zeroing order")
D$act <- D$actual_share_e
S$actual <- S$actual_e
# diagnostic: the actual winner should usually also lead on actual primary share
lead <- do.call(rbind, lapply(split(D, D$pair), function(x) {
  top <- tapply(seq_len(nrow(x)), x$sk, function(i) x$party[i][which.max(x$act[i])])
  s <- S[S$pair == x$pair[1], ]
  data.frame(pair = x$pair[1], agree = mean(top[s$sk] == s$actual))
}))
if (any(lead$agree < 0.6)) die("summary winners agree with the sharedetail primary-share leader in only ", paste(sprintf("%s %.2f", lead$pair[lead$agree < 0.6], lead$agree[lead$agree < 0.6]), collapse = ", "), " (< 0.60): summary and sharedetail look like different elections")

D$changed <- abs(D$pred_share_l - D$pred_share_e) > TOL
exempt <- {
  tot <- aggregate(act ~ pair + party, D, sum)
  paste(tot$pair[tot$act == 0], tot$party[tot$act == 0], sep = "|")
}
D$exempt <- paste(D$pair, D$party, sep = "|") %in% exempt

# ---- cells differing per pair ----------------------------------------------------------------
cells <- do.call(rbind, lapply(pairs, function(p) {
  x <- D[D$pair == p, ]
  data.frame(pair = p, cells = nrow(x), cells_differ = sum(x$changed), seats = length(unique(x$sk)),
             seats_with_a_differing_cell = length(unique(x$sk[x$changed])),
             max_abs_diff_pts = if (any(x$changed)) max(abs(x$pred_share_l - x$pred_share_e)) else 0)
}))
cat("\nTable 0 - cells whose predicted primary share differs between arms, per pair (counts; 0 everywhere means the arms are the same forecast)\n")
show(cells)
cat(sprintf("total: %d of %d cells differ (%.1f%%) in %d of %d seat-elections\n", sum(cells$cells_differ), sum(cells$cells),
            100 * sum(cells$cells_differ) / sum(cells$cells), sum(cells$seats_with_a_differing_cell), sum(cells$seats)))

# ---- C0 --------------------------------------------------------------------------------------
D$ghost_e <- D$act == 0 & D$pred_share_e > 0
D$ghost_l <- D$act == 0 & D$pred_share_l > 0
c0 <- do.call(rbind, lapply(pairs, function(p) { x <- D[D$pair == p, ]
  data.frame(pair = p, ghost_early = sum(x$ghost_e & !x$exempt), ghost_late = sum(x$ghost_l & !x$exempt),
             exempt_cells_late = sum(x$ghost_l & x$exempt), exempt_classes = paste(sort(unique(x$party[x$exempt])), collapse = "/")) }))
cat("\nTable C0 - ghost cells (class did not stand, actual share 0, but forecast share > 0) outside the by-design absent-class list (counts; the LATE column must be 0 in every pair)\n")
show(c0)
gl <- D[D$ghost_l & !D$exempt, ]
if (nrow(gl)) {
  cat("late-arm ghost cells:\n")
  show(gl[order(-gl$pred_share_l), c("pair", "seat", "party", "pred_share_e", "pred_share_l")][seq_len(min(30, nrow(gl))), ])
}
cat(sprintf("C0: %s - %d late-arm ghost cell(s) (early arm: %d; exempt absent-class cells in late: %d) across %d pair(s)\n",
            if (nrow(gl) == 0) "PASS" else "FAIL", nrow(gl), sum(D$ghost_e & !D$exempt), sum(D$ghost_l & D$exempt), length(pairs)))
if (nrow(gl)) flag(sprintf("C0: %d late-arm ghost cell(s)", nrow(gl)))

# ---- C2 / C3 ---------------------------------------------------------------------------------
S$ll_e <- -log(pmax(S$prob_e, EPS)); S$ll_l <- -log(pmax(S$prob_l, EPS))
S$br_e <- (1 - S$prob_e)^2; S$br_l <- (1 - S$prob_l)^2
S$hit_e <- S$pred_e == S$actual; S$hit_l <- S$pred_l == S$actual
pooled <- data.frame(arm = c("early", "late", "late - early"), n_seats = c(nrow(S), nrow(S), NA),
  log_loss = c(mean(S$ll_e), mean(S$ll_l), mean(S$ll_l) - mean(S$ll_e)),
  brier = c(mean(S$br_e), mean(S$br_l), mean(S$br_l) - mean(S$br_e)),
  top_pick_correct = c(sum(S$hit_e), sum(S$hit_l), sum(S$hit_l) - sum(S$hit_e)),
  pct_correct = 100 * c(mean(S$hit_e), mean(S$hit_l), mean(S$hit_l) - mean(S$hit_e)))
cat("\nTable C2a - pooled over all scored seat-elections: seat log loss (winner probability clamped at 1e-6; lower is better), Brier (mean (1-p)^2 on the winner probability; lower is better), seats where the top pick won (higher is better)\n")
show(pooled, 5)
perpair <- do.call(rbind, lapply(pairs, function(p) { x <- S[S$pair == p, ]
  data.frame(pair = p, n_seats = nrow(x), ll_early = mean(x$ll_e), ll_late = mean(x$ll_l), delta = mean(x$ll_l) - mean(x$ll_e),
             worse_than_guard = (mean(x$ll_l) - mean(x$ll_e)) > GUARD_C3) }))
# DECISION (Claude, 2026-10-04, before any late-arm result existed): the 0.0020 guard is carried over
# from v61, whose "22-election log loss 0.3434 -> 0.3413" is the UNWEIGHTED MEAN OVER PAIRS of per-pair
# log loss. So C2 is gated on that mean's delta. The seat-weighted pooled delta is printed for
# information only.
dl <- mean(perpair$delta)
dl_pooled <- mean(S$ll_l) - mean(S$ll_e)
cat(sprintf("C2: %s - unweighted mean over the %d pairs of the per-pair log loss delta (late minus early) %+.5f (guard: not worse than %+.4f; negative is better)\n",
            if (dl <= GUARD_C2) "PASS" else "FAIL", length(pairs), dl, GUARD_C2))
cat(sprintf("     unweighted mean of per-pair log loss: early %.4f, late %.4f (the v61 headline 0.3413 is this kind of mean)\n",
            mean(perpair$ll_early), mean(perpair$ll_late)))
cat(sprintf("     informational: seat-weighted pooled delta %+.5f over %d seat-elections; sd of the %d per-pair deltas %.5f; SE of their mean %.5f\n",
            dl_pooled, nrow(S), nrow(perpair), stats::sd(perpair$delta), stats::sd(perpair$delta) / sqrt(nrow(perpair))))
if (dl > GUARD_C2) flag(sprintf("C2: mean per-pair log loss delta %+.5f > %+.4f", dl, GUARD_C2))
cat("\nTable C3 - mean seat log loss per pair and late-minus-early delta (lower is better; delta > +0.011 is flagged)\n")
show(perpair, 5)
cat(sprintf("C3: %s - %d pair(s) worse than %+.3f; largest delta %+.5f (%s), smallest %+.5f (%s)\n",
            if (!any(perpair$worse_than_guard)) "PASS" else "FAIL", sum(perpair$worse_than_guard), GUARD_C3,
            max(perpair$delta), perpair$pair[which.max(perpair$delta)], min(perpair$delta), perpair$pair[which.min(perpair$delta)]))
if (any(perpair$worse_than_guard)) flag(sprintf("C3: %s worse than %+.3f", paste(perpair$pair[perpair$worse_than_guard], collapse = ","), GUARD_C3))

EDGES <- c(0, 0.9, 0.95, 0.99, 0.999, 1)
rel <- do.call(rbind, lapply(c("early", "late"), function(a) {
  pp <- if (a == "early") S$pred_p_e else S$pred_p_l; hit <- if (a == "early") S$hit_e else S$hit_l
  band <- cut(pp, EDGES, include.lowest = TRUE)
  do.call(rbind, lapply(levels(band), function(b) { k <- band == b
    data.frame(arm = a, band = b, n = sum(k), n_wrong = sum(!hit[k]), said_pct = if (any(k)) 100 * mean(pp[k]) else NA_real_,
               got_pct = if (any(k)) 100 * mean(hit[k]) else NA_real_) })) }))
cat("\nTable C2b - reliability by confidence band of the top pick: n seats, n_wrong = seats where the top pick lost (counts), said = mean stated probability, got = share that won (said and got should match; reported, not decisive)\n")
show(rel, 4)

# ---- C4 --------------------------------------------------------------------------------------
D$zero_e <- D$pred_share_e < TOL; D$zero_l <- D$pred_share_l < TOL
c4 <- D[D$zero_l & !D$zero_e & D$act > 0, ]
c4pre <- sum(D$zero_e & D$act > 0)
cat("\nTable C4 - cells zeroed in the late arm, not in the early arm, whose class DID stand (actual share > 0): must be none\n")
show(c4[, c("pair", "seat", "party", "pred_share_e", "pred_share_l", "act")])
cat(sprintf("C4: %s - %d cell(s) zeroed where the class stood, of %d late-arm zeroed cells (early arm already had %d such cells; zeroed cells in early: %d)\n",
            if (nrow(c4) == 0) "PASS" else "FAIL", nrow(c4), sum(D$zero_l), c4pre, sum(D$zero_e)))
if (nrow(c4)) flag(sprintf("C4: %d class-stood cell(s) zeroed", nrow(c4)))

# ---- R1 --------------------------------------------------------------------------------------
fl <- S[S$prob_l <= FLOOR_P & S$prob_e > FLOOR_P, ]; fo <- S[S$prob_e <= FLOOR_P & S$prob_l > FLOOR_P, ]
cat("\nTable R1 - seats where the ACTUAL winner is at the probability floor (p <= 1e-4 in the file) in late but not early: must be none\n")
show(fl[, c("pair", "seat", "actual", "prob_e", "prob_l")], 5)
cat(sprintf("R1: %s - %d floor event(s) late-not-early (reverse, early-not-late: %d; seats at the floor in early: %d, in late: %d)\n",
            if (nrow(fl) == 0) "PASS" else "FAIL", nrow(fl), nrow(fo), sum(S$prob_e <= FLOOR_P), sum(S$prob_l <= FLOOR_P)))
if (nrow(fl)) flag(sprintf("R1: %d floor event(s)", nrow(fl)))

# ---- R2 --------------------------------------------------------------------------------------
chg_seats <- unique(D$sk[D$changed]); A <- D[D$sk %in% chg_seats, ]
cat(sprintf("\nR2 set: %d cells in %d seat-elections where any cell differs between arms\n", nrow(A), length(chg_seats)))
if (nrow(A)) {
  A$err_e <- A$pred_share_e - A$act; A$err_l <- A$pred_share_l - A$act
  r2 <- do.call(rbind, lapply(split(A, A$party), function(x) {
    n <- nrow(x); se <- if (n >= 2L) stats::sd(x$err_l - x$err_e) / sqrt(n) else NA_real_
    grow <- abs(mean(x$err_l)) - abs(mean(x$err_e))
    data.frame(class = x$party[1], n_cells = n, bias_early = mean(x$err_e), bias_late = mean(x$err_l), abs_bias_change = grow, se = se,
               refuse = grow > 0 & (is.na(se) | grow > 2 * se)) }))
  cat("Table R2 - signed primary error (predicted minus actual, points) per class on those cells; refuse = absolute bias grew by more than 2 SE (smaller absolute bias is better)\n")
  show(r2, 4)
  cat(sprintf("R2: %s - %d class(es) flagged (n < 2 classes cannot be assessed and are flagged if bias grew)\n", if (!any(r2$refuse)) "PASS" else "FAIL", sum(r2$refuse)))
  if (any(r2$refuse)) flag(sprintf("R2: bias grew > 2 SE for %s", paste(r2$class[r2$refuse], collapse = ",")))
} else cat("R2: PASS (nothing differs between arms, so no bias can have moved)\n")

# ---- R3 --------------------------------------------------------------------------------------
fv <- S[S$pred_e != S$pred_l, ]
dk <- stats::setNames(seq_len(nrow(D)), D$ck)
ck_e <- paste(fv$sk, fv$pred_e, sep = "|"); ix <- dk[ck_e]
zeroed_led <- !is.na(ix) & D$act[ix] == 0 & D$pred_share_e[ix] > 0 & D$zero_l[ix]
unmatched <- sum(is.na(ix))
fv$excluded <- zeroed_led
cat(sprintf("\nR3: seats whose top pick differs between arms: %d of %d; excluded because the early leader was a class that did not stand and is zeroed in late: %d; counted: %d",
            nrow(fv), nrow(S), sum(zeroed_led), sum(!zeroed_led)))
if (unmatched) cat(sprintf(" (%d early leaders had a label not found among that seat's classes; counted, not excluded)", unmatched))
cat("\n")
cf <- fv[!fv$excluded, ]
if (nrow(fv)) { cat("Table R3a - every seat whose top pick changed (excluded = zeroed class led in early)\n"); show(fv[, c("pair", "seat", "pred_e", "pred_l", "actual", "excluded")]) }
if (nrow(cf)) {
  parties <- sort(unique(c(cf$pred_e, cf$pred_l)))
  r3 <- do.call(rbind, lapply(parties, function(p) { into <- sum(cf$pred_l == p); out <- sum(cf$pred_e == p)
    data.frame(class = p, flips_into = into, flips_out_of = out, binom_p_two_sided = stats::binom.test(into, into + out, 0.5)$p.value) }))
  cat("Table R3b - counted flips by class: seats won (top pick) by the class in late but not early, and the reverse (counts; one-way traffic into or out of a class is the refusal)\n")
  show(r3, 4)
}
refuse3 <- nrow(cf) >= 8L && any(r3$binom_p_two_sided < 0.05)
cat(sprintf("R3: %s - %d counted flip(s) (rule: refuse if >= 8 and a two-sided binomial test at p0 = 0.5 rejects at 0.05 for some class)\n", if (!refuse3) "PASS" else "FAIL", nrow(cf)))
if (refuse3) flag(sprintf("R3: one-way flips (%d)", nrow(cf)))

# ---- verdict ---------------------------------------------------------------------------------
cat(sprintf("\nSUMMARY: R7 PASS (reached here). %s\n", if (length(flags)) paste0(length(flags), " flag(s): ", paste(flags, collapse = " | ")) else "No flags."))
cat("Not scored here: C1 (direction only per the addendum), R4 (port shape, needs the SP2 log line), R5, R6, and the decision itself (see the prereg decision rule; clause refusals go to Pete).\n")

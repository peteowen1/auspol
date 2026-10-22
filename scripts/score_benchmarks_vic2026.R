# Score our Victoria 2026 forecast against the outside forecasts frozen before polling day.
#
#   Rscript scripts/score_benchmarks_vic2026.R --results=<csv>          # after the VEC declares every district
#   Rscript scripts/score_benchmarks_vic2026.R --dry-run                # before: our own favourite stands in as the winner
#
# The pre-registration is docs/plans/external-benchmark-vic2026-2026-10-20.md, and every rule below is quoted from it,
# not chosen here. This script reads ONLY the committed calls files (docs/benchmarks/vic2026/<date>/<source>-calls.csv,
# written by scripts/snapshot_benchmarks.R) and the results file. It never fetches and never reruns a model.
#
# RESULTS FILE: one row per district, columns `district, winner, status`. `winner` is the elected candidate's party as
# the VEC prints it (classed here by classify_party(), the one source of truth for classes); `status` is "declared"
# once the distribution of preferences is complete, anything else holds the district out (counted, never guessed).
#
# WHAT IT PRINTS, per freeze date (27 Nov is the comparison of record; 17 Nov is reported beside it):
#   - which capture each source contributes: the newest on or before the freeze date (carried forward, its date
#     printed), and none for a source first captured after 27 Nov;
#   - probability sources (ours, AE Forecasts): seat-winner log loss at the 1e-6 clamp with the 1e-4 clamp beside it,
#     Brier (mean squared distance of the winner's probability from 1), both lower is better, and the paired per-seat
#     log-loss difference against ours with its SE over seats;
#   - every source: favourite/call accuracy as x/n (ties excluded and counted) and seats per class against the actual.
# The SE over seats is for ONE election, whose seats share one statewide error: it overstates precision, and no
# "significant" claim is made from it.
#
# DRY RUN: the outcome is our own 27 Nov (or newest) favourite in each district. That is not a result; it checks the
# arithmetic on an answer known in advance: ours must score 88/88 and its log loss must equal the mean of -log of
# its favourite's probability. The script stops (EB9!) if either fails.
#
# Emits EB* codes. A `!` code means the scoring cannot be trusted as printed.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
DRY <- "--dry-run" %in% args
RESULTS <- sub("^--results=", "", grep("^--results=", args, value = TRUE))
if (!DRY && length(RESULTS) != 1L) stop("EB0! give --results=<csv> (district, winner, status) or --dry-run")

ROOT <- "docs/benchmarks/vic2026"
RECORD <- "2026-11-27"           # the comparison of record (plan: Fri 27 Nov, the day before polling day)
EARLY  <- "2026-11-17"           # reported beside it: the day before early voting
SOURCES <- c("ours", "aeforecasts", "ges", "jago-ours")
PROB_SOURCES <- c("ours", "aeforecasts")
N_DISTRICTS <- 88L
CLAMP <- 1e-6; CLAMP_ALT <- 1e-4

dates <- sort(list.dirs(ROOT, full.names = FALSE, recursive = FALSE))
dates <- dates[grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", dates)]
if (!length(dates)) stop("EB1! no dated capture folders under ", ROOT)
cat(sprintf("EB1  %d capture date(s) on disk: %s\n", length(dates), paste(dates, collapse = ", ")))

# The newest capture of a source on or before a freeze date. A source first captured after RECORD is excluded.
capture_for <- function(src, freeze) {
  have <- dates[file.exists(file.path(ROOT, dates, paste0(src, "-calls.csv")))]
  have <- have[have <= freeze]
  if (!length(have)) return(NA_character_)
  max(have)
}

read_calls <- function(src, day) {
  f <- file.path(ROOT, day, paste0(src, "-calls.csv"))
  dt <- fread(f, colClasses = c(district = "character", call_class = "character", prob = "numeric"))
  if (!identical(names(dt), c("district", "call_class", "prob"))) stop("EB2! ", f, " columns are ", paste(names(dt), collapse = ","))
  nd <- uniqueN(dt$district)
  if (nd != N_DISTRICTS) stop(sprintf("EB2! %s names %d districts, not %d", f, nd, N_DISTRICTS))
  if (src %in% PROB_SOURCES) {
    if (anyNA(dt$prob)) stop("EB2! ", f, " is a probability source with blank probabilities")
    tot <- dt[, .(s = sum(prob)), by = district]
    if (any(abs(tot$s - 1) > 0.01)) stop(sprintf("EB2! %s: probabilities do not sum to 1 in %d districts", f, sum(abs(tot$s - 1) > 0.01)))
  } else {
    if (nrow(dt) != N_DISTRICTS) stop(sprintf("EB2! %s is call-only but has %d rows for %d districts", f, nrow(dt), N_DISTRICTS))
  }
  dt[]
}

# Favourite per district. A tie at the top is NOT a call: excluded from accuracy and counted.
favourites <- function(dt) {
  if (all(is.na(dt$prob))) return(dt[, .(district, fav = call_class, tie = FALSE)])
  top <- dt[, .(pmax = max(prob)), by = district]
  m <- merge(dt, top, by = "district")[prob == pmax]
  m[, .(fav = call_class[1], tie = .N > 1L), by = district]
}

# ---- the outcome --------------------------------------------------------------------------------------------------
pick_ours <- capture_for("ours", RECORD)
if (is.na(pick_ours)) stop("EB3! no capture of our own forecast on or before ", RECORD)
if (DRY) {
  fv <- favourites(read_calls("ours", pick_ours))
  if (any(fv$tie)) stop("EB3! dry run: our own favourite is tied in ", sum(fv$tie), " districts")
  outcome <- fv[, .(district, actual = fav, declared = TRUE)]
  cat(sprintf("EB3  DRY RUN: the outcome is our own favourite from the %s capture. Nothing below is a result.\n", pick_ours))
} else {
  res <- fread(RESULTS, colClasses = "character")
  if (!all(c("district", "winner", "status") %in% names(res))) stop("EB3! ", RESULTS, " needs columns district, winner, status")
  ours_names <- unique(read_calls("ours", pick_ours)$district)
  miss <- setdiff(ours_names, res$district); extra <- setdiff(res$district, ours_names)
  if (length(miss) || length(extra))
    stop(sprintf("EB3! results do not name our 88 districts exactly: missing %s; unknown %s",
                 paste(miss, collapse = ", "), paste(extra, collapse = ", ")))
  if (anyDuplicated(res$district)) stop("EB3! results name a district twice: ", paste(res$district[duplicated(res$district)], collapse = ", "))
  outcome <- res[, .(district, winner = trimws(winner), declared = tolower(trimws(status)) == "declared")]
  # classify_party() never says "unknown": a blank name becomes IND and any name it does not recognise becomes OTH.
  # So a blank winner stops here, and every name -> class pair is printed for a human to read before the scores.
  if (any(outcome$declared & !nzchar(outcome$winner)))
    stop("EB3! declared districts with a blank winner: ", paste(outcome[declared & !nzchar(winner), district], collapse = ", "))
  outcome[, actual := classify_party(winner)]
  map <- outcome[declared == TRUE, .(seats = .N), by = .(winner, actual)][order(-seats)]
  cat("EB3  every declared winner's party as the VEC prints it, and the class it scores as (read this first):\n")
  for (i in seq_len(nrow(map))) cat(sprintf("       %-45s -> %-9s %2d seat(s)\n", map$winner[i], map$actual[i], map$seats[i]))
  if (any(map$actual == "OTH"))
    cat(sprintf("EB3? %d seat(s) scored OTH, the class classify_party() gives any name it does not recognise: check them by hand: %s\n",
                sum(map[actual == "OTH", seats]), paste(outcome[declared & actual == "OTH", district], collapse = ", ")))
  cat(sprintf("EB3  results %s: %d declared, %d held out (not yet declared; counted, not guessed)\n",
              RESULTS, sum(outcome$declared), sum(!outcome$declared)))
}
scored <- outcome[declared == TRUE]

# ---- scoring one freeze date -------------------------------------------------------------------------------------
score_date <- function(freeze, label) {
  cat(sprintf("\n==== %s: snapshots on or before %s ====\n", label, freeze))
  picks <- vapply(SOURCES, capture_for, character(1), freeze = freeze)
  for (s in SOURCES) cat(sprintf("EB4  %-12s %s\n", s, if (is.na(picks[[s]])) "no capture on or before this date: EXCLUDED"
                                                      else if (picks[[s]] == freeze) paste("captured", picks[[s]])
                                                      else paste("carried forward from", picks[[s]])))
  use <- names(picks)[!is.na(picks)]
  if (!"ours" %in% use) { cat("EB4! our own forecast has no capture for this date; nothing is scored\n"); return(invisible(NULL)) }
  calls <- setNames(lapply(use, function(s) read_calls(s, picks[[s]])), use)

  # Probabilities: the actual winner's probability, 0 where the source gave that class nothing.
  cat("\nSeat-winner log loss and Brier on the actual winner's probability (lower is better):\n")
  per_seat <- list()
  for (s in intersect(PROB_SOURCES, use)) {
    p <- merge(scored, calls[[s]], by.x = c("district", "actual"), by.y = c("district", "call_class"), all.x = TRUE)
    p[is.na(prob), prob := 0]
    if (nrow(p) != nrow(scored)) stop("EB5! ", s, ": ", nrow(p), " scored rows for ", nrow(scored), " declared districts")
    per_seat[[s]] <- p[, .(district, ll = -log(pmax(prob, CLAMP)), ll_alt = -log(pmax(prob, CLAMP_ALT)), br = (1 - prob)^2)]
  }
  pt <- rbindlist(lapply(names(per_seat), function(s) per_seat[[s]][, .(source = s, n = .N,
          logloss = mean(ll), logloss_1e4 = mean(ll_alt), brier = mean(br), at_floor = sum(ll >= -log(CLAMP) - 1e-9))]))
  print(pt[, .(source, n, logloss = round(logloss, 4), `logloss (1e-4 clamp)` = round(logloss_1e4, 4),
               brier = round(brier, 4), `seats at the 1e-6 floor` = at_floor)], row.names = FALSE)

  # Paired difference against ours: same seats, one number per seat, SE over seats.
  for (s in setdiff(names(per_seat), "ours")) {
    d <- merge(per_seat[[s]][, .(district, a = ll)], per_seat[["ours"]][, .(district, b = ll)], by = "district")[, a - b]
    cat(sprintf("EB5  %s minus ours, paired per seat: %+.4f log loss (SE %.4f over %d seats; positive means ours is better).\n",
                s, mean(d), sd(d) / sqrt(length(d)), length(d)))
  }
  cat("     The SE treats 88 seats as independent; they share one statewide error, so it overstates precision.\n")

  # Accuracy and seat totals, every source.
  cat("\nFavourite or call against the declared winner (x of n; ties are not calls):\n")
  acc <- rbindlist(lapply(use, function(s) {
    fv <- merge(scored, favourites(calls[[s]]), by = "district")
    data.table(source = s, correct = sum(fv$fav == fv$actual & !fv$tie), n = sum(!fv$tie), ties = sum(fv$tie))
  }))
  print(acc[, .(source, accuracy = sprintf("%d/%d", correct, n), ties)], row.names = FALSE)

  cat("\nSeats per class, called against actual (declared districts only):\n")
  tot <- rbindlist(lapply(use, function(s) merge(scored, favourites(calls[[s]]), by = "district")[tie == FALSE, .(source = s, cls = fav)]))
  tab <- dcast(rbind(tot, scored[, .(source = "ACTUAL", cls = actual)]), cls ~ source, fun.aggregate = length, value.var = "cls")
  setcolorder(tab, c("cls", "ACTUAL", intersect(use, names(tab))))
  print(tab, row.names = FALSE)
  invisible(list(pt = pt, acc = acc))
}

rec <- score_date(RECORD, "COMPARISON OF RECORD")
score_date(EARLY, "REPORTED BESIDE IT (day before early voting)")

# ---- the known-answer check, dry run only --------------------------------------------------------------------------
if (DRY) {
  if (is.null(rec)) stop("EB9! dry run scored nothing for the record date")
  a <- rec$acc[source == "ours"]
  fv <- favourites(read_calls("ours", pick_ours))
  p_fav <- merge(fv, read_calls("ours", pick_ours), by.x = c("district", "fav"), by.y = c("district", "call_class"))$prob
  want_ll <- mean(-log(pmax(p_fav, CLAMP)))
  got_ll <- rec$pt[source == "ours", logloss]
  if (a$correct != N_DISTRICTS || a$n != N_DISTRICTS || abs(got_ll - want_ll) > 1e-12)
    stop(sprintf("EB9! dry run failed its known answer: ours %d/%d (want 88/88), log loss %.6f (want %.6f)",
                 a$correct, a$n, got_ll, want_ll))
  cat(sprintf("\nEB9  dry run: ours %d/%d and log loss %.4f match the known answer. The scorer is ready for the VEC results.\n",
              a$correct, a$n, got_ll))
}

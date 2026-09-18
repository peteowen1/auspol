# For every AEF-7 seat, what did OUR simulation and AEF's simulation say
# about the pairing that ACTUALLY happened -- not just each side's own
# top-frequency guess.
#
# WHY THIS EXISTS. build_aef_tcp.R and the "ITG final two"/"AEF final two"
# columns on the ledger both report each side's #1-most-likely scenario,
# which is the right "headline" number but means the ledger's TCP MAE was
# only ever scored on the ~86-87% of seats where that #1 guess happened to
# match the real pairing (n=568/574 of 660) -- silently dropping the seats
# where a side got the WINNER right via a pairing it did not lead with, or
# missed the pairing outright. Both simulations already carry every pairing
# they drew, not just the top one:
#   - ours: tcp_scenarios() writes output/backtest-<pair>-ourtcp*.csv, one
#     row per (seat, scenario) with freq and f1_tcp_pct, ALL pairings.
#   - AEF's: seatTcpScenarios/seatTcpBands in external/reference/aef/*-
#     summary.json (build_aef_tcp.R currently reads only the top one).
# This script re-reads both sources and, for each seat, finds the scenario
# matching the REAL pairing (from output/aef7-final-two-and-tcp-reference.csv,
# an official/derived source, unaffected by our model) regardless of whether
# it was that side's #1 pick. Pete asked for TCP scored on all 660 seats,
# not just the matched subset, 2026-09-18.
#
# Emits AT7 codes. Writes output/aef7-tcp-actual.csv.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

eps <- 1e-6
OUT <- "output"
RAW <- file.path("external", "reference", "aef")

ref_all <- fread(file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), showProgress = FALSE)
ref_all <- ref_all[, .(pair, seat, f1, f2, f2cp)]
# 28 seats (27 vic2022, 1 nsw2023) have never had a resolved official/derived
# final-two in this reference file at all -- a pre-existing data gap, not
# something this script can fill. There is no ground truth to score a TCP
# prediction against for these, so they are excluded rather than silently
# scored as "the pairing never occurred" (freq 0), which would be a
# different and wrong claim about the MODEL rather than the DATA.
unresolved <- ref_all[is.na(f1) | is.na(f2) | f1 == "" | f2 == ""]
ref <- ref_all[!(is.na(f1) | is.na(f2) | f1 == "" | f2 == "")]
cat(sprintf("AT7  %d of %d official rows have a resolved final-two to score against (%d unresolved, pre-existing gap: %s)\n",
            nrow(ref), nrow(ref_all), nrow(unresolved),
            paste(names(table(unresolved$pair)), table(unresolved$pair), sep = "=", collapse = ", ")))

actual_share_of <- function(named, w, r, wshare)
  fifelse(named == w, wshare, fifelse(named == r, 100 - wshare, NA_real_))

# ---- OUR side: the ourtcp file from the SAME harness run as the pair's
# win file (scripts/ledger_inputs.R). The previous rule -- newest by name,
# skipping anything named n5000 -- silently paired the new run's seat
# probabilities with the OLD run's TCP scenarios on 2026-09-18. ----
PAIRS <- unique(ref$pair)
source("scripts/ledger_inputs.R")

our_rows <- rbindlist(lapply(PAIRS, function(pr) {
  x <- run_table(pr, "ourtcp")
  if (is.null(x)) { cat(sprintf("AT7! no ourtcp file for %s\n", pr)); return(NULL) }
  x[, pair := pr]
  x
}), fill = TRUE)

our_match <- merge(ref, our_rows, by = c("pair", "seat"), all.x = TRUE,
                    allow.cartesian = TRUE)
our_match <- our_match[(f1.y == f1.x & f2.y == f2.x) | (f1.y == f2.x & f2.y == f1.x)]
setnames(our_match, c("f1.y", "f2.y"), c("our_row_f1", "our_row_f2"))
# our_tcp_pred_pct is what WE predicted for our_row_f1 within this pairing;
# our_tcp_actual_share is what our_row_f1 actually got in real life (f2cp is
# the REAL winner f1.x's real share, so a named party that is the real
# runner-up gets 100-f2cp instead) -- two different quantities, compared to
# each other for the MAE, never substituted for one another.
#
# our_row_f1 is whichever of the real two finalists our OWN scenario table
# happens to list first -- an arbitrary artefact of tcp_scenarios()'s own
# row order, not "our predicted winner". f1_tcp_pct inherits that same
# arbitrariness and can legitimately read under 50% (our_row_f1 is our
# PREDICTED LOSER of this pairing) -- exactly the confusion Pete hit on
# Wentworth fed2025 with AEF's data (documented on the ledger page itself)
# and then on Mallee fed2022 with a second, related confusion (ITG
# confidence there was 0.853 for a DIFFERENT pairing, LNP v IND, that our
# top scenario guessed and which never happened -- see the changelog).
# our_tcp_pick/our_tcp_pick_pct re-orient to "whichever of the real two
# finalists we predicted to win, and what we gave them", always >=50%
# by construction, like every other 2CP number on this page.
our_match[, our_tcp_pick := fifelse(f1_tcp_pct >= 50, our_row_f1,
                                     fifelse(our_row_f1 == f1.x, f2.x, f1.x))]
our_match[, our_tcp_pick_pct := fifelse(f1_tcp_pct >= 50, f1_tcp_pct, 100 - f1_tcp_pct)]
our_match <- our_match[, .(pair, seat, our_tcp_actual_freq = freq,
                            our_tcp_pred_pct = f1_tcp_pct,
                            our_tcp_actual_share = actual_share_of(our_row_f1, f1.x, f2.x, f2cp),
                            our_tcp_pick, our_tcp_pick_pct)]
setnames(our_match, "seat", "seat_m")
ref <- merge(ref, our_match, by.x = c("pair", "seat"), by.y = c("pair", "seat_m"), all.x = TRUE)
# a seat where our sim never once drew the real pairing has no row here at
# all -- that is a real, informative zero, not missing data.
ref[is.na(our_tcp_actual_freq), our_tcp_actual_freq := 0]
cat(sprintf("AT7  our side: %d of %d seats had the real pairing somewhere in their scenario table\n",
            sum(ref$our_tcp_actual_freq > 0), nrow(ref)))

# ---- AEF side: search every scenario (not just their #1) in the raw cache ----
AEF_CODE <- c(fed2022 = "2022fed", fed2025 = "2025fed", nsw2023 = "2023nsw",
              qld2024 = "2024qld", sa2026  = "2026sa",  vic2022 = "2022vic",
              wa2025  = "2025wa")
aef_class_lookup <- function(pa, pn) {
  idx  <- vapply(pa, function(p) as.character(p[[1]]), character(1))
  abbr <- vapply(pa, function(p) as.character(p[[2]]), character(1))
  nm_idx <- vapply(pn, function(p) as.character(p[[1]]), character(1))
  name <- vapply(pn, function(p) as.character(p[[2]]), character(1))
  stopifnot(identical(idx, nm_idx))
  stats::setNames(classify_party(name = name, code = abbr), idx)
}

aef_actual_one <- function(pr, code, official) {
  fs <- file.path(RAW, sprintf("%s-summary.json", code))
  if (!file.exists(fs)) { cat(sprintf("AT7! missing %s for %s\n", fs, pr)); return(NULL) }
  j <- fromJSON(fs, simplifyVector = FALSE)$report
  seats <- unlist(j$seatNames)
  lookup <- aef_class_lookup(j$partyAbbr, j$partyName)
  scen <- j$seatTcpScenarios; band <- j$seatTcpBands
  rows <- vector("list", length(seats))
  for (i in seq_along(seats)) {
    sn <- seats[i]
    off <- official[seat == sn]
    if (!nrow(off)) next
    sc <- scen[[i]]; bd <- band[[i]]
    if (!length(sc)) next
    freqs <- vapply(sc, function(x) as.numeric(x[[2]]), numeric(1))
    matched <- NULL; matched_freq <- 0
    for (k in seq_along(sc)) {
      pr_k <- sc[[k]][[1]]
      idxA <- as.character(pr_k[[1]]); idxB <- as.character(pr_k[[2]])
      clsA <- unname(lookup[idxA]); clsB <- unname(lookup[idxB])
      if (is.na(clsA) || is.na(clsB)) next
      if ((clsA == off$f1 && clsB == off$f2) || (clsA == off$f2 && clsB == off$f1)) {
        matched <- list(idxA = idxA, idxB = idxB, clsA = clsA, clsB = clsB)
        matched_freq <- freqs[k]
        break
      }
    }
    if (is.null(matched)) {
      rows[[i]] <- data.table(seat = sn, aef_tcp_actual_freq = 0,
                               aef_tcp_pred_pct = NA_real_, aef_tcp_actual_share = NA_real_,
                               aef_tcp_pick = NA_character_, aef_tcp_pick_pct = NA_real_)
      next
    }
    bmatch <- NULL
    for (b in bd) {
      bp <- b[[1]]
      if (as.character(bp[[1]]) == matched$idxA && as.character(bp[[2]]) == matched$idxB) { bmatch <- b; break }
    }
    pct <- NA_real_
    if (!is.null(bmatch)) {
      pctiles <- unlist(bmatch[[2]])
      if (length(pctiles) == 15) pct <- pctiles[8]
    }
    # pct is AEF's PREDICTED share for matched$clsA within this scenario;
    # the actual/real share that party got is a different quantity (off$f2cp
    # is the REAL winner off$f1's real share) -- kept as two columns, never
    # substituted for one another (this conflation was a bug caught before
    # this script's first real run, same mistake fixed on the "our" side above).
    #
    # matched$clsA is an arbitrary "party A" from AEF's own scenario-tuple
    # ordering, not their predicted winner -- Wentworth fed2025 is the case
    # already documented on the ledger page for this: "AEF pick: LNP" at
    # 43.5% actually meant AEF favoured the OTHER finalist (IND) at 56.5%,
    # correctly. aef_tcp_pick/aef_tcp_pick_pct re-orient to always name
    # whichever of the real two finalists AEF favoured, always >=50%.
    pick <- if (is.na(pct)) NA_character_ else if (pct >= 50) matched$clsA else matched$clsB
    pick_pct <- if (is.na(pct)) NA_real_ else if (pct >= 50) pct else 100 - pct
    rows[[i]] <- data.table(seat = sn, aef_tcp_actual_freq = round(matched_freq, 4),
                             aef_tcp_pred_pct = pct,
                             aef_tcp_actual_share = actual_share_of(matched$clsA, off$f1, off$f2, off$f2cp),
                             aef_tcp_pick = pick, aef_tcp_pick_pct = pick_pct)
  }
  out <- rbindlist(rows, fill = TRUE)
  out[, pair := pr]
  out
}

aef_rows <- rbindlist(Map(function(pr, code) aef_actual_one(pr, code, ref[pair == pr]),
                           names(AEF_CODE), unname(AEF_CODE)), fill = TRUE)
ref <- merge(ref, aef_rows, by = c("pair", "seat"), all.x = TRUE)
ref[is.na(aef_tcp_actual_freq), aef_tcp_actual_freq := 0]
cat(sprintf("AT7  AEF side: %d of %d seats had the real pairing somewhere in their scenario table\n",
            sum(ref$aef_tcp_actual_freq > 0), nrow(ref)))

# put the 28 unresolved-final-two seats back so downstream joins keep all
# 660 rows -- their new TCP columns are genuinely NA (no ground truth),
# distinct from a resolved seat whose freq is a real, informative 0.
full <- rbind(ref, unresolved, fill = TRUE)
fwrite(full, file.path(OUT, "aef7-tcp-actual.csv"))
cat(sprintf("AT7  wrote %s (%d rows, %d scoreable + %d unresolved)\n",
            file.path(OUT, "aef7-tcp-actual.csv"), nrow(full), nrow(ref), nrow(unresolved)))

cat("\nAT7  pooled, all seats where the pairing occurred in the table (else eps floor for log loss):\n")
ll <- function(freq) -log(pmax(freq, eps))
cat(sprintf("  TCP scenario log loss  -- ours %.4f | AEF %.4f\n",
            mean(ll(ref$our_tcp_actual_freq)), mean(ll(ref$aef_tcp_actual_freq))))
m <- ref[!is.na(our_tcp_pred_pct)]
a <- ref[!is.na(aef_tcp_pred_pct)]
cat(sprintf("  TCP MAE on the real pairing (n=%d ours / %d AEF) -- ours %.2f | AEF %.2f\n",
            nrow(m), nrow(a),
            mean(abs(m$our_tcp_pred_pct - m$our_tcp_actual_share)),
            mean(abs(a$aef_tcp_pred_pct - a$aef_tcp_actual_share))))

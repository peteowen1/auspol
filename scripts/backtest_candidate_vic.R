# Backtest the candidate-level seat model on Victoria -- the state the live
# forecast is actually for.
#
# Two pairs, both newly possible: 2014 -> 2018 and 2018 -> 2022. Until the VEC
# archive was found this morning the repo held one Victorian election's
# seat-level first preferences, so there was nothing to score against.
#
# Nothing leaks. Each pair swings from the EARLIER election's district first
# preferences, uses the EARLIER election's flow matrix, and is scored against
# the commission's own declared winners.
#
# Emits BV* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

N_SIMS <- 20000; SEED <- 42; SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()

PAIRS <- list(
  list(from = 2014, to = 2018),
  list(from = 2018, to = 2022))

share_of <- function(f) {
  d <- fread(file.path(P, f), showProgress = FALSE)
  d[, .(votes = sum(votes)), by = .(seat, party)]
}

out_all <- list()
for (K in PAIRS) {
  fa <- share_of(sprintf("vec-%d-vic-firstprefs.csv", K$from))
  fb <- share_of(sprintf("vec-%d-vic-firstprefs.csv", K$to))
  tx <- fread(file.path(P, sprintf("vec-%d-vic-transfers.csv", K$from)),
              showProgress = FALSE)
  # LEAKAGE GUARD, asserted on the source rather than on a filtered copy: a
  # table filtered to one election trivially contains only that election.
  stopifnot(all(tx$election == sprintf("vic%d", K$from)))
  fm <- build_flow_matrix(tx, min_n = 3L)

  wf <- file.path(P, sprintf("vec-%d-vic-winners.csv", K$to))
  if (file.exists(wf)) {
    win <- fread(wf); truth_src <- "the VEC's declared winners"
  } else {
    # 2022 has no archived winners file. The 2026 seat file records who HOLDS
    # each seat, which is the 2022 winner except where a by-election has since
    # changed hands -- Mulgrave, Warrandyte and Narracan all went to one. Those
    # are named and excluded rather than scored against the wrong party.
    s <- as.data.table(load_seats(2026, "vic"))[, .(seat, winner = incumbent)]
    # Only a by-election that CHANGED THE PARTY corrupts truth. One that
    # returned the same party leaves the incumbent field equal to the 2022
    # winner, so excluding it throws away a valid observation for nothing --
    # which a first pass did to Werribee.
    #
    # Victoria has had six Legislative Assembly contests since 2022: the
    # Narracan supplementary (Jan 2023), Warrandyte (Aug 2023), Mulgrave (Nov
    # 2023), Werribee and Prahran (Feb 2025), and Nepean (May 2026). Only
    # PRAHRAN changed hands -- the Greens won it in 2022 and the Liberals won
    # the by-election.
    byelections_changed <- c("Prahran")
    byelections_retained <- c("Mulgrave", "Warrandyte", "Narracan",
                              "Werribee", "Nepean")
    byelections <- byelections_changed
    win <- s[!seat %in% byelections]
    truth_src <- sprintf("the 2026 seat file, excluding %d by-election seats",
                         length(byelections))
    # A hand-written by-election list is exactly the kind of thing that is wrong
    # and looks right: the first version of it missed Prahran, where the Greens
    # won in 2022 and the Liberals won the February 2025 by-election, so the
    # model was scored against a party that did not win the election being
    # predicted. So the list is CHECKED rather than trusted.
    #
    # Any seat whose recorded incumbent differs from its 2022 first-preference
    # leader is either a seat won from behind on preferences -- legitimate -- or
    # a by-election the list has missed. Both are surfaced; the known
    # won-from-behind seats are named so a NEW one stands out.
    lead22 <- fb[, .(v = sum(votes)), by = .(seat, party)]
    lead22[, pct := 100 * v / sum(v), by = seat]
    lead22 <- lead22[, .SD[which.max(pct)], by = seat][, .(seat, fp_leader = party)]
    chk <- merge(lead22, s, by = "seat")
    cf <- function(x) fifelse(x %in% c("NAT", "LIB", "LNP", "CLP"), "LNP", x)
    chk[, `:=`(fp_leader = cf(fp_leader), winner = cf(winner))]
    won_from_behind <- c("Bass", "Hastings", "Nepean")
    odd <- chk[fp_leader != winner &
                 !seat %in% c(won_from_behind, byelections, byelections_retained)]
    if (nrow(odd)) {
      stop("These seats' recorded incumbent differs from the 2022 first-preference ",
           "leader and are neither a known won-from-behind seat nor a listed ",
           "by-election: ", paste(odd$seat, collapse = ", "),
           ". Confirm which before scoring against them.")
    }
  }
  coal <- function(x) fifelse(x %in% c("NAT", "LIB", "LNP", "CLP"), "LNP", x)
  win[, winner := coal(winner)]

  wide <- dcast(fa, seat ~ party, value.var = "votes", fill = 0)
  mat <- as.matrix(wide[, -1, with = FALSE]); rownames(mat) <- wide$seat
  mat <- 100 * mat / rowSums(mat)
  sa <- fa[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
  sb <- fb[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

  parties <- colnames(mat); shares <- mat
  for (p in parties) if (p %in% names(sb) && p %in% names(sa)) {
    shares[, p] <- pmax(0, mat[, p] + (sb[[p]] - sa[[p]]))
  }
  shares <- 100 * shares / rowSums(shares)
  keep <- intersect(rownames(shares), win$seat)
  shares <- shares[keep, , drop = FALSE]
  truth <- setNames(win$winner, win$seat)[keep]

  cat(sprintf("\nBV1  Victoria %d -> %d: %d districts scored, truth from %s\n",
              K$from, K$to, length(keep), truth_src))
  dropped <- setdiff(win$seat, rownames(mat))
  if (length(dropped)) {
    cat(sprintf("BV1  %d districts have no %d baseline and are not scored: %s\n",
                length(dropped), K$from, paste(sort(dropped), collapse = ", ")))
  }
  # The 2021 Victorian redistribution left NINE districts with no 2018 baseline
  # to swing from -- Ashwood, Berwick, Glen Waverley, Greenvale, Kalkallo,
  # Laverton, Pakenham, Point Cook and Eureka. Eight are genuinely new;
  # **Eureka is a renamed Buninyong**, with the sitting member recontesting
  # under the new name, so "did not exist" would be wrong for it. It is still
  # excluded because its boundaries changed materially -- it gained Bacchus
  # Marsh and lost Scarsdale and Sebastopol -- but the distinction is recorded
  # so nobody concludes there is no lineage to check. The floor is set
  # against the pair with the most churn rather than at a number that assumes
  # boundaries never move, and it names what it dropped either way.
  if (length(keep) < 70L) {
    stop("Only ", length(keep), " districts could be scored. Even the 2021 ",
         "redistribution plus the by-election exclusions leaves 76, so this ",
         "means the district names stopped matching, not that the chamber ",
         "changed.")
  }

  sp <- seat_swing_spread(as.data.table(load_seats(2026, "vic")),
                          unname(sb[["ALP"]] - sa[["ALP"]]))
  psd <- setNames(rep(1.5, length(parties)), parties)
  set.seed(SEED)
  sim <- simulate_seat_contests(shares, fm, party_sd = psd,
                                seat_sd = sp$sd_within, n_sims = N_SIMS,
                                smooth = SMOOTH, seed = SEED)
  wp <- as.data.table(sim$win_prob)

  pa <- merge(data.table(seat = keep, actual = unname(truth)),
              wp[, .(seat, party, prob)],
              by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
  pa[is.na(prob), prob := 0]
  pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
  res <- merge(pa, pr, by = "seat")
  stopifnot(nrow(res) == length(keep))
  res[, pair := sprintf("vic%d", K$to)]

  z <- data.frame(y = as.integer(res$pred == res$actual),
                  lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
  sl <- if (length(unique(z$y)) > 1)
    stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
  cat(sprintf("BV2  accuracy %d/%d (%.1f%%) | Brier %.4f | log score %.4f | slope %.3f\n",
              sum(res$pred == res$actual), nrow(res),
              100 * mean(res$pred == res$actual), mean((1 - res$prob)^2),
              -mean(log(pmax(res$prob, eps))), sl))
  cat(sprintf("BV2  seats where the winner got under 5%% from us: %d\n",
              sum(res$prob < 0.05)))
  cat("BV3  misses, worst first\n")
  print(head(res[pred != actual][order(prob),
                                 .(seat, we_said = pred, our_p = round(pred_p, 3),
                                   actual, gave_winner = round(prob, 3))], 8))
  out_all[[length(out_all) + 1L]] <- res
}

R <- rbindlist(out_all)
fwrite(R, file.path("output", "backtest-vic.csv"))
cat(sprintf("\nBV4  pooled over %d district-elections: accuracy %.1f%%, Brier %.4f\n",
            nrow(R), 100 * mean(R$pred == R$actual), mean((1 - R$prob)^2)))
cat("BV4  for comparison, NSW 2023 gave 80.7% and 0.1468\n")
cat("\nBV5  by the party that actually won\n")
print(R[, .(n = .N, mean_prob_we_gave = round(mean(prob), 3),
            called = sum(pred == actual)), by = actual][order(-n)])

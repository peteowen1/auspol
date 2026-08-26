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

# ---- other jurisdictions' flows, date-filtered ------------------------------
# Against docs/plans/prereg-qld-flows.md and docs/plans/prereg-wa-flows.md.
# Queensland 2020 and 2024 add 750 exclusion events; Western Australia's seven
# admissible elections add 1,634 and take One Nation's from 198 to 359.
#
# Either may only be used to predict an election held AFTER it. That rule lives
# in pool_configured_flows() rather than in a copy per harness -- there were
# four byte-identical copies, one of which had rotted into a gate that was
# defined and never called, and it is the one rule here that must never be
# wrong. Both sources default OFF.

# ARM B of docs/plans/prereg-calibration.md. A multiplier on the per-seat
# spread. Default 1 reproduces the published behaviour exactly.
SEAT_SD_MULT <- as.numeric(Sys.getenv("AUSPOL_SEAT_SD_MULT", "1"))
if (SEAT_SD_MULT != 1) cat(sprintf("CAL  seat_sd multiplier %.2f applied
", SEAT_SD_MULT))

N_SIMS <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))


# ARM B/C of docs/plans/prereg-statewide-covariance.md. AUSPOL_PARTY_COR=shrunk
# correlates the parties' statewide deviations instead of drawing them
# independently. Empty (the default) reproduces the previous behaviour exactly.
PARTY_COR <- NULL
if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", ""))) {
  .co <- readRDS("output/statewide-cov.rds")
  PARTY_COR <- if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) .co$cor else .co$cor_shrunk
  cat(sprintf("COV  party correlation ON (%s): cor(ONP,LNP) = %+.2f
",
              Sys.getenv("AUSPOL_PARTY_COR"), PARTY_COR["ONP", "LNP"]))
}

# THE FLOW FIXES, PORTED. `fallback_smooth` and `flow_sd` were added to the
# South Australian harness on 2026-08-25 and existed NOWHERE ELSE, so setting
# them in the environment for a cross-harness comparison silently did nothing
# here -- an experiment that never ran, reading as an input that does not
# matter. That is the failure CLAUDE.md records under "A fix to one harness is
# a fix to ALL of them", and it recurred in the same session the rule was
# written. Both default to 0, which reproduces the previous behaviour exactly.
# INSURGENCY SURGE, against docs/plans/prereg-insurgency-surge.md. Wired here on
# 2026-08-26 after a four-arm comparison produced BYTE-IDENTICAL results for the
# surge arm and the do-nothing arm in this harness -- the "this input does not
# matter" signature. It was implemented in seat_sim.R and wired into the federal
# and WA harnesses only, so three of five harnesses compared the surge against
# itself. Third breach of the fix-everywhere rule in one day.
SURGE_H <- as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0"))
if (SURGE_H > 0)
  cat(sprintf("BS0s surge hazard %.4f, size N(15.6, 6.1), floor 2%%
", SURGE_H))
FB_SMOOTH <- as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0"))
FLOW_SD   <- as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0"))
cat(sprintf("BS1f fallback_smooth %.2f | flow_sd %.2f
", FB_SMOOTH, FLOW_SD))

CAL_TAG <- paste0(
  if (as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0")) > 0) "-surge" else "",
  if (as.numeric(Sys.getenv("AUSPOL_SHRINK", "0")) != 0)
    sprintf("-sh%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_SHRINK")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0")) != 0)
    sprintf("-el%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER")), nsmall = 1)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0")) != 0)
    sprintf("-fb%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0")) != 0)
    sprintf("-fsd%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_FLOW_SD")), nsmall = 1)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5")) != 1.5)
    sprintf("-psd%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_PARTY_SD")), nsmall = 2)))
  else "",
  if (SEAT_SD_MULT != 1) sprintf("-m%s", format(SEAT_SD_MULT, nsmall = 1)) else "",
  if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")) "-port" else "",
  if (N_SIMS != 20000L) sprintf("-n%d", N_SIMS) else "",
  # "-corraw" and "-cor" are DIFFERENT correlation matrices. Both used to tag
  # "-cor", so running the raw arm and then the shrunk one wrote the second
  # over the first and a before/after comparison compared an arm with itself.
  if (!is.null(PARTY_COR))
    (if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "-corraw" else "-cor")
  else "",
  if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1")) "-qld" else "",
  if (identical(Sys.getenv("AUSPOL_WA_FLOWS", "0"), "1")) "-wa" else "",
  # The control arm of refusal W1 runs with the flows switched ON and a cutoff
  # that admits nothing. Without this it would write to the same "-wa" name as
  # the real arm and overwrite it -- the baseline-clobbering that has already
  # produced four byte-identical comparisons here.
  if (nzchar(Sys.getenv("AUSPOL_WA_CUTOFF", "")) ||
      nzchar(Sys.getenv("AUSPOL_QLD_CUTOFF", ""))) "-cut" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_3C", "0"), "1")) "-no3c" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_LNP", "0"), "1")) "-nolnp" else "",
  # AUSPOL_FLOW_UNC swaps the simulation for a 40-replicate ensemble that
  # perturbs every flow, which is as large a change as any flag here, and it
  # reached no filename at all -- so the ensemble arm overwrote the very
  # baseline it exists to be compared against.
  if (identical(Sys.getenv("AUSPOL_FLOW_UNC", "0"), "1")) "-unc" else "")

SEED <- 42; SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()

PAIRS <- list(
  list(from = 2014, to = 2018),
  list(from = 2018, to = 2022))

share_of <- function(f) {
  d <- fread(file.path(P, f), showProgress = FALSE)
  d[, .(votes = sum(votes)), by = .(seat, party)]
}

out_all <- list(); tot_all <- list()
for (K in PAIRS) {
  fa <- share_of(sprintf("vec-%d-vic-firstprefs.csv", K$from))
  fb <- share_of(sprintf("vec-%d-vic-firstprefs.csv", K$to))
  tx <- fread(file.path(P, sprintf("vec-%d-vic-transfers.csv", K$from)),
              showProgress = FALSE)
  # LEAKAGE GUARD, asserted on the source rather than on a filtered copy: a
  # table filtered to one election trivially contains only that election.
  stopifnot(all(tx$election == sprintf("vic%d", K$from)))
  tx <- pool_configured_flows(tx, if (K$to == 2018L) "2018-11-24" else "2022-11-26")
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
  # THIS HARNESS HAS NEVER PASSED `shrink`, the same defect
  # docs/reviews/calibration-2026-08-21.md found and that was fixed in the SA
  # harness today. fit_seats_full.R PUBLISHES with shrink = 0.10 and
  # simulate_seat_contests() defaults it to 0, so every calibration figure this
  # harness has produced describes a model we do not ship. Default 0 keeps past
  # runs comparable.
  SHRINK <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0"))
  # STRONGHOLD ELASTICITY, against docs/plans/prereg-stronghold-elasticity.md.
  # Default OFF. Criteria 1 and 3 of that plan require this arm on Victoria and
  # NSW as well as SA before adoption, which is why it is here.
  ELASTIC   <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0"))
  ELASTIC_D <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_FALL", "2"))
  DEV_SLOPE <- dev_slopes_for(union(colnames(mat), names(sb)))
  cat(sprintf("BV1d  dev slopes: %s%s
",
              if (all(DEV_SLOPE == 1)) "all 1.000 (uniform swing)" else
                paste(sprintf("%s=%.3f", names(DEV_SLOPE), DEV_SLOPE), collapse=" "),
              if (length(attr(DEV_SLOPE, "absent")))
                paste0(" | not contested here: ",
                       paste(attr(DEV_SLOPE, "absent"), collapse=",")) else ""))
  pinned <- matrix(FALSE, nrow(mat), ncol(mat), dimnames = dimnames(mat))
  for (p in parties) if (p %in% names(sb) && p %in% names(sa)) {
    d_state <- sb[[p]] - sa[[p]]
    val <- dev_slope(mat[, p], sa[[p]], sb[[p]], DEV_SLOPE[[p]])
    if (ELASTIC > 0 && d_state < -ELASTIC_D && sa[[p]] > 0) {
      over <- mat[, p] / sa[[p]]
      hit <- is.finite(over) & over > ELASTIC
      if (any(hit)) {
        val[hit] <- pmax(0, mat[hit, p] * sb[[p]] / sa[[p]])
        pinned[hit, p] <- TRUE
      }
    }
    shares[, p] <- val
  }
  if (ELASTIC > 0) {
    cat(sprintf("BV1e elasticity ON (over %.2f, fall %.1f): %d cells\n",
                ELASTIC, ELASTIC_D, sum(pinned)))
  }
  # Constrained renormalisation: a cut cell must not receive back a share of
  # the vote just taken off it. See the SA harness for the measured effect.
  if (ELASTIC > 0 && any(pinned)) {
    for (i in which(rowSums(pinned) > 0)) {
      keepc <- pinned[i, ]
      room <- 100 - sum(shares[i, keepc]); rest <- sum(shares[i, !keepc])
      if (rest > 0 && room > 0) shares[i, !keepc] <- shares[i, !keepc] * room / rest
    }
    oth <- which(rowSums(pinned) == 0)
    if (length(oth)) shares[oth, ] <- 100 * shares[oth, , drop = FALSE] / rowSums(shares[oth, , drop = FALSE])
  } else {
    shares <- 100 * shares / rowSums(shares)
  }
  keep <- intersect(rownames(shares), win$seat)
  shares <- shares[keep, , drop = FALSE]
  truth <- setNames(win$winner, win$seat)[keep]

  # ---- seat-swing port, ported from backtest_candidate_nsw.R ---------------
  # Against docs/plans/prereg-seat-swing-port-round2.md. The block is copied
  # unchanged in substance (refusal P4) with ONE mechanical rename: the NSW
  # version calls the seat file `sa`, and this script already uses `sa` for the
  # statewide 'from' shares at line 99 and reads it again at line 136. Pasting
  # the block verbatim would rebind `sa` to a data.table and silently break that
  # later read -- the shadowing hazard CLAUDE.md records five times. It is
  # `sf_to` here.
  #
  # NOT EVERY CYCLE CAN BE TESTED. seat_swing_adjustment() needs the seat file
  # for the election being predicted, and 2018vic.txt DOES NOT EXIST -- so the
  # 2014->2018 cycle gets no adjustment and is reported as untestable rather
  # than silently scored as if the port were off. Only 2018->2022 contributes.
  PORT <- identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")
  if (PORT) {
    sf_to <- tryCatch(as.data.table(load_seats(K$to, "vic")),
                      error = function(e) NULL)
    if (is.null(sf_to)) {
      cat(sprintf("BV3c seat-swing port REQUESTED but %dvic.txt does not exist; this cycle is NOT testable and runs unported\n",
                  K$to))
    } else {
      idx <- match(rownames(shares), sf_to$seat)
      adj <- rep(0, nrow(shares))
      adj[!is.na(idx)] <- seat_swing_adjustment(sf_to[idx[!is.na(idx)]])
      if (anyNA(idx)) {
        cat(sprintf("BV3c %d seats have no match in the seat file and get no adjustment: %s\n",
                    sum(is.na(idx)), paste(rownames(shares)[is.na(idx)], collapse = ", ")))
      }
      # Re-centre: seat_swing_adjustment() centres over the seats it was given,
      # and zeroing the unmatched ones reintroduces a mean. An uncentred
      # adjustment would shift the whole forecast.
      adj <- adj - mean(adj)
      stopifnot(all(is.finite(adj)))
      cat(sprintf("BV3c seat-swing port ON: adjustment mean %+.3f sd %.3f range %+.2f..%+.2f\n",
                  mean(adj), stats::sd(adj), min(adj), max(adj)))
      shares[, "ALP"] <- pmax(0, shares[, "ALP"] + adj)
      shares[, "LNP"] <- pmax(0, shares[, "LNP"] - adj)
      shares <- 100 * shares / rowSums(shares)
    }
  }

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
  # STATEWIDE UNCERTAINTY, MEASURED. All four harnesses hardcoded 1.5 with no
  # derivation. The realised statewide first-preference error over 139
  # party-cycles (33 independent cycles) is sd 2.33, so the harnesses were 1.6x
  # over-confident BEFORE any seat-level modelling. That is upstream of `shrink`,
  # which is a post-hoc patch for uncertainty that should have been present.
  # fit_seats_full.R already uses a per-party state_sd and falls back to 1.5 only
  # when it is NA. See docs/plans/prereg-party-sd-from-data.md.
  PARTY_SD <- as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5"))
  psd <- setNames(rep(PARTY_SD, length(parties)), parties)
  cat(sprintf("BS1p party_sd %.2f (realised statewide sd is 2.33)
", PARTY_SD))
  set.seed(SEED)
  # FLOW UNCERTAINTY, arm B. Against docs/plans/prereg-flow-uncertainty-v2.md.
  # Each replicate perturbs every source party's flow by an offset drawn from
  # N(0, sd) with the sd MEASURED from between-election variation across 10
  # full-preferential elections -- not fitted, not tuned. One Nation's is 10.38
  # points; the Greens' is 2.00, which is why treating the Greens flow as a
  # constant costs almost nothing and treating One Nation's as one does not.
  FLOW_UNC <- identical(Sys.getenv("AUSPOL_FLOW_UNC", "0"), "1")
  if (FLOW_UNC) {
    sds <- readRDS("output/flow-uncertainty-sd.rds")
    R_ENS <- 40L; per <- N_SIMS %/% R_ENS
    set.seed(SEED)
    acc <- NULL
    for (r in seq_len(R_ENS)) {
      tx2 <- copy(tx)
      off <- stats::rnorm(length(sds), 0, sds); names(off) <- names(sds)
      # The offset moves votes between ALP and LNP within each exclusion,
      # leaving the total transferred unchanged -- a flow is a split, not a
      # size.
      for (fp in names(off)) {
        idx <- tx2$from == fp & tx2$to %in% c("ALP", "LNP")
        if (!any(idx)) next
        sh <- off[[fp]] / 100
        tx2[idx & to == "ALP", votes := pmax(0, votes * (1 + sh))]
        tx2[idx & to == "LNP", votes := pmax(0, votes * (1 - sh))]
      }
      fmr <- build_flow_matrix(tx2, min_n = 3L)
      s1 <- simulate_seat_contests(shares, fmr, party_sd = psd,
                                   seat_sd = sp$sd_within * SEAT_SD_MULT, n_sims = per,
                                   smooth = SMOOTH, seed = SEED + r, shrink = SHRINK,
                                   fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD,
                                surge_h = SURGE_H)
      w1 <- as.data.table(s1$win_prob)[, .(seat, party, n = prob * per)]
      acc <- if (is.null(acc)) w1 else rbind(acc, w1)
    }
    wp <- acc[, .(prob = sum(n) / (R_ENS * per)), by = .(seat, party)]
    cat("BV1b flow uncertainty ON
")
  } else {
    set.seed(SEED)
    sim <- simulate_seat_contests(shares, fm, party_sd = psd,
                                  seat_sd = sp$sd_within * SEAT_SD_MULT, n_sims = N_SIMS,
                                  smooth = SMOOTH, seed = SEED, party_cor = PARTY_COR,
                                  shrink = SHRINK,
                                  fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD,
                                surge_h = SURGE_H)
    wp <- as.data.table(sim$win_prob)
  }

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
  # `sim` exists only on the non-FLOW_UNC branch: the ensemble path builds win
  # probabilities by accumulating counts and never produces a totals matrix. It
  # was referenced here unconditionally, so AUSPOL_FLOW_UNC=1 died with
  # "object 'sim' not found" partway through the first pair -- meaning the
  # flow-uncertainty comparison this script describes could not have been
  # produced by running it. Skipped and SAID, rather than skipped silently.
  if (FLOW_UNC) {
    cat("BV3b no seat-totals matrix under flow uncertainty; totals not written.
")
  } else {
    tot_all[[length(tot_all) + 1L]] <- data.table::data.table(
      pair = sprintf("vic%d", K$to), as.data.table(sim$totals))
  }
  out_all[[length(out_all) + 1L]] <- res
}

R <- rbindlist(out_all)
fwrite(R, file.path("output", sprintf("backtest-vic%s.csv", CAL_TAG)))
fwrite(rbindlist(tot_all, fill = TRUE), file.path("output", sprintf("backtest-vic-totals%s.csv", CAL_TAG)))
cat(sprintf("\nBV4  pooled over %d district-elections: accuracy %.1f%%, Brier %.4f\n",
            nrow(R), 100 * mean(R$pred == R$actual), mean((1 - R$prob)^2)))
cat("BV4  for comparison, NSW 2023 gave 80.7% and 0.1468\n")
cat("\nBV5  by the party that actually won\n")
print(R[, .(n = .N, mean_prob_we_gave = round(mean(prob), 3),
            called = sum(pred == actual)), by = actual][order(-n)])

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
source("scripts/harness_defaults.R")  # published defaults for every unset AUSPOL_* switch; see that file
suppressMessages(library(data.table))

# LEVEL-DEPENDENT SEAT VARIANCE, off by default. AUSPOL_LEVEL_SD="1.10,8.67"
# makes the per-seat deviation sd = a + b*sqrt(p(1-p)) instead of a flat
# seat_sd. Pre-registered in docs/plans/prereg-level-dependent-variance.md;
# unset reproduces the published model exactly.
.level_sd <- local({
  # ADOPTED 2026-08-27. Default ON at the fitted values; AUSPOL_LEVEL_SD="off"
  # reproduces the flat seat_sd exactly. See
  # docs/reviews/level-variance-2026-08-27.md -- federal seats called 99%+ and
  # LOST fall from 23 to 12 over 886 seat-elections, and Brier and log loss
  # improve in every subset on both federal and NSW.
  raw <- Sys.getenv("AUSPOL_LEVEL_SD", "1.10,8.67")
  if (identical(tolower(raw), "off") || !nzchar(raw)) NULL else {
    v <- suppressWarnings(as.numeric(strsplit(raw, ",")[[1]]))
    if (length(v) != 2L || !all(is.finite(v)))
      stop("AUSPOL_LEVEL_SD must be two finite numbers, e.g. 1.10,8.67")
    v
  }
})
cat(sprintf("LV1  level_sd: %s
", if (is.null(.level_sd)) "OFF (flat seat_sd)" else
            sprintf("a=%.2f b=%.2f", .level_sd[1], .level_sd[2])))

# PER-CLASS SLOPE MULTIPLIER, both 1 by default so this is a no-op until an arm
# sets it. AUSPOL_LEVEL_MULT_IND and AUSPOL_LEVEL_MULT_OTH scale level_sd's
# slope for independents and for every other non-major; majors are never
# touched. Pre-registered in docs/plans/prereg-class-specific-variance.md.
#
# WHY IT EXISTS. level_sd above ships ONE curve for every party, and the review
# that adopted it measured that the seats it fixed were not the seats it
# widened: on NSW the calibration slope went 0.565 -> 0.720 across all seats but
# 0.959 -> 1.272 EXCLUDING seats an independent won. The majors were already
# almost right and got widened past 1 anyway.
.level_mult <- local({
  g <- function(v) {
    x <- suppressWarnings(as.numeric(Sys.getenv(v, "1")))
    if (!is.finite(x) || x < 0) stop(v, " must be a finite, non-negative number")
    x
  }
  c(ind = g("AUSPOL_LEVEL_MULT_IND"), oth = g("AUSPOL_LEVEL_MULT_OTH"))
})
# Printed unconditionally, including when it is off. An arm that silently did
# not apply is indistinguishable from an arm that made no difference -- the
# failure CLAUDE.md records under "an experiment that never ran".
cat(sprintf("LV2  level_mult: %s
",
            if (all(.level_mult == 1)) "OFF (one curve for every class)" else
              sprintf("IND x%.2f, other non-major x%.2f",
                      .level_mult[["ind"]], .level_mult[["oth"]])))
# Built per call site from that seat file's own columns, because
# simulate_seat_contests() rejects a name that is not a share column.
.lm <- function(sh) level_mult_for(colnames(sh), .level_mult[["ind"]],
                                   .level_mult[["oth"]])


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
if (!is.finite(SEAT_SD_MULT) || SEAT_SD_MULT <= 0)
  stop("AUSPOL_SEAT_SD_MULT must be a positive number; got ", SEAT_SD_MULT)
# PORTED FROM THE FEDERAL HARNESS 2026-09-06: simulate_seat_contests() computes
# sd_cell from `level_sd` and IGNORES seat_sd whenever level_sd is given, and
# level_sd is on by default, so `seat_sd * SEAT_SD_MULT` at the call site was
# inert here while this printed "applied". The multiplier now scales whichever
# spread is actually in force, and the message says which.
if (SEAT_SD_MULT != 1) {
  if (is.null(.level_sd)) {
    cat(sprintf("CAL  seat_sd multiplier %.2f applied (flat seat_sd path)
", SEAT_SD_MULT))
  } else {
    .level_sd <- .level_sd * SEAT_SD_MULT
    cat(sprintf("CAL  spread multiplier %.2f applied to LEVEL_SD -> a=%.3f b=%.3f (seat_sd is inert here)
",
                SEAT_SD_MULT, .level_sd[1], .level_sd[2]))
  }
}

N_SIMS <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))


# ARM B/C of docs/plans/prereg-statewide-covariance.md. AUSPOL_PARTY_COR=shrunk
# correlates the parties' statewide deviations instead of drawing them
# independently. Empty (the default) reproduces the previous behaviour exactly.
# THE MATRIX IS CHOSEN PER TARGET, and this harness scores several targets in
# one run, so the matrix cannot be a single value fixed here. Only the MODE is
# read at this point; statewide_cor() is called inside the pair loop. Until
# 2026-09-07 every harness read one all-pairs correlation and scored against
# it, including the pairs that were in the fit, so an election was correlated
# using its own statewide swing. See
# docs/plans/prereg-statewide-cov-loo-2026-09-07.md.
PARTY_COR <- NULL
COR_MODE <- if (!nzchar(Sys.getenv("AUSPOL_PARTY_COR", ""))) NULL else
  if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "raw" else "shrunk"

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

# ARM FINGERPRINT. CAL_TAG names the parameters someone remembered to add, and
# twice now a new one was not: AUSPOL_LEVEL_SD and AUSPOL_DEV_SLOPE both wrote
# over another arm's per-seat output, silently, so a comparison read two copies
# of the same run. This appends a short hash of every AUSPOL_* variable that is
# set, so a NEW parameter cannot repeat that without anyone touching this line.
.arm_fingerprint <- local({
  e <- Sys.getenv()
  e <- e[grepl("^AUSPOL_", names(e)) & nzchar(e)]
  e <- e[!names(e) %in% c("AUSPOL_OUT_SUFFIX")]
  if (!length(e)) "" else {
    s <- paste(sort(paste0(names(e), "=", e)), collapse = ";")
    sprintf("-a%s", substr(tolower(paste0(as.hexmode(
      sum(utils::head(utf8ToInt(s), 4000) * seq_along(utils::head(utf8ToInt(s), 4000)))
    ))), 1, 6))
  }
})
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
  if (!is.null(.level_sd)) sprintf("-lv%s", gsub("[.]", "", paste(format(.level_sd, nsmall=2), collapse="_"))) else "",
  # "-corraw" and "-cor" are DIFFERENT correlation matrices. Both used to tag
  # "-cor", so running the raw arm and then the shrunk one wrote the second
  # over the first and a before/after comparison compared an arm with itself.
  # KEYED ON THE SWITCH, NOT ON THE MATRIX. PARTY_COR is now fetched per
  # target, which happens AFTER this tag is built, so testing the matrix
  # here silently dropped "-cor" from every filename while the run still
  # used a correlation -- a file whose name says one arm and whose
  # contents are another, which is the fingerprint failure this tag exists
  # to prevent.
  if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", "")))
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
  if (identical(Sys.getenv("AUSPOL_FLOW_UNC", "0"), "1")) "-unc" else "", .arm_fingerprint, .code_tag)

# READ FROM THE ENVIRONMENT, like the federal harness. AUSPOL_SEED is in
# scripts/published_flags.R, and until 2026-09-07 this harness hardcoded 42
# and ignored it -- so a reseed run to measure the noise floor returned
# byte-identical output, and the only tell was that it was TOO identical.
SEED <- as.integer(Sys.getenv("AUSPOL_SEED", "42")); SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()

# THREE PAIRS since 2026-09-07. vic2010 became available when the archived VEC
# result pages were parsed (scripts/fetch_preferences_vic2010.R); the eight
# spreadsheets previously recorded as the 2010 Assembly results are the
# Legislative Council. The 2013 redistribution renamed 15 of the 88 districts,
# so 2010 -> 2014 scores 73 seats, and the harness reports that coverage the
# same way it does for the 2021 redistribution.
PAIRS <- list(
  list(from = 2010, to = 2014),
  list(from = 2014, to = 2018),
  list(from = 2018, to = 2022))

# Polling day, per target election. This was a ternary reading
# `if (K$to == 2018L) ... else ...`, which silently gave any third pair the
# 2022 date -- a leakage bug the moment a pair was added, and one that nothing
# downstream would have reported.
VIC_DATE <- c("2014" = "2014-11-29", "2018" = "2018-11-24", "2022" = "2022-11-26")

share_of <- function(f) {
  d <- fread(file.path(P, f), showProgress = FALSE)
  d[, .(votes = sum(votes)), by = .(seat, party)]
}

out_all <- list(); tot_all <- list(); share_detail <- list()
for (K in PAIRS) {
  # ARM B of docs/plans/prereg-salience-expected-and-variance-2026-09-07.md.
  # NULL unless the switch is on, so a bare run is byte-identical.
  SD_OVR <- NULL

  # The correlation matrix for THIS pair. Printed with its source, because a
  # silent fallback is the failure this repo keeps finding: a run using a
  # different input from the one its log implies.
  PARTY_COR <- if (is.null(COR_MODE)) NULL else
    statewide_cor(sprintf("vic%d", K$to), mode = COR_MODE)
  if (nzchar(Sys.getenv("AUSPOL_PARTY_COR", "")))
    cat(sprintf("COV  vic%d party correlation (%s): cor(ONP,LNP) = %+.2f | %s\n",
                K$to, COR_MODE, PARTY_COR["ONP", "LNP"],
                attr(PARTY_COR, "cor_source")))

  fa <- share_of(sprintf("vec-%d-vic-firstprefs.csv", K$from))
  fb <- share_of(sprintf("vec-%d-vic-firstprefs.csv", K$to))
  tx <- fread(file.path(P, sprintf("vec-%d-vic-transfers.csv", K$from)),
              showProgress = FALSE)
  # LEAKAGE GUARD, asserted on the source rather than on a filtered copy: a
  # table filtered to one election trivially contains only that election.
  # `all()` over zero rows is TRUE -- the guard this repo's CLAUDE.md
  # documents as a shape that "cannot fail" -- so the row-count floor
  # matches the equivalent guard already used in the federal/QLD/SA
  # harnesses, not just the per-election check.
  stopifnot(nrow(tx) > 100L, all(tx$election == sprintf("vic%d", K$from)))
  .asof <- VIC_DATE[[as.character(K$to)]]
  if (is.null(.asof) || is.na(.asof)) stop("No polling date recorded for vic", K$to)
  tx <- pool_configured_flows(tx, .asof)
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
  # RE-ENTRY PRIOR, docs/plans/prereg-reentry-prior-2026-09-07.md. A class
  # contesting this seat but not the last one has no prior share, so swinging
  # zero forward leaves approximately zero -- 1,418 seat-class rows across the
  # corpus, costing 5.27 points of mean absolute error against 3.25 for the
  # model. Kimberley 2001 is the case: Labor did not stand there in 1996,
  # Carol Martin won it with 42.2%, and the model projected 2.1%.
  REENTRY_CELLS <- attr(reentry_apply_harness(mat, fa, fb, sb,
                               target = sprintf("vic%d", K$to),
                               pairs = all_election_pairs(), code = "BV1r"),
                        "reentry")

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
  .cond <- Sys.getenv("AUSPOL_DEV_SLOPE_MODE", "") %in% c("conditional", "screened")
  .screened <- identical(Sys.getenv("AUSPOL_DEV_SLOPE_MODE", ""), "screened")
  .ea <- sprintf("vic%d", K$from); .eb <- sprintf("vic%d", K$to)
  .returns <- if (.cond) tryCatch(candidate_returns(.ea, .eb), error = function(e) {
    cat(sprintf("BV1c! conditional slopes unavailable: %s
", conditionMessage(e))); NULL }) else NULL
  if (.cond && !is.null(.returns))
    cat(sprintf("BV1c conditional slopes ON: %d of %d seat-classes returning
",
                sum(.returns$same), nrow(.returns)))
  # THE BASE VALUE, not just the slope -- see personal_prior_vote()'s docs.
  # PORTED FROM THE FEDERAL HARNESS 2026-09-05, per this repo's rule that a
  # fix to one harness is a fix to all of them. Both off by default, so the
  # default path stays byte-identical until measured here.
  #   AUSPOL_MP_SLOPE       -- returning MEMBER (0.954) vs returning also-ran
  #                            (0.800); the shipped value pooled them at 0.907.
  #   AUSPOL_DEFECT_DISCOUNT -- a sitting major-party member who re-contests
  #                            under a non-major label brings 0.282 of their
  #                            major vote, ADDED to that class's base rather
  #                            than replacing it.
    .MP_SLOPE <- NULL
  if (identical(Sys.getenv("AUSPOL_MP_SLOPE", "0"), "1")) {
    # Values are READ FROM DISK, per target election, never hard-coded. The first
    # version of this tier carried c(IND = 0.954, OTH_RIGHT = 0.954, GRN = 0.994,
    # ONP = 0.610) from an uncommitted fit that had seen the elections it was then
    # scored on. Refitted leave-one-election-out (scripts/fit_mp_slope.R) the tier
    # is real -- the member/also-ran gap is positive in 18 of 18 folds -- but three
    # of those four numbers were wrong, and ONP's was the also-ran slope written
    # into the member row over ZERO member observations.
    .mpf <- "output/mp-slope-by-target.csv"
    if (!file.exists(.mpf))
      stop("AUSPOL_MP_SLOPE=1 needs ", .mpf, " -- run scripts/fit_mp_slope.R")
    .mpt <- data.table::fread(.mpf, showProgress = FALSE)
    .tgt <- .eb                       # copied to a differently-named local: a bare
    .row <- .mpt[.mpt$target == .tgt & is.finite(.mpt$member), ]  # `target` inside
    if (!nrow(.row))                                              # `[` would bind
      stop("no leave-one-out MP slopes for ", .tgt, " in ", .mpf) # to the column
    if (!identical(Sys.getenv("AUSPOL_MP_SLOPE_GRN", "0"), "1"))
      .row <- .row[.row$party != "GRN", ]   # GRN's member/also-ran gap is ~0
    .MP_SLOPE <- stats::setNames(as.numeric(.row$member), .row$party)
  }
  cat(sprintf("BV1n  MP tier: %s
  ",
              if (is.null(.MP_SLOPE)) "OFF" else
                paste(sprintf("%s=%.4f", names(.MP_SLOPE), .MP_SLOPE), collapse = " ")))
  # PORTED to fit_defector_discount() 2026-09-09 -- was a frozen 0.282 snapshot
  # of one federal-only run; now pooled across all six jurisdictions, refit
  # leave-this-target-out. See R/candidate_returns.R's docs.
  .defect <- NULL
  if (identical(Sys.getenv("AUSPOL_DEFECT_DISCOUNT", "0"), "1")) {
    .fd <- tryCatch(fit_defector_discount(.eb), error = function(e) {
    cat(sprintf("BV0d! defector-discount fit FAILED, no discount applied: %s
",
                conditionMessage(e)))
    list(discount = NULL, discount_mp = NULL, discount_loser = NULL, n = 0L)
  })
    if (is.null(.fd$discount)) {
      cat(sprintf("BV0d! only %d defector case(s) (need >=5); no discount applied\n", .fd$n))
    } else {
      cat(sprintf("BV0d defector discount %.3f from %d cases (target excluded, pooled all jurisdictions)\n",
                  .fd$discount, .fd$n))
      .defect <- .fd$discount
    }
  }
  # SPLIT SLOPE (AUSPOL_SPLIT_SLOPE=1, default OFF -- unset reproduces this
  # harness byte-for-byte). Gives the returning and departed portions of a
  # class's prior vote their own fitted slope instead of one slope chosen by
  # a binary flag. docs/plans/prereg-partial-return-split-slope-2026-09-09.md
  # FITTED CONDITIONAL SLOPES (AUSPOL_FIT_SLOPES=1, default OFF). Replaces the
  # eight hardcoded same/new constants with a leave-this-target-out fit;
  # structure untouched. docs/plans/prereg-fit-conditional-slopes-2026-09-09.md
  .fitsl <- if (identical(Sys.getenv("AUSPOL_FIT_SLOPES", "0"), "1"))
    fit_conditional_slopes(.eb) else NULL
  if (!is.null(.fitsl)) cat(sprintf("FS1  fitted slopes | same %s | new %s
",
    paste(sprintf("%s=%.3f", names(.fitsl$same), .fitsl$same), collapse=" "),
    paste(sprintf("%s=%.3f", names(.fitsl$new),  .fitsl$new),  collapse=" ")))
  .split <- split_slope_context(.ea, .eb)
  .own_prev <- if (.cond) tryCatch(personal_prior_vote(.ea, .eb, major_discount = .defect), error = function(e) { cat(sprintf("BV1p! personal_prior_vote() FAILED; class-level bases kept and NO transfer removed: %s\n", conditionMessage(e))); NULL }) else NULL
  mat <- remove_transferred_votes(mat, .own_prev)  # the vote moves with the person; see personal_prior_vote()
  .tr <- attr(mat, "transfers"); if (!is.null(.tr)) cat(sprintf("TR1  transfers moved with the person: %d applied%s\n", .tr$applied, if (length(.tr$skipped)) paste0("; SKIPPED ", length(.tr$skipped), ": ", paste(utils::head(.tr$skipped, 5), collapse = ", ")) else ""))
  .own_x <- function(p, seats, x) {
    if (is.null(.own_prev)) return(x)
    ov <- .own_prev[.own_prev$party == p, ]
    v <- stats::setNames(ov$own_prev_pcv, ov$seat)[seats]
    out <- x
    hit <- !is.na(v)
    out[hit] <- unname(v[hit])
    out
  }
  # ARM CS: only vic2022 has salience data (see docs/DATA-REGISTRY.md); for
  # vic2018 this returns NULL and the code below falls back to arm C plain.
  .permit <- if (.screened) salience_permit_for(.eb, .ea, "vic") else NULL
  .vic_slope <- function(p, seats) {
    if (.screened && !is.null(.permit)) {
      pv <- .permit[.permit$party == p, ]
      lut <- stats::setNames(as.logical(pv$permit), pv$seat)
      pm <- unname(lut[seats]); pm[is.na(pm)] <- TRUE
      return(screened_slopes(p, seats, .returns, pm, same_mp = .MP_SLOPE, same = if (is.null(.fitsl)) formals(screened_slopes)$same else .fitsl$same, new = if (is.null(.fitsl)) formals(screened_slopes)$new else .fitsl$new))
    }
    if (.cond && !is.null(.returns)) return(conditional_slopes(p, seats, .returns, same_mp = .MP_SLOPE, same = if (is.null(.fitsl)) formals(conditional_slopes)$same else .fitsl$same, new = if (is.null(.fitsl)) formals(conditional_slopes)$new else .fitsl$new))
    DEV_SLOPE[[p]]
  }
  # WHAT THE MP TIER ACTUALLY APPLIED TO. Printed unconditionally, including
  # when it is off: a run where .MP_SLOPE reached zero seat-classes is
  # indistinguishable in the score from one where the tier does not matter, and
  # that is the "experiment that never ran" failure CLAUDE.md records. The vic
  # 2014->2018 arm came back BYTE-IDENTICAL to its baseline and this line is
  # what settles whether that is a no-op or a real null result.
  cat(sprintf("BV1m  MP tier: %s
",
              if (is.null(.MP_SLOPE)) "OFF" else {
                .n <- if (!is.null(.returns) && "same_mp" %in% names(.returns))
                  sum(.returns$same_mp & .returns$party %in% names(.MP_SLOPE)) else 0L
                sprintf("ON (%s) applied to %d seat-classes",
                        paste(sprintf("%s=%.3f", names(.MP_SLOPE), .MP_SLOPE), collapse=" "), .n)
              }))
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
    .sl <- .vic_slope(p, rownames(mat))
    x_p <- .own_x(p, rownames(mat), mat[, p])
    val <- if (is.null(.split)) dev_slope(x_p, sa[[p]], sb[[p]], .sl) else
      split_dev_slope(x_p, .split$frac(p, rownames(mat)), sa[[p]], sb[[p]], .split$s_ret, .split$s_dep)
    if (ELASTIC > 0 && d_state < -ELASTIC_D && sa[[p]] > 0) {
      over <- x_p / sa[[p]]
      hit <- is.finite(over) & over > ELASTIC
      if (any(hit)) {
        val[hit] <- pmax(0, x_p[hit] * sb[[p]] / sa[[p]])
        pinned[hit, p] <- TRUE
      }
    }
    shares[, p] <- val
  }
  # Re-entry prior lands here, on the POST-SWING projection. See BV1r above.
  # The prediction is a target-election share; filling it into the prior-election
  # matrix let dev_slope() swing it a second time.
  if (!is.null(REENTRY_CELLS) && nrow(REENTRY_CELLS)) {
    # PERSONAL-VOTE PRIORITY, docs/plans/prereg-reentry-personal-vote-priority-
    # 2026-09-08.md. .own_prev's identity-matched defector floor must not be
    # overwritten by the generic re-entry GLM, which has no idea who the
    # candidate is (same shape as Kiama's Gareth Ward, NSW; Morwell's Russell
    # Northe, Nationals -> IND, is Victoria's own case).
    .rc <- protect_personal_vote_cells(REENTRY_CELLS, .own_prev)
    .ri <- cbind(match(.rc$seat,  rownames(shares)),
                 match(.rc$party, colnames(shares)))
    .rk <- stats::complete.cases(.ri)
    shares[.ri[.rk, , drop = FALSE]] <- .rc$value[.rk]
    .protected <- nrow(REENTRY_CELLS) - nrow(.rc)
    cat(sprintf("BV1r  re-entry applied post-swing to %d cell(s)%s\n", sum(.rk),
                if (.protected) sprintf(" | %d protected by own_prev", .protected) else ""))
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
  # ZERO IND WHEREVER NOBODY ACTUALLY STOOD AT THE TARGET ELECTION. Ported from
  # backtest_candidate_fed.R and backtest_candidate_sa.R; was missing here and
  # in NSW and WA. Which classes contest a seat is nomination data, knowable
  # before polling day, unlike the vote share those classes go on to get.
  # Without it the model swings the PRIOR election's independent vote forward
  # with no check that anyone recontested -- found investigating NSW's Dubbo,
  # which carried a retired independent's 28.4% forward with nobody to hold it.
  if ("IND" %in% colnames(shares)) {
    ind_seats <- fb[party == "IND" & votes > 0, unique(seat)]
    no_ind <- setdiff(rownames(shares), ind_seats)
    zeroed <- no_ind[shares[no_ind, "IND"] > 0]
    shares[no_ind, "IND"] <- 0
    if (length(zeroed)) {
      cat(sprintf("BV0  vic%d: zeroed IND in %d seat(s) with no independent nominated: %s\n",
                  K$to, length(zeroed), paste(sort(zeroed), collapse = ", ")))
    }
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
  # ARM SURGE-V2: see R/salience_surge.R and scripts/backtest_candidate_fed.R
  # for the full rationale. Computed fresh per pair, fit on every OTHER
  # available election so the target never leaks into its own fit.
  surge_arg <- SURGE_H; surge_mu_arg <- 15.6; surge_sd_arg <- 6.1
  surge_party_arg <- NULL
  if (identical(Sys.getenv("AUSPOL_SALIENCE_SURGE_V2", "0"), "1")) {
    v2_pairs <- list(
      list(election = "fed2010", prev = "fed2007", region = "fed"),
      list(election = "fed2013", prev = "fed2010", region = "fed"),
      list(election = "fed2016", prev = "fed2013", region = "fed"),
      list(election = "fed2019", prev = "fed2016", region = "fed"),
      list(election = "fed2022", prev = "fed2019", region = "fed"),
      list(election = "vic2022", prev = "vic2018", region = "vic"),
      list(election = "nsw2023", prev = "nsw2019", region = "nsw"),
      list(election = "sa2026",  prev = "sa2022",  region = "sa"),
      list(election = "wa2008",  prev = "wa2005",  region = "wa"))
    train_pairs <- Filter(function(p) p$election != .eb, v2_pairs)
    hz <- tryCatch(surge_hazard_for(.eb, .ea, "vic", train_pairs),
                   error = function(e) { cat(sprintf("BV0v! surge-v2 failed for %s: %s\n", .eb, conditionMessage(e))); NULL })
    if (!is.null(hz)) {
      sn <- rownames(shares)
      if (is.null(sn) && is.data.frame(shares)) sn <- as.character(shares$seat)
      v <- setNames(hz$seat_hazard$surge_h, hz$seat_hazard$seat)[sn]
      miss <- sum(is.na(v)); v[is.na(v)] <- 0
      surge_arg <- unname(v); surge_mu_arg <- hz$surge_mu; surge_sd_arg <- hz$surge_sd
      # THE SALIENCE POINT ESTIMATE, ported from the federal harness 2026-09-07.
      # This harness used the hazard for the DRAW only, so a governed candidate
      # with real salience kept a uniform-swing projection here while the same
      # candidate would have been blended federally.
      .exp_mode <- suppressWarnings(as.integer(Sys.getenv("AUSPOL_SALIENCE_EXPECTED", "0")))
      if (is.na(.exp_mode)) .exp_mode <- 0L
      shares <- blend_salience_shares(shares, hz, surge_mu_arg[1], expected = .exp_mode > 0L)
      # THE VARIANCE, not just the point estimate. level_sd is binomial-shaped
      # and gives a major on 30% more uncertainty than a top-percentile
      # insurgent on 13.9%; the salience band has measured the latter at 12.6.
      # exp_sd has been computed since surge_hazard_for() was written and read
      # by nothing. n_set is printed because an override that fills no cells is
      # an arm that looks like it ran and did not.
      if (identical(Sys.getenv("AUSPOL_SALIENCE_EXP_SD", "0"), "1")) {
        SD_OVR <- salience_sd_matrix(shares, hz)
        cat(sprintf("BV0d salience sd override: %d of %d cells set\n",
                    attr(SD_OVR, "n_set"), length(SD_OVR)))
      }
      cat(sprintf("BV0b salience point estimate applied to %d (seat,party) cells\n", attr(shares, "cells")))
      if (identical(Sys.getenv("AUSPOL_SURGE_RECIPIENT", "1"), "1") && !is.null(hz$seat_recipient)) {
        # THE SURGE GOES TO THE CLASS THE HAZARD WAS FITTED FOR (prereg-surge-recipient-2026-09-06.md).
        surge_party_arg <- unname(setNames(hz$seat_recipient$party, hz$seat_recipient$seat)[sn])
        cat(sprintf("SR1  surge recipient ON: %d of %d seats name a class (%s)\n", sum(!is.na(surge_party_arg)), length(sn),
                    paste(sprintf("%s=%d", names(table(surge_party_arg)), as.integer(table(surge_party_arg))), collapse = " ")))
      }
      # THE SCALE OF THE HAZARD (docs/plans/prereg-surge-hazard-scale-2026-09-06.md).
      # The ridge fit shrinks every seat toward the base rate, so the top-ranked
      # emergence seats carry 0.03-0.05; this multiplies before the blend and
      # the draw, capped at 1. Published value 1 until the sweep decides.
      .surge_scale <- as.numeric(Sys.getenv("AUSPOL_SURGE_SCALE", "1"))
      if (!is.finite(.surge_scale) || .surge_scale <= 0) stop("AUSPOL_SURGE_SCALE must be a positive number")
      if (.surge_scale != 1) {
        surge_arg <- pmin(1, surge_arg * .surge_scale)
        cat(sprintf("SC1  surge hazard x%.1f: mean %.4f, max %.4f, seats at the cap %d\n",
                    .surge_scale, mean(surge_arg), max(surge_arg), sum(surge_arg >= 1)))
      }
      cat(sprintf("BV0v %s: surge-v2 hazard for %d of %d seats (%d absent -> 0) | mean %.4f | mu %.2f sd %.2f | lambda %.1f | train winners %d\n",
                  .eb, length(sn) - miss, length(sn), miss, mean(surge_arg),
                  surge_mu_arg, surge_sd_arg, hz$lambda, hz$n_train_winners))
    }
  }
  # ARM H, docs/plans/prereg-reentry-flatratio-variance-2026-09-08.md. Widens
  # the SIMULATED uncertainty, not the point estimate, for cells that fell
  # back to the flat re-entry ratio -- point-shrinkage was tried and refused
  # for these classes (docs/NEXT-STEPS.md 2026-09-08). Off by default
  # (AUSPOL_REENTRY_SD_K=0); combined with any salience sd_override by taking
  # the larger of the two, never adding them.
  .reentry_sd_k <- as.numeric(Sys.getenv("AUSPOL_REENTRY_SD_K", "0"))
  if (.reentry_sd_k > 0) {
    .re_sd <- reentry_sd_matrix(shares, REENTRY_CELLS, .level_sd, .lm(shares), .reentry_sd_k)
    cat(sprintf("RH1  re-entry sd widening ON (k=%.1f): %d cell(s)
",
                .reentry_sd_k, attr(.re_sd, "n_set")))
    SD_OVR <- combine_sd_override(SD_OVR, .re_sd)
  }
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
      s1 <- simulate_seat_contests(level_sd = .level_sd, sd_override = SD_OVR, level_mult = .lm(shares), shares, fmr, party_sd = psd,
                                   seat_sd = sp$sd_within * SEAT_SD_MULT, n_sims = per,
                                   smooth = SMOOTH, seed = SEED + r, shrink = SHRINK,
                                   fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD,
                                surge_h = surge_arg, surge_party = surge_party_arg,
                                surge_from_zero = identical(Sys.getenv("AUSPOL_SURGE_FROM_ZERO", "0"), "1"), surge_mu = surge_mu_arg, surge_sd = surge_sd_arg)
      w1 <- as.data.table(s1$win_prob)[, .(seat, party, n = prob * per)]
      acc <- if (is.null(acc)) w1 else rbind(acc, w1)
    }
    wp <- acc[, .(prob = sum(n) / (R_ENS * per)), by = .(seat, party)]
    cat("BV1b flow uncertainty ON
")
  } else {
    set.seed(SEED)
    sim <- simulate_seat_contests(level_sd = .level_sd, sd_override = SD_OVR, level_mult = .lm(shares), shares, fm, party_sd = psd,
                                  seat_sd = sp$sd_within * SEAT_SD_MULT, n_sims = N_SIMS,
                                  smooth = SMOOTH, seed = SEED, party_cor = PARTY_COR,
                                  shrink = SHRINK,
                                  fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD,
                                surge_h = surge_arg, surge_party = surge_party_arg,
                                surge_from_zero = identical(Sys.getenv("AUSPOL_SURGE_FROM_ZERO", "0"), "1"), surge_mu = surge_mu_arg, surge_sd = surge_sd_arg)
    cat(sprintf("BV2e  engine %s | surge recipient fell back: %d class(es) absent, %d seat-draws at zero share\n", sim$engine, sim$surge_recipient_fallback, sim$surge_recipient_fallback_draws))
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
  .rr <- seat_share_rmse(shares, fb)  # the second metric: point-estimate seat-share RMSE vs actual
  share_detail[[length(share_detail) + 1L]] <-
    data.table::as.data.table(.rr$detail)[, pair := sprintf("vic%d", K$to)]
  cat(sprintf("BV2r  seat-share RMSE %.3f | MAE %.3f | by class %s | %d seats%s\n", .rr$rmse, .rr$mae,
              paste(sprintf("%s=%.2f", names(.rr$by_class), .rr$by_class), collapse = " "),
              .rr$n_seats, if (.rr$n_dropped) sprintf(" (%d unmatched dropped)", .rr$n_dropped) else ""))
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
fwrite(rbindlist(share_detail, fill = TRUE), file.path("output", sprintf("backtest-vic-sharedetail%s.csv", CAL_TAG)))
cat(sprintf("\nBV4  pooled over %d district-elections: accuracy %.1f%%, Brier %.4f\n",
            nrow(R), 100 * mean(R$pred == R$actual), mean((1 - R$prob)^2)))
cat("BV4  for comparison, NSW 2023 gave 80.7% and 0.1468\n")
cat("\nBV5  by the party that actually won\n")
print(R[, .(n = .N, mean_prob_we_gave = round(mean(prob), 3),
            called = sum(pred == actual)), by = actual][order(-n)])

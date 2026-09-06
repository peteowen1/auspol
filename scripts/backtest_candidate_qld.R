# Queensland 2020 -> 2024: the sixth candidate-level seat harness.
#
# Built 2026-09-07 from scripts/backtest_candidate_sa.R, which has the same
# single-pair shape. CLAUDE.md has recorded since 2026-08-25 that a Queensland
# harness is "buildable from data already on disk and does not exist yet";
# everything it needs was fetched on 2026-08-22 and has sat unused since.
#
# WHY IT IS WORTH BUILDING. Three reasons, in order:
#   1. Pete's objective is pooled seat log loss and seat-share RMSE across
#      EVERY election we forecast. Queensland 2024 adds 93 seat-elections to
#      1,549, and it is a jurisdiction the other five do not cover -- one
#      merged Coalition party, so a class structure no other harness has.
#   2. AE Forecasts publishes qld2024 (93 seats, log loss 0.3578), so this is
#      one more election where the benchmark can be scored against us rather
#      than quoted at us.
#   3. The emergence sample is 20 winners over nine elections and that is the
#      binding constraint on every salience question now open. Queensland is
#      the cheapest way to grow it.
#
# WHAT DIFFERS FROM THE OTHER FIVE, and why:
#   * FLOWS COME FROM QUEENSLAND'S OWN 2020 DISTRIBUTION (ecq-qld-transfers),
#     not from a federal election. Every other state harness borrows federal
#     flows because its own commission publishes none for the prior election;
#     the ECQ publishes both, so the state's own preferences are used, and
#     qld2020 is strictly before qld2024 so nothing leaks.
#   * NO ONE NATION CONCENTRATION ARM. The SA harness carries one, keyed on
#     `region == "sa"` in the transposed-federal file with a hardcoded
#     Frome -> Ngadjuri rename. It is SA-specific and off by default; it is
#     not ported rather than being ported wrongly.
#   * Queensland's Coalition is a single merged party (LNP), so the
#     three-cornered contests the WA and federal harnesses handle do not
#     arise here.
#
# Emits BQ* codes.
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
# spread, so the simulation carries more genuine seat-level uncertainty. Default
# 1 reproduces the published behaviour exactly; the run prints what it applied,
# because CLAUDE.md records an experiment whose edit never ran and whose
# byte-identical output read as "this input does not matter".
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

# OUTPUT FILENAME CARRIES THE CONFIG, and it must. These harnesses used to write
# to one fixed name, so running an experimental arm SILENTLY OVERWROTE the
# baseline it was meant to be compared against. That happened on 2026-08-21: a
# seat_sd sweep overwrote backtest-fed.csv and backtest-vic.csv, and the
# resulting comparison showed a difference of EXACTLY +0.0000 for all six
# federal elections because both arms were the same file. It read as "this
# input does not matter", which is the failure mode CLAUDE.md already records
# for an experiment that never ran.
#
# A default run still writes the plain name, so nothing downstream changes.

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

# Read from the environment like the federal and Victorian harnesses, and
# tagged into the filename below. Hardcoded, this script could not be run
# at the same sim count as the arms it is compared against, and a paired
# comparison across jurisdictions at different sim counts is not paired.
N_SIMS <- as.integer(Sys.getenv("AUSPOL_N_SIMS", "20000"))

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
  if (SEAT_SD_MULT != 1) sprintf("-m%s", format(SEAT_SD_MULT, nsmall = 1)) else "",
  # The concentration arm MUST be in the tag. Without it the arm overwrites
  # backtest-sa.csv and a before/after comparison compares an arm with itself
  # -- the baseline-clobbering that has already produced four byte-identical
  # comparisons in this repo.
  if (as.numeric(Sys.getenv("AUSPOL_ONP_CONC_SD", "0")) > 0)
    sprintf("-conc%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_ONP_CONC_SD")), nsmall = 2)))
  else "",
  if (as.numeric(Sys.getenv("AUSPOL_SHRINK", "0")) != 0)
    sprintf("-sh%s", sub("0[.]", "", format(as.numeric(Sys.getenv("AUSPOL_SHRINK")), nsmall = 2)))
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
  if (as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0")) != 0)
    sprintf("-el%s", sub("[.]", "", format(as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER")), nsmall = 1)))
  else "",
  if (identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")) "-port" else "",
  # "-corraw" and "-cor" are DIFFERENT correlation matrices. Both used to tag
  # "-cor", so running the raw arm and then the shrunk one wrote the second
  # over the first and a before/after comparison compared an arm with itself.
  if (!is.null(PARTY_COR))
    (if (identical(Sys.getenv("AUSPOL_PARTY_COR"), "raw")) "-corraw" else "-cor")
  else "",
  if (N_SIMS != 20000L) sprintf("-n%d", N_SIMS) else "",
  if (!is.null(.level_sd)) sprintf("-lv%s", gsub("[.]", "", paste(format(.level_sd, nsmall=2), collapse="_"))) else "",
  if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1")) "-qld" else "",
  if (identical(Sys.getenv("AUSPOL_WA_FLOWS", "0"), "1")) "-wa" else "",
  # The control arm of refusal W1 runs with the flows switched ON and a cutoff
  # that admits nothing. Without this it would write to the same "-wa" name as
  # the real arm and overwrite it -- the baseline-clobbering that has already
  # produced four byte-identical comparisons here.
  if (nzchar(Sys.getenv("AUSPOL_WA_CUTOFF", "")) ||
      nzchar(Sys.getenv("AUSPOL_QLD_CUTOFF", ""))) "-cut" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_3C", "0"), "1")) "-no3c" else "",
  if (identical(Sys.getenv("AUSPOL_WA_DROP_LNP", "0"), "1")) "-nolnp" else "", .arm_fingerprint, .code_tag)

SEED <- 42; # INSURGENCY SURGE, against docs/plans/prereg-insurgency-surge.md. Wired here on
# 2026-08-26 after a four-arm comparison produced BYTE-IDENTICAL results for the
# surge arm and the do-nothing arm in this harness -- the "this input does not
# matter" signature. It was implemented in seat_sim.R and wired into the federal
# and WA harnesses only, so three of five compared the surge against itself.
# Third breach of the fix-everywhere rule in one day.
SURGE_H <- as.numeric(Sys.getenv("AUSPOL_SURGE_H", "0"))
if (SURGE_H > 0)
  cat(sprintf("BQ0s surge hazard %.4f, size N(15.6, 6.1), floor 2%%
", SURGE_H))
SMOOTH <- 0.15; eps <- 1e-6
P <- election_data_path()
FLOW_FROM <- "qld2020"   # Queensland's OWN prior distribution; see the header

need <- c("ecq-2020-qld-firstprefs.csv", "ecq-2024-qld-firstprefs.csv",
          "ecq-qld-winners.csv", "ecq-qld-transfers.csv")
miss <- need[!file.exists(file.path(P, need))]
if (length(miss)) {
  stop("Missing ", paste(miss, collapse = ", "), ". Run ",
       "scripts/fetch_preferences_qld.R.")
}

fa <- fread(file.path(P, "ecq-2020-qld-firstprefs.csv"), showProgress = FALSE)
fb <- fread(file.path(P, "ecq-2024-qld-firstprefs.csv"), showProgress = FALSE)
win <- fread(file.path(P, "ecq-qld-winners.csv"),
             showProgress = FALSE)[election == "qld2024", .(seat, winner)]
tx <- fread(file.path(P, "ecq-qld-transfers.csv"),
            showProgress = FALSE)[election == FLOW_FROM]
# Guard on the row count as well as the id: all() over an empty table is TRUE,
# which is the guard-that-cannot-fail pattern CLAUDE.md records.
stopifnot(nrow(tx) > 100L, all(tx$election == FLOW_FROM))
# NOT pooled with the external sources: tx already IS Queensland's own
# transfers, and AUSPOL_QLD_FLOWS=1 (published) would pool qld2020 into
# itself. The other harnesses pool because they start from federal flows.
if (identical(Sys.getenv("AUSPOL_QLD_FLOWS", "0"), "1"))
  cat("BQ1! AUSPOL_QLD_FLOWS is set and IGNORED here: this harness already uses Queensland's own flows\n")
fm <- build_flow_matrix(tx, min_n = 3L)
cat(sprintf("\nBQ1  flow matrix from %s: %d exclusions\n",
            FLOW_FROM, uniqueN(tx[, paste(seat, round)])))

wide <- dcast(fa, seat ~ party, value.var = "votes", fill = 0)
mat <- as.matrix(wide[, -1, with = FALSE]); rownames(mat) <- wide$seat
mat <- 100 * mat / rowSums(mat)
st_a <- fa[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]
st_b <- fb[, .(v = sum(votes)), by = party][, setNames(100 * v / sum(v), party)]

parties <- colnames(mat); shares <- mat

# STRONGHOLD ELASTICITY, against docs/plans/prereg-stronghold-elasticity.md.
# Default OFF; a plain run is byte-identical.
#
# A uniform swing takes the same POINTS from a seat holding 67% as from one
# holding 30%. Measured across 2,878 observations, that is right on average and
# badly wrong in one specific place: a STRONGHOLD of a party FALLING statewide,
# where proportional nearly halves the error (MAE 6.964 -> 3.848 at >1.5x
# over-index, n=102). For all parties regardless of direction the same band has
# uniform better by 1.155, so the effect is conditional on falling.
#
# Both thresholds are FIXED by the plan and are not tuned here.
ELASTIC   <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_OVER", "0"))   # 0 = off; 1.5 = on
ELASTIC_D <- as.numeric(Sys.getenv("AUSPOL_ELASTIC_FALL", "2"))   # min statewide fall
n_elastic <- 0L; elastic_seats <- character(0)
# Which (seat, party) cells the rule cut. Renormalisation must NOT hand a
# stronghold back a share of the vote just taken off it -- measured on
# MacKillop, plain renormalisation undid 38% of the cut (35.3 -> 40.6).
DEV_SLOPE <- dev_slopes_for(union(parties, names(st_b)))
  .cond <- Sys.getenv("AUSPOL_DEV_SLOPE_MODE", "") %in% c("conditional", "screened")
  .screened <- identical(Sys.getenv("AUSPOL_DEV_SLOPE_MODE", ""), "screened")
.returns <- if (.cond) tryCatch(candidate_returns("qld2020", "qld2024"), error = function(e) {
  cat(sprintf("BQ1c! conditional slopes unavailable: %s
", conditionMessage(e))); NULL }) else NULL
if (.cond && !is.null(.returns))
  cat(sprintf("BQ1c conditional slopes ON: %d of %d seat-classes returning
",
              sum(.returns$same), nrow(.returns)))
# PORTED FROM THE FEDERAL HARNESS 2026-09-05, per this repo's rule that a fix
# to one harness is a fix to all of them. Both default OFF, so the default path
# is byte-identical until an arm sets them.
#   AUSPOL_MP_SLOPE        -- returning MEMBER (0.954) vs returning also-ran
#                             (0.800); the shipped slope pooled them at 0.907.
#   AUSPOL_DEFECT_DISCOUNT -- the measured form of the very exclusion the
#                             comment below argues for: a sitting major-party
#                             member re-contesting under a non-major label
#                             brings 0.282 of their major vote, ADDED to that
#                             class's base rather than replacing it. Fitted
#                             federally; MacKillop (62.3 -> 14.8) is the case
#                             that sets the discount low.
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
    .tgt <- "qld2024"                       # copied to a differently-named local: a bare
    .row <- .mpt[.mpt$target == .tgt & is.finite(.mpt$member), ]  # `target` inside
    if (!nrow(.row))                                              # `[` would bind
      stop("no leave-one-out MP slopes for ", .tgt, " in ", .mpf) # to the column
    if (!identical(Sys.getenv("AUSPOL_MP_SLOPE_GRN", "0"), "1"))
      .row <- .row[.row$party != "GRN", ]   # GRN's member/also-ran gap is ~0
    .MP_SLOPE <- stats::setNames(as.numeric(.row$member), .row$party)
  }
  cat(sprintf("BQ1m  MP tier: %s
  ",
              if (is.null(.MP_SLOPE)) "OFF" else
                paste(sprintf("%s=%.4f", names(.MP_SLOPE), .MP_SLOPE), collapse = " ")))
.defect <- if (identical(Sys.getenv("AUSPOL_DEFECT_DISCOUNT", "0"), "1")) 0.282 else NULL
# THE BASE VALUE, not just the slope -- see personal_prior_vote()'s docs.
.own_prev <- if (.cond) tryCatch(personal_prior_vote("qld2020", "qld2024", major_discount = .defect), error = function(e) { cat(sprintf("BQ1p! personal_prior_vote() FAILED; class-level bases kept and NO transfer removed: %s\n", conditionMessage(e))); NULL }) else NULL
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
.permit <- if (.screened) salience_permit_for("qld2024", "qld2020", "qld") else NULL
.sa_slope <- function(p, seats) {
  if (.screened && !is.null(.permit)) {
    pv <- .permit[.permit$party == p, ]
    lut <- stats::setNames(as.logical(pv$permit), pv$seat)
    pm <- unname(lut[seats]); pm[is.na(pm)] <- TRUE
    return(screened_slopes(p, seats, .returns, pm, same_mp = .MP_SLOPE))
  }
  if (.cond && !is.null(.returns)) return(conditional_slopes(p, seats, .returns, same_mp = .MP_SLOPE))
  DEV_SLOPE[[p]]
}
cat(sprintf("BQ1d  dev slopes: %s%s
",
            if (all(DEV_SLOPE == 1)) "all 1.000 (uniform swing)" else
              paste(sprintf("%s=%.3f", names(DEV_SLOPE), DEV_SLOPE), collapse=" "),
            if (length(attr(DEV_SLOPE, "absent")))
              paste0(" | not contested here: ",
                     paste(attr(DEV_SLOPE, "absent"), collapse=",")) else ""))
pinned <- matrix(FALSE, nrow(mat), ncol(mat), dimnames = dimnames(mat))

for (p in parties) if (p %in% names(st_b) && p %in% names(st_a)) {
  d_state <- st_b[[p]] - st_a[[p]]
  .sl <- .sa_slope(p, rownames(mat))
  x_p <- .own_x(p, rownames(mat), mat[, p])
  val <- dev_slope(x_p, st_a[[p]], st_b[[p]], .sl)
  if (ELASTIC > 0 && d_state < -ELASTIC_D && st_a[[p]] > 0) {
    over <- x_p / st_a[[p]]
    hit  <- is.finite(over) & over > ELASTIC
    if (any(hit)) {
      val[hit] <- pmax(0, x_p[hit] * st_b[[p]] / st_a[[p]])
      pinned[hit, p] <- TRUE
      n_elastic <- n_elastic + sum(hit)
      elastic_seats <- c(elastic_seats, sprintf("%s:%s", p, rownames(mat)[hit]))
    }
  }
  shares[, p] <- val
}
# PRINT WHAT IT APPLIED. CLAUDE.md records an experiment whose edit never ran
# and whose byte-identical output read as "this input does not matter".
if (ELASTIC > 0) {
  cat(sprintf("BQ1e elasticity ON (over-index > %.2f, statewide fall > %.1f): %d (seat, party) cells\n",
              ELASTIC, ELASTIC_D, n_elastic))
  if (n_elastic) {
    cat(sprintf("BQ1e fired on: %s\n",
                paste(utils::head(sort(elastic_seats), 12), collapse = ", ")))
  }
} else {
  cat("BQ1e elasticity OFF (uniform swing)\n")
}
# One Nation stood in most Queensland districts at both elections, so the
# districts have a ZERO baseline for the party that went on to make the final
# two in 32 of them. Adding the statewide shift to a zero baseline is the only
# thing that can be done without inventing a district-level distribution -- but
# it means the model enters those seats assuming One Nation polls its statewide
# average there. That is recorded because it is the single biggest source of
# error here, not because it can be fixed.
absent22 <- setdiff(names(st_b)[st_b > 1], names(st_a)[st_a > 1])
zero_base <- sum(mat[, "ONP"] == 0)
cat(sprintf("BQ1  districts with no 2020 One Nation vote to swing from: %d of %d\n",
            zero_base, nrow(mat)))
if (length(absent22)) {
  cat(sprintf("BQ1  parties polling >1%% in 2026 but not 2022: %s\n",
              paste(absent22, collapse = ", ")))
}
# The SA harness's One Nation CONCENTRATION arm is deliberately not ported:
# it is keyed on `region == "sa"` in federal-transposed-to-state.csv and
# carries a hardcoded Frome -> Ngadjuri rename. Porting it would need a
# Queensland transposition and its own pre-registration.

# ZERO IND WHERE NO INDEPENDENT STOOD. Ported from backtest_candidate_fed.R,
# which got this fix today; this harness never had it.
#
# Six Queenslandn seats had an independent in 2022 and none in 2026, and
# the model swings the departed candidate's vote forward regardless. Frome --
# renamed Ngadjuri, and one of the four seats One Nation won -- carried a
# 16.6% independent in 2022 who did not recontest, so roughly 15 points of the
# seat is assigned to a candidate who does not exist and every real party is
# dragged down when the seat renormalises.
#
# This is NOMINATION data, not the result: which classes contest a seat is
# knowable before polling day. There is no pre-election nomination list here,
# only "IND received a nonzero vote in the target election" as a proxy, so it
# is the same oracle input this harness already uses for `st_b` -- consistent
# with the default path, and it is why the federal version is gated OFF under
# FORECAST_MODE.
if ("IND" %in% colnames(shares)) {
  ind_seats <- fb[party == "IND" & votes > 0, unique(seat)]
  no_ind <- setdiff(rownames(shares), ind_seats)
  zeroed <- no_ind[shares[no_ind, "IND"] > 0.5]
  shares[no_ind, "IND"] <- 0
  cat(sprintf("BQ1i zeroed IND in %d seat(s) with no independent nominated%s\n",
              length(zeroed),
              if (length(zeroed)) paste0(": ", paste(sort(zeroed), collapse = ", ")) else ""))
}

# CONSTRAINED RENORMALISATION. Plain renormalisation scales every party in the
# seat, including one the elasticity rule just cut -- so the cut party receives
# back a share of its own removed vote. Measured on MacKillop: elasticity takes
# the Coalition to 35.3 (AEF forecast 35.0, actual 26.9) and renormalising puts
# it straight back to 40.6, undoing 38% of the correction.
#
# Where a cell was cut, it is PINNED at its elastic value and only the other
# parties in that seat are scaled to fill the remainder.
if (ELASTIC > 0 && any(pinned)) {
  for (i in which(rowSums(pinned) > 0)) {
    keep <- pinned[i, ]
    fixed_tot <- sum(shares[i, keep])
    rest <- shares[i, !keep]
    rest_tot <- sum(rest)
    room <- 100 - fixed_tot
    if (rest_tot > 0 && room > 0) {
      shares[i, !keep] <- rest * room / rest_tot
    }
  }
  # every other seat renormalises as before
  other <- which(rowSums(pinned) == 0)
  if (length(other)) {
    shares[other, ] <- 100 * shares[other, , drop = FALSE] / rowSums(shares[other, , drop = FALSE])
  }
  cat(sprintf("BQ1e constrained renormalisation applied to %d seat(s)\n",
              sum(rowSums(pinned) > 0)))
} else {
  shares <- 100 * shares / rowSums(shares)
}

# FROME WAS RENAMED NGADJURI at the 2025 Queenslandn redistribution, and
# it is the only name that differs between the two polls. It is MAPPED rather
# than dropped, which is the opposite of what backtest_candidate_vic.R does with
# Eureka -- so the reason has to be better than convenience.
#
# It is: One Nation WON Ngadjuri. Dropping the seat would remove one of its four
# wins from a 47-seat test whose entire purpose is scoring how the model handles
# a One Nation surge, and would do so in the direction that flatters the model.
# Excluding a seat is not neutral when the exclusion is correlated with the
# outcome under test.
#
# What is NOT verified is whether the boundaries moved materially as well as the
# name. If they did, this seat carries more error than the rest, and it is named
# here so nobody has to rediscover which one it is.
# NO RENAME MAP. Queensland's districts are the same 93 in 2020 and 2024 --
# the ECQ's 2017 redistribution predates both, and all 93 match by name
# (asserted below). The SA harness's Frome -> Ngadjuri map is SA's 2025
# redistribution and does not apply; carrying it here would silently rename a
# Queensland seat if one were ever called Frome.
keep <- intersect(rownames(shares), win$seat)
shares <- shares[keep, , drop = FALSE]
truth <- setNames(win$winner, win$seat)[keep]
N_DISTRICTS <- 93L   # Queensland's Legislative Assembly, unchanged 2020 -> 2024
if (length(keep) != N_DISTRICTS) {
  stop("Only ", length(keep), " of ", N_DISTRICTS, " districts matched between the 2020 first ",
       "preferences and the 2024 winners after applying the rename map. ",
       "Unmatched: ",
       paste(setdiff(win$seat, rownames(shares)), collapse = ", "))
}

# ---- seat-swing port, third testable election ------------------------------
# Against docs/plans/prereg-seat-swing-port-round2.md, which had TWO elections
# and a clustered standard error on one degree of freedom. Queensland is
# the third: 2026sa.txt carries fed_swing for all 47 seats. The federal corpus
# cannot help -- its seat files carry fed_swing for zero seats, because "how
# this seat swung at the preceding federal election" has no federal analogue.
#
# Same block as the Victorian and NSW harnesses, unchanged in substance
# (refusal P4).
PORT <- identical(Sys.getenv("AUSPOL_SEAT_SWING_PORT", "0"), "1")
if (PORT) {
  sf_to <- as.data.table(load_seats(2024L, "qld"))
  idx_p <- match(rownames(shares), sf_to$seat)
  adj <- rep(0, nrow(shares))
  adj[!is.na(idx_p)] <- seat_swing_adjustment(sf_to[idx_p[!is.na(idx_p)]])
  if (anyNA(idx_p)) {
    cat(sprintf("BQ1c %d seats have no match in the seat file and get no adjustment: %s\n",
                sum(is.na(idx_p)), paste(rownames(shares)[is.na(idx_p)], collapse = ", ")))
  }
  adj <- adj - mean(adj)
  stopifnot(all(is.finite(adj)))
  cat(sprintf("BQ1c seat-swing port ON: adjustment mean %+.3f sd %.3f range %+.2f..%+.2f\n",
              mean(adj), stats::sd(adj), min(adj), max(adj)))
  shares[, "ALP"] <- pmax(0, shares[, "ALP"] + adj)
  shares[, "LNP"] <- pmax(0, shares[, "LNP"] - adj)
  shares <- 100 * shares / rowSums(shares)
}

# Per-seat spread from the seat file of the election being predicted.
sp <- seat_swing_spread(as.data.table(load_seats(2024L, "qld")),
                        unname(st_b[["ALP"]] - st_a[["ALP"]]))
# STATEWIDE UNCERTAINTY. 1.5 was hardcoded in all four harnesses; the realised
# statewide first-preference error over 139 party-cycles is sd 2.33, so the
# harnesses were 1.6x over-confident BEFORE any seat-level modelling. That is
# upstream of `shrink`, which is a post-hoc patch for uncertainty that should
# have been present. fit_seats_full.R already uses a per-party state_sd and
# falls back to 1.5 only when it is NA.
PARTY_SD <- as.numeric(Sys.getenv("AUSPOL_PARTY_SD", "1.5"))
psd <- setNames(rep(PARTY_SD, length(parties)), parties)
cat(sprintf("BQ1p party_sd %.2f (realised statewide sd is 2.33)
", PARTY_SD))

# THIS HARNESS HAS NEVER PASSED `shrink`, which is the same defect
# docs/reviews/calibration-2026-08-21.md found in the federal, Victorian and
# NSW harnesses and which was never fixed here.
#
# fit_seats_full.R -- the model that PUBLISHES -- passes shrink = 0.10, the
# per-draw calibration shrink adopted after measuring over-confidence on 1,187
# seats. simulate_seat_contests() defaults it to 0. So every calibration figure
# this harness has produced, including the slope of 0.299 and the four One
# Nation seats at 0.000, describes a configuration we DO NOT SHIP.
#
# It matters most in exactly the seats that fail here. Shrink is a coin toss
# between the FINAL TWO, so where One Nation makes the final pair and loses, it
# still collects roughly shrink/2 of the draws instead of nothing.
#
# Defaulted to 0 so past runs stay comparable and nothing changes silently.
SHRINK <- as.numeric(Sys.getenv("AUSPOL_SHRINK", "0"))
stopifnot(is.finite(SHRINK), SHRINK >= 0, SHRINK < 1)
cat(sprintf("BQ1s shrink %.2f (fit_seats_full.R publishes with 0.10)\n", SHRINK))

set.seed(SEED)
# The two flow fixes, both default OFF so a plain run is unchanged.
# docs/reviews/flow-matrix-is-the-defect-2026-08-25.md: this matrix has NO
# conditional cell for ALP|LNP+ONP, LNP|ALP+ONP or GRN|LNP+ONP, so every
# One Nation contest falls back to a pooled rate that gives ONP 2.9% of Labor
# preferences (actual 22.1%) and 4.5% of Coalition preferences (actual 54.0%).
FB_SMOOTH <- as.numeric(Sys.getenv("AUSPOL_FALLBACK_SMOOTH", "0"))
FLOW_SD   <- as.numeric(Sys.getenv("AUSPOL_FLOW_SD", "0"))
cat(sprintf("BQ1f fallback_smooth %.2f | flow_sd %.2f\n", FB_SMOOTH, FLOW_SD))

# ARM SURGE-V2: see R/salience_surge.R and scripts/backtest_candidate_fed.R.
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
    list(election = "qld2024",  prev = "qld2020",  region = "qld"),
    list(election = "wa2008",  prev = "wa2005",  region = "wa"))
  train_pairs <- Filter(function(p) p$election != "qld2024", v2_pairs)
  hz <- tryCatch(surge_hazard_for("qld2024", "qld2020", "qld", train_pairs),
                 error = function(e) { cat(sprintf("BQ0v! surge-v2 failed: %s\n", conditionMessage(e))); NULL })
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
    cat(sprintf("BQ0b salience point estimate applied to %d (seat,party) cells\n", attr(shares, "cells")))
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
    cat(sprintf("BQ0v qld2024: surge-v2 hazard for %d of %d seats (%d absent -> 0) | mean %.4f | mu %.2f sd %.2f | lambda %.1f | train winners %d\n",
                length(sn) - miss, length(sn), miss, mean(surge_arg),
                surge_mu_arg, surge_sd_arg, hz$lambda, hz$n_train_winners))
  }
}
sim <- simulate_seat_contests(level_sd = .level_sd, level_mult = .lm(shares), shares, fm, party_sd = psd, seat_sd = sp$sd_within * SEAT_SD_MULT,
                              n_sims = N_SIMS, smooth = SMOOTH, seed = SEED,
                              shrink = SHRINK, party_cor = PARTY_COR,
                              fallback_smooth = FB_SMOOTH, flow_sd = FLOW_SD,
                              surge_h = surge_arg, surge_party = surge_party_arg,
                                surge_from_zero = identical(Sys.getenv("AUSPOL_SURGE_FROM_ZERO", "0"), "1"), surge_mu = surge_mu_arg, surge_sd = surge_sd_arg)
cat(sprintf("BQ2e  engine %s | surge recipient fell back: %d class(es) absent, %d seat-draws at zero share\n", sim$engine, sim$surge_recipient_fallback, sim$surge_recipient_fallback_draws))
wp <- as.data.table(sim$win_prob)

pa <- merge(data.table(seat = keep, actual = unname(truth)),
            wp[, .(seat, party, prob)],
            by.x = c("seat", "actual"), by.y = c("seat", "party"), all.x = TRUE)
pa[is.na(prob), prob := 0]
pr <- wp[, .SD[which.max(prob)], by = seat][, .(seat, pred = party, pred_p = prob)]
res <- merge(pa, pr, by = "seat")
stopifnot(nrow(res) == length(keep))
res[, pair := "qld2024"]

z <- data.frame(y = as.integer(res$pred == res$actual),
                lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
sl <- if (length(unique(z$y)) > 1)
  stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
.rr <- seat_share_rmse(shares, fb)  # the second metric: point-estimate seat-share RMSE vs actual
cat(sprintf("BQ2r  seat-share RMSE %.3f | MAE %.3f | by class %s | %d seats%s\n", .rr$rmse, .rr$mae,
            paste(sprintf("%s=%.2f", names(.rr$by_class), .rr$by_class), collapse = " "),
            .rr$n_seats, if (.rr$n_dropped) sprintf(" (%d unmatched dropped)", .rr$n_dropped) else ""))
cat(sprintf("\nBQ2  accuracy %d/%d (%.1f%%) | Brier %.4f | log %.4f | slope %.3f\n",
            sum(res$pred == res$actual), nrow(res),
            100 * mean(res$pred == res$actual), mean((1 - res$prob)^2),
            -mean(log(pmax(res$prob, eps))), sl))

# The question this election exists to answer.
cat("\nBQ3  ONE NATION and the minor right (Katter's party sits in OTH_RIGHT here)\n")
onp_true <- res[actual == "ONP"]
cat(sprintf("BQ3  seats One Nation actually won: %d | our mean probability there: %.3f\n",
            nrow(onp_true), if (nrow(onp_true)) mean(onp_true$prob) else NA_real_))
if (nrow(onp_true)) {
  print(onp_true[, .(seat, we_said = pred, our_p = round(pred_p, 3),
                     gave_ONP = round(prob, 3))][order(-gave_ONP)])
}
onp_pred <- res[pred == "ONP"]
cat(sprintf("BQ3  seats we called for One Nation: %d\n", nrow(onp_pred)))
exp_onp <- wp[party == "ONP", sum(prob)]
cat(sprintf("BQ3  expected One Nation seats across the simulation: %.1f (actual %d)\n",
            exp_onp, sum(truth == "ONP")))

cat("\nBQ4  misses, worst first\n")
print(head(res[pred != actual][order(prob),
                               .(seat, we_said = pred, our_p = round(pred_p, 3),
                                 actual, gave_winner = round(prob, 3))], 10))
fwrite(res, file.path("output", sprintf("backtest-qld%s.csv", CAL_TAG)))

# RETAIN THE FULL PER-SEAT PER-PARTY PROBABILITY TABLE.
#
# `res` above keeps only two rows' worth of information per seat -- the
# predicted winner and the actual winner -- so the probabilities for every
# other party are computed and thrown away. That is why a printed comparison
# does not sum to 1, and why "did we give anyone else a chance?" could not be
# answered without a fresh 25-minute run.
#
# Same shape as the seat-TCP finding earlier today: the quantity exists in
# memory and is discarded at the last step. docs/NEXT-STEPS.md records the
# federal version of this ("The full per-seat per-party probability table is
# never saved").
full <- merge(wp[, .(seat, party, prob)],
              data.table(seat = names(truth), actual = unname(truth)),
              by = "seat", all.x = TRUE)
full[, is_actual := party == actual]
setorder(full, seat, -prob)
fwrite(full, file.path("output", sprintf("backtest-qld-allprobs%s.csv", CAL_TAG)))
cat(sprintf("BQ5  wrote the full probability table: %d rows, %d seats, %d parties\n",
            nrow(full), uniqueN(full$seat), uniqueN(full$party)))
# A seat's probabilities must sum to 1. If they do not, the simulation dropped
# a draw somewhere and every number above is suspect.
chk <- full[, .(s = sum(prob)), by = seat]
if (any(abs(chk$s - 1) > 0.01)) {
  stop("Per-seat probabilities do not sum to 1 in ",
       sum(abs(chk$s - 1) > 0.01), " seat(s); worst ",
       round(max(abs(chk$s - 1)), 4))
}
cat("BQ5  every seat's probabilities sum to 1 (max deviation checked)\n")
fwrite(data.table(pair = "qld2024", as.data.table(sim$totals)), file.path("output", sprintf("backtest-qld-totals%s.csv", CAL_TAG)))

# NAME THE FILE ACTUALLY WRITTEN. This line was a hardcoded string and printed
# "backtest-qld.csv" for every arm, including arms that correctly wrote a tagged
# name. The tag mechanism exists because an untagged arm once overwrote the
# baseline it was being compared against; a log line that reports the untagged
# name recreates that confusion at the point where someone reads the result.
cat(sprintf("\nBQ5  wrote output/backtest-qld%s.csv and its totals\n", CAL_TAG))

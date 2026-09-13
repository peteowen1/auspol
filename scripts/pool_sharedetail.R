# Pool every backtest's per-seat, per-party PRIMARY VOTE point estimate into
# ONE table: our predicted primary, the actual primary, for every seat in
# every election we forecast.
#
# WHY THIS EXISTS. Until 2026-09-09 "what did we predict for seat X's primary
# vote" meant re-running that pair's harness from scratch -- seat_share_rmse()
# always computed this internally (for the RMSE line every harness already
# prints) and threw it away. Now every harness persists it
# (backtest-*-sharedetail*.csv); this script is the pool_backtests.R-style
# reader that turns those files into one answerable table instead of Pete
# having to ask for a fresh sim every time he wants a seat's numbers.
#
# Same discipline as pool_backtests.R: newest file per pair, staleness
# printed rather than assumed, a pair missing entirely is a visible warning
# not a silently short table. Re-run this after any backtest run that should
# be reflected here -- it does not run anything itself.
#
# ============================================================================
# THE CIRCULARITY TRAP, found 2026-09-13, and it cost a night of confused
# measurements before it was traced. READ THIS BEFORE REGENERATING SHAREDETAIL
# FOR THE PURPOSE OF TRAINING fit_xgb_primary_v6.R.
#
# AUSPOL_XGB_PRIMARY = "1" is the SHIPPED DEFAULT (published_flags.R) for
# every harness. It makes xgb_primary_override() REPLACE `shares` with v6's
# OWN prior predictions BEFORE the seat simulator runs -- and the simulator
# writes `pred_share` (into sharedetail, hence into this file, hence into
# what fit_xgb_primary_v6.R calls "the shipped baseline" and trains on as a
# feature) from THAT ALREADY-OVERRIDDEN result. So a sharedetail file built
# under default settings is NOT an independent "shipped model" baseline --
# it is v6's own output, one step removed through the simulator.
#
# Consequence: running "harness -> pool -> refit v6 -> harness again" under
# default flags is NOT a stable measurement, it is an ITERATIVE REFITTING
# LOOP. Doing this several times in one session (investigating sa2026's One
# Nation ranking) fed v6's output back into what it treats as ground truth
# each pass, and the pooled log loss drifted monotonically WORSE with every
# iteration -- 0.5384 -> 0.5794 -> 0.6463 -> 0.7015 -> 0.8126 on sa2026 alone
# -- with NOTHING in the committed code changing between measurements.
#
# THE FIX, every time sharedetail is regenerated FOR v6 TRAINING PURPOSES:
#   1. Run every harness with AUSPOL_XGB_PRIMARY=0 EXPLICITLY -- this writes
#      the TRUE, non-circular shipped-model pred_share.
#   2. Run this script (pool_sharedetail.R) to pool those files.
#   3. Run fit_xgb_primary_v6.R ONCE against that clean pool.
#   4. THEN, and only then, run the harnesses again with default flags
#      (AUSPOL_XGB_PRIMARY=1) to evaluate v6 in its normal operational role.
#      Do not iterate step 4's output back into step 1 -- that is the loop.
#
# Measured cost of getting this right, 2026-09-13: pooled seat log loss over
# all 23 pairs went 0.3115 (contaminated, several iterations deep) -> 0.2926
# (clean, one pass) -- the TRUE model was BETTER than every number reported
# that night, not worse; the contamination had been making it look worse.
#
# NOT YET FIXED: this script cannot tell, from a sharedetail file's name or
# content, whether AUSPOL_XGB_PRIMARY was on or off when it was written --
# the arm fingerprint hashes it in but the hash is not decodable. A proper
# fix records the flag's value as a column or sidecar file per sharedetail
# output and lets this script refuse/warn on contaminated input automatically,
# rather than relying on a human remembering this comment. Top-priority
# follow-up, not yet built.
# ============================================================================
#
# Emits PS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))  # for all_election_pairs()

OUT <- "output"
files <- list.files(OUT, pattern = "-sharedetail.*[.]csv$", full.names = TRUE)
# EXCLUDE THIS SCRIPT'S OWN OUTPUT. "pooled-sharedetail.csv" matches the pattern
# above, carries EVERY pair, and is by construction the newest file the moment
# this has been run once -- so the "newest file per pair" rule below selected it
# for all 23 pairs and the script silently re-copied its own previous output
# instead of re-deriving from the harness runs. Whether it re-derived or
# self-copied depended purely on mtime order, which is not a property anything
# downstream could see. Found 2026-09-12.
files <- files[basename(files) != "pooled-sharedetail.csv"]
if (!length(files)) stop("No sharedetail files in ", OUT, " -- run a harness first")

rows <- rbindlist(lapply(files, function(f) {
  d <- tryCatch(fread(f, showProgress = FALSE), error = function(e) {
    cat(sprintf("PS0! %s: unreadable (%s) -- dropped\n", basename(f), conditionMessage(e)))
    NULL
  })
  if (is.null(d)) return(NULL)
  if (!nrow(d)) { cat(sprintf("PS0! %s: 0 rows -- dropped\n", basename(f))); return(NULL) }
  need <- c("seat", "party", "pred_share", "actual_share", "pair")
  miss <- setdiff(need, names(d))
  if (length(miss)) {
    cat(sprintf("PS0! %s: missing column(s) %s -- dropped\n", basename(f), paste(miss, collapse = ", ")))
    return(NULL)
  }
  # xgb_on: NA when the harness that wrote this file predates the
  # xgb_primary_on column (2026-09-13). NA, not 0 -- an absent column is
  # UNVERIFIABLE, not confirmed clean, and the whole point of this guard is
  # that "unverifiable, therefore allow" is the posture that let the
  # circularity in docs/reviews/xgb-primary-circularity-2026-09-13.md go
  # undetected for a full session.
  xgb_on <- if ("xgb_primary_on" %in% names(d)) as.integer(d$xgb_primary_on[1]) else NA_integer_
  d[, .(file = f, mtime = file.mtime(f), pair = as.character(pair), seat, party,
        pred_share, actual_share, xgb_on = xgb_on)]
}))
if (!nrow(rows)) stop("No readable sharedetail files")

# NEWEST FILE PER PAIR -- two arms of the same pair must never blend, exactly
# the reason pool_backtests.R does this.
pick <- rows[, .(mtime = max(mtime)), by = pair]
rows <- merge(rows, pick, by = c("pair", "mtime"))
keep <- rows[, .(file = file[1]), by = pair]
rows <- merge(rows, keep, by = c("pair", "file"))

# THE ENFORCED VERSION of the warning comment above and in
# fit_xgb_primary_v6.R. AUSPOL_XGB_PRIMARY=1 (the shipped default) makes
# every harness overwrite `shares` with v6's own prior predictions before
# simulating, so pred_share in such a file is v6's output one step removed,
# not an independent baseline -- pooling it and refitting v6 is the
# circularity that cost a full session before it was traced
# (docs/reviews/xgb-primary-circularity-2026-09-13.md). A missing
# xgb_primary_on column (a file from before 2026-09-13) is UNVERIFIABLE, not
# confirmed clean, and gets the same refusal -- "unverifiable, therefore
# allow" is the posture that let this go undetected for a full session.
#
# AUSPOL_POOL_ALLOW_CONTAMINATED=1 is the escape hatch, for the rare case
# this file is wanted as a live/scoreboard read rather than as v6's own
# training input -- named to make misuse visible in any log that sets it.
bad <- unique(rows[is.na(xgb_on) | xgb_on == 1, .(pair, file, xgb_on)])
if (nrow(bad)) {
  # PRINT REGARDLESS OF WHETHER THE ESCAPE HATCH LETS EXECUTION CONTINUE.
  # The first version put this print INSIDE the stop()-guarded block, so
  # setting AUSPOL_POOL_ALLOW_CONTAMINATED=1 skipped both the stop AND the
  # print, and execution fell through to the unconditional "all clean" line
  # below -- a false success message on the exact run where contamination
  # was knowingly let through. Caught by the review gate. The escape hatch's
  # whole purpose is "make misuse visible in any log that sets it"; a log
  # that says "all clean" is the one thing it must never say here.
  print(bad)
  if (!identical(Sys.getenv("AUSPOL_POOL_ALLOW_CONTAMINATED", "0"), "1")) {
    stop(sprintf(paste0(
      "refusing to pool: %d pair(s) come from sharedetail written with ",
      "AUSPOL_XGB_PRIMARY=1 or no record of it at all (NA above means the ",
      "file predates this check). Re-run those harnesses with ",
      "AUSPOL_XGB_PRIMARY=0 before pooling for fit_xgb_primary_v6.R. Set ",
      "AUSPOL_POOL_ALLOW_CONTAMINATED=1 to override for a non-training read."),
      nrow(bad)))
  }
  cat(sprintf("PS3! %d pair(s) pooled DESPITE contamination (AUSPOL_POOL_ALLOW_CONTAMINATED=1) -- NOT safe for v6 training, only for a non-training read\n",
              nrow(bad)))
} else {
  cat(sprintf("PS3  all %d pairs verified clean: xgb_primary_on = 0 for every file pooled\n",
              uniqueN(rows$pair)))
}

# N_SIMS GUARD. `pred_share` here is a SIMULATION MEAN, and this file is not
# only a scoreboard -- fit_xgb_primary_v6.R reads it and trains the shipped
# primary model on that column. So it has two consumers with different precision
# needs, and only one of them tolerates an exploratory run.
#
# CLAUDE.md endorses AUSPOL_N_SIMS=5000 for exploratory arms and 20,000 only for
# a deciding run, which is correct for SCORING. On 2026-09-12 I regenerated all
# 22 pairs at 5,000 to measure the salience percentile fix -- a valid,
# correctly-matched measurement -- and then fed the by-product here. The extra
# sampling noise alone moved v6's pooled primary RMSE from 3.9201 to 4.0729 and
# flipped it from beating its baseline to losing to it by 3.65%. The tell was
# that WA pairs moved (wa2021 +0.672) when the change under test provably does
# nothing in WA, and that old and new correlated at r = 0.9991 -- noise, not a
# systematic shift.
#
# Nothing flagged it: the staleness check passed (all files minutes old), the
# code tag matched, and the column was fully populated. n_sims lives only in the
# filename, so read it and refuse.
# COMPUTED OUTSIDE THE BRACKETS, on a plain named vector. `file` is both a
# column here AND a base R function, so a bare `file` inside j does not resolve
# to the column -- the first version of this check silently found no n_sims on
# any of the 23 pairs and refused for the wrong reason. Tenth instance of the
# data.table NSE trap in this repo; CLAUDE.md says never use a bare column-name
# symbol inside `[`, and that is why.
# ABSENT TOKEN MEANS 20,000, AND THAT IS A CONVENTION, NOT AN UNKNOWN.
#
# All six harnesses build the tag as
#   if (N_SIMS != 20000L) sprintf("-n%d", N_SIMS) else ""
# so a full-quality deciding run carries NO token at all, and the great majority
# of files on disk have none. The first version returned NA for those and only
# printed "cannot be checked", which the review gate correctly called fail-open:
# the one posture a guard must not take is "unverifiable, therefore allow".
#
# But refusing every untokened file would refuse exactly the good ones. The
# honest fix is to make the convention EXPLICIT rather than leave it implicit --
# an absent token resolves to DEFAULT_SIMS, which then goes through the same
# comparison as every measured value. If a harness's own default ever drifts
# from 20000 this constant is the single place that has to move, and the
# mismatch becomes a one-line change instead of a silent hole.
DEFAULT_SIMS <- 20000L
.sims_for <- function(paths) {
  bn <- basename(paths)
  m <- regmatches(bn, regexpr("-n[0-9]+-", bn))
  out <- rep(DEFAULT_SIMS, length(bn))
  hit <- regexpr("-n[0-9]+-", bn) > 0
  out[hit] <- as.integer(gsub("[^0-9]", "", m))
  stats::setNames(out, paths)
}
.ufiles <- unique(rows$file)
rows[, n_sims := .sims_for(.ufiles)[file]]
MIN_SIMS <- as.integer(Sys.getenv("AUSPOL_POOL_MIN_SIMS", "20000"))
.low <- unique(rows[is.finite(n_sims) & n_sims < MIN_SIMS, .(pair, n_sims)])
.unk <- unique(rows[!is.finite(n_sims), .(pair)])
if (nrow(.unk))
  stop(sprintf(paste0("refusing to pool: %d pair(s) have an n_sims that is not finite ",
                      "even after the DEFAULT_SIMS convention was applied, which means ",
                      "the filename is malformed rather than merely untokened: %s"),
               nrow(.unk), paste(.unk$pair, collapse = ", ")))
# No longer reachable by an untokened file -- those now resolve to DEFAULT_SIMS
# and are checked like everything else. It stays as a genuine fail-closed branch
# for a filename that parses to something non-finite, which should be impossible
# and therefore should stop rather than print.
if (nrow(.low)) {
  print(.low[order(n_sims)])
  stop(sprintf(paste0("refusing to pool: %d pair(s) come from runs below %d sims. ",
                      "pred_share is a simulation mean and fit_xgb_primary_v6.R trains on it. ",
                      "Re-run those pairs at AUSPOL_N_SIMS=%d, or set AUSPOL_POOL_MIN_SIMS ",
                      "lower if this file is only being used as a scoreboard."),
               nrow(.low), MIN_SIMS, MIN_SIMS))
}
cat(sprintf("PS1  n_sims per pair: min %d, max %d (floor %d)\n",
            min(rows$n_sims, na.rm = TRUE), max(rows$n_sims, na.rm = TRUE), MIN_SIMS))

tagof <- function(f) {
  m <- regmatches(basename(f), regexpr("-g[0-9a-f]+x?", basename(f)))
  if (length(m)) sub("^-g", "", m) else "(untagged)"
}
per <- rows[, .(n = .N, mtime = max(mtime), file = file[1]), by = pair]
per[, code := vapply(file, tagof, character(1))]
setorder(per, pair)
newest <- max(per$mtime)
per[, stale_h := round(as.numeric(difftime(newest, mtime, units = "hours")), 1)]

cat(sprintf("PS1  %d pairs, %d seat-class rows, newest file %s\n",
            nrow(per), nrow(rows), format(newest, "%Y-%m-%d %H:%M")))
print(per[, .(pair, n, code, stale_h)])

old <- per[stale_h > 24]
if (nrow(old)) {
  cat(sprintf("\nPS2! %d pair(s) come from a file more than a day older than the newest: %s\n",
              nrow(old), paste(sprintf("%s (%.0fh)", old$pair, old$stale_h), collapse = ", ")))
} else {
  cat("\nPS2  every pair comes from a file within a day of the newest.\n")
}

.known <- vapply(all_election_pairs(), `[[`, character(1), "election")
.missing <- setdiff(.known, unique(rows$pair))
if (length(.missing)) {
  cat(sprintf("PS2c! %d of %d known pair(s) have NO sharedetail at all yet -- run their harness once: %s\n",
              length(.missing), length(.known), paste(.missing, collapse = ", ")))
} else {
  cat(sprintf("PS2c  all %d known pairs have sharedetail on hand.\n", length(.known)))
}

fwrite(rows[, .(pair, seat, party, pred_share, actual_share)], file.path(OUT, "pooled-sharedetail.csv"))
cat(sprintf("\nPS5  wrote %s -- %d rows, %d pairs, %d unique seats\n",
            file.path(OUT, "pooled-sharedetail.csv"), nrow(rows), uniqueN(rows$pair), uniqueN(rows$seat)))

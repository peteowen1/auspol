# Pool every candidate-seat backtest into ONE table: seat log loss, Brier and
# accuracy per election and across all of them.
#
# WHY THIS EXISTS. The standing objective is pooled seat log loss and seat-share
# RMSE across every election we forecast, and until now answering that meant
# reading six harness logs and adding up by hand. Twice that produced a table
# built from files that were days old while the model had moved underneath.
#
# So this script does two things a hand-assembled table cannot:
#   1. It takes the NEWEST file for each pair, and
#   2. it PRINTS that file's modification time and code tag next to the numbers,
#      so a stale row is visible in the output instead of having to be
#      remembered. A row older than the newest row is flagged.
#
# It reads only what the harnesses already write. `prob` (fed/vic/wa) and `p`
# (nsw/sa/qld) are both the probability assigned to the party that ACTUALLY won,
# which is what log loss needs; `pred`/`pred_p` are the argmax call and its
# probability, which is what accuracy needs.
#
# Emits PB* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))  # for all_election_pairs()

# THE SAME FLOOR THE HARNESSES USE. Every harness clamps at 1e-6 before taking
# a log, and this script originally used 1e-9 -- which is not a rounding
# difference. A seat the model gives probability EXACTLY zero contributes
# -log(eps) on its own, so at 1e-9 it costs 20.7 and at 1e-6 it costs 13.8, and
# over 73 seats that single choice moved vic2014 from 0.4662 to 0.5608. The
# pooled table has to agree with the harness logs or the same model reports two
# different numbers depending on who asked.
EPS <- 1e-6

OUT <- "output"
files <- list.files(OUT, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
files <- grep("-totals|allprobs|-seatsd|-diag", files, value = TRUE, invert = TRUE)
if (!length(files)) stop("No backtest files in ", OUT)

# One row per (file, pair). A harness that scores several pairs writes them into
# one file with a `pair` column; the single-pair harnesses put the election in
# the filename instead.
#
# EVERY return(NULL) BELOW USED TO BE SILENT. A read failure, an empty file,
# a missing prob/pred/actual column or an unmatched filename all dropped that
# file with nothing printed -- so losing one of 22+ pairs (a truncated CSV, a
# harness that renamed a column, a partial write) shrank the pooled `n` with
# no trace, in the one script whose entire job is to be the trustworthy
# cross-election number. Each drop reason is now named (PB0!), and the
# completeness check below (PB2c) catches a pair missing ENTIRELY.
skipped_files <- data.table(file = character(0), mtime = as.POSIXct(character(0)))
rows <- rbindlist(lapply(files, function(f) {
  d <- tryCatch(fread(f, showProgress = FALSE), error = function(e) {
    cat(sprintf("PB0! %s: unreadable (%s) -- dropped\n", basename(f), conditionMessage(e)))
    NULL
  })
  if (is.null(d)) return(NULL)
  if (!nrow(d)) { cat(sprintf("PB0! %s: 0 rows -- dropped\n", basename(f))); return(NULL) }
  pcol <- if ("prob" %in% names(d)) "prob" else if ("p" %in% names(d)) "p" else NA_character_
  if (is.na(pcol) || !all(c("pred", "actual") %in% names(d))) {
    cat(sprintf("PB0! %s: missing prob/p/pred/actual column(s) -- dropped\n", basename(f)))
    return(NULL)
  }
  # A stage-1 run of scripts/rebuild_forecasts.sh (AUSPOL_XGB_PRIMARY=0, the
  # base_pred-only baseline the xgb layer is trained on) writes win files
  # that look exactly like scored ones and are the NEWEST on disk for the
  # hour until stage 6 finishes. Its sibling sharedetail carries the flag;
  # a win file whose sibling says xgb was off is not a forecast and never
  # scores here. (Added 2026-09-18 after the ledger silently mixed vintages.)
  suf <- regmatches(basename(f), regexpr("-a[0-9a-f]+-g[0-9a-f]+x?[.]csv$", basename(f)))
  if (length(suf)) {
    sib <- list.files(OUT, pattern = paste0("sharedetail.*", sub("[.]csv$", "", suf), "[.]csv$"), full.names = TRUE)
    if (!length(sib)) {
      # Every harness writes its sharedetail beside its win file; a win file
      # with no sibling is a run still in flight (or one killed before it
      # finished), and its flag is unknown. Unknown is not "scored".
      cat(sprintf("PB0  %s: no sibling sharedetail yet (run in flight or incomplete) -- skipped\n", basename(f)))
      skipped_files <<- rbind(skipped_files, data.table(file = f, mtime = file.mtime(f)))
      return(NULL)
    }
    s1 <- fread(sib[1], showProgress = FALSE, nrows = 1)
    if ("xgb_primary_on" %in% names(s1) && s1$xgb_primary_on[1] != 1L) {
      cat(sprintf("PB0  %s: sibling sharedetail has xgb_primary_on=%s (a base_pred-only stage-1 run) -- not a forecast, skipped\n",
                  basename(f), s1$xgb_primary_on[1]))
      skipped_files <<- rbind(skipped_files, data.table(file = f, mtime = file.mtime(f)))
      return(NULL)
    }
  }
  if (!"pair" %in% names(d)) {
    m <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
    if (!length(m)) {
      cat(sprintf("PB0! %s: no pair column and no election in the filename -- dropped\n", basename(f)))
      return(NULL)
    }
    d[, pair := m]
  }
  d[, .(file = f, mtime = file.mtime(f), pair = as.character(pair),
        p = pmin(pmax(get(pcol), EPS), 1), hit = as.integer(pred == actual))]
}))
if (!nrow(rows)) stop("No readable backtest files")

# COMPLETENESS, not just presence: a pair dropped entirely (not just a stale
# file) is invisible to every check below, which only look at what IS there.
.known <- vapply(all_election_pairs(), `[[`, character(1), "election")
.missing <- setdiff(.known, unique(rows$pair))
if (length(.missing)) {
  cat(sprintf("PB2c! %d of %d known pair(s) have NO backtest file at all: %s\n",
              length(.missing), length(.known), paste(.missing, collapse = ", ")))
} else {
  cat(sprintf("PB2c  all %d known pairs are present.\n", length(.known)))
}

# NEWEST FILE PER PAIR. Not the newest file overall and not all of them: two
# arms of the same pair must never be averaged together, which is what globbing
# everything would silently do.
pick <- rows[, .(mtime = max(mtime)), by = pair]
# A SKIPPED FILE NEWER THAN THE CHOSEN ONE IS SAID OUT LOUD. The sibling
# guard above drops in-flight or base_pred-only win files, and the newest
# SURVIVING file is then pooled -- which is right while a rebuild is
# running, and wrong if the newest run crashed between its win file and
# its sharedetail (review gate, 2026-09-18). Both look the same from here.
if (nrow(skipped_files)) {
  for (pr in pick$pair) {
    nf <- skipped_files[grepl(paste0("(^|[^a-z])", sub("[0-9]{4}$", "", pr), "|", pr), basename(skipped_files$file)) & skipped_files$mtime > pick[pair == pr]$mtime]
    if (nrow(nf)) cat(sprintf("PB2s! %s: pooled file is older than %d skipped file(s) (in flight, incomplete, or xgb off): %s\n",
                              pr, nrow(nf), paste(basename(nf$file), collapse = ", ")))
  }
}
rows <- merge(rows, pick, by = c("pair", "mtime"))
# A pair can still tie on mtime across two arms; keep one file per pair.
keep <- rows[, .(file = file[1]), by = pair]
rows <- merge(rows, keep, by = c("pair", "file"))

tagof <- function(f) {
  m <- regmatches(basename(f), regexpr("-g[0-9a-f]+x?", basename(f)))
  if (length(m)) sub("^-g", "", m) else "(untagged)"
}
per <- rows[, .(n = .N,
                accuracy = mean(hit),
                brier = mean((1 - p)^2),
                logloss = -mean(log(p)),
                mtime = max(mtime),
                file = file[1]), by = pair]
per[, `:=`(code = vapply(file, tagof, character(1)),
           region = sub("[0-9]{4}$", "", pair))]
setorder(per, region, pair)

newest <- max(per$mtime)
per[, stale_hours := as.numeric(difftime(newest, mtime, units = "hours"))]

cat(sprintf("\nPB1  %d pairs, %d seat-elections, newest file %s\n",
            nrow(per), sum(per$n), format(newest, "%Y-%m-%d %H:%M")))
print(per[, .(pair, n, accuracy = round(accuracy, 4), brier = round(brier, 4),
              logloss = round(logloss, 4), code,
              stale_h = round(stale_hours, 1))])

old <- per[stale_hours > 24]
if (nrow(old)) {
  cat(sprintf("\nPB2! %d pair(s) come from a file more than a day older than the newest: %s\n",
              nrow(old), paste(sprintf("%s (%.0fh)", old$pair, old$stale_hours), collapse = ", ")))
  cat("PB2! Those rows describe an older model. Re-run those harnesses before quoting this table.\n")
} else {
  cat("\nPB2  every pair comes from a file within a day of the newest.\n")
}

# SEATS AT THE FLOOR, reported beside the metric they dominate. A seat the model
# gives essentially zero contributes -log(EPS) on its own -- 13.8 at 1e-6 -- so a
# handful of them set pooled log loss, and a seat CROSSING the floor moves it by
# more than most real changes do. On 2026-09-07 the whole 0.0019 difference
# between two versions of this model was one seat, Barwon in nsw2019, going from
# 0.000050 to 0.000001. Without this line that reads as a model change.
FLOOR <- 1e-4
atf <- rows[p <= FLOOR]
cat(sprintf("\nPB2f %d of %d seat-elections give the actual winner <= %.0e; they carry %.1f%% of the total log loss\n",
            nrow(atf), nrow(rows), FLOOR,
            100 * sum(-log(atf$p)) / sum(-log(rows$p))))
if (nrow(atf))
  cat(sprintf("PB2f by pair: %s\n",
              paste(sprintf("%s=%d", names(table(atf$pair)), as.integer(table(atf$pair))),
                    collapse = " ")))
cat(sprintf("\nPB3  POOLED over %d seat-elections: accuracy %.4f | Brier %.4f | log loss %.4f\n",
            nrow(rows), mean(rows$hit), mean((1 - rows$p)^2), -mean(log(rows$p))))
# The same pooled log loss with those seats removed. Not a replacement -- they
# are real failures and hiding them would be worse -- but a change that moves
# THIS number is a change to the model, while one that moves only the number
# above may be a single seat crossing a constant.
cat(sprintf("PB3f POOLED excluding the %d floor seats: log loss %.4f over %d seat-elections\n",
            nrow(atf), -mean(log(rows[p > FLOOR]$p)), nrow(rows[p > FLOOR])))
cat(sprintf("PB3  unweighted mean over the %d pairs:      accuracy %.4f | Brier %.4f | log loss %.4f\n",
            nrow(per), mean(per$accuracy), mean(per$brier), mean(per$logloss)))

by_region <- rows[, .(pairs = uniqueN(pair), n = .N, accuracy = round(mean(hit), 4),
                      brier = round(mean((1 - p)^2), 4),
                      logloss = round(-mean(log(p)), 4)),
                  by = .(region = sub("[0-9]{4}$", "", pair))][order(region)]
cat("\nPB4  by jurisdiction\n"); print(by_region)

# `file` is written so downstream consumers (scripts/ledger_inputs.R) can
# take their sharedetail / allprobs / ourtcp inputs from the SAME harness run
# as this win file, by its arm+git hash suffix -- not "the newest file by
# name", which on 2026-09-18 mixed three vintages into one ledger page.
fwrite(per[, .(pair, n, accuracy, brier, logloss, code, mtime, file = basename(file))],
       file.path(OUT, "pooled-backtest.csv"))
cat(sprintf("\nPB5  wrote %s\n", file.path(OUT, "pooled-backtest.csv")))

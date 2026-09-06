# Pooling another jurisdiction's transfers into a backtest ---------------------
#
# Four backtest harnesses carried a byte-identical copy of the Queensland date
# filter. Adding Western Australia beside each would have made eight copies of
# the one piece of logic in this repo that must never be wrong: the rule that a
# backtest may only use data that existed before the election it predicts.
# CLAUDE.md records three leakage bugs, one of them introduced while fixing
# another, so there is now exactly one implementation and it is tested.

# Source metadata. The DATES ARE HAND-ENTERED, because neither commission
# publishes a machine-readable polling day with its results -- the ECQ archive
# gives an event name and the WAEC gives a year. `check_flow_source()` therefore
# verifies each date against the year in its own election key, which catches a
# transposed or mistyped year, the failure hand-entered tables actually have.
EXTERNAL_FLOWS <- list(
  qld = list(
    label = "Queensland", file = "ecq-qld-transfers.csv", code = "QF5",
    script = "scripts/fetch_preferences_qld.R",
    dates = c(qld2020 = "2020-10-31", qld2024 = "2024-10-26")),
  wa = list(
    label = "Western Australian", file = "waec-wa-transfers.csv", code = "WF7",
    script = "scripts/fetch_preferences_wa.R",
    # 2001 is absent deliberately: the fetcher excludes it on exhaustion
    # (2.27%), so it is not in the file and must not become admissible here.
    dates = c(wa1996 = "1996-12-14", wa2005 = "2005-02-26",
              wa2008 = "2008-09-06", wa2013 = "2013-03-09",
              wa2017 = "2017-03-11", wa2021 = "2021-03-13",
              wa2025 = "2025-03-08")),
  # SOUTH AUSTRALIA 2026 IS THE ONLY ELECTION WHERE ONE NATION REACHED THE
  # FINAL TWO AT SCALE, AND IT IS THE ONE THE MATRIX MOST NEEDS.
  #
  # Every other source here is a two-major contest. Built from federal 2025
  # alone, the matrix has NO conditional cell for `ALP|LNP+ONP`,
  # `LNP|ALP+ONP` or `GRN|LNP+ONP` -- the exact contests Victoria 2026 is
  # forecasting -- so those exclusions fall back to a pooled rate that sends
  # One Nation 2.9% of Labor preferences and 4.5% of Coalition preferences.
  # South Australia 2026 measured 22.1% and 54.0%. See
  # docs/reviews/flow-matrix-is-the-defect-2026-08-25.md.
  #
  # THE DATE GATE IS WHAT MAKES THIS SAFE. SA polled 2026-03-21, so it is
  # admissible for Victoria (2026-11-28) and NSW (2027) and is refused for
  # any backtest of SA 2026 itself -- which would be straight leakage, since
  # it would be predicting an election from its own distribution.
  sa = list(
    label = "South Australian", file = "ecsa-2026-sa-transfers.csv", code = "SF1",
    script = "scripts/fetch_preferences_sa.R",
    dates = c(sa2026 = "2026-03-21")))

#' Pool another jurisdiction's transfers into a backtest, filtered by date
#'
#' Admits only source elections held STRICTLY BEFORE the election being
#' predicted, so a backtest can never use a result that did not yet exist.
#'
#' @param tx `data.table` of transfers for the election being predicted from.
#' @param before Date, or a string `as.Date()` accepts, of the election being
#'   PREDICTED. Not the election `tx` came from.
#' @param source `"qld"` or `"wa"`.
#' @param not_after Optional extra ceiling on what may be admitted, applied on
#'   top of `before` by taking the earlier of the two. Its purpose is refusal W1
#'   of `docs/plans/prereg-wa-flows.md`: Western Australia's earliest election
#'   predates every backtest election, so unlike Queensland there is no set of
#'   elections that naturally admits nothing and can serve as a control. Setting
#'   this to 1990 admits nothing, and the run must then reproduce the baseline
#'   byte-for-byte -- which tests the filter rather than the data.
#' @param quiet Suppress the progress line. The line reports which elections
#'   were admitted; `CLAUDE.md` records an experiment whose edit never ran and
#'   whose byte-identical output read as "this input does not matter", so the
#'   default is to print what was applied.
#' @return `tx` with the admitted rows appended, or `tx` unchanged when no
#'   source election precedes `before`.
#' @export
pool_external_flows <- function(tx, before, source, not_after = NULL,
                               quiet = FALSE) {
  S <- EXTERNAL_FLOWS[[source]]
  if (is.null(S)) {
    stop("Unknown flow source '", source, "'. Known: ",
         paste(names(EXTERNAL_FLOWS), collapse = ", "))
  }
  f <- file.path(election_data_path(), S$file)
  if (!file.exists(f)) stop("Run ", S$script, " first; ", S$file, " is absent.")
  before <- as.Date(before)
  if (is.na(before)) stop("`before` is not a date.")
  if (!is.null(not_after) && nzchar(not_after)) {
    cap <- as.Date(not_after)
    if (is.na(cap)) stop("`not_after` is not a date.")
    before <- min(before, cap)
  }

  q <- data.table::fread(f, showProgress = FALSE)
  # A source election present in the file but missing from `dates` would be
  # SILENTLY DROPPED by the filter below, which is the shape of failure this
  # repo keeps meeting: a smaller pool that still produces a plausible number.
  extra <- setdiff(unique(q$election), names(S$dates))
  if (length(extra)) {
    stop(S$file, " holds election(s) with no date in EXTERNAL_FLOWS$", source,
         ": ", paste(extra, collapse = ", "),
         ". Undated they are dropped without a word. Add the polling day.")
  }
  d <- as.Date(S$dates)
  if (anyNA(d)) stop("Unparseable date in EXTERNAL_FLOWS$", source, ".")
  yr <- sub("^[a-z]+", "", names(S$dates))
  if (!all(yr == unname(format(d, "%Y")))) {
    bad <- names(S$dates)[yr != format(d, "%Y")]
    stop("Date does not match the year in its own key: ",
         paste(bad, collapse = ", "), ".")
  }

  # Intersected with what the file HOLDS, not just what the table dates. A
  # partial fetch is legitimate -- someone may have pulled only recent
  # elections -- and must return an empty admission, not an error.
  ok <- intersect(names(S$dates)[d < before], unique(q$election))
  if (!length(ok)) {
    if (!quiet) {
      cat(sprintf("%s  no %s election precedes %s; unchanged (control)\n",
                  S$code, S$label, as.character(before)))
    }
    return(tx)
  }
  q <- q[q$election %in% ok]
  # Belt and braces on the thing that matters: assert on the FILTERED result,
  # not on the filter, and require it to be non-empty. `all()` over an empty
  # set is TRUE, so a check that passes vacuously is worse than none.
  stopifnot(nrow(q) > 0L, all(as.Date(S$dates[q$election]) < before))
  if (!quiet) {
    cat(sprintf("%s  +%s for %s: %d exclusion events added\n",
                S$code, paste(ok, collapse = "+"), as.character(before),
                data.table::uniqueN(paste(q$election, q$seat, q$round))))
  }
  data.table::rbindlist(list(tx, q), fill = TRUE)
}

#' Pool whichever external flows the environment has switched on
#'
#' The harness-facing wrapper. Four backtest scripts each carried their own
#' copy of this gating, and a fifth jurisdiction would have doubled that to
#' eight; one of the four had drifted into defining a gate it never called
#' while still labelling its output as though it had.
#'
#' Both sources default OFF. `AUSPOL_QLD_CUTOFF` and `AUSPOL_WA_CUTOFF` cap
#' what each may admit, independently, for the control described in
#' `pool_external_flows()`. They are deliberately per-source: one shared cutoff
#' held every source out at once, so a control meant to isolate one of them
#' silently removed the other.
#'
#' @inheritParams pool_external_flows
#' @return `tx` with any switched-on, date-admissible transfers appended.
#' @export
pool_configured_flows <- function(tx, before, quiet = FALSE) {
  for (s in c("qld", "wa", "sa")) {
    on <- identical(Sys.getenv(sprintf("AUSPOL_%s_FLOWS", toupper(s)), "0"), "1")
    # PER SOURCE, not global. A single AUSPOL_FLOW_CUTOFF capped every source
    # at once, so the control arm meant to hold Western Australia out held
    # QUEENSLAND out as well and could never match a baseline that has it. The
    # control caught that on its first run, which is the whole reason a control
    # that tests the plumbing rather than the data is worth having.
    cap <- Sys.getenv(sprintf("AUSPOL_%s_CUTOFF", toupper(s)), "")
    if (on) {
      tx <- pool_external_flows(tx, before, s, not_after = cap, quiet = quiet)
      # The fallback arm fixed in advance by refusal W2 of
      # docs/plans/prereg-wa-flows.md: admit Western Australia's transfers
      # EXCEPT those where the excluded candidate was Coalition. WA runs
      # Liberal against National in rural seats, so its LNP-origin piles go to
      # another LNP candidate 55.8% of the time against 16.3% in the current
      # pool. Pre-specified so it could not be invented after the result.
      # The three-cornered-seat arm of docs/plans/prereg-wa-three-cornered.md.
      # Drops every exclusion in a seat where both a Liberal and a National
      # contested, which is where the LNP-by-construction artefact lives. The
      # marker is computed by the fetcher, not re-derived here, so one
      # definition governs both the printed counts and the filter.
      if (s == "wa" && identical(Sys.getenv("AUSPOL_WA_DROP_3C", "0"), "1")) {
        if (!"three_cornered" %in% names(tx)) {
          stop("AUSPOL_WA_DROP_3C is set but the transfer pool carries no ",
               "three_cornered marker. Re-run scripts/fetch_preferences_wa.R. ",
               "Without it this arm would silently be the unfiltered one.")
        }
        drop <- tx$three_cornered %in% TRUE
        if (!any(drop)) {
          stop("AUSPOL_WA_DROP_3C is set and nothing is marked three-cornered, ",
               "so this arm would be a byte-identical copy of the arm it is ",
               "meant to be compared against.")
        }
        if (!quiet) {
          cat(sprintf("WF9  three-cornered filter: %d rows dropped\n", sum(drop)))
        }
        tx <- tx[!drop]
      }
      if (s == "wa" && identical(Sys.getenv("AUSPOL_WA_DROP_LNP", "0"), "1")) {
        drop <- tx$election %in% names(EXTERNAL_FLOWS$wa$dates) & tx$from == "LNP"
        if (!quiet) {
          cat(sprintf("WF8  W2 fallback: %d WA LNP-origin rows dropped
", sum(drop)))
        }
        tx <- tx[!drop]
      }
    }
  }
  # The marker is Western Australia's alone, so it would arrive as NA on every
  # other source's rows and become a column the flow matrix never asked for.
  if ("three_cornered" %in% names(tx)) tx[, three_cornered := NULL]
  tx
}

#' Load voting-intention polls for a region
#'
#' Reads the anchor project's hand-maintained poll file
#' (`poll-data-<region>.csv`) into a tidy data.table. Party first-preference
#' columns like "ALP FP" become `ALP`; `#N/A` becomes `NA`. The published TPP
#' (`@TPP`, ALP share) is kept for display/validation only — forecasts derive
#' TPP from first preferences, matching the anchor methodology.
#'
#' @param region One of "fed", "nsw", "vic", "qld", "wa", "sa".
#' @return data.table with columns `date`, `firm`, `tpp_published`, one
#'   numeric column per party, and — only when the source file carries them —
#'   `gl_approve` and `gl_disapprove`. Sets attributes `parties` AND `region`;
#'   the latter is relied on by [cycle_polls()] and [unfold_others()].
#' @export
load_polls <- function(region = "fed") {
  path <- anchor_data_path(sprintf("poll-data-%s.csv", region))
  raw <- data.table::fread(path, na.strings = c("#N/A", "", "NA"))

  party_cols <- grep(" FP$", names(raw), value = TRUE)
  parties <- sub(" FP$", "", party_cols)
  out <- data.table::data.table(
    date = as.Date(raw$MidDate),
    firm = trimws(raw$Firm),
    tpp_published = suppressWarnings(as.numeric(raw$`@TPP`))
  )
  for (i in seq_along(party_cols)) {
    out[[parties[i]]] <- suppressWarnings(as.numeric(raw[[party_cols[i]]]))
  }
  if ("GLApp" %in% names(raw)) {
    out$gl_approve <- suppressWarnings(as.numeric(raw$GLApp))
    out$gl_disapprove <- suppressWarnings(as.numeric(raw$GLDis))
  }
  data.table::setattr(out, "parties", parties)
  data.table::setattr(out, "region", region)

  sanity_check_polls(out, region)
  out
}

#' @keywords internal
sanity_check_polls <- function(polls, region) {
  parties <- attr(polls, "parties")
  n <- nrow(polls)
  dr <- range(polls$date, na.rm = TRUE)
  stopifnot(n > 100, dr[1] >= as.Date("1940-01-01"), dr[2] <= Sys.Date() + 14)

  fp <- as.matrix(polls[, parties, with = FALSE])
  sums <- rowSums(fp, na.rm = TRUE)
  # Modern polls (reporting >= 3 parties) should sum near 100
  modern <- rowSums(!is.na(fp)) >= 3
  bad <- modern & (sums < 95 | sums > 105)
  message(sprintf(
    "polls[%s]: %d rows, %s to %s, %d firms; %d/%d modern rows with FP sums outside 95-105",
    region, n, dr[1], dr[2], data.table::uniqueN(polls$firm), sum(bad), sum(modern)
  ))
  if (sum(bad) > 0.02 * sum(modern)) {
    warning("More than 2% of modern polls have FP sums far from 100 - check parsing")
  }
  invisible(polls)
}

#' Load election cycle boundaries
#'
#' @return data.table: `year`, `region`, `start`, `end` (election day).
#' @export
load_election_cycles <- function() {
  # Read via read_anchor_csv(), not fread(). This is a hand-maintained file in
  # the same directory as preference-estimates.csv, which already carries
  # trailing "#comment" fields on some rows — and fread STOPS EARLY on the
  # first such row without erroring. That is the bug that once trained the
  # fundamentals model on 62% of its data. The file is uniform today; this
  # stops a future annotation silently truncating the cycle table.
  raw <- read_anchor_csv("election-cycles.csv",
                         c("year", "region", "start", "end"))
  raw[, `:=`(year = as.integer(year), region = as.character(region),
             start = as.Date(start), end = as.Date(end))]
  out <- raw[!is.na(year) & !is.na(start) & !is.na(end)]
  if (nrow(out) < 60) {
    warning(sprintf("election-cycles.csv parsed only %d rows - expected ~77",
                    nrow(out)))
  }
  out[]
}

#' Load prior (previous-election) results
#'
#' One row per (cycle year, region, party): the party's vote share at the
#' elections preceding that cycle, most recent first.
#'
#' @return data.table: `year`, `region`, `party`, `prev1`..`prevN`.
#' @export
load_prior_results <- function() {
  lines <- readLines(anchor_data_path("prior-results.csv"), warn = FALSE)
  parts <- strsplit(lines, ",")
  parts <- parts[vapply(parts, length, 1L) >= 4]
  n_prev <- max(vapply(parts, length, 1L)) - 3L
  rows <- lapply(parts, function(p) {
    vals <- suppressWarnings(as.numeric(p[4:length(p)]))
    c(p[1], p[2], sub(" FP$", "", p[3]), vals, rep(NA_real_, n_prev - length(vals)))
  })
  dt <- data.table::as.data.table(do.call(rbind, rows))
  data.table::setnames(dt, c("year", "region", "party", paste0("prev", seq_len(n_prev))))
  dt[, year := as.integer(year)]
  for (col in paste0("prev", seq_len(n_prev))) {
    dt[, (col) := suppressWarnings(as.numeric(get(col)))]
  }
  dt[]
}

#' Load preference flow estimates (share of each party's preferences to ALP)
#'
#' A second numeric column, where present, is the exhaust rate (share of the
#' party's ballots that express no major-party preference) - nonzero under
#' optional preferential voting (NSW, and Qld before 2016).
#'
#' @return data.table: `year`, `region`, `party`, `flow_alp`, `exhaust`
#'   (percent).
#' @export
load_preference_flows <- function() {
  lines <- readLines(anchor_data_path("preference-estimates.csv"), warn = FALSE)
  parts <- strsplit(lines, ",")
  parts <- parts[vapply(parts, length, 1L) >= 4]
  dt <- data.table::rbindlist(lapply(parts, function(p) {
    exh <- if (length(p) >= 5) suppressWarnings(as.numeric(p[5])) else NA_real_
    data.table::data.table(
      year = as.integer(p[1]),
      region = p[2],
      party = sub(" FP$", "", p[3]),
      flow_alp = suppressWarnings(as.numeric(p[4])),
      exhaust = data.table::fifelse(is.na(exh), 0, exh)
    )
  }))
  dt[!is.na(flow_alp)]
}

#' Preference flows for a cycle, carrying forward when a year is missing
#'
#' The anchor's flow file is hand-maintained and incomplete: Victoria, for
#' instance, has estimates only for 2018, nothing for 2022 or 2026. Selecting
#' on year alone returns zero rows, and [derive_tpp()] then falls back to a
#' 50-50 split for every party — badly wrong for the Greens, who send about
#' 82% of their preferences to Labor. A silent 50-50 would move Victorian TPP
#' by several points with nothing failing.
#'
#' This carries each party's most recent estimate for that region forward to
#' the requested year, and says so. It never reaches across regions:
#' preference behaviour differs by state, and optional preferential voting
#' makes exhaust rates region-specific.
#'
#' @param flows From [load_preference_flows()].
#' @param year,region The cycle wanted.
#' @param quiet Suppress the carry-forward message.
#' @return data.table of the same shape, with a `flow_year` column recording
#'   which election each estimate actually came from.
#' @export
flows_for <- function(flows, year, region, quiet = FALSE) {
  # NB: masks and orderings are computed OUTSIDE the data.table [ ] so that
  # the bare argument names `year` and `region` bind to this function's
  # parameters rather than to the same-named columns. Written the obvious way,
  # `flows[flows$region == region & flows$year <= year, ]` becomes
  # `region == region` — always TRUE — and silently returns every row for
  # every region, which handed Victoria the federal 2028 flows (Greens 88.19
  # instead of 81.94) and pushed its 2022 validation TPP 3 points high.
  keep <- flows$region == region & flows$year <= year
  avail <- flows[which(keep), ]
  if (!nrow(avail)) {
    stop("No preference flows at all for region '", region, "' up to ", year)
  }
  # Most recent estimate per party, at or before the requested year
  ord <- order(avail$party, -avail$year)
  avail <- avail[ord, ]
  out <- avail[which(!duplicated(avail$party)), ]
  data.table::setnames(out, "year", "flow_year")
  out$year <- year
  carried <- out[which(out$flow_year != year), ]
  if (nrow(carried) && !quiet) {
    message(sprintf(
      "  preference flows for %s %d: carried forward %s",
      region, year,
      paste(sprintf("%s (from %d)", carried$party, carried$flow_year),
            collapse = ", ")))
  }
  out[]
}

#' Restrict polls to one election cycle
#'
#' @param polls From [load_polls()].
#' @param year Election year identifying the cycle.
#' @param cycles From [load_election_cycles()]; loaded if missing.
#' @return Filtered polls with attributes `cycle_year`, `cycle_start`,
#'   `cycle_end` set.
#' @export
cycle_polls <- function(polls, year, cycles = NULL) {
  if (is.null(cycles)) cycles <- load_election_cycles()
  reg <- attr(polls, "region")
  # NB: masks computed OUTSIDE the data.table [ ] so bare names like `year`
  # bind to function arguments, not same-named columns.
  keep <- (cycles$year == year) & (cycles$region == reg)
  cyc <- cycles[which(keep), ]
  if (nrow(cyc) != 1) stop("No unique cycle for ", year, " ", reg)
  in_cycle <- polls$date >= cyc$start & polls$date <= cyc$end
  out <- polls[which(in_cycle), ]
  for (a in c("parties", "region")) data.table::setattr(out, a, attr(polls, a))
  data.table::setattr(out, "cycle_year", year)
  data.table::setattr(out, "cycle_start", cyc$start)
  data.table::setattr(out, "cycle_end", cyc$end)
  out
}

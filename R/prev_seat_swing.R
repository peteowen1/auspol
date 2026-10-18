# Previous-election seat swing, derived from our own results ----------------
#
# WHY THIS EXISTS (2026-10-16). The backtest harnesses fed `seat_swing_spread()`
# the anchor's seat file for the target election, or for a LATER election
# where none exists. That file's `fPreviousTppSwing` is the seat-level swing at
# the election BEFORE the one the file is for, so for the fallbacks (nsw2011,
# nsw2015, sa2010/14/18, qld2012-2020, fed2010-16) it was a swing from after
# the target, and for vic2022 / sa2018 it was the target's own result. The
# spread of those swings sets `seat_sd`, so the leak reached every seat.
#
# The fix: for target election Y with previous election P, use the seat-level
# two-party swing AT election P (P against the election before P). That is
# knowable before Y, and comes from results we hold, not from a file authored
# for some other election.

#' Seat-level two-party swing at one past election, from archived results
#'
#' Reads the parsed AE archive of per-seat results
#' (`external/elections/archive/{year}{region}-tcp.csv`, written by
#' `scripts/build_archived_results.R`). Its `swing` column is the change in each
#' candidate's two-candidate-preferred share since the election before, already
#' put onto the boundaries of the election it describes.
#'
#' Only contests between ALP and the Coalition (classes `ALP` and `LNP`) are
#' kept. A two-candidate swing in an ALP-versus-independent or Greens seat is
#' not a two-party swing and would put a different quantity into the spread.
#' Seats whose swing is missing (no previous result on the same footing) are
#' dropped, not zero-filled. The counts at each stage are returned in
#' `attr(, "coverage")` so a thin election is visible.
#'
#' Region labels come from the anchor's seat files (a label, never an
#' outcome): for each seat, the file whose year is nearest `label_year`
#' (default `election`; ties go to the earlier file). Seats with no label in
#' any file keep `seat_region = NA`; [derived_seat_spread()] drops them.
#'
#' @param region One of `"fed"`, `"nsw"`, `"vic"`, `"qld"`, `"sa"`, `"wa"`.
#' @param election Year of the election whose seat-level swing is wanted -- the
#'   PREVIOUS election of the pair being backtested.
#' @param label_year Year to take region labels nearest to. Default `election`.
#' @param archive_dir Directory holding the archive files.
#' @return data.table: `seat`, `seat_region`, `prev_swing` (ALP's swing, points),
#'   with `attr(, "coverage")`: a named integer vector `n_seats`, `n_alp_lnp`,
#'   `n_swing`, `n_labelled`.
#' @export
prev_seat_swing <- function(region, election, label_year = election,
                            archive_dir = election_data_path("archive")) {
  stopifnot(length(region) == 1L, length(election) == 1L)
  path <- file.path(archive_dir, sprintf("%d%s-tcp.csv", as.integer(election), region))
  if (!file.exists(path)) {
    stop("No archived seat results at ", path, " -- cannot derive the ", region,
         " ", election, " seat swing.")
  }
  a <- data.table::fread(path)
  need <- c("seat", "party", "swing")
  if (!all(need %in% names(a))) {
    stop(path, " lacks column(s): ", paste(setdiff(need, names(a)), collapse = ", "))
  }
  n_seats <- data.table::uniqueN(a$seat)
  # One row per seat: ALP's row, in a seat whose two finalists are exactly
  # ALP and LNP. Counting rows by party (not by position) so a seat listing
  # LNP twice, or one finalist, cannot slip through.
  cnt <- a[, list(n = .N, has_alp = sum(party == "ALP"), has_lnp = sum(party == "LNP")),
           by = "seat"]
  ok <- cnt$seat[cnt$n == 2L & cnt$has_alp == 1L & cnt$has_lnp == 1L]
  alp <- a[a$seat %in% ok & a$party == "ALP", c("seat", "swing"), with = FALSE]
  data.table::setnames(alp, "swing", "prev_swing")
  alp$prev_swing <- suppressWarnings(as.numeric(alp$prev_swing))
  n_alp_lnp <- nrow(alp)
  alp <- alp[is.finite(alp$prev_swing), ]
  lab <- seat_region_labels(region, label_year)
  alp$seat_region <- lab$seat_region[match(.seat_key(alp$seat), lab$skey)]
  data.table::setcolorder(alp, c("seat", "seat_region", "prev_swing"))
  attr(alp, "coverage") <- c(n_seats = n_seats, n_alp_lnp = n_alp_lnp,
                             n_swing = nrow(alp),
                             n_labelled = sum(!is.na(alp$seat_region)))
  alp
}

#' Within-region spread of the derived previous seat swing
#'
#' The derived counterpart of `seat_swing_spread(load_seats(Y, region), s)` for
#' the harnesses: same function underneath, but the per-seat swings come from
#' [prev_seat_swing()] at the PREVIOUS election, so nothing from the target
#' election or later is read. Seats without a region label are dropped (they
#' cannot enter a within-region deviation) and counted.
#'
#' @param region,election,label_year,archive_dir See [prev_seat_swing()].
#' @param statewide_swing Passed to [seat_swing_spread()]; `sd_within` does not
#'   depend on it (the constant cancels inside regions), so `0` is fine.
#' @return The list from [seat_swing_spread()] plus `src` (a one-line source
#'   description), `n_swing` (ALP-vs-Coalition seats with a swing) and
#'   `n_unlabelled` (dropped for lack of a region label).
#' @export
derived_seat_spread <- function(region, election, statewide_swing = 0,
                                label_year = election,
                                archive_dir = election_data_path("archive")) {
  ps <- prev_seat_swing(region, election, label_year, archive_dir)
  cov <- attr(ps, "coverage")
  lab <- ps[!is.na(ps$seat_region), ]
  if (nrow(lab) < 10L) {
    stop("Only ", nrow(lab), " labelled ALP-v-Coalition seats with a swing for ",
         region, " ", election, "; too few to measure a seat spread.")
  }
  sp <- seat_swing_spread(lab, statewide_swing)
  sp$src <- sprintf("archive %d%s-tcp swing", as.integer(election), region)
  sp$n_swing <- unname(cov[["n_swing"]])
  sp$n_unlabelled <- sp$n_swing - nrow(lab)
  sp
}

#' Which source the seat spread comes from (AUSPOL_SEAT_SPREAD_SRC)
#'
#' `"derived"` (published) measures the spread from our own results at the
#' previous election, [derived_seat_spread()]. `"anchor"` is the old behaviour,
#' kept only to reproduce earlier numbers: it reads the anchor's seat file for
#' the target election or a later one and leaks. See `R/prev_seat_swing.R`.
#' @return `"derived"` or `"anchor"`; stops on anything else.
#' @export
seat_spread_src <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_SPREAD_SRC", "derived")
  if (!v %in% c("derived", "anchor")) {
    stop("AUSPOL_SEAT_SPREAD_SRC must be \"derived\" or \"anchor\"; got \"", v, "\"")
  }
  v
}

#' Region labels for seats, from the anchor's seat files
#'
#' @param region Region code.
#' @param near_year Year to take each seat's label nearest to.
#' @return data.table: `skey` (normalised seat name), `seat_region`.
#' @keywords internal
seat_region_labels <- function(region, near_year) {
  root <- getOption("auspol.anchor_dir",
                    file.path(pkg_root(), "external", "aus-polling-analyser"))
  files <- list.files(file.path(root, "analysis", "seats"),
                      pattern = sprintf("^[0-9]{4}%s\\.txt$", region))
  years <- as.integer(substr(files, 1, 4))
  if (!length(years)) {
    return(data.table::data.table(skey = character(), seat_region = character()))
  }
  # Nearest year first; on a tie the earlier file.
  years <- years[order(abs(years - near_year), years)]
  out <- lapply(years, function(y) {
    s <- load_seats(y, region)
    data.table::data.table(skey = .seat_key(s$seat), seat_region = s$seat_region)
  })
  out <- data.table::rbindlist(out)
  out <- out[!is.na(out$seat_region), ]
  out[!duplicated(out$skey), ]
}

# Normalise a seat name for matching across sources.
.seat_key <- function(x) gsub("[^a-z0-9]", "", tolower(x))

#' Seat spread for one backtest pair, from the source AUSPOL_SEAT_SPREAD_SRC names
#'
#' The one call the nsw / sa / qld / vic harnesses make. `"derived"` (the
#' published value) uses [derived_seat_spread()] at the pair's PREVIOUS
#' election `from`. `"anchor"` reproduces the old behaviour, which LEAKS: the
#' anchor seat file for `anchor_year` (default the target `to`), else for
#' `anchor_fallback_year`, a LATER election. Prints one `SSP1` line saying
#' which source, how many seats, and the resulting `sd_within`, so a pair's
#' source is never silent.
#'
#' @param region Region code.
#' @param from,to Previous and target election years of the pair.
#' @param statewide_swing Statewide ALP swing (cancels inside `sd_within`).
#' @param anchor_year Seat file year tried first in `"anchor"` mode.
#' @param anchor_fallback_year Seat file year used when that file is missing
#'   (`"anchor"` mode only); `NA` for none.
#' @param src Source; default [seat_spread_src()].
#' @return The list from [seat_swing_spread()] (`sd_within`, `sd_between`, ...).
#' @export
harness_seat_spread <- function(region, from, to, statewide_swing,
                                anchor_year = to, anchor_fallback_year = NA_integer_,
                                src = seat_spread_src()) {
  if (identical(src, "derived")) {
    sp <- derived_seat_spread(region, from, statewide_swing, label_year = to)
    cat(sprintf("SSP1  %s%d seat spread: derived from %s | %d ALP-v-Coalition seats with a swing, %d unlabelled dropped | within %.2f, between %.2f\n",
                region, to, sp$src, sp$n_swing, sp$n_unlabelled, sp$sd_within, sp$sd_between))
    return(sp)
  }
  used <- anchor_year
  s <- tryCatch(data.table::as.data.table(load_seats(anchor_year, region)), error = function(e) NULL)
  if (is.null(s) && !is.na(anchor_fallback_year)) {
    used <- anchor_fallback_year
    s <- tryCatch(data.table::as.data.table(load_seats(used, region)), error = function(e) NULL)
  }
  if (is.null(s)) stop("SSP1! anchor mode: no ", region, " seat file for ", anchor_year,
                       if (!is.na(anchor_fallback_year)) paste0(" or ", anchor_fallback_year), ".")
  sp <- seat_swing_spread(s, statewide_swing)
  note <- if (used > to) "  [LEAK: a later election's file]"
          else if (used == to) "  [own-election file: swing at the previous election]" else ""
  cat(sprintf("SSP1  %s%d seat spread: ANCHOR %d%s.txt%s | %d seats | within %.2f, between %.2f\n",
              region, to, used, region, note, sp$n, sp$sd_within, sp$sd_between))
  sp
}

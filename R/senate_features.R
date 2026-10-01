#' Federal Senate share of each party class, as xgb features
#'
#' For each (pair, seat, party): `senate_pct`, the party class's share of the
#' Senate first preferences cast in the seat, and `senate_dev`, that share
#' minus the class's mean over the pair's seats (the geography, net of the
#' level). The Senate vote is a party's base with no local candidate, so it
#' carries what personal votes hide. First test against v56's error: no
#' signal for Labor/Coalition, clear for the minor right (t 3.1), weak for the
#' Greens (t 1.9). plans/prereg-xgb-senate-2026-10-01.md.
#'
#' Time-forward by construction: a STATE pair uses the federal election before
#' it, through the booth -> district maps (`output/senate-by-district-class.csv`,
#' scripts/build_senate_by_district.R); a FEDERAL pair uses the PREVIOUS federal
#' election's Senate vote in the division of the same name
#' (`output/senate-by-division-class.csv`). `NA` where no Senate booth data
#' exists (wa2001, wa2005, wa2013, fed2007; renamed divisions).
#'
#' @param keys data.table with `pair`, `seat`, `party`.
#' @param district,division The two tables; read from `output/` when `NULL`.
#' @return `keys` with `senate_pct` and `senate_dev` added (row order kept).
#' @export
senate_features <- function(keys, district = NULL, division = NULL) {
  out <- data.table::copy(data.table::as.data.table(keys))
  out[, `.ord` := .I]
  if (is.null(district)) {
    f <- out_path("senate-by-district-class.csv")
    district <- if (file.exists(f)) data.table::fread(f, showProgress = FALSE) else NULL
    # The daily run has no AEC files: the promote step ships Victoria's slice.
    fv <- out_path("senate-vic2026.csv")
    if (is.null(district) && file.exists(fv)) district <- data.table::fread(fv, showProgress = FALSE)
  }
  if (is.null(division)) {
    f <- out_path("senate-by-division-class.csv")
    division <- if (file.exists(f)) data.table::fread(f, showProgress = FALSE) else NULL
  }
  if (is.null(district) && is.null(division)) {
    cat("SEN0! no Senate tables in output/ -- senate_pct/senate_dev are all NA (run scripts/build_senate_by_district.R)\n")
    out[, `:=`(senate_pct = NA_real_, senate_dev = NA_real_)]
    out[, `.ord` := NULL]
    return(out[])
  }
  nm <- function(z) normalise_seat(z)
  tabs <- list()
  if (!is.null(district)) {
    dist_tab <- district
    tabs[[1]] <- data.table::data.table(pair = paste0(dist_tab$region, dist_tab$cycle), k = nm(dist_tab$district),
                                        party = dist_tab$cls, senate_pct = dist_tab$senate_pct)
  }
  if (!is.null(division)) {
    # div_tab/dist_tab, NOT the argument names: both tables have a column named
    # like the argument, and a bare `division` inside `[` binds to the column.
    div_tab <- division
    feds <- sort(unique(div_tab$fed))
    nxt <- stats::setNames(c(feds[-1], NA), feds)     # Senate at fed F feeds the pair at the NEXT federal election
    keep <- !is.na(nxt[as.character(div_tab$fed)])
    d <- div_tab[keep]
    d$pair <- paste0("fed", nxt[as.character(d$fed)])
    tabs[[2]] <- data.table::data.table(pair = d$pair, k = nm(d$division), party = d$cls, senate_pct = d$senate_pct)
  }
  S <- unique(data.table::rbindlist(tabs), by = c("pair", "k", "party"))
  out[, k := nm(seat)]
  out <- merge(out, S, by = c("pair", "k", "party"), all.x = TRUE, sort = FALSE)
  # the class's mean over the pair's seats that have a Senate share for it
  out[, senate_dev := senate_pct - mean(senate_pct, na.rm = TRUE), by = c("pair", "party")]
  out[!is.finite(senate_dev), senate_dev := NA_real_]
  data.table::setorder(out, `.ord`)
  out[, c("k", ".ord") := NULL]
  out[]
}

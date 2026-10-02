#' Climate 200 / Voices endorsement of a seat's candidates, as xgb features
#'
#' For each (pair, seat, party): `c200`, whether a candidate of that class in
#' that seat had Climate 200 support announced before polling day, and
#' `voices`, whether a local "Voices of" group endorsed them. Built by
#' scripts/build_endorsement_features.py from sourced lists
#' (external/reference/climate200/endorsements.csv). Zero means not endorsed --
#' including before Climate 200 existed (2019), which is a true zero.
#'
#' Why: community independents "from nowhere" are the largest block of primary
#' misses (Mackellar, Goldstein, Kooyong, Curtin, North Sydney, Wakehurst: ours
#' 9-12%, AE Forecasts 20-28%, actual 25-40%). plans/prereg-endorsement-2026-10-02.md.
#'
#' @param keys data.table with `pair`, `seat`, `party`.
#' @param tab The feature table; read from `output/` when `NULL`.
#' @return `keys` with `c200` and `voices` added (row order kept).
#' @export
endorsement_features <- function(keys, tab = NULL) {
  out <- data.table::copy(data.table::as.data.table(keys))
  out[, `.ord` := .I]
  if (is.null(tab)) {
    f <- out_path("endorsement-features.csv")
    if (!file.exists(f)) {
      cat("EN0! output/endorsement-features.csv missing -- endorsement features are all 0 (run scripts/build_endorsement_features.py)\n")
      out[, `:=`(c200 = 0, voices = 0)]
      out[, `.ord` := NULL]
      return(out[])
    }
    tab <- data.table::fread(f, showProgress = FALSE)
  }
  # en_tab, not tab: keep argument names out of `[` (CLAUDE.md, NSE)
  en_tab <- data.table::as.data.table(tab)
  e <- unique(en_tab[, list(pair, k = normalise_seat(seat), party,
                            c200 = as.numeric(c200), voices = as.numeric(voices))],
              by = c("pair", "k", "party"))
  out[, k := normalise_seat(seat)]
  out <- merge(out, e, by = c("pair", "k", "party"), all.x = TRUE, sort = FALSE)
  out[is.na(c200), c200 := 0]
  out[is.na(voices), voices := 0]
  data.table::setorder(out, `.ord`)
  out[, c("k", ".ord") := NULL]
  out[]
}

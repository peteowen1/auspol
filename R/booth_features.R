#' Booth-pattern features from the previous election, as xgb inputs
#'
#' For each (pair, seat, party): `booth_spread`, how much the class's share
#' varied across the seat's polling places at the PREVIOUS election, and
#' `early_gap`, its share among early, pre-poll and postal votes minus its share
#' on the day. Built by scripts/build_booth_features.py for every state and
#' federal pair with prior booth data; NA where there is none (federal 2007, a
#' state's first election in the series, a district renamed since).
#'
#' Why: tested against v58's remaining error with election-clustered errors
#' (2026-10-02): One Nation's early-vote gap t -5.4 (3 of 4 elections), Labor's
#' spread t -1.9 (negative in 11 of 12 elections), the Greens' early gap t +2.1.
#' plans/prereg-booth-features-2026-10-02.md.
#'
#' @param keys data.table with `pair`, `seat`, `party`.
#' @param tab The feature table; read from `output/` when `NULL`.
#' @return `keys` with `booth_spread` and `early_gap` added (row order kept).
#' @export
booth_features <- function(keys, tab = NULL) {
  out <- data.table::copy(data.table::as.data.table(keys))
  out[, `.ord` := .I]
  if (is.null(tab)) {
    f <- out_path("booth-features.csv")
    if (!file.exists(f) && file.exists(out_path("booth-features-vic2026.csv"))) f <- out_path("booth-features-vic2026.csv")
    if (!file.exists(f)) {
      cat("BTF0! output/booth-features.csv missing -- booth features are all NA (run scripts/build_booth_features.py)\n")
      out[, `:=`(booth_spread = NA_real_, early_gap = NA_real_)]
      out[, `.ord` := NULL]
      return(out[])
    }
    tab <- data.table::fread(f, showProgress = FALSE)
  }
  # bt_tab, not tab: keep argument names out of `[` (CLAUDE.md, NSE)
  bt_tab <- data.table::as.data.table(tab)
  b <- unique(bt_tab[, list(pair, k = normalise_seat(seat), party,
                            booth_spread = as.numeric(booth_spread), early_gap = as.numeric(early_gap))],
              by = c("pair", "k", "party"))
  out[, k := normalise_seat(seat)]
  out <- merge(out, b, by = c("pair", "k", "party"), all.x = TRUE, sort = FALSE)
  data.table::setorder(out, `.ord`)
  out[, c("k", ".ord") := NULL]
  out[]
}

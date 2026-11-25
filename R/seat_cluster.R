# SEAT CLUSTER FACTOR (AUSPOL_SEAT_CLUSTER_COR; docs/plans/prereg-seat-cluster-cor-2026-11-25.md).
#
# Until this, the only thing tying one seat's draw to another was the statewide draw: given
# it, every seat was an independent coin. Seats in the same region, or of the same kind, miss
# together (One Nation surging across regional seats at once), so the published seat RANGES
# were too narrow. This splits each cell's noise into a part common to the seat's cluster and
# a part of its own, holding the cell's total variance fixed:
#
#   noise[i, k] = sd_cell[i, k] * (sqrt(rho_k) * z[cluster(i), k] + sqrt(1 - rho_k) * z_own[i, k])
#
# so no seat's win probability moves (up to the shape of the error quantiles; see the prereg),
# and only the JOINT law changes: P(majority), P(hung), seat-count ranges.
#
# Clusters, per jurisdiction (seat_cluster_map()):
#   vic  the 8 Legislative Council regions (external/reference/vec/vic-district-regions.csv,
#        2022 boundaries; districts not in the file, i.e. renamed ones in earlier pairs, get none)
#   nsw  the NSW regions file (external/reference/nsw/nsw-district-regions.csv), same rule
#   fed  the state or territory of the division (inst/extdata/fed-division-state.csv)
#   qld, sa, wa, nt  no region file on disk: k-means on the seat's PROJECTED primary shares
#        (the model's own pre-election input, so no leak), k = round(seats / 11), about the
#        size of a Victorian region. A "seat type" grouping, not a geographic one.
#
# rho_k is the intraclass correlation of standardised seat misses within clusters, measured
# per election on the published-path predictions (scripts/fit_seat_cluster_icc.R ->
# inst/extdata/seat-cluster-icc.csv), pooled over elections dated BEFORE the target only,
# separately for federal and state elections, and partially pooled across classes toward the
# all-class mean (seat_cluster_rho()).

#   "type" (plans/prereg-seat-type-cor-2026-11-25.md) clusters EVERY jurisdiction by seat type:
#        k-means on z-scored projected shares plus the seven census features of the latest
#        census before polling day (seat_cluster_type_map()); rho from the one-way type ICC.
#   "both" two independent factors per cell, region (as "1") and type, rho from a crossed
#        random-effects fit (inst/extdata/seat-cluster-icc-type.csv); jurisdictions with no
#        region file get the type factor alone, as under "type".

#' Seat cluster factor mode (`AUSPOL_SEAT_CLUSTER_COR`: "0", "1", "type" or "both")
#' @keywords internal
seat_cluster_mode <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_CLUSTER_COR", "0")
  if (!v %in% c("0", "1", "type", "both"))
    stop("AUSPOL_SEAT_CLUSTER_COR must be \"0\", \"1\", \"type\" or \"both\"; got \"", v, "\"", call. = FALSE)
  v
}

#' Is the seat cluster factor on? (`AUSPOL_SEAT_CLUSTER_COR` anything but "0")
#' @keywords internal
seat_cluster_on <- function() !identical(seat_cluster_mode(), "0")

SCT_CENSUS_COLS <- c("yr12_pct", "born_aus_pct", "indig_pct", "over55_pct", "under35_pct",
                     "lang_other_pct", "edu_25plus_pct")

#' Seat-TYPE cluster id per seat for one election (AUSPOL_SEAT_CLUSTER_COR "type" / "both")
#'
#' k-means (k = round(seats / 11), at least 2) on a per-seat feature vector, every column
#' z-scored across the election's seats: the projected shares, and the census features of the
#' latest census before polling day. A seat without census values gets 0 (the mean) on those
#' columns. Nothing from the election's results is used.
#' @param election Label such as `"vic2022"`.
#' @param seats Seat names, in the order of `shares`.
#' @param shares Projected shares (seats x classes).
#' @param census Data frame with `pair`, `seat` and the census columns, or `NULL` to read
#'   `<root>/output/census-features-vintage.csv`; `FALSE` = shares only.
#' @param root Directory holding `output/`.
#' @param quiet Suppress the SCT1 line.
#' @return Integer vector with attributes `scheme`, `labels`, `n_census`.
#' @keywords internal
seat_cluster_type_map <- function(election, seats, shares, census = NULL, root = ".", quiet = FALSE) {
  norm <- function(x) tolower(gsub("[^a-z]", "", tolower(x)))
  x <- as.matrix(shares); storage.mode(x) <- "double"
  x[!is.finite(x)] <- 0
  if (nrow(x) != length(seats)) stop("seat_cluster_type_map: shares has ", nrow(x), " rows for ", length(seats), " seats", call. = FALSE)
  n_cen <- 0L
  if (!isFALSE(census)) {
    if (is.null(census)) {
      f <- file.path(root, "output", "census-features-vintage.csv")
      if (!file.exists(f)) stop("seat_cluster_type_map: ", f, " is missing", call. = FALSE)
      census <- utils::read.csv(f, stringsAsFactors = FALSE)
    }
    miss <- setdiff(c("pair", "seat", SCT_CENSUS_COLS), names(census))
    if (length(miss)) stop("seat_cluster_type_map: census table lacks ", paste(miss, collapse = ", "), call. = FALSE)
    ce <- census[census$pair == election, , drop = FALSE]
    if (anyDuplicated(norm(ce$seat))) stop("seat_cluster_type_map: duplicate census seats in ", election, call. = FALSE)
    cm <- as.matrix(ce[match(norm(seats), norm(ce$seat)), SCT_CENSUS_COLS, drop = FALSE])
    storage.mode(cm) <- "double"
    n_cen <- sum(rowSums(is.finite(cm)) == length(SCT_CENSUS_COLS))
    x <- cbind(x, cm)
  }
  # z-score each column; a constant or all-missing column carries nothing and is dropped
  z <- apply(x, 2, function(v) {
    s <- stats::sd(v, na.rm = TRUE); m <- mean(v, na.rm = TRUE)
    if (!is.finite(s) || s == 0) return(rep(NA_real_, length(v)))
    out <- (v - m) / s; out[!is.finite(out)] <- 0; out
  })
  z <- z[, colSums(is.finite(z)) > 0, drop = FALSE]
  k <- max(2L, as.integer(round(nrow(z) / 11)))
  .had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  .old <- if (.had) get(".Random.seed", envir = globalenv(), inherits = FALSE) else NULL
  set.seed(20261126L)
  km <- stats::kmeans(z, centers = k, nstart = 20, iter.max = 100)
  if (.had) assign(".Random.seed", .old, envir = globalenv()) else rm(".Random.seed", envir = globalenv())
  lab <- paste0("type", km$cluster)
  labels <- sort(unique(lab)); id <- match(lab, labels)
  scheme <- sprintf("type k-means on shares%s (k = %d)", if (isFALSE(census)) "" else " + census", k)
  if (!quiet) cat(sprintf("SCT1 %s: %s; census features for %d of %d seats; cluster sizes %s\n", election, scheme,
                          n_cen, length(seats), paste(sort(tabulate(id), decreasing = TRUE), collapse = "/")))
  attr(id, "scheme") <- scheme; attr(id, "labels") <- labels; attr(id, "n_census") <- n_cen
  id
}

#' Does the jurisdiction have a region cluster file (vic, nsw) or a state (federal)?
#' @keywords internal
seat_cluster_has_region <- function(election) .sc_juris(election) %in% c("vic", "nsw", "fed")

#' Read the type ICC table (inst/extdata/seat-cluster-icc-type.csv) as a seat_cluster_rho() table
#' @param col `"icc_type"`, `"icc_r2"` or `"icc_t2"`.
#' @keywords internal
seat_cluster_type_tab <- function(col) {
  f <- file.path("inst", "extdata", "seat-cluster-icc-type.csv")
  if (!file.exists(f)) f <- system.file("extdata", "seat-cluster-icc-type.csv", package = "auspol")
  if (!nzchar(f) || !file.exists(f)) stop("seat-cluster-icc-type.csv is missing (scripts/fit_seat_cluster_icc.R --scheme=type)", call. = FALSE)
  t <- utils::read.csv(f, stringsAsFactors = FALSE)
  if (!col %in% names(t)) stop("seat-cluster-icc-type.csv has no column ", col, call. = FALSE)
  data.frame(election = t$election, party = t$party, icc = t[[col]], n_cells = t$n_cells, stringsAsFactors = FALSE)
}

.sc_juris <- function(election) sub("[0-9]+$", "", election)

#' Cluster id per seat for one election
#'
#' @param election Label such as `"vic2022"`.
#' @param seats Seat names, in the order of the share matrix.
#' @param shares Projected shares (seats x classes); used only for the k-means jurisdictions.
#' @param root Directory holding `external/` and `inst/` (default: working directory).
#' @return Integer vector (`NA` = no cluster term) with attributes `scheme` and `labels`.
#' @keywords internal
seat_cluster_map <- function(election, seats, shares = NULL, root = ".") {
  j <- .sc_juris(election)
  norm <- function(x) tolower(gsub("[^a-z]", "", tolower(x)))
  from_file <- function(f, key, val) {
    if (!file.exists(f)) stop("seat_cluster_map: ", f, " is missing", call. = FALSE)
    m <- utils::read.csv(f, stringsAsFactors = FALSE)
    lab <- m[[val]][match(norm(seats), norm(m[[key]]))]
    lab
  }
  if (j == "vic") {
    lab <- from_file(file.path(root, "external", "reference", "vec", "vic-district-regions.csv"), "district", "region")
    scheme <- "vic regions (8)"
  } else if (j == "nsw") {
    lab <- from_file(file.path(root, "external", "reference", "nsw", "nsw-district-regions.csv"), "district", "region")
    scheme <- "nsw regions"
  } else if (j == "fed") {
    f <- file.path(root, "inst", "extdata", "fed-division-state.csv")
    if (!file.exists(f)) f <- system.file("extdata", "fed-division-state.csv", package = "auspol")
    if (!nzchar(f) || !file.exists(f)) stop("seat_cluster_map: fed-division-state.csv is missing", call. = FALSE)
    m <- utils::read.csv(f, stringsAsFactors = FALSE)
    lab <- m$state[match(norm(seats), norm(m$seat))]
    scheme <- "fed states"
  } else if (j %in% c("qld", "sa", "wa", "nt")) {
    if (is.null(shares)) stop("seat_cluster_map: ", j, " clusters on projected shares; pass shares", call. = FALSE)
    x <- as.matrix(shares); storage.mode(x) <- "double"
    x[!is.finite(x)] <- 0
    k <- max(2L, as.integer(round(nrow(x) / 11)))
    # separate stream: save, draw, restore (the caller's simulation stream is untouched)
    .had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    .old <- if (.had) get(".Random.seed", envir = globalenv(), inherits = FALSE) else NULL
    set.seed(20261125L)
    km <- stats::kmeans(x, centers = k, nstart = 20, iter.max = 100)
    if (.had) assign(".Random.seed", .old, envir = globalenv()) else rm(".Random.seed", envir = globalenv())
    lab <- paste0("type", km$cluster)
    scheme <- sprintf("%s k-means on projected shares (k = %d)", j, k)
  } else {
    lab <- rep(NA_character_, length(seats))
    scheme <- paste0(j, ": no cluster definition")
  }
  labels <- sort(unique(lab[!is.na(lab)]))
  id <- match(lab, labels)
  attr(id, "scheme") <- scheme; attr(id, "labels") <- labels
  id
}

#' Intraclass correlation of seat misses within clusters, one election and class
#'
#' One-way random-effects method of moments; can be negative (returned as is).
#' @param y Standardised misses.
#' @param g Cluster ids (no `NA`).
#' @keywords internal
seat_cluster_icc1 <- function(y, g) {
  ok <- is.finite(y) & !is.na(g); y <- y[ok]; g <- g[ok]
  N <- length(y); G <- length(unique(g))
  if (G < 2L || N - G < 1L) return(NA_real_)
  nc <- tapply(y, g, length); mc <- tapply(y, g, mean); m <- mean(y)
  msb <- sum(nc * (mc - m)^2) / (G - 1)
  msw <- sum((y - mc[as.character(g)])^2) / (N - G)
  n0 <- (N - sum(nc^2) / N) / (G - 1)
  den <- msb + (n0 - 1) * msw
  if (!is.finite(den) || den <= 0) return(NA_real_)
  (msb - msw) / den
}

#' Time-forward, partially pooled cluster correlation per class for one target election
#'
#' @param election Target label. Elections dated strictly before it, in the same group
#'   (federal, or any state), are used; nothing else.
#' @param tab The per-election table (default `inst/extdata/seat-cluster-icc.csv`).
#' @param quiet Suppress the SCC2 line.
#' @return Named vector over classes in `[0, 0.9]`, attribute `n_elections`.
#' @keywords internal
seat_cluster_rho <- function(election, tab = NULL, quiet = FALSE) {
  if (is.null(tab)) {
    f <- file.path("inst", "extdata", "seat-cluster-icc.csv")
    if (!file.exists(f)) f <- system.file("extdata", "seat-cluster-icc.csv", package = "auspol")
    if (!nzchar(f) || !file.exists(f)) stop("seat_cluster_rho: seat-cluster-icc.csv is missing (scripts/fit_seat_cluster_icc.R)", call. = FALSE)
    tab <- utils::read.csv(f, stringsAsFactors = FALSE)
  }
  ed <- election_dates()
  if (!election %in% names(ed)) stop("seat_cluster_rho: no date for ", election, call. = FALSE)
  t0 <- as.Date(ed[[election]])
  grp <- if (.sc_juris(election) == "fed") "fed" else "state"
  tab$grp <- ifelse(.sc_juris(tab$election) == "fed", "fed", "state")
  tab$date <- as.Date(unname(ed[tab$election]))
  if (anyNA(tab$date)) stop("seat_cluster_rho: no date for ", paste(unique(tab$election[is.na(tab$date)]), collapse = ", "), call. = FALSE)
  use <- tab[tab$grp == grp & tab$date < t0 & is.finite(tab$icc), , drop = FALSE]
  cls <- sort(unique(tab$party))
  out <- stats::setNames(numeric(length(cls)), cls)
  n_el <- length(unique(use$election))
  if (n_el == 0L) {
    if (!quiet) cat(sprintf("SCC2 %s: no earlier %s election measured; rho 0 for every class (no cluster term)\n", election, grp))
    attr(out, "n_elections") <- 0L
    return(out)
  }
  # per class: weighted mean over elections (weight = cells scored), SE from the spread
  est <- se <- stats::setNames(rep(NA_real_, length(cls)), cls)
  for (k in cls) {
    u <- use[use$party == k, , drop = FALSE]
    if (!nrow(u)) next
    w <- u$n_cells / sum(u$n_cells)
    est[k] <- sum(w * u$icc)
    v <- if (nrow(u) >= 2L) sum(w * (u$icc - est[k])^2) * nrow(u) / (nrow(u) - 1) else NA_real_
    # one election: no spread to measure, so the SE is the pooled across-class spread (wide)
    se[k] <- if (is.finite(v)) sqrt(v * sum(w^2)) else NA_real_
  }
  have <- is.finite(est)
  se_fill <- if (any(is.finite(se))) max(se, na.rm = TRUE) else stats::sd(use$icc)
  if (!is.finite(se_fill)) se_fill <- 0.2
  se[have & !is.finite(se)] <- se_fill
  # partial pooling across classes (CLAUDE.md shrinkage rule): precision-weighted mean, and the
  # between-class variance by DerSimonian-Laird, so a precisely measured class that differs
  # (independents, ~0.05) keeps its own value while a noisy one is pulled to the mean
  pw <- 1 / se[have]^2
  mu <- sum(pw * est[have]) / sum(pw)
  tau2 <- if (sum(have) >= 2L) {
    Q <- sum(pw * (est[have] - mu)^2)
    max(0, (Q - (sum(have) - 1)) / (sum(pw) - sum(pw^2) / sum(pw)))
  } else 0
  wsh <- ifelse(have, tau2 / (tau2 + se^2), 0)
  shr <- mu + wsh * (ifelse(have, est, mu) - mu)
  clamped <- names(shr)[shr < 0 | shr > 0.9]
  out[] <- pmin(pmax(shr, 0), 0.9)
  if (!quiet) {
    cat(sprintf("SCC2 %s: rho from %d earlier %s election(s); pooled mean %.3f, between-class var %.4f\n",
                election, n_el, grp, mu, tau2))
    cat(sprintf("SCC2   %-9s raw %+.3f se %.3f w %.2f -> rho %.3f\n", cls, est, se, wsh, out), sep = "")
    if (length(clamped)) cat(sprintf("SCC2   clamped to [0, 0.9]: %s\n", paste(clamped, collapse = ", ")))
  }
  attr(out, "n_elections") <- n_el
  out
}

#' Arguments for simulate_seat_contests() under AUSPOL_SEAT_CLUSTER_COR
#'
#' @param election Target label.
#' @param shares The share matrix the simulator gets (rows = seats, row names or a `seat`
#'   column = seat names).
#' @param tag Prefix for the printed line.
#' @param quiet Suppress printing.
#' @return `list(seat_cluster, cluster_rho)`, both `NULL` when the switch is off.
#' @export
seat_cluster_setup <- function(election, shares, tag = "SCC1", quiet = FALSE) {
  mode <- seat_cluster_mode()
  if (identical(mode, "0")) return(list(seat_cluster = NULL, cluster_rho = NULL))
  seats <- if (is.data.frame(shares) && "seat" %in% names(shares)) as.character(shares$seat) else rownames(shares)
  if (is.null(seats)) stop("seat_cluster_setup: shares has no seat names", call. = FALSE)
  sh <- if (is.data.frame(shares)) shares[, setdiff(names(shares), "seat"), drop = FALSE] else shares
  if (mode %in% c("type", "both")) {
    tid <- seat_cluster_type_map(election, seats, sh, quiet = quiet)
    if (!(identical(mode, "both") && seat_cluster_has_region(election))) {
      rho <- seat_cluster_rho(election, tab = seat_cluster_type_tab("icc_type"), quiet = quiet)
      rho <- rho[intersect(names(rho), colnames(sh))]
      if (!quiet) cat(sprintf("%s %s: AUSPOL_SEAT_CLUSTER_COR=%s, %s: %d clusters%s\n", tag, election, mode,
                              attr(tid, "scheme"), length(attr(tid, "labels")),
                              if (identical(mode, "both")) " (no region file: type factor only)" else ""))
      return(list(seat_cluster = as.integer(tid), cluster_rho = rho))
    }
    rid <- seat_cluster_map(election, seats, sh)
    rr <- seat_cluster_rho(election, tab = seat_cluster_type_tab("icc_r2"), quiet = quiet)
    rt <- seat_cluster_rho(election, tab = seat_cluster_type_tab("icc_t2"), quiet = quiet)
    cls <- intersect(union(names(rr), names(rt)), colnames(sh))
    rr <- stats::setNames(ifelse(is.na(rr[cls]), 0, rr[cls]), cls)
    rt <- stats::setNames(ifelse(is.na(rt[cls]), 0, rt[cls]), cls)
    tot <- rr + rt; scl <- ifelse(tot > 0.9, 0.9 / tot, 1)
    if (!quiet && any(scl < 1))
      cat(sprintf("%s %s: rho_region + rho_type > 0.9 for %s; both scaled to sum 0.9\n", tag, election, paste(cls[scl < 1], collapse = ",")))
    rr <- rr * scl; rt <- rt * scl
    if (!quiet) {
      cat(sprintf("%s %s: AUSPOL_SEAT_CLUSTER_COR=both, region %s (%d clusters, %d of %d seats) + %s (%d clusters)\n",
                  tag, election, attr(rid, "scheme"), length(attr(rid, "labels")), sum(!is.na(rid)), length(rid),
                  attr(tid, "scheme"), length(attr(tid, "labels"))))
      cat(sprintf("%s   %-9s rho_region %.3f rho_type %.3f\n", tag, cls, rr, rt), sep = "")
    }
    return(list(seat_cluster = cbind(region = as.integer(rid), type = as.integer(tid)),
                cluster_rho = list(region = rr, type = rt)))
  }
  id <- seat_cluster_map(election, seats, sh)
  rho <- seat_cluster_rho(election, quiet = quiet)
  rho <- rho[intersect(names(rho), colnames(sh))]
  if (!quiet) {
    cat(sprintf("%s %s: AUSPOL_SEAT_CLUSTER_COR=1, %s: %d clusters, %d of %d seats matched%s\n",
                tag, election, attr(id, "scheme"), length(attr(id, "labels")), sum(!is.na(id)), length(id),
                if (any(is.na(id))) paste0(" (no term: ", paste(utils::head(seats[is.na(id)], 6), collapse = ", "),
                                           if (sum(is.na(id)) > 6) ", ..." else "", ")") else ""))
  }
  list(seat_cluster = as.integer(id), cluster_rho = rho)
}

#' Coalition line-up changes in the seat-swing port (`AUSPOL_SEAT_SWING_PORT_3C`)
#'
#' The port carries each state seat's transposed federal two-party swing into
#' its own swing. Where the Coalition's federal candidate line-up changed
#' between the two federal elections that swing compares (a Liberal seat that
#' gained a National, a three-cornered contest that appeared or went away, a
#' Liberal replaced by a National), the federal swing is partly that candidate
#' change and not a mood the state seat will share. Federal Bendigo, 2025: the
#' Nationals stood beside the Liberals for the first time and the Coalition
#' gained 10.7 points there, which the port moved into Bendigo West.
#'
#' Each booth the transposition used is checked: its division at the federal
#' election being transposed against its division at the federal election
#' before (matched by `PollingPlaceID`, so a redistribution compares the booth
#' with its own earlier contest). A booth is AFFECTED when the two divisions'
#' Coalition line-ups differ ([fed_coalition_lineup()]). A seat's affected
#' share `frac` is the vote share of its booths that are affected.
#'
#' Switch values (default `"0"` leaves the port byte-identical):
#' * `"1"` replaces each seat's federal swing by
#'   `m + (1 - (1 - w) * frac) * (fed_swing - m)`, `m` the cycle's mean over its
#'   seats, with `w = AUSPOL_SEAT_SWING_PORT_3C_W` (default `"0"`: the affected
#'   share of the seat's deviation is removed; `"0.5"` keeps half of it). Applied
#'   in [seat_swing_port_fs()], so the coefficient is FITTED on cleaned earlier
#'   cycles and APPLIED to a cleaned target, in every harness that applies the
#'   port and in `fit_seats_full.R`.
#' * `"2"` fits `w` time-forward: in each target's fit the deviation is split
#'   into its unaffected part `(1 - frac) dev` and its affected part
#'   `frac dev`, the two slopes `b_u`, `b_a` are fitted on the earlier cycles,
#'   and `w = clamp(b_a / b_u, 0, 1)` is shrunk toward 0 (exclusion) by the
#'   precision of `b_a` (`w * b_a^2 / (b_a^2 + se_a^2)`). The fit and the target
#'   are then cleaned at that `w`.
#' docs/plans/prereg-seat-swing-port-3c-2026-10-25.md.
#' @return `"0"`, `"1"` or `"2"`; an error for anything else.
#' @keywords internal
seat_swing_port_3c_mode <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_SWING_PORT_3C", "2")
  if (!v %in% c("0", "1", "2")) stop("AUSPOL_SEAT_SWING_PORT_3C must be \"0\", \"1\" or \"2\", not \"", v, "\"")
  v
}

#' The fixed weight mode "1" keeps of an affected deviation
#' @return Number in `[0, 1]` from `AUSPOL_SEAT_SWING_PORT_3C_W` (default 0).
#' @keywords internal
seat_swing_port_3c_w <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_SWING_PORT_3C_W", "0")
  w <- suppressWarnings(as.numeric(v))
  if (!is.finite(w) || w < 0 || w > 1) stop("AUSPOL_SEAT_SWING_PORT_3C_W must be a number in [0, 1], not \"", v, "\"")
  w
}

#' Each federal division's Coalition candidate line-up
#'
#' From the candidate corpus: the Coalition candidates (`party == "LNP"`) in each
#' division at each federal election, by party abbreviation. The Queensland
#' merged party (`LNQ` in 2010, `LNP` after) is one label, `LNP`.
#' @param cand Candidate rows (`region`, `year`, `seat`, `party`, `party_ab`);
#'   `output/candidacies.csv` when `NULL`.
#' @return data.table `year`, `division` (normalised), `n_coal`, `lineup`
#'   (sorted abbreviations joined by `+`, `""` for none). Every federal division
#'   with any candidate appears, so a division with no Coalition candidate is
#'   `n_coal = 0`, not missing.
#' @export
fed_coalition_lineup <- function(cand = NULL) {
  if (is.null(cand)) {
    f <- out_path("candidacies.csv")
    if (!file.exists(f)) stop("AUSPOL_SEAT_SWING_PORT_3C needs ", f, "; run scripts/build_candidacies.R")
    cand <- data.table::fread(f, showProgress = FALSE, select = c("region", "year", "seat", "party", "party_ab"))
  }
  region_v <- as.character(cand[["region"]])
  keep <- region_v == "fed"
  yr <- as.integer(cand[["year"]][keep])
  dv <- normalise_seat(cand[["seat"]][keep])
  coal <- as.character(cand[["party"]][keep]) == "LNP"
  ab <- as.character(cand[["party_ab"]][keep])
  ab[ab %in% c("LNQ", "LNP")] <- "LNP"
  d <- data.table::data.table(year = yr, division = dv, coal = coal, ab = ab)
  d[, list(n_coal = sum(coal), lineup = paste(sort(ab[coal]), collapse = "+")), by = c("year", "division")]
}

#' Whether two Coalition line-ups differ
#'
#' A different number of Coalition candidates is a change (a three-cornered
#' contest appeared or went away). With one candidate on each side, a different
#' party is a change (Liberal to National). The Queensland merger is NOT a
#' change: when one side is the merged party `LNP` alone and the other side has
#' any Coalition candidate (Liberal, National, both, or `LNP`), the line-up is
#' treated as unchanged, since the merger replaced them, not a candidate choice
#' (so a 2007 `LP+NP` contest against a 2010 `LNP` one is unchanged). `LNP`
#' against no Coalition candidate is still a change. `NA` on either side gives
#' `NA` (unknown).
#' @param now,prev Line-up strings from [fed_coalition_lineup()].
#' @return Logical vector.
#' @keywords internal
coalition_lineup_changed <- function(now, prev) {
  n_of <- function(x) ifelse(is.na(x), NA_integer_, ifelse(x == "", 0L, lengths(strsplit(x, "+", fixed = TRUE))))
  nn <- n_of(now); np <- n_of(prev)
  out <- nn != np
  same_n <- !is.na(out) & !out
  out[same_n] <- now[same_n] != prev[same_n]
  merger <- !is.na(out) & ((now == "LNP" & np > 0L) | (prev == "LNP" & nn > 0L))
  out[merger] <- FALSE
  out
}

# Booth -> division at one federal election: the two-party booth file when it
# exists (with votes), else the polling-place list (divisions only).
.fed_booth_divisions <- function(year, need_votes) {
  dir <- file.path(pkg_root(), "external", "reference", "aec", "booths")
  tf <- file.path(dir, sprintf("tpp-fed%d.csv", year))
  if (file.exists(tf)) {
    d <- data.table::fread(tf, skip = 1L, showProgress = FALSE)
    return(data.table::data.table(place_id = as.integer(d[["PollingPlaceID"]]),
                                  division = normalise_seat(d[["DivisionNm"]]),
                                  tot = as.numeric(d[["TotalVotes"]])))
  }
  if (need_votes) stop("AUSPOL_SEAT_SWING_PORT_3C: no two-party booth file ", tf)
  pf <- file.path(dir, sprintf("pp-fed%d.csv", year))
  if (!file.exists(pf)) return(NULL)
  d <- data.table::fread(pf, skip = 1L, showProgress = FALSE)
  data.table::data.table(place_id = as.integer(d[["PollingPlaceID"]]),
                         division = normalise_seat(d[["DivisionNm"]]), tot = NA_real_)
}

# The booth -> state district join for one cycle. The four-state map
# (fed-booth-map.csv, written by scripts/transpose_fed_swing.R) first, then a
# WA map beside it, then the WA correspondence files transpose_fed_swing.R
# reads (its WA_JOBS list, mirrored here).
.port_3c_booth_map <- function(region, cycle) {
  rg <- region; cy <- as.integer(cycle)
  for (f in c(election_data_path("fed-booth-map.csv"), election_data_path("fed-booth-map-wa.csv"))) {
    if (!file.exists(f)) next
    m <- data.table::fread(f, showProgress = FALSE)
    hit <- as.character(m[["region"]]) == rg & as.integer(m[["cycle"]]) == cy
    if (any(hit)) return(unique(data.table::data.table(district = m[["district"]][hit], place_id = as.integer(m[["place_id"]][hit]))))
  }
  if (rg == "wa") {
    wa_files <- c("2008" = "booths-2008wa.csv", "2013" = "booths-2013wa-coord.csv", "2017" = "booths-2017wa.csv",
                  "2021" = "booths-2021wa.csv", "2025" = "booths-2025wa.csv")
    nm <- wa_files[as.character(cy)]
    f <- if (is.na(nm)) NA_character_ else file.path(pkg_root(), "external", "reference", "correspondences", nm)
    if (!is.na(f) && file.exists(f)) {
      m <- data.table::fread(f, showProgress = FALSE)
      return(unique(data.table::data.table(district = m[["district"]], place_id = as.integer(m[["place_id"]]))))
    }
  }
  NULL
}

#' Each state seat's share of federal votes from booths whose Coalition
#' line-up changed
#'
#' @param region,cycle,fed The state cycle (`"vic"`, 2026) and the federal
#'   election its swing is transposed from (2025).
#' @param lineup [fed_coalition_lineup()] output.
#' @param booth_map,booths_now,booths_prev Optional overrides (tests): the
#'   booth -> district map (`district`, `place_id`) and the booth -> division
#'   tables (`place_id`, `division`, `tot`) for `fed` and the federal election
#'   before it. Read from disk when `NULL`.
#' @return data.table `s` (normalised seat), `frac`, `divisions` (the changed
#'   divisions contributing, `;`-separated), with attribute `changed` (every
#'   changed division in the cycle's booths, with its two line-ups) and
#'   `unknown` (booth votes whose line-up could not be read).
#' @export
seat_swing_port_3c_share <- function(region, cycle, fed, lineup,
                                     booth_map = NULL, booths_now = NULL, booths_prev = NULL) {
  fed <- as.integer(fed)
  yrs <- sort(unique(lineup$year))
  prev_yr <- if (any(yrs < fed)) max(yrs[yrs < fed]) else NA_integer_
  if (is.na(prev_yr)) stop("AUSPOL_SEAT_SWING_PORT_3C: no federal election before ", fed, " in the candidate corpus")
  if (!fed %in% yrs) stop("AUSPOL_SEAT_SWING_PORT_3C: fed", fed, " is not in the candidate corpus")
  if (is.null(booth_map)) booth_map <- .port_3c_booth_map(region, cycle)
  if (is.null(booth_map) || !nrow(booth_map))
    stop("AUSPOL_SEAT_SWING_PORT_3C: no booth -> district map for ", region, cycle)
  if (is.null(booths_now)) booths_now <- .fed_booth_divisions(fed, need_votes = TRUE)
  if (is.null(booths_prev)) booths_prev <- .fed_booth_divisions(prev_yr, need_votes = FALSE)
  bm_place <- as.integer(booth_map[["place_id"]])
  bm_s <- normalise_seat(booth_map[["district"]])
  now_place <- as.integer(booths_now[["place_id"]])
  i_now <- match(bm_place, now_place)
  div_now <- booths_now[["division"]][i_now]
  tot <- as.numeric(booths_now[["tot"]])[i_now]
  prev_hit <- if (is.null(booths_prev)) rep(NA_integer_, length(bm_place))
              else match(bm_place, as.integer(booths_prev[["place_id"]]))
  div_prev <- if (is.null(booths_prev)) rep(NA_character_, length(bm_place)) else booths_prev[["division"]][prev_hit]
  # A booth new at this election keeps its division's name as the comparator.
  div_prev <- ifelse(is.na(div_prev), div_now, div_prev)
  ly_y <- as.integer(lineup$year); ly_d <- as.character(lineup$division); ly_l <- lineup$lineup
  l_now <- ly_l[match(paste(fed, div_now), paste(ly_y, ly_d))]
  l_prev <- ly_l[match(paste(prev_yr, div_prev), paste(ly_y, ly_d))]
  ch <- coalition_lineup_changed(l_now, l_prev)
  in_now <- !is.na(i_now)
  ok <- in_now & is.finite(tot) & tot > 0
  # Booths that cannot be weighed or compared are COUNTED, never dropped quietly:
  # absent from the now file (booth count; no votes to weigh), present with no
  # votes (booth count), and new since the earlier election (vote share; they
  # are compared under their own division's name).
  is_new <- ok & is.na(prev_hit)
  unknown <- sum(tot[ok & is.na(ch)])
  aff <- ok & !is.na(ch) & ch
  b <- data.table::data.table(s = bm_s[ok], tot = tot[ok], aff = aff[ok],
                              div = ifelse(aff, paste0(div_prev, "->", div_now), NA_character_)[ok])
  out <- b[, list(frac = sum(tot[aff]) / sum(tot),
                  divisions = paste(sort(unique(div[aff])), collapse = ";")), by = "s"]
  chg <- unique(data.table::data.table(prev_division = div_prev[aff], division = div_now[aff],
                                       prev = l_prev[aff], now = l_now[aff]))
  attr(out, "changed") <- chg
  attr(out, "unknown") <- unknown / sum(tot[ok])
  attr(out, "n_booths") <- length(bm_place)
  attr(out, "n_not_in_now") <- sum(!in_now)
  attr(out, "n_no_votes") <- sum(in_now & !ok)
  attr(out, "new") <- sum(tot[is_new]) / sum(tot[ok])
  .port_3c_coverage_stop(sprintf("%s%s <- fed%d", region, cycle, fed), out)
  out
}

# Coverage limits for the line-up share (`AUSPOL_SEAT_SWING_PORT_3C`)
#
# Above these the share table is not describing the booths the transposition
# used, and the run stops. Limits, against the largest seen in the 16 cycles
# of the dry run of 2026-10-25 (prereg): booths absent from the federal
# two-party file over 2% of the map's booths (seen: 0 everywhere); booths with
# no votes over 5% (seen: 20 of 831, 2.4%, wa2021); votes in booths with no
# earlier-election match over 30% (seen: 15.3%, wa2025); votes whose line-up
# cannot be read over 5% (seen: 1.5%, sa2022); and, in
# [seat_swing_port_3c_clean()], any state seat of the cycle missing from the
# share table (seen: none).
PORT_3C_LIMITS <- c(not_in_now = 0.02, no_votes = 0.05, new = 0.30, unknown = 0.05)

.port_3c_coverage_stop <- function(lab, sh) {
  nb <- attr(sh, "n_booths")
  v <- c(not_in_now = attr(sh, "n_not_in_now") / nb, no_votes = attr(sh, "n_no_votes") / nb,
         new = attr(sh, "new"), unknown = attr(sh, "unknown"))
  v[!is.finite(v)] <- 1
  bad <- names(v)[v > PORT_3C_LIMITS[names(v)]]
  if (length(bad))
    stop("AUSPOL_SEAT_SWING_PORT_3C ", lab, ": coverage over its limit (", paste(sprintf("%s %.1f%% > %.0f%%", bad, 100 * v[bad], 100 * PORT_3C_LIMITS[bad]), collapse = "; "),
         "). The booth map, the federal booth files and the candidate corpus do not describe the same booths.")
  invisible(v)
}

#' Clean the port's transposed federal swing for Coalition line-up changes
#'
#' `AUSPOL_SEAT_SWING_PORT_3C` "1" or "2". Adds `frac` and `fed_swing_raw` to
#' `fs` and replaces `fed_swing` by `m + (1 - (1 - w) frac) (fed_swing - m)`
#' within each cycle. Prints an `S3C1` line per cycle naming the changed
#' divisions and the seats moved.
#' @param fs The port's transposed swing table (`seat`, `fed_swing`, `region`,
#'   `cycle`, `fed`).
#' @param w Weight kept of an affected deviation; `NULL` adds `frac` only.
#' @param lineup,share_fun Overrides for tests.
#' @return `fs`, with `frac`, `fed_swing_raw` and (when `w` is given) cleaned
#'   `fed_swing`.
#' @keywords internal
seat_swing_port_3c_clean <- function(fs, w = NULL, lineup = NULL, share_fun = seat_swing_port_3c_share,
                                     labels = NULL) {
  if (!"fed" %in% names(fs)) stop("AUSPOL_SEAT_SWING_PORT_3C: the transposed swing table has no `fed` column")
  if (is.null(lineup)) lineup <- fed_coalition_lineup()
  fs <- data.table::copy(if (data.table::is.data.table(fs)) fs else data.table::as.data.table(fs))
  fs$fed_swing_raw <- fs$fed_swing
  fs$frac <- 0
  lab_v <- paste0(fs$region, fs$cycle)
  s_v <- normalise_seat(fs$seat)
  todo <- unique(lab_v)
  if (!is.null(labels)) todo <- todo[todo %in% labels]
  for (lab in todo) {
    at <- which(lab_v == lab)
    rg <- fs$region[at[1]]; cy <- fs$cycle[at[1]]; fy <- fs$fed[at[1]]
    sh <- share_fun(rg, cy, fy, lineup)
    fr <- sh$frac[match(s_v[at], sh$s)]
    no_seat <- fs$seat[at][!is.finite(fr)]
    if (length(no_seat))
      stop("AUSPOL_SEAT_SWING_PORT_3C ", lab, ": ", length(no_seat), " of ", length(at), " seats have no booth in the line-up share table (",
           paste(utils::head(no_seat, 8L), collapse = ", "), "); the booth map and the transposed swing disagree on seat names")
    fs$frac[at] <- fr
    chg <- attr(sh, "changed")
    moved <- at[fr > 0]
    ord <- moved[order(-fs$frac[moved])]
    top <- utils::head(ord, 6L)
    nb <- attr(sh, "n_booths")
    cov <- if (is.null(nb)) "coverage not reported" else
      sprintf("coverage: %d of %d map booths absent from the fed%s two-party file, %d with no votes; %.1f%% of votes in booths new since the earlier election (compared by division name); %.1f%% of votes with an unreadable line-up (treated unaffected); 0 of %d seats unmatched",
              attr(sh, "n_not_in_now"), nb, fy, attr(sh, "n_no_votes"), 100 * attr(sh, "new"), 100 * attr(sh, "unknown"), length(at))
    cat(sprintf("S3C1 %s <- fed%s: %d Coalition line-up change(s) in its booths (%s); %d of %d seats touched%s; %s\n",
                lab, fy, if (is.null(chg)) 0L else nrow(chg),
                if (is.null(chg) || !nrow(chg)) "none" else paste(sprintf("%s %s->%s", chg$division, ifelse(chg$prev == "", "none", chg$prev), ifelse(chg$now == "", "none", chg$now)), collapse = ", "),
                length(moved), length(at),
                if (length(top)) paste0("; largest: ", paste(sprintf("%s %.0f%%", fs$seat[top], 100 * fs$frac[top]), collapse = ", ")) else "",
                cov))
  }
  if (!is.null(w)) fs <- .port_3c_apply_w(fs, w)
  fs
}

# Re-weight a table that already carries `frac` and `fed_swing_raw`: within each
# cycle, m + (1 - (1 - w) frac) (raw - m), m the cycle mean of the raw swing.
.port_3c_apply_w <- function(fs, w) {
  lab_v <- paste0(fs$region, fs$cycle)
  m <- stats::ave(fs$fed_swing_raw, lab_v, FUN = mean)
  fs$fed_swing <- m + (1 - (1 - w) * fs$frac) * (fs$fed_swing_raw - m)
  fs
}

#' The time-forward line-up weight (`AUSPOL_SEAT_SWING_PORT_3C=2`)
#'
#' Fits the unaffected and affected slopes on the port's earlier-cycle rows
#' (`dev` the RAW within-cycle deviation, `frac`, `yy`), through the origin,
#' with the larger of the cycle-clustered and ordinary errors. Returns
#' `w = clamp(b_a / b_u, 0, 1) * b_a^2 / (b_a^2 + se_a^2)`: exclusion (0) unless
#' the affected part is measured to carry over. 0 when there is no affected
#' variation to fit or `b_u <= 0`.
#' @param rows data.table `dev`, `frac`, `yy`, `pair`.
#' @return list `w`, `b_u`, `b_a`, `se_a`, `n_aff` (rows with `frac > 0`).
#' @keywords internal
seat_swing_port_3c_fit_w <- function(rows) {
  n_aff <- sum(rows$frac > 0)
  zero <- list(w = 0, b_u = NA_real_, b_a = NA_real_, se_a = NA_real_, n_aff = n_aff)
  if (n_aff < 2L) return(zero)
  X <- cbind(u = (1 - rows$frac) * rows$dev, a = rows$frac * rows$dev)
  XtX <- crossprod(X)
  # Rank and conditioning, not the determinant: det() scales with the squared
  # size of the deviations, so a fixed tolerance on it means nothing.
  if (qr(X)$rank < 2L || kappa(XtX, exact = TRUE) > 1e10) return(zero)
  inv <- solve(XtX)
  b <- drop(inv %*% crossprod(X, rows$yy))
  e <- drop(rows$yy - X %*% b)
  G <- length(unique(rows$pair))
  v_ols <- inv * sum(e^2) / max(1, nrow(rows) - 2)
  v <- v_ols
  if (G >= 2L) {
    sc <- rowsum(X * e, rows$pair)
    v_cl <- inv %*% crossprod(sc) %*% inv * G / (G - 1)
    v <- if (v_cl[2, 2] > v_ols[2, 2]) v_cl else v_ols
  }
  se_a <- sqrt(v[2, 2])
  if (!is.finite(b[["u"]]) || b[["u"]] <= 0) return(utils::modifyList(zero, list(b_u = b[["u"]], b_a = b[["a"]], se_a = se_a)))
  ratio <- min(1, max(0, b[["a"]] / b[["u"]]))
  w <- ratio * b[["a"]]^2 / (b[["a"]]^2 + se_a^2)
  list(w = w, b_u = b[["u"]], b_a = b[["a"]], se_a = se_a, n_aff = n_aff)
}

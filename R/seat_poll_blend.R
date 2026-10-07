# Public pollsters whose direct seat polls count as independent under
# AUSPOL_SEAT_POLL_SOURCES="public" (Pete's allowlist choice, 2026-09-29).
# Matched case-insensitively as regexes against the pollster name, so
# "YouGov" covers "YouGov Galaxy" and "Freshwater" covers "Freshwater Strategy".
PUBLIC_SEAT_POLLSTERS <- c("YouGov", "Galaxy", "Newspoll", "RedBridge", "DemosAU",
                           "Freshwater", "EMRS", "Resolve", "Ipsos", "Essential",
                           "Roy Morgan")

#' Seat polls as model classes, per seat, for one election
#'
#' Reads `external/reference/polls/seat-polls/seat_polls.csv` (built by
#' `scripts/fetch_seat_polls.R`), keeps poll rows with a primary and fieldwork
#' ending within `days` before election day, maps each party to a model class,
#' sums within class per poll and averages over polls.
#' docs/plans/prereg-seat-poll-blend-2026-09-29.md.
#'
#' @param election Label such as `"fed2022"`.
#' @param days Fieldwork window before election day.
#' @param by_type Keep MRP and direct polls apart (a `type` column).
#' @param by_poll Return one row per poll and class (`seat`, `poll_id`,
#'   `class`, `fp`, `mrp`), with every class a poll does not name as `REST`
#'   and each poll scaled to 100; input to [seat_poll_implied()].
#' @return data.table (`seat`, `class`, `poll`, `n_polls`, `n_mrp`, and `type`
#'   when `by_type`), possibly empty. A release (pollster + dates) covering at
#'   least 20 seats counts as MRP, whatever its name.
#' @export
seat_poll_shares <- function(election, days = 90, by_type = FALSE, by_poll = FALSE) {
  f <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")
  empty <- data.table::data.table(seat = character(0), class = character(0), poll = numeric(0),
                                  n_polls = integer(0), n_mrp = integer(0))
  if (!file.exists(f)) return(empty)
  s <- .read_seat_polls_file(f)
  el_arg <- election
  ed <- as.Date(unname(election_dates()[el_arg]))
  keep <- s$election == el_arg & s$row_type == "poll" & is.finite(s$fp) &
    !is.na(s$fieldwork_end) & as.Date(s$fieldwork_end) < ed & as.Date(s$fieldwork_end) >= ed - days
  s <- s[keep]
  if (!nrow(s)) return(empty)
  p <- toupper(trimws(s$party))
  s$class <- ifelse(p == "ALP", "ALP",
             ifelse(p %in% c("LIB", "NAT", "LNP", "L/NP", "CLP"), "LNP",
             ifelse(p == "GRN", "GRN",
             ifelse(p %in% c("ON", "ONP"), "ONP",
             ifelse(p == "IND" | grepl("\\(IND\\)$", p), "IND",
             ifelse(p %in% c("UAP", "KAP"), "OTH_RIGHT", "OTH"))))))
  s$poll_id <- paste(s$seat_name, s$pollster, s$date_raw)
  if (identical(Sys.getenv("AUSPOL_SEAT_POLL_IND_MAP", "1"), "1")) s <- .seat_poll_ind_map(s, el_arg)
  # MRP by STRUCTURE: YouGov's 2022 MRP is labelled plain "YouGov".
  s$release <- paste(s$pollster, s$date_raw)
  cover <- s[, list(n_seats = data.table::uniqueN(seat_name)), by = release]
  s$is_mrp <- cover$n_seats[match(s$release, cover$release)] >= 20L
  src <- Sys.getenv("AUSPOL_SEAT_POLL_SOURCES", "all")
  if (!src %in% c("all", "public")) stop("AUSPOL_SEAT_POLL_SOURCES must be \"all\" or \"public\", not ", src)
  if (src == "public") {
    # Accent/RedBridge's MRP releases split their fieldwork dates by seat, so
    # some fall under the 20-seat structural test; the name is reliable here.
    s$is_mrp <- s$is_mrp | grepl("MRP", s$pollster, ignore.case = TRUE)
    # plans/prereg-seat-poll-public-only-2026-09-29.md: MRP releases, plus
    # direct polls by an allowlisted public pollster with no recorded sponsor.
    sponsored <- !is.na(s$client) & nzchar(trimws(s$client))
    public <- grepl(paste(PUBLIC_SEAT_POLLSTERS, collapse = "|"), s$pollster, ignore.case = TRUE)
    keep_src <- s$is_mrp | (public & !sponsored)
    n_all <- data.table::uniqueN(s$poll_id)
    s <- s[which(keep_src)]
    cat(sprintf("SPB0 %s: public pollsters only, %d of %d polls kept\n", el_arg, data.table::uniqueN(s$poll_id), n_all))
    if (!nrow(s)) return(empty)
  }
  if (by_poll) {
    # Per-poll rows for seat_poll_implied(): only classes a poll NAMES are
    # comparable with ours (ALP, LNP, GRN, and ONP / IND where reported). Its
    # UAP, KAP and "Others" columns are catch-alls -- YouGov 2022's "OTH" is
    # Katter's 43 in Kennedy and Zoe Daniel's 24 in Goldstein -- so they go
    # to REST. Each poll is scaled to 100 over its reported rows first.
    s$class[!s$class %in% c("ALP", "LNP", "GRN", "ONP", "IND")] <- "REST"
    pp <- s[, list(fp = sum(fp), mrp = is_mrp[1]), by = list(seat = seat_name, poll_id, class)]
    pp[, fp := 100 * fp / sum(fp), by = poll_id]
    return(pp)
  }
  per_poll <- s[, list(fp = sum(fp), mrp = is_mrp[1]), by = list(seat = seat_name, poll_id, class)]
  if (!by_type) return(per_poll[, list(poll = mean(fp), n_polls = .N, n_mrp = sum(mrp)), by = list(seat, class)])
  per_poll$type <- ifelse(per_poll$mrp, "mrp", "direct")
  per_poll[, list(poll = mean(fp), n_polls = .N, n_mrp = sum(mrp)), by = list(seat, class, type)]
}

#' Each seat poll as a full vector over OUR classes (per-poll match)
#'
#' For each poll, classes it names take its number; our remaining classes
#' (share above 0) share its `REST` total in proportion to our own shares, so
#' a catch-all "Others" is compared with what it actually contains. Named
#' mass with no matching class of ours joins `REST`. The vectors are then
#' averaged over a seat's polls. Pete's choice over a fixed four-class
#' collapse, 2026-09-29: it keeps One Nation and independent numbers where a
#' poll reports them. plans/prereg-seat-poll-per-poll-match-2026-09-29.md.
#'
#' @param pp From `seat_poll_shares(by_poll = TRUE)`.
#' @param our data.table `seat`, `class`, `share` (our shares, any scale).
#' @return data.table `seat`, `class`, `poll`, `n_polls`, `n_mrp`.
#' @export
seat_poll_implied <- function(pp, our) {
  out <- data.table::data.table(seat = character(0), class = character(0), poll = numeric(0),
                                n_polls = integer(0), n_mrp = integer(0))
  if (!nrow(pp)) return(out)
  our_seat <- normalise_seat(our$seat)
  pp_seat <- normalise_seat(pp$seat)
  ids <- unique(pp$poll_id)
  vecs <- lapply(ids, function(id) {
    r <- pp[which(pp$poll_id == id), ]
    st <- pp_seat[which(pp$poll_id == id)][1]
    o <- our[which(our_seat == st & is.finite(our$share) & our$share > 0), ]
    if (!nrow(o)) return(NULL)
    named <- r[r$class != "REST" & r$class %in% o$class, ]
    rest_total <- 100 - sum(named$fp)
    rest_cls <- setdiff(o$class, named$class)
    v <- stats::setNames(numeric(nrow(o)), o$class)
    v[named$class] <- named$fp
    if (length(rest_cls)) {
      w_rest <- o$share[match(rest_cls, o$class)]
      v[rest_cls] <- max(0, rest_total) * w_rest / sum(w_rest)
    }
    data.table::data.table(seat = r$seat[1], class = names(v), poll = unname(v), mrp = r$mrp[1])
  })
  vv <- data.table::rbindlist(vecs)
  if (!nrow(vv)) return(out)
  vv[, list(poll = mean(poll), n_polls = .N, n_mrp = sum(mrp)), by = list(seat, class)]
}

#' Seat-poll cells for one election in the active match mode
#'
#' `AUSPOL_SEAT_POLL_MATCH` "class" (default, v50/v51): the poll's own class
#' labels. "perpoll": [seat_poll_implied()] against `our`.
#' @keywords internal
.seat_poll_cells <- function(election, our) {
  m <- Sys.getenv("AUSPOL_SEAT_POLL_MATCH", "class")
  if (!m %in% c("class", "perpoll")) stop("AUSPOL_SEAT_POLL_MATCH must be \"class\" or \"perpoll\", not ", m)
  if (m == "class") return(seat_poll_shares(election))
  seat_poll_implied(seat_poll_shares(election, by_poll = TRUE), our)
}

#' Time-forward weight for pulling seat primaries toward seat polls
#'
#' Least squares on earlier elections' polled (seat, class) cells: prediction
#' `xgb_pred_seat` from `output/forecasts.csv`, target `actual_share`.
#' `w = sum(dx*dy)/sum(dx^2)`, SE clustered on seat-election, shrunk
#' `w*w^2/(w^2+se^2)`, clamped between 0 and 1; 0 with no earlier polled cells.
#'
#' @param target_election Label such as `"fed2025"`.
#' @return list: `w`, `raw`, `se`, `n` (cells), `k` (earlier elections used).
#' @export
seat_poll_weight <- function(target_election) {
  f <- current_seat_predictions()
  if (is.null(f)) stop("seat_poll_weight needs this rebuild's as-at predictions (output/xgb-primary-asat-predictions.csv)")
  els <- unique(f$election)
  els <- els[elections_before(els, target_election)]
  rows <- data.table::rbindlist(lapply(els, function(e) {
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party,
                                  pred = xgb_pred_seat, actual = actual_share)]
    sp <- .seat_poll_cells(e, data.table::data.table(seat = fe$seat, class = fe$class, share = fe$pred))
    if (!nrow(sp)) return(NULL)
    sp$seat <- normalise_seat(sp$seat)
    m <- merge(sp, fe, by = c("seat", "class"))
    m <- m[is.finite(pred) & is.finite(actual) & pred > 0]
    if (!nrow(m)) return(NULL)
    m$unit <- paste(e, m$seat)
    m$el <- e
    m
  }), fill = TRUE)
  if (!nrow(rows)) return(list(w = 0, raw = NA_real_, se = NA_real_, n = 0L, k = 0L))
  dx <- rows$poll - rows$pred
  dy <- rows$actual - rows$pred
  b <- sum(dx * dy) / sum(dx^2)
  e <- dy - b * dx
  G <- length(unique(rows$unit))
  se2 <- sum(tapply(dx * e, rows$unit, sum)^2) / sum(dx^2)^2 * .cluster_df(G)
  w <- min(1, max(0, b * b^2 / (b^2 + se2)))
  list(w = w, raw = b, se = sqrt(se2), n = nrow(rows), k = length(unique(rows$el)))
}

#' The seat-poll blend's inputs for one target, computed or shipped
#'
#' Computed from the poll file and `output/forecasts.csv` when both exist; the
#' daily GitHub run has neither, so the rebuild's promote step writes
#' `output/seat-poll-blend-<target>.csv` and ships it with the models.
#'
#' @param target_election Label such as `"vic2026"`.
#' @param write Write the shipped table.
#' @return data.table (`seat`, `class`, `type`, `poll`, `n_polls`, `n_mrp`) with
#'   attribute `w` (pooled weight plus `w_direct`, `w_mrp`).
#' @export
seat_poll_blend_table <- function(target_election, write = FALSE) {
  src <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")
  cache <- out_path(sprintf("seat-poll-blend-%s.csv", target_election))
  if (file.exists(src) && .has_seat_predictions()) {
    w <- seat_poll_weight(target_election)
    sw <- seat_poll_weights_split(target_election)
    w$w_direct <- sw$direct$w; w$w_mrp <- sw$mrp$w
    ind_on <- .ind_weight_on()
    if (ind_on) { wi <- seat_poll_ind_weight(target_election); w$w_ind <- wi$w; w$w_ind_raw <- wi$raw; w$w_ind_se <- wi$se; w$w_ind_n <- wi$n }
    tb <- seat_poll_shares(target_election, by_type = TRUE)
    if (write) {
      out <- data.table::copy(tb)
      if (!nrow(out)) out <- data.table::data.table(seat = NA_character_, class = NA_character_, type = NA_character_,
                                                    poll = NA_real_, n_polls = NA_integer_, n_mrp = NA_integer_)
      out$w <- w$w; out$w_raw <- w$raw; out$w_se <- w$se; out$w_n <- w$n; out$w_k <- w$k
      out$w_direct <- w$w_direct; out$w_mrp <- w$w_mrp
      if (ind_on) { out$w_ind <- w$w_ind; out$w_ind_raw <- w$w_ind_raw; out$w_ind_se <- w$w_ind_se; out$w_ind_n <- w$w_ind_n }
      data.table::fwrite(out, cache)
    }
  } else if (file.exists(cache)) {
    raw <- data.table::fread(cache, showProgress = FALSE)
    if (length(unique(raw$w)) != 1L) stop(cache, " has more than one weight")
    w <- list(w = raw$w[1], raw = raw$w_raw[1], se = raw$w_se[1], n = raw$w_n[1], k = raw$w_k[1],
              w_direct = raw$w_direct[1], w_mrp = raw$w_mrp[1])
    if (.ind_weight_on()) {
      if (!"w_ind" %in% names(raw)) {
        # A table shipped before the IND weight existed (review 2026-10-06): stopping here
        # made fit_seats_full.R publish with NO seat-poll blend at all, still green. Fall
        # back to the class-blind weight for IND cells, loudly, until the table is re-promoted.
        cat(sprintf("SPB!! %s was written without the IND weight (w_ind): IND cells use the class-blind weight %.3f. Re-promote it (scripts/promote_rebuild.R) to ship w_ind.\n",
                    basename(cache), w$w))
        w$w_ind <- w$w; w$w_ind_raw <- NA_real_; w$w_ind_se <- NA_real_; w$w_ind_n <- 0L
      } else {
        w$w_ind <- raw$w_ind[1]; w$w_ind_raw <- raw$w_ind_raw[1]; w$w_ind_se <- raw$w_ind_se[1]; w$w_ind_n <- raw$w_ind_n[1]
      }
    }
    tb <- raw[!is.na(raw$seat), list(seat, class, type, poll, n_polls, n_mrp)]
    cat(sprintf("SPB  %s: blend inputs read from %s (sources absent)\n", target_election, basename(cache)))
  } else {
    stop("seat-poll blend for ", target_election, ": neither the sources (", src,
         ", output/forecasts.csv) nor the shipped table (", cache, ") exist")
  }
  attr(tb, "w") <- w
  tb
}

#' Pull seat primaries toward seat polls by the time-forward weight
#'
#' For each polled (seat, class) whose share is already above 0 (no phantom
#' candidates): `share + w * (poll - share)`, then rows renormalised to 100.
#' A no-op unless `AUSPOL_SEAT_POLL_BLEND` is "1". Callers apply it after the
#' xgb override and the seat-swing port.
#'
#' @param shares Matrix of primary shares, rownames = seats, colnames = classes.
#' @param target_election Label such as `"fed2022"`.
#' @return `shares`, blended.
#' @export
seat_poll_blend_apply <- function(shares, target_election) {
  mode <- Sys.getenv("AUSPOL_SEAT_POLL_BLEND", "1")
  if (!mode %in% c("1", "2", "3")) return(shares)
  if (mode == "3") {
    # plans/prereg-seat-poll-joint-fp-tpp-2026-09-30.md: primary AND two-party
    # seat-poll gaps, weights fitted jointly on earlier elections.
    jt <- seat_poll_joint_table(target_election)
    return(.seat_poll_blend_joint(shares, target_election, jt$w, jt$sp, jt$tp))
  }
  tb <- seat_poll_blend_table(target_election)
  w <- attr(tb, "w")
  perpoll <- identical(Sys.getenv("AUSPOL_SEAT_POLL_MATCH", "class"), "perpoll")
  ind_on <- .ind_weight_on()
  if (ind_on && perpoll) stop("AUSPOL_SEAT_POLL_IND_WEIGHT=1 needs AUSPOL_SEAT_POLL_MATCH=class (per-poll cells carry no direct/MRP type)")
  if (mode == "2") {
    if (perpoll) stop("AUSPOL_SEAT_POLL_MATCH=perpoll is built for AUSPOL_SEAT_POLL_BLEND=1 only")
    return(.seat_poll_blend_split(shares, tb, w, target_election))
  }
  tb_type <- tb
  # Mode 1 (v50): one weight on the mean over every poll, MRP or direct.
  tb <- tb[, list(poll = sum(poll * n_polls) / sum(n_polls), n_polls = sum(n_polls), n_mrp = sum(n_mrp)),
           by = list(seat, class)]
  if (perpoll) {
    # Not yet in the shipped table the daily run reads: backtests only until
    # it ships (plans/prereg-seat-poll-per-poll-match-2026-09-29.md).
    our <- data.table::data.table(seat = rep(rownames(shares), ncol(shares)),
                                  class = rep(colnames(shares), each = nrow(shares)),
                                  share = as.vector(shares))
    tb <- seat_poll_implied(seat_poll_shares(target_election, by_poll = TRUE), our)
    cat(sprintf("SPB1 %s: per-poll match, %d implied cells\n", target_election, nrow(tb)))
  }
  wvec <- rep(w$w, nrow(tb))
  if (ind_on && nrow(tb)) {
    ik <- .ind_direct_cells(tb, tb_type)
    tb$poll[ik$row] <- ik$poll
    wvec[ik$row] <- w$w_ind
    cat(sprintf("SPIW %s: IND weight %.3f (raw %.3f, se %.3f, %d earlier direct IND cells; class-blind %.3f); %d IND cells on a direct poll\n",
                target_election, w$w_ind, w$w_ind_raw, w$w_ind_se, w$w_ind_n, w$w, length(ik$row)))
  }
  if (!nrow(tb) || (w$w <= 0 && !(ind_on && is.finite(w$w_ind) && w$w_ind > 0))) {
    cat(sprintf("SPB  %s: no blend (w %.3f from %d earlier polled cells in %d elections; %d polled cells here)\n",
                target_election, w$w, w$n, w$k, nrow(tb)))
    return(shares)
  }
  i <- match(normalise_seat(tb$seat), normalise_seat(rownames(shares)))
  j <- match(tb$class, colnames(shares))
  ok <- !is.na(i) & !is.na(j)
  ok[ok] <- shares[cbind(i[ok], j[ok])] > 0
  before <- shares
  shares[cbind(i[ok], j[ok])] <- shares[cbind(i[ok], j[ok])] + wvec[ok] * (tb$poll[ok] - shares[cbind(i[ok], j[ok])])
  shares <- 100 * shares / rowSums(shares)
  cat(sprintf("SPB  %s: w %.3f (raw %.3f, se %.3f, %d cells in %d earlier elections); %d of %d polled cells applied across %d seats (%d MRP-only); mean |change| %.2f points\n",
              target_election, w$w, w$raw, w$se, w$n, w$k, sum(ok), nrow(tb),
              length(unique(i[ok])), sum(tb$n_mrp[ok] == tb$n_polls[ok]),
              mean(abs(shares - before)[unique(i[ok]), , drop = FALSE])))
  shares
}

#' Separate, partially pooled seat-poll weights for MRP and direct polls
#'
#' Pooled `w` from [seat_poll_weight()] is the prior. Each type's own estimate
#' `b_t` (SE clustered on seat-election) moves it by `k_t = tau^2/(tau^2+se_t^2)`,
#' `tau^2 = max(0, (b_d-b_m)^2/2 - (se_d^2+se_m^2)/2)`; a type with no earlier
#' cells keeps the pooled weight. docs/plans/prereg-seat-poll-mrp-split-2026-09-29.md.
#'
#' @param target_election Label such as `"fed2025"`.
#' @return list: `pooled` (as [seat_poll_weight()]), `direct` and `mrp`
#'   (each `w`, `b`, `se`, `n`, `k`).
#' @export
seat_poll_weights_split <- function(target_election) {
  pooled <- seat_poll_weight(target_election)
  f <- current_seat_predictions()
  els <- unique(f$election)
  els <- els[elections_before(els, target_election)]
  rows <- data.table::rbindlist(lapply(els, function(e) {
    sp <- seat_poll_shares(e, by_type = TRUE)
    if (!nrow(sp)) return(NULL)
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party,
                                  pred = xgb_pred_seat, actual = actual_share)]
    sp$seat <- normalise_seat(sp$seat)
    m <- merge(sp, fe, by = c("seat", "class"))
    m <- m[is.finite(pred) & is.finite(actual) & pred > 0]
    if (!nrow(m)) return(NULL)
    m$unit <- paste(e, m$seat)
    m
  }), fill = TRUE)
  est <- function(tp) {
    r <- if (nrow(rows)) rows[rows$type == tp] else rows
    if (!nrow(r)) return(list(b = NA_real_, se = NA_real_, n = 0L))
    dx <- r$poll - r$pred; dy <- r$actual - r$pred
    b <- sum(dx * dy) / sum(dx^2); e <- dy - b * dx
    G <- length(unique(r$unit))
    se2 <- sum(tapply(dx * e, r$unit, sum)^2) / sum(dx^2)^2 * .cluster_df(G)
    list(b = b, se = sqrt(se2), n = nrow(r))
  }
  d <- est("direct"); m <- est("mrp")
  tau2 <- if (is.finite(d$b) && is.finite(m$b)) max(0, (d$b - m$b)^2 / 2 - (d$se^2 + m$se^2) / 2) else 0
  pool_one <- function(x) {
    if (!is.finite(x$b)) return(c(x, list(w = pooled$w, k = 0)))
    k <- tau2 / (tau2 + x$se^2)
    c(x, list(w = min(1, max(0, pooled$w + k * (x$b - pooled$w))), k = k))
  }
  list(pooled = pooled, direct = pool_one(d), mrp = pool_one(m), tau2 = tau2)
}

.seat_poll_blend_split <- function(shares, tb, w, target_election) {
  if (!nrow(tb)) {
    cat(sprintf("SPB2 %s: no polled cells (w_direct %.3f, w_mrp %.3f)
", target_election, w$w_direct, w$w_mrp))
    return(shares)
  }
  before <- shares
  base <- shares
  i <- match(normalise_seat(tb$seat), normalise_seat(rownames(shares)))
  j <- match(tb$class, colnames(shares))
  ok <- !is.na(i) & !is.na(j)
  ok[ok] <- base[cbind(i[ok], j[ok])] > 0
  wt <- ifelse(tb$type == "mrp", w$w_mrp, w$w_direct)
  if (.ind_weight_on()) {
    wt[tb$class == "IND" & tb$type == "direct"] <- w$w_ind
    cat(sprintf("SPIW %s: IND weight %.3f (raw %.3f, se %.3f, %d earlier direct IND cells; direct %.3f)\n",
                target_election, w$w_ind, w$w_ind_raw, w$w_ind_se, w$w_ind_n, w$w_direct))
  }
  # Both types move from the SAME pre-blend share, so the order is irrelevant.
  for (r in which(ok)) {
    shares[i[r], j[r]] <- shares[i[r], j[r]] + wt[r] * (tb$poll[r] - base[i[r], j[r]])
  }
  shares <- pmax(shares, 0)
  shares <- 100 * shares / rowSums(shares)
  cat(sprintf("SPB2 %s: w_direct %.3f, w_mrp %.3f (pooled %.3f); applied %d direct and %d MRP cells across %d seats; mean |change| %.2f points
",
              target_election, w$w_direct, w$w_mrp, w$w, sum(ok & tb$type == "direct"), sum(ok & tb$type == "mrp"),
              length(unique(i[ok])), mean(abs(shares - before)[unique(i[ok]), , drop = FALSE])))
  shares
}

#' Small-sample factor for a cluster-robust variance, G clusters
#'
#' `G / (G - 1)`. With ONE cluster the sandwich has nothing to compare and its
#' score sum is ~0 by construction, so the old `G / max(1, G - 1)` returned a
#' near-zero SE and the shrinkage passed the slope through untouched: fed2019's
#' blend weight was 1.000, fitted on fed2016's single polled seat (Mayo),
#' against a hindsight-best 0.29. One cluster is no information: `Inf`, so the
#' shrunk weight is 0. `AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER="legacy"` restores the
#' old factor (screening only).
#' @keywords internal
.cluster_df <- function(G) {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER", "none")
  if (!v %in% c("none", "legacy")) stop("AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER must be \"none\" or \"legacy\", not ", v)
  if (v == "legacy") return(G / max(1, G - 1))
  if (G < 2) Inf else G / (G - 1)
}

.ind_weight_on <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_IND_WEIGHT", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_IND_WEIGHT must be \"0\" or \"1\", not ", v)
  v == "1"
}

#' Seat-poll rows as read from disk, plus the hand-keyed primaries when asked
#'
#' `AUSPOL_SEAT_POLL_HANDKEYED` "1" appends
#' `external/reference/polls/seat-polls/hand_keyed_primaries.csv`: primaries the
#' Wikipedia tables lack (Mayo fed2016, Wakehurst nsw2023), each row carrying a
#' `source` column. Same columns as the fetcher's file, so every reader treats
#' them alike.
#' @keywords internal
.read_seat_polls_file <- function(f) {
  s <- .seat_poll_coalition_dedup(data.table::fread(f, showProgress = FALSE))
  v <- Sys.getenv("AUSPOL_SEAT_POLL_HANDKEYED", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_HANDKEYED must be \"0\" or \"1\", not ", v)
  if (v == "0") return(s)
  hf <- file.path(dirname(f), "hand_keyed_primaries.csv")
  if (!file.exists(hf)) stop("AUSPOL_SEAT_POLL_HANDKEYED=1 but ", hf, " is missing")
  h <- data.table::fread(hf, showProgress = FALSE)
  if (!nrow(h) || anyNA(h$source) || any(!nzchar(h$source))) stop(hf, " must have rows, each with a source")
  cat(sprintf("SPHK hand-keyed seat-poll rows appended: %d (%s)\n", nrow(h),
              paste(unique(paste(h$election, h$seat_name)), collapse = ", ")))
  h$source <- NULL
  data.table::rbindlist(list(s, h), use.names = TRUE, fill = TRUE)
}

# A complete poll's primaries sum to 100 within this many points (rounding).
# docs/CONSTANTS.md.
SEAT_POLL_TOTAL_TOL <- 5

#' Drop a Coalition figure the fetcher copied from a merged Lib/Nat cell
#'
#' `rvest::html_table(fill = TRUE)` repeats a merged ("colspan") cell in every
#' column it spans. Wikipedia's fed2022 YouGov table gives Nicholls one
#' Coalition figure across its Lib and Nat columns, so the file holds Lib 41
#' AND Nat 41, the poll sums to 141 and our LNP class read 82 (published
#' 55.3 against an actual 44.2). A poll's Nat row is dropped when it equals
#' the Lib row, the poll's total is above 105 with both, and 95 to 105
#' without one. Genuine three-cornered contests (Bullwinkel fed2025: Lib 41,
#' Nat 22) differ and are kept. `AUSPOL_SEAT_POLL_COALITION_DEDUP`; every drop
#' is printed (SPCD).
#' @keywords internal
.seat_poll_coalition_dedup <- function(s) {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_COALITION_DEDUP", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_COALITION_DEDUP must be \"0\" or \"1\", not ", v)
  # A file without the poll columns is not a seat-poll table; leave it to the caller.
  if (v == "0" || !nrow(s) || !all(c("election", "seat", "pollster", "date_raw", "party", "fp", "row_type") %in% names(s))) return(s)
  pid <- paste(s$election, s$seat, s$pollster, s$date_raw, sep = " | ")
  pty <- toupper(trimws(s$party))
  isp <- s$row_type == "poll" & is.finite(s$fp)
  tot <- tapply(s$fp[isp], pid[isp], sum)
  lib <- isp & pty == "LIB"
  nat <- isp & pty == "NAT"
  lib_fp <- s$fp[lib][match(pid, pid[lib])]
  drop <- nat & is.finite(lib_fp) & s$fp == lib_fp
  t_both <- tot[pid]
  tol <- SEAT_POLL_TOTAL_TOL
  drop <- drop & !is.na(t_both) & t_both > 100 + tol & abs(t_both - s$fp - 100) <= tol
  for (k in which(drop)) cat(sprintf("SPCD %s: Nat %.1f duplicates Lib (merged cell); poll total %.1f -> %.1f
",
                                     pid[k], s$fp[k], t_both[[k]], t_both[[k]] - s$fp[k]))
  s[!drop]
}

# Minimum poll OTH figure (points) for it to be read as a named independent.
# docs/CONSTANTS.md. A genuine catch-all OTH in these polls is typically 2-8.
SEAT_POLL_IND_MAP_MIN_OTH <- 10
# Skip the remap when one of our non-major classes already has this fraction of
# the poll's OTH figure. 0.5: Kennedy (45 vs 43) and Bass (5.9 vs 10) skip;
# Goldstein (4.9 vs 24) and Mackellar (4.4 vs 23) remap. docs/CONSTANTS.md.
SEAT_POLL_IND_MAP_KNOWN_FRAC <- 0.5

#' Move a poll's OTH figure to IND where the poll leaves IND blank
#'
#' Applies to one poll in one seat when: no finite IND figure in that poll,
#' the summed OTH figure is at least `SEAT_POLL_IND_MAP_MIN_OTH`, and the
#' election's candidate list (names only, no votes) has an IND candidate in
#' the seat. Every remapped cell is printed (SPIM).
#' @param s Poll rows with `class`, `poll_id`, `seat_name`, `fp`.
#' @param election Label.
#' @keywords internal
.seat_poll_ind_map <- function(s, election) {
  cf <- out_path("candidacies.csv")
  if (!file.exists(cf)) stop("AUSPOL_SEAT_POLL_IND_MAP=1 needs ", cf)
  C <- data.table::fread(cf, showProgress = FALSE, select = c("election", "seat", "party"))
  el <- election
  ind_seats <- unique(normalise_seat(C$seat[C$election == el & C$party == "IND"]))
  has_ind <- tapply(s$class == "IND" & is.finite(s$fp), s$poll_id, any)
  oth_fp <- tapply(ifelse(s$class == "OTH" & is.finite(s$fp), s$fp, 0), s$poll_id, sum)
  cand <- names(oth_fp)[!has_ind[names(oth_fp)] & oth_fp >= SEAT_POLL_IND_MAP_MIN_OTH]
  seat_of <- s$seat_name[match(cand, s$poll_id)]
  cand <- cand[normalise_seat(seat_of) %in% ind_seats]
  # CREDIBLE CONTENDER ONLY (Amendment 1, Pete 2026-10-06): the remap fired on polls
  # whose OTH was not an independent (fed2025 McMahon 9.3 -> 23.5, actual 9.8; fed2022
  # Richmond, Parkes, Lyne). Remap only where pre-election evidence says the seat's
  # independent is a real contender: endorsed (Climate 200 or a Voices group,
  # output/endorsement-features.csv) or the sitting independent member (elected IND
  # at the previous election in that seat).
  ef <- out_path("endorsement-features.csv")
  endorsed <- if (file.exists(ef)) {
    E <- data.table::fread(ef, showProgress = FALSE)
    unique(normalise_seat(E$seat[E$pair == el & E$party == "IND" & (E$c200 %in% 1 | E$voices %in% 1)]))
  } else {
    cat(sprintf("SPIM! %s: %s missing -- no seat counts as endorsed, so only sitting independents can be remapped\n", el, ef))
    character(0)
  }
  pr <- Filter(function(p) identical(p$election, el), all_election_pairs())
  sitting <- if (length(pr)) {
    Cp <- data.table::fread(cf, showProgress = FALSE, select = c("election", "seat", "party", "elected"))
    unique(normalise_seat(Cp$seat[Cp$election == pr[[1]]$prev & Cp$party == "IND" & Cp$elected %in% TRUE]))
  } else character(0)
  sn0 <- normalise_seat(s$seat_name[match(cand, s$poll_id)])
  cred <- sn0 %in% c(endorsed, sitting)
  for (id in cand[!cred]) cat(sprintf("SPIM %s %s | %s | OTH %.1f NOT remapped: independent not endorsed and not sitting\n",
                                      el, s$seat_name[match(id, s$poll_id)], id, oth_fp[id]))
  cand <- cand[cred]
  # A non-independent candidate the model already knows explains a big OTH:
  # Katter's 43 in Kennedy 2022 (our OTH_RIGHT pred 45). Skip the seat when any
  # one non-major class of ours (OTH, OTH_RIGHT, ONP) already carries at least
  # SEAT_POLL_IND_MAP_KNOWN_FRAC of the poll's OTH figure. as-at predictions
  # only, so nothing from the target election's result.
  f <- current_seat_predictions()
  if (!is.null(f) && any(f$election == el) && length(cand)) {
    fe <- f[f$election == el & f$party %in% c("OTH", "OTH_RIGHT", "ONP")]
    fe$seat <- normalise_seat(fe$seat)
    big <- tapply(fe$xgb_pred_seat, fe$seat, max)
    sn <- normalise_seat(s$seat_name[match(cand, s$poll_id)])
    known <- !is.na(big[sn]) & big[sn] >= SEAT_POLL_IND_MAP_KNOWN_FRAC * oth_fp[cand]
    for (id in cand[known]) cat(sprintf("SPIM %s %s | %s | OTH %.1f NOT remapped: known non-major class pred %.1f\n",
                                        el, s$seat_name[match(id, s$poll_id)], id, oth_fp[id], big[sn[match(id, cand)]]))
    cand <- cand[!known]
  } else if (length(cand)) {
    cat(sprintf("SPIM %s: no as-at predictions, known-candidate exclusion not applied\n", el))
  }
  if (length(cand)) {
    hit <- which(s$class == "OTH" & s$poll_id %in% cand & is.finite(s$fp))
    for (r in hit) cat(sprintf("SPIM %s %s | %s | OTH %.1f -> IND\n", election, s$seat_name[r], s$poll_id[r], s$fp[r]))
    s$class[hit] <- "IND"
  }
  .seat_poll_known_class_map(s, el, f)
}

# A poll that files a KNOWN non-independent minor under OTH (Katter in Kennedy
# 2022: YouGov MRP OTH 43, KAP is our OTH_RIGHT) left the KAP cell polled at
# only the UAP's 6, and once the fed2022 blend weight rose (Mayo 2016 added) the
# blend pulled OTH_RIGHT to 19.5 (actual 46.1). The poll's OTH lumps together
# whatever it does not name, so split it across OTH_RIGHT, ONP and OTH in
# proportion to the share our as-at prediction expects of each BEYOND what the
# poll already reports for that class. Kennedy: OTH_RIGHT expects 44.7, the
# poll names 6, OTH expects ~0, so ~all of the 43 goes to OTH_RIGHT. Only where
# a named class's unreported share is at least SEAT_POLL_IND_MAP_KNOWN_FRAC of
# the OTH figure (a dominant known minor, not a scatter of small parties).
# As-at predictions only (current_seat_predictions()), so nothing from the result.
.seat_poll_known_class_map <- function(s, el, f = current_seat_predictions()) {
  if (is.null(f) || !any(f$election == el)) return(s)
  lump <- c("OTH_RIGHT", "ONP", "OTH")
  fe <- f[f$election == el & f$party %in% lump]
  if (!nrow(fe)) return(s)
  fe$seat <- normalise_seat(fe$seat)
  add <- list(); drop <- integer(0)
  for (id in unique(s$poll_id)) {
    r_oth <- which(s$poll_id == id & s$class == "OTH" & is.finite(s$fp))
    if (length(r_oth) != 1L || s$fp[r_oth] < SEAT_POLL_IND_MAP_MIN_OTH) next
    oth_fig <- s$fp[r_oth]
    fs <- fe[fe$seat == normalise_seat(s$seat_name[r_oth])]
    if (!nrow(fs)) next
    pred <- vapply(lump, function(k) sum(fs$xgb_pred_seat[fs$party == k], na.rm = TRUE), numeric(1))
    named <- vapply(lump, function(k) if (k == "OTH") 0 else
      sum(s$fp[s$poll_id == id & s$class == k & is.finite(s$fp)]), numeric(1))
    resid <- pmax(pred - named, 0)
    if (max(resid[c("OTH_RIGHT", "ONP")]) < SEAT_POLL_IND_MAP_KNOWN_FRAC * oth_fig) next
    part <- oth_fig * resid / sum(resid)
    cat(sprintf("SPIM %s %s | %s | OTH %.1f split by as-at expectation: OTH_RIGHT %.1f, ONP %.1f, OTH %.1f\n",
                el, s$seat_name[r_oth], id, oth_fig, part[["OTH_RIGHT"]], part[["ONP"]], part[["OTH"]]))
    for (k in lump[part > 0]) {
      row <- s[r_oth]; row$class <- k; row$fp <- part[[k]]
      add[[length(add) + 1L]] <- row
    }
    drop <- c(drop, r_oth)
  }
  if (!length(drop)) return(s)
  rbind(s[-drop], data.table::rbindlist(add))
}

#' Direct-poll IND cells of a by-type blend table
#'
#' @param tb Pooled table (`seat`, `class`, `poll`, ...).
#' @param tb_type By-type table (`seat`, `class`, `type`, `poll`).
#' @return list `row` (rows of `tb`) and `poll` (mean over direct polls).
#' @keywords internal
.ind_direct_cells <- function(tb, tb_type) {
  d <- tb_type[tb_type$class == "IND" & tb_type$type == "direct"]
  row <- match(paste(d$seat, d$class), paste(tb$seat, tb$class))
  keep <- !is.na(row)
  list(row = row[keep], poll = d$poll[keep])
}

#' IND-specific seat-poll blend weight, time-forward and partially pooled
#'
#' Per earlier election `e` and class `c`, the least-squares slope `b_ec` of
#' `actual - pred` on `poll - pred` over DIRECT-poll cells with a named
#' candidate (`pred > 0`) (groups of at least 3 cells), SE clustered on seat.
#' The class effect is `d_ec = b_ec - b_e`, where `b_e` is election `e`'s slope
#' over all classes: election-wide swings in how far polls should be trusted
#' (fed2022 high, fed2025 low) are the class-blind weight's business, not
#' IND's. `tau^2 = max(0, mean(d_ec^2 - se_ec^2))` over all groups is how far a
#' class's own slope genuinely strays from its election's; IND's precision-
#' weighted mean `dbar` (SE `se_d`) moves the class-blind weight
#' [seat_poll_weight()] by `k = tau^2 / (tau^2 + se_d^2)`:
#' `w = w0 + k * dbar`, clamped to 0..1. No IND group of 3+ cells, or fewer
#' than 3 groups to estimate `tau^2` from, keeps `w0`.
#'
#' @param target_election Label such as `"fed2022"`.
#' @return list `w`, `raw` (IND's own pooled slope over earlier cells), `se`
#'   (of `dbar`), `n` (earlier IND direct cells), `k` (earlier elections with
#'   an IND group), `w0`, `dbar`, `tau2`, `shrink_k`.
#' @export
seat_poll_ind_weight <- function(target_election) {
  pooled <- seat_poll_weight(target_election)
  f <- current_seat_predictions()
  if (is.null(f)) stop("seat_poll_ind_weight needs this rebuild's as-at predictions")
  els <- unique(f$election)
  els <- els[elections_before(els, target_election)]
  rows <- data.table::rbindlist(lapply(els, function(e) {
    sp <- seat_poll_shares(e, by_type = TRUE)
    if (!nrow(sp)) return(NULL)
    sp <- sp[sp$type == "direct"]
    if (!nrow(sp)) return(NULL)
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party,
                                  pred = xgb_pred_seat, actual = actual_share)]
    sp$seat <- normalise_seat(sp$seat)
    m <- merge(sp, fe, by = c("seat", "class"))
    m <- m[is.finite(pred) & is.finite(actual) & pred > 0]
    if (!nrow(m)) return(NULL)
    m$el <- e
    m
  }), fill = TRUE)
  w0 <- pooled$w
  none <- list(w = w0, raw = NA_real_, se = NA_real_, n = 0L, k = 0L, w0 = w0,
               dbar = NA_real_, tau2 = NA_real_, shrink_k = 0)
  if (is.null(rows) || !nrow(rows)) return(none)
  none$n <- sum(rows$class == "IND")
  slope <- function(r) {
    dx <- r$poll - r$pred; dy <- r$actual - r$pred
    if (nrow(r) < 3L || sum(dx^2) <= 0) return(NULL)
    b <- sum(dx * dy) / sum(dx^2); e <- dy - b * dx
    G <- length(unique(r$seat))
    list(b = b, se2 = sum(tapply(dx * e, r$seat, sum)^2) / sum(dx^2)^2 * .cluster_df(G))
  }
  g <- list()
  for (e in unique(rows$el)) {
    re <- rows[rows$el == e]
    be <- slope(re)
    if (is.null(be)) next
    for (cl in unique(re$class)) {
      bc <- slope(re[re$class == cl])
      if (!is.null(bc)) g[[length(g) + 1L]] <- data.table::data.table(el = e, class = cl, n = sum(re$class == cl),
                                                                     d = bc$b - be$b, se2 = bc$se2, b = bc$b)
    }
  }
  if (!length(g)) return(none)
  g <- data.table::rbindlist(g)
  gi <- g[g$class == "IND"]
  if (nrow(g) < 3L || !nrow(gi)) return(none)
  tau2 <- max(0, mean(g$d^2 - g$se2))
  wt <- 1 / pmax(gi$se2, 1e-6)
  dbar <- sum(wt * gi$d) / sum(wt)
  se_d2 <- 1 / sum(wt)
  k <- if (tau2 + se_d2 > 0) tau2 / (tau2 + se_d2) else 0
  ri <- rows[rows$class == "IND"]
  dx <- ri$poll - ri$pred; dy <- ri$actual - ri$pred
  list(w = min(1, max(0, w0 + k * dbar)), raw = sum(dx * dy) / sum(dx^2), se = sqrt(se_d2), n = nrow(ri),
       k = nrow(gi), w0 = w0, dbar = dbar, tau2 = tau2, shrink_k = k)
}

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
  s <- data.table::fread(f, showProgress = FALSE)
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
  se2 <- sum(tapply(dx * e, rows$unit, sum)^2) / sum(dx^2)^2 * G / max(1, G - 1)
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
    tb <- seat_poll_shares(target_election, by_type = TRUE)
    if (write) {
      out <- data.table::copy(tb)
      if (!nrow(out)) out <- data.table::data.table(seat = NA_character_, class = NA_character_, type = NA_character_,
                                                    poll = NA_real_, n_polls = NA_integer_, n_mrp = NA_integer_)
      out$w <- w$w; out$w_raw <- w$raw; out$w_se <- w$se; out$w_n <- w$n; out$w_k <- w$k
      out$w_direct <- w$w_direct; out$w_mrp <- w$w_mrp
      data.table::fwrite(out, cache)
    }
  } else if (file.exists(cache)) {
    raw <- data.table::fread(cache, showProgress = FALSE)
    if (length(unique(raw$w)) != 1L) stop(cache, " has more than one weight")
    w <- list(w = raw$w[1], raw = raw$w_raw[1], se = raw$w_se[1], n = raw$w_n[1], k = raw$w_k[1],
              w_direct = raw$w_direct[1], w_mrp = raw$w_mrp[1])
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
  mode <- Sys.getenv("AUSPOL_SEAT_POLL_BLEND", "0")
  if (!mode %in% c("1", "2")) return(shares)
  tb <- seat_poll_blend_table(target_election)
  w <- attr(tb, "w")
  perpoll <- identical(Sys.getenv("AUSPOL_SEAT_POLL_MATCH", "class"), "perpoll")
  if (mode == "2") {
    if (perpoll) stop("AUSPOL_SEAT_POLL_MATCH=perpoll is built for AUSPOL_SEAT_POLL_BLEND=1 only")
    return(.seat_poll_blend_split(shares, tb, w, target_election))
  }
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
  if (!nrow(tb) || w$w <= 0) {
    cat(sprintf("SPB  %s: no blend (w %.3f from %d earlier polled cells in %d elections; %d polled cells here)\n",
                target_election, w$w, w$n, w$k, nrow(tb)))
    return(shares)
  }
  i <- match(normalise_seat(tb$seat), normalise_seat(rownames(shares)))
  j <- match(tb$class, colnames(shares))
  ok <- !is.na(i) & !is.na(j)
  ok[ok] <- shares[cbind(i[ok], j[ok])] > 0
  before <- shares
  shares[cbind(i[ok], j[ok])] <- shares[cbind(i[ok], j[ok])] + w$w * (tb$poll[ok] - shares[cbind(i[ok], j[ok])])
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
    se2 <- sum(tapply(dx * e, r$unit, sum)^2) / sum(dx^2)^2 * G / max(1, G - 1)
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

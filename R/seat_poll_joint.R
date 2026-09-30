#' Seat polls' two-party figures, per seat, for one election
#'
#' Labor's share of Labor-vs-Coalition two-party figures in seat polls whose
#' fieldwork ended within `days` before polling day, averaged over polls
#' (a Coalition figure is flipped). plans/prereg-seat-poll-joint-fp-tpp-2026-09-30.md.
#'
#' @param election Label such as `"nsw2023"`.
#' @param days Fieldwork window.
#' @return data.table `seat`, `tpp_poll`, `n_tpp`.
#' @export
seat_poll_tpp <- function(election, days = 90) {
  empty <- data.table::data.table(seat = character(0), tpp_poll = numeric(0), n_tpp = integer(0))
  f <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")
  if (!file.exists(f)) return(empty)
  s <- data.table::fread(f, showProgress = FALSE)
  el_arg <- election
  ed <- as.Date(unname(election_dates()[el_arg]))
  keep <- s$election == el_arg & s$row_type == "poll" & is.finite(s$tcp_a) &
    !is.na(s$fieldwork_end) & as.Date(s$fieldwork_end) < ed & as.Date(s$fieldwork_end) >= ed - days
  s <- s[which(keep)]
  if (!nrow(s)) return(empty)
  coal <- c("L/NP", "LIB", "LNP", "NAT", "LP", "NP", "CLP")
  a <- toupper(trimws(s$tcp_party_a)); b <- toupper(trimws(s$tcp_party_b))
  alp_share <- ifelse(a == "ALP" & b %in% coal, s$tcp_a,
               ifelse(a %in% coal & b == "ALP", 100 - s$tcp_a, NA_real_))
  s$alp_tpp <- alp_share
  s$poll_id <- paste(s$seat_name, s$pollster, s$date_raw)
  pp <- unique(s[is.finite(s$alp_tpp), list(seat = seat_name, poll_id, alp_tpp)])
  if (!nrow(pp)) return(empty)
  pp[, list(tpp_poll = mean(alp_tpp), n_tpp = .N), by = seat]
}

#' Our Labor two-party estimate per seat from primaries and earlier flows
#'
#' `(ALP + sum_p s_p f_p (1 - e_p)) / (ALP + LNP + sum_p s_p (1 - e_p))`, with
#' each other class's flow to Labor `f_p` and exhaust `e_p` from
#' [flows_for()] over flows observed at elections dated BEFORE the target
#' ([elections_before()]; the target's own flows would leak). IND and OTH_RIGHT take the OTH flow when the
#' region has none of their own.
#'
#' @param d data.table `seat`, `class`, `share` for one election.
#' @param region,year The target.
#' @return data.table `seat`, `tpp_ours`.
#' @keywords internal
.our_seat_tpp <- function(d, region, year) {
  # Time-forward BY DATE (Pete, 2026-09-30: "can't we use dates not years"):
  # keep only flows observed at elections dated before the target, the same
  # test every other time-forward fit uses, then take the latest per party.
  all_fl <- load_preference_flows()
  target_lab <- paste0(region, year)
  before <- elections_before(paste0(all_fl$region, all_fl$year), target_lab)
  fl <- suppressMessages(flows_for(all_fl[which(before), ], year, region, quiet = TRUE))
  fr <- function(p, col) {
    k <- match(p, fl$party)
    if (is.na(k)) k <- match("OTH", fl$party)
    if (is.na(k)) return(if (col == "flow_alp") 50 else 0)
    v <- fl[[col]][k]; if (is.finite(v)) v else if (col == "flow_alp") 50 else 0
  }
  d <- data.table::copy(d)
  d$f <- vapply(d$class, fr, 1, col = "flow_alp") / 100
  d$e <- vapply(d$class, fr, 1, col = "exhaust") / 100
  d$f[d$class == "ALP"] <- 1; d$e[d$class == "ALP"] <- 0
  d$f[d$class == "LNP"] <- 0; d$e[d$class == "LNP"] <- 0
  d[, list(tpp_ours = 100 * sum(share * f * (1 - e)) / sum(share * (1 - e))), by = seat]
}

#' Joint time-forward weights for seat polls' primary and two-party gaps
#'
#' On earlier elections' polled cells: `actual - pred = b1 * (poll primary -
#' pred) + b2 * s * (poll two-party - our two-party)`, s = +1 Labor, -1
#' Coalition, 0 otherwise; a missing figure contributes 0. Through the origin,
#' SE clustered on seat-election, each coefficient shrunk `b^3/(b^2+se^2)` and
#' clamped to [0, 1]. Pete, 2026-09-30: let the fit decide the weight of each.
#'
#' @param target_election Label such as `"nsw2023"`.
#' @return list `w1`, `w2`, `b`, `se`, `n` (cells), `k` (elections).
#' @export
seat_poll_weights_joint <- function(target_election) {
  f <- current_seat_predictions()
  if (is.null(f)) stop("seat_poll_weights_joint needs this rebuild's as-at predictions")
  els <- unique(f$election)
  els <- els[elections_before(els, target_election)]
  rows <- data.table::rbindlist(lapply(els, function(e) {
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party, pred = xgb_pred_seat, actual = actual_share)]
    sp <- seat_poll_shares(e); tp <- seat_poll_tpp(e)
    if (!nrow(sp) && !nrow(tp)) return(NULL)
    sp$seat <- normalise_seat(sp$seat); tp$seat <- normalise_seat(tp$seat)
    polled <- union(sp$seat, tp$seat)
    m <- fe[fe$seat %in% polled & is.finite(fe$pred) & fe$pred > 0]
    m <- merge(m, sp[, list(seat, class, poll)], by = c("seat", "class"), all.x = TRUE)
    ot <- .our_seat_tpp(m[, list(seat, class, share = pred)], sub("[0-9]{4}$", "", e), as.integer(sub("^[a-z]+", "", e)))
    m <- merge(merge(m, tp[, list(seat, tpp_poll)], by = "seat", all.x = TRUE), ot, by = "seat", all.x = TRUE)
    sgn <- ifelse(m$class == "ALP", 1, ifelse(m$class == "LNP", -1, 0))
    m$dx1 <- ifelse(is.finite(m$poll), m$poll - m$pred, 0)
    m$dx2 <- ifelse(is.finite(m$tpp_poll) & is.finite(m$tpp_ours), sgn * (m$tpp_poll - m$tpp_ours), 0)
    m$dy <- m$actual - m$pred
    m$unit <- paste(e, m$seat); m$el <- e
    m[m$dx1 != 0 | m$dx2 != 0]
  }), fill = TRUE)
  zero <- list(w1 = 0, w2 = 0, b = c(NA_real_, NA_real_), se = c(NA_real_, NA_real_), n = nrow(rows), k = 0L)
  if (nrow(rows) < 10) return(zero)
  X <- cbind(rows$dx1, rows$dx2); y <- rows$dy
  use <- colSums(X != 0) > 0
  b <- se <- c(0, 0)
  Xu <- X[, use, drop = FALSE]
  XtX <- crossprod(Xu)
  bu <- solve(XtX, crossprod(Xu, y))
  res <- y - Xu %*% bu
  G <- tapply(seq_along(y), rows$unit, function(i) crossprod(Xu[i, , drop = FALSE], res[i]), simplify = FALSE)
  meat <- Reduce(`+`, lapply(G, function(g) g %*% t(g)))
  V <- solve(XtX) %*% meat %*% solve(XtX) * length(G) / max(1, length(G) - 1)
  b[use] <- as.vector(bu); se[use] <- sqrt(diag(V))
  shrink <- function(bb, ss) if (!is.finite(ss) || ss <= 0) 0 else min(1, max(0, bb * bb^2 / (bb^2 + ss^2)))
  list(w1 = shrink(b[1], se[1]), w2 = if (use[2]) shrink(b[2], se[2]) else 0, b = b, se = se,
       n = nrow(rows), k = length(unique(rows$el)))
}

#' Blend mode 3: primary and two-party seat-poll gaps with jointly fitted weights
#'
#' @param shares Matrix of primary shares, rownames = seats, colnames = classes.
#' @param target_election Label such as `"nsw2023"`.
#' @param w The [seat_poll_weights_joint()] list.
#' @param sp,tp Primary cells ([seat_poll_shares()]) and two-party polls ([seat_poll_tpp()]).
#' @return `shares`, blended, each row rescaled to 100.
#' @keywords internal
.seat_poll_blend_joint <- function(shares, target_election, w, sp, tp) {
  before <- shares
  seats_n <- normalise_seat(rownames(shares))
  if (nrow(sp) && w$w1 > 0) {
    i <- match(normalise_seat(sp$seat), seats_n); j <- match(sp$class, colnames(shares))
    ok <- !is.na(i) & !is.na(j); ok[ok] <- shares[cbind(i[ok], j[ok])] > 0
    shares[cbind(i[ok], j[ok])] <- shares[cbind(i[ok], j[ok])] + w$w1 * (sp$poll[ok] - shares[cbind(i[ok], j[ok])])
  }
  n_tpp <- 0L
  if (nrow(tp) && w$w2 > 0 && all(c("ALP", "LNP") %in% colnames(shares))) {
    d <- data.table::data.table(seat = rep(rownames(before), ncol(before)),
                                class = rep(colnames(before), each = nrow(before)), share = as.vector(before))
    ot <- .our_seat_tpp(d, sub("[0-9]{4}$", "", target_election), as.integer(sub("^[a-z]+", "", target_election)))
    ot$k <- normalise_seat(ot$seat)
    for (r in seq_len(nrow(tp))) {
      i <- match(normalise_seat(tp$seat[r]), seats_n); if (is.na(i)) next
      g <- tp$tpp_poll[r] - ot$tpp_ours[match(seats_n[i], ot$k)]
      if (!is.finite(g) || shares[i, "ALP"] <= 0 || shares[i, "LNP"] <= 0) next
      adj <- w$w2 * g
      shares[i, "ALP"] <- max(0, shares[i, "ALP"] + adj); shares[i, "LNP"] <- max(0, shares[i, "LNP"] - adj)
      n_tpp <- n_tpp + 1L
    }
  }
  shares <- 100 * shares / rowSums(shares)
  cat(sprintf("SPB3 %s: joint weights w_primary %.3f (raw %.3f, se %.3f), w_twoparty %.3f (raw %.3f, se %.3f); %d cells in %d earlier elections; %d primary cells, %d two-party seats applied; mean |change| %.2f\n",
              target_election, w$w1, w$b[1], w$se[1], w$w2, w$b[2], w$se[2], w$n, w$k,
              nrow(sp), n_tpp, mean(abs(shares - before))))
  shares
}

#' Mode-3 inputs for one target, computed or shipped
#'
#' The daily run has no poll file or as-at predictions, so the promote step
#' writes `output/seat-poll-joint-<target>.csv` (primary cells, the two-party
#' polls as class "@TPP", and the two weights).
#' @param target_election Label such as `"vic2026"`.
#' @param write Write the shipped table.
#' @return list `w`, `sp`, `tp`.
#' @export
seat_poll_joint_table <- function(target_election, write = FALSE) {
  src <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")
  cache <- out_path(sprintf("seat-poll-joint-%s.csv", target_election))
  if (file.exists(src) && .has_seat_predictions()) {
    w <- seat_poll_weights_joint(target_election)
    sp <- seat_poll_shares(target_election)
    tp <- seat_poll_tpp(target_election)
    if (write) {
      out <- data.table::rbindlist(list(
        if (nrow(sp)) sp[, list(seat, class, poll)] else NULL,
        if (nrow(tp)) tp[, list(seat, class = "@TPP", poll = tpp_poll)] else NULL), fill = TRUE)
      if (!nrow(out)) out <- data.table::data.table(seat = NA_character_, class = NA_character_, poll = NA_real_)
      out$w1 <- w$w1; out$w2 <- w$w2; out$b1 <- w$b[1]; out$b2 <- w$b[2]
      out$se1 <- w$se[1]; out$se2 <- w$se[2]; out$n <- w$n; out$k <- w$k
      data.table::fwrite(out, cache)
    }
  } else if (file.exists(cache)) {
    raw <- data.table::fread(cache, showProgress = FALSE)
    w <- list(w1 = raw$w1[1], w2 = raw$w2[1], b = c(raw$b1[1], raw$b2[1]), se = c(raw$se1[1], raw$se2[1]),
              n = raw$n[1], k = raw$k[1])
    raw <- raw[!is.na(raw$seat)]
    sp <- raw[raw$class != "@TPP", list(seat, class, poll)]
    tp <- raw[raw$class == "@TPP", list(seat, tpp_poll = poll)]
    cat(sprintf("SPB3 %s: joint blend inputs read from %s (sources absent)\n", target_election, basename(cache)))
  } else {
    stop("seat-poll joint blend for ", target_election, ": neither the sources nor ", cache, " exist")
  }
  list(w = w, sp = sp, tp = tp)
}

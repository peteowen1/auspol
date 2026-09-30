#' Party leaders' own seats, per election, with each leader's role
#'
#' From `external/reference/leaders/leaders.csv` (`scripts/fetch_leaders.R`,
#' each election article's infobox). Leaders with a lower-house seat only.
#' Role: `gov` (the head of government going in), `opp` (another major-party
#' leader), `minor` (Greens, Katter, Palmer, One Nation). A Nationals leader
#' beside a Liberal leader is left out: the three measured (Trenorden, Grylls
#' twice) carry no signal and their class is shared with the Liberal leader.
#' "Liberals for Forests" (wa2001) is not the Liberal Party.
#'
#' @return data.table `pair`, `seat`, `party` (model class), `leader`, `role`.
#' @export
leader_seats <- function() {
  f <- file.path(pkg_root(), "external", "reference", "leaders", "leaders.csv")
  if (!file.exists(f)) stop("leader_seats needs ", f, " (scripts/fetch_leaders.R)")
  L <- data.table::fread(f, showProgress = FALSE)
  L <- L[is.finite(L$slot) & nzchar(L$leader_clean) & !grepl("No leader|N/A", L$leader_clean)]
  p <- L$party_clean
  cls <- ifelse(grepl("Labor", p), "ALP",
         ifelse(grepl("Greens", p), "GRN",
         ifelse(grepl("Katter|Palmer", p), "OTH_RIGHT",
         ifelse(grepl("One Nation", p), "ONP",
         ifelse(grepl("Liberal|Coalition|coalition", p) & !grepl("Forests", p), "LNP", NA_character_)))))
  # Two nsw infoboxes leave the Liberal leader's party cell blank.
  blank_lib <- is.na(cls) & L$election %in% c("nsw2019", "nsw2023") &
    L$leader_clean %in% c("Gladys Berejiklian", "Dominic Perrottet")
  cls[blank_lib] <- "LNP"
  seat <- trimws(sub("\\(.*$", "", L$leaders_seat_clean))
  role <- ifelse(cls %in% c("ALP", "LNP"),
                 ifelse(!is.na(L$head_of_govt) & L$leader_clean == L$head_of_govt, "gov", "opp"),
                 "minor")
  keep <- !is.na(cls) & nzchar(seat) &
    !grepl("Senate|Legislative|MLC|Did not stand", L$leaders_seat_clean)
  out <- data.table::data.table(pair = L$election, seat = seat, party = cls,
                                leader = L$leader_clean, role = role)[which(keep)]
  # One leader per (pair, seat, party): a Liberal-led Coalition's class is
  # shared with its Nationals partner, who keeps no separate bonus.
  out[!duplicated(out[, list(pair, seat, party)])]
}

#' Time-forward leader-seat bonus per role, partially pooled
#'
#' Seat-specific miss = actual minus as-at `xgb_pred_seat` ([current_seat_predictions()])
#' less that class's median miss in that election, at leader seats of
#' elections before the target. Each role's mean is shrunk toward the pooled
#' mean by `tau^2 / (tau^2 + se_role^2)` (tau^2 = between-role variance, method
#' of moments); the pooled mean is shrunk toward 0 by `mu^2 / (mu^2 + se^2)`.
#' Pete's questions, 2026-09-29: does the bump differ for a sitting premier,
#' a challenger and a minor-party leader? plans/prereg-leader-seat-2026-09-29.md.
#'
#' @param target_election Label such as `"nsw2023"`.
#' @return data.table `role`, `bonus`, `raw`, `se`, `n`, with attribute `pooled`.
#' @export
leader_seat_bonus <- function(target_election) {
  f <- current_seat_predictions()
  if (is.null(f)) stop("leader_seat_bonus needs this rebuild's as-at predictions (output/xgb-primary-asat-predictions.csv)")
  f <- f[is.finite(f$xgb_pred_seat) & is.finite(f$actual_share)]
  s <- f[, list(pred = sum(xgb_pred_seat), actual = sum(actual_share)), by = list(pair = election, seat, party)]
  s$r <- s$actual - s$pred
  s[, r_seat := r - stats::median(r), by = list(pair, party)]
  ls <- leader_seats()
  ls$k <- paste(ls$pair, normalise_seat(ls$seat), ls$party)
  s$k <- paste(s$pair, normalise_seat(s$seat), s$party)
  m <- merge(s[elections_before(s$pair, target_election)], ls[, list(k, role)], by = "k")
  roles <- c("gov", "opp", "minor")
  empty <- data.table::data.table(role = roles, bonus = 0, raw = NA_real_, se = NA_real_, n = 0L)
  if (nrow(m) < 3) { attr(empty, "pooled") <- list(mu = 0, raw = NA_real_, se = NA_real_, n = nrow(m)); return(empty) }
  mu_raw <- mean(m$r_seat); mu_se <- stats::sd(m$r_seat) / sqrt(nrow(m))
  mu <- mu_raw * mu_raw^2 / (mu_raw^2 + mu_se^2)
  by_role <- m[, list(raw = mean(r_seat), se = if (.N > 1) stats::sd(r_seat) / sqrt(.N) else NA_real_, n = .N), by = role]
  ok <- is.finite(by_role$se)
  tau2 <- if (sum(ok) >= 2) max(0, stats::var(by_role$raw[ok]) - mean(by_role$se[ok]^2)) else 0
  by_role$w <- ifelse(ok, tau2 / (tau2 + by_role$se^2), 0)
  by_role$bonus <- mu + by_role$w * (by_role$raw - mu)
  out <- merge(data.table::data.table(role = roles), by_role[, list(role, bonus, raw, se, n)], by = "role", all.x = TRUE)
  out$bonus[is.na(out$bonus)] <- mu
  out$n[is.na(out$n)] <- 0L
  attr(out, "pooled") <- list(mu = mu, raw = mu_raw, se = mu_se, n = nrow(m), tau2 = tau2)
  out
}

#' The leader-seat inputs for one target, computed or shipped
#'
#' The daily run has no `output/forecasts.csv`, so the promote step writes
#' `output/leader-seat-<target>.csv` and it ships with the models.
#' @param target_election Label such as `"vic2026"`.
#' @param write Write the shipped table.
#' @return data.table `seat`, `party`, `leader`, `role`, `bonus` (possibly empty).
#' @export
leader_seat_table <- function(target_election, write = FALSE) {
  cache <- out_path(sprintf("leader-seat-%s.csv", target_election))
  src <- file.path(pkg_root(), "external", "reference", "leaders", "leaders.csv")
  if (.has_seat_predictions() && file.exists(src)) {
    b <- leader_seat_bonus(target_election)
    ls <- leader_seats()
    .t <- target_election
    tb <- merge(ls[ls$pair == .t, list(seat, party, leader, role)],
                b[, list(role, bonus, raw, se, n)], by = "role")
    if (write) data.table::fwrite(tb, cache)
  } else if (file.exists(cache)) {
    tb <- data.table::fread(cache, showProgress = FALSE)
    cat(sprintf("LS0  %s: leader-seat inputs read from %s (sources absent)\n", target_election, basename(cache)))
  } else {
    stop("leader-seat bonus for ", target_election, ": neither the sources nor ", cache, " exist")
  }
  tb
}

#' Add the leader-seat bonus to each party in its own leader's seat
#'
#' A no-op unless `AUSPOL_LEADER_SEAT` is "1". The leader's class gains its
#' role's bonus in the leader's seat; the row is rescaled to its previous
#' total, so the others give up the points in proportion.
#'
#' @param shares Matrix of primary shares, rownames = seats, colnames = classes.
#' @param target_election Label such as `"nsw2023"`.
#' @return `shares`, adjusted.
#' @export
leader_seat_apply <- function(shares, target_election) {
  if (!identical(Sys.getenv("AUSPOL_LEADER_SEAT", "0"), "1")) return(shares)
  # Neither sources nor a shipped table (a fresh checkout's first rebuild):
  # say so and run without the bonus, as the demographic step does, rather
  # than crash the harness.
  tb <- tryCatch(leader_seat_table(target_election), error = function(e) {
    cat(sprintf("LS1! %s: leader-seat bonus SKIPPED -- %s\n", target_election, conditionMessage(e)))
    NULL
  })
  if (is.null(tb)) return(shares)
  if (!nrow(tb)) {
    cat(sprintf("LS1  %s: no leaders with a seat here\n", target_election))
    return(shares)
  }
  i <- match(normalise_seat(tb$seat), normalise_seat(rownames(shares)))
  j <- match(tb$party, colnames(shares))
  hit <- which(!is.na(i) & !is.na(j) & is.finite(tb$bonus))
  for (h in hit) {
    tot <- sum(shares[i[h], ])
    shares[i[h], j[h]] <- max(0, shares[i[h], j[h]] + tb$bonus[h])
    shares[i[h], ] <- shares[i[h], ] * tot / sum(shares[i[h], ])
  }
  miss <- setdiff(seq_len(nrow(tb)), hit)
  cat(sprintf("LS1  %s: leader-seat bonus applied to %s%s\n", target_election,
              if (length(hit)) paste(sprintf("%s %s (%s %+.2f, n %d)", tb$party[hit], tb$seat[hit],
                                             tb$role[hit], tb$bonus[hit], tb$n[hit]), collapse = "; ") else "no seat",
              if (length(miss)) sprintf("; NOT MATCHED: %s", paste(tb$seat[miss], collapse = ", ")) else ""))
  shares
}

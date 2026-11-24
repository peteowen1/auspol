#' Read the leaders table: `leaders.csv` plus the hand-kept supplement
#'
#' `leaders.csv` is regenerated from Wikipedia by `scripts/fetch_leaders.R`
#' and would overwrite hand-added rows, so older elections it lacks live in
#' `leaders-supplement.csv` (same columns plus `source_url`, `source_date`,
#' `note`). Supplement rows are appended only for elections absent from
#' `leaders.csv`; `leaders.csv` wins on any overlap. A supplement missing any
#' `leaders.csv` column or any of the three source columns stops the run.
#'
#' @return data.table with the `leaders.csv` columns.
#' @export
read_leaders <- function() {
  d <- file.path(pkg_root(), "external", "reference", "leaders")
  f <- file.path(d, "leaders.csv")
  if (!file.exists(f)) stop("leader_seats needs ", f, " (scripts/fetch_leaders.R)")
  L <- data.table::fread(f, showProgress = FALSE)
  g <- file.path(d, "leaders-supplement.csv")
  # AUSPOL_LEADERS_SUPPLEMENT=0 (diagnostic, 2026-10-13): leaders.csv only, to attribute the supplement's effect
  if (!file.exists(g) || identical(Sys.getenv("AUSPOL_LEADERS_SUPPLEMENT", "1"), "0")) return(L)
  S <- data.table::fread(g, showProgress = FALSE)
  need <- c(names(L), "source_url", "source_date", "note")
  if (!setequal(names(S), need))
    stop("leaders-supplement.csv columns differ from leaders.csv + source_url/source_date/note: missing ",
         paste(setdiff(need, names(S)), collapse = ","), "; extra ", paste(setdiff(names(S), need), collapse = ","))
  S <- S[!S$election %in% L$election, names(L), with = FALSE]
  coerce_to <- function(x, cls) switch(cls, integer = as.integer(x), numeric = as.numeric(x), logical = as.logical(x),
                                       character = as.character(x), as.character(x))
  for (cn in names(L)) if (!identical(class(S[[cn]]), class(L[[cn]]))) data.table::set(S, j = cn, value = coerce_to(S[[cn]], class(L[[cn]])[1]))
  cat(sprintf("LS2  leaders-supplement.csv: %d rows used for %d elections absent from leaders.csv\n",
              nrow(S), length(unique(S$election))))
  rbind(L, S)
}

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
#' Elections `leaders.csv` lacks (2001-2018 backfill) come from the hand-kept
#' `leaders-supplement.csv` beside it, which `scripts/fetch_leaders.R` never
#' writes; see [read_leaders()].
#'
#' @return data.table `pair`, `seat`, `party` (model class), `leader`, `role`.
#' @export
leader_seats <- function() {
  L <- read_leaders()
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
  .role_pooled_bonus(m)
}

#' Partially pooled mean of `r_seat` per role (gov, opp, minor), shared by the
#' leader-seat and former-leader-seat fits
#'
#' Each role's mean is shrunk toward the pooled mean by `tau^2 / (tau^2 + se^2)`;
#' the pooled mean is shrunk toward 0 by `mu^2 / (mu^2 + se^2)`. Under 3 rows
#' every bonus is 0.
#' @param m data.table with `r_seat` and `role`.
#' @return data.table `role`, `bonus`, `raw`, `se`, `n`, with attribute `pooled`.
#' @keywords internal
.role_pooled_bonus <- function(m) {
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

#' Whether former leaders' seats are corrected (`AUSPOL_LEADER_FORMER`)
#' @return `TRUE` when the switch is "1"; an error for any value other than "0" or "1".
#' @keywords internal
leader_former_on <- function() {
  v <- Sys.getenv("AUSPOL_LEADER_FORMER", "0")
  if (!v %in% c("0", "1")) stop("AUSPOL_LEADER_FORMER must be \"0\" or \"1\", not \"", v, "\"")
  identical(v, "1")
}

#' Former leaders' seats at one election
#'
#' The seat each party's leader held at the previous election in the same
#' jurisdiction (the latest earlier `leader_seats()` election with the same
#' label prefix), where that party's leader at `target_election` sits in a
#' different seat: Andrews' Mulgrave and Guy's Bulleen for vic2026. The seat's
#' base still carries some of that leader's personal vote, which the
#' leader-seat bonus never takes back (found 24 Nov 2026 tracing Mulgrave).
#' An election with no leader rows of its own is skipped, so a gap in the
#' leaders table cannot mark a sitting leader's seat as a former one.
#' @param target_election Label such as `"vic2026"`.
#' @param ls [leader_seats()] output (passed in to avoid re-reading).
#' @return data.table `seat`, `party`, `leader`, `role` (the role at the previous election), `prev`.
#' @export
former_leader_seats <- function(target_election, ls = leader_seats()) {
  none <- data.table::data.table(seat = character(0), party = character(0), leader = character(0),
                                 role = character(0), prev = character(0))
  tgt <- target_election
  now <- ls[ls$pair == tgt]
  if (!nrow(now)) return(none)
  jur <- sub("[0-9]+$", "", ls$pair)
  cand <- unique(ls$pair[jur == sub("[0-9]+$", "", tgt)])
  cand <- cand[elections_before(cand, tgt)]
  if (!length(cand)) return(none)
  pv <- cand[which.max(as.integer(sub("^[a-z]+", "", cand)))]
  old <- ls[ls$pair == pv]
  here <- paste(normalise_seat(now$seat), now$party)
  old <- old[!paste(normalise_seat(old$seat), old$party) %in% here]
  data.table::data.table(seat = old$seat, party = old$party, leader = old$leader, role = old$role, prev = rep(pv, nrow(old)))
}

#' Time-forward correction at former leaders' seats, partially pooled by role
#'
#' Same fit as [leader_seat_bonus()] (actual minus as-at `xgb_pred_seat`, less
#' the class's median miss that election), at the former-leader seats of every
#' election before the target. Sized 25 Nov 2026 on the live as-at predictions:
#' 36 seats, mean -1.70 (SE 0.82), shrunk -1.38.
#' @param target_election Label such as `"vic2026"`.
#' @return As [leader_seat_bonus()].
#' @export
former_leader_bonus <- function(target_election) {
  f <- current_seat_predictions()
  if (is.null(f)) stop("former_leader_bonus needs this rebuild's as-at predictions (output/xgb-primary-asat-predictions.csv)")
  f <- f[is.finite(f$xgb_pred_seat) & is.finite(f$actual_share)]
  s <- f[, list(pred = sum(xgb_pred_seat), actual = sum(actual_share)), by = list(pair = election, seat, party)]
  s$r <- s$actual - s$pred
  s[, r_seat := r - stats::median(r), by = list(pair, party)]
  ls <- leader_seats()
  prs <- unique(s$pair[elections_before(s$pair, target_election)])
  fl <- data.table::rbindlist(lapply(prs, function(e) {
    x <- former_leader_seats(e, ls)
    if (nrow(x)) x$pair <- e
    x
  }), fill = TRUE)
  if (!nrow(fl)) return(.role_pooled_bonus(data.table::data.table(r_seat = numeric(0), role = character(0))))
  fl$k <- paste(fl$pair, normalise_seat(fl$seat), fl$party)
  s$k <- paste(s$pair, normalise_seat(s$seat), s$party)
  m <- merge(s[, list(k, r_seat)], fl[, list(k, role)], by = "k")
  .role_pooled_bonus(m)
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
    # AUSPOL_LEADER_FORMER: former leaders' seats as rows of their own, role "former_<role>", so the shipped table
    # carries them and the apply loop below moves them like any other row.
    if (leader_former_on()) {
      fs <- former_leader_seats(.t, ls)
      if (nrow(fs)) {
        fb <- former_leader_bonus(.t)
        fr <- merge(fs[, list(seat, party, leader, role)], fb[, list(role, bonus, raw, se, n)], by = "role")
        fr$role <- paste0("former_", fr$role)
        tb <- rbind(tb, fr[, names(tb), with = FALSE])
      }
    }
    if (write) data.table::fwrite(tb, cache)
  } else if (file.exists(cache)) {
    tb <- data.table::fread(cache, showProgress = FALSE)
    cat(sprintf("LS0  %s: leader-seat inputs read from %s (sources absent)\n", target_election, basename(cache)))
  } else {
    stop("leader-seat bonus for ", target_election, ": neither the sources nor ", cache, " exist")
  }
  tb
}

#' Move one cell of a share row by `delta`, the rest of the row paying for it
#'
#' The cell ends exactly `delta` higher (floored at 0, capped at the row
#' total), and every other cell is scaled in proportion so the row total is
#' unchanged. Adding `delta` and then rescaling the WHOLE row instead hands
#' back `delta * (s + delta) / (tot + delta)` of it: a leader on 45 given +2.45 kept
#' only +1.32, and v54's leaders still beat the published forecast by 1.72
#' points (n 52, SE 0.77). plans/prereg-leader-bonus-size-2026-09-30.md.
#' @param row Named numeric row of shares.
#' @param j Index of the cell to move.
#' @param delta Points to add (negative to take away).
#' @return `row`, same total.
#' @keywords internal
.shift_cell <- function(row, j, delta) {
  tot <- sum(row); s <- row[j]
  new <- min(tot, max(0, s + delta))
  rest <- tot - s
  if (rest > 0) row[-j] <- row[-j] * (tot - new) / rest
  else if (tot - new > 0) return(row)   # nobody else holds a share to give: leave the row alone
  row[j] <- new
  row
}

#' Add the leader-seat bonus to each party in its own leader's seat
#'
#' A no-op unless `AUSPOL_LEADER_SEAT` is "1". The leader's class gains its
#' role's bonus in the leader's seat, in full; the other classes give the
#' points up in proportion ([.shift_cell()]).
#'
#' @param shares Matrix of primary shares, rownames = seats, colnames = classes.
#' @param target_election Label such as `"nsw2023"`.
#' @param stage `"post_blend"` (the default argument: after the seat-poll
#'   blend) or `"pre_blend"`. The bonus is applied only at the stage
#'   `AUSPOL_LEADER_BEFORE_BLEND` names (`"1"`, shipped 7 Nov 2026: pre;
#'   `"0"`: post), so callers make both calls.
#' @return `shares`, adjusted.
#' @export
leader_seat_apply <- function(shares, target_election, stage = c("post_blend", "pre_blend")) {
  if (!identical(Sys.getenv("AUSPOL_LEADER_SEAT", "1"), "1")) return(shares)
  # AUSPOL_LEADER_BEFORE_BLEND (6 Nov; SHIPPED "1" 7 Nov): the bonus is fitted as actual minus the PRE-blend tree prediction
  # (leader_seat_bonus(): xgb_pred_seat), so it corrects the number the seat polls are blended into. Added after the
  # blend, a polled leader's seat gets the leader effect twice: once in the polls, once here (Melbourne fed2025: blend
  # 49.35 -> 45.94 Greens, then +2.58, published 49.26; Bandt got 39.5). Each script calls this twice, before the
  # seat-poll blend with stage = "pre_blend" and after it with "post_blend"; the switch says which one acts.
  # plans/prereg-leader-before-blend-2026-11-06.md
  stage <- match.arg(stage)
  lb <- Sys.getenv("AUSPOL_LEADER_BEFORE_BLEND", "1")
  if (!lb %in% c("0", "1")) stop("AUSPOL_LEADER_BEFORE_BLEND must be \"0\" or \"1\", not ", lb)
  if (!identical(stage, if (lb == "1") "pre_blend" else "post_blend")) return(shares)
  # Neither sources nor a shipped table (a fresh checkout's first rebuild):
  # say so and run without the bonus, as the demographic step does, rather
  # than crash the harness.
  tb <- tryCatch(leader_seat_table(target_election), error = function(e) {
    cat(sprintf("LS1! %s: leader-seat bonus SKIPPED -- %s\n", target_election, conditionMessage(e)))
    NULL
  })
  if (is.null(tb)) return(shares)
  # a shipped table may carry former-leader rows; they act only with the switch on
  if (!leader_former_on()) tb <- tb[!startsWith(tb$role, "former_")]
  if (!nrow(tb)) {
    cat(sprintf("LS1  %s: no leaders with a seat here\n", target_election))
    return(shares)
  }
  i <- match(normalise_seat(tb$seat), normalise_seat(rownames(shares)))
  j <- match(tb$party, colnames(shares))
  hit <- which(!is.na(i) & !is.na(j) & is.finite(tb$bonus))
  for (h in hit) {
    shares[i[h], ] <- .shift_cell(shares[i[h], ], j[h], tb$bonus[h])
  }
  miss <- setdiff(seq_len(nrow(tb)), hit)
  cat(sprintf("LS1  %s: leader-seat bonus applied to %s%s\n", target_election,
              if (length(hit)) paste(sprintf("%s %s (%s %+.2f, n %d)", tb$party[hit], tb$seat[hit],
                                             tb$role[hit], tb$bonus[hit], tb$n[hit]), collapse = "; ") else "no seat",
              if (length(miss)) sprintf("; NOT MATCHED: %s", paste(tb$seat[miss], collapse = ", ")) else ""))
  shares
}

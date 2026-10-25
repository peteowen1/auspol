# AUSPOL_LEVEL_DEAD_PARTY: a party that stood last time and is not standing now
# gives up the share the level model would otherwise carry forward for it.
#
# WHY. The statewide level starts, wherever polls are silent, from the previous
# election's result: the thin-cycle path (R/thin_cycle.R) for every class, and
# the split of the unpolled "others" bucket (bucket_split_ratio(), the live
# minor-field scaling in fit_seats_full.R, the federal harness's own copy) for
# the bucket classes. None of them asks whether the party that made up that
# share is on the ballot. nt2024: Territory Alliance took 12.9 of nt2020's 14.1
# OTH, did not stand in 2024, and the thin cycle carried OTH forward at 14.8 with
# no polls behind it; there was then no OTH candidate at all, so the 14.8 was
# dropped at the level (forecast_statewide_or_oracle(), `keep`) and handed out
# pro rata by the seat renormalisation (docs/reviews/wa-nt-seat-layer-trace-
# 2026-10-25.md). The general case: any class, or any named party inside a
# bucket class, that stood last time and stands in fewer seats this time.
#
# WHAT. Three pieces, all off under "0" (byte-identical). Which share is dead
# (dead_party_table()): a party contesting a fraction f of its previous share of
# seats keeps f of its share (seat-count ratio, chamber-size adjusted, capped at
# 1). Single-party classes (ALP, LNP, GRN, ONP) are judged as a class (a
# Coalition partner sitting out is not a dead vote); the bucket classes (OTH,
# OTH_RIGHT, IND) party by party, independents excluded (individual departures
# are the seat layer's business), a party standing under a new name found by its
# candidates.
#   1. dead_party_prior(): where the previous result SPLITS a total (the unpolled
#      bucket's prior ratio), each non-standing party's share is removed from its
#      class and given to the classes that do stand.
#   2. dead_party_level(): where the level itself is CARRIED from the previous
#      result (the thin cycle), each class's level loses its dead fraction times
#      the part of it that was carried (1 - its weight on polls), given to the
#      standing classes. NOT the thin cycle's starting point: there the unpolled
#      classes share what the polled ones leave, so a smaller prior for one only
#      hands the residual to another (nt2024 under that design: IND 23.9 against
#      14.2, every poll-free point of the residual given to independents).
#   3. dead_class_keep(): the level of a class with no candidate anywhere is
#      redistributed the same way instead of being dropped.
# Where the share goes, by the switch's value:
#   "flow" : the class's pooled preference flows (build_flow_matrix()$pooled,
#            the harness's own time-forward matrix), restricted to the classes
#            standing; pro rata where there is no flow row (printed);
#   "pro"  : pro rata to the standing classes' (adjusted) previous shares.
#
# TIME-FORWARD. Which parties stand is nomination data, public ~2-3 weeks
# before polling day. The harnesses read it as the target's candidacies with
# votes > 0 or pcv > 0 (the same proxy zero_unnominated() uses); the live
# forecast passes the nomination list only when AUSPOL_NOM_LIVE=1 opens it,
# otherwise nothing is judged dead (DPL0!).
#
# docs/plans/prereg-level-dead-party-2026-10-25.md. Prints DPL1 (prior split:
# per class, party removed, share, where it went), DPL3 (carried level), DPL2
# (class standing nowhere) and DPL0! (skipped, with the reason).

#' The validated `AUSPOL_LEVEL_DEAD_PARTY` switch
#'
#' @return `"0"` (off, default), `"flow"` or `"pro"`.
#' @export
level_dead_party_mode <- function() {
  m <- Sys.getenv("AUSPOL_LEVEL_DEAD_PARTY", "0")
  if (!nzchar(m)) m <- "0"
  if (!m %in% c("0", "flow", "pro"))
    stop("AUSPOL_LEVEL_DEAD_PARTY must be \"0\", \"flow\" or \"pro\"; got \"", m, "\"", call. = FALSE)
  m
}

# Classes that are one party statewide: judged as a class, never by name.
DEAD_PARTY_SINGLE <- c("ALP", "LNP", "GRN", "ONP")

.dp_stop  <- c("the", "party", "of", "and", "inc", "incorporated", "branch", "division", "ltd", "limited", "group")
.dp_place <- c("australia", "australian", "aust", "victoria", "victorian", "vic", "nsw", "new", "south", "wales",
               "queensland", "qld", "sa", "wa", "western", "northern", "territory", "nt", "tasmania", "tasmanian",
               "tas", "act", "federal")

#' Name tokens for matching a party across elections
#' @param x One party name.
#' @return list(full = stemmed tokens minus filler words, core = minus place words too,
#'   initials = initials of every word but "the"/"of"/"and", compact = the name squashed to letters).
#' @noRd
dead_party_tokens <- function(x) {
  s <- tolower(as.character(x))
  s <- gsub("&", " and ", s, fixed = TRUE)
  s <- gsub("\\([^)]*\\)", " ", s)            # "(Fred Nile Group)", "(NSW Branch)"
  s <- sub("\\s+-\\s+.*$", "", s)             # "Sustainable Australia Party - Stop Overdevelopment"
  s <- gsub("[^a-z0-9 ]", " ", s)
  tk <- strsplit(trimws(s), "\\s+")[[1]]
  tk <- tk[nzchar(tk) & (nchar(tk) > 1L | grepl("^[0-9]$", tk))]
  stem <- sub("(ics|ic|s)$", "", tk)
  stem <- ifelse(nchar(stem) >= 3L, stem, tk)
  full <- stem[!tk %in% .dp_stop]
  core <- stem[!tk %in% c(.dp_stop, .dp_place)]
  ini <- paste(substr(tk[!tk %in% c("the", "of", "and")], 1L, 1L), collapse = "")
  # initials without place words too: "CA" = Country Alliance = "Australian Country Alliance"
  ini2 <- paste(substr(tk[!tk %in% c("the", "of", "and", "party", .dp_place)], 1L, 1L), collapse = "")
  list(full = full, core = if (length(core)) core else full, initials = unique(c(ini, ini2)),
       compact = paste(tk, collapse = ""))
}

#' Is party name `a` the same party as any of `b`?
#'
#' Equal filler-free names, equal place-free names, the shorter place-free name
#' (two words or more) inside the longer, or one name the other's initials
#' ("AJP" = Animal Justice Party). Errs toward "same party": a missed match
#' judges a party dead and moves its share, a false match leaves today's
#' behaviour.
#' @param a One name. @param b Character vector of names.
#' @return logical(1)
#' @noRd
dead_party_same <- function(a, b) {
  if (!length(b)) return(FALSE)
  A <- dead_party_tokens(a)
  for (nm in b) {
    B <- dead_party_tokens(nm)
    if (!length(A$full) || !length(B$full)) next
    if (identical(A$full, B$full) || identical(A$core, B$core)) return(TRUE)
    sm <- if (length(A$core) <= length(B$core)) A$core else B$core
    bg <- if (length(A$core) <= length(B$core)) B$core else A$core
    if (length(sm) >= 2L && all(sm %in% bg)) return(TRUE)
    if (nchar(A$compact) <= 5L && any(nchar(B$initials) >= 2L & B$initials == A$compact)) return(TRUE)
    if (nchar(B$compact) <= 5L && any(nchar(A$initials) >= 2L & A$initials == B$compact)) return(TRUE)
  }
  FALSE
}

.dp_is_ind <- function(x) {
  x <- tolower(trimws(as.character(x)))
  # "Independent Your Voice" (sa2022 ballot labels) and "No Affiliation" are individuals, not parties
  is.na(x) | !nzchar(x) | grepl("^[-[:space:]]*$", x) |
    grepl("^(independent|ind\\b|non[- ]?affiliated|no affiliation|unaffiliated|unendorsed|ungrouped)", x)
}

# A person across elections: first given name plus surname, lower-cased and sorted, from `given`/`surname`
# where both are present (WA's `name` is the surname alone), else every token of `name` (sources print
# "SURNAME Given" or "Given Surname"); empty when there is not a two-word name.
.dp_person <- function(d) {
  col <- function(cn) if (cn %in% names(d)) as.character(d[[cn]]) else rep(NA_character_, nrow(d))
  nm <- col("name"); gv <- col("given"); sn <- col("surname")
  both <- !is.na(gv) & nzchar(trimws(gv)) & !is.na(sn) & nzchar(trimws(sn))
  nm[both] <- paste(sub("\\s.*$", "", trimws(gv[both])), sn[both])
  vapply(nm, function(s) {
    tk <- strsplit(gsub("[^a-z ]", " ", tolower(ifelse(is.na(s), "", s))), "\\s+")[[1]]
    tk <- tk[nchar(tk) > 1L]
    if (length(tk) < 2L) "" else paste(sort(tk), collapse = " ")
  }, "", USE.NAMES = FALSE)
}

# Minimum people who stood for a previous party and now stand for one label, for that label to count as the
# party under a new name (Liberal Democrats -> Libertarian, fed2025: 15; CDP -> Australian Christians, wa2013:
# 10; UAP -> Trumpet of Patriots, fed2025: 9). Also: the label with the most such people, and they are at least
# DEAD_PARTY_SUCCESSOR_SHARE of its candidates. A classification rule, not a fitted constant.
DEAD_PARTY_SUCCESSOR_MIN <- 3L
DEAD_PARTY_SUCCESSOR_SHARE <- 0.05

# "No evidence" from dead_party_table(): tested with inherits(x, "dp_none"), never is.null().
.dp_none <- function(reason) structure(list(), class = "dp_none", reason = reason)

#' Which previous parties do not stand at the target, and how much share that is
#'
#' @param target Label, e.g. `"nt2024"`.
#' @param corpus `output/candidacies.csv` or a data.frame with `election, region,
#'   year, seat, party, party_raw, votes` (`party_ab`, `pcv` optional). Read from
#'   `output/candidacies.csv` when NULL.
#' @param standing Optional data.frame of the target's candidates (`seat, party`,
#'   `party_raw` and `party_ab` optional). NULL: the corpus's target rows with
#'   votes > 0 or pcv > 0 (the harnesses' nomination proxy).
#' @return data.table, one row per previous party (single-party classes one row per
#'   class): `cls, party, prev_share` (points of the previous formal vote),
#'   `successor` (the new label it stands under, found by its candidates, or NA),
#'   `prev_seats, tgt_seats, contest` (0..1), `dead_share`. Attributes `prior`
#'   (label), `standing_classes`, `class_share` (named, previous class shares from
#'   the corpus). When the corpus cannot say, an empty object of class `dp_none`
#'   with attribute `reason` (`structure(NULL, ...)` cannot carry one).
#' @export
dead_party_table <- function(target, corpus = NULL, standing = NULL) {
  region <- sub("[0-9]{4}$", "", target)
  year <- suppressWarnings(as.integer(sub("^[a-z]+", "", target)))
  if (is.null(corpus)) {
    f <- out_path("candidacies.csv")
    if (!file.exists(f)) return(.dp_none("no output/candidacies.csv"))
    corpus <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(corpus)
  for (cn in c("party_raw", "party_ab")) if (!cn %in% names(C)) C[[cn]] <- NA_character_
  if (!"pcv" %in% names(C)) C[["pcv"]] <- NA_real_
  # masks OUTSIDE the brackets (data.table NSE: `region`/`year` are columns too)
  reg_c <- C$region; yr_c <- suppressWarnings(as.integer(C$year)); v_c <- suppressWarnings(as.numeric(C$votes))
  prev_ok <- !is.na(reg_c) & reg_c == region & !is.na(yr_c) & yr_c < year & is.finite(v_c) & v_c > 0
  if (!any(prev_ok)) return(.dp_none(sprintf("no earlier %s election with votes in the corpus", region)))
  prev_year <- max(yr_c[prev_ok])
  P <- C[prev_ok & yr_c == prev_year]
  prior <- P$election[1]
  if (is.null(standing)) {
    pcv_c <- suppressWarnings(as.numeric(C$pcv))
    tg_ok <- !is.na(C$election) & C$election == target & ((is.finite(v_c) & v_c > 0) | (is.finite(pcv_c) & pcv_c > 0))
    Tg <- C[tg_ok]
    if (!nrow(Tg)) return(.dp_none(sprintf("no %s candidacies with votes or pcv > 0", target)))
  } else {
    Tg <- data.table::as.data.table(standing)
    for (cn in c("party_raw", "party_ab")) if (!cn %in% names(Tg)) Tg[[cn]] <- NA_character_
    if (!nrow(Tg)) return(.dp_none("empty nomination list"))
  }
  P$seat_k <- normalise_seat(P$seat); Tg$seat_k <- normalise_seat(Tg$seat)
  ch_p <- data.table::uniqueN(P$seat_k); ch_t <- data.table::uniqueN(Tg$seat_k)
  tot <- sum(as.numeric(P$votes))
  cls_share <- tapply(as.numeric(P$votes), P$party, sum) * 100 / tot
  frac <- function(n_p, n_t) if (n_p <= 0) 1 else min(1, (n_t / ch_t) / (n_p / ch_p))
  rows <- list()
  for (cl in names(cls_share)) {
    pc <- P[P$party == cl]; tc <- Tg[Tg$party == cl]
    np_cl <- data.table::uniqueN(pc$seat_k); nt_cl <- data.table::uniqueN(tc$seat_k)
    if (cl %in% DEAD_PARTY_SINGLE || nt_cl == 0L) {
      # a single-party class, or a bucket with nobody standing at all: judged as a class
      k <- frac(np_cl, nt_cl)
      rows[[length(rows) + 1L]] <- data.table::data.table(cls = cl, party = if (cl %in% DEAD_PARTY_SINGLE) cl else paste0("(all ", cl, ")"),
        prev_share = unname(cls_share[[cl]]), prev_seats = np_cl, tgt_seats = nt_cl, contest = k)
      next
    }
    nm_p <- ifelse(.dp_is_ind(pc$party_raw), NA_character_, as.character(pc$party_raw))
    named <- !is.na(nm_p)
    if (!any(named)) next
    pp_c <- .dp_person(pc); tp_c <- .dp_person(tc)
    for (pn in unique(nm_p[named])) {
      sel <- named & nm_p == pn
      alt <- unique(stats::na.omit(c(pn, pc$party_ab[sel])))
      alt <- alt[nzchar(alt)]
      hit <- vapply(seq_len(nrow(tc)), function(i) {
        cand <- c(tc$party_raw[i], tc$party_ab[i]); cand <- cand[!is.na(cand) & nzchar(cand) & !.dp_is_ind(cand)]
        length(cand) > 0L && any(vapply(alt, function(a) dead_party_same(a, cand), logical(1)))
      }, logical(1))
      # THE SAME PARTY UNDER A NEW NAME: the label (same class) most of its previous candidates now stand for
      # (match on the person, not just the label). Names alone miss every rename.
      ppl <- unique(pp_c[sel]); ppl <- ppl[nzchar(ppl)]
      succ <- NA_character_
      if (length(ppl) && nrow(tc)) {
        lab_ok <- !.dp_is_ind(tc$party_raw) & !hit
        ov <- table(tc$party_raw[lab_ok & tp_c %in% ppl])
        if (length(ov)) {
          best <- names(ov)[which.max(ov)]; nb <- max(ov); size <- sum(lab_ok & tc$party_raw == best, na.rm = TRUE)
          if (nb >= DEAD_PARTY_SUCCESSOR_MIN && nb >= DEAD_PARTY_SUCCESSOR_SHARE * size) {
            succ <- best
            hit <- hit | (!is.na(tc$party_raw) & tc$party_raw == best)
          }
        }
      }
      rows[[length(rows) + 1L]] <- data.table::data.table(cls = cl, party = pn, successor = succ,
        prev_share = 100 * sum(as.numeric(pc$votes[sel])) / tot,
        prev_seats = data.table::uniqueN(pc$seat_k[sel]), tgt_seats = data.table::uniqueN(tc$seat_k[hit]),
        contest = frac(data.table::uniqueN(pc$seat_k[sel]), data.table::uniqueN(tc$seat_k[hit])))
    }
  }
  D <- data.table::rbindlist(rows, fill = TRUE)
  if (!"successor" %in% names(D)) D[, successor := NA_character_]
  D[, dead_share := prev_share * (1 - contest)]
  data.table::setattr(D, "prior", prior)
  data.table::setattr(D, "standing_classes", sort(unique(Tg$party)))
  data.table::setattr(D, "class_share", cls_share)
  D
}

#' Weights for giving a class's removed share to the classes that stand
#' @noRd
.dp_weights <- function(cl, recipients, flows, mode, base) {
  if (identical(mode, "flow") && !is.null(flows) && !is.null(flows$pooled[[cl]])) {
    f <- flows$pooled[[cl]]
    w <- stats::setNames(vapply(recipients, function(r) { v <- f[r]; if (length(v) == 1L && is.finite(v)) unname(v) else 0 }, 0), recipients)
    if (sum(w) > 0) return(structure(w / sum(w), src = "flows"))
  }
  b <- stats::setNames(vapply(recipients, function(r) { v <- base[r]; if (length(v) == 1L && is.finite(v)) max(0, unname(v)) else 0 }, 0), recipients)
  if (sum(b) > 0) return(structure(b / sum(b), src = if (identical(mode, "flow")) "pro rata (no flow row)" else "pro rata"))
  structure(stats::setNames(rep(1 / length(recipients), length(recipients)), recipients), src = "equal")
}

#' The previous result the level carries forward, with non-standing parties' share moved
#'
#' Under `AUSPOL_LEVEL_DEAD_PARTY` = `"flow"`/`"pro"`, each class of `st_a` loses
#' the share of its parties that do not stand at `target` (from
#' [dead_party_table()]) and that share goes to the classes that stand. Under
#' `"0"`, `st_a` is returned unchanged (byte-identical).
#'
#' Use it ONLY where the previous result stands in for a level (the thin cycle's
#' start, the unpolled bucket's split), never as the baseline a seat swings from.
#'
#' @param st_a Named numeric, the previous election's statewide shares by class.
#' @param target Label, e.g. `"nt2024"`.
#' @param parties Classes the caller carries (recipients are drawn from these and
#'   `names(st_a)`).
#' @param flows The harness's [build_flow_matrix()] result, or NULL.
#' @param corpus,standing Passed to [dead_party_table()].
#' @param mode The switch value (default [level_dead_party_mode()]).
#' @param label Text for the log line.
#' @return Named numeric over `union(names(st_a), standing parties)`, same total as
#'   `st_a`; attribute `dead` (the table) and `moved` (points removed per class).
#' @export
dead_party_prior <- function(st_a, target, parties = names(st_a), flows = NULL, corpus = NULL,
                             standing = NULL, mode = level_dead_party_mode(), label = target) {
  if (identical(mode, "0")) return(st_a)
  D <- dead_party_table(target, corpus = corpus, standing = standing)
  if (inherits(D, "dp_none")) {
    cat(sprintf("DPL0! %s: AUSPOL_LEVEL_DEAD_PARTY=%s but no nomination evidence (%s); level unchanged\n",
                label, mode, attr(D, "reason")))
    return(st_a)
  }
  stand <- attr(D, "standing_classes"); csh <- attr(D, "class_share")
  out <- st_a
  out[!is.finite(out)] <- 0
  recip <- intersect(union(names(st_a), parties), stand)
  for (r in setdiff(recip, names(out))) out[[r]] <- 0
  dead_c <- D[D$dead_share > 0, list(dead = sum(dead_share), who = paste(sprintf("%s %.1f (%d->%d seats)", party, dead_share, prev_seats, tgt_seats), collapse = "; ")), by = "cls"]
  dead_c <- dead_c[dead_c$cls %in% names(st_a)]
  if (!nrow(dead_c)) {
    cat(sprintf("DPL1  %s (from %s): every previous party >0 stands; level unchanged\n", label, attr(D, "prior")))
    attr(out, "dead") <- D; attr(out, "moved") <- stats::setNames(numeric(0), character(0))
    return(out[union(names(st_a), setdiff(names(out), names(st_a)))])
  }
  # removed share per class, in st_a's own units: the dead fraction of the class's corpus share
  rm_c <- stats::setNames(vapply(seq_len(nrow(dead_c)), function(i) {
    cl <- dead_c$cls[i]; cs <- csh[cl]
    f <- if (length(cs) == 1L && is.finite(cs) && cs > 0) min(1, dead_c$dead[i] / cs) else 0
    st_a[[cl]] * f
  }, 0), dead_c$cls)
  base <- out
  base[names(rm_c)] <- base[names(rm_c)] - rm_c
  out <- base
  if (!length(recip)) {
    cat(sprintf("DPL0! %s: no standing class to receive %.1f points; level unchanged\n", label, sum(rm_c)))
    return(st_a)
  }
  for (i in seq_len(nrow(dead_c))) {
    cl <- dead_c$cls[i]
    w <- .dp_weights(cl, recip, flows, mode, base)
    out[names(w)] <- out[names(w)] + rm_c[[cl]] * w
    cat(sprintf("DPL1  %s (from %s, %s): %s %.2f -> %.2f; removed %s; to %s by %s\n",
                label, attr(D, "prior"), mode, cl, st_a[[cl]], st_a[[cl]] - rm_c[[cl]], dead_c$who[i],
                paste(sprintf("%s %+.2f", names(w), rm_c[[cl]] * w)[w > 0], collapse = " "), attr(w, "src")))
  }
  if (abs(sum(out) - sum(st_a[is.finite(st_a)])) > 1e-8) stop("DPL1: the adjusted previous result does not keep its total")
  attr(out, "dead") <- D; attr(out, "moved") <- rm_c
  out
}

#' A carried-forward level, with the carried part of each class's dead share moved
#'
#' For a level built from the previous result (the thin cycle): each STANDING
#' class's level loses `level * f * carried`, where `f` is the dead fraction of
#' its previous share ([dead_party_table()]) and `carried` is the part of the
#' level that came from the previous result rather than polls (thin cycle:
#' `1 - attr(level, "w_polls")`); that share goes to the standing classes by
#' flows or pro rata. Classes standing nowhere are left for [dead_class_keep()].
#' Under `"0"`, `level` is returned unchanged.
#'
#' @param level Named numeric level (sums to 100).
#' @param target Label, e.g. `"nt2024"`.
#' @param carried Named numeric in 0..1 per class (missing = 1).
#' @param flows,corpus,standing,mode,label As [dead_party_prior()].
#' @return Named numeric over `names(level)`, same total; attribute `moved`.
#' @export
dead_party_level <- function(level, target, carried = NULL, flows = NULL, corpus = NULL, standing = NULL,
                             mode = level_dead_party_mode(), label = target) {
  if (identical(mode, "0")) return(level)
  D <- dead_party_table(target, corpus = corpus, standing = standing)
  if (inherits(D, "dp_none")) {
    cat(sprintf("DPL0! %s: AUSPOL_LEVEL_DEAD_PARTY=%s but no nomination evidence (%s); level unchanged\n",
                label, mode, attr(D, "reason")))
    return(level)
  }
  stand <- intersect(names(level), attr(D, "standing_classes")); csh <- attr(D, "class_share")
  dead_c <- D[D$dead_share > 0 & D$cls %in% stand, list(dead = sum(dead_share), who = paste(sprintf("%s %.1f (%d->%d seats)", party, dead_share, prev_seats, tgt_seats), collapse = "; ")), by = "cls"]
  out <- level
  if (!nrow(dead_c) || !length(stand)) return(out)
  cw <- function(cl) { v <- if (is.null(carried)) NA_real_ else carried[cl]; if (length(v) != 1L || !is.finite(v)) 1 else min(1, max(0, unname(v))) }
  rm_c <- stats::setNames(vapply(seq_len(nrow(dead_c)), function(i) {
    cl <- dead_c$cls[i]; cs <- csh[cl]
    f <- if (length(cs) == 1L && is.finite(cs) && cs > 0) min(1, dead_c$dead[i] / cs) else 0
    level[[cl]] * f * cw(cl)
  }, 0), dead_c$cls)
  base <- level; base[names(rm_c)] <- base[names(rm_c)] - rm_c
  out <- base
  for (i in seq_len(nrow(dead_c))) {
    cl <- dead_c$cls[i]
    if (!(rm_c[[cl]] > 0)) next
    w <- .dp_weights(cl, stand, flows, mode, base)
    out[names(w)] <- out[names(w)] + rm_c[[cl]] * w
    cat(sprintf("DPL3  %s (from %s, %s): carried level %s %.2f -> %.2f (dead %s; carried part %.2f); to %s by %s\n",
                label, attr(D, "prior"), mode, cl, level[[cl]], level[[cl]] - rm_c[[cl]], dead_c$who[i], cw(cl),
                paste(sprintf("%s %+.2f", names(w), rm_c[[cl]] * w)[w > 0], collapse = " "), attr(w, "src")))
  }
  if (abs(sum(out) - sum(level)) > 1e-8) stop("DPL3: the adjusted level does not keep its total")
  attr(out, "moved") <- rm_c
  out
}

#' The live forecast's nomination rows for the dead-party check, or NULL
#'
#' Only when [live_nominations()] opens the gate (`AUSPOL_NOM_LIVE=1`, the final
#' list loaded): a provisional list would judge every party not yet listed dead.
#' Returns the corpus's `election == target` rows (with `party_raw`), or NULL
#' after printing why. Off (`"0"`), returns NULL silently.
#' @param seats Forecast seat names. @param target,prior Corpus labels.
#' @param corpus Optional candidacies table.
#' @return data.table or NULL.
#' @export
dead_party_live_standing <- function(seats, target, prior, corpus = NULL) {
  if (identical(level_dead_party_mode(), "0")) return(NULL)
  nm <- live_nominations(seats, election = target, prior = prior, corpus = corpus)
  if (is.null(nm$target)) {
    cat(sprintf("DPL0! %s: AUSPOL_LEVEL_DEAD_PARTY=%s but no final nomination list (%s); nothing judged dead, level unchanged\n",
                target, level_dead_party_mode(), nm$reason))
    return(NULL)
  }
  C <- corpus
  if (is.null(C)) C <- data.table::fread(out_path("candidacies.csv"), showProgress = FALSE)
  C <- data.table::as.data.table(C)
  el_c <- C$election
  C[!is.na(el_c) & el_c == target]
}

#' Redistribute the level of a class with no candidate anywhere, instead of dropping it
#'
#' Under `"0"` returns `level[keep]` exactly as before. Otherwise the level of
#' every class in `level` but not in `keep` goes to the `keep` classes, by flows
#' (`"flow"`) or pro rata (`"pro"`).
#' @param level Named numeric, the full level vector.
#' @param keep Classes that stand.
#' @param flows,mode,label As [dead_party_prior()].
#' @return Named numeric over `keep`.
#' @export
dead_class_keep <- function(level, keep, flows = NULL, mode = level_dead_party_mode(), label = "") {
  out <- level[keep]
  if (identical(mode, "0")) return(out)
  gone <- setdiff(names(level), keep)
  gone <- gone[is.finite(level[gone]) & level[gone] > 0]
  if (!length(gone) || !length(keep)) return(out)
  base <- out
  for (cl in gone) {
    w <- .dp_weights(cl, keep, flows, mode, base)
    out[names(w)] <- out[names(w)] + level[[cl]] * w
    cat(sprintf("DPL2  %s: %s stands nowhere, its level %.2f goes to %s by %s (was dropped and renormalised pro rata in the seats)\n",
                label, cl, level[[cl]], paste(sprintf("%s %+.2f", names(w), level[[cl]] * w)[w > 0], collapse = " "), attr(w, "src")))
  }
  out
}

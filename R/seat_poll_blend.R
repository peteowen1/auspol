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
#' ending before election day, maps each party to a model class, sums within
#' class per poll and averages over polls: by recency and precision under
#' `AUSPOL_SEAT_POLL_DECAY` (shipped 2026-10-09, [seat_poll_decay_params()]),
#' otherwise equally within the `days` window.
#' docs/plans/prereg-seat-poll-blend-2026-09-29.md.
#'
#' @param election Label such as `"fed2022"`.
#' @param days Fieldwork window before election day; ignored under
#'   `AUSPOL_SEAT_POLL_DECAY=1`, which weights by recency instead.
#' @param .raw Internal: under the decay, return one row per poll and class
#'   with its days out, seat sample and group, for [seat_poll_decay_params()].
#' @param by_type Keep MRP and direct polls apart (a `type` column).
#' @param by_poll Return one row per poll and class (`seat`, `poll_id`,
#'   `class`, `fp`, `mrp`), with every class a poll does not name as `REST`
#'   and each poll scaled to 100; input to [seat_poll_implied()].
#' @return data.table (`seat`, `class`, `poll`, `n_polls`, `n_mrp`, and `type`
#'   when `by_type`), possibly empty. A release (pollster + dates) covering at
#'   least 20 seats counts as MRP, whatever its name.
#' @export
seat_poll_shares <- function(election, days = 90, by_type = FALSE, by_poll = FALSE, .raw = FALSE) {
  # MEMOISED (2026-10-10): one vic2026 blend table made 178 calls for 55
  # distinct inputs, ~18 of its 27 s. The key holds EVERY AUSPOL_* variable
  # (not a hand-picked list, which goes stale the day a switch is added) and
  # the mtime and size of every file this reads, so an arm or a refreshed file
  # is a different key. A copy is returned: callers may modify with `:=`.
  # The lines the real call printed are replayed on a hit, so the output is
  # the same as uncached. options(auspol.seat_poll_memo = FALSE) turns it off.
  .seat_poll_memoised(.seat_poll_memo_key(election, days, by_type, by_poll, .raw),
                      function() .seat_poll_shares_impl(election, days, by_type, by_poll, .raw))
}

.seat_poll_memo <- new.env(parent = emptyenv())

#' @keywords internal
.seat_poll_memoised <- function(key, compute) {
  if (isFALSE(getOption("auspol.seat_poll_memo"))) return(compute())
  hit <- .seat_poll_memo[[key]]
  if (is.null(hit)) {
    val <- NULL
    printed <- utils::capture.output(val <- compute())
    hit <- list(val = val, printed = printed)
    assign(key, hit, envir = .seat_poll_memo)
  }
  if (length(hit$printed)) cat(hit$printed, sep = "\n")
  data.table::copy(hit$val)
}

# `extra` names further files whose stamps belong in the key (a caller's own
# input, e.g. .read_seat_polls_file()'s `f` and the hand-keyed file beside it).
#' @keywords internal
.seat_poll_memo_key <- function(election, days, by_type, by_poll, .raw, extra = character(0)) {
  env <- Sys.getenv(); env <- env[startsWith(names(env), "AUSPOL_")]
  sp <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls")
  files <- c(file.path(sp, c("seat_polls.csv", "hand_keyed_primaries.csv", "poll_methods.csv", "mrp_candidates.csv", "seat_poll_corrections.csv")),
             out_path(c("candidacies.csv", "endorsement-features.csv", "xgb-primary-asat-predictions.csv", "forecasts.csv")),
             # Under AUSPOL_POSTXGB_RESID_NET=1 current_seat_predictions() also reads the port's inputs;
             # stamped only then, so the default key (and so the default cache) is unchanged.
             if (postxgb_resid_net_on()) .port_input_files() else character(0),
             extra)
  fi <- file.info(files, extra_cols = FALSE)
  paste(election, days, by_type, by_poll, .raw, pkg_root(),
        paste(names(env), env, sep = "=", collapse = "|"),
        paste(files, format(as.numeric(fi$mtime), digits = 15), fi$size, collapse = "|"), sep = "#")
}

#' @keywords internal
.seat_poll_shares_impl <- function(election, days = 90, by_type = FALSE, by_poll = FALSE, .raw = FALSE) {
  f <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")
  empty <- data.table::data.table(seat = character(0), class = character(0), poll = numeric(0),
                                  n_polls = integer(0), n_mrp = integer(0))
  if (!file.exists(f)) return(empty)
  decay <- .seat_poll_decay_on()
  if (decay && by_poll) stop("AUSPOL_SEAT_POLL_DECAY=1 is built for the class match only (AUSPOL_SEAT_POLL_MATCH=class)")
  s <- .read_seat_polls_file(f)
  el_arg <- election
  ed <- as.Date(unname(election_dates()[el_arg]))
  # Polls after polling day are never read (that is leakage, not a window).
  # The `days` window is the shipped hard cut; AUSPOL_SEAT_POLL_DECAY replaces
  # it with a recency weight (.seat_poll_cell_weights()).
  keep <- s$election == el_arg & s$row_type == "poll" & is.finite(s$fp) &
    !is.na(s$fieldwork_end) & as.Date(s$fieldwork_end) < ed
  if (!decay) keep <- keep & as.Date(s$fieldwork_end) >= ed - days
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
  # a poll's "others" lump, as against a party or candidate it NAMES -- tagged before any remap or split moves the
  # lump into a class (AUSPOL_SEAT_POLL_NAMED_ONLY, .seat_poll_named_only())
  s$.bucket <- p == "OTH"
  if (identical(Sys.getenv("AUSPOL_SEAT_POLL_IND_MAP", "1"), "1")) s <- .seat_poll_ind_map(s, el_arg)
  # MRP by STRUCTURE: YouGov's 2022 MRP is labelled plain "YouGov".
  s$release <- paste(s$pollster, s$date_raw)
  cover <- s[, list(n_seats = data.table::uniqueN(seat_name)), by = release]
  s$is_mrp <- cover$n_seats[match(s$release, cover$release)] >= 20L
  # AUSPOL_SEAT_POLL_MRP_NAME: the structural test misses an MRP release that
  # covered fewer than 20 seats -- YouGov's final fed2025 MRP ("YouGov (MRP)",
  # Bradfield 47.8, 4 days out) was filed as a direct poll. The name says MRP.
  if (.seat_poll_mrp_name_on()) s$is_mrp <- s$is_mrp | grepl("MRP", s$pollster, ignore.case = TRUE)
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
  if (.seat_poll_namedonly_on()) {
    s <- .seat_poll_named_only(s, el_arg)
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
  if (!decay) {
    if (!by_type) return(per_poll[, list(poll = mean(fp), n_polls = .N, n_mrp = sum(mrp)), by = list(seat, class)])
    per_poll$type <- ifelse(per_poll$mrp, "mrp", "direct")
    return(per_poll[, list(poll = mean(fp), n_polls = .N, n_mrp = sum(mrp)), by = list(seat, class, type)])
  }
  # DECAY: each poll's facts (days before polling day, seat sample size,
  # sponsor), one row per poll.
  pf <- s[, list(days = as.numeric(ed - as.Date(fieldwork_end[1])),
                 n_seat = suppressWarnings(as.numeric(sample_n[1])),
                 sponsored = !is.na(client[1]) & nzchar(trimws(client[1])),
                 firm = .seat_poll_firm_key(pollster[1]),
                 .pollster = pollster[1], .fw = as.character(fieldwork_end[1]), .seat0 = seat[1],
                 .n0 = suppressWarnings(as.numeric(sample_n[1]))), by = poll_id]
  per_poll <- merge(per_poll, pf, by = "poll_id")
  # MRP sample sizes are the NATIONAL survey (YouGov fed2025: 10,822), not the seat's.
  per_poll$n_seat[per_poll$mrp] <- NA_real_
  per_poll$group <- ifelse(per_poll$mrp, "mrp", ifelse(per_poll$sponsored, "sponsored", "direct"))
  if (.seat_poll_groups_mode() != "0") {
    M <- .seat_poll_method_table()
    el_lab <- el_arg
    M <- M[M$election %in% el_lab]
    k_pp <- paste(per_poll$.seat0, per_poll$.pollster, per_poll$.fw, per_poll$.n0)
    k_m <- paste(M$seat, M$pollster, M$fieldwork_end, M$sample_n)
    hit <- match(k_pp, k_m)
    old <- ifelse(per_poll$mrp, "mrp", ifelse(per_poll$sponsored, "direct_stake", "direct_indep"))
    per_poll$group <- ifelse(is.na(hit), old, M$mgroup[hit])
    per_poll$group[per_poll$mrp] <- "mrp"          # MRP by structure stays MRP whatever the file says
    if (.seat_poll_firm_on()) {
      pc <- M$pollster_clean[hit]
      per_poll$firm <- ifelse(is.na(hit) | !nzchar(pc) | pc == "unknown", per_poll$firm, .seat_poll_firm_key(pc))
    }
    up <- unique(per_poll[, c("poll_id", "group"), with = FALSE])
    cat(sprintf("SPG1 %s seat-poll groups (%s): %s; %d of %d polls matched the method file\n", el_arg, .seat_poll_groups_mode(),
                paste(sprintf("%s %d", names(table(up$group)), as.integer(table(up$group))), collapse = ", "),
                sum(!is.na(unique(data.table::data.table(id = per_poll$poll_id, h = hit))$h)), length(unique(per_poll$poll_id))))
  }
  if (.raw) return(per_poll)
  per_poll$wt <- .seat_poll_cell_weights(per_poll, seat_poll_decay_params(el_arg))
  per_poll$type <- ifelse(per_poll$mrp, "mrp", "direct")
  by_cols <- if (by_type) c("seat", "class", "type") else c("seat", "class")
  if (.seat_poll_firm_shared_on()) return(.seat_poll_firm_shared_cells(per_poll, seat_poll_decay_params(el_arg), by_cols))
  per_poll[, list(poll = sum(wt * fp) / sum(wt), n_polls = .N, n_mrp = sum(mrp), wsum = sum(wt)), by = by_cols]
}

.seat_poll_decay_on <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_DECAY", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_DECAY must be \"0\" or \"1\", not ", v)
  v == "1"
}
.seat_poll_precision_on <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_PRECISION_BLEND", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_PRECISION_BLEND must be \"0\" or \"1\", not ", v)
  v == "1"
}
.seat_poll_firm_on <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_FIRM_FLOOR", "0")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_FIRM_FLOOR must be \"0\" or \"1\", not ", v)
  v == "1"
}
# AUSPOL_SEAT_POLL_GROUPS (prereg-seat-poll-method-weights-2026-10-18.md): "0" = groups mrp / direct / sponsored
# (sponsored from the client column, filled for ~35 of 1,210 polls); "method" = groups from
# external/reference/polls/seat-polls/poll_methods.csv (mrp, direct_indep, direct_stake, optin) with an opt-in floor
# prior of 225 (an opt-in poll misses by ~15 points until its record says otherwise; amendment 1); "method0" = the
# same groups with no opt-in prior.
.seat_poll_groups_mode <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_GROUPS", "method")
  if (!v %in% c("0", "method", "method0")) stop("AUSPOL_SEAT_POLL_GROUPS must be \"0\", \"method\" or \"method0\", not ", v)
  v
}
.seat_poll_onoff <- function(name, default = "1") {   # every switch below ships "1" (arm H, 2026-10-18)
  v <- Sys.getenv(name, default)
  if (!v %in% c("0", "1")) stop(name, " must be \"0\" or \"1\", not ", v)
  v == "1"
}
# prereg-seat-poll-method-weights-2026-10-18.md amendment 2 (the one Bayesian blend):
.seat_poll_sizevar_on  <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_SIZEVAR")   # model variance depends on predicted size
.seat_poll_allpolls_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_ALLPOLLS")  # no direct-only override of the IND cell
.seat_poll_splitall_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_SPLIT_ALL") # "others" over every unnamed class standing
.seat_poll_namedonly_on   <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_NAMED_ONLY")    # amendment 3
.seat_poll_modelvar_all_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_MODELVAR_ALL") # amendment 5
.seat_poll_salience_var_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_SALIENCE_VAR") # amendment 4

#' Keep only the poll figures that measure a class (AUSPOL_SEAT_POLL_NAMED_ONLY)
#'
#' A poll measures a seat-class cell only if it names EVERY candidate of that
#' class standing in the seat, or its "others" figure is zero. ALP, LNP, GRN
#' and ONP run one candidate each, so naming them is enough. A pooled class
#' (IND, OTH_RIGHT, OTH) with candidates the poll did not name hides part of
#' its vote in "others", so the poll's figure is not its measurement (Kennedy
#' 2022: the UAP named at 6, Katter in "others"). Every row built from the
#' "others" lump (the endorsed-independent remap, the known-class split,
#' SPLIT_ALL) is dropped: a number carved out of "others" is not the
#' pollster's measurement of anyone (Curtin 2022: YouGov never modelled
#' Chaney; its others 14 voted as her figure). A cell no poll measures keeps
#' our own prediction. Candidates per class from `output/candidacies.csv`
#' (the ballot, known before polling day). Prints SPN1.
#' docs/plans/prereg-seat-poll-method-weights-2026-10-18.md, amendment 3.
#' @keywords internal
.seat_poll_named_only <- function(s, el, cand = NULL) {
  if (!".bucket" %in% names(s)) stop(".seat_poll_named_only(): rows carry no .bucket tag")
  cf <- out_path("candidacies.csv")
  cd <- if (!is.null(cand)) data.table::as.data.table(cand) else if (file.exists(cf))
    data.table::fread(cf, select = c("election", "seat", "party"), showProgress = FALSE) else NULL
  el_c <- el   # never the bare argument inside `[` (data.table NSE, CLAUDE.md)
  nc <- if (is.null(cd)) data.table::data.table(sk = character(0), class = character(0), n_cand = integer(0)) else
    cd[cd$election == el_c, list(n_cand = .N), by = list(sk = normalise_seat(seat), class = party)]
  if (!nrow(nc)) cat(sprintf("SPN1! %s: no candidacies rows, so a pooled class cannot be checked for unnamed candidates (every named row counts)
", el))
  bucket <- s$.bucket %in% TRUE
  nm <- s[!bucket, list(n_named = .N), by = list(poll_id, class)]
  oth <- s[, list(oth = sum(fp[.bucket %in% TRUE])), by = poll_id]
  n_named <- nm$n_named[match(paste(s$poll_id, s$class), paste(nm$poll_id, nm$class))]
  n_named[is.na(n_named)] <- 0L
  n_cand <- nc$n_cand[match(paste(normalise_seat(s$seat_name), s$class), paste(nc$sk, nc$class))]
  n_cand[is.na(n_cand)] <- 0L
  oth_p <- oth$oth[match(s$poll_id, oth$poll_id)]
  single <- s$class %in% c("ALP", "LNP", "GRN", "ONP")
  # A DIRECT poll's named entry is the candidate it asked about (Freshwater Warringah 2025: IND 33 is Steggall, a
  # second independent sits in its others 12), so it measures that candidate even when the class has others standing.
  # The part-named rule is for an MRP's party columns (Kennedy 2022: UAP named, Katter in others).
  direct <- if ("is_mrp" %in% names(s)) !(s$is_mrp %in% TRUE) else rep(FALSE, nrow(s))
  idm <- Sys.getenv("AUSPOL_SEAT_POLL_IND_DIRECT", "ind")
  if (!idm %in% c("0", "ind", "pooled", "listed"))
    stop("AUSPOL_SEAT_POLL_IND_DIRECT must be \"0\", \"ind\", \"pooled\" or \"listed\", not ", idm)
  listed <- rep(FALSE, nrow(s))
  if (idm == "listed") {
    # "listed": an MRP's IND column counts as the seat's independent only where mrp_candidates.csv says that release
    # modelled them (YouGov 2025 Warringah yes, Mayo no; agent research 2026-10-18, inferred from column sizes, not
    # stated by the pollster). Such a row is a named candidate, like a direct poll's.
    mf <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "mrp_candidates.csv")
    if (!file.exists(mf)) stop("AUSPOL_SEAT_POLL_IND_DIRECT=listed needs ", mf)
    mc <- data.table::fread(mf, showProgress = FALSE)
    yes <- paste(mc$election, mc$pollster, as.character(mc$release_date), normalise_seat(mc$seat))[mc$modelled == "yes"]
    listed <- s$class == "IND" & paste(el, s$pollster, as.character(as.Date(s$fieldwork_end)), normalise_seat(s$seat_name)) %in% yes
  }
  full <- single | direct | listed | n_named >= n_cand | !(oth_p > 0)
  keep <- !bucket & full
  # AUSPOL_SEAT_POLL_IND_DIRECT (amendment 6): an MRP's IND / OTH_RIGHT / OTH columns are party columns, not
  # candidates, so a label cannot say whether its IND is the independent standing (YouGov Mayo 2025: IND 1.9,
  # Sharkie inside OTH). "ind": MRPs never vote on an independent's cell; "pooled": nor on OTH_RIGHT or OTH.
  n_mrp_drop <- 0L
  if (idm != "0") {
    if (!"is_mrp" %in% names(s)) stop(".seat_poll_named_only(): AUSPOL_SEAT_POLL_IND_DIRECT needs the is_mrp column")
    dcls <- if (idm == "ind") "IND" else c("IND", "OTH_RIGHT", "OTH")
    mrp_drop <- keep & (s$is_mrp %in% TRUE) & s$class %in% dcls
    mrp_drop <- mrp_drop & !listed
    n_mrp_drop <- sum(mrp_drop); keep <- keep & !mrp_drop
  }
  if (idm != "0") cat(sprintf("SPN2 %s: MRPs do not vote on %s (%d rows), direct polls only\n", el,
                              switch(idm, ind = "independents", listed = "independents they are not listed as modelling",
                                     "IND / OTH_RIGHT / OTH"), n_mrp_drop))
  cat(sprintf("SPN1 %s named-only: %d of %d poll rows kept; dropped %d built from \"others\" and %d of a pooled class the poll named only in part\n",
              el, sum(keep), length(keep), sum(bucket), sum(!bucket & !full)))
  s[keep]
}

SEAT_POLL_OPTIN_FLOOR_PRIOR <- 225   # points^2 (sd 15): CHOSEN prior for opt-in seat polls (amendment 1)
.seat_poll_method_table <- function() {
  f <- file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "poll_methods.csv")
  if (!file.exists(f)) stop("AUSPOL_SEAT_POLL_GROUPS is on but ", f, " is missing")
  m <- data.table::fread(f, showProgress = FALSE, colClasses = list(character = c("fieldwork_end")))
  m$sample_n <- suppressWarnings(as.numeric(m$sample_n))
  stake <- c("party", "union", "advocacy_group", "industry_lobby", "candidate_campaign")
  m$mgroup <- ifelse(m$method == "mrp", "mrp", ifelse(m$method == "optin_link", "optin",
                     ifelse(m$sponsor_type %in% stake, "direct_stake", "direct_indep")))
  unique(m, by = c("election", "seat", "pollster", "fieldwork_end", "sample_n"))
}
.seat_poll_group_names <- function() if (.seat_poll_groups_mode() == "0") c("mrp", "direct", "sponsored") else c("mrp", "direct_indep", "direct_stake", "optin")
.seat_poll_group_prior <- function(g, pool) if (identical(g, "optin") && .seat_poll_groups_mode() == "method") SEAT_POLL_OPTIN_FLOOR_PRIOR else pool
.seat_poll_firm_key <- function(x) {
  k <- tolower(trimws(gsub("\\([^)]*\\)", "", x)))
  k[is.na(k)] <- ""
  k
}

SEAT_POLL_MODEL_VAR_PRIOR <- 25    # points^2 (sd 5): our seat primary error before any polled election; the AEF-7 ledger's primary RMSE is 5.13

#' Our own model's error variance on polled cells, per class, time-forward
#'
#' For the precision blend: mean of `(actual - xgb_pred_seat)^2` over every
#' EARLIER election's polled (seat, class) cells with a prediction above 0,
#' per class, each shrunk toward the pooled value by `SEAT_POLL_FLOOR_K`
#' pseudo seat-elections and the pool toward `SEAT_POLL_MODEL_VAR_PRIOR`.
#' @param target_election Label such as `"fed2022"`.
#' @return Named numeric vector (classes plus `pooled`), points^2.
#' @export
seat_poll_model_var <- function(target_election) {
  f <- current_seat_predictions()
  els <- if (is.null(f)) character(0) else unique(f$election)
  els <- els[elections_before(els, target_election)]
  all_cells <- .seat_poll_modelvar_all_on()
  rows <- data.table::rbindlist(lapply(els, function(e) {
    if (all_cells) {
      # AUSPOL_SEAT_POLL_MODELVAR_ALL (amendment 5): the model's own error needs no poll to be measured, so every
      # earlier seat-class cell with a prediction and a result counts, not only the polled ones (almost none before
      # fed2022, which left independents at the prior sd 5 against a true model error of ~15)
      fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party, pred = xgb_pred_seat, actual = actual_share)]
      fe <- fe[is.finite(pred) & is.finite(actual) & pred > 0]
      if (!nrow(fe)) return(NULL)
      fe$unit <- paste(e, fe$seat)
      return(fe)
    }
    sp <- NULL
    utils::capture.output(sp <- seat_poll_shares(e))
    if (is.null(sp) || !nrow(sp)) return(NULL)
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party, pred = xgb_pred_seat, actual = actual_share)]
    sp$seat <- normalise_seat(sp$seat)
    m <- merge(sp[, list(seat, class)], fe, by = c("seat", "class"))
    m <- m[is.finite(pred) & is.finite(actual) & pred > 0]
    if (!nrow(m)) return(NULL)
    m$unit <- paste(e, m$seat)
    m
  }), fill = TRUE)
  K <- SEAT_POLL_FLOOR_K
  if (!nrow(rows)) {
    # no earlier polled cells (fed2016, the first election with seat polls): the prior variance, and the size
    # exponent at its prior 0 (no size scaling), so AUSPOL_SEAT_POLL_SIZEVAR has nothing to scale by
    out <- c(pooled = SEAT_POLL_MODEL_VAR_PRIOR)
    attr(out, "ref") <- c(pooled = 1); attr(out, "g") <- 0; attr(out, "g_raw") <- NA_real_; attr(out, "g_se") <- NA_real_
    attr(out, "sal_b") <- 0; attr(out, "sal_mean") <- 0; attr(out, "sal_se") <- NA_real_; attr(out, "sal_n") <- 0L   # (review 2026-10-18)
    if (.seat_poll_heavy_tail_on()) {   # the mixture's prior (.seat_poll_em2 on too few cells) (review 2026-10-19)
      p0 <- .seat_poll_em2(numeric(0))
      attr(out, "ht_pi") <- c(pooled = p0[["pi"]]); attr(out, "ht_s1") <- c(pooled = p0[["s1"]]); attr(out, "ht_k") <- c(pooled = p0[["k"]])
    }
    return(out)
  }
  e2 <- (rows$actual - rows$pred)^2
  U <- length(unique(rows$unit))
  pooled <- (U * mean(e2) + K * SEAT_POLL_MODEL_VAR_PRIOR) / (U + K)
  cls <- sort(unique(rows$class))
  v <- vapply(cls, function(cl) {
    i <- rows$class == cl
    n <- length(unique(rows$unit[i]))
    (n * mean(e2[i]) + K * pooled) / (n + K)
  }, numeric(1))
  out <- c(v, pooled = pooled)
  # AUSPOL_SEAT_POLL_SIZEVAR: one exponent g on (pred + 1) relative to each class's median prediction, from
  # log squared error on the same earlier cells (class-demeaned), shrunk toward 0 by its SE. A 5% independent then
  # carries far less model uncertainty than a 35% one, instead of the class-pooled sd for every independent.
  ref <- vapply(cls, function(cl) stats::median(rows$pred[rows$class == cl]), numeric(1))
  ly <- log(pmax(e2, 0.25)); lx <- log(rows$pred + 1) - log(ref[rows$class] + 1)
  ly <- ly - stats::ave(ly, rows$class); lx <- lx - stats::ave(lx, rows$class)
  g <- if (sum(lx^2) > 0) sum(lx * ly) / sum(lx^2) else 0
  res <- ly - g * lx; se <- sqrt(sum(res^2) / max(1, length(ly) - 1) / sum(lx^2))
  wg <- if (is.finite(g) && is.finite(se) && g != 0) max(0, 1 - se^2 / g^2) else 0
  attr(out, "ref") <- c(ref, pooled = stats::median(rows$pred)); attr(out, "g") <- wg * g
  attr(out, "g_raw") <- g; attr(out, "g_se") <- se
  # AUSPOL_SEAT_POLL_SALIENCE_VAR (amendment 4): how much an independent's model error grows with the campaign rise
  # in search interest. x = log(jump + 0.01) centred on the earlier independent cells that have salience; b from
  # their log squared error after the size term, shrunk toward 0 by its SE. Cells with no salience take no part.
  attr(out, "sal_b") <- 0; attr(out, "sal_mean") <- 0; attr(out, "sal_se") <- NA_real_; attr(out, "sal_n") <- 0L
  # AUSPOL_SEAT_POLL_HEAVY_TAIL (prereg-seat-poll-heavy-tail-2026-10-18.md): the model's error is a two-part mixture.
  # Fitted per class on the same earlier cells' errors standardised by each cell's own variance (class v x the size
  # scaling), zero-mean, by EM: ordinary scale s1, "badly wrong" scale k * s1 with weight pi.
  if (.seat_poll_heavy_tail_on()) {
    vrow <- v[rows$class] * ((rows$pred + 1) / (ref[rows$class] + 1))^(wg * g)
    z2 <- e2 / vrow
    fits <- lapply(c(cls, "pooled"), function(cl) .seat_poll_em2(if (cl == "pooled") z2 else z2[rows$class == cl]))
    names(fits) <- c(cls, "pooled")
    pr_pi <- 0.02; Kp <- SEAT_POLL_FLOOR_K
    npool <- length(z2); pi_pool <- (npool * fits$pooled[["pi"]] + Kp * pr_pi) / (npool + Kp)
    ht_pi <- vapply(c(cls, "pooled"), function(cl) { n <- if (cl == "pooled") npool else sum(rows$class == cl)
      if (cl == "pooled") pi_pool else (n * fits[[cl]][["pi"]] + Kp * pi_pool) / (n + Kp) }, numeric(1))
    attr(out, "ht_pi") <- ht_pi
    attr(out, "ht_s1") <- vapply(fits, function(x) x[["s1"]], numeric(1))
    attr(out, "ht_k") <- vapply(fits, function(x) x[["k"]], numeric(1))
  }
  if (.seat_poll_salience_var_on()) {
    ind <- which(rows$class == "IND")
    sl <- data.table::rbindlist(lapply(unique(sub(" .*", "", rows$unit[ind])), function(e)
      .seat_poll_ind_salience(e)[, election := e]), fill = TRUE)
    if (nrow(sl)) {
      j <- sl$jump[match(paste(sub(" .*", "", rows$unit[ind]), rows$seat[ind]), paste(sl$election, sl$sk))]
      ok <- is.finite(j)
      if (sum(ok) >= 3L) {
        x <- log(pmax(j[ok], 0) + 0.01); mx <- mean(x); x <- x - mx
        yr <- (ly - g * lx)[ind][ok]; yr <- yr - mean(yr)
        b <- if (sum(x^2) > 0) sum(x * yr) / sum(x^2) else 0
        bse <- sqrt(sum((yr - b * x)^2) / max(1, length(x) - 1) / sum(x^2))
        wb <- if (is.finite(b) && is.finite(bse) && b != 0) max(0, 1 - bse^2 / b^2) else 0
        attr(out, "sal_b") <- wb * b; attr(out, "sal_mean") <- mx; attr(out, "sal_se") <- bse; attr(out, "sal_n") <- sum(ok)
        attr(out, "sal_b_raw") <- b
      }
    }
  }
  out
}

#' Campaign rise in search interest for a seat's independents (max over them)
#'
#' From `output/salience-v6.csv` (`jump`, fetch_salience_v6.R). One row per
#' seat with an independent that has salience; for AUSPOL_SEAT_POLL_SALIENCE_VAR.
#' @keywords internal
.seat_poll_ind_salience <- function(election) {
  sf <- out_path("salience-v6.csv")
  if (!file.exists(sf)) return(data.table::data.table(sk = character(0), jump = numeric(0)))
  sv <- data.table::fread(sf, select = c("election", "seat", "party", "jump"), showProgress = FALSE)
  el_s <- election
  sv <- sv[sv$election == el_s & sv$party == "IND" & is.finite(sv$jump)]
  if (!nrow(sv)) return(data.table::data.table(sk = character(0), jump = numeric(0)))
  sv[, list(jump = max(jump)), by = list(sk = normalise_seat(seat))]
}

.seat_poll_mrp_name_on <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_MRP_NAME", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_MRP_NAME must be \"0\" or \"1\", not ", v)
  v == "1"
}

# Constants of the seat-poll decay (docs/CONSTANTS.md). The half-life prior is
# Pete's choice (2026-10-09, "60 days"); the rest make "weak prior" a number.
SEAT_POLL_HALFLIFE_PRIOR <- 60     # days
SEAT_POLL_HALFLIFE_LOGSD <- 0.7    # prior sd of log(half-life): 60 days, 2-sd range 15 to 245
SEAT_POLL_FLOOR_PRIOR <- 16        # non-sampling error variance, points^2 (sd 4), before any data
SEAT_POLL_FLOOR_K <- 10            # pseudo seat-elections pulling each group's floor to the pool
SEAT_POLL_N_FALLBACK <- 600        # seat sample when no earlier direct poll records one

#' Per-poll weight in a seat's poll average: recency times precision
#'
#' `wt = 0.5^(days / H) / (fp * (100 - fp) / n + floor[group])`: halves every
#' `H` days before polling day, and is the inverse of the poll's error variance
#' (sampling, from the seat sample `n`; MRP has none of its own, its error is
#' all floor) plus a non-sampling floor for its group (`mrp`, `direct`,
#' `sponsored`). A direct poll without a recorded sample takes `p$n_fill`.
#' @keywords internal
.seat_poll_cell_weights <- function(pp, p) {
  w <- .seat_poll_cell_weight_parts(pp, p)
  w$r / (w$sv + w$fl)
}

# The three parts of a poll's weight: recency r, sampling variance sv, non-sampling floor fl.
.seat_poll_cell_weight_parts <- function(pp, p) {
  n <- pp$n_seat
  n[!pp$mrp & !is.finite(n)] <- p$n_fill
  sv <- ifelse(pp$mrp, 0, pp$fp * (100 - pp$fp) / n)
  fl <- unname(p$floor[pp$group])
  # AUSPOL_SEAT_POLL_FIRM_FLOOR: the pollster's own track record scales its
  # group's floor (seat_poll_decay_params(), shrunk toward 1).
  if (.seat_poll_firm_on() && length(p$firm_mult)) {
    m <- unname(p$firm_mult[pp$firm]); m[!is.finite(m)] <- 1
    fl <- fl * m
  }
  list(r = 0.5^(pp$days / p$H), sv = sv, fl = fl)
}

# named numeric vector <-> "a=1;b=2" in one CSV cell (the frozen blend table)
.kv_write <- function(x) if (is.null(x) || !length(x)) "" else paste(sprintf("%s=%.8g", names(x), x), collapse = ";")
.kv_read <- function(s) {
  if (is.na(s) || !nzchar(s)) return(stats::setNames(numeric(0), character(0)))
  kv <- strsplit(strsplit(s, ";", fixed = TRUE)[[1]], "=", fixed = TRUE)
  stats::setNames(as.numeric(vapply(kv, `[`, "", 2)), vapply(kv, `[`, "", 1))
}

.seat_poll_firm_shared_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_FIRM_SHARED")   # amendment 7
.seat_poll_heavy_tail_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_HEAVY_TAIL", "0")   # prereg-seat-poll-heavy-tail (ARM)

# Zero-mean two-component normal mixture on squared standardised errors z2, by EM: weight pi on the wide component,
# scales s1 and k * s1 (k >= 1.5). Returns c(pi, s1, k).
.seat_poll_em2 <- function(z2) {
  z2 <- z2[is.finite(z2)]
  if (length(z2) < 20L) return(c(pi = 0.02, s1 = 1, k = 9))
  p <- 0.05; s1 <- stats::median(z2) / 0.455; k <- 9   # 0.455 = median of a chi-square(1)
  for (it in seq_len(200L)) {
    d1 <- (1 - p) * exp(-z2 / (2 * s1)) / sqrt(s1)
    d2 <- p * exp(-z2 / (2 * s1 * k)) / sqrt(s1 * k)
    r <- d2 / (d1 + d2); r[!is.finite(r)] <- 1
    p_new <- mean(r); s1_new <- sum((1 - r) * z2) / sum(1 - r)
    k_new <- max(1.5, sum(r * z2) / max(sum(r), 1e-9) / s1_new)
    done <- abs(p_new - p) < 1e-7 && abs(k_new - k) < 1e-6
    p <- p_new; s1 <- s1_new; k <- k_new
    if (done) break
  }
  c(pi = p, s1 = s1, k = k)
}
.seat_poll_election_err_on <- function() .seat_poll_onoff("AUSPOL_SEAT_POLL_ELECTION_ERR") # amendment 8
SEAT_POLL_ELECTION_ERR_PRIOR <- 4   # sd 2 points: the prior for an election-wide seat-poll miss (amendment 8)

#' Election-wide seat-poll error variance per class (AUSPOL_SEAT_POLL_ELECTION_ERR)
#'
#' An error every seat poll in an election shares (fed2025's all under-called
#' Labor) cannot be averaged away by more polls or firms. For each EARLIER
#' election with polled cells: `d` = mean over its polled cells of (cell poll
#' average - actual), `s2` = the variance of those differences / cells;
#' `tau2_c = mean over elections of max(0, d^2 - s2)`, shrunk toward the pool
#' over classes by `SEAT_POLL_FLOOR_K` pseudo-elections and the pool toward
#' `SEAT_POLL_ELECTION_ERR_PRIOR`. prereg-seat-poll-method-weights amendment 8.
#' @keywords internal
seat_poll_election_err <- function(target_election) {
  f <- current_seat_predictions()
  els <- if (is.null(f)) character(0) else unique(f$election)
  els <- els[elections_before(els, target_election)]
  d <- data.table::rbindlist(lapply(els, function(e) {
    sp <- NULL; utils::capture.output(sp <- seat_poll_shares(e))
    if (is.null(sp) || !nrow(sp)) return(NULL)
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party, actual = actual_share)]
    sp$seat <- normalise_seat(sp$seat)
    m <- merge(sp[, list(seat, class, poll)], fe, by = c("seat", "class"))[is.finite(actual)]
    if (!nrow(m)) return(NULL)
    m[, list(d = mean(poll - actual), s2 = if (.N > 1) stats::var(poll - actual) / .N else NA_real_, n = .N, election = e), by = class]
  }), fill = TRUE)
  K <- SEAT_POLL_FLOOR_K; pr <- SEAT_POLL_ELECTION_ERR_PRIOR
  if (!nrow(d)) return(c(pooled = pr))
  d <- d[is.finite(s2)]
  if (!nrow(d)) return(c(pooled = pr))
  d$t2 <- pmax(0, d$d^2 - d$s2)
  E <- length(unique(d$election))
  pooled <- (E * mean(d$t2) + K * pr) / (E + K)
  cls <- sort(unique(d$class))
  v <- vapply(cls, function(cl) { x <- d$t2[d$class == cl]; (length(x) * mean(x) + K * pooled) / (length(x) + K) }, numeric(1))
  out <- c(v, pooled = pooled); attr(out, "n_elections") <- E
  out
}

# AUSPOL_SEAT_POLL_FIRM_SHARED: a firm's polls in a cell are ONE measurement. The floor (method and house error) is
# shared by every release from that firm, so it counts once, divided by the recency of the firm's newest poll; only
# sampling variance averages out across its polls. The cell's precision sums over firms. (Seven MRP waves from two
# firms had counted as seven independent measurements: Aston fed2025, amendment 7.)
.seat_poll_firm_shared_cells <- function(per_poll, p, by_cols) {
  w <- .seat_poll_cell_weight_parts(per_poll, p)
  pp <- data.table::copy(per_poll); pp$.r <- w$r; pp$.sv <- w$sv; pp$.fl <- w$fl
  fm <- pp[, list(fp = sum(wt * fp) / sum(wt), n = .N, n_mrp = sum(mrp),
                  prec = 1 / (.fl[which.max(.r)] / max(.r) + if (any(.sv <= 0)) 0 else 1 / sum(1 / .sv))),
           by = c(by_cols, "firm")]
  fm[, list(poll = sum(prec * fp) / sum(prec), n_polls = sum(n), n_mrp = sum(n_mrp), wsum = sum(prec)), by = by_cols]
}

.seat_poll_decay_cache <- new.env(parent = emptyenv())

#' Time-forward decay parameters for the seat polls of one election
#'
#' Fitted on every EARLIER election's polls against its actual result (as
#' [seat_poll_weight()] is): the non-sampling floor per group (`mrp`, `direct`,
#' `sponsored`) is the recency-weighted mean of `(poll - actual)^2` minus
#' sampling variance, each group shrunk toward the pooled floor by
#' `SEAT_POLL_FLOOR_K` pseudo seat-elections and the pool toward
#' `SEAT_POLL_FLOOR_PRIOR`; the half-life `H` maximises the Gaussian profile
#' likelihood of the weighted seat averages' errors (one unit per
#' seat-election) plus a log-normal prior around `SEAT_POLL_HALFLIFE_PRIOR`.
#' Alternates the two three times. With no earlier polls, the priors alone.
#'
#' @param target_election Label such as `"fed2022"`.
#' @return list `H`, `floor` (named by group), `n_fill`, `n_units`, `n_polls`.
#' @export
seat_poll_decay_params <- function(target_election) {
  # keyed on EVERYTHING it reads (every AUSPOL_* variable and every input file's stamp, via the shares memo key):
  # a hand-picked list of switches went stale as soon as GROUPS / SPLIT_ALL were added (2026-10-18)
  key <- paste("DECAY", .seat_poll_memo_key(target_election, 0, FALSE, FALSE, TRUE))
  if (!is.null(.seat_poll_decay_cache[[key]])) return(.seat_poll_decay_cache[[key]])
  grp <- .seat_poll_group_names()
  prior <- list(H = SEAT_POLL_HALFLIFE_PRIOR,
                floor = stats::setNames(vapply(grp, function(g) .seat_poll_group_prior(g, SEAT_POLL_FLOOR_PRIOR), numeric(1)), grp),
                n_fill = SEAT_POLL_N_FALLBACK, n_units = 0L, n_polls = 0L, firm_mult = numeric(0))
  f <- current_seat_predictions()
  els <- if (is.null(f)) character(0) else unique(f$election)
  els <- els[elections_before(els, target_election)]
  rows <- data.table::rbindlist(lapply(els, function(e) {
    pp <- NULL
    utils::capture.output(pp <- seat_poll_shares(e, .raw = TRUE))   # SPIM/SPHK lines once per target, not per earlier election
    if (is.null(pp) || !nrow(pp) || !"poll_id" %in% names(pp)) return(NULL)
    fe <- f[f$election == e, list(seat = normalise_seat(seat), class = party, actual = actual_share)]
    pp$seat <- normalise_seat(pp$seat)
    m <- merge(pp, fe, by = c("seat", "class"))
    m <- m[is.finite(actual)]
    if (!nrow(m)) return(NULL)
    m$unit <- paste(e, m$seat)
    m
  }), fill = TRUE)
  out <- prior
  if (nrow(rows)) {
    nd <- rows$n_seat[!rows$mrp & is.finite(rows$n_seat)]
    n_fill <- if (length(nd)) stats::median(nd) else SEAT_POLL_N_FALLBACK
    nn <- rows$n_seat; nn[!rows$mrp & !is.finite(nn)] <- n_fill
    sv <- ifelse(rows$mrp, 0, rows$fp * (100 - rows$fp) / nn)
    r2 <- (rows$fp - rows$actual)^2 - sv
    H <- SEAT_POLL_HALFLIFE_PRIOR
    grid <- exp(seq(log(7), log(730), length.out = 60))
    U <- length(unique(rows$unit))
    cell <- paste(rows$unit, rows$class)
    for (it in 1:3) {
      rec <- 0.5^(rows$days / H)
      pool_n <- U
      pool <- (pool_n * max(1, sum(rec * r2) / sum(rec)) + SEAT_POLL_FLOOR_K * SEAT_POLL_FLOOR_PRIOR) / (pool_n + SEAT_POLL_FLOOR_K)
      fl <- vapply(grp, function(g) {
        # each group shrinks toward ITS OWN prior: the pool, except opt-in under "method" (amendment 1)
        pg <- .seat_poll_group_prior(g, pool)
        i <- rows$group == g
        if (!any(i)) return(pg)
        ng <- length(unique(rows$unit[i]))
        raw <- max(1, sum(rec[i] * r2[i]) / sum(rec[i]))
        (ng * raw + SEAT_POLL_FLOOR_K * pg) / (ng + SEAT_POLL_FLOOR_K)
      }, numeric(1))
      obj <- vapply(grid, function(h) {
        w <- 0.5^(rows$days / h) / (sv + fl[rows$group])
        avg <- tapply(w * rows$fp, cell, sum) / tapply(w, cell, sum)
        act <- tapply(rows$actual, cell, `[`, 1)
        sse <- sum((avg - act[names(avg)])^2)
        0.5 * U * log(sse / length(avg)) + (log(h) - log(SEAT_POLL_HALFLIFE_PRIOR))^2 / (2 * SEAT_POLL_HALFLIFE_LOGSD^2)
      }, numeric(1))
      H <- grid[which.min(obj)]
    }
    # POLLSTER TRACK RECORD: each firm's recency-weighted (poll - actual)^2
    # minus sampling variance, over its group floor, shrunk toward 1 by
    # SEAT_POLL_FLOOR_K pseudo seat-elections. An unnamed pollster has none.
    rec <- 0.5^(rows$days / H)
    ratio <- pmax(r2, 0) / fl[rows$group]
    firms <- setdiff(unique(rows$firm), "")
    fm <- vapply(firms, function(k) {
      i <- rows$firm == k
      ng <- length(unique(rows$unit[i]))
      raw <- sum(rec[i] * ratio[i]) / sum(rec[i])
      (ng * raw + SEAT_POLL_FLOOR_K) / (ng + SEAT_POLL_FLOOR_K)
    }, numeric(1))
    out <- list(H = H, floor = fl, n_fill = n_fill, n_units = U, n_polls = length(unique(paste(rows$unit, rows$poll_id))),
                firm_mult = fm)
    if (.seat_poll_firm_on() && length(fm))
      cat(sprintf("SPF  %s pollster floor multipliers (1 = its group's floor): %s\n", target_election,
                  paste(sprintf("%s %.2f", names(fm), fm), collapse = ", ")))
  }
  cat(sprintf("SPD  %s seat-poll decay: half-life %.0f days, floor sd %s points, n fill %.0f (%d earlier polls, %d seat-elections%s)\n",
              target_election, out$H, paste(sprintf("%s %.2f", names(out$floor), sqrt(out$floor)), collapse = " / "),
              out$n_fill, out$n_polls, out$n_units, if (out$n_units == 0L) "; priors only" else ""))
  .seat_poll_decay_cache[[key]] <- out
  out
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
  pr <- .seat_poll_prior()
  if (!nrow(rows)) return(list(w = if (is.null(pr)) 0 else pr[["mean"]], raw = NA_real_, se = NA_real_, n = 0L, k = 0L))
  dx <- rows$poll - rows$pred
  dy <- rows$actual - rows$pred
  b <- sum(dx * dy) / sum(dx^2)
  e <- dy - b * dx
  G <- length(unique(rows$unit))
  se2 <- .cluster_se2(sum(tapply(dx * e, rows$unit, sum)^2), sum(dx^2)^2, G)
  w <- if (is.null(pr)) {
    b * b^2 / (b^2 + se2)   # shrunk toward 0 (the pre-2026-10-09 behaviour)
  } else if (!is.finite(se2)) {
    pr[["mean"]]            # one cluster carries no information: the prior alone
  } else {
    # precision-weighted between the prior and the earlier elections' slope
    (pr[["mean"]] / pr[["sd"]]^2 + b / se2) / (1 / pr[["sd"]]^2 + 1 / se2)
  }
  list(w = min(1, max(0, w)), raw = b, se = sqrt(se2), n = nrow(rows), k = length(unique(rows$el)))
}

# AUSPOL_SEAT_POLL_PRIOR: "0" (shipped until 2026-10-09; 0.75 since) shrinks the fitted weight toward 0, so
# an election with no earlier polled cells blends nothing (fed2016 Mayo,
# fed2019 Warringah: a poll had Steggall at 22.3 and the weight was 0). Any
# other value is a prior mean for the weight, combined with the earlier
# elections' slope by precision, its sd from AUSPOL_SEAT_POLL_PRIOR_SD. 0.75 is
# Pete's judgement (2026-10-09), knowingly informed by the fed2022 fit of 0.751:
# a hindsight prior, recorded as such in docs/CONSTANTS.md.
.seat_poll_prior <- function() {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_PRIOR", "0.75")
  m <- suppressWarnings(as.numeric(v))
  if (!is.finite(m) || m < 0 || m > 1) stop("AUSPOL_SEAT_POLL_PRIOR must be a number in 0..1, not ", v)
  if (m == 0) return(NULL)
  s <- suppressWarnings(as.numeric(Sys.getenv("AUSPOL_SEAT_POLL_PRIOR_SD", "0.25")))
  if (!is.finite(s) || s <= 0) stop("AUSPOL_SEAT_POLL_PRIOR_SD must be a positive number")
  c(mean = m, sd = s)
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
    if (.seat_poll_precision_on()) {
      w$vm <- seat_poll_model_var(target_election)
      # everything the precision blend fits, so the frozen table the daily run reads (no seat predictions there,
      # pipeline-overwrite-audit F17) carries it too: election-wide error and the target's independents' salience
      if (.seat_poll_election_err_on()) w$te <- seat_poll_election_err(target_election)
      if (.seat_poll_salience_var_on()) w$si <- .seat_poll_ind_salience(target_election)
    }
    ind_on <- .ind_weight_on()
    if (ind_on) { wi <- seat_poll_ind_weight(target_election); w$w_ind <- wi$w; w$w_ind_raw <- wi$raw; w$w_ind_se <- wi$se; w$w_ind_n <- wi$n }
    tb <- seat_poll_shares(target_election, by_type = TRUE)
    if (write) {
      out <- data.table::copy(tb)
      if (!nrow(out)) out <- data.table::data.table(seat = NA_character_, class = NA_character_, type = NA_character_,
                                                    poll = NA_real_, n_polls = NA_integer_, n_mrp = NA_integer_,
                                                    wsum = if (.seat_poll_decay_on()) NA_real_ else NULL)
      out$w <- w$w; out$w_raw <- w$raw; out$w_se <- w$se; out$w_n <- w$n; out$w_k <- w$k
      out$w_direct <- w$w_direct; out$w_mrp <- w$w_mrp
      if (!is.null(w$vm)) {
        out$vm <- .kv_write(w$vm)
        out$vm_ref <- .kv_write(attr(w$vm, "ref"))
        # the fitted values AND the ones only the log lines print (SPSV, SPSL), so the daily run's log matches the rebuild's
        out$vm_par <- .kv_write(unlist(attributes(w$vm)[intersect(c("g", "g_raw", "g_se", "sal_b", "sal_b_raw", "sal_mean", "sal_se", "sal_n"),
                                                                    names(attributes(w$vm)))]))
      }
      if (!is.null(attr(w$vm, "ht_pi"))) {
        ht <- c(attr(w$vm, "ht_pi"), attr(w$vm, "ht_s1"), attr(w$vm, "ht_k"))
        names(ht) <- c(paste0("pi.", names(attr(w$vm, "ht_pi"))), paste0("s1.", names(attr(w$vm, "ht_s1"))), paste0("k.", names(attr(w$vm, "ht_k"))))
        out$vm_ht <- .kv_write(ht)
      }
      if (!is.null(w$te)) out$te <- .kv_write(w$te)
      if (!is.null(w$si)) out$sal <- if (nrow(w$si)) .kv_write(stats::setNames(w$si$jump, w$si$sk)) else ""
      if (ind_on) { out$w_ind <- w$w_ind; out$w_ind_raw <- w$w_ind_raw; out$w_ind_se <- w$w_ind_se; out$w_ind_n <- w$w_ind_n }
      data.table::fwrite(out, cache)
    }
  } else if (file.exists(cache)) {
    raw <- data.table::fread(cache, showProgress = FALSE)
    if (length(unique(raw$w)) != 1L) stop(cache, " has more than one weight")
    w <- list(w = raw$w[1], raw = raw$w_raw[1], se = raw$w_se[1], n = raw$w_n[1], k = raw$w_k[1],
              w_direct = raw$w_direct[1], w_mrp = raw$w_mrp[1])
    if (.seat_poll_precision_on()) {
      if (!"vm" %in% names(raw)) stop(basename(cache), " was written without the model variance (vm) but AUSPOL_SEAT_POLL_PRECISION_BLEND=1: re-promote it")
      w$vm <- .kv_read(raw$vm[1])
      need <- c(vm_ref = .seat_poll_sizevar_on() || .seat_poll_salience_var_on(), vm_par = .seat_poll_sizevar_on() || .seat_poll_salience_var_on(),
                te = .seat_poll_election_err_on(), sal = .seat_poll_salience_var_on(), vm_ht = .seat_poll_heavy_tail_on())
      miss <- names(need)[need & !names(need) %in% names(raw)]
      if (length(miss)) stop(basename(cache), " was written without ", paste(miss, collapse = ", "),
                             " but the seat-poll switches need them: re-promote it (scripts/promote_rebuild.R)")
      if ("vm_ref" %in% names(raw)) attr(w$vm, "ref") <- .kv_read(raw$vm_ref[1])
      if ("vm_par" %in% names(raw)) { pp <- .kv_read(raw$vm_par[1])
        for (a in names(pp)) attr(w$vm, a) <- pp[[a]]
        for (a in c("g", "sal_b", "sal_mean")) if (is.null(attr(w$vm, a))) attr(w$vm, a) <- 0 }
      if ("vm_ht" %in% names(raw)) {
        ht <- .kv_read(raw$vm_ht[1])
        for (pre in c("pi", "s1", "k")) { x <- ht[startsWith(names(ht), paste0(pre, "."))]; names(x) <- sub("^[a-z0-9]+[.]", "", names(x))
          attr(w$vm, paste0("ht_", pre)) <- x }
      }
      if ("te" %in% names(raw)) w$te <- .kv_read(raw$te[1])
      if ("sal" %in% names(raw)) { sv <- .kv_read(raw$sal[1]); w$si <- data.table::data.table(sk = names(sv), jump = unname(sv)) }
    }
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
    tb <- raw[!is.na(raw$seat), intersect(c("seat", "class", "type", "poll", "n_polls", "n_mrp", "wsum"), names(raw)), with = FALSE]
    if (.seat_poll_decay_on() && !"wsum" %in% names(tb)) {
      # A table shipped before the decay (2026-10-09): stopping here would make
      # fit_seats_full.R publish with no seat-poll blend at all (the w_ind
      # precedent above). Its window averages are used as they are, loudly.
      cat(sprintf("SPB!! %s was written without the decay weights (wsum): its 90-day-window poll averages are used as they are. Re-promote it (scripts/promote_rebuild.R).\n",
                  basename(cache)))
    }
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
  # Types combine by poll count; under AUSPOL_SEAT_POLL_DECAY by their summed
  # per-poll weights, so a stale MRP cannot outvote a fresh direct poll.
  tb$agg_w <- if ("wsum" %in% names(tb)) tb$wsum else tb$n_polls
  tb <- tb[, list(poll = sum(poll * agg_w) / sum(agg_w), n_polls = sum(n_polls), n_mrp = sum(n_mrp),
                  wsum = sum(agg_w)), by = list(seat, class)]
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
  if (ind_on && nrow(tb) && .seat_poll_allpolls_on())
    cat(sprintf("SPAP %s: every poll votes on the independent cell (no direct-only override; MRP and direct by their own weights)\n", target_election))
  if (ind_on && nrow(tb) && !.seat_poll_allpolls_on()) {
    ik <- .ind_direct_cells(tb, tb_type)
    tb$poll[ik$row] <- ik$poll
    wvec[ik$row] <- w$w_ind
    cat(sprintf("SPIW %s: IND weight %.3f (raw %.3f, se %.3f, %d earlier direct IND cells; class-blind %.3f); %d IND cells on a direct poll\n",
                target_election, w$w_ind, w$w_ind_raw, w$w_ind_se, w$w_ind_n, w$w, length(ik$row)))
  }
  prec_on <- .seat_poll_precision_on()
  if (prec_on && nrow(tb)) {
    # PRECISION BLEND: each cell's pull is v / (v + 1/P), P the seat's summed
    # per-poll weights (recency x precision, in 1/points^2) and v our own
    # model's error variance for that class on earlier elections' polled cells.
    # Replaces the fitted w and the IND weight: more, fresher, bigger polls pull
    # harder, and a class we predict badly (IND) is pulled harder by itself.
    if (!.seat_poll_decay_on()) stop("AUSPOL_SEAT_POLL_PRECISION_BLEND=1 needs AUSPOL_SEAT_POLL_DECAY=1 (P is the decayed poll precision)")
    vm <- w$vm
    if (is.null(vm) || !"pooled" %in% names(vm)) stop("seat-poll blend for ", target_election, ": no model variance (vm) for the precision blend")
    # A shipped table without decay weights leaves wsum = n_polls (a count, not
    # a precision in 1/points^2), which would size every pull wrongly.
    if (!"wsum" %in% names(tb_type)) stop("AUSPOL_SEAT_POLL_PRECISION_BLEND=1 needs a seat-poll table with decay weights (wsum): re-promote it")
    v <- unname(vm[tb$class]); v[!is.finite(v)] <- vm[["pooled"]]
    if (.seat_poll_sizevar_on()) {
      g <- attr(vm, "g"); ref <- attr(vm, "ref")
      if (is.null(g) || is.null(ref)) stop("AUSPOL_SEAT_POLL_SIZEVAR=1 but the model variance carries no size exponent")
      rf <- unname(ref[tb$class]); rf[!is.finite(rf)] <- ref[["pooled"]]
      rs <- match(normalise_seat(tb$seat), normalise_seat(rownames(shares)))
      cs <- match(tb$class, colnames(shares))
      pr <- ifelse(is.na(rs) | is.na(cs), rf, shares[cbind(ifelse(is.na(rs), 1L, rs), ifelse(is.na(cs), 1L, cs))])
      v <- v * ((pmax(pr, 0) + 1) / (rf + 1))^g
      cat(sprintf("SPSV %s: model variance scales with predicted size, exponent %.2f (raw %.2f, se %.2f); cell sd %.1f-%.1f\n",
                  target_election, g, attr(vm, "g_raw"), attr(vm, "g_se"), sqrt(min(v)), sqrt(max(v))))
    }
    if (.seat_poll_salience_var_on()) {
      sb <- attr(vm, "sal_b"); if (is.null(sb)) stop("AUSPOL_SEAT_POLL_SALIENCE_VAR=1 but the model variance carries no salience term")
      si <- if (!is.null(w$si)) w$si else .seat_poll_ind_salience(target_election)
      ji <- si$jump[match(normalise_seat(tb$seat), si$sk)]
      mult <- ifelse(tb$class == "IND" & is.finite(ji), exp(sb * (log(pmax(ji, 0) + 0.01) - attr(vm, "sal_mean"))), 1)
      v <- v * mult
      cat(sprintf("SPSL %s: independent model variance x exp(b * salience), b %.2f (raw %.2f, se %.2f, %d earlier cells); %d cells scaled, multiplier %.2f-%.2f\n",
                  target_election, sb, if (is.null(attr(vm, "sal_b_raw"))) NA_real_ else attr(vm, "sal_b_raw"),
                  attr(vm, "sal_se"), attr(vm, "sal_n"), sum(mult != 1),
                  if (any(mult != 1)) min(mult[mult != 1]) else 1, if (any(mult != 1)) max(mult[mult != 1]) else 1))
      for (r in which(tb$class == "IND" & mult != 1 & normalise_seat(tb$seat) %in% c("mcmahon", "curtin", "warringah", "mayo", "goldstein")))
        cat(sprintf("SPSL   %s %s: salience %.3f, multiplier %.2f, model sd %.1f\n", target_election, tb$seat[r], ji[r], mult[r], sqrt(v[r])))
    }
    t2 <- 0
    if (.seat_poll_election_err_on()) {
      te <- if (!is.null(w$te)) w$te else seat_poll_election_err(target_election)
      t2 <- unname(te[tb$class]); t2[!is.finite(t2)] <- te[["pooled"]]
      cat(sprintf("SPEE %s: election-wide poll error added to every cell (%d earlier elections): %s\n", target_election,
                  if (is.null(attr(te, "n_elections"))) 0L else attr(te, "n_elections"),
                  paste(sprintf("%s sd %.1f", names(te), sqrt(te)), collapse = ", ")))
    }
    wvec <- v / (v + 1 / tb$wsum + t2)
    if (.seat_poll_heavy_tail_on()) {
      hp <- attr(vm, "ht_pi"); hs <- attr(vm, "ht_s1"); hk <- attr(vm, "ht_k")
      if (is.null(hp) || is.null(hs) || is.null(hk)) stop("AUSPOL_SEAT_POLL_HEAVY_TAIL=1 but the model variance carries no mixture (re-promote the blend table)")
      pick <- function(x) { y <- unname(x[tb$class]); y[!is.finite(y)] <- x[["pooled"]]; y }
      pi_c <- pick(hp); s1_c <- pick(hs); k_c <- pick(hk)
      rs <- match(normalise_seat(tb$seat), normalise_seat(rownames(shares))); cs <- match(tb$class, colnames(shares))
      pred <- ifelse(is.na(rs) | is.na(cs), NA_real_, shares[cbind(ifelse(is.na(rs), 1L, rs), ifelse(is.na(cs), 1L, cs))])
      gap <- tb$poll - pred; pv <- 1 / tb$wsum + t2
      v1 <- v * s1_c; v2 <- v * s1_c * k_c
      l1 <- (1 - pi_c) * stats::dnorm(gap, 0, sqrt(v1 + pv)); l2 <- pi_c * stats::dnorm(gap, 0, sqrt(v2 + pv))
      wb <- l2 / (l1 + l2); wb[!is.finite(wb)] <- 0
      wvec <- ifelse(is.finite(gap), (1 - wb) * v1 / (v1 + pv) + wb * v2 / (v2 + pv), wvec)
      cat(sprintf("SPHT %s: heavy-tailed model error, badly-wrong weight %s; posterior weight on it > 0.5 in %d of %d cells\n",
                  target_election, paste(sprintf("%s %.3f (x%.1f)", names(hp), hp, hk), collapse = ", "), sum(wb > 0.5), length(wb)))
      for (r in which(tb$class == "IND" & normalise_seat(tb$seat) %in% c("goldstein", "northsydney", "curtin", "warringah", "mcmahon", "mayo")))
        cat(sprintf("SPHT   %s %s IND: model %.1f, polls %.1f, badly-wrong weight %.2f, pull %.2f -> %.1f\n",
                    target_election, tb$seat[r], pred[r], tb$poll[r], wb[r], wvec[r], pred[r] + wvec[r] * gap[r]))
    }
    cat(sprintf("SPPB %s: precision blend, pull median %.2f (range %.2f-%.2f) over %d cells; model sd by class %s\n",
                target_election, stats::median(wvec), min(wvec), max(wvec), nrow(tb),
                paste(sprintf("%s %.1f", names(vm), sqrt(vm)), collapse = ", ")))
  }
  if (!nrow(tb) || (!prec_on && w$w <= 0 && !(ind_on && is.finite(w$w_ind) && w$w_ind > 0))) {
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
  shares <- row_shift_exact(before, shares, target_election, "seat-poll blend")   # audit F16 (RSX1); default = whole-row rescale
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
    se2 <- .cluster_se2(sum(tapply(dx * e, r$unit, sum)^2), sum(dx^2)^2, G)
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
  shares <- row_shift_exact(before, shares, target_election, "seat-poll blend (mode 2)")   # audit F16 (RSX1)
  cat(sprintf("SPB2 %s: w_direct %.3f, w_mrp %.3f (pooled %.3f); applied %d direct and %d MRP cells across %d seats; mean |change| %.2f points
",
              target_election, w$w_direct, w$w_mrp, w$w, sum(ok & tb$type == "direct"), sum(ok & tb$type == "mrp"),
              length(unique(i[ok])), mean(abs(shares - before)[unique(i[ok]), , drop = FALSE])))
  shares
}

#' Cluster-robust variance `meat / bread * G / (G - 1)`, G clusters
#'
#' Returns `Inf` outright below two clusters. With ONE cluster the sandwich has nothing to compare and its
#' score sum is ~0 by construction, so the old `G / max(1, G - 1)` returned a
#' near-zero SE and the shrinkage passed the slope through untouched: fed2019's
#' blend weight was 1.000, fitted on fed2016's single polled seat (Mayo),
#' against a hindsight-best 0.29. One cluster is no information: `Inf`, so the
#' shrunk weight is 0. `AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER="legacy"` restores the
#' old factor (screening only).
#' @keywords internal
.cluster_se2 <- function(meat, bread, G) {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER", "none")
  if (!v %in% c("none", "legacy")) stop("AUSPOL_SEAT_POLL_W_SINGLE_CLUSTER must be \"none\" or \"legacy\", not ", v)
  if (v == "legacy") return(meat / bread * G / max(1, G - 1))
  # Inf directly, never meat * Inf: with one cluster the score sum is ~0 by
  # construction and is often exactly 0, and 0 * Inf is NaN (review 2026-10-08).
  if (G < 2) Inf else meat / bread * G / (G - 1)
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
  # Read once per process per key (seat_poll_shares() calls this for every
  # distinct election): same all-AUSPOL_* + file-stamp key, copy returned.
  # `f` and its hand-keyed sibling are stamped themselves: a caller may pass
  # any file (a test's tempfile), not only the repo copy (review, 2026-10-10).
  key <- paste("FILE", f, .seat_poll_memo_key("", 0, FALSE, FALSE, FALSE,
               extra = c(f, file.path(dirname(f), c("hand_keyed_primaries.csv", "seat_poll_corrections.csv")))), sep = "#")
  .seat_poll_memoised(key, function() .read_seat_polls_file_impl(f))
}

#' @keywords internal
.read_seat_polls_file_impl <- function(f) {
  s <- .seat_poll_coalition_dedup(.seat_poll_apply_corrections(data.table::fread(f, showProgress = FALSE), f))
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

#' Correct seat-poll figures the source page got wrong (seat_poll_corrections.csv)
#'
#' One row per wrong figure: the poll (election, seat_name, pollster,
#' fieldwork_end), the party label as scraped, the value the scrape holds
#' (`fp_wrong`), the value the pollster published (`fp_right`) and where that
#' was read. Applied after every scrape, so a refetch cannot bring the error
#' back. A correction whose `fp_wrong` is not found exactly once stops the run:
#' a silently unmatched correction is a fix that quietly stopped applying.
#' First case: Wikipedia's RedBridge Melbourne Nov 2024 row had the three
#' major figures in the wrong columns (Accent Research's PDF, 2026-10-18).
#' Prints SPCX. `AUSPOL_SEAT_POLL_CORRECTIONS` ("1"; "0" off).
#' @keywords internal
.seat_poll_apply_corrections <- function(s, f) {
  v <- Sys.getenv("AUSPOL_SEAT_POLL_CORRECTIONS", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_SEAT_POLL_CORRECTIONS must be \"0\" or \"1\", not ", v)
  cf <- file.path(dirname(f), "seat_poll_corrections.csv")
  if (v == "0" || !file.exists(cf)) return(s)
  cx <- data.table::fread(cf, showProgress = FALSE, colClasses = list(character = c("fieldwork_end")))
  if (!nrow(cx)) return(s)
  if (any(!nzchar(cx$source))) stop(basename(cf), ": every correction needs a source")
  fpn <- suppressWarnings(as.numeric(s$fp))
  for (i in seq_len(nrow(cx))) {
    hit <- which(s$election == cx$election[i] & s$seat_name == cx$seat_name[i] & s$pollster == cx$pollster[i] &
                 as.character(s$fieldwork_end) == cx$fieldwork_end[i] & s$party == cx$party[i] & s$row_type == "poll" &
                 is.finite(fpn) & abs(fpn - cx$fp_wrong[i]) < 1e-9)
    if (length(hit) != 1L)
      stop(sprintf("SPCX! correction %d (%s %s %s %s %s %s -> %s) matched %d rows, not 1: the scrape changed; check %s",
                   i, cx$election[i], cx$seat_name[i], cx$pollster[i], cx$fieldwork_end[i], cx$party[i],
                   cx$fp_wrong[i], cx$fp_right[i], length(hit), basename(cf)))
    s$fp[hit] <- if (is.character(s$fp)) as.character(cx$fp_right[i]) else cx$fp_right[i]
  }
  cat(sprintf("SPCX %d seat-poll figure(s) corrected from %s: %s\n", nrow(cx), basename(cf),
              paste(unique(paste(cx$election, cx$seat_name, cx$pollster, cx$fieldwork_end)), collapse = "; ")))
  s
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
  split_all <- .seat_poll_splitall_on()
  lump <- c("OTH_RIGHT", "ONP", "OTH")
  fe <- f[f$election == el & (split_all | f$party %in% lump)]
  if (!nrow(fe)) return(s)
  fe$seat <- normalise_seat(fe$seat)
  add <- list(); drop <- integer(0)
  for (id in unique(s$poll_id)) {
    r_oth <- which(s$poll_id == id & s$class == "OTH" & is.finite(s$fp))
    if (length(r_oth) != 1L || s$fp[r_oth] < SEAT_POLL_IND_MAP_MIN_OTH) next
    oth_fig <- s$fp[r_oth]
    fs <- fe[fe$seat == normalise_seat(s$seat_name[r_oth])]
    if (!nrow(fs)) next
    if (split_all) {
      # every class standing here (our prediction above 0) gets a share of the poll's OTH in proportion to what we
      # expect of it BEYOND what the poll already reports for that class (the shipped rule's residual, extended from
      # OTH_RIGHT/ONP/OTH to every class). A named class is NOT excluded: Kennedy 2022's poll names the UAP (our
      # OTH_RIGHT) at 6 while Katter (also OTH_RIGHT, expected 44.7) sits in its OTH 43; excluding named classes gave
      # Katter none of it (P(win) 0.994 -> 0.067 in the first screen). But a class that runs ONE candidate (ALP, LNP,
      # GRN, ONP) and is named is fully reported, so the poll's OTH holds none of it: only the classes that pool several
      # candidates (IND, OTH_RIGHT, OTH) keep a residual claim once named.
      nm1 <- intersect(unique(s$class[s$poll_id == id & is.finite(s$fp)]), c("ALP", "LNP", "GRN", "ONP"))
      lump_k <- c(setdiff(unique(fs$party[is.finite(fs$xgb_pred_seat) & fs$xgb_pred_seat > 0]), c(nm1, "OTH")), "OTH")
      pred <- vapply(lump_k, function(k) sum(fs$xgb_pred_seat[fs$party == k], na.rm = TRUE), numeric(1))
      named <- vapply(lump_k, function(k) if (k == "OTH") 0 else
        sum(s$fp[s$poll_id == id & s$class == k & is.finite(s$fp)]), numeric(1))
      resid <- pmax(pred - named, 0)
      if (sum(resid) <= 0) next
      part <- oth_fig * resid / sum(resid)
      cat(sprintf("SPIM %s %s | %s | OTH %.1f split over every unnamed class: %s\n", el, s$seat_name[r_oth], id, oth_fig,
                  paste(sprintf("%s %.1f", names(part), part), collapse = ", ")))
    } else {
    pred <- vapply(lump, function(k) sum(fs$xgb_pred_seat[fs$party == k], na.rm = TRUE), numeric(1))
    named <- vapply(lump, function(k) if (k == "OTH") 0 else
      sum(s$fp[s$poll_id == id & s$class == k & is.finite(s$fp)]), numeric(1))
    resid <- pmax(pred - named, 0)
    if (max(resid[c("OTH_RIGHT", "ONP")]) < SEAT_POLL_IND_MAP_KNOWN_FRAC * oth_fig) next
    part <- oth_fig * resid / sum(resid)
    cat(sprintf("SPIM %s %s | %s | OTH %.1f split by as-at expectation: OTH_RIGHT %.1f, ONP %.1f, OTH %.1f\n",
                el, s$seat_name[r_oth], id, oth_fig, part[["OTH_RIGHT"]], part[["ONP"]], part[["OTH"]]))
    }
    for (k in names(part)[part > 0]) {
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
    list(b = b, se2 = .cluster_se2(sum(tapply(dx * e, r$seat, sum)^2), sum(dx^2)^2, G))
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
  # A one-cluster group carries no information (se2 Inf): it must not enter
  # tau2 (one Inf turns the mean to -Inf, so tau2 0 for every class) or dbar
  # (all-Inf weights give 0/0). Review 2026-10-08.
  g <- g[is.finite(g$se2)]
  if (!nrow(g)) return(none)
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

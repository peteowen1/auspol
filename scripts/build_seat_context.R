# Seat context for EVERY training election, from our own corpus.
#
# The seat-file features (incumbent party, retiring member, first-term member
# and party) come from the anchor's seat files, which exist for recent
# elections only: on 13 of 22 training pairs they are 100% missing, so the
# seat model could not see who held a seat for half its corpus. Pete,
# 2026-09-28: incomplete data gets completed, not routed around.
# docs/plans/prereg-seat-context-complete-2026-09-28.md.
#
# Phase 1 (this script): sitting member and incumbent class (previous winner,
# replaced by an intervening by-election winner's class), retiring (the sitting
# member is in external/reference/retirements/retirements.csv for the target),
# soph_cand (the sitting member first won the seat at the previous election)
# and soph_party (the seat changed class at the previous election).
# Phase 2 (margin, previous swing) is a separate build.
#
# VALIDATION before use: on pairs where load_seats() has values, agreement
# must be >= 95% (CON5 prints it, and the script stops below 90% so a broken
# derivation cannot be written as a fill).
#
# Writes output/seat-context.csv. Emits SC* codes.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })

C <- fread("output/candidacies.csv", showProgress = FALSE)[is.finite(votes)]
C[, s := normalise_seat(seat)]
name_key <- function(n, g) vapply(paste(n, fifelse(is.na(g), "", g)), function(x) {
  tk <- unique(strsplit(gsub("[^A-Z]+", " ", toupper(x)), " +")[[1]]); paste(sort(tk[nzchar(tk)]), collapse = " ")
}, character(1), USE.NAMES = FALSE)
C[, nk := name_key(name, given)]
dts <- election_dates()
C[, edate := as.Date(unname(dts[election]))]

# winner per seat per election: `elected`, else the highest primary (vic2010
# carries no elected flags)
win <- C[, {
  w <- which(elected %in% TRUE)
  if (length(w) != 1L) w <- which.max(votes)
  .(win_class = party[w], win_nk = nk[w], win_name = name[w])
}, by = .(election, region, s, edate)]
cat(sprintf("CON1  winners: %d seat-elections over %d elections\n", nrow(win), uniqueN(win$election)))

BY <- fread("external/reference/byelections/byelection-winners.csv", showProgress = FALSE)
BY[, `:=`(s = normalise_seat(seat), bdate = as.Date(date), by_class = classify_party(winner_party_raw))]
RT <- fread("external/reference/retirements/retirements.csv", showProgress = FALSE)
RT[, `:=`(s = normalise_seat(seat), rk = name_key(member, NA))]

pairs <- all_election_pairs()
out <- rbindlist(lapply(pairs, function(pr) {
  el <- pr$election; pv <- pr$prev
  cur <- unique(C[election == el, .(s, seat, region)])
  if (!nrow(cur)) return(NULL)
  ed <- as.Date(unname(dts[el])); pd <- as.Date(unname(dts[pv]))
  pw <- win[election == pv, .(s, prev_class = win_class, sitting_nk = win_nk, sitting_name = win_name)]
  # the election before the previous one, for the first-term flags
  ppv <- win[region == cur$region[1] & edate < pd][edate == max(edate)]
  ppw <- ppv[, .(s, pp_class = win_class, pp_nk = win_nk)]
  x <- merge(cur, pw, by = "s", all.x = TRUE)
  x <- merge(x, ppw, by = "s", all.x = TRUE)
  # an intervening by-election replaces the class (and the member is unknown)
  bw <- BY[region == cur$region[1] & bdate > pd & bdate < ed][order(bdate)][, .SD[.N], by = s][, .(s, by_class)]
  x <- merge(x, bw, by = "s", all.x = TRUE)
  x[, incumbent_class := fifelse(!is.na(by_class), by_class, prev_class)]
  x[!is.na(by_class), sitting_nk := NA_character_]
  # retiring: the sitting member (by name) or the seat is in the retirement list
  rt <- RT[election == el]
  x[, retiring := (!is.na(sitting_nk) & sitting_nk %in% rt$rk) | s %in% rt$s]
  x[, retire_reason := rt$reason[match(s, rt$s)]]
  # first-term member / party: the seat changed hands at the previous election
  x[, soph_party := !is.na(pp_class) & !is.na(prev_class) & prev_class != pp_class & is.na(by_class)]
  x[, soph_cand := !is.na(pp_nk) & !is.na(sitting_nk) & sitting_nk != pp_nk]
  x[, `:=`(pair = el, prev = pv)]
  x[, .(pair, prev, region, seat, s, incumbent_class, sitting_name, retiring, retire_reason, soph_cand, soph_party,
        by_election = !is.na(by_class), has_prev = !is.na(prev_class))]
}), fill = TRUE)
cat(sprintf("CON2  seat context: %d seat-pairs over %d pairs; previous winner found for %.1f%%\n",
            nrow(out), uniqueN(out$pair), 100 * mean(out$has_prev)))

# ---- VALIDATION against the seat files where they exist --------------------
# The seat file stores party CODES; the same map fit_xgb_primary_v6.R uses
# (codes not listed, e.g. ALP, GRN, IND, pass through as they are).
INCUMBENT_CODE_CLASS <- c(LIB = "LNP", NAT = "LNP", LNP = "LNP",
                          SFF = "OTH_RIGHT", KAP = "OTH_RIGHT", CA = "IND")
val <- rbindlist(lapply(unique(out$pair), function(el) {
  yr <- as.integer(sub("^[a-z]+", "", el)); rg <- sub("[0-9]{4}$", "", el)
  sf <- tryCatch(as.data.table(load_seats(yr, rg)), error = function(e) NULL)
  if (is.null(sf) || !nrow(sf)) return(NULL)
  sf[, `:=`(s = normalise_seat(seat), sf_class = ifelse(incumbent %in% names(INCUMBENT_CODE_CLASS), unname(INCUMBENT_CODE_CLASS[incumbent]), incumbent))]   # the seat file stores CODES (ALP, LIB): the same mapping fit_xgb_primary_v6.R uses
  m <- merge(out[pair == el], sf[, .(s, sf_class, sf_ret = retirement, sf_sc = soph_cand, sf_sp = soph_party)], by = "s")
  m[, pair := el]
  m
}), fill = TRUE)
if (nrow(val)) {
  agree <- val[, .(seats = .N, incumbent = round(mean(incumbent_class == sf_class, na.rm = TRUE), 3),
                   retiring = round(mean(retiring == sf_ret, na.rm = TRUE), 3),
                   soph_cand = round(mean(soph_cand == sf_sc, na.rm = TRUE), 3),
                   soph_party = round(mean(soph_party == sf_sp, na.rm = TRUE), 3)), by = pair]
  cat("CON5  agreement with the seat file where it exists (share of seats; 1.000 = identical):\n"); print(agree)
  tot <- val[, .(incumbent = mean(incumbent_class == sf_class, na.rm = TRUE), retiring = mean(retiring == sf_ret, na.rm = TRUE))]
  cat(sprintf("CON5  overall: incumbent %.3f, retiring %.3f over %d seats\n", tot$incumbent, tot$retiring, nrow(val)))
  dis <- val[incumbent_class != sf_class]
  if (nrow(dis)) { cat("CON5  incumbent disagreements (first 12):\n"); print(dis[1:min(12, .N), .(pair, seat, ours = incumbent_class, seat_file = sf_class, by_election)]) }
  if (tot$incumbent < 0.90) stop("CON5! incumbent agreement below 90%; the derivation is not trustworthy enough to fill with")
}
# ---- PHASE 2: margin and previous swing ------------------------------------
# The seat file's `margin` is Labor's two-party-preferred vote against the
# Coalition minus 50, even where they were not the final two (Melbourne,
# Greens-held: +25.0), and `prev_swing` is that figure's change at the previous
# election. Estimated for every seat and election with the method the
# published two-party series uses (derive_tpp()): Labor's primary plus each
# other class's preferences at that election's flow rate, on the
# non-exhausted total. Validated against the seat file below.
cy <- load_election_cycles(); FA <- load_preference_flows()
flow_map <- function(fl, cls) {
  key <- switch(cls, GRN = "GRN", ONP = "ONP", OTH_RIGHT = if ("UAP" %in% fl$party) "UAP" else "OTH", "OTH")
  r <- fl[fl$party == key]; if (!nrow(r)) r <- fl[fl$party == "OTH"]
  if (!nrow(r)) return(c(flow = 0.5, ex = 0))
  c(flow = r$flow_alp[1] / 100, ex = if ("exhaust" %in% names(r) && is.finite(r$exhaust[1])) r$exhaust[1] / 100 else 0)
}
tpp_of <- function(el) {
  rg <- sub("[0-9]{4}$", "", el); yr <- as.integer(sub("^[a-z]+", "", el))
  fl <- tryCatch(flows_for(FA, yr, rg, cycles = cy, quiet = TRUE), error = function(e) NULL)
  if (is.null(fl)) return(NULL)
  d <- C[election == el, .(v = sum(votes)), by = .(s, party)]
  d[, share := 100 * v / sum(v), by = s]
  mf <- rbindlist(lapply(unique(d$party), function(p) data.table(party = p, flow = flow_map(fl, p)[["flow"]], ex = flow_map(fl, p)[["ex"]])))
  d <- merge(d, mf, by = "party")
  d[, .(tpp = 100 * (sum(share[party == "ALP"]) + sum((share * flow * (1 - ex))[!party %in% c("ALP", "LNP")])) /
             (sum(share[party %in% c("ALP", "LNP")]) + sum((share * (1 - ex))[!party %in% c("ALP", "LNP")]))), by = s]
}
all_el <- unique(C$election)
TPP <- rbindlist(lapply(all_el, function(el) { t <- tpp_of(el); if (is.null(t)) NULL else t[, election := el] }))
cat(sprintf("SC7  two-party estimates: %d seat-elections over %d elections\n", nrow(TPP), uniqueN(TPP$election)))
fwrite(TPP, "output/seat-tpp-estimates.csv")   # read by the live forecast under AUSPOL_SEAT_CONTEXT_MARGIN=all
prev_of <- setNames(sapply(pairs, `[[`, "prev"), sapply(pairs, `[[`, "election"))
ord <- unique(C[, .(election, region, edate)])[order(region, edate)]
ord[, prev := shift(election), by = region]
pp_of <- setNames(ord$prev, ord$election)
out[, `:=`(t_prev = TPP[.(out$prev, out$s), on = .(election, s), tpp],
           t_pp = TPP[.(unname(pp_of[out$prev]), out$s), on = .(election, s), tpp])]
out[, `:=`(margin_est = t_prev - 50, prev_swing_est = t_prev - t_pp)]
out[, c("t_prev", "t_pp") := NULL]
cat(sprintf("SC7  margin estimated for %.1f%% of seat-pairs, previous swing for %.1f%%\n",
            100 * mean(is.finite(out$margin_est)), 100 * mean(is.finite(out$prev_swing_est))))
if (nrow(val)) {
  vm <- merge(out[, .(pair, s, margin_est, prev_swing_est)],
              rbindlist(lapply(unique(val$pair), function(el) {
                yr <- as.integer(sub("^[a-z]+", "", el)); rg <- sub("[0-9]{4}$", "", el)
                sf <- as.data.table(load_seats(yr, rg)); sf[, .(pair = el, s = normalise_seat(seat), sf_margin = margin, sf_swing = prev_swing)] })),
              by = c("pair", "s"))
  vm <- vm[is.finite(margin_est) & is.finite(sf_margin)]
  r_m <- vm[, cor(margin_est, sf_margin)]; mae_m <- vm[, mean(abs(margin_est - sf_margin))]
  vs <- vm[is.finite(prev_swing_est) & is.finite(sf_swing)]
  r_s <- if (nrow(vs) > 10) vs[, cor(prev_swing_est, sf_swing)] else NA_real_
  cat(sprintf("SC8  margin vs seat file: r %.3f, mean |diff| %.2f points over %d seats | previous swing: r %.3f over %d seats\n",
              r_m, mae_m, nrow(vm), r_s, nrow(vs)))
  print(vm[, .(seats = .N, r_margin = round(cor(margin_est, sf_margin), 3), mae = round(mean(abs(margin_est - sf_margin)), 2)), by = pair])
  if (!is.finite(r_m) || r_m < 0.9) cat("SC8! margin agreement below the pre-registered 0.9; margin will NOT be filled\n")
  out[, margin_ok := is.finite(r_m) && r_m >= 0.9]
  out[, swing_ok := is.finite(r_s) && r_s >= 0.9]
}

fwrite(out, "output/seat-context.csv")
cat(sprintf("CON6  wrote output/seat-context.csv (%d rows)\n", nrow(out)))

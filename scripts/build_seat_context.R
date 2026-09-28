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
# must be >= 95% (SC5 prints it, and the script stops below 90% so a broken
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
cat(sprintf("SC1  winners: %d seat-elections over %d elections\n", nrow(win), uniqueN(win$election)))

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
cat(sprintf("SC2  seat context: %d seat-pairs over %d pairs; previous winner found for %.1f%%\n",
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
  cat("SC5  agreement with the seat file where it exists (share of seats; 1.000 = identical):\n"); print(agree)
  tot <- val[, .(incumbent = mean(incumbent_class == sf_class, na.rm = TRUE), retiring = mean(retiring == sf_ret, na.rm = TRUE))]
  cat(sprintf("SC5  overall: incumbent %.3f, retiring %.3f over %d seats\n", tot$incumbent, tot$retiring, nrow(val)))
  dis <- val[incumbent_class != sf_class]
  if (nrow(dis)) { cat("SC5  incumbent disagreements (first 12):\n"); print(dis[1:min(12, .N), .(pair, seat, ours = incumbent_class, seat_file = sf_class, by_election)]) }
  if (tot$incumbent < 0.90) stop("SC5! incumbent agreement below 90%; the derivation is not trustworthy enough to fill with")
}
fwrite(out, "output/seat-context.csv")
cat(sprintf("SC6  wrote output/seat-context.csv (%d rows)\n", nrow(out)))

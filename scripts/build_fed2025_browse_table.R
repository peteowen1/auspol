# A full, candidate-level browsable table for fed2025: projected vs actual
# primary, personal and party-class prior history, national swing context,
# salience, per-seat log loss, and AEF's own primary prediction where
# available. Built for eyeballing/filtering, not for modelling -- every
# quantity here already exists elsewhere; this just assembles them once.
#
# Emits FBT* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

C <- fread("output/candidacies.csv", showProgress = FALSE)
SAL <- fread("output/salience-v6.csv", showProgress = FALSE)
PROJ <- fread("output/dump-shares-blended-fed2025.csv", showProgress = FALSE)
BT <- fread("output/backtest-fed-p2025-lv110_867-fc-sh10-ab6e03.csv", showProgress = FALSE)

ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))
TARGET <- "fed2025"; PREV <- "fed2022"

# ---- candidate rows, fed2025 -------------------------------------------------
cand <- C[C$election == TARGET, .(seat, party, name, given, surname, actual_pcv = pcv, elected)]

# ---- own personal prior vote, ANY party (search_form matched) --------------
PREVT <- C[C$election == PREV]
cand[, .k := search_form(given, surname, name)]
PREVT[, .k := search_form(given, surname, name)]
cand[, .s := ns(seat)]; PREVT[, .s := ns(seat)]
prev_best <- PREVT[nzchar(.k), .(own_prev_pcv = max(pcv, na.rm = TRUE),
                                 own_prev_party = party[which.max(pcv)]), by = .(.s, .k)]
cand <- merge(cand, prev_best, by = c(".s", ".k"), all.x = TRUE)

# ---- party-CLASS prior vote in this seat (not personal) --------------------
class_prev <- PREVT[, .(class_prev_pcv = sum(pcv, na.rm = TRUE)), by = .(.s = ns(seat), party)]
cand <- merge(cand, class_prev, by = c(".s", "party"), all.x = TRUE)
cand[is.na(class_prev_pcv), class_prev_pcv := 0]

# ---- party national % this election and last (vote-weighted) --------------
nat_share <- function(el) {
  # NOT `tot`: candidacies.csv has its OWN column literally named "tot" (total
  # enrolment), and a bare `tot` inside C[...] binds to THAT column, not this
  # local scalar -- the exact NSE trap CLAUDE.md already records six times.
  # Dividing a per-group scalar sum by a per-ROW column vector doesn't
  # collapse the group, so `by = party` silently returned one row per INPUT
  # row (1122) instead of one per party (7).
  total_votes_all <- sum(C[C$election == el, votes], na.rm = TRUE)
  C[C$election == el, .(nat_pct = 100 * sum(votes, na.rm = TRUE) / total_votes_all), by = party]
}
nat_now <- nat_share(TARGET); nat_prev <- nat_share(PREV)
cand <- merge(cand, nat_now[, .(party, party_national_now = nat_pct)], by = "party", all.x = TRUE)
cand <- merge(cand, nat_prev[, .(party, party_national_prev = nat_pct)], by = "party", all.x = TRUE)

# ---- our PROJECTED share (party-class level -- the model has no per-candidate
# projection, see docs/reviews/b1-sizing-2026-08-27.md) ----------------------
PROJ[, .s := ns(seat)]
cand <- merge(cand, PROJ[, .(.s, party, projected_share = projected_share)], by = c(".s", "party"), all.x = TRUE)

# ---- salience: seat-relative percentile, this candidate specifically ------
SAL_T <- SAL[SAL$election == TARGET]
SAL_T[, jp := rank(jump, ties.method = "average") / .N]
SAL_T[, .k := keyword]; SAL_T[, .s := ns(seat)]
cand <- merge(cand, SAL_T[, .(.s, party, .k = .k, salience_jump = jump, salience_pctile = jp)],
             by.x = c(".s", "party", ".k"), by.y = c(".s", "party", ".k"), all.x = TRUE)
cand[, salience_pm_relative := NA_real_]  # not yet built -- see chat: needs raw-batch re-derivation

# ---- actual winner, per seat -------------------------------------------------
seat_winner <- cand[elected == TRUE, .(seat, actual_winner_party = party, actual_winner_name = name)]
cand <- merge(cand, seat_winner, by = "seat", all.x = TRUE)

# ---- our result + per-seat log loss (party-level, from the backtest) -------
BT[, .s := ns(seat)]
BT[, our_prob_on_actual := prob]
BT[, our_pred_party := pred]
BT[, our_ll := -log(pmax(prob, 1e-6))]
cand <- merge(cand, BT[, .(.s, our_pred_party, our_prob_on_actual, our_ll)], by = ".s", all.x = TRUE)

# ---- AEF's own primary prediction (median seatFpBands) ---------------------
aef <- fromJSON("external/reference/aef/2025fed-summary.json", simplifyVector = FALSE)$report
aef_lookup <- setNames(vapply(aef$partyAbbr, function(p) as.character(p[[2]]), ""),
                       vapply(aef$partyAbbr, function(p) as.character(p[[1]]), ""))
seat_names <- unlist(aef$seatNames)
aef_rows <- list()
for (i in seq_along(seat_names)) {
  bands <- aef$seatFpBands[[i]]
  for (b in bands) {
    idx <- as.character(b[[1]]); vals <- unlist(b[[2]])
    cls <- unname(aef_lookup[idx])
    if (is.na(cls) || !length(vals)) next
    med <- if (length(vals) >= 8) vals[8] else NA_real_  # 8th of 15 = 50th percentile
    aef_rows[[length(aef_rows) + 1L]] <- data.table(seat = seat_names[i], party = cls, aef_primary_median = med)
  }
}
AEF <- rbindlist(aef_rows, fill = TRUE)
AEF <- AEF[, .(aef_primary_median = sum(aef_primary_median, na.rm = TRUE)), by = .(seat, party)]  # sum: some party codes map >1 index (named+generic)
AEF[, .s := ns(seat)]
cand <- merge(cand, AEF[, .(.s, party, aef_primary_median)], by = c(".s", "party"), all.x = TRUE)

# ---- final table -------------------------------------------------------------
OUT <- cand[, .(
  seat, party, name, given, surname,
  actual_pcv = round(actual_pcv, 2),
  elected,
  projected_share = round(projected_share, 2),
  aef_primary_median = round(aef_primary_median, 2),
  own_prev_pcv = round(own_prev_pcv, 2),
  own_prev_party,
  class_prev_pcv = round(class_prev_pcv, 2),
  party_national_prev = round(party_national_prev, 2),
  party_national_now = round(party_national_now, 2),
  salience_pctile = round(salience_pctile, 3),
  salience_jump = round(salience_jump, 3),
  salience_pm_relative,
  actual_winner_party, actual_winner_name,
  our_pred_party, our_prob_on_actual = round(our_prob_on_actual, 4),
  our_ll = round(our_ll, 3)
)]
setorder(OUT, seat, -actual_pcv)
fwrite(OUT, "output/fed2025-browse-table.csv")
cat(sprintf("FBT1  wrote output/fed2025-browse-table.csv: %d rows, %d seats\n",
            nrow(OUT), uniqueN(OUT$seat)))
cat(sprintf("FBT2  coverage: projected %.0f%% | AEF %.0f%% | own_prev %.0f%% | salience %.0f%%\n",
            100*mean(!is.na(OUT$projected_share)), 100*mean(!is.na(OUT$aef_primary_median)),
            100*mean(!is.na(OUT$own_prev_pcv)), 100*mean(!is.na(OUT$salience_pctile))))

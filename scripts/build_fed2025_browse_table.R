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

# ---- seat_salience and election_salience ------------------------------------
# Both are "how loud is this candidate against the loudest in scope", now that
# fetch_salience_v6.R covers MAJORS too (2026-08-28). Before that the majors
# were filtered out before Trends was ever queried, so a seat had no denominator
# worth the name -- the loudest candidate in scope was whoever the emergence
# gate happened to fetch.
#
#   seat_salience     = 100 * jump / max(jump in that seat)
#   election_salience = 100 * jump / max(jump in that election)
#
# The PM/Premier is no longer a denominator, only the anchor that makes separate
# Trends batches comparable at all. Design settled with Pete on 2026-08-28.
#
# Denominators are computed OUTSIDE the brackets and given names that match no
# column. That is the data.table NSE collision this repo has now hit SEVEN
# times, most recently in this very script (a local `tot` shadowed
# candidacies.csv's own `tot` column and turned a 7-row groupby into 1122).
#
# TWO THINGS A RATIO TO THE MAXIMUM GETS WRONG, both found by an anchor check
# that asked for the range before anyone looked at a value. The first draft of
# this block produced seat_salience down to -182,224.
#
#   1. `jump` GOES NEGATIVE -- 9.2% of fed2025 and up to 38% of WA 2017. A
#      negative jump means search interest FELL over the campaign. That is "no
#      surge", which is 0 salience, not negative salience. Floored, not dropped.
#   2. A seat whose loudest candidate scored 0.0032 (Dobell) had another
#      candidate's -2.94 divided by it, giving -91,300. Flooring at 0 fixes that
#      arithmetically: a ratio of non-negatives to their own maximum is in
#      [0, 100] at ANY positive denominator.
#
# NO MINIMUM-DENOMINATOR CONSTANT. The first attempt required the seat maximum
# to reach 1% of the ELECTION maximum, and the coverage guard below caught it
# immediately: seat_salience fell to 3% populated. Albanese's 18.03 is a
# thousandfold outlier against a seat-max median of 0.019, so the election
# maximum is a useless yardstick for a seat, and any absolute floor would be a
# number picked off a scale with no anchor -- the thing docs/CONSTANTS.md exists
# to stop.
#
# Instead the DENOMINATOR IS PUBLISHED, as seat_salience_basis. Grayndler's 100
# rests on 18.03 and Burt's on 0.00097, and a reader can now see which is which
# rather than having the distinction silently thrown away or silently kept.
SAL_T[, jump_pos := pmax(jump, 0)]
seat_den <- SAL_T[, .(seat_jump_max = max(jump_pos)), by = .s]
election_jump_max <- max(SAL_T$jump_pos)
cand <- merge(cand, seat_den, by = ".s", all.x = TRUE)
cand[, salience_jump_pos := pmax(salience_jump, 0)]

# A seat where NOTHING was measured has no denominator, and 0/0 must not become
# a number. NA means "not measured", which is a different claim from 0, and this
# repo has already lost a seat to a zero from a sparse table being read as a
# measurement.
cand[, seat_salience := fifelse(!is.na(seat_jump_max) & seat_jump_max > 0,
                                100 * salience_jump_pos / seat_jump_max, NA_real_)]
cand[, seat_salience_basis := fifelse(!is.na(seat_jump_max) & seat_jump_max > 0,
                                      seat_jump_max, NA_real_)]
cand[, election_salience := if (election_jump_max > 0)
       100 * salience_jump_pos / election_jump_max else NA_real_]

# Both are shares of a maximum over non-negative values, so [0, 100] holds BY
# CONSTRUCTION. Asserted anyway: the first draft violated it by five orders of
# magnitude and every row count, type and coverage check still passed.
for (.c in c("seat_salience", "election_salience")) {
  .v <- cand[[.c]]; .v <- .v[!is.na(.v)]
  if (length(.v) && (min(.v) < -1e-9 || max(.v) > 100 + 1e-9)) {
    stop("FBT! ", .c, " outside [0, 100]: min ", signif(min(.v), 6),
         " max ", signif(max(.v), 6), ". A ratio to a maximum cannot leave ",
         "that range unless the numerator is negative or the denominator is noise.")
  }
}

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
  seat_salience = round(seat_salience, 1),
  seat_salience_basis = signif(seat_salience_basis, 3),
  election_salience = round(election_salience, 1),
  actual_winner_party, actual_winner_name,
  our_pred_party, our_prob_on_actual = round(our_prob_on_actual, 4),
  our_ll = round(our_ll, 3)
)]
setorder(OUT, seat, -actual_pcv)
fwrite(OUT, "output/fed2025-browse-table.csv")
cat(sprintf("FBT1  wrote output/fed2025-browse-table.csv: %d rows, %d seats\n",
            nrow(OUT), uniqueN(OUT$seat)))
# COVERAGE, not presence. A column can be present, correctly typed and 0%
# populated while every row-count check passes -- the rule in ~/.claude/CLAUDE.md
# after 4,978,201 names were silently discarded in citiusverse.
cat(sprintf("FBT3  salience denominators: %d seats with a positive max, %d without; election max %.2f
",
            uniqueN(cand[seat_jump_max > 0]$.s), uniqueN(cand[is.na(seat_jump_max) | seat_jump_max <= 0]$.s),
            election_jump_max))
cat(sprintf("FBT3  seat_salience %.0f%% populated | election_salience %.0f%%
",
            100*mean(!is.na(OUT$seat_salience)), 100*mean(!is.na(OUT$election_salience))))
if (mean(!is.na(OUT$seat_salience)) < 0.10) {
  stop("FBT! seat_salience is under 10% populated -- the join or the denominator ",
       "is wrong. A column that lands empty must fail the build, not ship.")
}
cat(sprintf("FBT2  coverage: projected %.0f%% | AEF %.0f%% | own_prev %.0f%% | salience %.0f%%\n",
            100*mean(!is.na(OUT$projected_share)), 100*mean(!is.na(OUT$aef_primary_median)),
            100*mean(!is.na(OUT$own_prev_pcv)), 100*mean(!is.na(OUT$salience_pctile))))

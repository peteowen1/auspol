# Defector over-call check (docs/reviews/defector-overcarry-2026-10-14.md).
#
# Cases use fit_defector_discount()'s own definition (R/candidate_returns.R): a major-party
# (ALP/LNP/NAT) candidate with >= 10% at the previous election who stands under a non-major
# label in the same seat (or its renamed successor) at the next. Losing candidates count
# (AUSPOL_DEFECT_POOLED=2); was_mp marks sitting members. Each case is joined to
# output/forecasts.csv (the published as-at path) on election, seat and the defector's class,
# and to the old party's row in the same seat.
#
# Over-call = predicted primary minus actual, percentage points; positive = we gave too much.
#   Rscript scripts/diag_defector_overcarry.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
C  <- fread(file.path("output", "candidacies.csv"), showProgress = FALSE)
FC <- fread(file.path("output", "forecasts.csv"), showProgress = FALSE)
cat(sprintf("DFO0  candidacies %d rows, %d elections; forecasts %d rows, %d elections\n",
            nrow(C), uniqueN(C$election), nrow(FC), uniqueN(FC$election)))
MAJ <- c("ALP", "LNP", "NAT")
kk <- function(d) match_key(surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
                                        if ("name" %in% names(d)) d$name else NA_character_),
                             given_of(if ("given" %in% names(d)) d$given else NA_character_,
                                      if ("name" %in% names(d)) d$name else NA_character_), "person")
rn <- seat_rename_map()
cases <- rbindlist(lapply(all_election_pairs(), function(pr) {
  PREVT <- C[C$election == pr$prev]; NOWT <- C[C$election == pr$election]
  if (!nrow(PREVT) || !nrow(NOWT) || !"elected" %in% names(PREVT)) return(NULL)
  PREVT <- copy(PREVT)[, `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
  NOWT  <- copy(NOWT)[,  `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
  align_person_keys(NOWT, PREVT); align_person_keys(PREVT, NOWT)
  PREVT[, .s2 := .s]; PREVT[.s %in% names(rn), .s2 := rn[.s]]
  a <- PREVT[nzchar(.k) & party %in% MAJ & pcv >= 10,
             list(.s, .s2, .k, old_party = party, prior = pcv, was_mp = elected %in% TRUE)]
  a <- unique(rbind(a[, list(.s, .k, old_party, prior, was_mp)], a[, list(.s = .s2, .k, old_party, prior, was_mp)]))
  b <- NOWT[nzchar(.k) & !party %in% MAJ, list(.s, .k, seat, name = if ("name" %in% names(NOWT)) name else .k,
                                                new_party = party, now = pcv)]
  m <- merge(a, b, by = c(".s", ".k"))
  if (!nrow(m)) return(NULL)
  m[, election := pr$election]
  m[, list(election, seat, name, old_party, new_party, was_mp, prior, now)]
}), fill = TRUE)
cases <- unique(cases, by = c("election", "seat", "name"))
cat(sprintf("DFO1  %d defector cases over %d elections (%d sitting members)\n",
            nrow(cases), uniqueN(cases$election), sum(cases$was_mp)))
FC[, .s := normalise_seat(seat)]; cases[, .s := normalise_seat(seat)]
# the defector's own row: same election, seat, class (the new label)
dfr <- FC[, list(pred = xgb_pred[1], base = base_pred[1], act = actual_share[1], n_in_class = .N),
          by = list(election, .s, new_party = party)]
M <- merge(cases, dfr, by = c("election", ".s", "new_party"))
# a class with two candidates in one seat cannot be attributed to the defector alone
M <- M[n_in_class == 1L]
opr <- FC[, list(election, .s, old_party = party, old_pred = xgb_pred, old_act = actual_share)]
opr <- unique(opr, by = c("election", ".s", "old_party"))
M <- merge(M, opr, by = c("election", ".s", "old_party"), all.x = TRUE)
cat(sprintf("DFO2  %d of %d cases scored (forecasts row for the defector's class, sole candidate in it); dropped: %s\n",
            nrow(M), nrow(cases), paste(setdiff(cases[, paste(election, seat)], M[, paste(election, seat)]), collapse = ", ")))
M[, `:=`(over = pred - act, over_base = base - act, old_over = old_pred - old_act)]
setorder(M, -over)
print(M[, list(election, seat, name, old_party, new_party, was_mp, prior = round(prior, 1), base = round(base, 1),
               pred = round(pred, 1), act = round(act, 1), over = round(over, 1), old_over = round(old_over, 1))], nrows = 200)
s <- function(x, lab) {
  cat(sprintf("DFO3  %-16s n=%2d  over-call mean %+.2f (se %.2f), median %+.2f, over-called %d; base mean %+.2f; old party mean %+.2f\n",
              lab, nrow(x), mean(x$over), sd(x$over) / sqrt(nrow(x)), median(x$over), sum(x$over > 0),
              mean(x$over_base), mean(x$old_over, na.rm = TRUE)))
}
s(M, "all"); s(M[was_mp == TRUE], "sitting members"); s(M[was_mp == FALSE], "losing candidates")
s(M[startsWith(election, "fed")], "federal"); s(M[!startsWith(election, "fed")], "state")
fwrite(M, file.path("output", "defector-overcarry.csv"))
cat("DFO4  wrote output/defector-overcarry.csv\n")

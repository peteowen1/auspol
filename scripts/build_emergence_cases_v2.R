# CANDIDATE-level emergence cases. Pete's specification, 2026-09-11.
#
# WHY v1 WAS WRONG, and it was wrong in four ways at once:
#
# 1. IT MEASURED THE PARTY, NOT THE PERSON. Wentworth's IND class went 33.0 to
#    35.8 -- a rise of 2.8, so v1 scored it "not an emergence". But Kerryn
#    Phelps (32.4% in 2019) did not stand, and Allegra SPENDER went from
#    nothing to 35.8%. That is the emergence, and party-level share cannot see
#    it. Same in Kooyong (Yates 9.0 -> Ryan 40.3) and Mackellar (Thompson 12.2
#    -> Scamps 38.1). Three of the six 2022 teals were TRAINING NEGATIVES in
#    the model built to predict teals.
#
# 2. IT TRAINED ON EVERYTHING. All 13,352 rows including ALP and LNP in every
#    seat, which cannot emerge by construction, so the base rate was diluted to
#    1.5% and a calibrated model can barely leave the floor.
#
# 3. IT DEFINED EMERGENCE BY A STARTING LEVEL ("below 10% last time"), which
#    excludes exactly the seats where a strong independent vote already exists
#    and a new person inherits and grows it.
#
# 4. IT IGNORED WHETHER THE CANDIDATE HAD EVER STOOD BEFORE, which is both
#    knowable in advance and the single most obvious feature of an emergence.
#
# THE v2 DEFINITION: a NON-MAJOR candidate whose OWN vote rose by at least
# AUSPOL_EMERGE_RISE points (default 10) on what THAT PERSON polled in THAT
# seat last time -- zero if they did not stand. Majors excluded from the
# population entirely; sitting members flagged rather than dropped, so the
# choice stays measurable.
#
# Emits E2* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
RISE <- as.numeric(Sys.getenv("AUSPOL_EMERGE_RISE", "10"))
MAJORS <- c("ALP", "LNP", "NAT")
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
C[, cls := classify_party(party_raw, party_ab)]
C[, sn := normalise_seat(seat)]
# Person key: surname plus given initial, the same shape candidate_returns()
# uses. Not the full name -- commissions are inconsistent about middle names
# and capitalisation between elections.
C[, pk := match_key(surname_of(surname, name), given_of(given, name), "initial")]

PREV <- c(fed2007="fed2004", fed2010="fed2007", fed2013="fed2010", fed2016="fed2013",
          fed2019="fed2016", fed2022="fed2019", fed2025="fed2022",
          nsw2019="nsw2015", nsw2023="nsw2019", qld2020="qld2017", qld2024="qld2020",
          sa2026="sa2022", vic2014="vic2010", vic2018="vic2014", vic2022="vic2018",
          wa2001="wa1996", wa2005="wa2001", wa2008="wa2005", wa2013="wa2008",
          wa2017="wa2013", wa2021="wa2017", wa2025="wa2021")

rows <- list()
for (el in names(PREV)) {
  now <- C[C$election == el & nzchar(pk)]
  prv <- C[C$election == PREV[[el]] & nzchar(pk)]
  if (!nrow(now) || !nrow(prv)) { cat(sprintf("E20! %s: no rows -- skipped\n", el)); next }
  # THIS PERSON'S own vote in THIS seat last time. match() on a built key, not
  # merge()-then-positional -- data.table::merge() sorts and would splice the
  # wrong person's history onto a candidate.
  k_now <- paste(now$sn, now$pk)
  idx <- match(k_now, paste(prv$sn, prv$pk))
  now[, own_prev := ifelse(is.na(idx), 0, prv$pcv[idx])]
  now[, stood_before := as.integer(!is.na(idx))]
  # Did ANYONE of this class stand here last time, and at what level? Keeps the
  # party-level context available as a feature without making it the target.
  cl <- prv[, .(cls_prev = sum(pcv, na.rm = TRUE)), by = .(sn, cls)]
  ci <- match(paste(now$sn, now$cls), paste(cl$sn, cl$cls))
  now[, cls_prev := ifelse(is.na(ci), 0, cl$cls_prev[ci])]
  now[, pair := el]
  rows[[el]] <- now[, .(pair, seat, party = cls, name, pk, pcv, own_prev, stood_before,
                        cls_prev, elected, historic_elected, ballot_position)]
}
A <- rbindlist(rows, fill = TRUE)
A[, rise := pcv - own_prev]

cat(sprintf("E21  %d candidate-rows over %d pairs\n", nrow(A), uniqueN(A$pair)))

# 2. THE POPULATION: non-majors only. A major cannot "emerge" -- it contests
# every seat every time -- and including them is what diluted v1's base rate.
POP <- A[!party %in% MAJORS]
cat(sprintf("E22  population after dropping %s: %d rows (v1 trained on all %d)\n",
            paste(MAJORS, collapse = "/"), nrow(POP), nrow(A)))

POP[, emerged := as.integer(rise >= RISE)]
cat(sprintf("E23  target: a non-major candidate whose OWN vote rose >= %.0f points\n", RISE))
cat(sprintf("E23  emergences: %d of %d = %.2f%% base rate (v1: 201 of 13352 = 1.51%%)\n",
            sum(POP$emerged), nrow(POP), 100 * mean(POP$emerged)))
cat("\nE24  by class -- Pete's point that ONP/GRN are not the same animal as IND\n")
print(POP[, .(candidates = .N, emerged = sum(emerged),
              rate = sprintf("%.1f%%", 100 * mean(emerged)),
              first_time = sprintf("%.0f%%", 100 * mean(stood_before == 0)),
              mean_rise_if_emerged = round(mean(rise[emerged == 1]), 1)),
          by = party][order(-emerged)])
cat("\nE25  first-time contender: is it a flag worth having?\n")
print(POP[, .(candidates = .N, emerged = sum(emerged),
              rate = sprintf("%.1f%%", 100 * mean(emerged))),
          by = .(first_time = stood_before == 0)])

cat("\nE26  THE TEST THAT MATTERS -- the six fed2022 teals, which v1 flagged 3 of 6:\n")
tl <- POP[pair == "fed2022" & party == "IND" &
          seat %in% c("Wentworth", "Mackellar", "Kooyong", "Curtin", "North Sydney", "Goldstein")]
print(tl[, .(seat, candidate = name, own_prev = round(own_prev, 1), pcv = round(pcv, 1),
             rise = round(rise, 1), first_time = stood_before == 0, emerged)][order(-rise)])
cat(sprintf("E26  v2 flags %d of %d.\n", sum(tl$emerged), nrow(tl)))

fwrite(POP[, .(pair, seat, party, name, pk, own_prev, cls_prev, pcv, rise,
               stood_before, emerged, elected, ballot_position)],
       file.path(OUT, "emergence-cases-v2.csv"))
cat(sprintf("\nE27  wrote %s/emergence-cases-v2.csv\n", OUT))

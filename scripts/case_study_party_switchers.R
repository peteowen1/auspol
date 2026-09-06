# CASE STUDY: an incumbent who changes party label between elections.
#
# WHY. Philip Donato held Orange as a Shooter (OTH_RIGHT) in 2019 and won it as
# an independent (IND) in 2023 -- found while fixing candidate_returns(), which
# had been matching WITHIN party and calling him a new candidate. Fixing that
# bug surfaced the case; this asks whether it is common enough, and consistent
# enough in direction, to warrant its own model adjustment.
#
# METHOD. candidate_returns() now matches the same person across a seat
# regardless of party. A row where the person returns AND the party differs
# from what they stood under last time is a party-switch. For each, compare
# what UNIFORM SWING under their NEW class would have predicted against what
# they actually got.
#
# Emits PS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
C[, `:=`(sur = surname_of(surname, name), giv = given_of(given, name))]
E <- unique(C[, .(region, year)])[order(region, year)]
rows <- list()

for (k in seq_len(nrow(E))) {
  rg <- E$region[k]; yr <- E$year[k]
  py <- suppressWarnings(max(C[region == rg & year < yr, year]))
  if (!is.finite(py)) next
  NOWT <- C[region == rg & year == yr]; PREVT <- C[region == rg & year == py]
  sh <- intersect(unique(NOWT$seat), unique(PREVT$seat))
  if (length(sh) < 20) next

  # Statewide swing per class, for the uniform-swing counterfactual.
  swf <- function(d) d[, .(v = sum(votes)), by = party][, .(party, pct = 100*v/sum(v))]
  sa <- swf(PREVT); sb <- swf(NOWT)
  sw <- merge(sa, sb, by = "party", all = TRUE, suffixes = c("_a","_b"))
  sw[is.na(pct_a), pct_a := 0][is.na(pct_b), pct_b := 0][, swing := pct_b - pct_a]

  key <- function(d) paste(gsub("[^a-z]", "", tolower(d$sur)),
                           gsub("[^a-z]", "", tolower(d$giv)))
  NOWT[, .k := key(.SD)]; PREVT[, .k := key(.SD)]
  ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))
  NOWT[, .s := ns(seat)]; PREVT[, .s := ns(seat)]

  N <- NOWT[seat %in% sh & nzchar(.k), .(.s, seat, party, pcv, .k)]
  P <- PREVT[seat %in% sh & nzchar(.k), .(.s, party, pcv, .k)]
  M <- merge(N, P, by = c(".s", ".k"), suffixes = c("_now", "_prev"))
  sw2 <- M[party_now != party_prev]                       # THE PARTY SWITCHERS
  if (!nrow(sw2)) next
  sw2 <- merge(sw2, sw[, .(party, swing)], by.x = "party_now", by.y = "party", all.x = TRUE)
  sw2[, uniform_pred := pmax(0, pcv_prev + swing)]
  sw2[, election := paste0(rg, yr)][, prev_election := paste0(rg, py)]
  rows[[length(rows) + 1L]] <- sw2[, .(election, prev_election, seat, party_prev, party_now,
                                       pcv_prev, uniform_pred, pcv_now,
                                       error = uniform_pred - pcv_now)]
}
R <- rbindlist(rows)
cat(sprintf("PS1  %d party-switch cases across %d elections\n", nrow(R), uniqueN(R$election)))

cat("\nPS2  every case, in full\n")
print(R[order(-abs(error)), .(election, seat, from = party_prev, to = party_now,
      prev = round(pcv_prev,1), uniform_pred = round(uniform_pred,1),
      actual = round(pcv_now,1), error = round(error,1))], row.names = FALSE)

cat(sprintf("\nPS3  mean error %.2f (uniform_pred - actual) | mean |error| %.2f | n %d\n",
            mean(R$error), mean(abs(R$error)), nrow(R)))
cat(sprintf("PS3  over-predicted (uniform too high): %d | under-predicted: %d | exact: %d\n",
            sum(R$error > 1), sum(R$error < -1), sum(abs(R$error) <= 1)))
cat(sprintf("PS3  SE of the mean error: %.2f | t vs 0: %+.2f\n",
            sd(R$error)/sqrt(nrow(R)), mean(R$error)/(sd(R$error)/sqrt(nrow(R)))))

cat("\nPS4  by DIRECTION of switch -- toward or away from a major party\n")
MAJ <- c("ALP","LNP","NAT")
R[, dir := fifelse(party_prev %in% MAJ & !party_now %in% MAJ, "major -> minor",
            fifelse(!party_prev %in% MAJ & party_now %in% MAJ, "minor -> major",
                    "minor -> minor"))]
print(R[, .(n=.N, mean_error=round(mean(error),2), mean_abs=round(mean(abs(error)),2)), by=dir],
      row.names=FALSE)

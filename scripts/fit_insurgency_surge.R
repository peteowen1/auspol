# The insurgency SURGE model: how often a non-major's vote jumps, and by how
# much. Fitted LEAVE-ONE-ELECTION-OUT over the six federal elections.
#
# WHY NOT REUSE THE WIN-RISK MODEL. scripts/fit_insurgency_risk.R fits
# P(a non-major WINS). Using that as a surge probability is circular: it would
# make every surge a winning surge, when in reality a surge often falls short.
# The generative quantity is the SURGE ITSELF -- an observable event that does
# not condition on the outcome -- and whether it wins is then decided by the
# count, which is the whole point of doing this generatively rather than by
# overriding the winner.
#
# SURGE is defined as the best non-major GAINING >= 10 points on their share at
# the previous election. The threshold is pre-registered in
# docs/plans/prereg-insurgency-surge.md and is not tuned here.
#
# LEAKAGE. Features come from the `from` election only. The fold being predicted
# never contributes to the fit that scores it.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

P <- "external/elections"
FP  <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)
WIN <- fread(file.path(P, "aec-fed-winners.csv"), showProgress = FALSE)
MAJ <- c("ALP", "LNP", "NAT")
SURGE_THRESHOLD <- 10

FP[, tot := sum(votes), by = .(election, seat)]
FP[, pcv := 100 * votes / tot]

PAIRS <- list(c("fed2007","fed2010"), c("fed2010","fed2013"), c("fed2013","fed2016"),
              c("fed2016","fed2019"), c("fed2019","fed2022"), c("fed2022","fed2025"))
rows <- list()
for (k in PAIRS) {
  from <- k[1]; to <- k[2]
  a <- FP[election == from]; b <- FP[election == to]
  pa <- a[!party %in% MAJ, .(nm_party = party[which.max(pcv)], nm_from = max(pcv)), by = seat]
  pb <- b[!party %in% MAJ, .(nm_to = max(pcv)), by = seat]
  m  <- merge(pa, pb, by = "seat")
  hw <- WIN[election == from, .(seat, prev = winner)]
  m  <- merge(m, hw, by = "seat", all.x = TRUE)
  m[, nm_held := as.integer(!is.na(prev) & !prev %in% MAJ)]
  m[, `:=`(gain = nm_to - nm_from, pair = to)]
  rows[[to]] <- m
}
D <- rbindlist(rows)
D[, surge := as.integer(gain >= SURGE_THRESHOLD)]

cat(sprintf("IS1  %d seat-elections | %d surges (>= %+d pts) = %.2f%%\n",
            nrow(D), sum(D$surge), SURGE_THRESHOLD, 100 * mean(D$surge)))
print(D[, .(seats = .N, surges = sum(surge),
            rate = round(100 * mean(surge), 1)), by = pair][order(pair)],
      row.names = FALSE)

# ---- how big is a surge, given one happened? -------------------------------
# Fitted on surging seats only, and reported by whether a non-major already
# held the seat -- an incumbent independent has nowhere to surge from, which is
# why their measured gain is +1.5 against +16.3 for a seat with no incumbent.
sg <- D[surge == 1]
cat(sprintf("IS2  surge size: mean %+.1f | sd %.1f | median %+.1f | n %d\n",
            mean(sg$gain), sd(sg$gain), median(sg$gain), nrow(sg)))
print(sg[, .(n = .N, mean = round(mean(gain), 1), sd = round(sd(gain), 1)),
         by = nm_held][order(nm_held)], row.names = FALSE)

# ---- P(surge), leave-one-election-out --------------------------------------
FORM <- surge ~ log1p(nm_from) + nm_held
D[, q_loeo := NA_real_]
for (e in unique(D$pair)) {
  tr <- D[pair != e]; te <- which(D$pair == e)
  m  <- suppressWarnings(glm(FORM, data = tr, family = binomial()))
  D[te, q_loeo := predict(m, newdata = D[te], type = "response")]
}
stopifnot(!anyNA(D$q_loeo))

n1 <- sum(D$surge); n0 <- nrow(D) - n1
r  <- rank(D$q_loeo)
auc <- (sum(r[D$surge == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
cat(sprintf("IS3  out-of-sample AUC for P(surge): %.3f over %d surges\n", auc, n1))

D[, qb := cut(q_loeo, c(-1, .02, .05, .10, .20, 1))]
cat("IS3  predicted surge rate vs realised, OUT OF SAMPLE:\n")
print(D[, .(seats = .N, surges = sum(surge),
            said = round(100 * mean(q_loeo), 1),
            happened = round(100 * mean(surge), 1)), by = qb][order(qb)],
      row.names = FALSE)

# A surge is NOT a win. Reporting the conditional rate makes that concrete and
# is the number that would be wrong if the win-risk model had been reused here.
wn <- WIN[, .(pair = election, seat, won_by = winner)]
D2 <- merge(D, wn, by = c("pair", "seat"))
D2[, nm_win := as.integer(!won_by %in% MAJ)]
cat(sprintf("IS4  of %d surges, %d produced a non-major win (%.0f%%)\n",
            sum(D2$surge), sum(D2$surge & D2$nm_win),
            100 * mean(D2$nm_win[D2$surge == 1])))
cat(sprintf("IS4  of %d non-surges, %d produced one (%.1f%%)\n",
            sum(!D2$surge), sum(!D2$surge & D2$nm_win),
            100 * mean(D2$nm_win[D2$surge == 0])))

fwrite(D[, .(pair, seat, nm_party, nm_from, nm_held, q_loeo, gain, surge)],
       "output/fed-insurgency-surge.csv")
cat("IS5  wrote output/fed-insurgency-surge.csv\n")

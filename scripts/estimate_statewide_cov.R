# How do statewide party votes move TOGETHER between elections?
#
# Against docs/plans/prereg-statewide-covariance.md. Arm B needs the covariance
# of statewide first-preference CHANGES; this estimates it from the ten election
# pairs the corpus holds -- six federal, two Victorian, one NSW, one South
# Australian.
#
# WHY IT IS NEEDED. simulate_seat_contests() draws each party's statewide
# deviation independently, so a simulation where One Nation runs hot is equally
# likely to pair with a strong Coalition as a weak one. Votes come from
# somewhere, and this measures where.
#
# THE HONEST LIMIT, recorded as refusal V3 before any of this ran: One Nation is
# near zero and unmoving in nine of the ten pairs. Its column of this matrix is
# informed by South Australia 2026 and essentially nothing else, however many
# elections the other columns rest on.
#
# Emits CV* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
PARTIES <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH", "OTH_RIGHT")

share_of <- function(dt) {
  s <- dt[, .(v = sum(votes)), by = party]
  out <- setNames(rep(0, length(PARTIES)), PARTIES)
  m <- intersect(s$party, PARTIES)
  out[m] <- 100 * s$v[match(m, s$party)] / sum(s$v)
  out
}

fed <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)
PAIRS <- list()
for (k in list(c(2007, 2010), c(2010, 2013), c(2013, 2016), c(2016, 2019),
               c(2019, 2022), c(2022, 2025))) {
  PAIRS[[length(PAIRS) + 1L]] <- list(
    name = sprintf("fed%d", k[2]),
    a = share_of(fed[election == sprintf("fed%d", k[1])]),
    b = share_of(fed[election == sprintf("fed%d", k[2])]))
}
for (k in list(c(2014, 2018), c(2018, 2022))) {
  PAIRS[[length(PAIRS) + 1L]] <- list(
    name = sprintf("vic%d", k[2]),
    a = share_of(fread(file.path(P, sprintf("vec-%d-vic-firstprefs.csv", k[1])), showProgress = FALSE)),
    b = share_of(fread(file.path(P, sprintf("vec-%d-vic-firstprefs.csv", k[2])), showProgress = FALSE)))
}
PAIRS[[length(PAIRS) + 1L]] <- list(
  name = "nsw2023",
  a = share_of(fread(file.path(P, "nswec-2019-nsw-firstprefs.csv"), showProgress = FALSE)),
  b = share_of(fread(file.path(P, "nswec-2023-nsw-firstprefs.csv"), showProgress = FALSE)))
PAIRS[[length(PAIRS) + 1L]] <- list(
  name = "sa2026",
  a = share_of(fread(file.path(P, "ecsa-2022-sa-firstprefs.csv"), showProgress = FALSE)),
  b = share_of(fread(file.path(P, "ecsa-2026-sa-firstprefs.csv"), showProgress = FALSE)))

D <- t(vapply(PAIRS, function(p) p$b - p$a, numeric(length(PARTIES))))
rownames(D) <- vapply(PAIRS, function(p) p$name, character(1))
colnames(D) <- PARTIES
cat(sprintf("\nCV1  statewide first-preference CHANGE, %d election pairs\n", nrow(D)))
print(round(D, 2))

# Each row should sum to about zero: shares that rise must come from shares that
# fall. A row that does not is a party class missing from one side of the pair.
rs <- rowSums(D)
cat(sprintf("\nCV2  row sums (should be ~0): %s\n",
            paste(sprintf("%+.2f", rs), collapse = ", ")))
if (max(abs(rs)) > 0.5) {
  stop("Election pair(s) ", paste(rownames(D)[abs(rs) > 0.5], collapse = ", "),
       " have first preferences that do not sum to the same total on both ",
       "sides, so a party class is missing from one of them and the change is ",
       "not a change.")
}

CO <- stats::cor(D)
cat("\nCV3  correlation of statewide changes\n")
print(round(CO, 2))
cat(sprintf("\nCV3  the pair that matters for One Nation: cor(ONP, LNP) = %+.2f\n",
            CO["ONP", "LNP"]))
cat(sprintf("CV3  and cor(ONP, ALP) = %+.2f\n", CO["ONP", "ALP"]))
cat("CV3  V3 applies: nine of ten pairs have One Nation near zero, so its\n")
cat("CV3  column is South Australia 2026 and little else.\n")

# How much of One Nation's column is one election? Refuse to let that be
# invisible: recompute without South Australia and print both.
noSA <- stats::cor(D[rownames(D) != "sa2026", ])
cat(sprintf("\nCV4  without SA 2026: cor(ONP, LNP) = %+.2f (from %+.2f)\n",
            noSA["ONP", "LNP"], CO["ONP", "LNP"]))
cat(sprintf("CV4  One Nation's change without SA: %s\n",
            paste(sprintf("%+.2f", D[rownames(D) != "sa2026", "ONP"]), collapse = ", ")))

# Shrunk toward the diagonal at a weight FIXED IN ADVANCE by the plan, not tuned.
LAMBDA <- 0.5
SH <- LAMBDA * CO + (1 - LAMBDA) * diag(nrow(CO))
dimnames(SH) <- dimnames(CO)
cat(sprintf("\nCV5  shrunk toward independence at lambda = %.2f (pre-registered)\n", LAMBDA))
print(round(SH, 2))

saveRDS(list(change = D, cor = CO, cor_shrunk = SH, lambda = LAMBDA,
             parties = PARTIES),
        file.path("output", "statewide-cov.rds"))
cat("\nCV6  wrote output/statewide-cov.rds\n")

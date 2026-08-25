suppressMessages(library(data.table))
# What is observable BEFORE an election that flags a non-major insurgency?
#
# The top-end error is one failure mode: 8 of 9 misses at pred_p > 0.9999 were
# a non-major taking a seat called safe for a major (Wilkie, Oakeshott, Bandt,
# Palmer, McGowan, Steggall, Chaney, Dai Le). A flat `shrink` caps EVERY seat at
# 95% to absorb a risk that lives in a small identifiable subset.
#
# NOTHING HERE MAY USE THE ELECTION BEING PREDICTED. Every feature is computed
# from the `from` election only.
P <- "external/elections"
FP  <- fread(file.path(P, "aec-fed-firstprefs.csv"), showProgress = FALSE)
WIN <- fread(file.path(P, "aec-fed-winners.csv"), showProgress = FALSE)
MAJ <- c("ALP", "LNP", "NAT")

cat(sprintf("firstprefs: %d rows | elections: %s\n", nrow(FP),
            paste(sort(unique(FP$election)), collapse = " ")))
cat("parties:\n"); print(FP[, .N, by = party][order(-N)])

FP[, tot := sum(votes), by = .(election, seat)]
FP[, pcv := 100 * votes / tot]

PAIRS <- list(c("fed2007","fed2010"), c("fed2010","fed2013"), c("fed2013","fed2016"),
              c("fed2016","fed2019"), c("fed2019","fed2022"), c("fed2022","fed2025"))

rows <- list()
for (k in PAIRS) {
  from <- k[1]; to <- k[2]
  a <- FP[election == from]; b <- FP[election == to]
  # --- features from `from` only ---
  f <- a[, .(
    nm_prior   = sum(pcv[!party %in% MAJ]),          # non-major share last time
    nm_best    = max(c(0, pcv[!party %in% MAJ])),    # best single non-major
    n_parties  = .N,
    top1       = max(pcv),
    top2       = sort(pcv, decreasing = TRUE)[2]
  ), by = seat]
  f[, margin_prior := top1 - top2]
  wf <- WIN[election == from, .(seat, prev_winner = winner)]
  f <- merge(f, wf, by = "seat", all.x = TRUE)
  f[, nm_held := as.integer(!is.na(prev_winner) & !prev_winner %in% MAJ)]
  # --- outcome at `to` ---
  wt <- WIN[election == to, .(seat, won_by = winner)]
  f <- merge(f, wt, by = "seat")
  f[, nm_win := as.integer(!won_by %in% MAJ)]
  f[, `:=`(pair = to)]
  rows[[to]] <- f
}
D <- rbindlist(rows)
fwrite(D, "output/fed-upset-features.csv")

cat(sprintf("\n=== %d seat-elections, %d won by a non-major (%.2f%%) ===\n",
            nrow(D), sum(D$nm_win), 100 * mean(D$nm_win)))
print(D[, .(seats = .N, nm_wins = sum(nm_win)), by = pair][order(pair)], row.names = FALSE)

cat("\n=== do the features separate the upsets? ===\n")
for (v in c("nm_prior", "nm_best", "margin_prior", "n_parties", "nm_held")) {
  s <- D[, .(mean = round(mean(get(v)), 2)), by = nm_win]
  cat(sprintf("  %-13s  no-upset %7.2f | upset %7.2f\n", v,
              s[nm_win == 0, mean], s[nm_win == 1, mean]))
}

cat("\n=== how much of the risk sits in seats a non-major ALREADY held? ===\n")
print(D[, .(seats = .N, nm_wins = sum(nm_win),
            rate = round(100 * mean(nm_win), 1)), by = nm_held][order(nm_held)],
      row.names = FALSE)

cat("\n=== and by how big the best non-major was last time ===\n")
D[, nb := cut(nm_best, c(-1, 5, 10, 15, 20, 30, 100))]
print(D[, .(seats = .N, nm_wins = sum(nm_win),
            rate = round(100 * mean(nm_win), 1)), by = nb][order(nb)], row.names = FALSE)

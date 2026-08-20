# Federal preference distributions -> transfers, winners and final margins.
#
# The AEC distribution files are one row per (division, count, candidate,
# calculation type). At each count after the first, the excluded candidate's
# "Transfer Count" is NEGATIVE and every recipient's is positive -- which is
# exactly the (from, to, votes) shape build_flow_matrix() wants. The Elected
# column gives the commission's own declaration, so truth never has to come from
# our own exclusion machinery.
#
# WHY IT MATTERS THAT THESE ARE FEDERAL: the House uses FULL preferential
# voting, so no ballot exhausts -- verified, zero exhausted rows in 2022.
# Victoria is also full preferential, so these matrices are system-compatible
# with the Victorian forecast. NSW is OPTIONAL preferential and exhausts about
# 12%, so NSW transfers must NOT be pooled with these.
#
# Emits FT* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

RAW <- file.path("external", "reference", "aec")
OUT <- election_data_path()
raw <- readRDS(file.path(RAW, "dop-raw.rds"))

tx_all <- list(); win_all <- list(); tcp_all <- list()
for (E in raw) {
  d <- as.data.table(E$dt); setnames(d, make.names(names(d)))
  el <- sprintf("fed%d", E$year)
  need <- c("DivisionNm", "CountNumber", "PartyNm", "PartyAb", "Elected",
            "CalculationType", "CalculationValue", "Surname")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(el, " lacks column(s): ", paste(miss, collapse = ", "))

  d <- d[CalculationType == "Transfer Count"]
  d[, val := as.numeric(CalculationValue)]
  # Classify OUTSIDE the brackets -- `party` would otherwise be both a new
  # column and a bare symbol inside `[`, the shadowing trap this repo has hit
  # six times. Independents carry no party name and classify to IND correctly.
  cls <- classify_party(d$PartyNm, d$PartyAb)
  d[, party_class := cls]

  # At each count past the first, exactly one candidate is excluded (negative
  # transfer) and the rest receive. Asserted rather than assumed: a count with
  # two negatives would mean the file is not the shape this parser expects.
  ev <- d[CountNumber > 1]
  nneg <- ev[val < 0, .N, by = .(DivisionNm, CountNumber)]
  # A count with NO negative row is as broken as one with two: the recipients
  # would survive the merge with no `from`, and every transfer in that count
  # would silently vanish. Never seen in 2007-2025, but nothing distinguished
  # "no exclusion here" from "the exclusion disappeared".
  counts <- unique(ev[, .(DivisionNm, CountNumber)])
  noneg <- nrow(counts) - nrow(nneg)
  if (noneg > 0L) {
    stop(el, ": ", noneg, " division-counts have NO negative transfer. Their ",
         "recipient rows would be dropped by the merge without a trace.")
  }
  if (nrow(nneg) && max(nneg$N) > 1L) {
    bad <- nneg[N > 1][1]
    stop(el, ": ", bad$DivisionNm, " count ", bad$CountNumber, " has ", bad$N,
         " negative transfers; this parser assumes exactly one exclusion per count.")
  }
  from <- ev[val < 0, .(DivisionNm, CountNumber, from = party_class)]
  to   <- ev[val > 0, .(DivisionNm, CountNumber, to = party_class, votes = val)]
  tx <- merge(to, from, by = c("DivisionNm", "CountNumber"))
  # `el` is a scalar, and data.table requires every `by` element to be as long
  # as the table -- so the election label is added as a column, not folded into
  # the grouping list.
  tx <- tx[, .(votes = sum(votes)),
           by = .(seat = DivisionNm, round = CountNumber, from, to)]
  tx[, election := el]
  setcolorder(tx, c("election", "seat", "round", "from", "to", "votes"))
  tx_all[[length(tx_all) + 1L]] <- tx

  w <- unique(d[Elected == "Y", .(election = el, seat = DivisionNm,
                                  winner = party_class)])
  win_all[[length(win_all) + 1L]] <- w

  # Two-candidate-preferred at the final count, which gives each seat's margin.
  fin <- d[, .(last = max(CountNumber)), by = DivisionNm]
  pc <- as.data.table(E$dt); setnames(pc, make.names(names(pc)))
  pc <- pc[CalculationType == "Preference Count"]
  pc[, val := as.numeric(CalculationValue)]
  pc[, party_class := classify_party(pc$PartyNm, pc$PartyAb)]
  pc <- merge(pc, fin, by = "DivisionNm")[CountNumber == last & val > 0]
  tcp <- pc[, .(election = el, seat = DivisionNm, party = party_class, votes = val)]
  tcp_all[[length(tcp_all) + 1L]] <- tcp

  cat(sprintf("FT1  %s: %d transfer rows, %d divisions, %d winners, %s votes moved\n",
              el, nrow(tx), uniqueN(tx$seat), nrow(w),
              format(sum(tx$votes), big.mark = ",")))
}

tx <- rbindlist(tx_all); win <- rbindlist(win_all); tcp <- rbindlist(tcp_all)

# ---- anchor checks ----------------------------------------------------------
cat("\nFT2  seats won, by election -- these are the commission's own declarations\n")
print(dcast(win[, .N, by = .(election, winner)], winner ~ election,
            value.var = "N", fill = 0))

cat("\nFT3  Greens preference flow to Labor, by election\n")
cat("     (a fixed anchor: this belongs in the 75-90% band in every year)\n")
g <- tx[from == "GRN" & to %in% c("ALP", "LNP"),
        .(v = sum(votes)), by = .(election, to)]
g <- dcast(g, election ~ to, value.var = "v")
g[, pct_alp := round(100 * ALP / (ALP + LNP), 1)]
print(g[, .(election, pct_alp)])
if (any(g$pct_alp < 70 | g$pct_alp > 92)) {
  stop("A Greens-to-Labor flow outside 70-92% means the classifier or the ",
       "transfer parse is wrong, whatever the rest of the file looks like.")
}

cat("\nFT4  One Nation preference flow to Labor, by election\n")
o <- tx[from == "ONP" & to %in% c("ALP", "LNP"), .(v = sum(votes)), by = .(election, to)]
o <- dcast(o, election ~ to, value.var = "v")
o[, pct_alp := round(100 * ALP / (ALP + LNP), 1)]
print(o[, .(election, pct_alp)])

fwrite(tx, file.path(OUT, "aec-fed-transfers.csv"))
fwrite(win, file.path(OUT, "aec-fed-winners.csv"))
fwrite(tcp, file.path(OUT, "aec-fed-tcp.csv"))
cat(sprintf("\nFT5  wrote transfers (%d rows), winners (%d), two-candidate counts (%d)\n",
            nrow(tx), nrow(win), nrow(tcp)))
for (e in unique(tx$election)) {
  fm <- build_flow_matrix(tx[election == e], min_n = 3L)
  cat(sprintf("FT6  %s flow matrix: %d conditional cells, %d pooled rows\n",
              e, length(fm$conditional), length(fm$pooled)))
}

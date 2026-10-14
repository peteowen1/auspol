# build_hare_clark_ballots.R -- ACT ballot files folded to distinct TICKET-SLOT sequences, for the
# candidate-level Hare-Clark simulation.
#
#   Rscript scripts/build_hare_clark_ballots.R          (after scripts/build_hare_clark_data.R)
#
# Every preference becomes "unit#rank": the ticket (canonical unit key from output/hare-clark-candidates.csv)
# and the candidate's rank WITHIN the ticket by first preferences in that electorate (1 = the ticket's
# biggest vote-getter). Identities are dropped on purpose: a later election has different candidates, and
# what carries over is the shape (a vote for a ticket's leader, then its number two, then another ticket).
# Sequences are cut at 20 preferences (a seat is never decided past that depth in 5- and 7-member counts).
#
# Output: output/hare-clark-act-ballots.csv  year, electorate, seq ("ALP#1>ALP#2>GRN#1"), n.
# CHECK: HCT1 ballots per electorate equal the formal totals in hare-clark-units.csv.

suppressPackageStartupMessages(library(data.table))
ref <- file.path("external", "reference")
dirs <- c(`2008` = file.path(ref, "act", "raw", "2008"), `2012` = file.path(ref, "act", "raw", "2012"),
          `2016` = file.path(ref, "act", "raw", "2016"), `2020` = file.path(ref, "elections-act", "raw", "2020"),
          `2024` = file.path(ref, "act", "raw", "2024"))
cands <- fread("output/hare-clark-candidates.csv")[region == "act"]
units <- fread("output/hare-clark-units.csv")[region == "act"]
MAXP <- 20L
out <- list(); fails <- 0L
for (yy in names(dirs)) {
  dir <- dirs[[yy]]; y <- as.integer(yy)
  el <- fread(file.path(dir, "Electorates.txt"))
  cf <- fread(list.files(dir, pattern = "^[Cc]andidates\\.txt$", full.names = TRUE))
  for (i in seq_len(nrow(el))) {
    ec <- el$ecode[i]; en <- el$electorate[i]
    cc <- cf[cf$ecode == ec, ]
    cc[, name := sub("^(.*?), (.*)$", "\\2 \\1", cname, perl = TRUE)]
    ce <- cands[cands$year == y & cands$electorate == en, ]
    cc[, unit := ce$unit[match(name, ce$candidate)]]
    cc[, votes := ce$votes[match(name, ce$candidate)]]
    stopifnot(!anyNA(cc$unit))
    cc[, rank := frank(-votes, ties.method = "first"), by = unit]
    cc[, slot := paste0(unit, "#", rank)]
    cc[, cid := pcode * 1000L + ccode]
    d <- fread(file.path(dir, paste0(en, "Total.txt")), select = c("batch", "pindex", "pref", "pcode", "ccode"))
    d <- d[pref <= MAXP]
    d[, slot := cc$slot[match(pcode * 1000L + ccode, cc$cid)]]
    setorder(d, batch, pindex, pref)
    s <- d[, .(seq = paste(slot, collapse = ">")), by = .(batch, pindex)][, .N, by = seq]
    nb <- sum(s$N); formal <- units[year == y & electorate == en, sum(votes)]
    ok <- nb == formal
    if (!ok) fails <- fails + 1L
    cat(sprintf("HCT1 %s  act%d %-12s %s ballots -> %s sequences (formal %s)\n", if (ok) "PASS" else "FAIL", y, en,
                format(nb, big.mark = ","), format(nrow(s), big.mark = ","), format(formal, big.mark = ",")))
    out[[paste(yy, en)]] <- s[, .(year = y, electorate = en, seq, n = N)]
    rm(d, s); invisible(gc(verbose = FALSE))
  }
}
fwrite(rbindlist(out), "output/hare-clark-act-ballots.csv")
if (fails) quit(status = 1L)

# Which defectors hold their vote? (docs/reviews/defector-overcarry-2026-10-14.md, part 2)
# Reads output/defector-overcarry.csv (scripts/diag_defector_overcarry.R) and adds pre-election facts from
# output/candidacies.csv: times elected before (historic_elected at the previous election), region, level.
# Outcome: retention = actual share / previous share. Also: our over-call (pred - actual), to see which facts
# the model already uses (over-call flat across a fact) and which it misses (over-call moves with it).
#   Rscript scripts/diag_defector_holders.R
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
M <- fread(file.path("output", "defector-overcarry.csv"))
C <- fread(file.path("output", "candidacies.csv"), showProgress = FALSE)
cat(sprintf("DFH0  %d defector cases; candidacies %d rows\n", nrow(M), nrow(C)))
prs <- rbindlist(lapply(all_election_pairs(), function(p) data.table(election = p$election, prev = p$prev)))
M <- merge(M, prs, by = "election", all.x = TRUE)
# times elected before, from the previous election's row for this person (surname match within seat)
C[, .s := normalise_seat(seat)]; C[, sur := toupper(trimws(sub(",.*$", "", sub("^.* ([A-Z'-]+)$", "\\1", name))))]
M[, sur := toupper(trimws(sub(",.*$", "", sub("^.* ([A-Z'-]+)( .*)?$", "\\1", name))))]
M[, sur2 := toupper(trimws(sub("^([A-Z'-]+)[ ,].*$", "\\1", name)))]
pv <- C[party %in% c("ALP", "LNP", "NAT"), list(prev = election, .s, sur, hist = suppressWarnings(as.numeric(historic_elected)))]
M <- merge(M, unique(pv, by = c("prev", ".s", "sur")), by.x = c("prev", ".s", "sur"), by.y = c("prev", ".s", "sur"), all.x = TRUE)
M[is.na(hist), hist := pv[match(paste(M$prev[is.na(M$hist)], M$.s[is.na(M$hist)], M$sur2[is.na(M$hist)]), paste(prev, .s, sur)), hist]]
cat(sprintf("DFH1  times-elected matched for %d of %d (%s)\n", sum(!is.na(M$hist)), nrow(M),
            paste(M[is.na(hist), paste(election, seat)], collapse = ", ")))
M[, `:=`(ret = act / prior, region = sub("[0-9]+$", "", election), level = fifelse(startsWith(election, "fed"), "fed", "state"))]
grp <- function(by) M[, list(n = .N, ret_median = round(median(ret), 2), act_mean = round(mean(act), 1),
                             over_mean = round(mean(over), 1), over_se = round(sd(over) / sqrt(.N), 1)), by = by][order(get(by[1]))]
cat("\nRetention = actual / previous share (higher = held more). Over-call = our final share - actual, points.\n")
cat("\n-- by sitting member or not\n");   print(grp("was_mp"))
cat("\n-- by level\n");                   print(grp("level"))
cat("\n-- by jurisdiction\n");            print(grp("region"))
cat("\n-- by new label\n");               print(grp("new_party"))
# historic_elected is a yes/no flag, not a count: count terms as the earlier elections in the corpus where the
# same surname won the same seat (corpus starts 2001 for most jurisdictions, so long careers are truncated).
C[, yr := as.integer(sub("^[a-z]+", "", election))]; C[, reg := sub("[0-9]+$", "", election)]
won <- C[elected %in% TRUE, list(reg, .s, sur, yr)]
M[, yr := as.integer(sub("^[a-z]+", "", election))]
# Plain vectors with different names: inside won[...] a bare .s / sur / yr binds to won's OWN columns
# (the data.table NSE trap in CLAUDE.md; this script hit it on its first run, 0 of 34 matched).
m_reg <- M$region; m_s <- M$.s; m_sur <- M$sur; m_sur2 <- M$sur2; m_yr <- M$yr
M[, hist := vapply(seq_len(nrow(M)), function(i) {
  keep <- won$reg == m_reg[i] & won$.s == m_s[i] & won$sur %in% c(m_sur[i], m_sur2[i]) & won$yr < m_yr[i]
  as.numeric(sum(keep)) }, numeric(1))]
cat(sprintf("DFH1b terms counted from the corpus: sitting members with 0 found %d of %d (name-key misses)\n",
            M[was_mp == TRUE & hist == 0, .N], M[was_mp == TRUE, .N]))
M[, terms := fcase(hist == 0, "0 found", hist <= 1, "1", hist <= 2, "2", default = "3+")]
cat("\n-- by times elected before (sitting members only)\n"); print(M[was_mp == TRUE, list(n = .N, ret_median = round(median(ret), 2),
  over_mean = round(mean(over), 1)), by = terms][order(terms)])
M[, prior_band := cut(prior, c(0, 30, 45, 55, 100))]
cat("\n-- by previous share\n");          print(grp("prior_band"))
sc <- function(x, y) suppressWarnings(stats::cor(x, y, method = "spearman", use = "complete.obs"))
cat(sprintf("\nDH2  Spearman, retention vs previous share %.2f, vs times elected %.2f; over-call vs previous share %.2f, vs times elected %.2f\n",
            sc(M$ret, M$prior), sc(M$ret, M$hist), sc(M$over, M$prior), sc(M$over, M$hist)))
fwrite(M, file.path("output", "defector-holders.csv"))
cat("DFH3  wrote output/defector-holders.csv\n")
# Electorate size: formal votes in the seat at the PREVIOUS election (knowable before polling day).
sz <- C[, list(formal = sum(as.numeric(votes), na.rm = TRUE)), by = list(prev = election, .s)]
M <- merge(M, sz, by = c("prev", ".s"), all.x = TRUE)
cat(sprintf("\nDH4  electorate size found for %d of %d; Spearman retention vs log formal votes %.2f (sitting members %.2f); over-call vs it %.2f\n",
            sum(M$formal > 0, na.rm = TRUE), nrow(M), sc(M$ret, log(M$formal)), sc(M$ret[M$was_mp], log(M$formal[M$was_mp])),
            sc(M$over, log(M$formal))))
M[, size_band := cut(formal, c(0, 10000, 30000, 60000, Inf), labels = c("<10k", "10-30k", "30-60k", "60k+"))]
cat("-- by electorate size (formal votes, previous election)\n"); print(grp("size_band"))
fwrite(M, file.path("output", "defector-holders.csv"))

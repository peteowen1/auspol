# Measured preference splits between One Nation and the major parties, from real distributions of
# preferences (every external/elections/*-transfers.csv). 2026-11-26, for the One Nation flow calibration.
#
# For each excluded class (from), each election, and each pair of survivors (ONP vs LNP, ONP vs ALP):
#   all      = every exclusion where both of the pair were still alive; share of the votes reaching
#              the pair that went to the first party named (LNP or ALP), i.e. AWAY from One Nation.
#   final    = only exclusions where the pair were the ONLY two left (the split that sets the final count).
# n = exclusions (seat-rounds), seats = distinct seats.
#
# Usage: Rscript scripts/measure_onp_flows.R [elections_dir] [out_csv]
suppressMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
P <- if (length(args) >= 1) args[1] else "external/elections"
out <- if (length(args) >= 2) args[2] else NA_character_
fs <- c("aec-fed-transfers.csv", "ecq-qld-transfers.csv", "ecsa-2026-sa-transfers.csv", "nswec-nsw-transfers.csv",
        "vec-2010-vic-transfers.csv", "vec-2014-vic-transfers.csv", "vec-2018-vic-transfers.csv",
        "vec-2022-vic-transfers.csv", "waec-wa-transfers.csv")
fs <- fs[file.exists(file.path(P, fs))]
tx <- rbindlist(lapply(fs, function(f) fread(file.path(P, f))[, src := f]), fill = TRUE)
cat(sprintf("MOF rows %d | elections %d | files %d | from classes: %s\n", nrow(tx), uniqueN(tx$election),
            length(fs), paste(sort(unique(tx$from)), collapse = " ")))
ex <- tx[, .(surv = paste(sort(unique(to)), collapse = "+"), tot = sum(votes),
             v_alp = sum(votes[to == "ALP"]), v_onp = sum(votes[to == "ONP"]), v_lnp = sum(votes[to == "LNP"])),
         by = .(election, seat, round, frm = from)]
has <- function(s, p) grepl(paste0("(^|[+])", p, "([+]|$)"), s)
res <- list()
for (pr in list(c("LNP", "ONP"), c("ALP", "ONP"))) {
  a <- pr[1]; b <- pr[2]
  va_col <- paste0("v_", tolower(a)); vb_col <- paste0("v_", tolower(b))
  pair <- paste(sort(c(a, b)), collapse = "+")
  sel <- has(ex$surv, a) & has(ex$surv, b) & ex$frm != a & ex$frm != b
  x <- ex[sel]
  x[, `:=`(va = get(va_col), vb = get(vb_col), fin = surv == pair)]
  x <- x[va + vb > 0]
  r <- x[, .(n_all = .N, seats_all = uniqueN(seat), votes_all = sum(va + vb),
             pct_away_all = 100 * sum(va) / sum(va + vb),
             n_final = sum(fin), seats_final = uniqueN(seat[fin]), votes_final = sum((va + vb)[fin]),
             pct_away_final = ifelse(sum(fin) > 0, 100 * sum(va[fin]) / sum((va + vb)[fin]), NA_real_)),
         by = .(election, frm)]
  r[, pair := paste0(a, "_v_ONP")]
  res[[length(res) + 1]] <- r
}
res <- rbindlist(res)
setcolorder(res, c("pair", "frm", "election"))
setorder(res, pair, frm, election)
for (p in unique(res$pair)) for (f in unique(res[pair == p]$frm)) {
  z <- res[pair == p & frm == f]
  if (sum(z$n_all) < 3) next
  cat(sprintf("\n=== %s excluded, %s both alive: %% to %s (away from One Nation) ===\n", f,
              sub("_v_", " and ", p), sub("_v_ONP", "", p)))
  print(z[, .(election, n_all, seats_all, pct_away_all = round(pct_away_all, 1),
              n_final, pct_away_final = round(pct_away_final, 1))], nrows = 200)
  pooled_all <- 100 * sum(z$pct_away_all * z$votes_all / 100) / sum(z$votes_all)
  zf <- z[n_final > 0]
  pooled_fin <- if (nrow(zf)) 100 * sum(zf$pct_away_final * zf$votes_final / 100) / sum(zf$votes_final) else NA
  cat(sprintf("  pooled (vote-weighted): all %.1f (n %d) | final %.1f (n %d)\n", pooled_all, sum(z$n_all),
              pooled_fin, sum(z$n_final)))
}
if (!is.na(out)) { fwrite(res, out); cat("MOF wrote", out, nrow(res), "rows\n") }

# WHOLE-COUNT VIEW: seats whose final two were One Nation and X (the last round's survivors). Share of every
# vote transferred during the count (all rounds, all excluded candidates) that ended with X rather than One Nation:
# the number comparable with "the rest's preferences" backed out of a TCP and two primaries.
last <- ex[, .SD[round == max(round)], by = .(election, seat)]
fin <- last[surv %in% c("LNP+ONP", "ALP+ONP"), .(election, seat, fin2 = surv)]
fin <- unique(fin)
w <- merge(tx, fin, by = c("election", "seat"))
w[, other := sub("[+]?ONP[+]?", "", fin2)]
wc <- w[to %in% c("ONP", other), .(to_other = sum(votes[to == other]), to_onp = sum(votes[to == "ONP"])),
        by = .(election, seat, fin2)]
wc[, pct_rest_to_other := 100 * to_other / (to_other + to_onp)]
cat("\n=== WHOLE COUNT, final two One Nation v X: % of all transferred votes ending with X (not One Nation) ===\n")
print(wc[, .(seats = .N, median = round(median(pct_rest_to_other), 1), min = round(min(pct_rest_to_other), 1),
             max = round(max(pct_rest_to_other), 1),
             pooled = round(100 * sum(to_other) / sum(to_other + to_onp), 1)), by = .(fin2, election)][order(fin2, election)])
if (!is.na(out)) fwrite(wc, sub("[.]csv$", "-wholecount.csv", out))

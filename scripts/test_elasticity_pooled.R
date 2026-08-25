options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
PREF <- election_data_path()
OVER <- 1.5; FALL <- 2

fs <- list.files(PREF, pattern = "firstprefs\\.csv$", full.names = TRUE)
meta <- data.table(f = fs, base = basename(fs))
meta[, region := tstrsplit(base, "-", keep = 3)[[1]]]
meta[, year := as.integer(tstrsplit(base, "-", keep = 2)[[1]])]
meta <- meta[!is.na(year)][order(region, year)]
load1 <- function(f) {
  d <- fread(f, showProgress = FALSE)
  if (!all(c("seat","party","votes") %in% names(d))) return(NULL)
  d[, tot := sum(votes), by = seat]; d[, p := 100*votes/tot]; d[, .(seat, party, p, votes)]
}
rows <- list()
for (rg in unique(meta$region)) {
  yy <- meta[region == rg, year]
  for (i in seq_len(max(0, length(yy)-1L))) {
    a <- load1(meta[region==rg & year==yy[i], f]); b <- load1(meta[region==rg & year==yy[i+1], f])
    if (is.null(a) || is.null(b)) next
    sa <- a[, .(sw_a = 100*sum(votes)/sum(a$votes)), by = party]
    sb <- b[, .(sw_b = 100*sum(votes)/sum(b$votes)), by = party]
    j <- merge(merge(a[, .(seat,party,p_a=p)], b[, .(seat,party,p_b=p)], by=c("seat","party")),
               merge(sa, sb, by="party"), by="party")
    j[, cycle := paste(rg, yy[i], yy[i+1])]
    rows[[length(rows)+1L]] <- j
  }
}
D <- rbindlist(rows, fill = TRUE)
D <- D[p_a >= 3 & sw_a >= 2 & is.finite(p_a) & is.finite(p_b)]
D[, d_state := sw_b - sw_a]
D[, pred_uniform := p_a + d_state]
D[, over := p_a / sw_a]
D[, fires := d_state < -FALL & over > OVER]
D[, pred_rule := fifelse(fires, p_a * sw_b / sw_a, pred_uniform)]

cat(sprintf("observations %d, cycles %d\n", nrow(D), uniqueN(D$cycle)))
cat(sprintf("rule fires on %d (%.1f%%)\n\n", sum(D$fires), 100*mean(D$fires)))
cat("=== CRITERION 2: pooled first-preference MAE across ALL observations ===\n")
mu <- mean(abs(D$p_b - D$pred_uniform)); mr <- mean(abs(D$p_b - D$pred_rule))
cat(sprintf("  uniform everywhere : %.4f\n", mu))
cat(sprintf("  with the rule      : %.4f\n", mr))
cat(sprintf("  change             : %+.4f  -> %s\n", mr - mu,
            if (mr <= mu) "PASS (does not worsen)" else "FAIL"))

cat("\n=== R2: per-cycle, on the cells where it fires ===\n")
f <- D[fires == TRUE]
per <- f[, .(n = .N,
             uniform = round(mean(abs(p_b - pred_uniform)),3),
             rule    = round(mean(abs(p_b - pred_rule)),3),
             better  = round(mean(abs(p_b - pred_uniform)) - mean(abs(p_b - pred_rule)),3)),
         by = cycle][order(-n)]
print(per)
cat(sprintf("R2  rule better in %d of %d cycles where it fires\n",
            sum(per$better > 0), nrow(per)))

cat("\n=== R1: is it a One Nation special? by party ===\n")
print(f[, .(n = .N,
            better = round(mean(abs(p_b - pred_uniform)) - mean(abs(p_b - pred_rule)),3)),
        by = party][order(-n)])

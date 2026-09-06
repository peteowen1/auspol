options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
PREF <- election_data_path()

# Uniform beat proportional pooled (3.724 vs 3.970) and by SWING MAGNITUDE the
# hypothesis was refused. Neither cut was BASE SIZE -- which is what a
# stronghold is, and what AEF's MacKillop number implies.
fs <- list.files(PREF, pattern = "firstprefs\\.csv$", full.names = TRUE)
meta <- data.table(f = fs, base = basename(fs))
meta[, region := tstrsplit(base, "-", keep = 3)[[1]]]
meta[, year := as.integer(tstrsplit(base, "-", keep = 2)[[1]])]
meta <- meta[!is.na(year)][order(region, year)]
load1 <- function(f) {
  d <- fread(f, showProgress = FALSE)
  if (!all(c("seat","party","votes") %in% names(d))) return(NULL)
  d[, tot := sum(votes), by = seat]; d[, p := 100*votes/tot]
  d[, .(seat, party, p, votes)]
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
    j[, `:=`(cycle = paste(rg, yy[i], yy[i+1]))]
    rows[[length(rows)+1L]] <- j
  }
}
D <- rbindlist(rows, fill = TRUE)
D <- D[p_a >= 3 & sw_a >= 2 & is.finite(p_a) & is.finite(p_b)]
D[, d_seat := p_b - p_a]
D[, d_state := sw_b - sw_a]
D[, err_u := abs(d_seat - d_state)]
D[, err_p := abs(d_seat - p_a * d_state / sw_a)]
# how far this seat over-indexes for its party, in RATIO terms
D[, base_ratio := p_a / sw_a]

cat(sprintf("%d observations, %d cycle-pairs\n\n", nrow(D), uniqueN(D$cycle)))
cat("=== uniform vs proportional, BY HOW MUCH THE SEAT OVER-INDEXES ===\n")
D[, band := cut(base_ratio, breaks = c(0, 0.8, 1.0, 1.2, 1.5, 99),
                labels = c("<0.8x","0.8-1.0x","1.0-1.2x","1.2-1.5x",">1.5x"))]
tab <- D[, .(n = .N, mae_uniform = round(mean(err_u),3),
             mae_prop = round(mean(err_p),3),
             prop_better = round(mean(err_u) - mean(err_p),3)), by = band][order(band)]
print(tab)

cat("\n=== and restricted to a party FALLING statewide (the stronghold case) ===\n")
F <- D[d_state < -2]
tf <- F[, .(n = .N, mae_uniform = round(mean(err_u),3),
            mae_prop = round(mean(err_p),3),
            prop_better = round(mean(err_u) - mean(err_p),3)), by = band][order(band)]
print(tf)
cat(sprintf("\n(a falling party, %d observations across %d cycles)\n",
            nrow(F), uniqueN(F$cycle)))

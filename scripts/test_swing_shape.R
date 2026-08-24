options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
PREF <- election_data_path()

# OUR MODEL APPLIES A UNIFORM POINTS SWING:
#   shares[, p] <- mat22[, p] + (statewide_now - statewide_prev)
# So a party on 58.9% and a party on 19.8% both fall by the same NUMBER OF
# POINTS. The alternative is a PROPORTIONAL swing, where a party loses a
# fraction of what it had, so strongholds fall further in points.
#
# Which is right is a classic question and, unlike the sourcing question,
# it has a large corpus: every party, every consecutive district pair.

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
  if (length(yy) < 2) next
  for (i in seq_len(length(yy)-1L)) {
    a <- load1(meta[region==rg & year==yy[i], f]); b <- load1(meta[region==rg & year==yy[i+1], f])
    if (is.null(a) || is.null(b)) next
    sa <- a[, .(sw_a = 100*sum(votes)/sum(a$votes)), by = party]
    sb <- b[, .(sw_b = 100*sum(votes)/sum(b$votes)), by = party]
    st <- merge(sa, sb, by = "party")
    j <- merge(a[, .(seat, party, p_a = p)], b[, .(seat, party, p_b = p)],
               by = c("seat","party"))
    j <- merge(j, st, by = "party")
    j[, `:=`(cycle = paste(rg, yy[i], yy[i+1]), region = rg)]
    rows[[length(rows)+1L]] <- j
  }
}
D <- rbindlist(rows, fill = TRUE)
# Only parties that actually contest both times at a real level -- a party
# going 0 -> 20 is not a "swing", it is an entry, and averaging the two
# together is what would hide the answer.
D <- D[p_a >= 3 & sw_a >= 2 & is.finite(p_a) & is.finite(p_b)]
D[, d_seat := p_b - p_a]
D[, d_state := sw_b - sw_a]

cat(sprintf("=== %d (district, party) observations, %d cycle-pairs, %d regions ===\n",
            nrow(D), uniqueN(D$cycle), uniqueN(D$region)))

# UNIFORM predicts   d_seat = d_state                (intercept 0, slope 0 on p_a)
# PROPORTIONAL predicts d_seat = p_a * d_state/sw_a  (scales with the seat's base)
D[, pred_uniform := d_state]
D[, pred_prop := p_a * d_state / sw_a]
cat("\n=== which prediction is closer? (MAE over all observations) ===\n")
cat(sprintf("uniform points swing : MAE %.3f\n", mean(abs(D$d_seat - D$pred_uniform))))
cat(sprintf("proportional swing   : MAE %.3f\n", mean(abs(D$d_seat - D$pred_prop))))

# The direct test: regress the seat's swing on its own base, given the
# statewide swing. Uniform => coefficient 0. Proportional => coefficient
# equal to d_state/sw_a, i.e. bigger seats swing more when the party falls.
cat("\n=== does a seat's swing depend on its OWN base? (per cycle-pair) ===\n")
per <- D[, {
  if (.N >= 30 && var(p_a) > 0) {
    m <- stats::lm(d_seat ~ p_a)
    .(n = .N, d_state = round(d_state[1],1), slope_on_base = round(coef(m)[["p_a"]],4))
  } else .(n = .N, d_state = NA_real_, slope_on_base = NA_real_)
}, by = .(cycle, party)][!is.na(slope_on_base)]
per[, expected_if_proportional := round(d_state / 100, 4)]
print(head(per[order(-abs(slope_on_base))], 15))

cat("\n=== SUMMARY: sign agreement between slope and statewide swing ===\n")
cat("If a FALLING party falls MORE in its strongholds, slope and d_state\n")
cat("share a sign. Uniform swing predicts slope ~ 0 regardless.\n\n")
per[, agree := sign(slope_on_base) == sign(d_state)]
print(per[, .(n_partycycles = .N, share_agreeing = round(mean(agree),3),
              mean_slope = round(mean(slope_on_base),4))])
print(per[, .(n = .N, share_agreeing = round(mean(agree),3)), by = party][order(-n)])

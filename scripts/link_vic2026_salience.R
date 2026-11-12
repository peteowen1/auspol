# Puts the vic2026 salience snapshot into output/salience-v6.csv, the corpus governed_population(),
# the live xgb features (xgb_primary_predict_live) read (the DS3b blend needs the surge-v2 hazard, off since 31 Oct). Until this existed nothing
# did: every live Victorian run printed "XG5! no salience corpus yet for vic2026" (checked 12 Nov 2026;
# the old connector, build_vic2026_salience_corpus.R, was retired 27 Oct for writing search LEVEL).
#
# RANK-MAPPED, not raw (Pete, 12 Nov 2026). build_vic2026_salience_jump.R divides each candidate's
# rise by the anchor's rise (Ben Carroll, Premier since 28 Jul 2026). Carroll's own rise is small, so
# the 11 Nov snapshot ran ~20x the backtest scale (90th percentile 0.168 against vic2022's 0.0079,
# max 6.52 against 0.24). The anchor's size is a property of who is Premier, not of the candidates, so
# only each candidate's RANK within vic2026 is kept: a positive jump becomes the same quantile of the
# backtest corpus's positive jumps, a negative one the same quantile of its negative jumps, and zero
# stays zero. The share of zero / positive / negative is vic2026's own and is printed (SLK3).
#
# Rows written: every candidate linked to the anchor scale, plus unlinked ones whose raw rise is
# exactly zero (a flat series is zero on any scale). Unlinked candidates with a non-zero raw rise
# have no comparable value and are left out, so they get the model's no-claim defaults; counted (SLK2).
#   AUSPOL_SALIENCE_TO=<date> Rscript scripts/build_vic2026_salience_jump.R   (first, same date)
#   Rscript scripts/link_vic2026_salience.R [--dry-run]                     (codes SLK0-SLK5)
suppressMessages(library(data.table))
dry <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)
sal_f <- file.path("output", "salience-v6.csv")
jump_f <- file.path("output", "vic2026-salience-jump.csv")
cand_f <- file.path("output", "candidacies.csv")
for (f in c(sal_f, jump_f, cand_f)) if (!file.exists(f)) stop("SLK0! missing ", f)

S <- fread(sal_f, showProgress = FALSE)
J <- fread(jump_f, showProgress = FALSE)
cat(sprintf("SLK0  %s: %d candidates in %d seats, snapshot to %s\n", jump_f, nrow(J), uniqueN(J$seat),
            paste(unique(J$snapshot_to), collapse = ",")))
if (uniqueN(J$snapshot_to) != 1L) stop("SLK0! more than one snapshot date in ", jump_f)

REF <- S[S$election != "vic2026" & is.finite(S$jump)]
pos_ref <- sort(REF$jump[REF$jump > 0]); neg_ref <- sort(REF$jump[REF$jump < 0])
cat(sprintf("SLK1  reference corpus: %d rows in %d elections (%d positive, %d zero, %d negative)\n",
            nrow(REF), uniqueN(REF$election), length(pos_ref), sum(REF$jump == 0), length(neg_ref)))
if (length(pos_ref) < 100L || length(neg_ref) < 100L) stop("SLK1! reference corpus too thin to rank-map onto")

keep <- J[(linked %in% TRUE & is.finite(jump)) | (!(linked %in% TRUE) & jump_raw %in% 0)]
keep[!(linked %in% TRUE), jump := 0]
dropped <- fsetdiff(J[, .(seat, keyword)], keep[, .(seat, keyword)])
cat(sprintf("SLK2  %d rows kept (%d linked, %d unlinked with a flat series); %d left out (unlinked, non-zero raw rise or no series)\n",
            nrow(keep), sum(keep$linked %in% TRUE), sum(!(keep$linked %in% TRUE)), nrow(dropped)))

# quantile of x within its own sign group -> same quantile of the reference group. Midpoint plotting
# positions, (rank - 0.5) / n: with (rank - 1) / (n - 1) the loudest vic2026 candidate always took the
# reference's single most extreme value (31.29, first dry run 12 Nov), whatever its own size.
map_q <- function(x, ref) {
  if (!length(x)) return(x)
  p <- (rank(x, ties.method = "average") - 0.5) / length(x)
  as.numeric(quantile(ref, probs = p, names = FALSE, type = 7))
}
keep[, jump_mapped := 0]
ip <- which(keep$jump > 0); ineg <- which(keep$jump < 0)
keep[ip, jump_mapped := map_q(keep$jump[ip], pos_ref)]
keep[ineg, jump_mapped := map_q(keep$jump[ineg], neg_ref)]
q <- function(v) if (length(v)) paste(sprintf("%.4f", quantile(v, c(.5, .9, 1), names = FALSE)), collapse = "/") else "-"
cat(sprintf("SLK3  vic2026 shares: %.0f%% positive, %.0f%% zero, %.0f%% negative (reference %.0f/%.0f/%.0f)\n",
            100 * mean(keep$jump > 0), 100 * mean(keep$jump == 0), 100 * mean(keep$jump < 0),
            100 * length(pos_ref) / nrow(REF), 100 * mean(REF$jump == 0), 100 * length(neg_ref) / nrow(REF)))
cat(sprintf("SLK3  positive jump median/p90/max: raw %s -> mapped %s (reference %s)\n",
            q(keep$jump[ip]), q(keep$jump_mapped[ip]), q(pos_ref)))
# the mapping must keep order within each sign group (the whole point): fail loudly if it does not
if (length(ip) > 1L && any(diff(keep$jump_mapped[ip][order(keep$jump[ip])]) < 0)) stop("SLK3! mapping broke the order of positive jumps")
if (length(ineg) > 1L && any(diff(keep$jump_mapped[ineg][order(keep$jump[ineg])]) < 0)) stop("SLK3! mapping broke the order of negative jumps")

C <- fread(cand_f, showProgress = FALSE)
# Narracan's 2022 contest was a deferred supplementary election (2023) that the corpus does not hold,
# so a seat missing from vic2022 takes its vic2018 figures instead, named in SLK4.
seats22 <- unique(C$seat[C$election == "vic2022"])
no_prev_seat <- setdiff(unique(keep$seat), seats22)
src <- C[(C$election == "vic2022") | (C$election == "vic2018" & C$seat %in% no_prev_seat)]
prev <- src[, .(prev_party = max(pcv, na.rm = TRUE)), by = .(seat, party)]
prev[!is.finite(prev_party), prev_party := 0]
out <- merge(keep[, .(seat, keyword, party, jump = jump_mapped)], prev, by = c("seat", "party"), all.x = TRUE)
out[is.na(prev_party), prev_party := 0]
still <- setdiff(no_prev_seat, unique(C$seat[C$election == "vic2018"]))
cat(sprintf("SLK4  prev_party = the class's best candidate share in vic2022 (as fetch_salience_v6.R:411); from vic2018 for %d seat(s) missing in vic2022%s\n",
            length(no_prev_seat), if (length(no_prev_seat)) paste0(" (", paste(no_prev_seat, collapse = ", "), ")") else ""))
if (length(still)) cat(sprintf("SLK4! %d seat(s) in neither vic2022 nor vic2018, prev_party 0: %s\n", length(still), paste(still, collapse = ", ")))
out <- out[, .(keyword, election = "vic2026", seat, party, pcv = NA_real_, elected = NA, prev_party, jump)]
cat("SLK4  top 10 mapped jumps:\n"); print(out[order(-jump)][1:10, .(seat, keyword, party, jump = round(jump, 4))])

before <- nrow(S); S <- S[S$election != "vic2026"]
comb <- rbindlist(list(S, out), use.names = TRUE)
if (dry) { cat(sprintf("SLK5  DRY RUN: would write %s with %d vic2026 rows (%d total)\n", sal_f, nrow(out), nrow(comb))); quit(save = "no") }
fwrite(comb, sal_f)
cat(sprintf("SLK5  wrote %s: %d vic2026 rows, %d total (was %d)\n", sal_f, nrow(out), nrow(comb), before))

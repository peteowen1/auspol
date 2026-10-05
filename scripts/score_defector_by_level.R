# Score the defector-by-level arm against its baseline, exactly as pre-registered in
# docs/plans/prereg-defector-by-level-2026-10-05.md. Written and committed BEFORE the
# arm ran.
#
# Usage: Rscript scripts/score_defector_by_level.R <baseline_snapshot_dir> <arm_snapshot_dir>
# Each dir must hold forecasts.csv, aef-comparison-full.csv and forecasts-seats.csv.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) != 2L) stop("usage: score_defector_by_level.R <baseline_dir> <arm_dir>")
rd <- function(d, f) { p <- file.path(d, f); if (!file.exists(p)) stop("missing ", p); fread(p, showProgress = FALSE) }
FA <- rd(a[1], "forecasts.csv"); FB <- rd(a[2], "forecasts.csv")
LA <- rd(a[1], "aef-comparison-full.csv"); LB <- rd(a[2], "aef-comparison-full.csv")
SA <- rd(a[1], "forecasts-seats.csv"); SB <- rd(a[2], "forecasts-seats.csv")
cat(sprintf("DL0 baseline %s: forecasts %d rows (built %s), ledger %d seats\n", a[1], nrow(FA), FA$built_at[1], nrow(LA)))
cat(sprintf("DL0 arm      %s: forecasts %d rows (built %s), ledger %d seats\n", a[2], nrow(FB), FB$built_at[1], nrow(LB)))
stopifnot(nrow(FA) > 1000, nrow(FB) > 1000, nrow(LA) > 600, nrow(LB) > 600)

# ---- target cells: sitting major-party members who stood again in the same seat under another class
devtools::load_all("C:/dev/auspol", quiet = TRUE)
C <- fread("C:/dev/auspol/output/candidacies.csv", showProgress = FALSE)
MAJ <- c("ALP", "LNP", "NAT")
kk <- function(d) match_key(surname_of(if ("surname" %in% names(d)) d$surname else NA_character_, d$name),
                            given_of(if ("given" %in% names(d)) d$given else NA_character_, d$name), "initial")
pairs <- all_election_pairs()
tgt_el <- unique(FA$election)
T <- rbindlist(lapply(pairs, function(pr) {
  if (!pr$election %in% tgt_el) return(NULL)
  P <- copy(C[C$election == pr$prev]); N <- copy(C[C$election == pr$election])
  if (!nrow(P) || !nrow(N) || !"elected" %in% names(P)) return(NULL)
  # Sitting = elected at the previous election, CORRECTED for by-elections (Speirs,
  # Black sa2026, was replaced at the 2024 by-election and was not sitting).
  P <- .prev_with_byelection_mp(P, pr$prev, pr$election)
  P[, `:=`(.k = kk(.SD), .s = normalise_seat(seat))]; N[, `:=`(.k = kk(.SD), .s = normalise_seat(seat))]
  gv <- function(d) tolower(gsub("[^A-Za-z]", "", given_of(if ("given" %in% names(d)) d$given else NA_character_, d$name)))
  P[, .g := gv(.SD)]; N[, .g := gv(.SD)]
  m <- merge(P[nzchar(.k) & party %in% MAJ & elected %in% TRUE, .(.s, .k, prior_party = party, prior_pcv = pcv, prior_name = name, .g_p = .g)],
             N[nzchar(.k) & !party %in% MAJ, .(.s, .k, seat, name, party, pcv, .g_n = .g)], by = c(".s", ".k"))
  if (!nrow(m)) return(NULL)
  # A party switch is where a surname+initial collision is costly: it invents a
  # defector (Trevor SMITH matched to the sitting Tony SMITH, Casey fed2022). Drop
  # a match whose first names disagree in their first TWO letters; Mike/Michael and
  # Kate/Katherine still match (R/names.R documents why the initial key is used).
  bad <- nzchar(m$.g_p) & nzchar(m$.g_n) & substr(m$.g_p, 1, 2) != substr(m$.g_n, 1, 2)
  if (any(bad)) cat(sprintf("DL1! %s: dropped %d first-name conflict(s): %s\n", pr$election, sum(bad),
                            paste(sprintf("%s (%s) vs %s", m$prior_name[bad], m$.s[bad], m$name[bad]), collapse = "; ")))
  m <- m[!bad]
  if (!nrow(m)) return(NULL)
  m[, election := pr$election][]
}))
cat(sprintf("DL1 target cells (sitting major member -> other class, same seat, %d forecast elections): %d\n", length(tgt_el), nrow(T)))
print(T[, .(election, seat, name, prior_party, prior_pcv = round(prior_pcv, 1), party, actual = round(pcv, 1))], row.names = FALSE)
stopifnot(nrow(T) >= 5)

# ---- PRIMARY: squared error of xgb_pred on the defector's class row, paired, unit = seat-election
k <- c("election", "seat", "party")
M <- merge(merge(unique(T[, ..k]), FA[, c(k, "xgb_pred", "actual_share"), with = FALSE], by = k),
           FB[, c(k, "xgb_pred"), with = FALSE], by = k, suffixes = c("_a", "_b"))
miss <- fsetdiff(unique(T[, ..k]), M[, ..k])
if (nrow(miss)) stop("DL2! ", nrow(miss), " target cell(s) not found in both forecasts tables (class label mismatch?): ",
                     paste(do.call(paste, miss), collapse = "; "))
M[, d := (actual_share - xgb_pred_b)^2 - (actual_share - xgb_pred_a)^2]
D <- sum(M$d); se <- sd(M$d) * sqrt(nrow(M))
cat(sprintf("\nDL2 PRIMARY: target-cell squared error baseline %.1f -> arm %.1f, change %.1f, SE %.1f (n=%d cells) => %s\n",
            sum((M$actual_share - M$xgb_pred_a)^2), sum((M$actual_share - M$xgb_pred_b)^2), D, se, nrow(M),
            if (D < -se) "PASS (better by more than 1 SE)" else "FAIL"))
print(M[order(d), .(election, seat, party, base = round(xgb_pred_a, 1), arm = round(xgb_pred_b, 1), actual = round(actual_share, 1))], row.names = FALSE)

# ---- GUARD 1: ledger seat log loss, paired per seat, SE clustered on election (pair)
eps <- 1e-6
ll <- function(L) L[, .(pair, seat, ll = -log(pmax(eps, ifelse(is.na(our_p), eps, our_p))))]
G <- merge(ll(LA), ll(LB), by = c("pair", "seat"), suffixes = c("_a", "_b"))
G[, d := ll_b - ll_a]
cl <- G[, .(s = sum(d), n = .N), by = pair]
g_mean <- sum(cl$s) / sum(cl$n); g_se <- sqrt(nrow(cl) / (nrow(cl) - 1) * sum((cl$s - cl$n * g_mean)^2)) / sum(cl$n)
cat(sprintf("\nDL3 GUARD ledger log loss: %.4f -> %.4f (mean change %+.4f, clustered SE %.4f, %d seats, %d pairs) => %s\n",
            mean(G$ll_a), mean(G$ll_b), g_mean, g_se, nrow(G), nrow(cl), if (g_mean <= g_se) "HOLDS" else "BREACHED"))
print(cl[, .(pair, n, change = round(s / n, 4))][order(-change)], row.names = FALSE)

# ---- GUARD 2: whole-table primary squared error, SE clustered on election
W <- merge(FA[, c(k, "xgb_pred", "actual_share"), with = FALSE], FB[, c(k, "xgb_pred"), with = FALSE], by = k, suffixes = c("_a", "_b"))
W[, d := (actual_share - xgb_pred_b)^2 - (actual_share - xgb_pred_a)^2]
wc <- W[, .(s = sum(d), n = .N), by = election]
w_mean <- sum(wc$s) / sum(wc$n); w_se <- sqrt(nrow(wc) / (nrow(wc) - 1) * sum((wc$s - wc$n * w_mean)^2)) / sum(wc$n)
cat(sprintf("DL4 GUARD whole-table RMSE %.3f -> %.3f (mean sq change %+.3f, clustered SE %.3f, %d rows) => %s\n",
            sqrt(mean((W$actual_share - W$xgb_pred_a)^2)), sqrt(mean((W$actual_share - W$xgb_pred_b)^2)),
            w_mean, w_se, nrow(W), if (w_mean <= w_se) "HOLDS" else "BREACHED"))

# ---- DISQUALIFIER: a defector who actually won must not lose more than 0.05 win probability
win <- T[, .(election, seat, party)]
Q <- merge(merge(win, SA[, .(election, seat, party, p_a = win_prob, is_winner)], by = c("election", "seat", "party")),
           SB[, .(election, seat, party, p_b = win_prob)], by = c("election", "seat", "party"))
Q <- Q[is_winner %in% c(TRUE, 1, "TRUE")]
cat(sprintf("\nDL5 DISQUALIFIER defectors who won (n=%d): ", nrow(Q)))
if (!nrow(Q)) cat("none found in the forecast seats file\nDL5 => UNVERIFIABLE (counts as FIRES: an absent check is not a pass)\n") else {
  print(Q[, .(election, seat, party, p_a = round(p_a, 3), p_b = round(p_b, 3))], row.names = FALSE)
  cat(sprintf("DL5 => %s\n", if (any(Q$p_b < Q$p_a - 0.05)) "FIRES" else "does not fire"))
}

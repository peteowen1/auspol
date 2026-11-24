# Scores the early-share screen against its prereg (docs/plans/prereg-early-share-labor-2026-11-24.md):
# shipped baseline, real arm (AUSPOL_DEMO_RESID_EARLY=1) and placebo (=shuffle), read from quick_arm's cache.
suppressPackageStartupMessages(library(data.table))
root <- file.path(Sys.getenv("TEMP"), "auspol-quickarm", "cache")
ks <- list.dirs(root, recursive = FALSE)
meta <- rbindlist(lapply(ks, function(k) { f <- file.path(k, "_key.rds"); if (!file.exists(f)) return(NULL); x <- readRDS(f)
  data.table(ck = basename(k), code = x$code, input = x$input, sims = x$sims, env = paste(x$env, collapse = " "), at = file.mtime(f)) }))
arm <- meta[env == "AUSPOL_DEMO_RESID_EARLY=1"][order(-at)][1]
stopifnot(nrow(arm) == 1, !is.na(arm$ck))
same <- meta[code == arm$code & input == arm$input & sims == arm$sims]
base <- same[env == ""][1]; plc <- same[env == "AUSPOL_DEMO_RESID_EARLY=shuffle"][1]
stopifnot(!is.na(base$ck))
cat(sprintf("code %s, input %s, %d sims. baseline %s, arm %s, placebo %s\n", arm$code, arm$input, arm$sims, base$ck, arm$ck, if (is.na(plc$ck)) "NOT RUN YET" else plc$ck))
units <- function(k) setdiff(list.dirs(file.path(root, k), recursive = FALSE, full.names = FALSE), "")
have <- function(k, u) file.exists(file.path(root, k, u, "meta.rds"))
U <- intersect(units(base$ck), units(arm$ck)); U <- U[have(base$ck, U) & have(arm$ck, U)]
if (!is.na(plc$ck)) U <- U[have(plc$ck, U)]
cat("elections scored:", length(U), ":", paste(sort(U), collapse = " "), "\n")
rd <- function(k, f) rbindlist(lapply(U, function(u) { d <- fread(file.path(root, k, u, f), showProgress = FALSE); d[, pair := u]; d }), fill = TRUE)
sdt <- function(k, nm) { d <- rd(k, "sharedetail.csv")[, .(pair, seat, party, actual_share, p = pred_share)]; setnames(d, "p", nm); d }
S <- merge(sdt(base$ck, "b"), sdt(arm$ck, "a")[, .(pair, seat, party, a)], by = c("pair", "seat", "party"))
S <- if (is.na(plc$ck)) S[, s := NA_real_] else merge(S, sdt(plc$ck, "s")[, .(pair, seat, party, s)], by = c("pair", "seat", "party"))
tab <- fread("output/prev-early-share.csv")[, .(pair, seat, has = TRUE)]
S <- merge(S, tab, by = c("pair", "seat"), all.x = TRUE); S[is.na(has), has := FALSE]
eps <- 0.5 / arm$sims
ll <- function(k, nm) { d <- rd(k, "allprobs.csv"); d <- d[as.logical(is_actual) == TRUE, .(pair, seat, l = -log(pmax(prob, eps)))]; setnames(d, "l", nm); d }
L <- merge(ll(base$ck, "b"), ll(arm$ck, "a"), by = c("pair", "seat"))
L <- if (is.na(plc$ck)) L[, s := NA_real_] else merge(L, ll(plc$ck, "s"), by = c("pair", "seat"))

# 1. identity
idn <- S[, .(cells = .N, moved_arm = sum(abs(a - b) > 1e-9), moved_plc = sum(abs(s - b) > 1e-9, na.rm = TRUE), max_move = max(abs(a - b))), by = pair][order(pair)]
cat("\n1. IDENTITY. Cells whose predicted share moved at all, per election (an election the correction does not act on must show 0):\n"); print(idn)

# 2. primary: Labor squared error on covered seats, arm vs placebo, paired by election
A <- S[party == "ALP" & has == TRUE]
per <- A[, .(seats = .N, base = sqrt(mean((b - actual_share)^2)), arm = sqrt(mean((a - actual_share)^2)), plc = sqrt(mean((s - actual_share)^2)),
             d_arm = mean((a - actual_share)^2) - mean((b - actual_share)^2), d_plc = mean((s - actual_share)^2) - mean((b - actual_share)^2),
             mean_move = mean(abs(a - b))), by = pair][order(pair)]
act <- per[mean_move > 1e-9]
cat("\n2. PRIMARY. Labor primary RMSE in points on seats that have a previous early share, LOWER IS BETTER. base = shipped, arm = correction on, plc = shuffled placebo.\n")
print(act[, .(pair, seats, base = round(base, 3), arm = round(arm, 3), plc = round(plc, 3), arm_minus_base = round(arm - base, 3), plc_minus_base = round(plc - base, 3), mean_shift = round(mean_move, 2))])
s3 <- function(v) sprintf("%+.4f (SE across elections %.4f, %d of %d elections better)", mean(v), sd(v) / sqrt(length(v)), sum(v < 0), length(v))
cat("   squared error, arm vs baseline:  ", s3(act$d_arm), "\n")
if (!is.na(plc$ck)) { cat("   squared error, placebo vs baseline:", s3(act$d_plc), "\n"); cat("   squared error, ARM vs PLACEBO:    ", s3(act$d_arm - act$d_plc), "  <- the prereg's primary\n") }
AA <- A[pair %in% act$pair]
cat(sprintf("   pooled Labor RMSE over %d seats: base %.3f, arm %.3f, placebo %.3f\n", nrow(AA), sqrt(mean((AA$b - AA$actual_share)^2)), sqrt(mean((AA$a - AA$actual_share)^2)), sqrt(mean((AA$s - AA$actual_share)^2))))
al <- S[pair %in% act$pair]
cat(sprintf("   all parties, same elections (%d cells): base %.3f, arm %.3f, placebo %.3f\n", nrow(al), sqrt(mean((al$b - al$actual_share)^2)), sqrt(mean((al$a - al$actual_share)^2)), sqrt(mean((al$s - al$actual_share)^2))))

# 3. guards: seat-winner log loss
pl <- L[pair %in% act$pair, .(seats = .N, base = mean(b), arm = mean(a), plc = mean(s)), by = pair][order(pair)]
cat("\n3. GUARD. Seat-winner log loss (how surprised the win probabilities were by the actual winner), LOWER IS BETTER.\n")
print(pl[, .(pair, seats, base = round(base, 4), arm = round(arm, 4), plc = round(plc, 4), arm_minus_base = round(arm - base, 4), plc_minus_base = round(plc - base, 4))])
cat("   arm vs baseline, mean of elections:  ", s3(pl$arm - pl$base), "\n")
if (!is.na(plc$ck)) cat("   placebo vs baseline:                 ", s3(pl$plc - pl$base), "\n")
LL <- L[pair %in% act$pair]
cat(sprintf("   pooled over %d seats: base %.4f, arm %.4f, placebo %.4f\n", nrow(LL), mean(LL$b), mean(LL$a), mean(LL$s)))
cat("   Victorian elections:", paste(sprintf("%s %+.4f (placebo %+.4f)", pl[grepl("^vic", pair)]$pair, pl[grepl("^vic", pair), arm - base], pl[grepl("^vic", pair), plc - base]), collapse = "; "), "\n")

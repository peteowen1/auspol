# Score the seat-poll Bayesian blend arms on docs/plans/prereg-seat-poll-method-weights-2026-10-18.md's terms:
# PRIMARY seat log loss on seats with at least one seat poll in that election, GUARD every seat of those elections,
# SE clustered on election; the one-election and one-seat (McMahon) clauses; McMahon reported. Lower is better.
#   Rscript scripts/score_seatpoll_arms.R <base_dir> <arm_dir> <n_sims> [label]
# Folders hold one subfolder per election with allprobs.csv and sharedetail.csv (quick_arm cache). Codes SPA0-SPA6.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 3) stop("usage: score_seatpoll_arms.R <base_dir> <arm_dir> <n_sims> [label]")
base_dir <- a[1]; arm_dir <- a[2]; n_sims <- as.numeric(a[3]); lab <- if (length(a) >= 4) a[4] else "arm"
eps <- if (n_sims >= 20000) 1e-6 else 0.5 / n_sims
els <- intersect(list.dirs(base_dir, full.names = FALSE, recursive = FALSE), list.dirs(arm_dir, full.names = FALSE, recursive = FALSE))
els <- els[file.exists(file.path(base_dir, els, "allprobs.csv")) & file.exists(file.path(arm_dir, els, "allprobs.csv"))]
sp <- fread("external/reference/polls/seat-polls/seat_polls.csv")[row_type == "poll"]
polled <- unique(sp[, .(election, seat)])[, polled := TRUE]
norm <- function(x) tolower(gsub("[^a-z]", "", tolower(x)))
polled[, sk := norm(seat)]
cat(sprintf("SPA0 %s: %d elections; floor eps %.1e; %d polled seat-elections on file\n", lab, length(els), eps, nrow(polled)))
pw <- function(f) { x <- fread(f); w <- x[x$is_actual == TRUE, .(p = sum(prob)), by = seat]
  merge(data.table(seat = unique(x$seat)), w, by = "seat", all.x = TRUE)[is.na(p), p := 0] }
rows <- rbindlist(lapply(els, function(e) {
  m <- merge(pw(file.path(base_dir, e, "allprobs.csv")), pw(file.path(arm_dir, e, "allprobs.csv")), by = "seat", suffixes = c("_a", "_b"))
  m[, election := e][, sk := norm(seat)]
  m <- merge(m, polled[election == e, .(sk, polled)], by = "sk", all.x = TRUE)[is.na(polled), polled := FALSE]
  m
}))
rows[, d := -log(pmax(p_b, eps)) + log(pmax(p_a, eps))]
cl <- function(x) { G <- uniqueN(x$election); dbar <- mean(x$d); s <- x[, .(r = sum(d - dbar)), by = election]$r
  c(n = nrow(x), d = dbar, se = if (G > 1) sqrt(G / (G - 1) * sum(s^2)) / nrow(x) else NA_real_) }
pr <- function(t, x) { r <- cl(x)
  cat(sprintf("  %-38s seats %4d | change %+.4f (SE %.4f)%s\n", t, r["n"], r["d"], r["se"],
              if (is.finite(r["se"]) && r["d"] < -r["se"]) "  better by >1 SE" else if (is.finite(r["se"]) && r["d"] > r["se"]) "  WORSE by >1 SE" else "  within 1 SE"))
  invisible(r) }
cat(sprintf("SPA1 %s minus baseline, seat-winner log loss (lower is better), SE clustered on election:\n", lab))
r1 <- pr("PRIMARY: seats with a seat poll", rows[polled == TRUE])
rg <- pr("GUARD: every seat", rows)
for (e in els) pr(paste0("  ", e, " (polled seats)"), rows[polled == TRUE & election == e])
pe <- rows[polled == TRUE, .(s = sum(d)), by = election]; net <- sum(pe$s)
top <- if (net < 0) max(pe$s / net) else NA
cat(sprintf("SPA2 REFUSAL one election > half the gain: largest share %s -> %s\n", format(round(top, 2)),
            if (is.na(top)) "no net gain" else if (top > 0.5) "REFUSED" else "passes"))
nm <- rows[polled == TRUE & !(election == "fed2025" & sk == "mcmahon")]
r3 <- cl(nm)
cat(sprintf("SPA3 primary WITHOUT McMahon: %+.4f (SE %.4f) -> %s\n", r3["d"], r3["se"],
            if (is.finite(r3["se"]) && r3["d"] < -r3["se"]) "still better by >1 SE" else "within 1 SE: a one-seat result, to Pete"))
mc <- rows[election == "fed2025" & sk == "mcmahon"]
if (nrow(mc)) cat(sprintf("SPA4 McMahon fed2025: P(actual winner) baseline %.3f -> arm %.3f\n", mc$p_a, mc$p_b))
sd_ <- function(d) { f <- file.path(d, "fed2025", "sharedetail.csv"); if (!file.exists(f)) return(NULL)
  x <- fread(f); x[tolower(seat) == "mcmahon", .(party, pred = round(pred_share, 1), actual = round(actual_share, 1))] }
b <- sd_(base_dir); r <- sd_(arm_dir)
if (!is.null(b) && !is.null(r)) { cat("SPA5 McMahon fed2025 shares:\n"); print(merge(b, r[, .(party, arm = pred)], by = "party")) }
cat(sprintf("SPA6 VERDICT %s: primary %s; guard %s\n", lab,
            if (is.finite(r1["se"]) && r1["d"] < -r1["se"]) "better by more than 1 SE" else "NOT better by more than 1 SE",
            if (is.finite(rg["se"]) && rg["d"] > rg["se"]) "FAILS" else "passes"))

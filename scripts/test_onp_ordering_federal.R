# Does the federal One Nation vote order districts better than the Greens share?
#
# Against docs/plans/prereg-onp-allocation-federal.md, committed before this
# ran. The decision rule and refusals N1-N5 are there and are NOT restated.
#
# Three arms, ORDERING only -- no level is fitted, no spread is fitted, on 33
# observations that are all conditioned on One Nation choosing to stand:
#   A  current: by Greens share, coefficient as shipped
#   B  proposed: by transposed federal ONP from the PRECEDING federal election
#   C  floor: uniform, no ordering
#
# Emits OF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
ONP_B1 <- -0.0968          # the shipped Greens-share coefficient, unchanged
tr <- fread(file.path(P, "federal-transposed-to-state.csv"))

CASES <- list(
  list(file = "nswec-2019-nsw-firstprefs.csv", region = "nsw", cycle = 2019),
  list(file = "nswec-2023-nsw-firstprefs.csv", region = "nsw", cycle = 2023))

results <- list()
for (K in CASES) {
  d <- fread(file.path(P, K$file))
  d[, pct := 100 * votes / sum(votes), by = seat]
  w <- dcast(d, seat ~ party, value.var = "pct", fill = 0)
  actual <- w[, .(seat, onp = if ("ONP" %in% names(w)) ONP else 0,
                  grn = if ("GRN" %in% names(w)) GRN else 0)]
  # Only districts One Nation actually contested can score an ordering: a zero
  # from a seat they did not stand in says nothing about where they are strong.
  act <- actual[onp > 0]
  fed <- tr[region == K$region & cycle == K$cycle & party == "ONP",
            .(seat, fed_onp = pct)]
  m <- merge(act, fed, by = "seat")
  cat(sprintf("\nOF1  %s %d: ONP contested %d districts; %d also have a transposed federal ONP vote\n",
              toupper(K$region), K$cycle, nrow(act), nrow(m)))
  if (nrow(m) < 5L) {
    cat("OF1  fewer than 5 comparable districts -- reported, not scored\n")
    next
  }

  # Arm A reproduces the shipped rule exactly: rank by the Greens-share index.
  m[, idx_A := ONP_B1 * grn]
  m[, `:=`(rank_A = frank(-idx_A), rank_B = frank(-fed_onp),
           rank_actual = frank(-onp))]
  sA <- stats::cor(m$rank_A, m$rank_actual, method = "spearman")
  sB <- stats::cor(m$rank_B, m$rank_actual, method = "spearman")

  # MAE after scaling each ordering to the ACTUAL statewide total, so the
  # comparison is of shape alone and no arm gets credit for the level.
  tot <- sum(m$onp)
  alloc <- function(x) tot * x / sum(x)
  # A's magnitudes come from its rank, mapped onto the observed spread -- the
  # shipped mechanism, reproduced rather than approximated.
  ratio <- sort(m$onp / mean(m$onp))
  a_alloc <- numeric(nrow(m))
  ord <- order(m$idx_A)
  for (r in seq_len(nrow(m))) {
    q <- (r - 1) / max(1, nrow(m) - 1)
    pos <- q * (length(ratio) - 1)
    lo <- floor(pos) + 1; hi <- min(lo + 1, length(ratio))
    a_alloc[ord[r]] <- ratio[lo] + (pos - (lo - 1)) * (ratio[hi] - ratio[lo])
  }
  mae_A <- mean(abs(alloc(a_alloc) - m$onp))
  mae_B <- mean(abs(alloc(m$fed_onp) - m$onp))
  mae_C <- mean(abs(rep(tot / nrow(m), nrow(m)) - m$onp))

  cat(sprintf("OF2  Spearman rank correlation with the actual ONP ordering\n"))
  cat(sprintf("     A Greens-share %+.3f | B federal ONP %+.3f\n", sA, sB))
  cat(sprintf("OF3  MAE after scaling to the actual statewide total\n"))
  cat(sprintf("     A %.3f | B %.3f | C uniform %.3f\n", mae_A, mae_B, mae_C))
  results[[length(results) + 1L]] <- data.table(
    election = sprintf("%s%d", K$region, K$cycle), n = nrow(m),
    rho_A = sA, rho_B = sB, mae_A = mae_A, mae_B = mae_B, mae_C = mae_C)
}

R <- rbindlist(results)
if (!nrow(R)) stop("No election had enough comparable districts to score.")
cat("\nOF4  summary\n"); print(R)

b_wins_rho <- all(R$rho_B > R$rho_A)
b_no_worse_mae <- all(R$mae_B <= R$mae_A)
both_beat_uniform <- all(pmin(R$mae_A, R$mae_B) < R$mae_C)
# The pre-registration required BOTH NSW elections. Only one is ever scorable
# (NSW 2019 has a single district where One Nation contested the state election
# and had a matched federal vote), so `all()` over one row must not be reported
# as "every election" -- that is a claim about a test half of which was dropped.
if (nrow(R) < 2L) {
  cat(sprintf("
OF4b WARNING: the plan required 2 elections; %d was scorable.
", nrow(R)))
  cat("OF4b Any verdict below rests on that one, and the deviation is recorded in
")
  cat("OF4b docs/plans/prereg-onp-allocation-federal.md rather than only here.
")
}
verdict <- if (!both_beat_uniform) {
  "ADOPT C -- neither ordering beats a uniform allocation"
} else if (b_wins_rho && b_no_worse_mae) {
  sprintf("ADOPT B -- wins on rank in %d of %d scorable election(s), no worse on MAE", nrow(R), nrow(R))
} else "KEEP A"
cat(sprintf("\nOF5  verdict: %s\n", verdict))
cat(sprintf("OF5  B beats A on rank in %d of %d; B no worse on MAE in %d of %d\n",
            sum(R$rho_B > R$rho_A), nrow(R), sum(R$mae_B <= R$mae_A), nrow(R)))
fwrite(R, file.path("output", "onp-ordering-federal.csv"))

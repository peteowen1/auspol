# score_ind_split_gated.R -- Amendment 2 of docs/plans/prereg-ind-split-points-2026-11-18.md, scored offline.
#
#   Rscript scripts/score_ind_split_gated.R deciding-runs/20261118-1404-indsplit-carry
#
# Composite: the arm's seat probabilities in GATED seat-elections (two or more independents whose `cred` in
# output/ind-split-candidates.csv is not "none"), the baseline's everywhere else. Valid only because the split acts
# per seat: GSS1 checks that seats with fewer than two independents are byte-identical between the two cache keys.
# Seat-winner log loss, floored at 0.5 / sims as quick_arm does; lower is better. SE clustered on election.
# Check codes GSS1-GSS3.
suppressMessages(library(data.table))
run <- commandArgs(TRUE)[1]
pj <- jsonlite::fromJSON(file.path(run, "params.json"))
cdir <- if (dir.exists(file.path(run, "cache"))) file.path(run, "cache") else file.path(pj$QuickDir, "cache")
keys <- list.dirs(cdir, recursive = FALSE, full.names = FALSE)
if (length(keys) != 2) stop(sprintf("GSS1! expected 2 cache keys in %s, found %d", cdir, length(keys)))
rd <- function(k) rbindlist(lapply(list.files(file.path(cdir, k), "allprobs.csv", recursive = TRUE, full.names = TRUE),
                                   function(f) { x <- fread(f); x[, pair := basename(dirname(f))]; x }), fill = TRUE)
K1 <- rd(keys[1]); K2 <- rd(keys[2])
sims <- if (!is.null(pj$Sims)) as.numeric(pj$Sims) else 1000
fl <- 0.5 / sims

cand <- fread("output/ind-split-candidates.csv", encoding = "UTF-8")
multi <- unique(cand[, .(pair = election, seat)])
gate <- cand[cred != "none", .N, by = .(pair = election, seat)][N >= 2, .(pair, seat)]

# The arm is the key that lowered the independents in Kooyong 2022 (a 2-independent seat, the split's known loss).
pk <- function(x) x[pair == "fed2022" & seat == "Kooyong" & party == "IND", sum(prob)]
arm_is_2 <- pk(K2) < pk(K1)
BASE <- if (arm_is_2) K1 else K2; ARM <- if (arm_is_2) K2 else K1
cat(sprintf("GSS1 %s: base key %s, arm key %s; %d elections; floor %.5f; Kooyong 2022 IND base %.3f arm %.3f\n",
            basename(run), if (arm_is_2) keys[1] else keys[2], if (arm_is_2) keys[2] else keys[1],
            uniqueN(BASE$pair), fl, pk(BASE), pk(ARM)))

# Validity: outside the 2+ independent seats the two runs must agree exactly.
cols <- c("pair", "seat", "party", "prob")
X <- merge(BASE[, ..cols], ARM[, ..cols], by = c("pair", "seat", "party"), suffixes = c("_b", "_a"))
X <- X[!multi, on = c("pair", "seat")]
nd <- X[prob_b != prob_a, uniqueN(paste(pair, seat))]
cat(sprintf("GSS1 seats with <2 independents: %d seat-elections compared, %d differ\n",
            X[, uniqueN(paste(pair, seat))], nd))
if (nd > 0) stop("GSS1! the arm moved seats it should not touch: the composite is not valid")

ll <- function(x) x[is_actual == TRUE, .(ll = -log(pmax(sum(prob), fl))), by = .(pair, seat)]
LB <- ll(BASE); LA <- ll(ARM)
M <- merge(LB, LA, by = c("pair", "seat"), suffixes = c("_b", "_a"))
M[, g := FALSE][gate, g := TRUE, on = c("pair", "seat")]
M[, ll_c := ifelse(g, ll_a, ll_b)]
won <- unique(BASE[is_actual == TRUE & party == "IND", .(pair, seat)])
cat(sprintf("GSS2 gated seat-elections in the scored set: %d in %d elections (of %d with 2+ independents); of them won by an independent: %d\n",
            M[g == TRUE, .N], M[g == TRUE, uniqueN(pair)], nrow(merge(M, multi, by = c("pair", "seat"))),
            nrow(merge(M[g == TRUE], won, by = c("pair", "seat")))))

one <- function(x, nm, col) {
  x <- copy(x); x[, d := get(col) - ll_b]
  by_e <- x[, .(s = sum(d), n = .N), by = pair]
  n <- sum(by_e$n); m <- sum(by_e$s) / n
  se <- sqrt(sum((by_e$s - by_e$n * m)^2)) / n * sqrt(nrow(by_e) / max(1, nrow(by_e) - 1))
  cat(sprintf("GSS3 %-12s %-30s seats %4d elections %2d  base %.4f  arm-base %+.4f (SE %.4f)  %s\n",
              col, nm, n, nrow(by_e), mean(x$ll_b), m, se,
              if (m < -se) "BETTER" else if (m > se) "WORSE" else "within 1 SE"))
  invisible(x)
}
for (col in c("ll_c", "ll_a")) {
  cat(sprintf("--- %s ---\n", if (col == "ll_c") "GATED composite (Amendment 2)" else "ungated arm K (as refused, for reference)"))
  one(merge(M, multi, by = c("pair", "seat")), "primary: 2+ independents", col)
  one(merge(M, won, by = c("pair", "seat")), "guard 1: independents won", col)
  one(M, "guard 2: all seats", col)
  if (col == "ll_c") {
    one(M[g == TRUE], "gated seats only", col)
    one(merge(M[g == TRUE], won, by = c("pair", "seat")), "gated seats, independent won", col)
    e2 <- copy(M)[, d := ll_c - ll_b][, .(m = mean(d), se = sd(d) / sqrt(.N)), by = pair][m > 2 * se & m > 0]
    cat(sprintf("GSS3 guard 2 elections worse by > 2 SE: %s\n", if (nrow(e2)) paste(e2$pair, collapse = ", ") else "none"))
  }
}
# The gated seats themselves, worst first: who they are and what moved.
pw <- function(x) x[party == "IND", .(p = sum(prob)), by = .(pair, seat)]
G <- merge(merge(M[g == TRUE, .(pair, seat, d = ll_a - ll_b)], pw(BASE), by = c("pair", "seat")),
           pw(ARM), by = c("pair", "seat"), suffixes = c("_base", "_arm"))
G[, ind_won := FALSE][won, ind_won := TRUE, on = c("pair", "seat")]
print(G[order(-abs(d))][, .(pair, seat, ind_won, p_base = round(p_base, 3), p_arm = round(p_arm, 3), d_ll = round(d, 3))], nrows = 80)

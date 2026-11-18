# score_ind_split_screen.R -- the pre-registered measures for the points-based independent split
# (docs/plans/prereg-ind-split-points-2026-11-18.md), from a deciding run's per-seat cache.
#
#   Rscript scripts/score_ind_split_screen.R <deciding-runs/<stamp>-<label>> [<scratch cache dir>]
#
# Reads cache/<key>/<election>/allprobs.csv for the run's two keys (baseline and arm: the arm key is the one whose
# probabilities differ). Seat-winner log loss per seat-election, probabilities floored at 0.5 / sims as quick_arm
# does; lower is better. Sets: seats with 2+ independents on the ballot (output/ind-split-candidates.csv, defined
# from nominations), the subset the independents WON, and all seats. SE clustered on election. Check codes ISS1-ISS3.
suppressMessages(library(data.table))
a <- commandArgs(TRUE)
run <- a[1]
pj <- jsonlite::fromJSON(file.path(run, "params.json"))
cdir <- if (length(a) >= 2) a[2] else if (dir.exists(file.path(run, "cache"))) file.path(run, "cache") else file.path(pj$QuickDir, "cache")
keys <- list.dirs(cdir, recursive = FALSE, full.names = FALSE)
if (length(keys) != 2) stop(sprintf("ISS1! expected 2 cache keys in %s, found %d", cdir, length(keys)))
# some harnesses write no `pair` column: take the election from the cache folder name, always
rd <- function(k) rbindlist(lapply(list.files(file.path(cdir, k), "allprobs.csv", recursive = TRUE, full.names = TRUE),
                                   function(f) { x <- fread(f); x[, pair := basename(dirname(f))]; x }), fill = TRUE)
A <- rd(keys[1]); B <- rd(keys[2])
sims <- if (!is.null(pj$Sims)) as.numeric(pj$Sims) else 1000
cat(sprintf("ISS1 %s: keys %s (%d rows, %d elections) and %s (%d rows, %d elections); floor %.5f\n", basename(run),
            keys[1], nrow(A), uniqueN(A$pair), keys[2], nrow(B), uniqueN(B$pair), 0.5 / sims))
ll <- function(x) x[is_actual == TRUE, .(ll = -log(pmax(sum(prob), 0.5 / sims))), by = .(pair, seat)]
LA <- ll(A); LB <- ll(B)
M <- merge(LA, LB, by = c("pair", "seat"), suffixes = c("_1", "_2"))
d <- fread("output/ind-split-candidates.csv", encoding = "UTF-8")
multi <- unique(d[, .(pair = election, seat)])
won <- unique(A[is_actual == TRUE & party == "IND", .(pair, seat)])
# which key is the arm: the one that moved seats with 2+ independents
mv <- merge(M, multi, by = c("pair", "seat"))
if (!nrow(mv) || all(mv$ll_1 == mv$ll_2)) stop("ISS2! no seat with 2+ independents moved: the split did not apply")
# Which key is the arm is read from the run's results.txt / log (quick_arm names the keys); both directions print.
score <- function(base, arm, lab) {
  M[, d := get(arm) - get(base)]
  one <- function(x, nm) {
    by_e <- x[, .(s = sum(d), n = .N), by = pair]
    n <- sum(by_e$n); m <- sum(by_e$s) / n
    se <- sqrt(sum((by_e$s - by_e$n * m)^2)) / n * sqrt(nrow(by_e) / max(1, nrow(by_e) - 1))
    worst <- x[, .(m = mean(d), se = stats::sd(d) / sqrt(.N), n = .N), by = pair][order(-m)][1]
    cat(sprintf("ISS3 %-28s seats %4d elections %2d  base %.4f  arm-base %+.4f (SE %.4f)  %s  | worst election %s %+.4f (%d seats)\n",
                nm, n, nrow(by_e), x[, mean(get(base))], m, se,
                if (m < -se) "BETTER" else if (m > se) "WORSE" else "within 1 SE", worst$pair, worst$m, worst$n))
  }
  cat(sprintf("--- arm = %s ---\n", lab))
  one(merge(M, multi, by = c("pair", "seat")), "primary: 2+ independents")
  one(merge(M, won, by = c("pair", "seat")), "guard 1: independents won")
  one(M, "guard 2: all seats")
  e2 <- M[, .(m = mean(d), se = sd(d) / sqrt(.N)), by = pair][m > 2 * se & m > 0]
  cat(sprintf("ISS3 guard 2 elections worse by > 2 SE: %s\n", if (nrow(e2)) paste(e2$pair, collapse = ", ") else "none"))
  show <- data.table(pair = c("sa2022", "fed2025", "fed2022", "fed2025"), seat = c("Waite", "Monash", "Kooyong", "Indi"))
  pw <- function(x) x[party == "IND", .(p = sum(prob)), by = .(pair, seat)]
  P <- merge(merge(show, pw(if (base == "ll_1") A else B), by = c("pair", "seat"), all.x = TRUE),
             pw(if (arm == "ll_1") A else B), by = c("pair", "seat"), all.x = TRUE, suffixes = c("_base", "_arm"))
  print(P)
}
score("ll_1", "ll_2", keys[2]); score("ll_2", "ll_1", keys[1])

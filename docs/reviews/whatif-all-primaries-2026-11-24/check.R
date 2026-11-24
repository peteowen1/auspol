# Independent R implementation of the page's weighted statistics, then compare with check.js output.
# Run from repo root: Rscript docs/reviews/whatif-all-primaries-2026-11-24/check.R  (after node check.js)
d <- "docs/reviews/whatif-all-primaries-2026-11-24/"
j <- jsonlite::fromJSON(paste0(d, "sims.json"), simplifyVector = FALSE)
V <- sapply(j$votes, unlist); S <- sapply(j$seats, unlist)   # 20000 x 5: Labor Coalition OneNation Greens Others
wq <- function(v, w, q) { o <- order(v, seq_along(v)); cw <- cumsum(w[o]); v[o][which(cw >= q * sum(w) & w[o] > 0)[1]] }
scen <- function(x, h = 1) {
  w <- exp(-0.5 * rowSums(sweep(V[, 1:4], 2, x[1:4])^2) / h^2)
  tot <- sum(w); m <- pmax(S[,1], S[,2], S[,3]); k <- (S[,1]==m) + (S[,2]==m) + (S[,3]==m)
  list(coalMajority = sum(w * (S[,2] >= 45)) / tot,
       laborMajority = sum(w * (S[,2] < 45 & S[,1] >= 45)) / tot,
       hung = sum(w * (S[,2] < 45 & S[,1] < 45)) / tot,
       ess = tot^2 / sum(w^2),
       meanLabor = sum(w * S[,1]) / tot, meanCoalition = sum(w * S[,2]) / tot,
       meanOneNation = sum(w * S[,3]) / tot, meanGreens = sum(w * S[,4]) / tot, meanOthers = sum(w * S[,5]) / tot,
       mostLabor = sum(w * (S[,1]==m) / k) / tot, mostCoalition = sum(w * (S[,2]==m) / k) / tot, mostOneNation = sum(w * (S[,3]==m) / k) / tot,
       p5 = sapply(1:5, function(i) wq(S[,i], w, .05)), p95 = sapply(1:5, function(i) wq(S[,i], w, .95)))
}
mu <- colMeans(V)  # unrounded vote means are in the json; use them
mu <- unlist(j$vote_means)[c("Labor","Coalition","OneNation","Greens","Others")]
R <- list(now = scen(c(0,0,0,0,0), h = 1e9), a = scen(mu), b = scen(c(20, 31, 21, 16, 12)))
js <- jsonlite::fromJSON(paste0(d, "check-js.json"))
maxdiff <- 0
for (s in names(R)) {
  cat("\n== scenario", s, "==\n")
  for (n in setdiff(names(js[[s]]), "")) {
    r <- R[[s]][[n]]; jv <- js[[s]][[n]]; dd <- abs(r - jv); maxdiff <- max(maxdiff, dd)
    cat(sprintf("%-15s R %9.4f  JS %9.4f  diff %.1e\n", n, r, jv, dd))
  }
  cat("p5 :", R[[s]]$p5, " p95:", R[[s]]$p95, "\n")
}
cat("\nmax abs difference R vs JS:", format(maxdiff, digits = 3), "\n")
stopifnot(maxdiff < 5e-4)

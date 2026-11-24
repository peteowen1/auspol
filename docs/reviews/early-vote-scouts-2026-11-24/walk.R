suppressPackageStartupMessages(library(data.table))
rd <- function(stem, sfx) fread(sprintf("deciding-runs/20261124-early-share-screen/live/%s-vic-2026-%s.csv", stem, sfx))
pb <- rd("seat-probs", "esbase"); pa <- rd("seat-probs", "esarm")
m <- merge(pb[, .(seat, party, b = prob)], pa[, .(seat, party, a = prob)], by = c("seat", "party"), all = TRUE)
m[is.na(b), b := 0]; m[is.na(a), a := 0]; num <- unique(m$party)
stopifnot(!anyDuplicated(m[, .(seat, party)]), uniqueN(m$seat) == 88)
m[, d := a - b]
cat(sprintf("\nWIN PROBABILITIES, 88 seats x %d party columns. Largest change in any cell: %.3f. Cells moving by 0.02 or more: %d; by 0.05 or more: %d\n", length(num), max(abs(m$d)), sum(abs(m$d) >= 0.02), sum(abs(m$d) >= 0.05)))
fav <- function(x) x[, .(fav = party[which.max(v)], p = max(v)), by = seat]
fb <- fav(m[, .(seat, party, v = b)]); fa <- fav(m[, .(seat, party, v = a)])
fl <- merge(fb, fa, by = "seat", suffixes = c("_base", "_arm"))[fav_base != fav_arm]
cat("Seats whose FAVOURITE changes:", nrow(fl), "\n"); if (nrow(fl)) print(fl)
sh_b <- rd("seat-shares", "esbase"); sh_a <- rd("seat-shares", "esarm")
alp <- merge(sh_b[, .(seat, alp_b = ALP)], sh_a[, .(seat, alp_a = ALP)], by = "seat")[, shift := round(alp_a - alp_b, 2)]
w <- dcast(m[party %in% c("ALP", "LNP", "ONP", "GRN")], seat ~ party, value.var = c("b", "a"))
w <- merge(w, alp[, .(seat, alp_primary = round(alp_b, 1), shift)], by = "seat")
w[, d_alp := round(a_ALP - b_ALP, 3)]
cat("\nTwelve seats where Labor's win chance moves most. alp_primary = Labor's predicted primary before; shift = points it moved; win chances 0-1.\n")
print(w[order(-abs(d_alp))][1:12, .(seat, alp_primary, shift, alp_win_before = round(b_ALP, 3), alp_win_after = round(a_ALP, 3), change = d_alp,
                                     lnp_before = round(b_LNP, 3), lnp_after = round(a_LNP, 3), onp_before = round(b_ONP, 3), onp_after = round(a_ONP, 3), grn_before = round(b_GRN, 3), grn_after = round(a_GRN, 3))], row.names = FALSE)
cat("\nAlbert Park:\n"); print(w[seat == "Albert Park", .(alp_primary, shift, alp_win_before = b_ALP, alp_win_after = a_ALP, grn_before = b_GRN, grn_after = a_GRN, lnp_before = b_LNP, lnp_after = a_LNP)], row.names = FALSE)
cat(sprintf("\nLabor primary shift delivered: mean |%.2f| points, max %.2f (%s), min %.2f (%s); statewide mean of seat shares %.3f -> %.3f\n",
            mean(abs(alp$shift)), max(alp$shift), alp[which.max(shift), seat], min(alp$shift), alp[which.min(shift), seat], mean(alp$alp_b), mean(alp$alp_a)))
es <- m[, .(before = sum(b), after = sum(a)), by = party][before > 0.05]
cat("\nEXPECTED SEATS (sum of win chances):\n"); print(es[, .(party, before = round(before, 2), after = round(after, 2), change = round(after - before, 2))], row.names = FALSE)
sb <- rd("seat-sims-full", "esbase"); sa <- rd("seat-sims-full", "esarm")
cat("sims columns:", paste(names(sb), collapse = " "), "\n")
out <- function(x) { c <- if ("LNP" %in% names(x)) x$LNP else NA; l <- x$ALP; c(coalition_majority = mean(c >= 45), labor_majority = mean(l >= 45), hung = mean(c < 45 & l < 45), coalition_most = mean(c > l)) }
cat("\nPARLIAMENT OUTCOMES, share of simulations:\n"); print(round(rbind(before = out(sb), after = out(sa)), 3))

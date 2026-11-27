# Scores docs/plans/prereg-night-lane-b-2026-11-27.md: base against one arm, on the three real-night replays.
#   Rscript scripts/score_night_lane_b.R --dir=<replay out dir> --base=<label> --arm=<label>
# Reads <dir>/<night>-<label>-seats.csv (night_replay_vec.R / night_replay_feed.R) and the winners in
# output/published-predictions.csv. Named seats: scripts/night_lane_b_seats.R (fixed in the prereg, copied below).
# Seat-winner log loss: -log(prob of the party that won), floored at 1e-6, averaged over the night's replay times.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
dir <- flag("dir"); bl <- flag("base", "base"); al <- flag("arm")
named <- list(
  vic2022 = c("Albert Park", "Bass", "Caulfield", "Essendon", "Euroa", "Footscray", "Geelong", "Hawthorn", "Ivanhoe", "Kew", "Malvern", "Melbourne", "Mildura", "Mornington", "Morwell", "Mulgrave", "Oakleigh", "Pascoe Vale", "Polwarth", "Prahran", "Preston", "Richmond", "Ringwood", "Shepparton", "Williamstown"),
  fed2022 = c("Adelaide", "Berowra", "Bonner", "Boothby", "Bradfield", "Brisbane", "Calare", "Canberra", "Clark", "Cooper", "Corangamite", "Cunningham", "Durack", "Fenner", "Fowler", "Franklin", "Fraser", "Fremantle", "Gellibrand", "Grayndler", "Griffith", "Groom", "Higgins", "Hume", "Indi", "Jagajaga", "Kennedy", "Kingsford Smith", "Lilley", "Macnamara", "Maribyrnong", "Mayo", "McPherson", "Melbourne", "Moreton", "Newcastle", "Nicholls", "North Sydney", "Perth", "Richmond", "Ryan", "Sturt", "Sydney", "Wannon", "Wills"),
  fed2025 = c("Adelaide", "Barton", "Bean", "Bendigo", "Blaxland", "Boothby", "Bradfield", "Brisbane", "Bullwinkel", "Calare", "Calwell", "Canberra", "Capricornia", "Cooper", "Corio", "Cunningham", "Durack", "Farrer", "Fenner", "Fisher", "Flinders", "Forrest", "Franklin", "Fraser", "Fremantle", "Gellibrand", "Grey", "Griffith", "Groom", "Hunter", "Jagajaga", "Kennedy", "Lalor", "Lilley", "Lyne", "Macnamara", "Maribyrnong", "Mayo", "Melbourne", "Monash", "Moreton", "Newcastle", "O'Connor", "Page", "Perth", "Richmond", "Ryan", "Sturt", "Swan", "Sydney", "Wright"))
P <- fread("output/published-predictions.csv")
score <- function(el, lab) {
  f <- file.path(dir, sprintf("%s-%s-seats.csv", el, lab)); if (!file.exists(f)) stop("SLB1! missing ", f)
  W <- fread(f)
  if (!"counted" %in% names(W)) { message("SLB1 ", f, " has no counted column (an older replay): the wrong-0.99 count ignores the 10% rule"); W$counted <- 1 }
  keep_p <- P$pair == el; win <- P[keep_p][won == TRUE, list(seat, party)]
  cnt <- unique(W[, list(seat, time, counted)])
  sc <- merge(CJ(seat = win$seat, time = unique(W$time)), win, by = "seat")
  sc <- merge(sc, W[, list(seat, party, time, prob)], by = c("seat", "party", "time"), all.x = TRUE)
  sc[is.na(prob), prob := 0]
  sc <- merge(sc, cnt, by = c("seat", "time"), all.x = TRUE); sc[is.na(counted), counted := 0]
  top <- W[, list(ptop = max(prob)), by = list(seat, time)]
  sc <- merge(sc, top, by = c("seat", "time"), all.x = TRUE)
  sc[, `:=`(ll = -log(pmax(prob, 1e-6)), wrong99 = ptop >= 0.99 & prob < 0.5 & counted >= 0.10)]
  sc
}
nights <- strsplit(flag("nights", paste(names(named), collapse = ",")), ",")[[1]]   # --nights=vic2022 for B3
dev_seats <- c("vic2022|Mildura", "fed2025|Melbourne")   # traced while building (disclosed in the prereg)
pool <- list()
for (el in nights) {
  b <- score(el, bl); x <- score(el, al)
  m <- merge(b[, list(seat, time, llb = ll, wb = wrong99, pb = prob)], x[, list(seat, time, lla = ll, wa = wrong99, pa = prob)], by = c("seat", "time"))
  ps <- m[, list(d = mean(lla - llb), llb = mean(llb), lla = mean(lla)), by = seat]   # night-average per seat
  nm <- ps[ps$seat %in% named[[el]]]
  se_all <- sd(ps$d) / sqrt(nrow(ps)); se_nm <- sd(nm$d) / sqrt(nrow(nm))
  last <- max(m$time)
  cat(sprintf("SLB2 %s %s vs %s | PRIMARY named %d seats: %.4f -> %.4f (d %+.4f, SE %.4f) | ALL %d seats: %.4f -> %.4f (d %+.4f, SE %.4f, guard %s) | wrong 0.99 calls (10%%+ counted, seat-times) %d -> %d | right at %s %d -> %d\n",
              el, bl, al, nrow(nm), mean(nm$llb), mean(nm$lla), mean(nm$d), se_nm, nrow(ps), mean(ps$llb), mean(ps$lla), mean(ps$d), se_all,
              if (mean(ps$d) > se_all) "FAIL" else "ok", sum(m$wb), sum(m$wa), last, sum(m$pb[m$time == last] > 0.5), sum(m$pa[m$time == last] > 0.5)))
  pool[[el]] <- nm[, list(key = paste(el, seat, sep = "|"), d)]
}
Q <- rbindlist(pool); Qx <- Q[!Q$key %in% dev_seats]
cat(sprintf("SLB3 POOLED PRIMARY %s vs %s, %d named seat-nights: d %+.4f (SE %.4f, %s) | without the two development seats (%d): d %+.4f (SE %.4f)\n",
            bl, al, nrow(Q), mean(Q$d), sd(Q$d) / sqrt(nrow(Q)), if (mean(Q$d) < -sd(Q$d) / sqrt(nrow(Q))) "better by >1 SE" else "not better by 1 SE",
            nrow(Qx), mean(Qx$d), sd(Qx$d) / sqrt(nrow(Qx))))

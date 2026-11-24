# Export simulated statewide primaries and seat counts for the what-if page.
# Run from the repo root.
d <- "deciding-runs/20261124-early-share-screen/live/"
rds <- readRDS(paste0(d, "night-state-vic-2026-esbase.rds"))
swd <- as.matrix(rds$swd)
seats <- read.csv(paste0(d, "seat-sims-full-vic-2026-esbase.csv"))
cols <- c("ALP","GRN","IND","LNP","ONP","OTH","OTH_RIGHT")
stopifnot(nrow(swd) == 20000, nrow(seats) == 20000, all(cols %in% colnames(swd)), all(cols %in% names(seats)))
stopifnot(all(rowSums(seats[, cols]) == 88))
oth_cols <- c("IND","OTH","OTH_RIGHT")
grp <- function(m) cbind(Labor = m[, "ALP"], Coalition = m[, "LNP"], OneNation = m[, "ONP"],
                         Greens = m[, "GRN"], Others = rowSums(m[, oth_cols]))
v <- round(grp(swd), 1)
s <- grp(as.matrix(seats[, cols]))
cat("rows: votes", nrow(v), " seats", nrow(s), "\n")
cat("mean votes (unrounded):\n"); print(round(colMeans(grp(swd)), 2))
cat("mean votes (rounded):\n"); print(round(colMeans(v), 2))
cat("mean seats:\n"); print(round(colMeans(s), 2))
cat("mean vote row sum:", round(mean(rowSums(swd)), 2), "\n")
lst <- list(parties = colnames(v), n = nrow(v), seats_total = 88,
            vote_means = round(colMeans(grp(swd)), 3), seat_means = round(colMeans(s), 3),
            votes = lapply(seq_len(5), function(j) v[, j]),
            seats = lapply(seq_len(5), function(j) as.integer(s[, j])))
lst$vote_means <- as.list(lst$vote_means); lst$seat_means <- as.list(lst$seat_means)
js <- jsonlite::toJSON(lst, auto_unbox = TRUE, digits = NA)
writeLines(js, "docs/reviews/whatif-all-primaries-2026-11-24/sims.json")
cat("wrote sims.json,", file.size("docs/reviews/whatif-all-primaries-2026-11-24/sims.json"), "bytes\n")

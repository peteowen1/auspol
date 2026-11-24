# Builds the demo-resid-vic2026.csv the daily run should read once AUSPOL_DEMO_RESID_EARLY ships:
# the LIVE release's census table (promoted 23 Nov from C:/dev/auspol-wt-rbm) plus Labor's early-share shift fitted
# on that same live model's as-at misses. Writes only into this folder; uploads nothing.
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
D <- "deciding-runs/20261124-early-share-screen"; LIVE <- "C:/dev/auspol-wt-rbm"
rel <- fread(file.path(D, "release", "demo-resid-vic2026.csv"))
stopifnot(identical(unname(tools::md5sum(file.path(D, "release", "demo-resid-vic2026.csv"))), unname(tools::md5sum(file.path(LIVE, "output", "demo-resid-vic2026.csv")))))
tab <- fread("output/prev-early-share.csv")
options(auspol.root = LIVE); tr <- auspol:::.demo_training_current(); options(auspol.root = normalizePath("."))
seats <- unique(rel$seat)
Sys.setenv(AUSPOL_DEMO_RESID_EARLY = "1")
r <- auspol:::early_share_adjust(seats, "vic2026", tr, file.path(LIVE, "output", "census-features.csv"), DEMO_FEATURES, tab = tab)
stopifnot(!is.null(r), length(r$adj) == length(seats), abs(sum(r$adj)) < 1e-8)
es <- data.table(seat = seats, class = "ALP", early = r$adj)
new <- merge(rel, es, by = c("seat", "class"), all.x = TRUE, sort = FALSE)
new[is.na(early), early := 0]
stopifnot(nrow(new) == nrow(rel), identical(new$seat, rel$seat), identical(new$class, rel$class), all(new[class != "ALP"]$early == 0))
cat(sprintf("rows %d (ALP %d, GRN %d); ALP seats shifted %d, unshifted: %s\n", nrow(new), sum(new$class == "ALP"), sum(new$class == "GRN"), sum(new$early != 0), paste(new[class == "ALP" & early == 0]$seat, collapse = ", ")))
cat(sprintf("ALP adj before: mean %+.3f, range %+.2f to %+.2f; after: mean %+.3f, range %+.2f to %+.2f; GRN rows unchanged: %s\n", mean(new[class == "ALP"]$adj), min(new[class == "ALP"]$adj), max(new[class == "ALP"]$adj),
            mean(new[class == "ALP", adj + early]), min(new[class == "ALP", adj + early]), max(new[class == "ALP", adj + early]), identical(new[class == "GRN"]$adj, rel[class == "GRN"]$adj)))
out <- new[, .(seat, class, adj = adj + early)]
dir.create(file.path(D, "to-publish"), showWarnings = FALSE)
fwrite(out, file.path(D, "to-publish", "demo-resid-vic2026.csv"))
fwrite(new[class == "ALP", .(seat, census_adj = round(adj, 3), early_shift = round(early, 3), total = round(adj + early, 3))][order(early_shift)], file.path(D, "to-publish", "shift-by-seat.csv"))
cat("wrote", file.path(D, "to-publish", "demo-resid-vic2026.csv"), "\n")

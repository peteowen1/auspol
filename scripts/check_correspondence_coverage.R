# Which intermediate vintage in the 2016->2025 SED correspondence chain
# actually matches WA/QLD's real election boundaries? Checked empirically
# per election rather than assumed, since redistribution timing varies by
# state and doesn't necessarily line up with ABS's correspondence-file years.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

REF <- file.path("external", "reference")
CORR <- file.path(REF, "correspondences", "abs-sed")

load_corr <- function(f) {
  d <- fread(file.path(CORR, f), showProgress = FALSE, encoding = "UTF-8")
  setnames(d, c("from_code","from_name","to_code","to_name","ratio","q1","q2","flag"))
  d[, .(from_code = as.character(from_code), to_code = as.character(to_code),
        to_name, ratio = as.numeric(ratio))]
}
steps <- list(
  y2021 = load_corr("CG_SED_2016_SED_2021.csv"),
  y2022 = load_corr("CG_SED_2021_SED_2022.csv"),
  y2024 = load_corr("CG_SED_2022_SED_2024.csv"),
  y2025 = load_corr("CG_SED_2024_SED_2025.csv")
)

chain <- steps$y2021[, .(src_code = from_code, cur_code = to_code, cur_name = to_name, ratio)]
snapshots <- list(y2021 = copy(chain))
for (nm in c("y2022","y2024","y2025")) {
  nxt <- copy(steps[[nm]]); setnames(nxt, "ratio", "ratio2")
  m <- merge(chain, nxt, by.x = "cur_code", by.y = "from_code", allow.cartesian = TRUE)
  m[, ratio := ratio * ratio2]
  chain <- m[, .(ratio = sum(ratio)), by = .(src_code, cur_code = to_code, cur_name = to_name)]
  snapshots[[nm]] <- copy(chain)
}

cf <- file.path("output", "candidacies.csv")
C <- fread(cf, showProgress = FALSE)
strip_suffix <- function(x) trimws(sub("\\s*\\(.*\\)\\s*$", "", x))

checks <- list(
  list(election = "wa2013"), list(election = "wa2017"),
  list(election = "qld2017"), list(election = "qld2020")
)
best <- list()
for (chk in checks) {
  ours <- sort(unique(C[election == chk$election, seat]))
  cat(sprintf("\n=== %s (%d our seats) ===\n", chk$election, length(ours)))
  covs <- numeric(0)
  for (nm in names(snapshots)) {
    theirs <- sort(unique(strip_suffix(snapshots[[nm]]$cur_name)))
    miss <- setdiff(ours, theirs)
    cov <- 1 - length(miss) / length(ours)
    covs[nm] <- cov
    cat(sprintf("  vintage %s: coverage %5.1f%% (%d unmatched)\n", nm, 100*cov, length(miss)))
    if (length(miss)) cat(sprintf("    unmatched: %s\n", paste(miss, collapse=", ")))
  }
  # EARLIEST vintage achieving the best coverage, not the newest. Chaining
  # further can only pull boundaries PAST the election being matched -- WA is
  # the concrete case: wa2017 peaks at 98.3% on 2021/2022 and falls to 89.8%
  # by 2025, because WA's 2023 redistribution enters the chain after the
  # election. Ties therefore resolve to the earliest, not the latest.
  best[[chk$election]] <- names(covs)[which.max(covs)]
}

# THE POINT OF THIS SCRIPT: say which file each election should actually use.
# Previously it printed coverage and stopped, and build_census_correspondence.R
# unconditionally wrote only the final 2025 vintage -- so nothing connected the
# measurement to the choice, and every consumer silently got 2025 boundaries
# even where an earlier vintage measurably fits better.
cat("\n=== USE THIS VINTAGE PER ELECTION (earliest vintage at best coverage) ===\n")
for (el in names(best)) {
  yr <- sub("^y", "", best[[el]])
  cat(sprintf("  %-9s -> external/reference/census/census-sed-2016-reaggregated-to-%s.csv (coverage %.1f%%)\n",
              el, yr, 100 * max(sapply(names(snapshots), function(nm) {
                ours <- sort(unique(C[election == el, seat]))
                theirs <- sort(unique(strip_suffix(snapshots[[nm]]$cur_name)))
                1 - length(setdiff(ours, theirs)) / length(ours)
              }))))
}
cat("\nNOTE: newest is NOT always right -- chaining past the election's own\n")
cat("redistribution makes coverage worse, not better. Pick per the table above.\n")

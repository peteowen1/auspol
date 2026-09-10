# Re-aggregates ABS census data across a boundary-vintage change using ABS's
# own population-weighted "Geographic Correspondence" files, instead of a
# name-similarity match (which silently imports the wrong people's
# demographics when a boundary genuinely moved, not just renamed -- see
# scripts/fetch_census_sed_2016.R's header comment for the concrete case
# this fixes: WA/QLD's "2016" SED boundary file was found to actually be a
# May-2018 reissue).
#
# APPROACH: ABS publishes SED-to-SED correspondence files DIRECTLY (no SA1
# intermediate step needed) -- https://www.abs.gov.au/statistics/standards/
# australian-statistical-geography-standard-asgs/edition-3-july-2021-june-2026/
# access-and-downloads/correspondences. Each row gives (source SED, target
# SED, RATIO_FROM_TO = population share of source going to target). Chaining
# consecutive correspondences (2016->2021->2022->2024->2025) lets us
# re-aggregate 2016 census data onto ANY later boundary vintage.
#
# COUNTS ONLY, NOT MEDIANS. G01 (age/sex) is counts -- safe to re-aggregate
# by population-weighted summing. G02 (medians: age, income, rent, mortgage)
# is NOT -- a median cannot be validly reconstructed from a population-
# weighted sum of medians. Re-aggregating those anyway would silently
# produce numbers that look like real medians but aren't. Median columns are
# identified and EXCLUDED from the output, named explicitly, not silently
# dropped.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

REF <- file.path("external", "reference")
CORR <- file.path(REF, "correspondences", "abs-sed")
CEN <- file.path(REF, "census")

# ---- load and chain the correspondence files --------------------------------
# Each file: SED_CODE_<from>, SED_NAME_<from>, SED_CODE_<to>, SED_NAME_<to>,
# RATIO_FROM_TO (population share of the FROM seat going to the TO seat).
load_corr <- function(f, from_yr, to_yr) {
  d <- fread(file.path(CORR, f), showProgress = FALSE, encoding = "UTF-8")
  setnames(d, c("from_code","from_name","to_code","to_name","ratio","q1","q2","flag"))
  d[, .(from_code = as.character(from_code), to_code = as.character(to_code),
        to_name, ratio = as.numeric(ratio))]
}

steps <- list(
  list(yr = 2021L, d = load_corr("CG_SED_2016_SED_2021.csv", 2016, 2021)),
  list(yr = 2022L, d = load_corr("CG_SED_2021_SED_2022.csv", 2021, 2022)),
  list(yr = 2024L, d = load_corr("CG_SED_2022_SED_2024.csv", 2022, 2024)),
  list(yr = 2025L, d = load_corr("CG_SED_2024_SED_2025.csv", 2024, 2025))
)

# ---- census, loaded once; column split decided once --------------------------
cen16 <- fread(file.path(CEN, "census-sed-2016.csv"), showProgress = FALSE)
cen16[, src_code := sub("^SED", "", sed_code)]

all_cols <- names(cen16)
median_cols <- grep("Median|Average", all_cols, value = TRUE)
count_cols <- setdiff(all_cols, c("sed_code", "src_code", "state", "sed_name", "seat", median_cols))
# A count column stored as CHARACTER (e.g. a future ABS extract using a
# suppressed-cell placeholder) would be silently dropped by this filter and
# show up only as a smaller number in the COLS line. Name them, the same way
# the median exclusion is named -- a silent narrowing is the failure this
# repo's own "assert coverage, not presence" rule exists to catch.
non_numeric <- count_cols[!sapply(cen16[, ..count_cols], is.numeric)]
if (length(non_numeric)) {
  cat(sprintf("COLS!  %d non-numeric count column(s) DROPPED (cannot be summed): %s\n",
              length(non_numeric), paste(non_numeric, collapse = ", ")))
}
count_cols <- setdiff(count_cols, non_numeric)
cat(sprintf("COLS   %d numeric count columns will be re-aggregated; %d median/average columns EXCLUDED (cannot be validly re-aggregated by weighted summing): %s\n",
            length(count_cols), length(median_cols), paste(head(median_cols, 5), collapse=", ")))

# Population total BEFORE re-aggregation, for the conservation check below.
pop_col <- if ("Tot_P_P" %in% count_cols) "Tot_P_P" else count_cols[1]
pop_before <- sum(cen16[[pop_col]], na.rm = TRUE)

# ---- chain step by step, writing an output at EVERY vintage ------------------
# ONE FILE PER VINTAGE, not just the final one. The right vintage is NOT
# always the newest: scripts/check_correspondence_coverage.R measures which
# vintage each election's own seat names actually match, and for WA the
# answer is 2021/2022 (98.3% for wa2017), with further chaining making it
# WORSE (89.8% by 2025) because WA's 2023 redistribution enters the chain
# after the election being matched. Writing only the 2025 file would silently
# hand every consumer the wrong-vintage boundaries for those elections.
# Consumers pick the vintage their own election matches; the diagnostic
# script says which that is.
chain <- steps[[1]]$d[, .(src_code = from_code, cur_code = to_code, cur_name = to_name, ratio)]
for (i in seq_along(steps)) {
  if (i > 1) {
    nxt <- copy(steps[[i]]$d)
    setnames(nxt, "ratio", "ratio2")
    m <- merge(chain, nxt, by.x = "cur_code", by.y = "from_code", allow.cartesian = TRUE)
    m[, ratio := ratio * ratio2]
    chain <- m[, .(ratio = sum(ratio)), by = .(src_code, cur_code = to_code, cur_name = to_name)]
  }
  yr <- steps[[i]]$yr
  this <- chain[, .(src_code, final_code = cur_code, final_name = cur_name, ratio)]

  # GATES the build, does not merely report. A source seat whose ratios do not
  # sum to 1 means population is unaccounted for -- silently shipping a
  # re-aggregated file built on it is exactly the "guard that cannot fail"
  # pattern CLAUDE.md records. Named, then stopped.
  chk <- this[, .(tot = sum(ratio)), by = src_code]
  bad <- chk[abs(tot - 1) > 0.01]
  if (nrow(bad)) {
    stop(sprintf("chain to %d: %d source SED(s) have ratios not summing to 1.0 (population unaccounted for): %s",
                 yr, nrow(bad), paste(sprintf("%s=%.3f", bad$src_code, bad$tot), collapse = ", ")))
  }
  cat(sprintf("CHAIN  %d: %d source SEDs -> %d pairs | ratio-sum check passed for all %d source seats\n",
              yr, uniqueN(this$src_code), nrow(this), nrow(chk)))
  fwrite(this, file.path(CORR, sprintf("chain_2016_to_%d.csv", yr)))

  mm <- merge(cen16, this, by = "src_code", allow.cartesian = TRUE)
  for (col in count_cols) mm[, (col) := get(col) * ratio]
  out <- mm[, lapply(.SD, sum, na.rm = TRUE), by = .(final_code, final_name), .SDcols = count_cols]

  # POPULATION CONSERVATION, asserted not assumed. The merge above is an inner
  # join: a src_code present in the census but absent from the chain vanishes
  # silently, taking its people with it. Nothing else downstream would notice.
  pop_after <- sum(out[[pop_col]], na.rm = TRUE)
  drift <- abs(pop_after - pop_before) / pop_before
  if (!is.finite(drift) || drift > 0.001) {
    stop(sprintf("chain to %d: population NOT conserved through re-aggregation -- %s before %.0f, after %.0f (%.3f%% drift). A source seat is failing to match the chain.",
                 yr, pop_col, pop_before, pop_after, 100 * drift))
  }

  f <- file.path(CEN, sprintf("census-sed-2016-reaggregated-to-%d.csv", yr))
  fwrite(out, f)
  cat(sprintf("WROTE  %s: %d target divisions, %d columns | %s conserved %.0f -> %.0f (%.4f%% drift)\n",
              f, nrow(out), length(count_cols), pop_col, pop_before, pop_after, 100 * drift))
}

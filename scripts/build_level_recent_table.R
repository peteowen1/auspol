# Input table for AUSPOL_LEVEL_RECENT (R/level_recent.R): per election and class
# (ALP, LNP, GRN), the shipped day-before trend level computed WITH THE BLEND
# OFF, the mean of the polls in the 28 days before polling day (Nationals folded
# into LNP), the poll count and the actual statewide share. level_recent_k()
# fits its blend constant on the rows dated before each target, so no harness
# refits another election's trend. Rebuild stage 5b, before the harnesses.
# plans/prereg-level-recent-blend-2026-10-10.md. Emits LT* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
Sys.setenv(AUSPOL_LEVEL_RECENT = "0")   # the trend this table records is the UNBLENDED one
suppressMessages(library(data.table))
C <- fread(out_path("candidacies.csv"), select = c("election", "party", "votes"), showProgress = FALSE)
share <- function(e) {
  .e <- e
  x <- C[C$election == .e & is.finite(C$votes), list(v = sum(votes)), by = "party"]
  setNames(100 * x$v / sum(x$v), x$party)
}
prs <- all_election_pairs()
rows <- list()
for (p in prs) {
  e <- p$election; reg <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e))
  ed <- as.Date(unname(election_dates()[e]))
  sa <- share(p$prev); sb <- share(e)
  fc <- NULL
  utils::capture.output(fc <- tryCatch(
    forecast_statewide_or_oracle(reg, yr, ed, names(sb), sa, sb, code = "LT0", n_sims = 20000L, seed = 42L, on_fail = "skip"),
    error = function(err) NULL))
  ra <- level_recent_avg(reg, ed)
  for (k in c("ALP", "LNP", "GRN"))
    rows[[length(rows) + 1L]] <- data.table(election = e, region = reg, cls = k,
                                            trend = if (is.null(fc) || !k %in% names(fc)) NA_real_ else unname(fc[k]),
                                            avg28 = unname(ra$avg[k]), n28 = ra$n, actual = unname(sb[k]))
}
R <- rbindlist(rows)
ok <- R[is.finite(trend) & is.finite(avg28) & is.finite(actual)]
cat(sprintf("LT1  %d rows, %d elections; scoreable %d (%d elections); trend missing for: %s\n", nrow(R), uniqueN(R$election),
            nrow(ok), uniqueN(ok$election), paste(unique(R$election[!is.finite(R$trend)]), collapse = ", ")))
if (uniqueN(ok$election) < 15L) stop("LT1! fewer than 15 scoreable elections -- check the trend fits and the poll files")
fwrite(R, out_path("level-recent.csv"))
cat(sprintf("LT2  wrote %s\n", out_path("level-recent.csv")))

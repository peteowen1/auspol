# Screen for docs/plans/prereg-own-poll-source-step2-2026-10-12.md: the day-before statewide level under AE's
# poll file vs our layered source. Run once per source (separate processes: load_polls() results are cached
# per process), then compare:
#   powershell.exe -Command 'Rscript "scripts/screen_poll_source.R" --source=ae'
#   powershell.exe -Command 'Rscript "scripts/screen_poll_source.R" --source=layered'
#   powershell.exe -Command 'Rscript "scripts/screen_poll_source.R" --compare'
# Each source run rebuilds the level-recent table (trend with the blend off, 28-day mean, actual) in memory, then
# applies the shipped blend with k refitted time-forward on THAT table. Writes deciding-runs/poll-source-<src>.csv
# only. Emits PQ* codes. Data.table NSE: masks are built outside [...].
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
suppressMessages(library(data.table))
args <- commandArgs(TRUE)
getarg <- function(nm, dflt) { a <- grep(paste0("^--", nm, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nm, "="), "", a[1]) else dflt }
OUTF <- function(s) file.path("deciding-runs", sprintf("poll-source-%s.csv", s))

if ("--compare" %in% args) {
  A <- fread(OUTF("ae")); L <- fread(OUTF("layered"))
  M <- merge(A[, .(election, cls, actual, lev_ae = level, trend_ae = trend)], L[, .(election, cls, lev_l = level, trend_l = trend)], by = c("election", "cls"))
  M <- M[is.finite(actual) & is.finite(lev_ae) & is.finite(lev_l)]
  rmse <- function(x, a) sqrt(mean((x - a)^2))
  jk <- function(a, b) { full <- rmse(M[[a]], M$actual) - rmse(M[[b]], M$actual); u <- unique(M$election); G <- length(u)
    th <- vapply(u, function(x) { m <- M$election != x; rmse(M[[a]][m], M$actual[m]) - rmse(M[[b]][m], M$actual[m]) }, 0)
    c(d = full, se = sqrt((G - 1) / G * sum((th - mean(th))^2))) }
  cat(sprintf("PQ5 %d cells / %d elections. Day-before level RMSE vs actual (points, lower better): AE %.3f | layered %.3f\n",
              nrow(M), uniqueN(M$election), rmse(M$lev_ae, M$actual), rmse(M$lev_l, M$actual)))
  r <- jk("lev_l", "lev_ae"); cat(sprintf("PQ5 layered - AE: %+.3f (SE %.3f, jackknife over elections)\n", r["d"], r["se"]))
  r2 <- jk("trend_l", "trend_ae"); cat(sprintf("PQ5 trend alone, layered - AE: %+.3f (SE %.3f)\n", r2["d"], r2["se"]))
  M[, moved := lev_l - lev_ae]
  cat("PQ6 cells whose level moved by more than 0.1 point:\n"); print(M[abs(moved) > 0.1, .(election, cls, actual = round(actual, 2), ae = round(lev_ae, 2), layered = round(lev_l, 2), moved = round(moved, 2))][order(-abs(moved))], nrows = 80)
  cat(sprintf("PQ7 elections unchanged (every cell within 1e-6): %d of %d\n", sum(M[, all(abs(moved) < 1e-6), by = election]$V1), uniqueN(M$election)))
  quit(save = "no")
}

SRC <- getarg("source", "ae")
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
Sys.setenv(AUSPOL_POLL_SOURCE = SRC)
cat(sprintf("PQ0 source %s (applies AUSPOL_POLL_SOURCE=%s); level blend %s HL %s, federal breakdowns r %s\n", SRC, poll_source_mode(),
            Sys.getenv("AUSPOL_LEVEL_RECENT"), Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE"), Sys.getenv("AUSPOL_LEVEL_FED_R")))
C <- fread(out_path("candidacies.csv"), select = c("election", "party", "votes"), showProgress = FALSE)
share <- function(e) { .e <- e; x <- C[C$election == .e & is.finite(C$votes), list(v = sum(votes)), by = "party"]; setNames(100 * x$v / sum(x$v), x$party) }
eds <- election_dates()
# 1. the level-recent table under this source (as scripts/build_level_recent_table.R, in memory)
Sys.setenv(AUSPOL_LEVEL_RECENT = "0")
rows <- list()
for (p in all_election_pairs()) {
  e <- p$election; reg <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e)); ed <- as.Date(unname(eds[e]))
  sa <- share(p$prev); sb <- share(e); fc <- NULL
  utils::capture.output(fc <- tryCatch(forecast_statewide_or_oracle(reg, yr, ed, names(sb), sa, sb, code = "PQ", n_sims = 20000L, seed = 42L, on_fail = "skip"), error = function(z) NULL))
  ra <- level_recent_avg(reg, ed)
  for (k in c("ALP", "LNP", "GRN"))
    rows[[length(rows) + 1L]] <- data.table(election = e, region = reg, cls = k, trend = if (is.null(fc) || !k %in% names(fc)) NA_real_ else unname(fc[k]),
                                            avg28 = unname(ra$avg[k]), n28 = ra$n, actual = unname(sb[k]))
}
tab <- rbindlist(rows)
cat(sprintf("PQ1 table: %d rows, %d elections, trend missing for: %s\n", nrow(tab), uniqueN(tab$election), paste(unique(tab$election[!is.finite(tab$trend)]), collapse = ",")))
# 2. the shipped blend on top, k refitted time-forward on this table
Sys.setenv(AUSPOL_LEVEL_RECENT = PUBLISHED_FLAGS[["AUSPOL_LEVEL_RECENT"]])
out <- rbindlist(lapply(unique(tab$election), function(e0) {
  d <- tab[tab$election == e0]; lv <- setNames(d$trend, d$cls)
  if (any(!is.finite(lv))) return(data.table(election = e0, cls = d$cls, trend = d$trend, level = NA_real_, actual = d$actual))
  lv <- c(lv[c("ALP", "LNP", "GRN")], OTH = 100 - sum(lv[c("ALP", "LNP", "GRN")]))
  invisible(capture.output(res <- level_recent_apply(lv, e0, d$region[1], as.Date(unname(eds[e0])), code = "PQ", tab = tab)))
  data.table(election = e0, cls = c("ALP", "LNP", "GRN"), trend = unname(lv[c("ALP", "LNP", "GRN")]), level = unname(res[c("ALP", "LNP", "GRN")]),
             actual = d$actual[match(c("ALP", "LNP", "GRN"), d$cls)])
}))
dir.create("deciding-runs", showWarnings = FALSE)
fwrite(out, OUTF(SRC))
cat(sprintf("PQ2 wrote %s: %d cells\n", OUTF(SRC), nrow(out)))

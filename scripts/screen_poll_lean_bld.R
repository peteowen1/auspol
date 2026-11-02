# Poll-lean screen, arm BLD (plans/prereg-poll-lean-2026-11-02.md, Amendment 1): blend One Nation's day-before level
# toward its recent polls, as the shipped level already does for ALP, LNP and GRN (R/level_recent.R,
# AUSPOL_LEVEL_RECENT_CLS). Scored on the SHIPPED level: the pre-blend forecast, then the blend.
#
#   powershell.exe -Command 'Rscript "scripts/screen_poll_lean_bld.R" [--cache=<dir>]'
#
# Step 1 rebuilds, per election, the pre-blend day-before level exactly as scripts/build_level_recent_table.R does
# (forecast_statewide_or_oracle(), blend off), keeping every class, and appends it to <cache>/bld-levels.csv after
# EACH election, so a killed run keeps what it finished and a rerun skips it. Step 2 applies the blend twice per
# election from that table (published classes vs + ONP), with k fitted time-forward by the shipped code.
#   PLB0  the dry run: the table's ALP/LNP/GRN pre-blend levels against output/level-recent.csv (must match)
#   PLB1  per election: shipped blend vs arm, the arm's k and w, One Nation level before/after
#   PLB2  clause 1, clause 3 (leave-one-election-out), clause 6 (direction)
#   PLB3  One Nation's signed error and sa2026 (the named-in-advance unacceptable win)
#   PLB4  the live walk: vic2026 with and without (needs the published run's pre-blend level)
# Writes nothing to output/. Data.table NSE: no local shares a column name inside [...].

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
suppressMessages(library(data.table))
stopifnot(Sys.getenv("AUSPOL_LEVEL_RECENT_CLS") == "ALP,LNP,GRN", Sys.getenv("AUSPOL_LEVEL_RECENT") == "decay")
args <- commandArgs(TRUE)
cache_dir <- sub("^--cache=", "", c(grep("^--cache=", args, value = TRUE), file.path(tempdir(), "bld"))[1])
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
cache_f <- file.path(cache_dir, "bld-levels.csv")
ARM <- "ALP,LNP,GRN,ONP"
MAIN <- c("ALP", "LNP", "GRN", "ONP")
LIVE <- c("vic2026", "nsw2027")

C <- fread(out_path("candidacies.csv"), select = c("election", "party", "votes"), showProgress = FALSE)
share <- function(e) {
  .e <- e
  x <- C[C$election == .e & is.finite(C$votes), list(v = sum(votes)), by = "party"]
  setNames(100 * x$v / sum(x$v), x$party)
}

# ---- step 1: pre-blend levels, one election at a time, persisted as it goes ----------------------------------
done <- if (file.exists(cache_f)) unique(fread(cache_f, showProgress = FALSE)$election) else character(0)
prs <- all_election_pairs()
cat(sprintf("PLB0  cache %s: %d elections already on disk, %d pairs in all\n", cache_f, length(done), length(prs)))
t0 <- Sys.time()
for (p in prs) {
  e <- p$election
  if (e %in% done || e %in% LIVE) next
  reg <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e))
  ed <- as.Date(unname(election_dates()[e]))
  sa <- share(p$prev); sb <- share(e)
  fc <- NULL
  Sys.setenv(AUSPOL_LEVEL_RECENT = "0")
  utils::capture.output(fc <- tryCatch(
    forecast_statewide_or_oracle(reg, yr, ed, names(sb), sa, sb, code = "PLBF", n_sims = 20000L, seed = 42L, on_fail = "skip"),
    error = function(err) NULL))
  Sys.setenv(AUSPOL_LEVEL_RECENT = "decay")
  cl <- union(names(sb), names(fc))
  row <- data.table(election = e, region = reg, cls = cl,
                    trend = if (is.null(fc)) NA_real_ else unname(fc[cl]),
                    actual = unname(sb[cl]))
  fwrite(row, cache_f, append = file.exists(cache_f))
  cat(sprintf("PLB0  %s done (%s), %.1f min so far\n", e, if (is.null(fc)) "NO FIT" else "ok",
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
stopifnot(Sys.getenv("AUSPOL_LEVEL_RECENT") == "decay")
L <- fread(cache_f, showProgress = FALSE)
L[is.na(actual), actual := 0]

# dry run against the shipped table
ref <- fread(out_path("level-recent.csv"), showProgress = FALSE)
chk <- merge(ref[, .(election, cls, ref_trend = trend)], L[, .(election, cls, trend)], by = c("election", "cls"))
chk <- chk[is.finite(chk$ref_trend) & is.finite(chk$trend)]
cat(sprintf("PLB0  dry run: %d ALP/LNP/GRN cells vs output/level-recent.csv, max |diff| %.4f (must be ~0)\n",
            nrow(chk), max(abs(chk$ref_trend - chk$trend))))
if (!nrow(chk) || max(abs(chk$ref_trend - chk$trend)) > 0.01) stop("PLB0! the rebuilt pre-blend level does not reproduce the shipped table")

# ---- step 2: blend under both class sets, scored on the shipped level -----------------------------------------
tab <- L[L$cls %in% MAIN & is.finite(L$trend), .(election, region, cls, trend, actual)]
score <- function(lv, act) {
  ps <- intersect(MAIN, names(lv))
  a <- vapply(ps, function(k) if (k %in% names(act)) act[[k]] else 0, 1)
  e <- unname(lv[ps]) - unname(a)
  list(mae = mean(abs(c(e, (100 - sum(lv[ps])) - (100 - sum(a))))), onp = if ("ONP" %in% ps) e[ps == "ONP"] else NA_real_)
}
rows <- list()
for (e in setdiff(unique(L$election), LIVE)) {
  x <- L[L$election == e & is.finite(L$trend)]
  if (!nrow(x)) next
  lv <- setNames(x$trend, x$cls); act <- setNames(x$actual, x$cls)
  lv <- lv * 100 / sum(lv)
  reg <- x$region[1]; ed <- as.Date(unname(election_dates()[e]))
  inc <- NULL; arm <- NULL
  o1 <- utils::capture.output(inc <- level_recent_apply(lv, e, reg, ed, code = "PLBi", tab = tab))
  Sys.setenv(AUSPOL_LEVEL_RECENT_CLS = ARM)
  o2 <- utils::capture.output(arm <- level_recent_apply(lv, e, reg, ed, code = "PLBa", tab = tab))
  Sys.setenv(AUSPOL_LEVEL_RECENT_CLS = "ALP,LNP,GRN")
  s0 <- score(inc, act); s1 <- score(arm, act)
  kw <- regmatches(o2, regexpr("k [0-9.]+.*w [0-9.]+", o2))
  rows[[e]] <- data.table(election = e, end = ed, shipped = s0$mae, arm = s1$mae, diff = s1$mae - s0$mae,
                          onp_pre = if ("ONP" %in% names(lv)) lv[["ONP"]] else NA_real_,
                          onp_shipped = if ("ONP" %in% names(inc)) inc[["ONP"]] else NA_real_,
                          onp_arm = if ("ONP" %in% names(arm)) arm[["ONP"]] else NA_real_,
                          onp_err_shipped = s0$onp, onp_err_arm = s1$onp, kw = if (length(kw)) kw[1] else "")
}
w <- rbindlist(rows); setorder(w, end)
cat("\nPLB1  shipped level vs arm, day-before mean absolute error in points (lower is better); diff = arm - shipped\n")
print(w[, .(election, shipped = round(shipped, 3), arm = round(arm, 3), diff = round(diff, 4),
            onp_pre = round(onp_pre, 2), onp_arm = round(onp_arm, 2), kw)])

n <- nrow(w); md <- mean(w$diff); se <- sd(w$diff) / sqrt(n)
cat(sprintf("\nPLB2  clause 1: mean change %+.4f points, SE %.4f (n %d elections): %s\n", md, se, n,
            if (md < -se) "PASS (better by more than 1 SE)" else "NOT PASSED"))
loo <- vapply(seq_len(n), function(j) { xx <- w$diff[-j]; mean(xx) + sd(xx) / sqrt(n - 1) }, 1)
cat(sprintf("PLB2  clause 3: leave-one-election-out, still better by > 1 SE in %d of %d drops; worst drop %s\n",
            sum(loo < 0), n, w$election[which.max(loo)]))
cat(sprintf("PLB2  clause 6: elections moved %d; better %d, worse %d\n", sum(abs(w$diff) > 1e-12),
            sum(w$diff < -1e-12), sum(w$diff > 1e-12)))

on <- w[is.finite(w$onp_err_shipped)]
cat("\nPLB3  One Nation signed error on the shipped level (points; positive = over-states)\n")
print(on[, .(election, shipped = round(onp_err_shipped, 2), arm = round(onp_err_arm, 2))])
cat(sprintf("PLB3  mean |ONP error| shipped %.3f, arm %.3f (n %d)\n", mean(abs(on$onp_err_shipped)), mean(abs(on$onp_err_arm)), nrow(on)))
sa <- w[w$election == "sa2026"]
if (nrow(sa)) cat(sprintf("PLB3  sa2026: shipped %.3f, arm %.3f, change %+.4f; One Nation %.2f -> %.2f (actual %.2f)\n",
                          sa$shipped, sa$arm, sa$diff, sa$onp_shipped, sa$onp_arm, sa$onp_shipped - sa$onp_err_shipped))

# ---- live walk: the vic2026 trend endpoint (rescaled, as fit_seats_full.R does before the blend) ---------------
cycles <- load_election_cycles(); pri <- load_prior_results(); m <- pri$region == "vic" & pri$year == 2026
nowt <- trend_as_at(load_polls("vic"), 2026, cycles, Sys.Date(), setNames(pri$prev1[m], pri$party[m]),
                    flows_for(load_preference_flows(), 2026, "vic", quiet = TRUE))
lv <- nowt$fp * 100 / sum(nowt$fp); ed <- as.Date(unname(election_dates()["vic2026"]))
cat("\nPLB4  vic2026, trend endpoint rescaled to 100, then the blend (as of today):\n")
b <- level_recent_apply(lv, "vic2026", "vic", ed, code = "PLB4s", as_at = Sys.Date())
Sys.setenv(AUSPOL_LEVEL_RECENT_CLS = ARM)
a <- level_recent_apply(lv, "vic2026", "vic", ed, code = "PLB4a", tab = rbind(fread(out_path("level-recent.csv"))[, .(election, region, cls, trend, actual)],
                                                                            tab[tab$cls == "ONP"]), as_at = Sys.Date())
Sys.setenv(AUSPOL_LEVEL_RECENT_CLS = "ALP,LNP,GRN")
print(round(rbind(pre_blend = lv, shipped = b[names(lv)], arm = a[names(lv)]), 2))

# Screen for docs/plans/prereg-responsive-trend-2026-10-12.md: can the poll trend alone (blend off) give a
# day-before level as good as the shipped recent-poll blend?
# Arms: T0 today's trend; T1 sigmas="pooled_tf"; T2 walk multiplier m picked time-forward; T3 = T2 with firm-equal centring (cm*).
# Read-only except its cache, deciding-runs/trend-screen-cache.csv (gitignored).
# Run: powershell.exe -Command 'Rscript "scripts/screen_trend_responsive.R" [--only=vic2022] [--arms=T0,T1,T2]'
# Data.table NSE: masks are built outside [...]; no local shares a column name used inside brackets.
t0 <- Sys.time()
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
suppressMessages(library(data.table))
args <- commandArgs(TRUE)
getarg <- function(nm, dflt) { a <- grep(paste0("^--", nm, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nm, "="), "", a[1]) else dflt }
ONLY <- getarg("only", ""); ARMS <- strsplit(getarg("arms", "T0,T1,T2"), ",")[[1]]
MGRID <- c(1, 2, 4, 8, 16); HORIZ <- c(0, 7, 28, 90)   # h = 0: the statewide forecast's day-before level (what ships); 7/28/90: trend endpoint
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
Sys.setenv(AUSPOL_LEVEL_RECENT = "0")   # every arm is the trend alone; the incumbent's blend is applied separately below
C <- fread(out_path("candidacies.csv"), select = c("election", "party", "votes"), showProgress = FALSE)
share <- function(e) { .e <- e; x <- C[C$election == .e & is.finite(C$votes), list(v = sum(votes)), by = "party"]; setNames(100 * x$v / sum(x$v), x$party) }
PREV <- setNames(vapply(all_election_pairs(), function(p) p$prev, ""), vapply(all_election_pairs(), function(p) p$election, ""))
CACHE <- "deciding-runs/trend-screen-cache.csv"

tab <- fread(out_path("level-recent.csv"), showProgress = FALSE)
cycles <- load_election_cycles(); pri <- load_prior_results(); eds <- election_dates()
ELS <- setdiff(unique(tab$election), c("vic2026", "nsw2027"))
if (nzchar(ONLY)) ELS <- intersect(ELS, strsplit(ONLY, ",")[[1]])
cat(sprintf("RT0 %d elections; arms %s; walk grid %s; horizons %s days before\n", length(ELS),
            paste(ARMS, collapse = ","), paste(MGRID, collapse = ","), paste(HORIZ, collapse = ",")))
RW0 <- default_sigmas("logit")[["sigma_rw"]]

cache <- if (file.exists(CACHE)) fread(CACHE) else data.table(e = character(), arm = character(), h = integer(), k = character(), lev = numeric())
key_have <- paste(cache$e, cache$arm, cache$h)
polls_by_region <- list()
fit_one <- function(e, arm0, h) {
  arm <- sub("^c", "", arm0)   # "c" prefix = arm T3's firm-equal centring on top of the rest
  Sys.setenv(AUSPOL_TREND_SZC = if (startsWith(arm0, "c")) "firms" else "polls")
  on.exit(Sys.setenv(AUSPOL_TREND_SZC = "polls"), add = TRUE)
  region <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e)); ed <- as.Date(unname(eds[e]))
  if (is.null(polls_by_region[[region]])) polls_by_region[[region]] <<- suppressMessages(load_polls(region))
  polls <- polls_by_region[[region]]
  kp <- which(pri$region == region & pri$year == yr)
  priors <- setNames(pri$prev1[kp], pri$party[kp])
  cs <- min(cycles$start[cycles$region == region & cycles$year == yr])
  fl <- tryCatch(flows_for(load_preference_flows(), yr, region, as_of = cs, cycles = cycles, quiet = TRUE), error = function(z) NULL)
  if (h == 0) {   # same call as scripts/build_level_recent_table.R, with the arm's switches set
    Sys.setenv(AUSPOL_TREND_SIGMAS = if (arm == "T1") "pooled_tf" else "default",
               AUSPOL_TREND_RW_MULT = if (startsWith(arm, "m")) sub("^m", "", arm) else "1")
    sb <- share(e); fc <- NULL
    utils::capture.output(fc <- tryCatch(forecast_statewide_or_oracle(region, yr, ed, names(sb), share(PREV[[e]]), sb, code = "RT", n_sims = 20000L, seed = 42L, on_fail = "skip"),
                                         error = function(z) { cat("RT! ", e, arm, conditionMessage(z), "
"); NULL }))
    Sys.setenv(AUSPOL_TREND_SIGMAS = "default", AUSPOL_TREND_RW_MULT = "1")
    if (is.null(fc)) return(NULL)
    ks <- intersect(c("ALP", "LNP", "GRN", "ON", "OTH"), names(fc))
    return(data.table(e = e, arm = arm0, h = h, k = ks, lev = unname(fc[ks])))
  }
  extra <- list(); sg <- "default"
  if (arm == "T1") sg <- "pooled_tf"
  if (startsWith(arm, "m")) extra$sigma_rw <- as.numeric(sub("^m", "", arm)) * RW0
  tr <- tryCatch(suppressMessages(do.call(trend_as_at, c(list(polls, yr, cycles, ed - h, priors, fl, sigmas = sg), extra))),
                 error = function(z) { cat("RT! ", e, arm, h, conditionMessage(z), "\n"); NULL })
  if (is.null(tr)) return(NULL)
  ks <- intersect(c("ALP", "LNP", "GRN", "ON", "OTH"), names(tr$fp))
  data.table(e = e, arm = arm0, h = h, k = ks, lev = unname(tr$fp[ks]))
}
arm_ids <- c(if ("T0" %in% ARMS) "m1", if ("T1" %in% ARMS) "T1", if ("T2" %in% ARMS) paste0("m", MGRID[-1]))
if ("T3" %in% ARMS) arm_ids <- c(arm_ids, paste0("cm", MGRID))
arm_ids <- unique(arm_ids)
# profile one unit before the loop
todo <- CJ(e = ELS, arm = arm_ids, h = HORIZ)
todo <- todo[!paste(todo$e, todo$arm, todo$h) %in% key_have]
cat(sprintf("RT1 %d fits to run (%d cached)\n", nrow(todo), nrow(cache[, .N, by = .(e, arm, h)])))
new <- list()
for (i in seq_len(nrow(todo))) {
  ti <- Sys.time(); r <- fit_one(todo$e[i], todo$arm[i], todo$h[i])
  if (i == 1) cat(sprintf("RT1 one fit (%s %s h=%d): %.1f s\n", todo$e[i], todo$arm[i], todo$h[i], as.numeric(Sys.time() - ti, units = "secs")))
  if (!is.null(r)) new[[length(new) + 1]] <- r
  if (i %% 25 == 0 || i == nrow(todo)) {
    cache <- rbind(cache, rbindlist(new)); new <- list(); fwrite(cache, CACHE)
    cat(sprintf("RT1 %d/%d fits, %.0f s\n", i, nrow(todo), as.numeric(Sys.time() - t0, units = "secs")))
  }
}
L <- cache[cache$e %in% ELS]

# actuals and the incumbent (shipped blend, decay 20) from level-recent.csv, day-before only
Sys.setenv(AUSPOL_LEVEL_RECENT = "decay", AUSPOL_LEVEL_RECENT_HALFLIFE = "20")
inc <- list()
for (e0 in ELS) {
  d <- tab[tab$election == e0]; lv <- setNames(d$trend, d$cls)
  if (any(!is.finite(lv[c("ALP", "LNP", "GRN")]))) next
  lv <- c(lv[c("ALP", "LNP", "GRN")], OTH = 100 - sum(lv[c("ALP", "LNP", "GRN")]))
  invisible(capture.output(res <- suppressWarnings(level_recent_apply(lv, e0, d$region[1], as.Date(unname(eds[e0])), code = "RT", tab = tab))))
  inc[[e0]] <- data.table(e = e0, k = c("ALP", "LNP", "GRN"), inc = unname(res[c("ALP", "LNP", "GRN")]), actual = d$actual[match(c("ALP", "LNP", "GRN"), d$cls)])
}
INC <- rbindlist(inc)[is.finite(actual)]
cat(sprintf("RT2 incumbent cells %d / %d elections (applies AUSPOL_LEVEL_RECENT=%s HL=%s)\n", nrow(INC), uniqueN(INC$e),
            Sys.getenv("AUSPOL_LEVEL_RECENT"), Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE")))
# sanity: cached T0 day-before must equal level-recent.csv's trend column (same code, same inputs)
chk <- merge(L[L$arm == "m1" & L$h == 0, .(e, k, lev)], tab[, .(e = election, k = cls, trend)], by = c("e", "k"))
cat(sprintf("RT2 T0 vs level-recent.csv trend: %d cells, max |diff| %.4f (expect ~0)\n", nrow(chk), max(abs(chk$lev - chk$trend))))

wide <- function(hh) {   # e, k, actual, inc, and one column per arm at horizon hh
  W <- dcast(L[L$h == hh & L$k %in% c("ALP", "LNP", "GRN")], e + k ~ arm, value.var = "lev")
  merge(INC, W, by = c("e", "k"))
}
rmse <- function(x, a) sqrt(mean((x - a)^2))
jk <- function(D, a, b) {
  m0 <- is.finite(D[[a]]) & is.finite(D[[b]]); D <- D[m0]
  full <- rmse(D[[a]], D$actual) - rmse(D[[b]], D$actual); els <- unique(D$e); G <- length(els)
  th <- vapply(els, function(x) { m <- D$e != x; rmse(D[[a]][m], D$actual[m]) - rmse(D[[b]][m], D$actual[m]) }, 0)
  per <- vapply(els, function(x) { m <- D$e == x; sum((D[[a]][m] - D$actual[m])^2) - sum((D[[b]][m] - D$actual[m])^2) }, 0)
  list(diff = full, se = sqrt((G - 1) / G * sum((th - mean(th))^2)), n = nrow(D), G = G, per = per)
}

# T2: per target, m chosen by day-before RMSE over elections whose polling day < target cycle start
D1 <- wide(0)
pick_for <- function(pfx) { mcols <- paste0(pfx, MGRID)
 rbindlist(lapply(unique(D1$e), function(x) {
  rg <- sub("[0-9]{4}$", "", x); yr <- as.integer(sub("^[a-z]+", "", x))
  cs <- min(cycles$start[cycles$region == rg & cycles$year == yr])
  past <- unique(D1$e)[as.Date(unname(eds[unique(D1$e)])) < cs]
  stopifnot(all(as.Date(unname(eds[past])) < cs))   # leakage assertion
  Dp <- D1[D1$e %in% past]
  nmiss <- vapply(mcols, function(cc) sum(!is.finite(Dp[[cc]])), 0L)
  if (any(nmiss > 0)) cat(sprintf("RT3! %s: past cells missing per grid point: %s (scored on what is there)
", x, paste(nmiss, collapse = ",")))
  m <- if (length(past) < 3) 1 else MGRID[which.min(vapply(mcols, function(cc) { ok <- is.finite(Dp[[cc]]); rmse(Dp[[cc]][ok], Dp$actual[ok]) }, 0))]
  data.table(e = x, m_pick = m, n_past = length(past))
})) }
pick <- pick_for("m")
if ("cm1" %in% names(D1)) { pc <- pick_for("cm"); setnames(pc, "m_pick", "cm_pick"); pick <- merge(pick, pc[, .(e, cm_pick)], by = "e") }
cat("RT3 T2 walk multiplier picked per target (time-forward):\n"); print(pick[order(as.Date(unname(eds[e])))])
for (hh in HORIZ) {
  Dh <- wide(hh); Dh <- merge(Dh, pick, by = "e")
  Dh[, T2 := NA_real_]
  for (mm in MGRID) { sel <- Dh$m_pick == mm; Dh$T2[sel] <- Dh[[paste0("m", mm)]][sel] }
  Dh[, T0 := m1]
  if ("cm_pick" %in% names(Dh) && "cm1" %in% names(Dh)) { Dh[, T3 := NA_real_]
    for (mm in MGRID) { sel <- Dh$cm_pick == mm; Dh$T3[sel] <- Dh[[paste0("cm", mm)]][sel] } }
  arms_here <- intersect(c("T1", "T2", "T3", "cm1"), names(Dh))
  cat(sprintf("\nRT4 horizon %d day(s) before: RMSE vs actual (points, lower better), %d cells / %d elections\n", hh, nrow(Dh), uniqueN(Dh$e)))
  for (cc in c("T0", arms_here, if (hh == 0) c("inc", paste0("m", MGRID), paste0("cm", MGRID)))) if (cc %in% names(Dh)) cat(sprintf("     %-4s %.3f\n", cc, rmse(Dh[[cc]][is.finite(Dh[[cc]])], Dh$actual[is.finite(Dh[[cc]])])))
  for (a in arms_here) {
    r0 <- jk(Dh, a, "T0")
    cat(sprintf("     %s - T0: %+.3f (SE %.3f)%s", a, r0$diff, r0$se,
                if (r0$diff < 0) sprintf("; largest single-election share of the gain %.0f%%", 100 * max(-r0$per[r0$per < 0]) / sum(-r0$per[r0$per < 0])) else ""))
    if (hh == 0) { ri <- jk(Dh, a, "inc"); cat(sprintf(" | %s - shipped: %+.3f (SE %.3f)", a, ri$diff, ri$se)) }
    cat("\n")
  }
  if (hh == 0) {
    cat("RT5 dry runs (day-before):\n")
    for (q in list(c("vic2022", "LNP"), c("sa2026", "ALP"), c("fed2019", "LNP"))) {
      rr <- Dh[Dh$e == q[1] & Dh$k == q[2]]
      if (nrow(rr)) cat(sprintf("     %s %s: T0 %.1f | T1 %s | T2 %s (m=%s) | shipped %.1f | actual %.1f\n", q[1], q[2], rr$T0,
                                if ("T1" %in% names(rr)) sprintf("%.1f", rr$T1) else "-", sprintf("%.1f", rr$T2), rr$m_pick, rr$inc, rr$actual))
      if (nrow(rr) && "T3" %in% names(rr)) cat(sprintf("       T3 %.1f (m=%s) | centring alone (cm1) %.1f
", rr$T3, rr$cm_pick, rr$cm1))
    }
  }
}
oth <- dcast(L[L$h == 0 & L$k %in% c("ON", "OTH")], e + k ~ arm, value.var = "lev")
if (nrow(oth)) for (a in intersect(c("T1", paste0("m", MGRID[-1]), paste0("cm", MGRID)), names(oth)))
  cat(sprintf("RT6 ON/OTH day-before max |%s - T0| %.2f points (report only)\n", a, max(abs(oth[[a]] - oth$m1), na.rm = TRUE)))
cat(sprintf("RT9 done in %.0f s\n", as.numeric(Sys.time() - t0, units = "secs")))

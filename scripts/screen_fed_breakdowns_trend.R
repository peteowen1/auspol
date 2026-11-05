# Statewide-level screen for federal polls' state breakdowns INSIDE the state trend
# (docs/plans/prereg-fed-breakdowns-in-trend-2026-10-26.md, Amendment 1 governs the decision rule).
#
#   powershell.exe -Command 'Rscript "scripts/screen_fed_breakdowns_trend.R" [--budget=8] [--cache=DIR]'
#
# Scores the PUBLISHED statewide level -- forecast_statewide_for() (the published path: trend as at the date, the
# live level recipe, the bucket split) then the shipped recent-poll blend (level_recent_apply(), k refitted on a
# level-recent table whose trend column is rebuilt under each arm) -- on the seven targets:
#   primary  day-before level RMSE (ALP, LNP, GRN, ONP wherever the state trend fits the class)
#   H        pooled RMSE of the level the forecast would have published 90 and 180 days out (Amendment 1)
# Arms B0 B1 B2 B3 and diagnostics B-eq, B2-noblend, B2-wide20. Paired against B0, SE = delete-one-election
# jackknife over the elections present. Runs the prereg's dry runs and mechanism checks first.
#
# Every fit is cached (one RDS per arm/target/horizon in --cache, default %TEMP%/fedbd/screen-cache), so a run
# stopped by --budget (minutes of new fits; default 8) resumes where it stopped. Writes nothing to output/.
# Data.table NSE: no local variable shares a column name inside [...]. Emits FB* codes.

t_start <- Sys.time()
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
suppressMessages(library(data.table))
args <- commandArgs(TRUE)
getarg <- function(nm, dflt) { a <- grep(paste0("^--", nm, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nm, "="), "", a[1]) else dflt }
BUDGET <- as.numeric(getarg("budget", "8"))
CACHE <- getarg("cache", file.path(Sys.getenv("TEMP", tempdir()), "fedbd", "screen-cache"))
dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)
if (startsWith(normalizePath(CACHE, winslash = "/", mustWork = FALSE), normalizePath(out_path(), winslash = "/", mustWork = FALSE)))
  stop("FB0! cache inside output/")
stopifnot(Sys.getenv("AUSPOL_TREND_FED_R") == "0", Sys.getenv("AUSPOL_LEVEL_RECENT") == "decay",
          Sys.getenv("AUSPOL_LEVEL_FED_R") == "0.15", Sys.getenv("AUSPOL_LEVEL_RECIPE") == "live")

TARGETS <- c("qld2020", "sa2022", "vic2022", "nsw2023", "qld2024", "wa2025", "sa2026")
HZ <- c(1L, 30L, 90L, 180L)
MAIN <- c("ALP", "LNP", "GRN", "ONP")
R_GRID <- c(0, 0.05, 0.1, 0.15, 0.25, 0.5, 1)
eds <- election_dates()
prs <- all_election_pairs(); PREV <- setNames(vapply(prs, `[[`, "", "prev"), vapply(prs, `[[`, "", "election"))
ALL <- names(PREV)
Cc <- fread(out_path("candidacies.csv"), select = c("election", "party", "votes"), showProgress = FALSE)
share <- function(e) { .e <- e; x <- Cc[Cc$election == .e & is.finite(Cc$votes), list(v = sum(votes)), by = "party"]; setNames(100 * x$v / sum(x$v), x$party) }
TAB0 <- fread(out_path("level-recent.csv"), showProgress = FALSE)
cat(sprintf("FB0  level-recent table %d rows / %d elections (modified %s); cache %s; budget %.0f min of new fits\n",
            nrow(TAB0), uniqueN(TAB0$election), format(file.info(out_path("level-recent.csv"))$mtime), CACHE, BUDGET))

# ---- arms: the trend switches (blend switches separately) -------------------------------------------------------
TREND_ENV <- function(r, src = "full", nn = "1", psd = "10")
  c(AUSPOL_TREND_FED_R = format(r), AUSPOL_TREND_FED_SRC = src, AUSPOL_TREND_FED_N = nn, AUSPOL_TREND_FED_PRIOR_SD = psd)
TR <- list(B0 = TREND_ENV(0, "shipped", "0"),
           B1 = TREND_ENV(0.15, "shipped", "0"),
           B2 = TREND_ENV(0.15, "full", "1"),
           Beq = TREND_ENV(1, "full", "0", "0.5"),
           wide20 = TREND_ENV(0.15, "full", "1", "20"))
for (r in setdiff(R_GRID, c(0, 0.15))) TR[[sprintf("B2r%s", format(r))]] <- TREND_ENV(r, "full", "1")
trend_key <- function(env) if (as.numeric(env[["AUSPOL_TREND_FED_R"]]) == 0) "B0" else paste(env, collapse = "_")

# ---- one fit: the published path, unblended, as at ed - h ----------------------------------------------------------
fund_memo <- new.env()
n_new <- 0L
over_budget <- function() as.numeric(difftime(Sys.time(), t_start, units = "mins")) > BUDGET
unblended <- function(env, e, h, live_asat = NULL) {
  key <- sprintf("%s__%s__%s", gsub("[^A-Za-z0-9.]", "-", trend_key(env)), e, if (is.null(live_asat)) h else paste0("live", format(live_asat)))
  f <- file.path(CACHE, paste0(key, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  if (over_budget()) return(structure(list(pending = TRUE), class = "pending"))
  rg <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e)); ed <- as.Date(unname(eds[e]))
  aa <- if (is.null(live_asat)) ed - h else live_asat
  prev <- if (e %in% names(PREV)) PREV[[e]] else c(vic2026 = "vic2022", nsw2027 = "nsw2023")[[e]]
  sa <- share(prev); sb <- if (is.null(live_asat)) share(e) else sa
  old <- Sys.getenv(names(env), unset = NA); do.call(Sys.setenv, as.list(env)); on.exit({
    for (k in names(old)) if (is.na(old[[k]])) Sys.unsetenv(k) else do.call(Sys.setenv, setNames(list(old[[k]]), k)) }, add = TRUE)
  fk <- paste(rg, yr)
  if (is.null(fund_memo[[fk]])) assign(fk, list(f = data.table(year = yr, region = rg, fund = tryCatch(fundamentals_tf(rg, yr), error = function(err) NA_real_)),
                                                m = tryCatch(projection_mix_tf(rg, yr), error = function(err) NULL)), envir = fund_memo)
  fm <- fund_memo[[fk]]
  if (!is.null(live_asat) && !is.finite(fm$f$fund)) {
    # live only: the fundamentals cannot be fitted for an election not yet held in some cycles; under the live
    # level recipe (LR1) the projection never reaches the level, so a placeholder changes nothing (asserted below)
    fm$f$fund <- 50; cat(sprintf("FB12 %s: no time-forward fundamentals; placeholder 50 (unused under the live recipe, LR1)\n", e))
  }
  fed_tab <- tryCatch(trend_fed_for_cycle(rg, yr, aa), error = function(err) err)
  t0 <- Sys.time()
  lg <- utils::capture.output(fc <- tryCatch(
    forecast_statewide_for(rg, yr, ed, names(sb), sa, fm$f, fm$m, n_sims = 20000L, seed = 42L, as_at = aa),
    error = function(err) err))
  out <- if (inherits(fc, "error")) list(ok = FALSE, why = conditionMessage(fc), log = lg) else {
    keep <- intersect(names(fc$st_fc), names(sb))
    list(ok = TRUE, lv = fc$st_fc[keep], folded = fc$folded, n_polls = fc$n_polls, fed = fc$fed_effects, n_fed = fc$n_fed,
         log = lg, fed_tab = if (inherits(fed_tab, "error")) NULL else fed_tab)
  }
  out$e <- e; out$h <- h; out$as_at <- aa; out$env <- env; out$secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(out, f); n_new <<- n_new + 1L
  out
}
pending <- function(x) inherits(x, "pending")

# ---- the arm's level-recent table, then the published (blended) level -----------------------------------------
arm_table <- function(trend_of) {        # trend_of: election -> unblended day-before fit for the 7 targets
  tb <- copy(TAB0)
  for (e in names(trend_of)) {
    u <- trend_of[[e]]; if (pending(u) || !isTRUE(u$ok)) next
    for (k in c("ALP", "LNP", "GRN")) {
      ix <- which(tb$election == e & tb$cls == k)
      if (length(ix) == 1L && k %in% names(u$lv)) tb$trend[ix] <- unname(u$lv[[k]])
    }
  }
  tb
}
blend <- function(u, e, tb, blend_env = c(AUSPOL_LEVEL_FED_R = "0.15")) {
  if (pending(u) || !isTRUE(u$ok)) return(NULL)
  old <- setNames(Sys.getenv(names(blend_env)), names(blend_env)); do.call(Sys.setenv, as.list(blend_env)); on.exit(do.call(Sys.setenv, as.list(old)), add = TRUE)
  rg <- sub("[0-9]{4}$", "", e); ed <- as.Date(unname(eds[e]))
  lg <- utils::capture.output(v <- level_recent_apply(u$lv, e, rg, ed, code = "FBr", tab = tb, as_at = u$as_at))
  attr(v, "log") <- lg
  v
}
fitted_cls <- function(u) setdiff(intersect(MAIN, names(u$lv)), u$folded)

# ---- scoring -------------------------------------------------------------------------------------------------------
ACT <- setNames(lapply(TARGETS, share), TARGETS)
cells <- function(levels, base_fits) {   # levels: election -> named vector; cells from B0's fitted classes
  rbindlist(lapply(names(levels), function(e) {
    v <- levels[[e]]; if (is.null(v)) return(NULL)
    cl <- fitted_cls(base_fits[[e]])
    a <- ACT[[e]]
    data.table(election = e, cls = cl, pred = unname(v[cl]), act = unname(ifelse(cl %in% names(a), a[cl], 0)))
  }))
}
rmse <- function(d) sqrt(mean((d$pred - d$act)^2))
paired <- function(arm, base) {          # arm/base: cell tables on the same cells
  m <- merge(arm, base, by = c("election", "cls"), suffixes = c("", ".b"))
  stopifnot(nrow(m) == nrow(base), all(abs(m$act - m$act.b) < 1e-12))
  D <- function(x) sqrt(mean((x$pred - x$act)^2)) - sqrt(mean((x$pred.b - x$act)^2))
  els <- unique(m$election); G <- length(els)
  jk <- vapply(els, function(g) D(m[m$election != g]), 0)
  se <- if (G > 1) sqrt((G - 1) / G * sum((jk - mean(jk))^2)) else NA_real_
  list(d = D(m), se = se, G = G, n = nrow(m), rmse_arm = sqrt(mean((m$pred - m$act)^2)), rmse_b0 = sqrt(mean((m$pred.b - m$act)^2)),
       rms_move = sqrt(mean((m$pred - m$pred.b)^2)), toward = sum(abs(m$pred - m$act) < abs(m$pred.b - m$act) - 1e-12),
       away = sum(abs(m$pred - m$act) > abs(m$pred.b - m$act) + 1e-12), m = m)
}
verdict <- function(p, h) {              # Amendment 1
  pw <- p$d > p$se; hw <- isTRUE(h$d > h$se)
  pb <- p$d < -p$se; hb <- isTRUE(h$d < -h$se)
  if (pw || hw) "FAIL" else if (pb || hb) "PASS" else "TIE"
}
verdict_orig <- function(d, se) if (d < -se) "PASS" else if (d > se) "FAIL" else "TIE"

# ---- dry run 1: the decision rule on known answers (no fitting) ------------------------------------------------------
cat("\nFB1  dry run 1, the rule on known answers (change, SE; positive = worse):\n")
dr <- list(list("blend F1 r=0.15", 0.034, 0.036, NULL, "TIE (Pete shipped on preference)"),
           list("blend r=1", 0.303, 0.248, NULL, "FAIL"), list("blend r=0.05", 0.010, 0.012, NULL, "TIE"),
           list("responsive T2", -0.163, 0.082, c(0.252, 0.162), "FAIL (refused on its 90-day guard)"),
           list("responsive T1", -0.079, 0.040, c(0.017, 0.046), "PASS on the primary, H within 1 SE"))
for (x in dr) {
  v <- if (is.null(x[[4]])) verdict_orig(x[[2]], x[[3]]) else verdict(list(d = x[[2]], se = x[[3]]), list(d = x[[4]][1], se = x[[4]][2]))
  cat(sprintf("     %-16s %+.3f (%.3f)%s -> %s; known answer %s\n", x[[1]], x[[2]], x[[3]],
              if (is.null(x[[4]])) "" else sprintf(", H %+.3f (%.3f)", x[[4]][1], x[[4]][2]), v, x[[5]]))
}

# ---- fits ----------------------------------------------------------------------------------------------------------
run_arm <- function(nm, hz = HZ, els = TARGETS) setNames(lapply(els, function(e) setNames(lapply(hz, function(h) unblended(TR[[nm]], e, h)), hz)), els)
FITS <- list()
for (nm in c("B0", "B1", "B2", "Beq", "wide20")) FITS[[nm]] <- run_arm(nm)
# B3's grid: the day before only (r is picked on the primary)
for (r in setdiff(R_GRID, c(0, 0.15))) FITS[[sprintf("B2r%s", format(r))]] <- run_arm(sprintf("B2r%s", format(r)), hz = 1L)
# mechanism: every non-target election, B1 and B2, day before (must equal B0 exactly)
NONT <- setdiff(ALL, TARGETS)
NT <- list()
for (nm in c("B0", "B1", "B2")) NT[[nm]] <- setNames(lapply(NONT, function(e) unblended(TR[[nm]], e, 1L)), NONT)
all_fits <- c(unlist(lapply(FITS, function(a) unlist(a, recursive = FALSE)), recursive = FALSE), unlist(NT, recursive = FALSE))
n_pend <- sum(vapply(all_fits, pending, TRUE))
cat(sprintf("\nFB2  fits: %d computed this run, %d pending (budget reached); %.1f min so far\n", n_new, n_pend,
            as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
if (n_pend) { cat("FB2  re-run to continue; the cache keeps every finished fit.\n"); quit(save = "no", status = 0) }
d1 <- function(nm) lapply(FITS[[nm]], `[[`, "1")

# ---- what every arm applied -----------------------------------------------------------------------------------------
cat("\nFB3  what each arm applied (switches; per target: breakdowns admitted to the day-before fit, newest fieldwork end, sample size source)\n")
for (nm in c("B0", "B1", "B2", "Beq", "wide20")) {
  cat(sprintf("     %-7s %s\n", nm, paste(sprintf("%s=%s", names(TR[[nm]]), TR[[nm]]), collapse = " ")))
  if (nm == "B0") next
  for (e in TARGETS) {
    u <- FITS[[nm]][[e]][["1"]]; ft <- u$fed_tab
    how <- if (!is.null(ft)) paste(sprintf("%s %d", names(table(ft$n_how)), table(ft$n_how)), collapse = ", ") else "-"
    cat(sprintf("       %s: %s rows admitted (%s), newest end %s; n: %s\n", e, if (is.null(u$n_fed)) 0L else u$n_fed,
                if (is.null(ft)) "none" else paste(sprintf("%s %d", MAIN, vapply(MAIN, function(k) sum(is.finite(ft[[k]])), 1L)), collapse = " "),
                if (is.null(ft)) "-" else format(max(ft$end)), how))
  }
}
cat("     B2-noblend = B2's trend with AUSPOL_LEVEL_FED_R=0 in the blend (its table and k refitted under it)\n")
# components that ran: the live level recipe drops the projection mix (LR1), so the mix never reaches the level
lr1 <- vapply(all_fits, function(u) isTRUE(u$ok) && any(grepl("^LR1 ", u$log)), TRUE)
okn <- vapply(all_fits, function(u) isTRUE(u$ok), TRUE)
cat(sprintf("FB3  components: trend fitted in %d of %d fits; LR1 (live recipe: level NOT anchored to the projection mix) printed in %d of those, so the fundamentals mix and output/projection-data.csv never reach the level; thin-cycle fits (no trend as at the date) %d\n",
            sum(okn), length(okn), sum(lr1 & okn), sum(!okn)))
if (any(okn & !lr1)) stop("FB3! a fit ran without the live recipe: the projection mix would reach the level and projection-data.csv would need rebuilding")
for (e in TARGETS) for (h in HZ) {
  u <- FITS$B0[[e]][[as.character(h)]]
  if (!isTRUE(u$ok)) cat(sprintf("FB3  %s %3d days out: NO trend as at %s (%s) -- the published path there is the thin-cycle estimate, which cannot be computed as at a horizon (it reads every poll before polling day); excluded from H in every arm, which the arm cannot reach anyway\n",
                                  e, h, format(u$as_at), sub("\\..*", "", u$why)))
}

# ---- mechanism checks -----------------------------------------------------------------------------------------------
cat("\nFB4  mechanism checks\n")
bad <- character(0)
# AMENDMENT 2 (prereg): the prereg listed wa2021 as unreachable ("the cycle has no trend at all ... takes the
# thin-cycle path"). On today's poll set its trend fits the day before, so the arm reaches it. It is reported
# separately below and NOT scored (the registered seven stay the seven); every other non-target must be identical.
REACHED <- "wa2021"
for (e in REACHED) for (nm in c("B1", "B2")) {
  a <- NT[[nm]][[e]]; b <- NT$B0[[e]]
  if (isTRUE(a$ok) && isTRUE(b$ok)) {
    cl <- fitted_cls(b); act <- share(e)
    cat(sprintf("FB4  %s (prereg: unreachable; Amendment 2: reached, reported, not scored) %s: %d breakdowns admitted, %d state polls; unblended day-before %s\n",
                e, nm, if (is.null(a$n_fed)) 0L else a$n_fed, a$n_polls,
                paste(sprintf("%s %.2f->%.2f (act %.2f)", cl, b$lv[cl], a$lv[cl], act[cl]), collapse = ", ")))
  } else cat(sprintf("FB4  %s %s: trend ok B0 %s, arm %s\n", e, nm, isTRUE(b$ok), isTRUE(a$ok)))
}
for (nm in c("B1", "B2")) for (e in setdiff(NONT, REACHED)) {
  a <- NT[[nm]][[e]]; b <- NT$B0[[e]]
  same <- identical(a$ok, b$ok) && (!isTRUE(a$ok) || identical(a$lv, b$lv))
  if (!same) bad <- c(bad, paste(nm, e))
  if (!is.null(a$n_fed) && a$n_fed > 0) bad <- c(bad, paste(nm, e, "admitted breakdowns"))
}
cat(sprintf("FB4  (a) %d non-target elections x B1, B2: day-before level identical to B0 in %d of %d (federal pairs included: %s)%s\n",
            length(NONT) - length(REACHED), 2L * (length(NONT) - length(REACHED)) - length(bad), 2L * (length(NONT) - length(REACHED)), paste(grep("^fed", NONT, value = TRUE), collapse = ","),
            if (length(bad)) paste0(" -- DIFFER: ", paste(bad, collapse = "; ")) else ""))
if (length(bad)) stop("FB4! a non-target level moved: bug, not result")
# the check can fail: B0 vs a target with breakdowns
cat(sprintf("FB4      (control: the same comparison on vic2022 B2 vs B0 reports identical = %s; must be FALSE)\n",
            identical(FITS$B2$vic2022[["1"]]$lv, FITS$B0$vic2022[["1"]]$lv)))
for (nm in c("B1", "B2", "Beq", "wide20")) {
  mv <- unlist(lapply(TARGETS, function(e) { a <- FITS[[nm]][[e]][["1"]]; b <- FITS$B0[[e]][["1"]]; if (!isTRUE(a$ok)) return(NULL); cl <- fitted_cls(b); abs(a$lv[cl] - b$lv[cl]) }))
  mh <- unlist(lapply(TARGETS, function(e) lapply(c("90", "180"), function(h) { a <- FITS[[nm]][[e]][[h]]; b <- FITS$B0[[e]][[h]]; if (!isTRUE(a$ok) || !isTRUE(b$ok)) return(NULL); cl <- fitted_cls(b); abs(a$lv[cl] - b$lv[cl]) })))
  cat(sprintf("FB4  (b) %-6s unblended day-before level: largest move %.3f pts over %d cells (> 0.05 needed: %s); 90/180 days: largest %.3f over %d cells (%s)\n",
              nm, max(mv), length(mv), max(mv) > 0.05, if (length(mh)) max(mh) else NA, length(mh), isTRUE(max(mh) > 0.05)))
  if (!(max(mv) > 0.05) || !isTRUE(max(mh) > 0.05)) stop("FB4! the breakdowns never reached the fit for ", nm)
}
lat <- unlist(lapply(all_fits, function(u) if (is.null(u$fed_tab)) NULL else as.numeric(u$as_at - max(u$fed_tab$end))))
cat(sprintf("FB4  (c) admitted breakdowns end before the as-at date in every fit: smallest gap %d day(s) over %d fits with breakdowns (asserted in code too)\n",
            as.integer(min(lat)), length(lat)))
if (min(lat) < 1) stop("FB4! a breakdown ended on or after its as-at date")
cat("FB4  (d) the class gate: the fitted class set is the same in every arm at every horizon: ")
gate_bad <- character(0)
for (nm in setdiff(names(FITS), grep("^B2r", names(FITS), value = TRUE))) for (e in TARGETS) for (h in as.character(HZ)) {
  a <- FITS[[nm]][[e]][[h]]; b <- FITS$B0[[e]][[h]]
  if (!identical(isTRUE(a$ok), isTRUE(b$ok)) || (isTRUE(a$ok) && !identical(sort(fitted_cls(a)), sort(fitted_cls(b)))))
    gate_bad <- c(gate_bad, sprintf("%s %s %s (ok %s/%s; %s | %s)", nm, e, h, isTRUE(a$ok), isTRUE(b$ok),
                                    paste(fitted_cls(a), collapse = ","), paste(fitted_cls(b), collapse = ",")))
}
cat(!length(gate_bad), "\n"); if (length(gate_bad)) { cat(gate_bad, sep = "\n"); stop("FB4! breakdowns created or removed a class") }
# B0 against the shipped table: the rebuilt unblended day-before level should equal level-recent.csv's trend column
b0d <- rbindlist(lapply(TARGETS, function(e) { u <- FITS$B0[[e]][["1"]]; if (!isTRUE(u$ok)) return(NULL)
  data.table(election = e, cls = intersect(c("ALP", "LNP", "GRN"), names(u$lv)), now = unname(u$lv[intersect(c("ALP", "LNP", "GRN"), names(u$lv))])) }))
b0d <- merge(b0d, TAB0[, list(election, cls, trend)], by = c("election", "cls"))
cat(sprintf("FB4  (e) B0 rebuilt against output/level-recent.csv's trend column: max |diff| %.2e over %d cells (non-zero means the inputs moved since 1 Nov, and the arm's table is rebuilt from B0 here anyway)\n",
            max(abs(b0d$now - b0d$trend)), nrow(b0d)))

# ---- dry run 2: the offset must hold the level -----------------------------------------------------------------------
cat("\nFB5  dry run 2, the offset holds the level (unblended day-before, points):\n")
for (nm in c("B1", "B2")) {
  a <- FITS[[nm]]$wa2025[["1"]]$lv[["ALP"]]; b <- FITS$B0$wa2025[["1"]]$lv[["ALP"]]
  cat(sprintf("     %s wa2025 ALP: B0 %.2f, arm %.2f, move %+.2f (must be under 1 point; a fall toward 34 is a failed offset)\n", nm, b, a, a - b))
  if (abs(a - b) >= 1) stop("FB5! the offset did not hold wa2025 ALP under ", nm)
}

# ---- tables and published levels per arm ------------------------------------------------------------------------------
pub_levels <- function(trend_fits_d1, fits_h, blend_env = c(AUSPOL_LEVEL_FED_R = "0.15")) {
  tb <- arm_table(trend_fits_d1)
  setNames(lapply(as.character(HZ), function(h) setNames(lapply(TARGETS, function(e) blend(fits_h[[e]][[h]], e, tb, blend_env)), TARGETS)), as.character(HZ))
}
LV <- list()
for (nm in c("B0", "B1", "B2", "Beq", "wide20")) LV[[nm]] <- pub_levels(d1(nm), FITS[[nm]])
LV[["B2-noblend"]] <- pub_levels(d1("B2"), FITS$B2, c(AUSPOL_LEVEL_FED_R = "0"))
LV[["B0-noblend"]] <- pub_levels(d1("B0"), FITS$B0, c(AUSPOL_LEVEL_FED_R = "0"))   # B2-noblend's own control (reported)

# ---- B3: r fitted time-forward on the primary, shrunk toward 0.15 -------------------------------------------------------
grid_lv <- list()
for (r in R_GRID) {
  nm <- if (r == 0) "B0" else if (r == 0.15) "B2" else sprintf("B2r%s", format(r))
  grid_lv[[format(r)]] <- pub_levels(d1(nm), lapply(FITS[[nm]], function(x) x["1"]))[["1"]]
}
B0d1 <- d1("B0")
sqerr <- rbindlist(lapply(names(grid_lv), function(r) cells(grid_lv[[r]], B0d1)[, r := as.numeric(r)][]))
sqerr[, se2 := (pred - act)^2]
pick_r <- function(as_at) {
  used <- TARGETS[as.Date(unname(eds[TARGETS])) < as_at]
  stopifnot(all(as.Date(unname(eds[used])) < as_at))
  m <- length(used)
  if (!m) return(list(r = 0.15, r_hat = NA_real_, m = 0L, used = character(0)))
  s <- sqerr[sqerr$election %in% used, list(sse = sum(se2)), by = "r"]
  r_hat <- s$r[which.min(s$sse)]
  list(r = (m * r_hat + 3 * 0.15) / (m + 3), r_hat = r_hat, m = m, used = used)
}
B3R <- rbindlist(lapply(TARGETS, function(e) rbindlist(lapply(HZ, function(h) {
  p <- pick_r(as.Date(unname(eds[e])) - h)
  data.table(election = e, h = h, r = p$r, r_hat = p$r_hat, m = p$m, used = paste(p$used, collapse = ","))
}))))
cat("\nFB6  B3: r picked time-forward (primary squared error over targets whose polling day is before the as-at date), shrunk (m r_hat + 3 x 0.15)/(m + 3)\n")
print(B3R[B3R$h %in% c(1L, 90L, 180L)], row.names = FALSE)
FITS$B3 <- setNames(lapply(TARGETS, function(e) setNames(lapply(HZ, function(h) {
  rr <- B3R$r[B3R$election == e & B3R$h == h]
  unblended(TREND_ENV(rr, "full", "1"), e, h) }), HZ)), TARGETS)
if (any(vapply(unlist(FITS$B3, recursive = FALSE), pending, TRUE))) { cat("FB6  B3 fits pending; re-run to continue\n"); quit(save = "no", status = 0) }
LV$B3 <- pub_levels(d1("B3"), FITS$B3)

# ---- scores ---------------------------------------------------------------------------------------------------------
score <- function(nm, base = "B0") {
  pc <- cells(LV[[nm]][["1"]], B0d1); pb <- cells(LV[[base]][["1"]], B0d1)
  hc <- rbindlist(lapply(c("90", "180"), function(h) { b0h <- lapply(FITS$B0, `[[`, h); x <- cells(LV[[nm]][[h]], b0h); if (!is.null(x) && nrow(x)) x[, election := paste0(election, "")][, hz := h][] }))
  hb <- rbindlist(lapply(c("90", "180"), function(h) { b0h <- lapply(FITS$B0, `[[`, h); x <- cells(LV[[base]][[h]], b0h); if (!is.null(x) && nrow(x)) x[, hz := h][] }))
  hc[, cls := paste(cls, hz)]; hb[, cls := paste(cls, hz)]
  p <- paired(pc, pb); hh <- paired(hc[, list(election, cls, pred, act)], hb[, list(election, cls, pred, act)])
  h90 <- paired(hc[hc$hz == "90", list(election, cls, pred, act)], hb[hb$hz == "90", list(election, cls, pred, act)])
  h180 <- paired(hc[hc$hz == "180", list(election, cls, pred, act)], hb[hb$hz == "180", list(election, cls, pred, act)])
  h30 <- paired(cells(LV[[nm]][["30"]], lapply(FITS$B0, `[[`, "30")), cells(LV[[base]][["30"]], lapply(FITS$B0, `[[`, "30")))
  list(p = p, h = hh, h90 = h90, h180 = h180, h30 = h30, v = verdict(p, hh))
}
S <- list(); for (nm in c("B1", "B2", "B3", "Beq", "B2-noblend", "wide20")) S[[nm]] <- score(nm, if (nm == "B2-noblend") "B0-noblend" else "B0")
S[["B2-noblend vs B0"]] <- score("B2-noblend", "B0")

pc0 <- cells(LV$B0[["1"]], B0d1)
cat(sprintf("\nFB7  cells: primary %d (%s); B0 primary RMSE %.3f pts\n", nrow(pc0),
            paste(sprintf("%s %s", pc0[, .N, by = "election"]$election, pc0[, .N, by = "election"]$N), collapse = ", "), rmse(pc0)))
cat(sprintf("FB7  H cells: 90 days %d over %s; 180 days %d over %s\n", S$B1$h90$n, paste(unique(S$B1$h90$m$election), collapse = ","),
            S$B1$h180$n, paste(unique(S$B1$h180$m$election), collapse = ",")))

# ---- size check -------------------------------------------------------------------------------------------------------
sz <- S$B1
cat(sprintf("\nFB8  size check (B1): primary RMS move %.4f vs 1.84 SE = %.4f (SE %.4f) -> %s; H RMS move %.4f vs 1.84 SE = %.4f (SE %.4f) -> %s\n",
            sz$p$rms_move, 1.84 * sz$p$se, sz$p$se, if (sz$p$rms_move < 1.84 * sz$p$se) "cannot show a pass at 80% power" else "can",
            sz$h$rms_move, 1.84 * sz$h$se, sz$h$se, if (sz$h$rms_move < 1.84 * sz$h$se) "cannot show a pass at 80% power" else "can"))
both_small <- sz$p$rms_move < 1.84 * sz$p$se && sz$h$rms_move < 1.84 * sz$h$se
cat(sprintf("FB8  both bounds under 1.84 SE: %s%s\n", both_small, if (both_small) " -> per the prereg this goes to Pete before any deciding run (none is run here)" else ""))

# ---- results ----------------------------------------------------------------------------------------------------------
cat("\nFB9  RESULTS. RMSE of the published statewide level against the result, points; change = arm minus B0, NEGATIVE = BETTER; SE = delete-one-election jackknife\n")
cat("     arm          primary: B0 -> arm (change, SE, n cells/elections)        H 90+180: B0 -> arm (change, SE, n)        verdict   toward/away (primary)\n")
for (nm in names(S)) {
  s <- S[[nm]]
  cat(sprintf("     %-17s %.3f -> %.3f (%+.4f, %.4f, %d/%d)   %.3f -> %.3f (%+.4f, %.4f, %d/%d)   %-5s   %d/%d\n", nm,
              s$p$rmse_b0, s$p$rmse_arm, s$p$d, s$p$se, s$p$n, s$p$G, s$h$rmse_b0, s$h$rmse_arm, s$h$d, s$h$se, s$h$n, s$h$G, s$v, s$p$toward, s$p$away))
}
cat("\nFB9  horizons separately (change, SE): 30 days reported only; 90 and 180 pooled above into H\n")
for (nm in names(S)) { s <- S[[nm]]; cat(sprintf("     %-17s 30d %+.4f (%.4f)   90d %+.4f (%.4f)   180d %+.4f (%.4f)\n", nm, s$h30$d, s$h30$se, s$h90$d, s$h90$se, s$h180$d, s$h180$se)) }
beq_p <- verdict_orig(S$Beq$p$d, S$Beq$p$se); beq_h <- verdict_orig(S$Beq$h$d, S$Beq$h$se)
cat(sprintf("\nFB9  dry run 3, the negative control: B-eq must FAIL the primary. Primary alone: %s (%+.4f, SE %.4f, %.2f SE); H alone: %s (%+.4f, SE %.4f, %.2f SE); Amendment 1 verdict %s\n",
            beq_p, S$Beq$p$d, S$Beq$p$se, S$Beq$p$d / S$Beq$p$se, beq_h, S$Beq$h$d, S$Beq$h$se, S$Beq$h$d / S$Beq$h$se, S$Beq$v))
if (beq_p != "FAIL") cat("FB9! the primary cannot see this input (prereg dry run 3: stop and report). The arms below are reported with that caveat; no deciding run follows from this screen.\n")
cat("FB9  B-eq unblended (before the blend) day-before RMSE change, the trend's own view of the control: ")
{ a <- cells(setNames(lapply(TARGETS, function(e) FITS$Beq[[e]][["1"]]$lv), TARGETS), B0d1); b <- cells(setNames(lapply(TARGETS, function(e) FITS$B0[[e]][["1"]]$lv), TARGETS), B0d1)
  pq <- paired(a, b); cat(sprintf("%.3f -> %.3f (%+.4f, SE %.4f)\n", pq$rmse_b0, pq$rmse_arm, pq$d, pq$se)) }
cat("FB9  unblended trend RMSE change at each horizon (reported; the prereg's expectation: 0.1-0.5 point moves, more months out):\n")
for (nm in c("B1", "B2", "B3")) for (h in as.character(HZ)) {
  a <- cells(setNames(lapply(TARGETS, function(e) { u <- FITS[[nm]][[e]][[h]]; if (isTRUE(u$ok)) u$lv else NULL }), TARGETS), lapply(FITS$B0, `[[`, h))
  b <- cells(setNames(lapply(TARGETS, function(e) { u <- FITS$B0[[e]][[h]]; if (isTRUE(u$ok)) u$lv else NULL }), TARGETS), lapply(FITS$B0, `[[`, h))
  if (is.null(a) || !nrow(a)) next
  pp <- paired(a, b)
  cat(sprintf("     %s %3s days: unblended RMSE %.3f -> %.3f (%+.4f, SE %.4f, %d cells, RMS move %.3f)\n", nm, h, pp$rmse_b0, pp$rmse_arm, pp$d, pp$se, pp$n, pp$rms_move))
}
cat("\nFB10 per-cell published day-before level, B0 / B1 / B2 / B3 / actual:\n")
pc <- Reduce(function(x, y) merge(x, y, by = c("election", "cls")), lapply(c("B0", "B1", "B2", "B3"), function(nm) {
  x <- cells(LV[[nm]][["1"]], B0d1)[, list(election, cls, v = round(pred, 2), act = round(act, 2))]; setnames(x, "v", nm); if (nm != "B0") x[, act := NULL]; x }))
print(pc, row.names = FALSE)

# ---- unacceptable-win clauses ------------------------------------------------------------------------------------------
cat("\nFB11 unacceptable-win checks\n")
cat(sprintf("     B3 r at the top of the grid (1) for most targets: %d of %d day-before picks have r_hat = 1\n",
            sum(B3R$r_hat[B3R$h == 1L] == 1, na.rm = TRUE), sum(B3R$h == 1L)))
for (nm in c("B1", "B2", "B3")) if (S[[nm]]$v == "PASS")
  cat(sprintf("     %s PASS: B2-wide20 primary %+.4f, H %+.4f (a sign change would mean the gain leaked through the prior)\n", nm, S$wide20$p$d, S$wide20$h$d))
offs <- rbindlist(lapply(TARGETS, function(e) { u <- FITS$B2[[e]][["1"]]; if (is.null(u$fed)) NULL else u$fed[, election := e][] }))
cat(sprintf("     B2 fitted offsets (day before, all targets): %d effects; |offset| under 0.5 pts in %d; median |offset| %.2f pts; range %.1f to %.1f\n",
            nrow(offs), sum(abs(offs$offset_pts) < 0.5), median(abs(offs$offset_pts)), min(offs$offset_pts), max(offs$offset_pts)))
fwrite(offs, file.path(CACHE, "..", "fedbd-offsets-B2-daybefore.csv"))
cat("     every B2 day-before offset (party, firm:term, n, offset pts, posterior sd pts):\n")
for (e in TARGETS) { o <- offs[offs$election == e]; if (nrow(o)) cat(sprintf("       %s: %s\n", e, paste(sprintf("%s %s n%d %+.1f(%.1f)", o$party, sub("^fed:", "", o$firm), o$n, o$offset_pts, o$sd_pts), collapse = "; "))) }
# correlated sampling error: same firm, state poll dated inside a breakdown's fieldwork
cat("     same-firm overlap (state poll dated inside a breakdown's fieldwork, same canonical firm), day-before B2:\n")
alias <- fread(file.path("external", "reference", "polls", "statewide-samples", "firm_alias.csv"), showProgress = FALSE)
for (e in TARGETS) {
  ft <- FITS$B2[[e]][["1"]]$fed_tab; if (is.null(ft)) next
  rg <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e))
  cp <- cycle_polls(suppressMessages(load_polls(rg)), yr); cp <- cp[cp$date < as.Date(unname(eds[e]))]
  cf <- .ps_canon(cp$firm, alias)
  np <- sum(vapply(seq_len(nrow(ft)), function(i) sum(cf == ft$canon[i] & cp$date >= ft$start[i] & cp$date <= ft$end[i]), 0L))
  cat(sprintf("       %s: %d pairs\n", e, np))
}

# ---- live ---------------------------------------------------------------------------------------------------------------
cat("\nFB12 live published statewide level as at today (", format(Sys.Date()), "), forecast_statewide_for() + the shipped blend, per arm\n")
live_r <- pick_r(Sys.Date())
cat(sprintf("     B3's live r: r_hat %s over %d targets -> %.3f\n", format(live_r$r_hat), live_r$m, live_r$r))
LIVE_ARMS <- list(B0 = TR$B0, B1 = TR$B1, B2 = TR$B2, B3 = TREND_ENV(live_r$r, "full", "1"))
for (e in c("vic2026", "nsw2027")) {
  rows <- list()
  for (nm in names(LIVE_ARMS)) {
    u <- unblended(LIVE_ARMS[[nm]], e, 0L, live_asat = Sys.Date())
    if (pending(u)) { cat("     live fits pending; re-run\n"); quit(save = "no", status = 0) }
    if (!isTRUE(u$ok)) { cat(sprintf("     %s %s: %s\n", e, nm, u$why)); next }
    tb <- arm_table(d1(if (nm == "B3") "B3" else nm))
    v <- blend(u, e, tb)
    rows[[nm]] <- list(u = u, v = v)
  }
  cl <- fitted_cls(rows$B0$u)
  tabl <- rbindlist(lapply(names(rows), function(nm) data.table(arm = nm, t(round(c(rows[[nm]]$v[cl]), 2)), n_fed = if (is.null(rows[[nm]]$u$n_fed)) 0L else rows[[nm]]$u$n_fed)))
  cat(sprintf("     %s (published level, points; n_fed = breakdowns admitted):\n", e)); print(tabl, row.names = FALSE)
  for (nm in setdiff(names(rows), "B0")) {
    mv <- rows[[nm]]$v[cl] - rows$B0$v[cl]
    cat(sprintf("     %s %s moves: %s\n", e, nm, paste(sprintf("%s %+.2f", cl, mv), collapse = ", ")))
    if (any(abs(mv) > 0.5)) {
      ft <- rows[[nm]]$u$fed_tab; ft <- ft[order(-as.integer(ft$end))]
      cat(sprintf("       move over 0.5: newest admitted breakdowns: %s\n", paste(utils::head(sprintf("%s %s-%s ALP %s LNP %s GRN %s ONP %s n %s", ft$canon, format(ft$start, "%d%b"), format(ft$end, "%d%b%y"),
          ft$ALP, ft$LNP, ft$GRN, ft$ONP, round(ft$n_used)), 8), collapse = "; ")))
      fe <- rows[[nm]]$u$fed
      cat(sprintf("       its offsets: %s\n", paste(sprintf("%s %s %+.1f(%.1f) n%d", fe$party, sub("^fed:", "", fe$firm), fe$offset_pts, fe$sd_pts, fe$n), collapse = "; ")))
      if (any(abs(mv) > 1)) cat("       FB12! a live move over 1 point: with a TIE in the backtest this goes to Pete with these rows\n")
    }
  }
}
saveRDS(list(S = lapply(S, function(s) lapply(s[c("p", "h", "h90", "h180", "h30")], function(x) x[setdiff(names(x), "m")])), B3R = B3R, LV = LV),
        file.path(CACHE, "..", "fedbd-screen-results.rds"))
cat(sprintf("\nFB13 done in %.1f min (%d new fits); results also in %s\n", as.numeric(difftime(Sys.time(), t_start, units = "mins")), n_new,
            normalizePath(file.path(CACHE, "..", "fedbd-screen-results.rds"), mustWork = FALSE)))

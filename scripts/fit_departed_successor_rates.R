# Time-forward departed-independent rates, split by a hand-coded successor flag.
#
# docs/plans/prereg-departed-successor-flag-2026-10-07.md. For each target
# election T the rates use ONLY successor cells whose polling day is strictly
# before T's -- never leave-one-out, which would train on later elections.
#
# Gates that run BEFORE any outcome is read (the script stops on failure):
#   1. The flag file covers every row of the outcome-blind coding input.
#   2. Every TRUE component carries a source dated strictly before polling day.
#   --audit prints the 10 random TRUE rows (seed 20261007) to open by hand, and
#   stops without reading outcomes. Run that first and record the audit.
#
# Cell flag: `strong` if ANY IND candidate in the cell has any component TRUE.
# Cells with a sitting or former MP among the INDs are excluded (defector
# machinery's question). Retention is the ratio of means, sum(IND now) /
# sum(IND before), the definition of the shipped 0.38.
#
# Shrinkage: r_g = mu_T + w_g (est_g - mu_T), w_g = tau^2 / (tau^2 + se_g^2),
# se_g clustered on election, tau^2 = max(0, var(est_g) - mean(se_g^2)).
# A group with no earlier cells takes mu_T; with no earlier cells at all mu_T
# falls back to the shipped 0.38 (itself fitted on the whole corpus -- the leak
# the prereg names; such targets are marked `fallback`).
#
# Writes output/departed-successor-rates.csv (target, seat, group, rate, ...)
# and output/departed-successor-fits.csv (one row per target: mu, est, se, w, n).

suppressPackageStartupMessages({library(data.table); devtools::load_all(quiet = TRUE)})

AUDIT_ONLY <- "--audit" %in% commandArgs(trailingOnly = TRUE)
FALLBACK_RATE <- 0.38   # formals(screened_slopes)$departed_rate, the shipped value
COMPONENTS <- c("endorsed_by_departed", "local_office", "community_group", "former_staffer")

inp <- fread("external/reference/successors/coding-input.csv")
flg <- fread("external/reference/successors/departed-ind-successors.csv", colClasses = "character")
cat(sprintf("coding input %d rows; flag file %d rows\n", nrow(inp), nrow(flg)))

# ---- Gate 1: coverage ----
key_in <- paste(inp$election, inp$seat, inp$candidate, sep = "|")
key_fl <- paste(flg$election, flg$seat, flg$candidate, sep = "|")
miss <- setdiff(key_in, key_fl); extra <- setdiff(key_fl, key_in)
if (length(miss) || length(extra) || anyDuplicated(key_fl))
  stop(sprintf("flag file does not match the input: %d missing, %d extra, %d duplicated\n  %s",
               length(miss), length(extra), sum(duplicated(key_fl)),
               paste(utils::head(c(miss, extra), 8), collapse = "\n  ")), call. = FALSE)
for (cc in COMPONENTS) {
  v <- toupper(trimws(flg[[cc]]))
  bad <- !v %in% c("TRUE", "FALSE", "UNKNOWN")
  if (any(bad)) stop(sprintf("%s has %d values outside TRUE/FALSE/UNKNOWN", cc, sum(bad)), call. = FALSE)
  set(flg, j = cc, value = v)
}
flg[, any_true := Reduce(`|`, lapply(COMPONENTS, function(cc) flg[[cc]] == "TRUE"))]

# ---- Gate 2: every TRUE has a source dated before polling day ----
flg <- inp[, .(election, seat, candidate, election_date = as.Date(election_date),
               prior_mp_in_our_data)][flg, on = .(election, seat, candidate)]
# Several sources are " | "-separated; the EARLIEST date must precede polling
# day and NONE may be on or after it (a post-election source is not evidence).
src_dates <- lapply(strsplit(ifelse(is.na(flg$source_date), "", flg$source_date), "\\s*\\|\\s*"),
                    function(d) suppressWarnings(as.Date(d, format = "%Y-%m-%d")))
flg[, src_n := lengths(src_dates)]
flg[, src_bad := vapply(seq_len(.N), function(i) {
  d <- src_dates[[i]]
  if (!flg$any_true[i]) return(FALSE)
  !length(d) || anyNA(d) || any(d >= flg$election_date[i])
}, logical(1))]
cat(sprintf("TRUE rows: %d of %d; with a missing, unparseable or on/after-polling-day source date: %d\n",
            sum(flg$any_true), nrow(flg), sum(flg$src_bad)))
if (any(flg$src_bad)) {
  print(flg[flg$src_bad, .(election, seat, candidate, election_date, source_date)])
  stop("Gate 2 failed: every TRUE needs ISO source dates strictly before polling day", call. = FALSE)
}

if (AUDIT_ONLY) {
  set.seed(20261007)
  tr <- flg[flg$any_true]
  pick <- tr[sort(sample(nrow(tr), min(10, nrow(tr))))]
  cat("\nAUDIT SAMPLE -- open each source, check date and quote, record in the review:\n")
  for (i in seq_len(nrow(pick))) with(pick[i], cat(sprintf(
    "\n[%d] %s %s -- %s (polling day %s)\n    components: %s\n    %s\n    dated %s: \"%s\"\n",
    i, election, seat, candidate, election_date,
    paste(COMPONENTS[unlist(.SD[, COMPONENTS, with = FALSE]) == "TRUE"], collapse = ", "),
    source_url, source_date, quote)))
  quit(save = "no")
}

# ---- Outcomes are read only past this line ----
cells <- fread("output/departed-ind-successors.csv")
cflag <- flg[, .(strong = any(any_true), has_mp = any(prior_mp_in_our_data %in% c("TRUE", TRUE))),
             by = .(election, seat)]
cells <- cflag[cells, on = .(election, seat)]
stopifnot(!anyNA(cells$strong))
cells[, election_date := as.Date(unname(election_dates(election)))]
cells[, group := ifelse(strong, "strong", "weak")]
use <- cells[!cells$has_mp]
cat(sprintf("cells %d; excluded (an IND is a sitting/former MP) %d; strong %d, weak %d (live %d)\n",
            nrow(cells), sum(cells$has_mp), sum(use$strong), sum(!use$strong), sum(!use$scored)))

ratio_fit <- function(d) {
  # Ratio-of-means retention with a cluster-on-election linearised SE.
  if (!nrow(d)) return(list(est = NA_real_, se = NA_real_, n = 0L, k = 0L))
  r <- sum(d$ind_total_now) / sum(d$prior_ind_total)
  e <- d$ind_total_now - r * d$prior_ind_total
  E <- tapply(e, d$election, sum); k <- length(E)
  se <- if (k > 1) sqrt(k / (k - 1) * sum(E^2)) / sum(d$prior_ind_total) else NA_real_
  list(est = r, se = se, n = nrow(d), k = k)
}

targets <- names(election_dates())
fits <- list(); rates <- list()
for (T in targets) {
  tday <- as.Date(unname(election_dates(T)))
  hist <- use[use$scored & use$election_date < tday]
  pooled <- ratio_fit(hist)
  fallback <- pooled$n == 0
  mu <- if (fallback) FALLBACK_RATE else pooled$est
  g <- lapply(c(strong = "strong", weak = "weak"), function(x) ratio_fit(hist[hist$group == x]))
  est <- vapply(g, `[[`, 0, "est"); se <- vapply(g, `[[`, 0, "se")
  ok <- !is.na(est) & !is.na(se)
  tau2 <- if (sum(ok) == 2) max(0, stats::var(est) - mean(se^2)) else 0
  w <- ifelse(ok, tau2 / (tau2 + se^2), 0); w[is.nan(w)] <- 0
  r <- ifelse(ok, mu + w * (est - mu), mu)
  fits[[T]] <- data.table(target = T, n_hist = pooled$n, k_hist = pooled$k, fallback, mu,
                          tau2, est_strong = est[["strong"]], se_strong = se[["strong"]],
                          n_strong = g$strong$n, w_strong = w[["strong"]], rate_strong = r[["strong"]],
                          est_weak = est[["weak"]], se_weak = se[["weak"]],
                          n_weak = g$weak$n, w_weak = w[["weak"]], rate_weak = r[["weak"]])
  here <- use[use$election == T]
  rates[[T]] <- if (nrow(here))
    data.table(target = T, seat = here$seat, group = here$group,
               rate = ifelse(here$strong, r[["strong"]], r[["weak"]]), fallback)
  else data.table(target = T, seat = "(none)", group = NA_character_, rate = NA_real_, fallback)
}
fits <- rbindlist(fits); rates <- rbindlist(rates)
stopifnot(!anyNA(rates$rate[rates$seat != "(none)"]))
fwrite(fits, "output/departed-successor-fits.csv")
fwrite(rates, "output/departed-successor-rates.csv")
cat(sprintf("\nwrote rates for %d cells over %d targets (%d targets fall back to %.2f)\n",
            sum(rates$seat != "(none)"), uniqueN(rates$target), sum(fits$fallback), FALLBACK_RATE))
print(fits[fits$target %in% unique(use$election),
           .(target, n_hist, fallback, mu = round(mu, 3), tau2 = signif(tau2, 2),
             strong = sprintf("%.2f (n%d, w%.2f) -> %.2f", est_strong, n_strong, w_strong, rate_strong),
             weak = sprintf("%.2f (n%d, w%.2f) -> %.2f", est_weak, n_weak, w_weak, rate_weak))])

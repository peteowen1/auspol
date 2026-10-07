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
# --split=sitting: groups by whether the departed leader was the sitting member
# (docs/plans/prereg-departed-sitting-split-2026-10-07.md). No hand-coded flags,
# so the flag gates do not apply; targets with no earlier cell get NO per-seat
# rate (today's behaviour) rather than the 0.38 fallback.
SITTING <- "--split=sitting" %in% commandArgs(trailingOnly = TRUE)
FALLBACK_RATE <- 0.38   # formals(screened_slopes)$departed_rate, the shipped value
COMPONENTS <- c("endorsed_by_departed", "local_office", "community_group", "former_staffer")

if (SITTING) {
  inp <- fread("external/reference/successors/coding-input.csv")
  mp <- inp[, .(has_mp = any(prior_mp_in_our_data %in% c("TRUE", TRUE))), by = .(election, seat)]
  cells <- mp[fread("output/departed-ind-successors.csv"), on = .(election, seat)]
  stopifnot(!anyNA(cells$has_mp))
  cells[, election_date := as.Date(unname(election_dates(election)))]
  cells[, group := ifelse(is.na(departed_elected), "unknown",
                          ifelse(departed_elected %in% TRUE, "sitting", "not_sitting"))]
  use <- cells[!cells$has_mp & cells$group != "unknown"]
  GROUPS <- c("sitting", "not_sitting"); OUT <- "output/departed-sitting"
  cat(sprintf("cells %d; excluded: sitting/former MP successor %d, no elected flag %d; sitting %d, not sitting %d (live %d)
",
              nrow(cells), sum(cells$has_mp), sum(!cells$has_mp & cells$group == "unknown"),
              sum(use$group == "sitting"), sum(use$group == "not_sitting"), sum(!use$scored)))
} else {
  inp <- fread("external/reference/successors/coding-input.csv")
  flg <- fread(Sys.getenv("AUSPOL_SUCCESSOR_FLAGS", "external/reference/successors/departed-ind-successors.csv"), colClasses = "character")   # override for gate tests only
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
  # Strict ISO only: as.Date() alone accepts "2022-03-05 (updated 2023-02-01)" on
  # its first ten characters, and "2022-3-5". A piece that is not exactly
  # YYYY-MM-DD becomes NA, which fails the gate.
  src_dates <- lapply(strsplit(ifelse(is.na(flg$source_date), "", flg$source_date), "\\s*\\|\\s*"),
                      function(d) {
                        d <- trimws(d)
                        ok <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", d)
                        out <- rep(as.Date(NA), length(d))
                        out[ok] <- as.Date(d[ok], format = "%Y-%m-%d")
                        out
                      })
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
      paste(COMPONENTS[vapply(COMPONENTS, function(cc) pick[[cc]][i] == "TRUE", logical(1))], collapse = ", "),
      source_url, source_date, quote)))
    quit(save = "no")
  }

  # ---- Outcomes are read only past this line ----
  cells <- fread("output/departed-ind-successors.csv")
  # A candidate with every component UNKNOWN (no pre-election profile to read)
  # cannot be called weak: older elections have thinner sources, so treating
  # UNKNOWN as FALSE would mix era with flag quality. Such a cell is `unknown`
  # unless some candidate is TRUE, and is left out of both the fit and the arm.
  flg[, all_unknown := Reduce(`&`, lapply(COMPONENTS, function(cc) flg[[cc]] == "UNKNOWN"))]
  cflag <- flg[, .(strong = any(any_true), any_unknown = any(all_unknown),
                   has_mp = any(prior_mp_in_our_data %in% c("TRUE", TRUE))),
               by = .(election, seat)]
  cells <- cflag[cells, on = .(election, seat)]
  stopifnot(!anyNA(cells$strong), !anyNA(cells$any_unknown))
  cells[, election_date := as.Date(unname(election_dates(election)))]
  cells[, group := ifelse(strong, "strong", ifelse(any_unknown, "unknown", "weak"))]
  use <- cells[!cells$has_mp & cells$group != "unknown"]
  cat(sprintf("cells %d; excluded: sitting/former MP %d, unknown (no profile, no TRUE) %d; strong %d, weak %d (live %d)\n",
              nrow(cells), sum(cells$has_mp), sum(!cells$has_mp & cells$group == "unknown"),
              sum(use$strong), sum(!use$strong), sum(!use$scored)))
  # Era balance, printed BEFORE any rate: if unknown or weak pile up in early
  # elections, the split partly measures source coverage, not the successor.
  print(cells[!cells$has_mp, .N, by = .(era = ifelse(year(election_date) < 2013, "before 2013", "2013 on"), group)][order(era, group)])
  GROUPS <- c("strong", "weak"); OUT <- "output/departed-successor"
}

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
  g <- lapply(stats::setNames(GROUPS, GROUPS), function(x) ratio_fit(hist[hist$group == x]))
  est <- vapply(g, `[[`, 0, "est"); se <- vapply(g, `[[`, 0, "se"); nn <- vapply(g, `[[`, 0L, "n")
  ok <- !is.na(est) & !is.na(se)
  tau2 <- if (sum(ok) == 2) max(0, stats::var(est) - mean(se^2)) else 0
  w <- ifelse(ok, tau2 / (tau2 + se^2), 0); w[is.nan(w)] <- 0
  r <- ifelse(ok, mu + w * (est - mu), mu)
  fits[[T]] <- cbind(data.table(target = T, n_hist = pooled$n, k_hist = pooled$k, fallback, mu, tau2),
                     as.data.table(as.list(c(stats::setNames(est, paste0("est_", GROUPS)), stats::setNames(se, paste0("se_", GROUPS)),
                                             stats::setNames(nn, paste0("n_", GROUPS)), stats::setNames(w, paste0("w_", GROUPS)),
                                             stats::setNames(r, paste0("rate_", GROUPS))))))
  here <- use[use$election == T]
  rates[[T]] <- if (nrow(here) && !(SITTING && fallback))
    data.table(target = T, seat = here$seat, group = here$group, rate = unname(r[here$group]), fallback)
  else data.table(target = T, seat = "(none)", group = NA_character_, rate = NA_real_, fallback)
}
fits <- rbindlist(fits, fill = TRUE); rates <- rbindlist(rates)
stopifnot(!anyNA(rates$rate[rates$seat != "(none)"]))
fwrite(fits, paste0(OUT, "-fits.csv"))
fwrite(rates, paste0(OUT, "-rates.csv"))
cat(sprintf("
wrote %s-rates.csv: %d cells over %d targets (%d targets with no earlier cell%s)
",
            OUT, sum(rates$seat != "(none)"), uniqueN(rates$target), sum(fits$fallback),
            if (SITTING) ", given no rate" else sprintf(", mu = %.2f", FALLBACK_RATE)))
show <- fits[fits$target %in% unique(use$election)]
for (gname in GROUPS) show[[gname]] <- sprintf("%.2f (n%d, w%.2f) -> %.2f", show[[paste0("est_", gname)]],
                                               as.integer(show[[paste0("n_", gname)]]), show[[paste0("w_", gname)]], show[[paste0("rate_", gname)]])
print(show[, c("target", "n_hist", "fallback", "mu", GROUPS), with = FALSE], nrows = 60)

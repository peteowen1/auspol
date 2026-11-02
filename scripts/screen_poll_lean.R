# Poll-lean screen (plans/prereg-poll-lean-2026-11-02.md). Step 0: the data gate and the primary's noise floor.
#
#   powershell.exe -Command 'Rscript "scripts/screen_poll_lean.R"'
#
# Prints, before any arm is built:
#   PL0a  per region, 2010+ statewide poll rows in the Wikipedia tables with a firm resolved by firm_alias.csv,
#         a method label (mode_raw) and a client (sponsor). Gate: firm resolved on >= 95%.
#   PL0b  per scored election, the day-before trend error (the prereg primary) on the published trend:
#         mean absolute error over ALP, LNP, GRN, ONP (where fitted) and everything else, against the
#         statewide primary in output/candidacies.csv.
#   PL0c  the primary's noise floor: a placebo arm (one poll dropped at random per election, seeded) scored
#         paired against the incumbent, giving the election-clustered SE of a paired difference under a change
#         that should do nothing. Gate: that SE <= 0.10 points.
#   PL0d  earlier-election support per scored election (elections with polls and a result before its cycle).
# Writes nothing to output/. Data.table NSE: no local shares a column name inside [...]; masks built outside.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/published_flags.R")
for (k in names(PUBLISHED_FLAGS)) if (Sys.getenv(k) == "") do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[k]]), k))

REGIONS <- c("fed", "nsw", "vic", "qld", "wa", "sa", "nt")
LIVE <- c("vic2026", "nsw2027")             # never scored (prereg leakage rules)
MAIN <- c("ALP", "LNP", "GRN", "ONP")

# ---- PL0a: label coverage -------------------------------------------------------------------------------
wiki <- fread("external/reference/polls/statewide-samples/statewide_polls_wiki.csv", encoding = "UTF-8")
alias <- fread("external/reference/polls/statewide-samples/firm_alias.csv")
fw_end <- as.Date(substr(as.character(wiki$fieldwork_end), 1, 10), format = "%Y-%m-%d")
is_poll <- wiki$row_type == "poll" & !is.na(fw_end) & fw_end >= as.Date("2010-01-01")
cat(sprintf("PL0a  %d poll rows, %d with no parseable fieldwork_end (left out)\n",
            sum(wiki$row_type == "poll"), sum(wiki$row_type == "poll" & is.na(fw_end))))
w <- wiki[is_poll]
fl <- tolower(ifelse(is.na(w$firm) | w$firm == "", w$firm_raw, w$firm))
pats <- tolower(alias$pattern)
w[, firm_ok := vapply(fl, function(f) !is.na(f) && f != "" && any(vapply(pats, function(p) grepl(p, f, perl = TRUE), TRUE)), TRUE)]   # patterns are REGEX (`red ?bridge|accent`); matching them as fixed text failed the gate on 2 Nov
mode_txt <- trimws(w$mode_raw)
w[, mode_ok := !is.na(mode_txt) & grepl("[A-Za-z]", mode_txt)]
cl <- trimws(ifelse(is.na(w$client) | w$client == "", w$client_raw, w$client))
w[, client_ok := !is.na(cl) & cl != ""]
cov <- w[, .(polls = .N, firm_resolved = sum(firm_ok), method_label = sum(mode_ok), client = sum(client_ok)), by = region]
cov <- rbind(cov, w[, .(region = "ALL", polls = .N, firm_resolved = sum(firm_ok), method_label = sum(mode_ok), client = sum(client_ok))])
cov[, `:=`(firm_pct = round(100 * firm_resolved / polls, 1), method_pct = round(100 * method_label / polls, 1),
           client_pct = round(100 * client / polls, 1))]
cat("\nPL0a  2010+ statewide poll rows in the Wikipedia tables: how many carry each label (percent, higher is better)\n")
print(cov)
firm_all <- cov[region == "ALL"]$firm_pct
cat(sprintf("PL0a  GATE firm resolved %.1f%% (require >= 95): %s\n", firm_all, if (firm_all >= 95) "PASS" else "FAIL"))
unres <- w[firm_ok == FALSE, .N, by = .(firm_raw)][order(-N)]
if (nrow(unres)) { cat("PL0a  unresolved firms, most rows first:\n"); print(head(unres, 12)) }

# The poll rows the trend actually fits (load_polls): the REC arm estimates per firm on THESE rows.
anc <- rbindlist(lapply(REGIONS, function(rg) {
  p <- load_polls(rg); k <- p$date >= as.Date("2010-01-01")
  data.table(region = rg, firm = p$firm[k])
}))
anc_cov <- anc[, .(polls = .N, firm_named = sum(!is.na(firm) & nzchar(trimws(firm))), firms = uniqueN(firm)), by = region]
anc_cov[, firm_pct := round(100 * firm_named / polls, 1)]
cat("\nPL0a2 2010+ poll rows the trend fits (load_polls): firm named, and distinct firm labels (percent, higher is better)\n")
print(anc_cov)
cat(sprintf("PL0a2 firm named on %.1f%% of %d rows\n", 100 * sum(anc_cov$firm_named) / sum(anc_cov$polls), sum(anc_cov$polls)))

# ---- actual statewide primaries -------------------------------------------------------------------------
cand <- fread("output/candidacies.csv", select = c("election", "region", "year", "party", "votes"))
cand[, votes := as.numeric(votes)]
tot <- cand[, .(tot = sum(votes, na.rm = TRUE)), by = .(election)]
act <- cand[, .(v = sum(votes, na.rm = TRUE)), by = .(election, region, year, party)]
act <- merge(act, tot, by = "election")
act[, share := 100 * v / tot]

cycles <- as.data.table(load_election_cycles())
pri <- as.data.table(load_prior_results())
pf <- load_preference_flows()

score_one <- function(fit, a_row) {
  if (is.null(fit)) return(NULL)
  ends <- fit$fp                      # trend_as_at() without with_series returns the endpoint shares here
  ps <- intersect(MAIN, names(ends))
  stopifnot(length(ps) >= 2L, all(is.finite(ends[ps])))   # PL0b once scored 0.000 everywhere on an empty party set
  got <- setNames(a_row$share, a_row$party)
  a <- vapply(ps, function(p) if (p %in% names(got)) got[[p]] else 0, 1)
  e <- unname(ends[ps]) - unname(a)
  oth_t <- 100 - sum(ends[ps]); oth_a <- 100 - sum(a)
  data.table(n_party = length(ps) + 1L, mae = mean(abs(c(e, oth_t - oth_a))),
             onp_fitted = "ONP" %in% ps)
}

set.seed(20261102)
rows <- list(); sup <- list()
for (rg in REGIONS) {
  polls <- load_polls(rg)
  for (el in unique(act[act$region == rg]$election)) {
    if (el %in% LIVE) next
    yr <- act[act$election == el]$year[1]
    ce <- cycles[cycles$region == rg & cycles$year == yr]
    if (!nrow(ce)) next
    asat <- ce$end[1] - 1
    m <- pri$region == rg & pri$year == yr
    priors <- setNames(pri$prev1[m], pri$party[m])
    flw <- tryCatch(flows_for(pf, yr, rg, quiet = TRUE), error = function(e) NULL)
    base <- tryCatch(trend_as_at(polls, yr, cycles, asat, priors, flw), error = function(e) NULL)
    a_row <- act[act$election == el]
    s0 <- score_one(base, a_row)
    if (is.null(s0)) { rows[[el]] <- data.table(election = el, scored = FALSE); next }
    # placebo: drop one poll of this cycle at random
    cp <- cycle_polls(polls, yr, cycles)
    in_cyc <- which(polls$date %in% cp$date[cp$date <= asat])
    drop_i <- if (length(in_cyc) > 8) sample(in_cyc, 1) else integer(0)
    pl2 <- polls[-drop_i]
    for (a in setdiff(names(attributes(polls)), names(attributes(pl2)))) data.table::setattr(pl2, a, attr(polls, a))
    plc <- if (length(drop_i)) tryCatch(trend_as_at(pl2, yr, cycles, asat, priors, flw), error = function(e) NULL) else base
    s1 <- score_one(plc, a_row)
    n_cyc <- sum(cp$date <= asat)
    rows[[el]] <- data.table(election = el, scored = TRUE, polls = n_cyc, n_party = s0$n_party,
                             onp_fitted = s0$onp_fitted, mae = s0$mae,
                             placebo_diff = if (is.null(s1)) NA_real_ else s1$mae - s0$mae)
    start_i <- ce$start[1]
    earlier <- cycles[cycles$end < start_i & paste0(cycles$region, cycles$year) %in% unique(act$election)]
    sup[[el]] <- data.table(election = el, earlier_same_region = sum(earlier$region == rg), earlier_all = nrow(earlier))
  }
}
res <- rbindlist(rows, fill = TRUE)
sc <- res[scored == TRUE]
cat(sprintf("\nPL0b  day-before trend error on the published trend, %d scored elections (%d with no fit: %s)\n",
            nrow(sc), sum(!res$scored), paste(res[scored == FALSE]$election, collapse = ", ")))
cat("PL0b  mae = mean absolute error in points over the main parties fitted plus everything else (lower is better)\n")
print(sc[order(-mae), .(election, polls, n_party, onp_fitted, mae = round(mae, 2))])
cat(sprintf("PL0b  incumbent: mean %.3f points, sd across elections %.3f, SE of the mean %.3f (n %d)\n",
            mean(sc$mae), sd(sc$mae), sd(sc$mae) / sqrt(nrow(sc)), nrow(sc)))

pd <- sc$placebo_diff[is.finite(sc$placebo_diff)]
se_p <- sd(pd) / sqrt(length(pd))
cat(sprintf("\nPL0c  placebo (one poll dropped at random per election, seed 20261102): paired diff mean %+.4f, sd %.4f, SE %.4f (n %d)\n",
            mean(pd), sd(pd), se_p, length(pd)))
cat(sprintf("PL0c  GATE paired-difference SE %.4f points (require <= 0.10): %s\n", se_p, if (se_p <= 0.10) "PASS" else "FAIL"))
cat("PL0c  NB a placebo moves less than a real arm, so this is a lower bound on the noise a real arm meets.\n")

sp <- rbindlist(sup)
cat("\nPL0d  earlier elections (with a result) ending before each scored cycle began: same region and all regions\n")
print(sp[order(earlier_all)])

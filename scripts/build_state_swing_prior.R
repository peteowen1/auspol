# State-election swing as a predictor of the federal swing in that state.
# Pete, 2026-09-12: "state level polling???? (this could help with the SA26 as
# well if we have federal state level info)"
#
# WHY. fed2022 missed Hasluck by 11.4 points and Tangney by 12.9 on the Labor
# primary. Both are WA seats, and WA swung +7.0 to Labor while the nation swung
# -0.8 -- a +7.8 deviation, the largest in the corpus. Our `level_pred` carries
# only a NATIONAL figure, so nothing in the model could know a state was moving
# differently from the country.
#
# OUR FEDERAL POLLS HAVE NO STATE BREAKDOWN. poll-data-fed.csv is 16 columns --
# MidDate, Firm, Brand, @TPP and party FP columns -- national only. So the
# obvious fix is unavailable and this is the substitute: the most recent STATE
# election before the federal one, which we do hold for five of eight
# jurisdictions.
#
# THE EYEBALL THAT MOTIVATED IT, fed2022:
#
#   state   state-election ALP swing   federal deviation that followed
#   WA      wa2017 42.2 -> wa2021 59.9 = +17.7        +7.8
#   QLD     qld2017 35.4 -> qld2020 39.6 =  +4.1      +1.5
#   NSW     nsw2015 34.1 -> nsw2019 33.3 =  -0.8      -0.4
#   VIC     vic2018 42.9 -> vic2022 37.0 =  -5.8      -3.3
#
# Four for four on sign, and the federal deviation is roughly 40% of the state
# swing. That is four points on one federal election, which is an observation
# and not evidence -- this script builds the feature across every federal pair
# so it can be tested properly.
#
# CAVEATS, stated before the numbers rather than after:
#   * only NSW/VIC/QLD/SA/WA have state elections here. TAS, ACT and NT get NA,
#     and that is 77 of 1,036 federal seat-elections.
#   * the gap between the state and federal election varies from two months to
#     four years, and a stale signal should decay. `months_gap` is emitted so a
#     model can use it rather than having it silently baked in.
#   * a state election's own swing is measured against the PREVIOUS state
#     election, which may itself predate the previous federal one. No attempt is
#     made to align the windows; that is a modelling choice, not a data one.
#
# NO LEAKAGE: every state election used strictly PRECEDES the federal polling
# day it is attached to. Asserted below, per pair, and the script stops if not.
#
# Emits SS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)

# Polling days. Needed because "most recent preceding state election" is a date
# question and election labels only carry a year -- wa2021 (13 Mar 2021) precedes
# fed2022 (21 May 2022), but sa2026 (21 Mar 2026) does NOT precede fed2025.
DATES <- c(
  fed2004="2004-10-09", fed2007="2007-11-24", fed2010="2010-08-21",
  fed2013="2013-09-07", fed2016="2016-07-02", fed2019="2019-05-18",
  fed2022="2022-05-21", fed2025="2025-05-03",
  nsw2015="2015-03-28", nsw2019="2019-03-23", nsw2023="2023-03-25",
  qld2017="2017-11-25", qld2020="2020-10-31", qld2024="2024-10-26",
  sa2018="2018-03-17",  sa2022="2022-03-19",  sa2026="2026-03-21",
  vic2010="2010-11-27", vic2014="2014-11-29", vic2018="2018-11-24", vic2022="2022-11-26",
  wa1996="1996-12-14",  wa2001="2001-02-10",  wa2005="2005-02-26", wa2008="2008-09-06",
  wa2013="2013-03-09",  wa2017="2017-03-11",  wa2021="2021-03-13", wa2025="2025-03-08")
DATES <- as.Date(DATES)
ST <- c(NSW="nsw", VIC="vic", QLD="qld", SA="sa", WA="wa")

alp_share <- function(el) {
  d <- C[C$election == el & is.finite(votes) & is.finite(tot)]
  if (!nrow(d)) return(NA_real_)
  seat_tot <- unique(d[, .(seat, tot)])
  denom <- sum(seat_tot$tot, na.rm = TRUE)
  if (!is.finite(denom) || denom <= 0) return(NA_real_)
  100 * sum(d[d$party == "ALP"]$votes, na.rm = TRUE) / denom
}

# Every state election we hold, with its date and its ALP swing on the previous
# one in the same state.
st_els <- grep("^(nsw|vic|qld|sa|wa)[0-9]{4}$", names(DATES), value = TRUE)
SW <- rbindlist(lapply(st_els, function(el) {
  reg <- sub("[0-9]{4}$", "", el)
  sibs <- sort(st_els[sub("[0-9]{4}$", "", st_els) == reg])
  i <- match(el, sibs)
  prev <- if (i > 1) sibs[i - 1] else NA_character_
  data.table(state_el = el, region = reg, date = DATES[[el]],
             prev_el = prev,
             alp = alp_share(el),
             alp_prev = if (is.na(prev)) NA_real_ else alp_share(prev))
}))
SW[, state_swing := alp - alp_prev]
cat(sprintf("SS1  %d state elections, %d with a computable swing\n",
            nrow(SW), sum(is.finite(SW$state_swing))))
print(SW[is.finite(state_swing), .(state_el, date, alp = round(alp, 1),
                                   swing = round(state_swing, 1))][order(date)])

# For each federal election and state: the most recent state election that
# STRICTLY precedes federal polling day.
fed_els <- grep("^fed", names(DATES), value = TRUE)
rows <- rbindlist(lapply(fed_els, function(fe) {
  fd <- DATES[[fe]]
  rbindlist(lapply(names(ST), function(abbr) {
    reg <- ST[[abbr]]
    cand <- SW[SW$region == reg & SW$date < fd & is.finite(SW$state_swing)]
    if (!nrow(cand)) return(data.table(pair = fe, state = abbr, state_el = NA_character_,
                                       state_swing = NA_real_, months_gap = NA_real_))
    pick <- cand[which.max(cand$date)]
    data.table(pair = fe, state = abbr, state_el = pick$state_el,
               state_swing = pick$state_swing,
               months_gap = as.numeric(fd - pick$date) / 30.44)
  }))
}))
# THE LEAKAGE ASSERTION. Every attached state election must predate its federal
# polling day. Cheap, and this is the class of error the repo has hit three times.
chk <- merge(rows[!is.na(state_el)], data.table(state_el = names(DATES), sd = DATES),
             by = "state_el")
chk[, fd := DATES[pair]]
if (any(chk$sd >= chk$fd)) {
  print(chk[sd >= fd])
  stop("SS2! a state election does not precede its federal polling day -- leakage")
}
cat(sprintf("SS2  leakage check passed: all %d attachments strictly precede polling day\n", nrow(chk)))

# The file is written AFTER fed_dev is computed below, not here -- consumers
# need the outcome alongside the predictor so the slope can be refitted
# leave-one-pair-out without recomputing federal swings from scratch.

# ---- does it actually predict? --------------------------------------------
fed <- C[grepl("^fed", C$election) & is.finite(votes) & is.finite(tot)]
seat_tot <- unique(fed[, .(election, seat, state, tot)])
den_state <- seat_tot[, .(denom = sum(tot, na.rm = TRUE)), by = .(election, state)]
alp_state <- fed[fed$party == "ALP", .(v = sum(votes, na.rm = TRUE)), by = .(election, state)]
A <- merge(alp_state, den_state, by = c("election", "state"))[, .(election, state, alp = 100 * v / denom)]
den_nat <- unique(fed[, .(election, seat, tot)])[, .(denom = sum(tot, na.rm = TRUE)), by = election]
alp_nat <- fed[fed$party == "ALP", .(v = sum(votes, na.rm = TRUE)), by = election]
N <- merge(alp_nat, den_nat, by = "election")[, .(election, alp_natl = 100 * v / denom)]
A <- merge(A, N, by = "election")
setorder(A, state, election)
A[, `:=`(sw = alp - shift(alp), nsw_ = alp_natl - shift(alp_natl)), by = state]
A[, dev := sw - nsw_]

M <- merge(A[, .(pair = election, state, dev)], rows, by = c("pair", "state"))
M <- M[is.finite(dev) & is.finite(state_swing)]
cat(sprintf("\nSS4  TEST: %d pair-state observations across %d federal elections\n",
            nrow(M), uniqueN(M$pair)))
cat("SS4  dev = how much more that state swung to Labor than the nation.\n")
cat("SS4  state_swing = the preceding state election's own ALP swing.\n\n")
print(M[order(-state_swing), .(pair, state, state_el, state_swing = round(state_swing, 1),
                               fed_dev = round(dev, 1), gap_months = round(months_gap))])
ROWS <- merge(rows, A[, .(pair = election, state, fed_dev = dev)],
              by = c("pair", "state"), all.x = TRUE)
fwrite(ROWS, file.path(OUT, "state-swing-prior.csv"))
cat(sprintf("SS3  wrote %s/state-swing-prior.csv (%d rows, %d usable for fitting)\n",
            OUT, nrow(ROWS), sum(is.finite(ROWS$state_swing) & is.finite(ROWS$fed_dev))))

cat(sprintf("\nSS5  correlation = %+.3f (n=%d)\n", cor(M$state_swing, M$dev), nrow(M)))
fit <- lm(dev ~ state_swing, data = M)
cat(sprintf("SS5  slope %+.3f (se %.3f, t = %.2f) | intercept %+.2f | R2 %.3f\n",
            coef(fit)[2], summary(fit)$coefficients[2, 2],
            summary(fit)$coefficients[2, 3], coef(fit)[1], summary(fit)$r.squared))
cat("SS5  a slope near 0.4 would match the fed2022 eyeball; a t under 2 means the\n")
cat("SS5  four-point pattern does not survive the full corpus.\n")
cat("\nSS6  does the signal decay with the gap? same fit, split at 24 months:\n")
for (g in list(c(0, 24), c(24, 999))) {
  s <- M[months_gap >= g[1] & months_gap < g[2]]
  if (nrow(s) < 6) { cat(sprintf("   %2.0f-%3.0f months: n=%d, too few\n", g[1], g[2], nrow(s))); next }
  cat(sprintf("   %2.0f-%3.0f months: n=%2d | r = %+.3f\n", g[1], g[2], nrow(s),
              cor(s$state_swing, s$dev)))
}

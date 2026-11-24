# Quick screen: does any early-vote feature predict the published model's MISS?
#
# Run:  Rscript scripts/screen_early_vote.R            (development elections)
#       Rscript scripts/screen_early_vote.R --final    (adds the fenced-off holdout)
#       Rscript scripts/screen_early_vote.R --only=comp   (ideas whose name matches)
# Needs output/early-vote/panel-*.csv (scripts/early_vote_panel.R) and
# output/published-predictions.csv. Runs in seconds; add an idea to IDEAS below.
#
# TARGET   miss = actual - ours, in points of primary vote, per party class,
#          from the published-path backtest. A feature only matters if it
#          predicts what the model got wrong.
# SCORE    time-forward: the slope is fitted on elections held strictly BEFORE
#          the one being scored, then applied to it. Feature and miss are both
#          centred within election, so a feature cannot win by tracking the
#          election-wide swing. Change in squared error per election; SE across
#          elections (the independent unit), not seats.
# PLACEBO  the feature shuffled between seats within each election, 200 times.
# HOLDOUT  vic2022 and fed2025 are not read until --final.
#
# LEAKAGE  Features may use: this election's COUNT of early/postal votes by seat
#          (the commissions publish these daily before polling day; here the
#          counted totals stand in for them), anything from EARLIER elections,
#          and our own prediction. Never this election's party split by type.
suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
FINAL <- "--final" %in% args
ONLY <- sub("^--only=", "", grep("^--only=", args, value = TRUE))
HOLDOUT <- c("vic2022", "fed2025")
N_PERM <- as.integer(sub("^--perm=", "", c(grep("^--perm=", args, value = TRUE), "--perm=200")[1]))
set.seed(20261124)

MONTH <- c(fed2010 = 8, fed2013 = 9, fed2016 = 7, fed2019 = 5, fed2022 = 5, fed2025 = 5,
           nsw = 3, vic = 11, sa = 3, wa = 3, wa2008 = 9, qld2020 = 10, qld2024 = 10)
GOV <- c(fed2010 = "ALP", fed2013 = "ALP", fed2016 = "LNP", fed2019 = "LNP", fed2022 = "LNP",
         fed2025 = "ALP", nsw2015 = "LNP", nsw2019 = "LNP", nsw2023 = "LNP", qld2020 = "ALP",
         qld2024 = "ALP", sa2026 = "ALP", vic2010 = "ALP", vic2014 = "LNP", vic2018 = "ALP",
         vic2022 = "ALP", wa2008 = "ALP", wa2013 = "LNP", wa2017 = "LNP", wa2021 = "ALP")

seat <- fread("output/early-vote/panel-seat.csv", encoding = "UTF-8")
pt <- fread("output/early-vote/panel-party.csv", encoding = "UTF-8")
pred <- fread("output/published-predictions.csv", encoding = "UTF-8")
pred <- pred[, .(ours = sum(ours), actual = sum(actual), prev_share = sum(prev_share, na.rm = TRUE)),
             by = .(election = pair, seat, party)]
pred[, miss := actual - ours]

# previous election of the same jurisdiction that is in the panel
els <- unique(seat[, .(election, juris, year)])[order(juris, year)]
els[, prev_el := shift(election), by = juris]
els[, when := year + fifelse(election %in% names(MONTH), MONTH[election], MONTH[juris]) / 12]
stopifnot(!anyNA(els$when))
seat <- merge(seat, els[, .(election, prev_el, when)], by = "election")
prev <- seat[, .(prev_el = election, seat, p_early = early_sh, p_postal = postal_sh,
                 p_ord = ordinary / tot)]
seat <- merge(seat, prev, by = c("prev_el", "seat"), all.x = TRUE)
seat[, `:=`(d_early = 100 * (early_sh - p_early), d_postal = 100 * (postal_sh - p_postal),
            early = 100 * early_sh, postal = 100 * postal_sh)]
# surprise: this election's rate beyond what last election's rate predicts,
# fitted within the election on counts only
seat[, surp_early := if (sum(!is.na(p_early)) > 20) early - predict(lm(early ~ p_early + p_postal), .SD) else NA_real_, by = election]
seat[, surp_postal := if (sum(!is.na(p_postal)) > 20) postal - predict(lm(postal ~ p_early + p_postal), .SD) else NA_real_, by = election]

# party lean by vote type at an election: share within the type minus share overall
pt4 <- pt[, .(votes = sum(votes)), by = .(election, seat, party, type)]
lean_seat <- pt4[, .(party, votes, tv = sum(votes)), by = .(election, seat, type)]
lean_seat <- merge(lean_seat, pt4[, .(pv = sum(votes)), by = .(election, seat, party)], by = c("election", "seat", "party"))
lean_seat[, sv := sum(votes), by = .(election, seat)]
lean_seat[, lean := 100 * (votes / tv - pv / sv)]
lean_st <- pt4[, .(votes = sum(votes)), by = .(election, party, type)]
lean_st[, tv := sum(votes), by = .(election, type)]
lean_st[, `:=`(pv = sum(votes)), by = .(election, party)]
lean_st[, sv := sum(votes) / uniqueN(type), by = election]
lean_st[, st_lean := 100 * (votes / tv - pv / sum(unique(tv))), by = election]

mix <- melt(seat[, .(election, prev_el, seat, early = early_sh, postal = postal_sh,
                     ordinary = ordinary / tot, other = other / tot)],
            id.vars = c("election", "prev_el", "seat"), variable.name = "type", value.name = "mix_now")
mix[, type := as.character(type)]
pmix <- mix[, .(prev_el = election, seat, type, mix_prev = mix_now)]
mix <- merge(mix, pmix, by = c("prev_el", "seat", "type"), all.x = TRUE)

D <- merge(pred, seat, by = c("election", "seat"))
# composition: change in the vote-type mix times each type's lean last time
cs <- merge(mix, lean_seat[, .(prev_el = election, seat, type, party, lean)],
            by = c("prev_el", "seat", "type"), allow.cartesian = TRUE)
cs <- cs[, .(comp_seat = sum((mix_now - mix_prev) * lean)), by = .(election, seat, party)]
cst <- merge(mix, lean_st[, .(prev_el = election, type, party, st_lean)],
             by = c("prev_el", "type"), allow.cartesian = TRUE)
cst <- cst[, .(comp_state = sum((mix_now - mix_prev) * st_lean),
               comp_level = sum(mix_now * st_lean)), by = .(election, seat, party)]
D <- merge(D, cs, by = c("election", "seat", "party"), all.x = TRUE)
D <- merge(D, cst, by = c("election", "seat", "party"), all.x = TRUE)
D[, gov := GOV[election]]
D[, gov_sign := fifelse(party == gov, 1, fifelse(party %in% c("ALP", "LNP"), -1, 0))]
ind <- D[party == "IND", .(election, seat, ind_ours = ours)]
D <- merge(D, ind, by = c("election", "seat"), all.x = TRUE)
D[, held := prev_share == max(prev_share), by = .(election, seat)]

# round 2: z-scores within election, so a slope learned when 10% voted early
# still means something when 50% do
zs <- function(v) (v - mean(v, na.rm = TRUE)) / sd(v, na.rm = TRUE)
D[, `:=`(z_early = zs(early), z_postal = zs(postal), z_prev_early = zs(p_early),
         z_prev_postal = zs(p_postal), z_surp_early = zs(surp_early),
         z_surp_postal = zs(surp_postal)), by = .(election, party)]
if (!FINAL) D <- D[!(election %in% HOLDOUT)]
cat(sprintf("EVS1 %s: %d elections, %d seat-elections, %d seat-party rows\n",
            if (FINAL) "FINAL (holdout included)" else "development (holdout vic2022, fed2025 unread)",
            uniqueN(D$election), uniqueN(D[, .(election, seat)]), nrow(D)))
print(D[party == "ALP", .(seats = .N, with_prev = sum(!is.na(d_early)), when = round(when[1], 2),
                          rmse_alp = round(sqrt(mean(miss^2)), 2)), by = election][order(when)])

# ---- ideas: each returns one number per row of D ---------------------------
IDEAS <- list(
  early_level   = function(d) d$early,          # share of votes cast early in person
  postal_level  = function(d) d$postal,
  d_early       = function(d) d$d_early,        # change since last election
  d_postal      = function(d) d$d_postal,
  surp_early    = function(d) d$surp_early,     # beyond what last time's rate predicts
  surp_postal   = function(d) d$surp_postal,
  comp_seat     = function(d) d$comp_seat,      # mix change x this seat's lean by type last time
  comp_state    = function(d) d$comp_state,     # mix change x statewide lean by type last time
  comp_level    = function(d) d$comp_level,     # mix now x statewide lean by type last time
  surp_early_gov  = function(d) d$surp_early * d$gov_sign,   # early surge against/for the government
  surp_postal_gov = function(d) d$surp_postal * d$gov_sign,
  surp_early_ind  = function(d) d$surp_early * (d$ind_ours >= 10),  # early surge where an independent is live
  surp_early_held = function(d) d$surp_early * fifelse(d$held, 1, -1), # early surge for/against the holder
  z_early       = function(d) d$z_early,        # this election's early share, ranked within election
  z_postal      = function(d) d$z_postal,
  z_prev_early  = function(d) d$z_prev_early,   # LAST election's share: a seat trait, known months out
  z_prev_postal = function(d) d$z_prev_postal,
  z_surp_early  = function(d) d$z_surp_early,   # what is new this election beyond the seat trait
  z_surp_postal = function(d) d$z_surp_postal
)
if (length(ONLY)) IDEAS <- IDEAS[grepl(ONLY, names(IDEAS))]
TARGETS <- c("ALP", "LNP", "GRN", "IND", "ONP", "OTH_RIGHT")

tf_score <- function(f, r, el, when) {
  # centred within election; slope from strictly earlier elections
  ok <- is.finite(f) & is.finite(r)
  f <- f[ok]; r <- r[ok]; el <- el[ok]; when <- when[ok]
  f <- f - ave(f, el); r <- r - ave(r, el)
  ue <- unique(data.table(el, when))[order(when)]
  out <- lapply(seq_len(nrow(ue)), function(i) {
    tr <- when < ue$when[i]; te <- el == ue$el[i]
    if (uniqueN(el[tr]) < 2 || sum(tr) < 100) return(NULL)
    b <- sum(f[tr] * r[tr]) / sum(f[tr]^2)
    data.table(el = ue$el[i], n = sum(te), b = b,
               d = mean((r[te] - b * f[te])^2) - mean(r[te]^2), base = mean(r[te]^2))
  })
  out <- rbindlist(out)
  list(per = out, r = cor(f, r), n = length(f), n_el = uniqueN(el))
}

res <- rbindlist(lapply(names(IDEAS), function(nm) {
  rbindlist(lapply(TARGETS, function(tg) {
    d <- D[party == tg]
    f <- IDEAS[[nm]](d)
    if (sum(is.finite(f)) < 200 || sd(f, na.rm = TRUE) == 0) return(NULL)
    s <- tf_score(f, d$miss, d$election, d$when)
    if (is.null(s$per) || nrow(s$per) < 3) return(NULL)
    obs <- mean(s$per$d)
    pl <- vapply(seq_len(N_PERM), function(k) {
      fp <- ave(f, d$election, FUN = function(v) { i <- which(is.finite(v)); v[i] <- v[i][sample.int(length(i))]; v })
      mean(tf_score(fp, d$miss, d$election, d$when)$per$d)
    }, numeric(1))
    data.table(idea = nm, target = tg, seats = s$n, r_in = round(s$r, 3),
               tested_el = nrow(s$per), better_el = sum(s$per$d < 0),
               rmse_base = round(sqrt(mean(s$per$base)), 2),
               d_mse = round(obs, 3), se = round(sd(s$per$d) / sqrt(nrow(s$per)), 3),
               pct = round(100 * obs / mean(s$per$base), 2),
               placebo_p = round(mean(pl <= obs), 3),
               same_sign = max(sum(s$per$b > 0), sum(s$per$b < 0)))
  }))
}))
setorder(res, d_mse)
cat("\nEVS2 Every idea x party. d_mse = change in squared miss (points^2) when the feature corrects the\n",
    "prediction, slope from earlier elections only. NEGATIVE IS BETTER. pct = that change as % of the\n",
    "model's squared miss. placebo_p = share of 200 shuffles doing at least as well (under 0.05 is unusual).\n",
    "better_el of tested_el = elections improved. r_in = in-sample correlation of feature with the miss.\n", sep = "")
print(res, nrows = 200)
k <- nrow(res)
cat(sprintf("\nEVS3 %d tests run. Expected by chance with placebo_p < 0.05: %.1f. Observed: %d. With d_mse < 0 and placebo_p < 0.05: %d\n",
            k, 0.05 * k, sum(res$placebo_p < 0.05), sum(res$placebo_p < 0.05 & res$d_mse < 0)))
cat(sprintf("EVS4 smallest correlation this panel can see at about 2 SE: %.3f (n = %d seats per party)\n",
            2 / sqrt(median(res$seats)), as.integer(median(res$seats))))
dir.create("output/early-vote", showWarnings = FALSE)
fwrite(res, sprintf("output/early-vote/screen-%s%s.csv", if (FINAL) "final" else "dev", if (length(ONLY)) paste0("-", gsub("[^a-z_]", "", ONLY)) else ""))

suppressPackageStartupMessages(library(data.table))
# ---- Scout B: election night. Once the ordinary (on-the-day) votes are counted, how well can the
# final primary share be projected, and how much does knowing the TRUE early/postal volume help? ----
pt <- fread("output/early-vote/panel-party.csv", encoding = "UTF-8")[party != "UNMATCHED"]
seat <- fread("output/early-vote/panel-seat.csv", encoding = "UTF-8")
els <- unique(seat[, .(election, juris, year)])[order(juris, year)]; els[, prev_el := shift(election), by = juris]
sh <- pt[, .(votes = sum(votes)), by = .(election, seat, party, type)]
sh[, tv := sum(votes), by = .(election, seat, type)]; sh[, s := votes / tv]
full <- CJ(election = unique(sh$election), type = c("ordinary", "early", "postal", "other"))
key <- unique(sh[, .(election, seat, party)]); key <- key[, .(type = c("ordinary", "early", "postal", "other")), by = .(election, seat, party)]
sh <- merge(key, sh[, .(election, seat, party, type, s)], by = c("election", "seat", "party", "type"), all.x = TRUE); sh[is.na(s), s := 0]
mix <- unique(pt[, .(tv = sum(votes)), by = .(election, seat, type)]); mix[, w := tv / sum(tv), by = .(election, seat)]
fin <- pt[, .(v = sum(votes)), by = .(election, seat, party)]; fin[, final := 100 * v / sum(v), by = .(election, seat)]
W <- dcast(sh, election + seat + party ~ type, value.var = "s")
W <- merge(W, els[, .(election, prev_el)], by = "election")
P <- copy(W)[, .(prev_el = election, seat, party, p_ord = ordinary, p_early = early, p_postal = postal, p_other = other)]
W <- merge(W, P, by = c("prev_el", "seat", "party"))
mw <- dcast(mix, election + seat ~ type, value.var = "w", fill = 0); setnames(mw, c("early", "ordinary", "other", "postal"), c("w_early", "w_ord", "w_other", "w_postal"))
W <- merge(W, mw, by = c("election", "seat"))
pm <- copy(mw)[, .(prev_el = election, seat, pw_early = w_early, pw_ord = w_ord, pw_other = w_other, pw_postal = w_postal)]
W <- merge(W, pm, by = c("prev_el", "seat"))
W <- merge(W, fin[, .(election, seat, party, final)], by = c("election", "seat", "party"))
W[, `:=`(e_early = pmin(1, pmax(0, ordinary + p_early - p_ord)), e_postal = pmin(1, pmax(0, ordinary + p_postal - p_ord)), e_other = pmin(1, pmax(0, ordinary + p_other - p_ord)))]
W[, `:=`(naive = 100 * ordinary,
         gap_prevmix = 100 * (pw_ord * ordinary + pw_early * e_early + pw_postal * e_postal + pw_other * e_other),
         gap_truemix = 100 * (w_ord * ordinary + w_early * e_early + w_postal * e_postal + w_other * e_other))]
W <- W[party %in% c("ALP", "LNP", "GRN", "ONP", "IND")]
r <- function(p, a) round(sqrt(mean((p - a)^2)), 3)
cat(sprintf("SCOUT B. %d elections, %d seat-elections, %d party rows (same seat and party at the previous election).\n", uniqueN(W$election), uniqueN(W[, .(election, seat)]), nrow(W)))
cat("RMSE in points of the projected FINAL primary share once on-the-day votes are counted. LOWER IS BETTER.\n",
    "naive = on-the-day share as is; gap_prevmix = add last election's early/postal lean, weighted by LAST election's vote-type mix;\n",
    "gap_truemix = the same lean weighted by THIS election's true mix (what the commission's early and postal counts tell us).\n", sep = "")
print(W[, .(rows = .N, naive = r(naive, final), gap_prevmix = r(gap_prevmix, final), gap_truemix = r(gap_truemix, final)), by = party])
pe <- W[, .(rows = .N, naive = r(naive, final), gap_prevmix = r(gap_prevmix, final), gap_truemix = r(gap_truemix, final)), by = election][order(election)]
print(pe)
dd <- W[, .(d = mean((gap_truemix - final)^2) - mean((gap_prevmix - final)^2)), by = election]
cat(sprintf("true mix vs previous mix, change in squared error per election: %+.4f (SE %.4f, %d of %d elections better)\n", mean(dd$d), sd(dd$d) / sqrt(nrow(dd)), sum(dd$d < 0), nrow(dd)))
cat(sprintf("how much the mix itself moves: mean absolute change in a seat's early share between elections %.1f points; postal %.1f\n",
            100 * mean(abs(W[party == "ALP"]$w_early - W[party == "ALP"]$pw_early)), 100 * mean(abs(W[party == "ALP"]$w_postal - W[party == "ALP"]$pw_postal))))

# ---- Scout C: postal vote APPLICATIONS (federal). 2016 and 2019 files say which channel each application came
# through, including each party's own postal-vote mail-out. 2022 and 2025 give totals and returns. ----
d <- "external/reference/aec/prepoll-daily"
pred <- fread("output/published-predictions.csv", encoding = "UTF-8")[grepl("^fed", pair), .(ours = sum(ours), actual = sum(actual)), by = .(election = pair, seat, party)]
pred[, miss := actual - ours]; pred[, k := toupper(seat)]
tot <- seat[grepl("^fed", election), .(election, k = toupper(seat), tot)]
rd <- function(f, el) { x <- fread(file.path(d, f), encoding = "UTF-8", header = TRUE); setnames(x, 1:2, c("st", "k")); x[, election := el]
  num <- function(n) if (n %in% names(x)) as.numeric(fifelse(is.na(x[[n]]), 0, as.numeric(x[[n]]))) else 0
  x[, .(election, k = toupper(k), alp = num("ALP"), lnp = num("LIB") + num("LNP") + num("NAT") + num("CLP"), grn = num("GRN"),
        aec = num("AEC - OPVA") + num("AEC - Paper"), gpv = num("GPV"))] }
A <- rbind(rd("20160702_WEB_Postal_Report.csv", "fed2016"), rd("20190518_WEB_Postal_Report_FE2019.csv", "fed2019"))
A <- merge(A, tot, by = c("election", "k"))
A[, `:=`(alp_r = 100 * alp / tot, lnp_r = 100 * lnp / tot, net_r = 100 * (alp - lnp) / tot, all_r = 100 * (alp + lnp + grn + aec + gpv) / tot)]
cat(sprintf("\nSCOUT C. Party postal mail-outs, fed2016 and fed2019: %d divisions matched of %d. Applications through Labor's form: %d and %d; through the Coalition's: %d and %d.\n",
            nrow(A), 301L, A[election == "fed2016", sum(alp)], A[election == "fed2019", sum(alp)], A[election == "fed2016", sum(lnp)], A[election == "fed2019", sum(lnp)]))
J <- merge(pred, A, by = c("election", "k"))
cat("Within-election correlation with our miss (actual - predicted primary). alp_r / lnp_r = applications through that party's form as % of votes;\n",
    "net_r = Labor's minus the Coalition's. About +-0.16 is 2 SE for one election of 150 seats.\n", sep = "")
o <- rbindlist(lapply(c("alp_r", "lnp_r", "net_r", "all_r"), function(f) rbindlist(lapply(c("ALP", "LNP", "GRN", "IND"), function(tg) {
  x <- J[party == tg]; x[, `:=`(fz = get(f) - mean(get(f)), m = miss - mean(miss)), by = election]
  data.table(feature = f, miss_of = tg, seats = nrow(x), pooled_r = round(cor(x$fz, x$m), 3), r2016 = round(x[election == "fed2016", cor(fz, m)], 2), r2019 = round(x[election == "fed2019", cor(fz, m)], 2)) }))))
print(o)
# totals and returns, 2022 and 2025
rt <- function(f, el) { x <- fread(file.path(d, f), encoding = "UTF-8"); setnames(x, c("st", "k", "apps", "ret")); x[, .(election = el, k = toupper(k), apps = as.numeric(apps), ret = as.numeric(ret))] }
Bq <- merge(rbind(rt("Postal-votes-220603.csv", "fed2022"), rt("Postal-votes-250521.csv", "fed2025")), tot, by = c("election", "k"))
Bq[, `:=`(app_r = 100 * apps / tot, ret_r = 100 * ret / apps)]
J2 <- merge(pred, Bq, by = c("election", "k"))
cat(sprintf("\nPostal totals, fed2022 and fed2025: %d divisions matched. app_r = applications as %% of votes; ret_r = %% of applications returned.\n", nrow(Bq)))
o2 <- rbindlist(lapply(c("app_r", "ret_r"), function(f) rbindlist(lapply(c("ALP", "LNP", "GRN", "IND", "ONP"), function(tg) {
  x <- J2[party == tg]; x[, `:=`(fz = get(f) - mean(get(f)), m = miss - mean(miss)), by = election]
  data.table(feature = f, miss_of = tg, seats = nrow(x), pooled_r = round(cor(x$fz, x$m), 3), r2022 = round(x[election == "fed2022", cor(fz, m)], 2), r2025 = round(x[election == "fed2025", cor(fz, m)], 2)) }))))
print(o2)

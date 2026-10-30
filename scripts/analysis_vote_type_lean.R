# Is a seat's vote-type lean (postal/absent/provisional/pre-poll-declaration vs ordinary)
# stable enough between federal elections to predict?  Review: docs/reviews/vote-type-lean-2026-10-30.md
# Reads external/reference/aec/fed{Y}-firstprefs.csv and -tcp.csv (2004-2025). Writes tables to SCRATCH.
# Run from the repo root.
suppressMessages(library(data.table))
source("R/parties.R")
SCRATCH <- "C:/Users/peteo/AppData/Local/Temp/claude/C--dev-auspol/d9620856-015e-4f5d-8963-ed4e84fea399/scratchpad/votetype"
dir.create(SCRATCH, showWarnings = FALSE, recursive = TRUE)
YEARS <- c(2004, 2007, 2010, 2013, 2016, 2019, 2022, 2025)
VT <- c(Absent = "AbsentVotes", Provisional = "ProvisionalVotes", PrePoll = "PrePollVotes", Postal = "PostalVotes")
MINV <- c(Absent = 300, Provisional = 100, PrePoll = 300, Postal = 300)  # min formal votes of that type in a division
CLS <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH")
out <- file.path(SCRATCH, "tables.md"); cat("", file = out)
emit <- function(...) { s <- paste0(..., collapse = ""); cat(s, "\n"); cat(s, "\n", file = out, append = TRUE) }
tab <- function(d, digits = 3) {
  d <- as.data.frame(d)
  for (j in seq_along(d)) if (is.numeric(d[[j]])) d[[j]] <- ifelse(is.na(d[[j]]), "NA", format(round(d[[j]], digits), nsmall = 0, trim = TRUE))
  emit("| ", paste(names(d), collapse = " | "), " |"); emit("|", paste(rep("---", ncol(d)), collapse = "|"), "|")
  for (i in seq_len(nrow(d))) emit("| ", paste(unlist(d[i, ]), collapse = " | "), " |")
  emit("")
}

rd <- function(kind, y) {
  f <- sprintf("external/reference/aec/fed%d-%s.csv", y, kind)
  x <- fread(f, skip = 1, showProgress = FALSE)
  x[, elec := y]
  x[, cls := classify_party(PartyNm, PartyAb)]
  x[, cls := ifelse(cls %in% c("ALP", "LNP", "GRN", "ONP", "IND"), cls, "OTH")]
  x[, div := toupper(trimws(DivisionNm))]
  x[, person := paste(toupper(trimws(Surname)), toupper(sub(" .*", "", trimws(GivenNm))))]
  x[, c("StateAb", "div", "elec", "cls", "person", "PartyAb", "OrdinaryVotes", "AbsentVotes", "ProvisionalVotes", "PrePollVotes", "PostalVotes", "TotalVotes"), with = FALSE]
}
FP <- rbindlist(lapply(YEARS, function(y) rd("firstprefs", y)))
TCP <- rbindlist(lapply(YEARS, function(y) rd("tcp", y)))
emit("Loaded FP rows ", nrow(FP), " (", uniqueN(FP[, .(elec, div)]), " division-elections); TCP rows ", nrow(TCP), " (", uniqueN(TCP[, .(elec, div)]), ")")
print(FP[, .(rows = .N, divs = uniqueN(div), tot = sum(TotalVotes)), by = elec])
print(TCP[, .(rows = .N, divs = uniqueN(div), tot = sum(TotalVotes)), by = elec])
stopifnot(FP[, all(OrdinaryVotes + AbsentVotes + ProvisionalVotes + PrePollVotes + PostalVotes == TotalVotes)])
stopifnot(TCP[, all(OrdinaryVotes + AbsentVotes + ProvisionalVotes + PrePollVotes + PostalVotes == TotalVotes)])
print(FP[, .N, by = cls])

# ---- long gap table at a given grain (key column name 'key') ----
mk_long <- function(D, keycol) {
  D <- copy(D); setnames(D, keycol, "key")
  g <- D[, lapply(.SD, sum), by = .(elec, div, key), .SDcols = c("OrdinaryVotes", unname(VT))]
  tot <- D[, lapply(.SD, sum), by = .(elec, div), .SDcols = c("OrdinaryVotes", unname(VT))]
  setnames(tot, c("OrdinaryVotes", unname(VT)), paste0("T_", c("Ordinary", names(VT))))
  g <- merge(g, tot, by = c("elec", "div"))
  g[, ord_share := 100 * OrdinaryVotes / T_Ordinary]
  L <- rbindlist(lapply(names(VT), function(v) {
    r <- data.table(elec = g$elec, div = g$div, kk = g$key, vt = v, votes = g[[VT[[v]]]], vt_total = g[[paste0("T_", v)]],
               ord_share = g$ord_share, ord_votes = g$OrdinaryVotes, ord_total = g$T_Ordinary)
    setnames(r, "kk", "key")  # a column called key collides with data.table()'s key= argument
    r
  }))
  L[, share := ifelse(vt_total >= MINV[vt], 100 * votes / vt_total, NA_real_)]
  L[, gap := share - ord_share]
  L
}
FPL <- mk_long(FP, "cls")
TCPc <- copy(TCP)
dupcls <- TCPc[, .(n = .N, u = uniqueN(cls)), by = .(elec, div)][u < n]
emit("TCP division-elections dropped because both finalists share a class: ", nrow(dupcls), " of ", uniqueN(TCP[, .(elec, div)]))
TCPk <- TCP[!dupcls, on = .(elec, div)]
TCPL <- mk_long(TCPk, "cls")
PL <- mk_long(FP, "person")

nat <- function(L) {
  L[!is.na(share), .(nat_gap = 100 * (sum(votes) / sum(vt_total) - sum(ord_votes) / sum(ord_total)), nd = .N), by = .(elec, key, vt)]
}
addnat <- function(L) {
  L <- merge(L, nat(L), by = c("elec", "key", "vt"), all.x = TRUE)
  L[, dev := gap - nat_gap]
  L
}
FPL <- addnat(FPL); TCPL <- addnat(TCPL); PL <- addnat(PL)
st <- unique(FP[, .(elec, div, st = StateAb)])
FPL <- merge(FPL, st, by = c("elec", "div"), all.x = TRUE)
FPL[, st_gap := mean(gap, na.rm = TRUE), by = .(elec, key, vt, st)]
FPL[, dev_st := gap - st_gap]

emit("\n## national gap by election (points, vote-type share minus ordinary share, vote-weighted)")
ng <- dcast(nat(FPL)[key %in% c("ALP", "LNP", "GRN", "ONP", "IND")], key + vt ~ elec, value.var = "nat_gap")
tab(ng[order(vt, key)], 2)
vs <- FP[, .(ord = sum(OrdinaryVotes), Absent = sum(AbsentVotes), Provisional = sum(ProvisionalVotes), PrePoll = sum(PrePollVotes), Postal = sum(PostalVotes)), by = elec]
vs[, c("Absent", "Provisional", "PrePoll", "Postal") := lapply(.SD, function(x) 100 * x / (ord + Absent + Provisional + PrePoll + Postal)), .SDcols = c("Absent", "Provisional", "PrePoll", "Postal")]
emit("\n## share of all formal votes by type (percent)"); tab(vs[, !"ord"], 1)

# ---- stability ----
prevpairs <- function(L, extra = character()) {
  a <- L[, c("elec", "div", "key", "vt", "gap", "dev", "votes", "vt_total", extra), with = FALSE]
  b <- copy(a); b[, elec := YEARS[match(elec, YEARS) + 1L]]
  b <- b[!is.na(elec)]
  setnames(b, c("gap", "dev", "votes", "vt_total", extra), paste0("p_", c("gap", "dev", "votes", "vt_total", extra)))
  merge(a, b, by = c("elec", "div", "key", "vt"))
}
fitstats <- function(d, x, y) {
  d <- d[!is.na(d[[x]]) & !is.na(d[[y]])]
  if (nrow(d) < 10) return(data.table(n = nrow(d), cor = NA_real_, slope = NA_real_, slope_se = NA_real_))
  m <- lm(d[[y]] ~ d[[x]]); s <- summary(m)$coefficients
  data.table(n = nrow(d), cor = cor(d[[x]], d[[y]]), slope = s[2, 1], slope_se = s[2, 2])
}
PP <- prevpairs(FPL, c("dev_st", "st_gap")); PP <- PP[key %in% CLS]
emit("\n## Stability of the first-preference gap, t-1 to t, same division and class (all 7 election pairs pooled)")
emit("Each row: correlation and regression slope of the gap at election t on the gap at t-1, same division and party class. total = raw gap; seat-specific = gap minus that election's national gap for the class; state removed = minus the state mean instead. n = division-class pairs. Higher cor/slope = more stable; 1 = perfectly persistent.")
st1 <- rbindlist(lapply(names(VT), function(v) {
  d <- PP[vt == v]
  rbind(cbind(vt = v, component = "total", fitstats(d, "p_gap", "gap")),
        cbind(vt = v, component = "seat-specific (national removed)", fitstats(d, "p_dev", "dev")),
        cbind(vt = v, component = "seat-specific (state removed)", fitstats(d, "p_dev_st", "dev_st")))
}))
tab(st1, 3)
emit("\n### by class, seat-specific component (national removed)")
st2 <- rbindlist(lapply(names(VT), function(v) rbindlist(lapply(CLS, function(k) {
  cbind(vt = v, cls = k, fitstats(PP[vt == v & key == k], "p_dev", "dev"))
}))))
tab(st2, 3)
emit("\n### correlation by election pair, seat-specific component, all classes pooled")
st3 <- rbindlist(lapply(names(VT), function(v) rbindlist(lapply(YEARS[-1], function(y) {
  cbind(vt = v, pair = paste0(YEARS[match(y, YEARS) - 1], "->", y), fitstats(PP[vt == v & elec == y], "p_dev", "dev"))
}))))
tab(dcast(st3, vt ~ pair, value.var = "cor"), 2)

# ---- person-level ----
PPp <- prevpairs(PL)
cls_of <- unique(FP[, .(elec, div, key = person, cls)])
PPp <- merge(PPp, cls_of, by = c("elec", "div", "key"))
cg <- FPL[, .(elec, div, cls = key, vt, cgap = gap, cdev = dev)]
cgp <- copy(cg); cgp[, elec := YEARS[match(elec, YEARS) + 1L]]; cgp <- cgp[!is.na(elec)]
setnames(cgp, c("cgap", "cdev"), c("p_cgap", "p_cdev"))
PPp <- merge(PPp, cg, by = c("elec", "div", "cls", "vt")); PPp <- merge(PPp, cgp, by = c("elec", "div", "cls", "vt"))
# a person's own 'national gap' is meaningless (group of one, dev would be 0): centre on the CLASS national gap
ncl <- nat(FPL)[, .(elec, cls = key, vt, ng_c = nat_gap)]
ncp <- copy(ncl); ncp[, elec := YEARS[match(elec, YEARS) + 1L]]; ncp <- ncp[!is.na(elec)]; setnames(ncp, "ng_c", "p_ng_c")
PPp <- merge(PPp, ncl, by = c("elec", "cls", "vt")); PPp <- merge(PPp, ncp, by = c("elec", "cls", "vt"))
PPp[, `:=`(dev = gap - ng_c, p_dev = p_gap - p_ng_c)]
PPp <- PPp[!is.na(gap) & !is.na(p_gap) & !is.na(cgap) & !is.na(p_cgap)]
emit("\n## Person vs party class: the same recontesting candidate in the same division at t-1 and t")
emit("Rows are candidates who stood in the same division at both elections (n). cor_person = correlation of that person's own gap across the two elections; cor_class = correlation of their party-class gap in that division over the same rows. Both on the seat-specific component. Higher = more persistent. Person key is surname + first given name within the division.")
pr <- rbindlist(lapply(names(VT), function(v) rbindlist(lapply(c("ALL", "IND", "ALP", "LNP", "GRN"), function(k) {
  d <- PPp[vt == v & (k == "ALL" | cls == k)]
  if (nrow(d) < 10) return(NULL)
  data.table(vt = v, cls = k, n = nrow(d),
             cor_person = cor(d$p_dev, d$dev), cor_class = cor(d$p_cdev, d$cdev))
}))))
tab(pr, 3)

# ---- prediction ----
build_pred <- function(L) {
  L <- L[key %in% CLS]
  lagdev <- function(k) { x <- L[, .(elec = YEARS[match(elec, YEARS) + k], div, key, vt, d = dev)]; x[!is.na(elec)] }
  l1 <- lagdev(1); setnames(l1, "d", "f1"); l2 <- lagdev(2); setnames(l2, "d", "f2")
  n1 <- unique(L[, .(elec = YEARS[match(elec, YEARS) + 1L], key, vt, nat1 = nat_gap)])[!is.na(elec)]
  X <- merge(L, l1, by = c("elec", "div", "key", "vt"), all.x = TRUE)
  X <- merge(X, l2, by = c("elec", "div", "key", "vt"), all.x = TRUE)
  X <- merge(X, n1, by = c("elec", "key", "vt"), all.x = TRUE)
  X[, f12 := ifelse(!is.na(f1) & !is.na(f2), (f1 + f2) / 2, f1)]
  X
}
slope_for <- function(X, tt, v, feat) {
  d <- X[X$elec < tt & X$vt == v & !is.na(X[[feat]]) & !is.na(X$dev)]
  if (nrow(d) < 30) return(NA_real_)
  unname(coef(lm(d$dev ~ 0 + d[[feat]]))[1])  # through origin: dev is already centred by the national gap
}
predict_all <- function(X, targets = c(2022, 2025)) {
  rbindlist(lapply(targets, function(tt) rbindlist(lapply(names(VT), function(v) {
    d <- X[X$elec == tt & X$vt == v & !is.na(X$share)]
    s1 <- slope_for(X, tt, v, "f1"); s12 <- slope_for(X, tt, v, "f12")
    d[, `:=`(slope1 = s1, slope12 = s12)]
    d[, pa := ord_share]
    d[, pb := ord_share + ifelse(is.na(nat1), 0, nat1)]
    d[, pc := pb + ifelse(is.na(f1), 0, s1 * f1)]
    d[, pc2 := pb + ifelse(is.na(f12), 0, s12 * f12)]
    d[, pd := ord_share + nat_gap + ifelse(is.na(f1), 0, s1 * f1)]
    d[, pe := ord_share + nat_gap]
    d
  }))))
}
rm_ <- function(e) sqrt(mean(e^2))
score <- function(P, by = c("elec", "vt")) P[, .(n = .N, n_with_prev = sum(!is.na(f1)), `a ordinary only` = rm_(pa - share), `b + national gap t-1` = rm_(pb - share),
         `c + seat gap t-1 (shrunk)` = rm_(pc - share), `c2 + seat gaps t-1,t-2` = rm_(pc2 - share),
         `diag e: oracle nat. gap` = rm_(pe - share), `diag d: oracle nat. + seat` = rm_(pd - share), slope1 = slope1[1]), by = by]
FX <- build_pred(FPL); FPred <- predict_all(FX)
emit("\n## Prediction of the final vote-type share of a class in a division, FIRST PREFERENCES, all classes pooled")
emit("RMSE in percentage points of the class's share within that vote type, over division-class pairs where the type had enough votes (min 300; provisional 100). Lower is better. a = ordinary share, b = + last election's national gap, c = + seat-specific gap shrunk by a slope fitted on earlier elections only (slope1 column), c2 = same using the mean of the last two elections. The two diag columns use the real national gap of the target election (not knowable on the night; they show how much error is national level rather than seat).")
tab(score(FPred)[order(vt, elec)], 3)
emit("\n### first preferences, by class (pooled over 2022 and 2025)")
tab(score(FPred, c("vt", "key"))[order(vt, key)][, !"slope1"], 3)
emit("\n### spread of the thing being predicted: SD and mean of (final vote-type share minus ordinary share), points")
tab(FPred[, .(n = .N, sd_gap = sd(share - ord_share), mean_gap = mean(share - ord_share)), by = .(elec, vt)][order(vt, elec)], 2)

TX <- build_pred(TCPL); TPred <- predict_all(TX)
lead <- TCPk[, .(ordv = sum(OrdinaryVotes)), by = .(elec, div, cls)][order(-ordv), .SD[1], by = .(elec, div)][, .(elec, div, key = cls)]
TPredL <- merge(TPred, lead, by = c("elec", "div", "key"))
emit("\n## Prediction of the final vote-type share of the ordinary-count LEADER, two-candidate preferred")
emit("Same predictors, target = share of the two-candidate vote in that vote type won by whoever leads the ordinary count. RMSE in points; lower is better. Divisions where both finalists share a class are excluded.")
tab(score(TPredL)[order(vt, elec)], 3)
emit("\n### spread of TCP leader gap (final vote-type share minus ordinary share), points")
tab(TPredL[, .(n = .N, sd_gap = sd(share - ord_share), mean_gap = mean(share - ord_share)), by = .(elec, vt)][order(vt, elec)], 2)

# ---- leader flips ----
fl <- TCPk[, .(ord = sum(OrdinaryVotes), tot = sum(TotalVotes)), by = .(elec, div, cls, person)]
fl[, `:=`(ord_lead = ord == max(ord), fin_lead = tot == max(tot)), by = .(elec, div)]
flips <- fl[ord_lead == TRUE][, .(elec, div, key = cls, flipped = !fin_lead)]
emit("\n## TCP leader changes between the ordinary-only count and the final count")
emit("Counts of divisions. flipped = the candidate leading on ordinary votes alone did not finish first. n_div excludes divisions where the finalists share a class.")
tab(flips[, .(n_div = .N, flipped = sum(flipped)), by = elec], 0)
print(flips[flipped == TRUE])
allv <- TCPL[key %in% CLS][, .(elec, div, key, vt, vt_total, ord_total, ord_votes, votes)]
pp <- merge(allv, TPred[, .(elec, div, key, vt, pa, pb, pc, pc2, pd, pe)], by = c("elec", "div", "key", "vt"), all.x = TRUE)
pp <- merge(pp, lead, by = c("elec", "div", "key"))
nfill <- pp[elec %in% c(2022, 2025), sum(is.na(pa))]
emit("Type-cells with too few votes to predict, filled with the actual share (negligible volume): ", nfill)
for (m in c("pa", "pb", "pc", "pc2", "pd", "pe")) pp[is.na(get(m)), (m) := 100 * votes / pmax(vt_total, 1)]
fin <- function(p) (pp_ord + sum(pp_vt * p / 100)) / (pp_ordt + sum(pp_vt))
ff <- pp[elec %in% c(2022, 2025), {
  o <- ord_votes[1]; ot <- ord_total[1]; tt <- ot + sum(vt_total)
  list(ordshare = 100 * o / ot, actual = 100 * (o + sum(votes)) / tt,
       fa = 100 * (o + sum(vt_total * pa / 100)) / tt, fb = 100 * (o + sum(vt_total * pb / 100)) / tt,
       fc = 100 * (o + sum(vt_total * pc / 100)) / tt, fc2 = 100 * (o + sum(vt_total * pc2 / 100)) / tt,
       fe = 100 * (o + sum(vt_total * pe / 100)) / tt)
}, by = .(elec, div, key)]
ff <- merge(ff, flips, by = c("elec", "div", "key"))
emit("\n## Final TCP share of the ordinary leader, whole division, predicted from ordinary share plus predicted declaration-vote shares")
emit("Uses the REAL volume of each vote type (an oracle; on the night volumes are uncertain) and swaps in the predicted share per declaration type. RMSE of the leader's final two-candidate percentage, points; lower is better. 'ordinary share unchanged' = the leader's ordinary share taken as the final answer. diag e = real national gap of that election added (not knowable on the night).")
tab(ff[, .(n = .N, `ordinary share unchanged` = rm_(ordshare - actual), `b nat gap t-1` = rm_(fb - actual), `c seat+nat` = rm_(fc - actual), `c2 two-election` = rm_(fc2 - actual), `diag e oracle nat` = rm_(fe - actual)), by = elec], 3)
emit("Flip detection: flips = divisions where the ordinary leader lost; caught_x = of those, how many method x puts under 50%; false_x = divisions where the leader held but method x put them under 50%.")
tab(ff[, .(n = .N, flips = sum(flipped), caught_b = sum(flipped & fb < 50), caught_c = sum(flipped & fc < 50), caught_c2 = sum(flipped & fc2 < 50), caught_oracle_nat = sum(flipped & fe < 50),
           false_b = sum(!flipped & fb < 50), false_c = sum(!flipped & fc < 50), false_c2 = sum(!flipped & fc2 < 50), false_oracle_nat = sum(!flipped & fe < 50)), by = elec], 0)
emit("\n### the divisions that flipped: ordinary leader share, actual final, and predictions (percent)")
tab(ff[flipped == TRUE, .(elec, div, cls = key, ordinary = ordshare, actual, b = fb, c = fc, c2 = fc2, oracle_nat = fe)][order(elec, div)], 2)
emit("\n### close divisions: ordinary leader within 3 points of 50 (n, flips, mean absolute error in points)")
tab(ff[abs(ordshare - 50) < 3, .(n = .N, flips = sum(flipped), mae_ord = mean(abs(ordshare - actual)), mae_b = mean(abs(fb - actual)), mae_c = mean(abs(fc - actual)), mae_c2 = mean(abs(fc2 - actual))), by = elec], 3)
saveRDS(list(FPred = FPred, TPredL = TPredL, ff = ff, st1 = st1), file.path(SCRATCH, "res.rds"))
emit("done")

# Screen for docs/plans/prereg-leader-approval-miss-2026-10-12.md: does the government leader's approval trend
# (A1, change) or level (A2) predict the government class's final polling miss? Read-only.
# Run: powershell.exe -Command 'Rscript "scripts/screen_leader_approval.R"'   Emits LQ* codes.
# Data.table NSE: masks are built outside [...]; no local shares a column name used inside brackets.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); source("scripts/published_flags.R")
suppressMessages(library(data.table))
for (n in names(PUBLISHED_FLAGS)) if (!nzchar(Sys.getenv(n))) do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[n]]), n))
tab <- fread(out_path("level-recent.csv"), showProgress = FALSE)
LR <- fread(out_path("leader-ratings.csv"), showProgress = FALSE); LR[, date := as.Date(date)]
eds <- election_dates()
ELS <- setdiff(unique(tab$election), c("vic2026", "nsw2027"))
TAU <- 0.05

# government party going into each election: the head of government's party in leaders.csv
ld <- fread(file.path("external", "reference", "leaders", "leaders.csv"), showProgress = FALSE)
gov <- rbindlist(lapply(c(ELS, "vic2026", "nsw2027"), function(e0) {
  d <- ld[ld$election == e0]; h <- unique(d$head_of_govt[nzchar(d$head_of_govt)])[1]
  p <- if (length(h) && !is.na(h)) d$party_clean[d$leader_clean == h][1] else NA_character_
  data.table(e = e0, head = h, party_raw = p, G = if (is.na(p)) NA_character_ else if (grepl("Labor", p)) "ALP" else "LNP")
}))
gov[e %in% c("vic2026", "nsw2027"), G := "ALP"]   # live cycles: not in leaders.csv; Allan/Carroll and Minns govern
print(gov)
if (anyNA(gov$G[gov$e %in% ELS])) stop("LQ0! no government party for: ", paste(gov$e[is.na(gov$G) & gov$e %in% ELS], collapse = ", "))

# shipped day-before level per election (published flags: decay 20 + federal breakdowns 0.15)
base <- rbindlist(lapply(ELS, function(e0) {
  d <- tab[tab$election == e0]; lv <- setNames(d$trend, d$cls)
  if (any(!is.finite(lv[c("ALP", "LNP", "GRN")]))) return(NULL)
  lv <- c(lv[c("ALP", "LNP", "GRN")], OTH = 100 - sum(lv[c("ALP", "LNP", "GRN")]))
  invisible(capture.output(res <- level_recent_apply(lv, e0, d$region[1], as.Date(unname(eds[e0])), code = "LQ", tab = tab)))
  data.table(e = e0, k = names(res), lev = unname(res), actual = c(d$actual[match(c("ALP", "LNP", "GRN"), d$cls)], NA))
}))
cat(sprintf("LQ1 shipped level: %d elections; applies AUSPOL_LEVEL_RECENT=%s HL=%s FED_R=%s\n", uniqueN(base$e),
            Sys.getenv("AUSPOL_LEVEL_RECENT"), Sys.getenv("AUSPOL_LEVEL_RECENT_HALFLIFE"), Sys.getenv("AUSPOL_LEVEL_FED_R")))

# predictors from AE's government-leader approve/disapprove, polls dated before polling day only
ae <- LR[LR$source == "ae"]
aw <- dcast(ae, date + firm + election ~ measure, value.var = "value", fun.aggregate = mean)
aw <- aw[is.finite(aw$approve) & is.finite(aw$disapprove)]; aw[, net := approve - disapprove]
# --pool (prereg Amendment 1, after the first screen): add the Wikipedia satisfaction tables' government-leader
# net satisfaction to AE's series, one reading per poll, so state elections with 1-2 AE polls get more.
if ("--pool" %in% commandArgs(TRUE)) {
  wk <- LR[LR$source == "wikipedia" & LR$measure == "net_sat" & LR$role == "gov", .(date, firm, election, net = value)]
  aw <- rbind(aw[, .(date, firm, election, net)], wk)
  aw <- unique(aw, by = c("date", "firm", "election"))
  cat(sprintf("LQ2p pooled: %d AE readings + %d Wikipedia net-satisfaction readings (same poll counted once)\n",
              sum(LR$source == "ae" & LR$measure == "approve"), nrow(wk)))
}
pred <- rbindlist(lapply(c(ELS, "vic2026", "nsw2027"), function(e0) {
  ed <- as.Date(unname(eds[e0])); aa <- if (ed > Sys.Date()) Sys.Date() else ed
  rg <- sub("[0-9]{4}$", "", e0)
  a <- aw[startsWith(aw$election, rg) & aw$date < aa]       # region's series, any cycle label, before polling day
  stopifnot(all(a$date < aa))
  w1 <- a$net[a$date >= aa - 90]; w0 <- a$net[a$date >= aa - 180 & a$date < aa - 90]
  data.table(e = e0, n90 = length(w1), n180 = length(w0),
             x1 = if (length(w1) && length(w0)) mean(w1) - mean(w0) else 0,
             x2 = if (length(w1)) mean(w1) else 0)
}))
P <- merge(merge(pred, gov[, .(e, G)], by = "e"), base[, .(e, G = k, lev, actual)], by = c("e", "G"), all.x = TRUE)
P[, y := actual - lev]
P[, ed := as.Date(unname(eds[e]))]; setorder(P, ed)
cat(sprintf("LQ2 predictors: %d elections with both windows (A1), %d with a final-90-day reading (A2); empty -> 0\n",
            sum(P$n90 > 0 & P$n180 > 0), sum(P$n90 > 0)))

beta_tf <- function(xcol) vapply(seq_len(nrow(P)), function(i) {
  past <- which(P$ed < P$ed[i] & is.finite(P$y)); stopifnot(all(P$ed[past] < P$ed[i]))
  if (length(past) < 3) return(0)
  x <- P[[xcol]][past]; y <- P$y[past]; lam <- mean(y^2) / TAU^2
  sum(x * y) / (sum(x^2) + lam)
}, 0)
P[, `:=`(b1 = beta_tf("x1"), b2 = beta_tf("x2"))]
P[, `:=`(c1 = b1 * x1, c2 = b2 * x2)]
print(P[, .(e, G, n90, n180, x1 = round(x1, 1), x2 = round(x2, 1), shipped = round(lev, 2), actual = round(actual, 2), miss = round(y, 2),
            b1 = signif(b1, 2), corr1 = round(c1, 2), b2 = signif(b2, 2), corr2 = round(c2, 2))], nrows = 40)

# apply to all classes (others absorb pro rata) and score
apply_corr <- function(ccol) {
  out <- copy(base)
  for (e0 in unique(out$e)) {
    g <- P$G[P$e == e0]; cc <- P[[ccol]][P$e == e0]; if (!length(cc) || cc == 0) next
    m <- out$e == e0; gi <- which(m & out$k == g); oi <- which(m & out$k != g)
    out$lev[gi] <- out$lev[gi] + cc
    out$lev[oi] <- out$lev[oi] * (sum(out$lev[oi]) - cc) / sum(out$lev[oi])
  }
  out
}
rmse <- function(a, b) sqrt(mean((a - b)^2))
jk <- function(A, B) {   # A, B: data.tables with e, lev, actual (same rows)
  full <- rmse(A$lev, A$actual) - rmse(B$lev, B$actual); u <- unique(A$e); G0 <- length(u)
  th <- vapply(u, function(x) { m <- A$e != x; rmse(A$lev[m], A$actual[m]) - rmse(B$lev[m], B$actual[m]) }, 0)
  per <- vapply(u, function(x) { m <- A$e == x; sum((A$lev[m] - A$actual[m])^2) - sum((B$lev[m] - B$actual[m])^2) }, 0)
  list(d = full, se = sqrt((G0 - 1) / G0 * sum((th - mean(th))^2)), per = setNames(per, u))
}
B3 <- base[is.finite(base$actual)]
gmask <- function(D) { gg <- merge(D, gov[, .(e, G)], by = "e"); gg[gg$k == gg$G] }
cat(sprintf("\nLQ3 shipped: government-class RMSE %.3f (%d cells); ALP/LNP/GRN RMSE %.3f (%d cells)\n",
            rmse(gmask(B3)$lev, gmask(B3)$actual), nrow(gmask(B3)), rmse(B3$lev, B3$actual), nrow(B3)))
for (arm in c("c1", "c2")) {
  A <- apply_corr(arm)[is.finite(base$actual)]
  rg <- jk(gmask(A), gmask(B3)); ra <- jk(A, B3)
  gain <- -rg$per[rg$per < 0]; top <- if (length(gain)) max(gain) / sum(gain) else NA
  cat(sprintf("LQ4 %s: government-class RMSE %+.3f (SE %.3f) | 66-cell RMSE %+.3f (SE %.3f) | largest single-election share of the gain %s\n",
              if (arm == "c1") "A1 change" else "A2 level", rg$d, rg$se, ra$d, ra$se, if (is.finite(top)) sprintf("%.0f%%", 100 * top) else "-"))
}
cat("\nLQ5 dry runs:\n")
for (q in c("vic2022", "qld2024", "sa2026")) { r <- P[P$e == q]
  cat(sprintf("     %s %s: x1 %+.1f, A1 correction %+.2f; x2 %+.1f, A2 correction %+.2f; shipped %.2f, actual %.2f\n", q, r$G, r$x1, r$c1, r$x2, r$c2, r$lev, r$actual)) }
r <- P[P$e %in% c("vic2026", "nsw2027")]
cat(sprintf("LQ6 live (information only): %s\n", paste(sprintf("%s x1 %+.1f -> A1 %+.2f, x2 %+.1f -> A2 %+.2f", r$e, r$x1, r$c1, r$x2, r$c2), collapse = " | ")))
cat(sprintf("LQ7 time-forward beta for A1 after the 10th election onward: %s\n", paste(signif(P$b1[11:nrow(P)], 2), collapse = ", ")))

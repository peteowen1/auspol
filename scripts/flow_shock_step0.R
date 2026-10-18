# Step 0 of docs/plans/prereg-statewide-flow-shock-2026-10-17.md: how much of the SHIPPED flow model's miss is
# statewide? Reads output/flow-event-residuals.csv (scripts/score_flows_oracle.R with
# AUSPOL_FLOW_ORACLE_CONFIGS=tf2): every real exclusion's predicted and actual split under the shipped tf2 flows.
# Per excluded class, the Coalition-vs-Labor logit residual of each event (actual minus predicted share to the
# Coalition side, LNP + ONP + OTH_RIGHT, among Coalition-side + Labor-side ALP + GRN), then the between-election
# variance of those residuals with the sampling part removed.
# GATE (decided in the prereg): the arm is built only if, for at least one of GRN, ONP, OTH_RIGHT, the
# between-election residual sd is >= 0.15 (logit) on 10+ elections. Codes FLS0-FLS3.
#   Rscript scripts/flow_shock_step0.R
suppressMessages(library(data.table))
f <- "output/flow-event-residuals.csv"
if (!file.exists(f)) stop("FLS0! ", f, " is missing -- run AUSPOL_FLOW_ORACLE_CONFIGS=tf2 Rscript scripts/score_flows_oracle.R all")
E <- fread(f)
cat(sprintf("FLS0 %d rows, %d elections\n", nrow(E), uniqueN(E$pair)))
RIGHT <- c("LNP", "ONP", "OTH_RIGHT"); LEFT <- c("ALP", "GRN")
ev <- E[, .(pred_r = sum(pred[to %in% RIGHT]), pred_l = sum(pred[to %in% LEFT]),
            act_r = sum(actual[to %in% RIGHT]), act_l = sum(actual[to %in% LEFT]), votes = event_votes[1]),
        by = .(pair, sk, from, surv, event_votes)]
ev <- ev[pred_r + pred_l > 0.2 & act_r + act_l > 0.2 & votes >= 200]       # both sides alive and the event is real
cl <- function(p) qlogis(pmin(pmax(p, 0.01), 0.99))
ev[, res := cl(act_r / (act_r + act_l)) - cl(pred_r / (pred_r + pred_l))]
cat(sprintf("FLS1 %d exclusion events with both sides alive, from %d classes\n", nrow(ev), uniqueN(ev$from)))
out <- rbindlist(lapply(split(ev, by = "from"), function(d) {
  el <- d[, .(n = .N, m = mean(res), v = if (.N > 1) var(res) else NA_real_), by = pair][n >= 3]
  if (nrow(el) < 3) return(NULL)
  within <- weighted.mean(el$v, pmax(el$n - 1, 1), na.rm = TRUE)
  between <- max(0, var(el$m) - mean(within / el$n))
  data.table(from = d$from[1], elections = nrow(el), events = sum(el$n), mean_resid = round(mean(el$m), 3),
             sd_between = round(sqrt(between), 3), sd_within = round(sqrt(within), 3),
             share_between = round(between / (between + within), 2))
}))
cat("FLS2 shipped-flow residual (logit, Coalition side vs Labor side), per excluded class:\n")
print(out[order(-sd_between)])
pass <- out[from %in% c("GRN", "ONP", "OTH_RIGHT") & elections >= 10 & sd_between >= 0.15]
cat(sprintf("FLS3 GATE: %s (classes passing: %s)\n", if (nrow(pass)) "PASSES -- build the arm" else "FAILS -- the shipped flows already track the statewide swing; closed",
            if (nrow(pass)) paste(sprintf("%s sd %.3f on %d elections", pass$from, pass$sd_between, pass$elections), collapse = "; ") else "none"))

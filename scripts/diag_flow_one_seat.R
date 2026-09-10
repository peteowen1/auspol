# Walk ONE seat's flows end to end: what the table says, what xgb says.
#
# The pooled 2x2 said the flow override costs wa2001 +0.048 and fed2016 +0.035.
# The seat-level pass (scripts/diag_flow_regressions.R) said those are two
# different failures -- wa2001 is 2 seats out of 57, fed2016 is a broad drift
# over 83 -- and neither is a floor-crossing artifact. A ratio cannot say WHY,
# so this prints the actual conditional dictionaries the simulator consumes.
#
# Usage: AUSPOL_DIAG_PAIR=wa2001 AUSPOL_DIAG_SEAT="Alfred Cove" Rscript this
#
# Emits D1* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

PAIR <- Sys.getenv("AUSPOL_DIAG_PAIR", "wa2001")
SEAT <- Sys.getenv("AUSPOL_DIAG_SEAT", "Alfred Cove")
PREV <- Sys.getenv("AUSPOL_DIAG_PREV", "wa1996")
REG  <- sub("[0-9]{4}$", "", PAIR)

cat(sprintf("D10  %s / %s (previous election %s, region %s)\n", PAIR, SEAT, PREV, REG))

# Is this election in the flow model's own training corpus at all? WA 2001 is
# NOT -- it has no transfer file of its own, which is why CLAUDE.md flags it as
# falling back to pooled flows. That matters twice over: no leave-one-out model
# exists for it, and every key it uses is an extrapolation from other
# jurisdictions and other decades.
TR <- fread("output/xgb-flows-v1-features.csv", showProgress = FALSE)
in_corpus <- PAIR %in% unique(TR$election)
cat(sprintf("D11  %s in the flow training corpus? %s%s\n", PAIR, in_corpus,
            if (!in_corpus) "  <- so its 'leave-one-out' model is the all-data model, and that is NOT leakage here" else ""))
loo_f <- sprintf("output/xgb-flows-v1-loo-%s.model", PAIR)
cat(sprintf("D11  %s exists? %s\n", loo_f, file.exists(loo_f)))

# The seat's actual primary shares for the target election, as the simulator
# sees them.
sd_all <- fread("output/pooled-sharedetail.csv", showProgress = FALSE)
S <- sd_all[pair == PAIR & seat == SEAT]
if (!nrow(S)) stop("no sharedetail rows for ", SEAT, " in ", PAIR)
cat("\nD12  primary shares this seat actually recorded (actual_share), and what the model predicted\n")
print(S[order(-actual_share), .(party, predicted = round(pred_share, 2), actual = round(actual_share, 2))])

CLASSES <- c("ALP","GRN","IND","LNP","NAT","ONP","OTH","OTH_RIGHT")
W <- dcast(sd_all[pair == PAIR & party %in% CLASSES], seat ~ party,
           value.var = "actual_share", fill = 0)
sh <- as.matrix(W[, -1]); rownames(sh) <- W$seat
if (!SEAT %in% rownames(sh)) stop(SEAT, " missing from the shares matrix")

ov <- xgb_flow_conditional_override_for(sh, PAIR, PREV, REG)
if (is.null(ov) || is.null(ov[[SEAT]])) stop("no xgb override built for ", SEAT)
K <- ov[[SEAT]]

# The table the override REPLACES, built exactly as the harness builds it.
TXR <- fread(file.path(election_data_path(),
                       switch(REG, fed = "aec-fed-transfers.csv", nsw = "nswec-nsw-transfers.csv",
                              qld = "ecq-qld-transfers.csv", sa = "ecsa-2026-sa-transfers.csv",
                              wa = "waec-wa-transfers.csv")), showProgress = FALSE)
tx <- TXR[election == PREV]
fm <- if (nrow(tx)) build_flow_matrix(tx, min_n = 3L) else NULL
cat(sprintf("\nD13  table flows built from %s: %s\n", PREV,
            if (is.null(fm)) "NOTHING -- this pair has no usable prior transfers, flows fall back to pooled" else sprintf("%d conditional key(s)", length(fm$conditional))))

# THE COMPARISON THAT MATTERS: for every key the xgb override supplies, what
# did the table say for the same key? A key the table never had is one where
# xgb is inventing a distribution the shipped model would have handled by
# falling back -- that is where a regression can come from without any single
# number looking wrong.
tbl_keys <- if (is.null(fm) || is.null(fm$conditional)) character(0) else names(fm$conditional)
present <- names(K)[names(K) %in% tbl_keys]
absent  <- setdiff(names(K), present)
cat(sprintf("D14  xgb supplies %d keys for this seat; the table had %d of them, and %d are keys the table would have FALLEN BACK on\n",
            length(K), length(present), length(absent)))

# Where does this seat's independent sit? Print every key whose survivor set
# contains IND, since that is the class both regressing pairs turn on.
ind_keys <- names(K)[grepl("IND", names(K))]
cat(sprintf("\nD15  %d key(s) involve IND. Showing up to 10 -- share of the excluded pot, %%\n", length(ind_keys)))
rows <- rbindlist(lapply(head(ind_keys, 10), function(k) {
  x <- K[[k]]
  t0 <- if (!is.null(fm) && !is.null(fm$conditional[[k]])) fm$conditional[[k]] else NULL
  # NOT `key =` -- data.table() treats that as its own key= argument and errors
  # naming your data. Documented trap in CLAUDE.md; hit it here.
  data.table(ky = k, to = names(x), xgb = round(unname(x), 1),
             table = if (is.null(t0)) NA_real_ else round(unname(t0[names(x)]), 1))
}), fill = TRUE)
print(rows)

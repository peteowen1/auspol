# Cheap verification before the expensive six-harness run: (1) default
# behavior byte-identical to pre-switch, (2) AUSPOL_DEFECT_CONSERVE actually
# changes `transfer` for a known major-defector case, (3) the xgb layer's
# own_prev_pcv is genuinely unaffected by the switch (since major_discount is
# never passed there) -- verified, not assumed.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# (1)+(2): direct call, Calare-shaped case (fed2022 -> fed2025, Andrew Gee
# NAT -> IND). fit_defector_discount() needs AUSPOL_DEFECT_DISCOUNT-style
# rate; use a fixed rate for a clean, reproducible check.
Sys.setenv(AUSPOL_DEFECT_CONSERVE = "1")
pv1 <- personal_prior_vote("fed2022", "fed2025", major_discount = 0.284)
Sys.setenv(AUSPOL_DEFECT_CONSERVE = "0")
pv0 <- personal_prior_vote("fed2022", "fed2025", major_discount = 0.284)
Sys.unsetenv("AUSPOL_DEFECT_CONSERVE")
pv_default <- personal_prior_vote("fed2022", "fed2025", major_discount = 0.284)

cat("Default (unset) vs explicit '1' identical:", identical(pv_default, pv1), "\n")

calare1 <- pv1[seat == "Calare" & party == "IND"]
calare0 <- pv0[seat == "Calare" & party == "IND"]
cat("\nCalare/IND, conserve=1:\n"); print(calare1)
cat("Calare/IND, conserve=0:\n"); print(calare0)
cat("own_prev_pcv identical across settings (should be TRUE -- only `transfer` should move):",
    isTRUE(all.equal(calare1$own_prev_pcv, calare0$own_prev_pcv)), "\n")
cat("transfer DIFFERS across settings (should be TRUE):",
    !isTRUE(all.equal(calare1$transfer, calare0$transfer)), "\n")

# (3): xgb layer call signature never passes major_discount -- confirm the
# resulting own_prev_pcv for a major-defector identity is NA regardless of
# AUSPOL_DEFECT_CONSERVE, i.e. genuinely unreached.
Sys.setenv(AUSPOL_DEFECT_CONSERVE = "1")
xgb_like1 <- personal_prior_vote("fed2022", "fed2025", minor_discount = NULL)
Sys.setenv(AUSPOL_DEFECT_CONSERVE = "0")
xgb_like0 <- personal_prior_vote("fed2022", "fed2025", minor_discount = NULL)
Sys.unsetenv("AUSPOL_DEFECT_CONSERVE")
cat("\nxgb-layer-shaped call (no major_discount), Calare/IND own_prev_pcv:\n")
cat("  conserve=1:", xgb_like1[seat == "Calare" & party == "IND"]$own_prev_pcv, "\n")
cat("  conserve=0:", xgb_like0[seat == "Calare" & party == "IND"]$own_prev_pcv, "\n")
cat("Identical (should be TRUE -- confirms switch cannot reach the xgb layer):",
    identical(xgb_like1, xgb_like0), "\n")

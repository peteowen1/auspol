test_that("state_flows_aec takes the state's AEC flow from the latest federal election before as_of, compulsory states only", {
  tab <- data.frame(fed_year = c(2022L, 2025L, 2025L, 2025L), state = c("vic", "vic", "vic", "nsw"),
                    party = c("GRN", "GRN", "ONP", "GRN"), alp_votes = 1, lnp_votes = 1, flow_alp = c(87.83, 89.70, 30, 80))
  cyc <- data.frame(region = "fed", year = c(2022L, 2025L), start = as.Date(c("2019-05-19", "2022-05-22")),
                    end = as.Date(c("2022-05-21", "2025-05-03")))
  used <- data.frame(year = 2026L, region = "vic", party = c("GRN", "ONP", "OTH"), flow_alp = c(83.46, 25, 50),
                     exhaust = 0, flow_source = "fitted", stringsAsFactors = FALSE)
  out <- state_flows_aec(used, cyc, as.Date("2026-10-30"), quiet = TRUE, table = tab)
  expect_equal(out$flow_alp, c(89.70, 30, 50))                         # OTH has no row: unchanged
  out22 <- state_flows_aec(used, cyc, as.Date("2024-01-01"), quiet = TRUE, table = tab)
  expect_equal(out22$flow_alp[1], 87.83)                               # 2025 not yet held: 2022 used
  expect_equal(state_flows_aec(used, cyc, as.Date("2022-05-21"), quiet = TRUE, table = tab)$flow_alp, used$flow_alp)  # held ON as_of is not before
  nsw <- used; nsw$region <- "nsw"
  expect_equal(state_flows_aec(nsw, cyc, as.Date("2026-10-30"), quiet = TRUE, table = tab)$flow_alp, used$flow_alp)  # optional-preferential: untouched
  opv <- used; opv$exhaust <- c(10, 0, 0)
  expect_equal(state_flows_aec(opv, cyc, as.Date("2026-10-30"), quiet = TRUE, table = tab)$flow_alp[1], 83.46)     # a row with exhaust: untouched
  qld16 <- used; qld16$region <- "qld"; qld16$year <- 2015L
  expect_equal(state_flows_aec(qld16, cyc, as.Date("2026-10-30"), quiet = TRUE, table = tab)$flow_alp, used$flow_alp)
})

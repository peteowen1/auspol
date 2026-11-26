# Upper-house vote model (R/upper_house_vote.R). Inline fixtures only: nothing here reads external/ or output/.

REGS8 <- c("Eastern Victoria", "North-Eastern Metropolitan", "Northern Metropolitan", "Northern Victoria",
           "South-Eastern Metropolitan", "Southern Metropolitan", "Western Metropolitan", "Western Victoria")

# Two districts per region; region effect eff[r] on each major's log ratio, plus noise sd `noise` per election.
fixture <- function(elections = c("vic2018", "vic2022"), eff = seq(-0.1, 0.1, length.out = 8), noise = 0, base = 0.85, seed = 1) {
  set.seed(seed)
  rows <- list()
  for (e in elections) for (i in seq_along(REGS8)) for (dd in 1:2) {
    reg <- if (e == "vic2018" && REGS8[i] == "North-Eastern Metropolitan") "Eastern Metropolitan" else REGS8[i]
    lo <- c(ALP = 3000, LNP = 3000, GRN = 1000, OTH = 3000)
    up <- lo
    b0 <- if (length(base) > 1) base[[e]] else base
    for (k in c("ALP", "LNP", "GRN")) up[[k]] <- lo[[k]] * b0 * exp(eff[i] + rnorm(1, 0, noise))
    up[["OTH"]] <- sum(lo) - sum(up[c("ALP", "LNP", "GRN")])
    rows[[length(rows) + 1]] <- data.frame(election = e, region = reg, district = paste(REGS8[i], dd), cls = names(lo), upper = up, lower = lo)
  }
  do.call(rbind, rows)
}

test_that("old Eastern Metropolitan maps to North-Eastern Metropolitan, eight regions asserted", {
  expect_equal(uh_map_region(c("Eastern Metropolitan", "Western Victoria")), c("North-Eastern Metropolitan", "Western Victoria"))
  rt <- uh_region_table(fixture())
  expect_equal(sort(unique(rt$reg)), sort(REGS8))
  bad <- fixture(); bad <- bad[bad$region != "Western Victoria", ]
  expect_error(uh_region_table(bad), "8 regions")
})

test_that("a party with no votes on one side of a region stops the table", {
  bad <- fixture(); bad$upper[bad$cls == "GRN" & bad$region == "Western Victoria"] <- 0
  expect_error(uh_region_table(bad), "zero votes")
})

test_that("stable region effects are kept, pure noise is shrunk away, uniform drops them", {
  stable <- uh_fit_majors(uh_region_table(fixture(eff = seq(-0.2, 0.2, length.out = 8), noise = 0.005)), c("vic2018", "vic2022"))
  expect_gt(stable$party$LNP$w, 0.9)
  expect_equal(exp(stable$party$ALP$mu), 0.85 * mean(exp(seq(-0.2, 0.2, length.out = 8))) / 1, tolerance = 0.05)
  noisy <- uh_fit_majors(uh_region_table(fixture(eff = rep(0, 8), noise = 0.1, seed = 3)), c("vic2018", "vic2022"))
  expect_lt(noisy$party$LNP$w, 0.5)
  uni <- uh_fit_majors(uh_region_table(fixture(eff = seq(-0.2, 0.2, length.out = 8))), c("vic2018", "vic2022"), regional = FALSE)
  expect_true(all(uni$party$GRN$eff == 0))
  expect_gt(uni$party$GRN$s2, 0.01)                      # the region spread became residual variance
  one <- uh_fit_majors(uh_region_table(fixture(elections = "vic2022")), "vic2022")
  expect_true(is.na(one$drift_common_sd))
  expect_error(uh_draw_major_ratios(one, uh_major_logratio(one, REGS8), 10), "two elections")
})

test_that("ratio draws are centred on the fitted ratio and share one statewide drift across regions", {
  f <- uh_fit_majors(uh_region_table(fixture(elections = c("vic2010", "vic2018", "vic2022"), noise = 0.02, base = c(vic2010 = 0.97, vic2018 = 0.84, vic2022 = 0.88))), c("vic2010", "vic2018", "vic2022"), regional = FALSE)
  expect_gt(f$drift_common_sd, 0.05)
  set.seed(2); d <- uh_draw_major_ratios(f, uh_major_logratio(f, REGS8), 4000)
  expect_equal(median(d$ALP), exp(f$party$ALP$mu), tolerance = 0.05)
  # regions within a simulation move together (common + party drift) when the region residual is small
  expect_gt(cor(log(d$LNP[, 1]), log(d$LNP[, 2])), 0)
})

test_that("DerSimonian-Laird: identical estimates give no between-unit variance; spread gives some", {
  p <- uh_dl_pool(c(0.1, 0.1, 0.1), c(0.05, 0.05, 0.05))
  expect_equal(p$tau2, 0); expect_equal(p$w, rep(1 / 3, 3)); expect_equal(p$mu, 0.1)
  q <- uh_dl_pool(c(-0.5, 0, 0.5), c(0.01, 0.01, 0.01))
  expect_gt(q$tau2, 0.1)
  expect_error(uh_dl_pool(c(NA, 1), c(0.1, NA)), "no usable")
})

test_that("One Nation pooling counts an election once, however many states it has", {
  src <- data.frame(source = c(paste("fed2022", c("NSW", "VIC", "QLD", "WA", "SA", "TAS")), "fed2025 VIC", "fed2025 NSW", "fed2019 VIC"),
                    kind = "federal Senate vs House", n = c(rep(20, 8), 3), log_ratio = c(rep(-0.2, 6), 0, 0, 5),
                    se = rep(0.03, 9))
  op <- uh_onp_pool(src)
  expect_equal(nrow(op$units), 2L)                       # fed2019 VIC (n 3) dropped by the n >= 5 rule
  expect_equal(op$dropped$source, "fed2019 VIC")
  expect_equal(sum(op$units$weight), 1)
  expect_lt(abs(op$units[unit == "fed2022"]$weight - op$units[unit == "fed2025"]$weight), 0.2)
})

test_that("the poll relative ratio ignores the poll's overall level", {
  a <- uh_poll_relative(17, 16, c(31, 16, 15), c(34, 19, 16), 0.88)
  b <- uh_poll_relative(17 * 0.8, 16, c(31, 16, 15) * 0.8, c(34, 19, 16), 0.88)   # 20% uncommitted removed from upper
  expect_equal(a, b)
  expect_equal(exp(uh_poll_relative(10, 10, c(9, 9), c(10, 10), 0.9)), 1)
})

test_that("One Nation poll units: a poll without One Nation's lower figure informs the discrepancy only", {
  rt <- uh_region_table(fixture())
  pl <- data.frame(poll = c(rep("a", 8), rep("b", 6)), n = 1000, house = c(rep(c("upper", "lower"), each = 4), rep(c("upper", "lower"), each = 3)),
                   party = c("LNP", "ALP", "GRN", "ONP", "LNP", "ALP", "GRN", "ONP", "LNP", "ALP", "GRN", "LNP", "ALP", "GRN"),
                   pct = c(30, 20, 15, 17, 34, 22, 16, 16, 30, 21, 14, 37, 26, 15))
  pu <- uh_onp_poll_units(pl, rt, c("vic2018", "vic2022"))
  expect_equal(nrow(pu$units), 1L)
  expect_equal(sort(unique(pu$disc$poll)), c("a", "b"))
  expect_gte(pu$disc_var, 0)
})

test_that("ticket experiments: changes split into common and party parts; a third election stops it", {
  nt <- data.frame(case = rep(c("X", "Y"), each = 6), election = rep(rep(c("e2001", "e2005"), each = 3), 2), cls = rep(c("ALP", "LNP", "GRN"), 4),
                   ratio = c(1, 1, 1, 1.1, 1.1, 1.1, 1, 1, 1, 0.9, 0.9, 0.9))
  nv <- uh_noticket_variance(nt)
  expect_equal(nv$party_sd, 0, tolerance = 1e-12)
  expect_gt(nv$common_sd, 0.09)
  bad <- rbind(nt, data.frame(case = "X", election = "e2009", cls = "ALP", ratio = 1))
  expect_error(uh_noticket_variance(bad), "exactly two")
})

test_that("minor pattern: shrinkage needs enough pairs; region levels keep the statewide level", {
  p <- data.frame(key = rep(c("a", "b"), each = 3), reg = rep(c("r1", "r2", "r3"), 2), pat = c(0.1, 0, -0.1, 0.2, 0, -0.2))
  expect_error(uh_minor_shrink(p, p), "fewer than 8")
  vw <- c(r1 = 1, r2 = 2, r3 = 1)
  lv <- uh_level_by_region(4, c(r1 = 0.5, r2 = 0, r3 = -0.5), 0.8, vw)
  expect_equal(sum(lv * vw) / sum(vw), 4)
  expect_gt(lv[["r1"]], lv[["r3"]])
  expect_equal(unname(uh_level_by_region(4, c(r1 = 0.5), 0, vw)), rep(4, 3))
})

test_that("minor votes fill the pool exactly, in proportion to the levels, polled weight moved by its factor", {
  lv <- data.frame(key = c("P", NA, NA), level = c(4, 2, 1), polled = c(TRUE, FALSE, FALSE))
  zf <- matrix(1, 4000, 1, dimnames = list(NULL, "P"))
  set.seed(4); mv <- uh_minor_votes(lv, rep(14, 4000), zf)
  expect_equal(rowSums(mv), rep(14, 4000))
  expect_equal(unname(colMeans(mv)), c(8, 4, 2), tolerance = 0.03)
  big <- uh_minor_votes(lv, rep(28, 4000), zf)               # a bigger pool scales every group, polled or not
  expect_equal(unname(colMeans(big)), c(16, 8, 4), tolerance = 0.03)
  zf2 <- zf; zf2[] <- 2
  up <- uh_minor_votes(lv, rep(14, 4000), zf2)
  expect_gt(mean(up[, 1]), 9.5)
  bad <- lv; bad$level[2] <- 0
  expect_error(uh_minor_votes(bad, rep(14, 10), zf[1:10, , drop = FALSE]), "positive level")
})

test_that("crowding model recovers a known slope and ticket term; refuses too few elections or a constant ticket", {
  set.seed(5)
  e <- paste0("e", 1:9); gr <- c(6, 18, 22, 20, 21, 20, 17, 19, 13); se <- c(5, 5, 5, 21, 21, 11, 11, 6, 37); tk <- c(1, 1, 1, 0, 0, 0, 0, 1, 0)
  cr <- do.call(rbind, lapply(c("ALP", "LNP", "GRN"), function(k) data.frame(election = e, unit = "s", groups = gr, seats = se, cls = k, ticket = tk,
    ratio = exp(-0.05 + -0.06 * log(gr / se) + 0.03 * tk + rnorm(9, 0, 0.005)))))
  et <- uh_crowding_table(cr)
  cf <- uh_crowding_fit(et, e)
  expect_equal(cf$coef$b, rep(-0.06, 3), tolerance = 0.15)
  expect_equal(cf$coef$c, rep(0.03, 3), tolerance = 0.5)
  pr <- uh_crowding_predict(cf, c(r1 = log(11 / 5), r2 = log(15 / 5)), 0)
  expect_gt(pr$point["r1", "ALP"], pr$point["r2", "ALP"])          # more crowded ballot, lower ratio
  set.seed(6); d <- uh_crowding_draws(cf, pr, c(ALP = 0.001, GRN = 0.001, LNP = 0.001), 2000)
  expect_equal(median(d$LNP[, "r1"]), exp(pr$point["r1", "LNP"]), tolerance = 0.02)
  expect_error(uh_crowding_fit(et, e[1:3]), "at least 4")
  expect_error(uh_crowding_fit(et, e[c(4:7, 9)]), "does not vary")
  bad <- cr; bad$groups[1] <- NA
  expect_error(uh_crowding_table(bad), "group count")
})

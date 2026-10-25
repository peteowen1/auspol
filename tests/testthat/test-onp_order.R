sen <- data.frame(region = "qld", cycle = 2020L, fed = 2019L,
                  district = c("Alpha", "Beta", "Gamma", "Delta"),
                  senate_pct = c(2, 9, 5, 12))

test_that("onp_senate_key looks seats up by normalised name and records the federal year", {
  k <- onp_senate_key(c("alpha", "Delta", "Nowhere"), "qld2020", senate = sen)
  expect_equal(as.numeric(k), c(2, 12, NA))
  expect_equal(names(k), c("alpha", "Delta", "Nowhere"))
  expect_equal(attr(k, "fed"), 2019L)
  expect_null(onp_senate_key("Alpha", "sa2026", senate = sen))
})

test_that("onp_senate_key REFUSES a Senate table from after the target (broken input: leakage)", {
  bad <- sen; bad$fed <- 2022L
  expect_error(onp_senate_key("Alpha", "qld2020", senate = bad), "leakage")
})

test_that("onp_rank_reassign keeps the values and hands them out in key order", {
  v <- c(a = 10, b = 30, c = 20)
  out <- onp_rank_reassign(v, key = c(3, 1, 2))
  expect_equal(out, c(a = 30, b = 10, c = 20))
  expect_equal(sort(unname(out)), sort(unname(v)))
  expect_error(onp_rank_reassign(v, c(1, NA, 2)), "NA")
  expect_error(onp_rank_reassign(v, 1:2), "length")
})

test_that("onp_senate_rank_apply re-orders One Nation by the Senate vote and keeps row totals", {
  sh <- rbind(Alpha = c(ALP = 40, LNP = 30, ONP = 20),
              Beta  = c(ALP = 40, LNP = 40, ONP = 10),
              Gamma = c(ALP = 50, LNP = 25, ONP = 15),
              Delta = c(ALP = 45, LNP = 30, ONP = 5))
  out <- onp_senate_rank_apply(sh, "qld2020", senate = sen, refill = "prop")
  # Senate order Alpha < Gamma < Beta < Delta gets 5, 10, 15, 20.
  expect_equal(out[, "ONP"], c(Alpha = 5, Beta = 15, Gamma = 10, Delta = 20))
  expect_equal(rowSums(out), rowSums(sh))
  expect_equal(out["Alpha", "ALP"] / out["Alpha", "LNP"], 40 / 30)   # proportional refill
  none <- onp_senate_rank_apply(sh, "qld2020", senate = sen, refill = "none")
  expect_equal(none[, c("ALP", "LNP")], sh[, c("ALP", "LNP")])
  expect_equal(none[, "ONP"], out[, "ONP"])
})

test_that("onp_senate_rank_apply leaves the matrix alone when too many seats lack a Senate share", {
  sh <- rbind(Alpha = c(ALP = 40, ONP = 20), Beta = c(ALP = 40, ONP = 10),
              Zeta = c(ALP = 40, ONP = 15), Eta = c(ALP = 40, ONP = 5))
  expect_null(suppressWarnings(onp_senate_rank_apply(sh, "qld2020", senate = sen)))
  expect_null(onp_senate_rank_apply(sh[, "ALP", drop = FALSE], "qld2020", senate = sen))
})

betas <- data.frame(moved = "ONP", class = c("ALP", "LNP", "GRN", "OTH"),
                    beta = c(-0.2, -0.5, -0.05, -0.25))

test_that("onp_fill_betas hands the gap out by the betas and sums to 100", {
  sh <- rbind(BoxHill = c(ALP = 30, LNP = 30, GRN = 15, IND = 3, OTH = 2, ONP = 0))
  out <- onp_fill_betas(sh, onp_target = 10, betas = betas)
  expect_equal(sum(out[1, colnames(out) != "ONP"]) + 10, 100)
  gap <- 90 - 80
  expect_equal(unname(out[1, "ALP"]), 30 + gap * 0.2)
  expect_equal(unname(out[1, "LNP"]), 30 + gap * 0.5)
  expect_equal(unname(out[1, "IND"] + out[1, "OTH"]), 5 + gap * 0.25)
  expect_equal(unname(out[1, "IND"] / out[1, "OTH"]), 3 / 2)
})

test_that("onp_fill_betas differs from the proportional fill, floors at zero, and respects held cells", {
  sh <- rbind(S1 = c(ALP = 40, LNP = 20, GRN = 20, ONP = 0))
  out <- onp_fill_betas(sh, 10, betas)
  prop <- sh[1, 1:3] * 90 / 80
  expect_false(isTRUE(all.equal(unname(out[1, 1:3]), unname(prop))))
  # A strong One Nation seat: the Greens would go negative under a big cut if not floored.
  sh2 <- rbind(S2 = c(ALP = 20, LNP = 10, GRN = 1, ONP = 0))
  out2 <- onp_fill_betas(sh2, 85, betas)
  expect_true(all(out2[1, 1:3] >= 0))
  expect_equal(sum(out2[1, 1:3]), 15)
  held <- matrix(c(TRUE, FALSE, FALSE, FALSE), 1, dimnames = dimnames(sh))
  out3 <- onp_fill_betas(sh, 10, betas, held = held)
  expect_equal(unname(out3[1, "ALP"]), 40)
  expect_equal(sum(out3[1, 1:3]), 90)
})

test_that("onp_fill_betas refuses betas with no losing class or no One Nation row (broken input)", {
  sh <- rbind(S1 = c(ALP = 40, LNP = 40, ONP = 0))
  expect_error(onp_fill_betas(sh, 10, transform(betas, beta = abs(beta))), "no class loses")
  expect_error(onp_fill_betas(sh, 10, transform(betas, moved = "ALP")), "no One Nation row")
})

# How-to-vote card selects the Liberal-excluded ALP:GRN flow row -- docs/plans/prereg-htv-flow-2026-09-18.md
fm <- list(conditional = list("LNP|ALP+GRN"     = c(ALP = 60, GRN = 40),
                              "LNP|ALP+GRN+IND" = c(ALP = 50, GRN = 30, IND = 20),
                              "LNP|ALP+IND"     = c(ALP = 70, IND = 30),
                              "GRN|ALP+LNP"     = c(ALP = 80, LNP = 20)))
tab <- data.frame(election = c("vic2022", "vic2022"), seat = c("ALL", "Kew"),
                  greens_above_labor = c(TRUE, FALSE), source = "test")
rows <- list(greens_above = 35, labor_above = 62)

test_that("only Liberal-excluded rows with both ALP and GRN alive change, other survivors untouched", {
  r <- htv_flow_override(NULL, fm, "vic2022", c("Footscray", "Kew"), table = tab, rows = rows)
  expect_equal(unname(r$Footscray[["LNP|ALP+GRN"]]), c(35, 65))
  expect_equal(unname(r$Footscray[["LNP|ALP+GRN+IND"]]), c(80 * 0.35, 80 * 0.65, 20))
  expect_equal(r$Footscray[["LNP|ALP+IND"]], fm$conditional[["LNP|ALP+IND"]])
  expect_equal(r$Footscray[["GRN|ALP+LNP"]], fm$conditional[["GRN|ALP+LNP"]])
  # a seat-level entry overrides the ALL entry
  expect_equal(unname(r$Kew[["LNP|ALP+GRN"]]), c(62, 38))
  expect_equal(attr(r, "htv")$applied, 2L)
})

test_that("no entry for the election leaves the override untouched, and an existing per-seat list is edited in place", {
  ov <- list(Footscray = list("LNP|ALP+GRN" = c(ALP = 55, GRN = 45)))
  attr(ov, "sd") <- "keep-me"
  expect_identical(htv_flow_override(ov, fm, "nsw2023", "Footscray", table = tab, rows = rows), ov)
  r <- htv_flow_override(ov, fm, "vic2022", "Footscray", table = tab, rows = rows)
  expect_equal(unname(r$Footscray[["LNP|ALP+GRN"]]), c(35, 65))
  expect_equal(attr(r, "sd"), "keep-me")
})

test_that("fit_htv_flow_rows leaves the target out and labels by the observed split", {
  d <- tempfile(); dir.create(d)
  tx <- data.table::data.table(
    election = c(rep("a2018", 4), rep("b2022", 4), rep("c2024", 4)),
    seat = rep(c("S1", "S1", "S2", "S2"), 3), round = 3L,
    from = "LNP", to = rep(c("ALP", "GRN"), 6),
    votes = c(60, 40, 60, 40,  30, 70, 30, 70,  70, 30, 70, 30))
  data.table::fwrite(tx, file.path(d, "x-transfers.csv"))
  f <- fit_htv_flow_rows("c2024", dir = d, min_seats = 2L)
  expect_equal(f$greens_above, 30); expect_equal(f$labor_above, 60)   # c2024's own 70% excluded
  g <- fit_htv_flow_rows("zzz", dir = d, min_seats = 2L)
  expect_equal(g$labor_above, 65)                                       # both labor-above elections, seat-weighted
})

test_that("AUSPOL_HTV_RECENCY_HL weights recent elections (prereg-htv-recency-2026-10-31)", {
  d <- tempfile(); dir.create(d)
  tx <- data.table::data.table(
    election = c(rep("a2018", 4), rep("c2024", 4)), seat = rep(c("S1", "S1", "S2", "S2"), 2), round = 3L,
    from = "LNP", to = rep(c("ALP", "GRN"), 4), votes = c(60, 40, 60, 40,  70, 30, 70, 30))
  data.table::fwrite(tx, file.path(d, "x-transfers.csv"))
  withr::local_envvar(AUSPOL_HTV_RECENCY_HL = "0")
  expect_equal(fit_htv_flow_rows("x2030", dir = d)$labor_above, 65)          # plain mean
  withr::local_envvar(AUSPOL_HTV_RECENCY_HL = "6")
  expect_equal(fit_htv_flow_rows("x2030", dir = d)$labor_above, (60 * 0.25 + 70 * 0.5) / 0.75)   # ages 12 and 6
  withr::local_envvar(AUSPOL_HTV_RECENCY_HL = "-1")
  expect_error(fit_htv_flow_rows("x2030", dir = d), "HTV11")
})

test_that("htv_card_p applies only when the card is not in the table", {
  tab <- data.table::data.table(election = "vic2022", seat = "ALL", greens_above_labor = TRUE)
  withr::local_envvar(AUSPOL_HTV_CARD_P = "")
  expect_true(is.na(htv_card_p("vic2026", table = tab)))
  withr::local_envvar(AUSPOL_HTV_CARD_P = "vic=0.67")
  expect_equal(htv_card_p("vic2026", table = tab), 0.67)
  expect_true(is.na(htv_card_p("vic2022", table = tab)))                       # known card: no mixing
  expect_true(is.na(htv_card_p("nsw2027", table = tab)))                       # no NSW entry: Victoria's estimate never leaks
  withr::local_envvar(AUSPOL_HTV_CARD_P = "vic=0.67, nsw=0.8")
  expect_equal(htv_card_p("nsw2027", table = tab), 0.8)
  withr::local_envvar(AUSPOL_HTV_CARD_P = "0.67")
  expect_error(htv_card_p("vic2026", table = tab), "HTV10")                    # a bare number is refused
  withr::local_envvar(AUSPOL_HTV_CARD_P = "vic=1.5")
  expect_error(htv_card_p("vic2026", table = tab), "HTV10")
})

test_that("htv_mix_sims takes the first p*n draws from the Labor-above run and weights win_prob alike", {
  mk <- function(w) list(totals = cbind(ALP = rep(w, 4L), GRN = rep(1L - w, 4L)),
                         tcp_winner = matrix(if (w == 1L) "ALP" else "GRN", 4, 1, dimnames = list(NULL, "S")),
                         tcp_runnerup = matrix(if (w == 1L) "GRN" else "ALP", 4, 1, dimnames = list(NULL, "S")),
                         tcp_share = matrix(0.55, 4, 1, dimnames = list(NULL, "S")),
                         win_prob = data.frame(seat = "S", party = if (w == 1L) "ALP" else "GRN", prob = 1))
  m <- htv_mix_sims(mk(1L), mk(0L), 0.75)
  expect_equal(unname(m$totals[, "ALP"]), c(1L, 1L, 1L, 0L))
  expect_equal(unname(m$tcp_winner[, "S"]), c("ALP", "ALP", "ALP", "GRN"))
  expect_equal(sort(m$win_prob$prob), c(0.25, 0.75))
  expect_equal(attr(m, "htv_card")$n_labor_above, 3L)
  b <- mk(0L); b$totals <- b$totals[1:3, ]
  expect_error(htv_mix_sims(mk(1L), b, 0.5), "HTV12")
})

# Seat-level quick screen (R/seat_state.R, scripts/seat_quick.R). Synthetic data only.

ss_matrix <- function() {
  build_flow_matrix(data.table::data.table(
    election = "x", seat = rep(c("a", "b", "c"), each = 3), round = 1L,
    from = "IND", to = rep(c("ALP", "LNP", "GRN"), 3),
    votes = c(400, 400, 200, 450, 350, 200, 380, 420, 200)), min_n = 2L)
}
ss_shares <- function() {
  matrix(c(40, 38, 12, 10,
           35, 42,  8, 15,
           45, 30, 20,  5,
           30, 30, 30, 10), nrow = 4, byrow = TRUE,
         dimnames = list(c("s1", "s2", "s3", "s4"), c("ALP", "LNP", "GRN", "IND")))
}

test_that("seat_state_sim is the plain call when not dumping, and its dump re-simulates identically", {
  sh <- ss_shares()
  old <- Sys.getenv("AUSPOL_SEAT_STATE_DUMP", NA)
  on.exit(if (is.na(old)) Sys.unsetenv("AUSPOL_SEAT_STATE_DUMP") else Sys.setenv(AUSPOL_SEAT_STATE_DUMP = old))
  Sys.unsetenv("AUSPOL_SEAT_STATE_DUMP")
  direct <- simulate_seat_contests(party_sd = c(ALP = 2, LNP = 2, GRN = 1, IND = 1), sh, ss_matrix(),
                                   seat_sd = 3, n_sims = 300, seed = 7, surge_h = c(s1 = 0.2, s2 = 0, s3 = 0.1, s4 = 0.3))
  wrapped <- seat_state_sim("x2020", party_sd = c(ALP = 2, LNP = 2, GRN = 1, IND = 1), sh, ss_matrix(),
                            seat_sd = 3, n_sims = 300, seed = 7, surge_h = c(s1 = 0.2, s2 = 0, s3 = 0.1, s4 = 0.3))
  expect_identical(direct$win_prob, wrapped$win_prob)
  f <- tempfile(fileext = ".rds")
  Sys.setenv(AUSPOL_SEAT_STATE_DUMP = f)
  dumped <- seat_state_sim("x2020", party_sd = c(ALP = 2, LNP = 2, GRN = 1, IND = 1), sh, ss_matrix(),
                           seat_sd = 3, n_sims = 300, seed = 7, surge_h = c(s1 = 0.2, s2 = 0, s3 = 0.1, s4 = 0.3))
  expect_identical(direct$win_prob, dumped$win_prob)       # dumping changes nothing
  st <- readRDS(sub("[.]rds$", "-x2020.rds", f))
  expect_true(all(nzchar(names(st$args))))                 # positional arguments were named
  expect_identical(st$args$shares, sh)
  expect_identical(seat_state_resim(st), direct$win_prob)  # the state IS the run
  Sys.setenv(AUSPOL_SEAT_STATE_DUMP = "nope.txt")
  expect_error(seat_state_sim("x", sh, ss_matrix(), party_sd = 1, n_sims = 5), "must end in .rds")
})

test_that("a seat subset keeps per-seat arguments aligned with their seats", {
  sh <- ss_shares()
  a <- seat_state_named_args(list(sh, ss_matrix(), party_sd = 1, n_sims = 10, shrink = c(0.1, 0.2, 0.3, 0.4),
                                  surge_h = c(s4 = 0.4, s1 = 0.1, s3 = 0.3, s2 = 0.2),
                                  sd_override = sh * 0 + 1, conditional_override = list(NULL, NULL, list(a = 1), NULL)))
  b <- seat_state_subset(a, c("s3", "s1"))
  expect_identical(rownames(b$shares), c("s3", "s1"))
  expect_identical(b$shrink, c(0.3, 0.1))
  expect_identical(unname(b$surge_h), c(0.3, 0.1))
  expect_identical(rownames(b$sd_override), c("s3", "s1"))
  expect_identical(b$conditional_override, list(list(a = 1), NULL))
  expect_identical(b$matrix, a$matrix)                      # never per seat
  bad <- a; bad$surge_mu <- c(1, 2)                         # a shape it cannot read: refused, not passed through
  expect_error(seat_state_subset(bad, "s1"), "cannot tell")
  expect_error(seat_state_subset(a, "s9"), "not in the state")
  bad2 <- a; rownames(bad2$sd_override) <- rev(rownames(sh))
  expect_error(seat_state_subset(bad2, "s1"), "seat order")
})

test_that("the seat cluster factor subsets by seat, and its per-class rho is passed through whole", {
  sh <- ss_shares()
  rho1 <- c(ALP = 0.1, LNP = 0.2, GRN = 0.05, IND = 0)    # length 4 = the seat count: must not be read as per seat
  a <- seat_state_named_args(list(sh, ss_matrix(), party_sd = 1, n_sims = 10,
                                  seat_cluster = c(1L, 2L, 1L, NA), cluster_rho = rho1))
  b <- seat_state_subset(a, c("s3", "s1"))
  expect_identical(b$seat_cluster, c(1L, 1L))
  expect_identical(b$cluster_rho, rho1)
  two <- list(region = c(ALP = 0.1, LNP = 0.1), type = c(ALP = 0.2, LNP = 0.05))   # AUSPOL_SEAT_CLUSTER_COR=both
  a2 <- seat_state_named_args(list(sh, ss_matrix(), party_sd = 1, n_sims = 10,
                                   seat_cluster = cbind(region = c(1L, 1L, 2L, 2L), type = c(3L, 4L, 3L, 4L)), cluster_rho = two))
  b2 <- seat_state_subset(a2, c("s4", "s2"))
  expect_identical(unname(b2$seat_cluster), cbind(c(2L, 1L), c(4L, 4L)))
  expect_identical(b2$cluster_rho, two)
})

test_that("a subset run matches the full run to Monte Carlo error, seat by seat", {
  sh <- ss_shares()
  a <- list(shares = sh, matrix = ss_matrix(), party_sd = c(ALP = 2, LNP = 2, GRN = 1, IND = 1),
            seat_sd = 3, n_sims = 4000, seed = 3, surge_h = c(0.2, 0, 0.1, 0.3))
  st <- list(args = a, env = character(0))
  full <- as.data.frame(seat_state_resim(st))
  one <- as.data.frame(seat_state_resim(st, seats = "s4"))
  m <- merge(full[full$seat == "s4", ], one, by = c("seat", "party"), all = TRUE)
  m[is.na(m)] <- 0
  expect_true(all(abs(m$prob.x - m$prob.y) < 4 * sqrt(0.25 / 4000) * sqrt(2)))
  expect_error(seat_state_resim(st, n_sims = 10, shares = sh[1:3, ]), "shape")
})

test_that("seat_tweak_check refuses a tweak that moves a seat it does not declare", {
  b <- ss_shares(); a <- b
  a["s2", ] <- .shift_cell(a["s2", ], 2, -1)
  expect_identical(seat_tweak_check(b, a, "s2"), "s2")
  a2 <- a; a2["s3", ] <- .shift_cell(a2["s3", ], 1, -1)     # the off-by-one row
  expect_error(seat_tweak_check(b, a2, "s2"), "SKQ7! .*s3")
  a3 <- a; a3["s2", 1] <- a3["s2", 1] + 1                    # a row total that changed
  expect_error(seat_tweak_check(b, a3, "s2"), "row total")
  expect_identical(seat_tweak_check(b, b, character(0)), character(0))
})

test_that("seat_state_ll pads untouched seats with exact zeros, as quick_arm's Q3 counts them", {
  s <- data.frame(pair = c("e1", "e1", "e2"), seat = c("a", "b", "c"), p_base = c(0.5, 0.9, 0.2), p_arm = c(0.25, 0.9, 0.4))
  L <- seat_state_ll(s, c(e1 = 4L, e2 = 2L, e3 = 5L), eps = 1e-6)
  dd <- c(log(2), 0, -log(2))
  expect_equal(L$touched$mean, mean(dd))
  expect_equal(L$all$mean, sum(dd) / 11)
  expect_identical(L$all$clusters, 3L)
  expect_equal(L$per_pair$ll_change_all, c(log(2) / 4, -log(2) / 2, 0))
  expect_error(seat_state_ll(s, c(e1 = 4L)), "no seat count")
})

test_that("the winprob safety measure is 0 at a coin flip or worse and 1 at certainty", {
  wp <- data.frame(pair = "e1", seat = c("A", "A", "B"), party = c("ALP", "LNP", "LNP"), prob = c(0.8, 0.2, 0.5))
  f <- former_safety_winprob(wp)
  fs <- data.frame(seat = c("A", "A", "B", "B"), party = c("ALP", "LNP", "LNP", "GRN"))
  expect_equal(f("e1", fs), c(0.6, 0, 0, 0))                # GRN in B: never drawn winning
  expect_true(all(is.na(f("e9", fs))))                       # an election with no probabilities: unknown, not 0
})

test_that("seat_quick takes only the current published-config baseline cache, by its key", {
  ctx <- list(code = "tabc1234", external = "anchor=x;reference=y;", input = "in0123456789", subdirs = character(0))
  base <- tempfile("cache"); dir.create(base)
  mk <- function(parts, name, ids = c("vic2022", "wa2025")) {
    d <- file.path(base, name); dir.create(d)
    saveRDS(parts, file.path(d, "_key.rds"))
    for (u in ids) { dir.create(file.path(d, u)); saveRDS(list(pair = u), file.path(d, u, sprintf("state-%s.rds", u)))
                     saveRDS(list(ok = TRUE), file.path(d, u, "meta.rds")) }
    d
  }
  good <- mk(quick_key_parts(ctx, 20000L, character(0), TRUE), quick_key(ctx, 20000L, character(0), TRUE))
  expect_identical(quick_check_seat_cache(good, ctx, c("vic2022", "wa2025"))$key, basename(good))
  arm_env <- c(AUSPOL_LEADER_FORMER = "1")
  arm <- mk(quick_key_parts(ctx, 20000L, arm_env, TRUE), quick_key(ctx, 20000L, arm_env, TRUE))
  expect_error(quick_check_seat_cache(arm, ctx, "vic2022"), "ARM cache .*AUSPOL_LEADER_FORMER=1")
  old <- utils::modifyList(ctx, list(code = "told9999"))
  stale <- mk(quick_key_parts(old, 20000L, character(0), TRUE), quick_key(old, 20000L, character(0), TRUE))
  expect_error(quick_check_seat_cache(stale, ctx, "vic2022"), "its code told9999 differs")
  nodump <- mk(quick_key_parts(ctx, 20000L, character(0), FALSE), quick_key(ctx, 20000L, character(0), FALSE))
  expect_error(quick_check_seat_cache(nodump, ctx, "vic2022"), "not built with --dump")
  expect_error(quick_check_seat_cache(good, ctx, c("vic2022", "fed2019")), "no state for 1 election.*fed2019")
  newin <- utils::modifyList(ctx, list(input = "in9999999999"))
  expect_error(quick_check_seat_cache(good, newin, "vic2022"), "inputs .* differ")
  # a unit killed after its state was dumped: state file present, completion marker (meta.rds) absent
  file.remove(file.path(good, "wa2025", "meta.rds"))
  expect_error(quick_check_seat_cache(good, ctx, c("vic2022", "wa2025")), "no state for 1 election.*wa2025")
  expect_identical(quick_check_seat_cache(good, ctx, "vic2022")$key, basename(good))
})

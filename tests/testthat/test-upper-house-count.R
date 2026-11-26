# Upper-house count from measured preferences (R/upper_house_count.R). Toy data only: no external/ files.

toy_pat <- function(rows, G) {       # rows: list(first, c(rest...), share)
  S <- matrix(0L, length(rows), G + 1L); sh <- numeric(length(rows))
  for (k in seq_along(rows)) { z <- c(rows[[k]][[1]], rows[[k]][[2]]); S[k, seq_along(z)] <- as.integer(z); sh[k] <- rows[[k]][[3]] }
  list(S = S, share = sh)
}

test_that("a hand-checkable count: quota, surplus, exclusion, exhaustion", {
  # 4 groups, 2 seats, 100 votes: quota 100 / 3 = 33.33.
  # A 40 (all A > B), B 25 (B only: exhausts), C 20 (half C > B, half C > D), D 15 (all D > C). A has 1 candidate.
  pat <- toy_pat(list(list(1, 2, 1), list(2, integer(0), 1), list(3, 2, 0.5), list(3, 4, 0.5), list(4, 3, 1)), 4L)
  r <- uh_stv(c(40, 25, 20, 15), pat, seats = 2L, cands = c(1, 2, 2, 2), trace = TRUE)
  q <- 100 / 3
  # A elected at 40; out of candidates, so its 6.67 surplus passes to B (31.67). Nobody at a quota: D (15) out,
  # all to C (35 >= 33.33): C elected. Nothing has exhausted.
  expect_equal(r$won, c(1L, 0L, 1L, 0L))
  expect_equal(r$order, c(1L, 3L))
  expect_equal(r$steps$what, c("elected", "surplus passed on", "excluded", "elected"))
  expect_equal(r$tallies[2, 2], 25 + 40 - q)
  expect_equal(r$tallies[3, 3], 35)
  expect_equal(r$exhausted, 0)
  # Same, but D's voters number nothing else: D (15) is excluded and exhausts, then B (31.67) and C (20) are the
  # last two for the last seat and B, the higher, wins without C being excluded.
  pat2 <- toy_pat(list(list(1, 2, 1), list(2, integer(0), 1), list(3, 2, 0.5), list(3, 4, 0.5), list(4, integer(0), 1)), 4L)
  r2 <- uh_stv(c(40, 25, 20, 15), pat2, seats = 2L, cands = c(1, 2, 2, 2), trace = TRUE)
  expect_equal(r2$won, c(1L, 1L, 0L, 0L))
  expect_equal(r2$steps$what, c("elected", "surplus passed on", "excluded", "elected: higher of the last two"))
  expect_equal(r2$exhausted, 15)                    # D's 15 exhaust; the last two (B 31.67, C 20) are not counted on
})

test_that("votes never increase, exhausted votes never come back, and every vote is accounted for", {
  set.seed(42)
  for (it in 1:30) {
    G <- sample(5:12, 1); P <- 200
    S <- matrix(0L, P, G + 1L)
    for (p in seq_len(P)) { L <- sample(1:G, 1); S[p, seq_len(L)] <- sample.int(G, L) }
    S <- S[S[, 1] > 0, , drop = FALSE]
    sh <- stats::runif(nrow(S)); sh <- sh / ave(sh, S[, 1], FUN = sum)
    v <- numeric(G); present <- sort(unique(S[, 1])); v[present] <- stats::rexp(length(present))
    pat <- list(S = S, share = sh)
    r <- uh_stv(v, pat, seats = 5L, cands = sample(1:5, G, TRUE), trace = TRUE)
    st <- r$steps
    expect_true(all(diff(st$live) <= 1e-9))                         # live votes only ever fall
    expect_true(all(diff(st$exhausted) >= -1e-9))                   # exhausted votes never return
    # every vote is live, exhausted, or one of the quotas used to elect (the closing step elects without a quota)
    k <- st$what %in% c("elected", "surplus passed on", "excluded")
    expect_equal((st$live + st$exhausted + r$quota * st$elected)[k], rep(sum(v), sum(k)), tolerance = 1e-9)
    expect_true(all(r$won <= 5L) && sum(r$won) <= 5L)
    # following the count's own path reproduces it
    expect_equal(uh_stv(v, pat, 5L, cands = NULL, replay = uh_replay_of(uh_stv(v, pat, 5L, trace = TRUE))),
                 uh_stv(v, pat, 5L))
  }
})

test_that("party classes: Libertarian and Labour DLP are not read as Liberal and Labor", {
  expect_equal(uh_party_class(c("Libertarian (formerly Liberal Democrats)", "Labour DLP", "Australian Labor Party",
                                "Liberal / The Nationals", "Liberal", "One Nation Victoria", "The Greens",
                                "Affordable Housing Now - Sustainable Australia Party", "Unnamed-1", "Christian Alliance Party - Reform AU",
                                "Socialist Alliance", "Trumpet of Patriots")),
               c("LIBT", "DLP", "ALP", "LNP", "LNP", "ONP", "GRN", "SAP", "POOL_C", "POOL_R", "SAL", "UAP"))
  expect_equal(uh_bloc(c("ALP", "LNP", "POOL_C", "DLP", "SAP")), c("L", "R", "C", "R", "C"))
})

toy_flows <- function() {
  seqs <- data.table::data.table(
    kind = c("ATL", "ATL", "ATL", "ATL", "BTL"),
    atl_marks = c(6L, 6L, 1L, 7L, 0L), btl_marks = c(0L, 0L, 0L, 0L, 12L),
    seq = c("A>B>C>D>E>F", "B>A>C>D>E>F", "C", "D>E>F>A>B>C>G", "E>D"),
    n = c(100L, 80L, 30L, 20L, 10L))
  groups <- data.table::data.table(letter = LETTERS[1:7],
    name = c("Australian Labor Party", "The Greens", "Liberal", "One Nation", "Family First", "Animal Justice Party", "Citizens Party"))
  uh_fit_flows(seqs, groups, 6L, label = "toy")
}

test_that("fitting, the flow matrix, and the boxes-numbered distribution", {
  f <- toy_flows()
  expect_equal(f$n_ballots, 240)
  expect_equal(sort(f$named), sort(c("ALP", "GRN", "LNP", "ONP", "FF", "AJP", "CIT")))
  fm <- uh_flow_matrix(f, K = 0)
  expect_equal(fm[first == "ALP" & nxt == "GRN"]$share, 1)
  expect_equal(fm[first == "LNP" & nxt == "EXH"]$share, 1)          # the lone 1 exhausts at once
  expect_true(all(abs(fm[, sum(shrunk), by = first]$V1 - 1) < 1e-9))
  bd <- uh_box_distribution(data.table::data.table(kind = c("ATL", "ATL", "BTL"), atl_marks = c(6L, 1L, 0L), n = c(3L, 1L, 5L)))
  expect_equal(bd$share, c(0.25, 0.75))
})

test_that("mapping onto a region: minimum cut to 5, missing parties go to their bloc, nothing is listed twice", {
  f <- toy_flows()
  grp <- c("Australian Labor Party", "The Greens", "Liberal", "One Nation", "Victorian Socialists", "Labour DLP")
  pat <- uh_region_patterns(grp, f, min_to = 5L, K = 0)
  S <- pat$S
  expect_true(all(apply(S, 1, function(z) { z <- z[z > 0]; !anyDuplicated(z) })))
  expect_true(all(abs(tapply(pat$share, S[, 1], sum) - 1) < 1e-9))
  # Labor's ballot stopped at the Senate minimum (6), so here it numbers 5: ALP > GRN > LNP > ONP, then Family First
  # (not standing) goes to the right pool: Labour DLP (on no Senate ballot, so a pool group). Animal Justice is cut.
  alp <- S[S[, 1] == 1, , drop = FALSE]
  expect_equal(alp[1, 1:6], c(1L, 2L, 3L, 4L, 6L, 0L))
  expect_equal(pat$class, c("ALP", "GRN", "LNP", "ONP", "POOL_L", "POOL_R"))
  # Labour DLP and Victorian Socialists have no first-preference ballots of their own: their bloc's stand in
  expect_true(all(pat$diag[class %in% c("POOL_L", "POOL_R")]$n_own == 0))
  # absent = "skip": Family First is dropped, not replaced, so the ballot ends after One Nation
  pk <- uh_region_patterns(grp, f, min_to = 5L, K = 0, absent = "skip")
  expect_equal(pk$S[pk$S[, 1] == 1, , drop = FALSE][1, 1:5], c(1L, 2L, 3L, 4L, 0L))
  expect_error(uh_region_patterns(grp, f, absent = "nearest"))
  # the stated minimum is respected
  pat6 <- uh_region_patterns(grp, f, min_to = 6L, K = 0)
  expect_equal(sum(pat6$S[pat6$S[, 1] == 1, ][1, ] > 0), 6L)
})

test_that("a bad input stops instead of passing quietly", {
  seqs <- data.table::data.table(kind = "ATL", atl_marks = 2L, btl_marks = 0L, seq = "A>Z", n = 5L)
  expect_error(uh_fit_flows(seqs, data.table::data.table(letter = "A", name = "Australian Labor Party")), "no group row")
  expect_error(uh_read_flows(textConnection("x")), "not a flows file")
})

test_that("count_region: one row per simulation, seats sum to the region's, flows file round trip", {
  f <- toy_flows()
  tmp <- tempfile(fileext = ".csv.gz"); uh_write_flows(f, tmp); f2 <- uh_read_flows(tmp)
  expect_equal(f2$named, f$named); expect_equal(f2$min_marks, 6L); expect_equal(sum(f2$seq$n), sum(f$seq$n))
  grp <- c("Australian Labor Party", "The Greens", "Liberal", "One Nation", "Labour DLP")
  set.seed(1); V <- matrix(stats::rexp(50 * 5), 50, 5)
  W <- count_region(V, grp, f2, seats = 5L, cands = c(5, 5, 5, 2, 2))
  expect_equal(dim(W), c(50L, 5L)); expect_equal(colnames(W), grp)
  expect_true(all(rowSums(W) == 5L)); expect_true(all(W[, 4:5] <= 2L))
  expect_equal(count_region(V[1, ], grp, f2, seats = 5L, cands = c(5, 5, 5, 2, 2))[1, ], W[1, ])
})

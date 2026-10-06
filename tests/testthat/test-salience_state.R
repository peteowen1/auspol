## State-election Trends salience, rebuilt from cached raw weekly series.
## Synthetic caches only: nothing here touches external/ or output/.

POLL <- as.Date("2020-03-21")
TO   <- POLL - 1L
FROM <- TO - 400L
WEEKS <- seq(FROM, TO, by = "week")          # 58 weekly points, all before polling day
N <- length(WEEKS)

# hits: a numeric vector of length N, or a named list keyword -> vector
write_batch <- function(dir, kws, hits_list, fetched = "2026-09-07", extra_dates = NULL) {
  s <- data.table::rbindlist(lapply(seq_along(kws), function(i) {
    data.table::data.table(keyword = kws[i], date = WEEKS, hits = hits_list[[i]])
  }))
  if (!is.null(extra_dates)) {
    s <- rbind(s, data.table::data.table(keyword = kws[1], date = extra_dates, hits = 100))
  }
  key <- gsub("[^A-Za-z0-9]", "_", sprintf("v6-%s-%s-%s-%s", "AU-NSW", FROM, TO, paste(kws, collapse = "-")))
  saveRDS(list(series = s, empty = FALSE, fetched = as.Date(fetched)),
          file.path(dir, paste0(substr(key, 1, 150), ".rds")))
}
ramp <- function(camp, base = 0) c(rep(base, N - 8L), rep(camp, 8L))

test_that("loader matches only the election's window and geography", {
  d <- withr::local_tempdir()
  write_batch(d, c("A One", "B Two"), list(ramp(10), ramp(0)))
  saveRDS(list(series = data.table::data.table(keyword = "X", date = WEEKS, hits = 1)),
          file.path(d, "v6_AU_VIC_2019_02_14_2020_03_20_X.rds"))
  b <- state_trends_load(POLL, "AU-NSW", d)
  expect_length(b, 1L)
  expect_setequal(unique(b[[1]]$keyword), c("A One", "B Two"))
  expect_length(state_trends_load(POLL, "AU-SA", d), 0L)
})

test_that("two-stage linking puts batches on the anchor's scale", {
  d <- withr::local_tempdir()
  # batch 1: a1 loudest (camp 50), a2 camp 25. batch 2 not needed.
  write_batch(d, c("a1", "a2", "a3"), list(ramp(50), ramp(25), ramp(0)))
  # link: anchor camp 100, a1 camp 20 -> a1 is 0.2 anchors; scale = 0.2/50
  write_batch(d, c("Anchor Person", "a1"), list(ramp(100), ramp(20)))
  r <- state_salience_stats(state_trends_load(POLL, "AU-NSW", d), POLL, "Anchor Person")
  st <- r$stats
  expect_equal(st[keyword == "a1"]$jump, 0.2, tolerance = 1e-9)
  expect_equal(st[keyword == "a2"]$jump, 0.1, tolerance = 1e-9)
  expect_equal(st[keyword == "a1"]$level, 0.2, tolerance = 1e-9)
  expect_true(all(st$scaled[st$keyword %in% c("a1", "a2")]))
})

test_that("a point dated on or after polling day never counts (time-forward)", {
  d1 <- withr::local_tempdir(); d2 <- withr::local_tempdir()
  write_batch(d1, c("a1", "a2"), list(ramp(50), ramp(5)))
  write_batch(d2, c("a1", "a2"), list(ramp(50), ramp(5)),
              extra_dates = c(POLL, POLL + 7L, POLL + 14L))
  link <- function(d) write_batch(d, c("Anchor Person", "a1"), list(ramp(100), ramp(20)))
  link(d1); link(d2)
  r1 <- state_salience_stats(state_trends_load(POLL, "AU-NSW", d1), POLL, "Anchor Person")
  r2 <- state_salience_stats(state_trends_load(POLL, "AU-NSW", d2), POLL, "Anchor Person")
  expect_gt(r2$diag$n_future, 0L)
  expect_equal(r1$diag$n_future, 0L)
  # the future weeks are 100s; if they leaked, a1's peak and level would move
  expect_equal(r2$stats[order(keyword)], r1$stats[order(keyword)])
})

test_that("percentiles rank non-zero values only, and are NA below the floor", {
  d <- withr::local_tempdir()
  kws <- paste0("k", 1:12)
  write_batch(d, kws, c(lapply(1:10, function(i) ramp(i)), list(ramp(0), ramp(0))))
  write_batch(d, c("Anchor Person", "k10"), list(ramp(100), ramp(20)))
  st <- state_salience_stats(state_trends_load(POLL, "AU-NSW", d), POLL, "Anchor Person")$stats
  # ten positive jumps: ranks 1/10 .. 10/10; the two exact zeros score 0, not a mid rank
  expect_equal(sort(st[jump > 0]$jump_pctile), (1:10) / 10)
  expect_equal(st[keyword %in% c("k11", "k12")]$jump_pctile, c(0, 0))
  # a field with only 3 positives gives NA, not 0 and not a filler
  d2 <- withr::local_tempdir()
  write_batch(d2, c("p1", "p2", "p3", "z1"), list(ramp(3), ramp(2), ramp(1), ramp(0)))
  write_batch(d2, c("Anchor Person", "p1"), list(ramp(100), ramp(10)))
  st2 <- state_salience_stats(state_trends_load(POLL, "AU-NSW", d2), POLL, "Anchor Person")$stats
  expect_true(all(is.na(st2$jump_pctile)))
})

test_that("candidacies with no series get NA everywhere, never a constant", {
  d <- withr::local_tempdir()
  write_batch(d, c("Ann Lee", "Bob Ray"), list(ramp(40), ramp(0)))
  write_batch(d, c("Anchor Person", "Ann Lee"), list(ramp(100), ramp(20)))
  cand <- data.table::data.table(
    election = "nsw2020", seat = c("X", "X", "Y"), party = c("IND", "ALP", "GRN"),
    name = c("Ann LEE", "Bob RAY", "Cy NOBODY"), given = c("Ann", "Bob", "Cy"),
    surname = c("Lee", "Ray", "Nobody"), pcv = c(30, 40, 2), elected = c(TRUE, FALSE, FALSE))
  reg <- data.table::data.table(election = "nsw2020", poll = as.character(POLL),
                                geo = "AU-NSW", anchor = "Anchor Person")
  res <- build_state_salience(d, cand, reg)
  p <- res$pop
  expect_equal(nrow(p), 3L)
  expect_equal(p[name == "Cy NOBODY"]$has_series, FALSE)
  nm <- c("level", "jump", "rise", "peak", "share8", "jump_pctile", "level_pctile")
  expect_true(all(is.na(unlist(p[name == "Cy NOBODY", nm, with = FALSE]))))
  expect_true(p[name == "Ann LEE"]$has_series)
  expect_gt(p[name == "Ann LEE"]$level, 0)
  expect_equal(res$diag$with_series, 2L)
  expect_equal(res$diag$candidacies, 3L)
  # class table: the unmatched class stays NA
  cls <- state_salience_class_table(p)
  expect_true(is.na(cls[party == "GRN"]$ss_rise))
})

test_that("switch 0 leaves the feature table byte-identical; switch 1 adds NA-able columns", {
  ALL <- data.table::data.table(pair = c("nsw2019", "nsw2019", "fed2022"),
                                seat = c("Barwon", "Dubbo", "Kooyong"),
                                party = c("IND", "IND", "IND"), x = c(1, 2, 3))
  before <- data.table::copy(ALL)
  off <- add_state_salience(ALL, on = FALSE)
  expect_identical(off, before)
  expect_identical(names(off), names(before))
  tab <- data.table::data.table(pair = "nsw2019", seat = "Dubbo", party = "IND",
                                ss_level = 0.5, ss_rise = 3, ss_peak = 0.9, ss_share8 = 1,
                                ss_jump_pctile = 0.7, ss_level_pctile = 0.6)
  on <- add_state_salience(data.table::copy(ALL), tab = tab, on = TRUE)
  expect_equal(nrow(on), 3L)
  expect_equal(on$seat, ALL$seat)
  expect_true(all(state_salience_cols() %in% names(on)))
  expect_equal(on$ss_level, c(NA, 0.5, NA))          # NA, not a filler, off-pair and unmatched
  expect_identical(on[, names(ALL), with = FALSE], before)
})

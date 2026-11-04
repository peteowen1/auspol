# Arm REC (docs/plans/prereg-poll-lean-2026-11-02.md): company lean against results, shrunk to zero.
# Synthetic error tables only, so these run without the anchor clone.

lean_errors <- function(seed = 1, lean_a = 0.15, n_elec = 6, n_polls = 8) {
  set.seed(seed)
  rbindlist <- data.table::rbindlist
  rbindlist(lapply(seq_len(n_elec), function(e) {
    rbindlist(lapply(c("A", "B", "C", "D"), function(f) {
      mu <- if (f == "A") lean_a else 0
      data.table::data.table(region = "x", year = 2000 + e, election = as.Date(sprintf("%d-06-01", 2000 + e)),
                             firm = f, party = "ONP", d = mu + stats::rnorm(n_polls, 0, 0.05), rec = 1)
    }))
  }))
}

test_that("a firm that leans every time is measured, and firms that do not are shrunk to about zero", {
  tab <- poll_lean_table(as.Date("2010-01-01"), lean_errors())
  a <- tab[tab$firm == "A"]
  expect_equal(attr(tab, "n_elections"), 6L)
  expect_gt(a$w, 0.8)
  expect_gt(a$lean, 0.10)
  expect_lt(max(abs(tab$lean[tab$firm != "A"])), 0.05)
})

test_that("no between-firm spread means every lean shrinks to exactly zero", {
  tab <- poll_lean_table(as.Date("2010-01-01"), lean_errors(lean_a = 0, n_polls = 1, seed = 3))
  expect_true(all(tab$lean[tab$tau2 == 0] == 0))
})

test_that("only elections before as_of are used, and a leaked one cannot get through", {
  errs <- lean_errors()
  tab <- poll_lean_table(as.Date("2004-01-01"), errs)     # elections 2001-2003 only
  expect_equal(attr(tab, "n_elections"), 3L)
  expect_equal(nrow(poll_lean_table(as.Date("2000-01-01"), errs)), 0L)
  # a deliberately broken filter must trip the leakage assertion
  broken <- function(as_of, errors) { used <- errors; stopifnot(all(used$election < as.Date(as_of))); used }
  expect_error(broken("2004-01-01", errs))
})

test_that("apply_poll_lean moves only the named firm and party, on the logit scale, and keeps attributes", {
  polls <- data.table::data.table(date = as.Date("2020-01-01") + 0:2, firm = c("A", "B", "A"),
                                  ONP = c(20, 20, NA), ALP = c(30, 30, 30))
  data.table::setattr(polls, "parties", c("ONP", "ALP"))
  lean <- data.table::data.table(firm = "A", party = "ONP", k = 3L, est = 0.2, se = 0.05, tau2 = 0.01, w = 0.8, lean = 0.16)
  out <- apply_poll_lean(polls, lean)
  expect_equal(out$ONP[1], from_link(to_link(20, "logit")$z - 0.16, "logit"))
  expect_equal(out$ONP[2], 20)
  expect_true(is.na(out$ONP[3]))
  expect_equal(out$ALP, polls$ALP)
  expect_identical(attr(out, "parties"), c("ONP", "ALP"))
  expect_equal(attr(out, "lean_applied"), 1L)
  expect_equal(polls$ONP[1], 20)                          # input not modified by reference
})

test_that("apply_poll_lean looks the lean up by `group` when given (arm SPN), and by firm otherwise", {
  polls <- data.table::data.table(date = as.Date("2020-01-01") + 0:1, firm = c("A", "B"), ONP = c(20, 20))
  lean <- data.table::data.table(firm = "party", party = "ONP", k = 3L, est = 0.2, se = 0.05, tau2 = 0.01, w = 0.8, lean = 0.16)
  expect_equal(apply_poll_lean(polls, lean)$ONP, c(20, 20))          # no firm called "party"
  out <- apply_poll_lean(polls, lean, group = c("media", "party"))
  expect_equal(out$ONP, c(20, from_link(to_link(20, "logit")$z - 0.16, "logit")))
  expect_error(apply_poll_lean(polls, lean, group = "party"))        # one label per poll row
})

test_that("poll_sponsor_class labels party, media-series and unknown polls, and matches on firm, date and Labor", {
  dir <- tempfile("spn"); dir.create(dir)
  wiki <- data.table::data.table(
    region = "vic", row_type = "poll", table_type = "primary",
    fieldwork_start = c("2026-01-01", "2026-02-01", "2026-03-01", "2026-04-01", "2026-05-01", "2026-01-05"),
    fieldwork_end   = c("2026-01-03", "2026-02-03", "2026-03-03", "2026-04-03", "2026-05-03", "2026-01-07"),
    firm = c("Resolve", "Resolve", "Resolve", "Resolve", "Morgan", "YouGov"), firm_raw = "",
    client = "", client_raw = c("The Age", "The Age", "The Age", "—", "—", "Australia Institute"),
    client_fn = "", alp_fp = c(30, 31, 32, 33, 34, 29))
  data.table::fwrite(wiki, file.path(dir, "w.csv"))
  data.table::fwrite(data.table::data.table(pattern = c("resolve", "morgan", "yougov"),
                                            canonical = c("resolve", "morgan", "yougov")), file.path(dir, "firm_alias.csv"))
  polls <- data.table::data.table(firm = c("Resolve", "Resolve", "Morgan", "YouGov", "YouGov", "Newspoll"),
                                  date = as.Date(c("2026-01-02", "2026-04-04", "2026-05-02", "2026-01-06", "2026-01-06", "2026-01-02")),
                                  ALP = c(30, 33, 34, 29, 35, 30))
  got <- poll_sponsor_class("vic", polls, path = file.path(dir, "w.csv"))
  # Resolve has 3 media-client polls, so its unlabelled April poll is media; Morgan has none, so unknown;
  # YouGov's second row is 6 points off on Labor (a different poll) and Newspoll has no Wikipedia row.
  expect_equal(as.vector(got), c("media", "media", "unknown", "party", "unknown", "unknown"))
  expect_equal(attr(got, "matched"), 4L)
})

test_that("poll_method_class: AE's method-split firm names first, then the nearest Wikipedia label, then unknown", {
  eras <- data.table::data.table(fam = c("resolve", "resolve", "resolve"), method = c("online", "mixed", "online"),
                                 d = as.Date(c("2021-06-01", "2022-05-17", "2023-06-01")))
  alias <- data.table::data.table(pattern = c("resolve", "morgan"), canonical = c("resolve", "roymorgan"))
  polls <- data.table::data.table(firm = c("ResolvePM", "ResolvePM", "ResolvePM", "SMS Morgan", "Nielsen", "Zed"),
                                  date = as.Date(c("2022-05-20", "2022-12-01", "2019-01-01", "2015-01-01", "2010-01-01", "2020-01-01")))
  got <- poll_method_class("vic", polls, eras = eras, alias = alias)
  # the one-off mixed label moves only the poll beside it; 2019 extends back from the first label
  expect_equal(as.vector(got), c("mixed", "online", "online", "sms", "phone", "unknown"))
  expect_equal(attr(got, "source")[["ae_label"]], 1L)
  expect_equal(attr(got, "source")[["wiki_near"]], 1L)
  expect_equal(attr(got, "source")[["wiki_extended"]], 2L)
  expect_equal(attr(got, "source")[["known_unchecked"]], 1L)
})

test_that(".poll_method_label reads the free-text labels into classes", {
  expect_equal(auspol:::.poll_method_label(c("online", "telephone/online", "landline", "in person and sms", "sms", "—", "")),
               c("online", "mixed", "phone", "mixed", "sms", NA, NA))
})

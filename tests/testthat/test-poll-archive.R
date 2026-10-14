test_that("AUSPOL_POLL_ARCHIVE defaults on (shipped 2026-10-14), turns off, and rejects junk", {
  withr::with_envvar(c(AUSPOL_POLL_ARCHIVE = NA), expect_true(poll_archive_on()))
  withr::with_envvar(c(AUSPOL_POLL_ARCHIVE = "0"), expect_false(poll_archive_on()))
  withr::with_envvar(c(AUSPOL_POLL_ARCHIVE = "yes"), expect_error(poll_archive_on(), "must be"))
})

test_that("archive_polls reads the shape wiki_polls does and .ps_add_archive skips polls already held", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("region,firm,fieldwork_start,fieldwork_end,ALP,LNP,GRN,ONP,DEM,FF,OTH,tpp_alp,sample,source",
               "fed,F2F Morgan,2007-01-06,2007-01-14,47,36.5,8,1.5,1.5,2,3.5,57.5,,t",
               "fed,Newspoll,2007-01-19,2007-01-21,44,39,7,,,,10,55,,t",
               "nsw,Newspoll,2007-01-19,2007-01-21,44,39,7,,,,10,55,,t"), f)
  parties <- c("LNP", "ALP", "GRN", "ONP", "DEM", "OTH")
  a <- archive_polls("fed", parties, f)
  expect_equal(nrow(a), 2L)
  expect_equal(a$date[1], as.Date("2007-01-10"))
  expect_equal(a$OTH[1], 100 - 36.5 - 47 - 8 - 1.5 - 1.5)   # remainder of the named parties
  expect_equal(a$origin, c("archive", "archive"))
  expect_null(archive_polls("vic", parties, f))
  alias <- data.table::data.table(pattern = c("newspoll", "morgan"), canonical = c("newspoll", "roymorgan"))
  own <- a[2]; own$origin <- "wiki"; own$ALP <- 44.5   # Wikipedia already has the Newspoll (within 4 days, same firm)
  r <- .ps_add_archive(own, a, alias)
  expect_equal(r$added, 1L); expect_equal(r$dup, 1L)
  expect_equal(sort(r$ours$origin), c("archive", "wiki"))
  expect_identical(.ps_add_archive(own, NULL, alias)$ours, own)
})

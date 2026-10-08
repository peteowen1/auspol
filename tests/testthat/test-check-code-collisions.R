# A check code is the short prefix on a diagnostic line (`cat(sprintf("G7 ...`,
# `stop("FJ0! ...`, `code = "BV1n"`). Two files printing the SAME code for
# DIFFERENT checks make a grep for that code meaningless: SP2 once meant both
# the seat-swing port (R/seat_swing_port.R, and the workflow alarm
# fit_seats_full.R prints) and the salience screen (R/salience_screen.R).
#
# This is a ratchet. Every code printed by more than one file must be listed,
# file by file, in check-code-allowlist.csv with a reason (the same check
# copied into several entry points, or a pre-registration clause id). A NEW
# collision fails here. Fix it by giving the new code an unused name; add an
# allowlist row only when the second file prints the very same check.
#
# Needs scripts/ and R/ from a source checkout: R CMD check builds without
# scripts/, so it skips there.

scan_check_codes <- function(root) {
  files <- c(list.files(file.path(root, "R"), "\\.R$", full.names = TRUE),
             list.files(file.path(root, "scripts"), "\\.(R|py|sh)$", full.names = TRUE))
  rx_str  <- "(?:[\"']|\\\\n)([A-Z]{1,4}[0-9]{1,2}(?:-[0-9]+)?[A-Za-z]{0,2})!*(?=[ :!])"
  rx_code <- "\\bcode\\s*=\\s*[\"']([A-Z]{1,4}[0-9]{1,2}[A-Za-z]{0,2})[\"']"
  out <- list()
  for (f in files) {
    l <- readLines(f, warn = FALSE, encoding = "UTF-8")
    l <- ifelse(validUTF8(l), l, iconv(l, "latin1", "UTF-8", sub = ""))
    l <- sub("^\\s*#.*$", "", l)                       # comment lines never emit
    rel <- substring(normalizePath(f, winslash = "/"), nchar(normalizePath(root, winslash = "/")) + 2L)
    for (rx in c(rx_str, rx_code)) {
      m <- gregexpr(rx, l, perl = TRUE)
      for (i in which(vapply(m, function(x) x[1] != -1L, logical(1)))) {
        st <- attr(m[[i]], "capture.start")[, 1]
        ln <- attr(m[[i]], "capture.length")[, 1]
        out[[length(out) + 1L]] <- data.frame(code = substring(l[i], st, st + ln - 1L), file = rel)
      }
    }
  }
  d <- unique(do.call(rbind, out))
  nf <- table(d$code)
  d[d$code %in% names(nf)[nf > 1L], , drop = FALSE]
}

test_that("a check code printed by more than one file is on the allowlist", {
  root <- testthat::test_path("..", "..")
  skip_if_not(dir.exists(file.path(root, "scripts")) && dir.exists(file.path(root, "R")),
              "scripts/ not shipped in the check build")
  allow <- utils::read.csv(testthat::test_path("check-code-allowlist.csv"), stringsAsFactors = FALSE)
  cur <- scan_check_codes(root)
  expect_gt(nrow(cur), 100)          # the scan found the known shared codes: it is not vacuous
  key <- function(x) paste(x$code, x$file)
  new <- cur[!key(cur) %in% key(allow), , drop = FALSE]
  expect(nrow(new) == 0L, paste0(
    "check code(s) now printed by more than one file and not on the allowlist (rename the new one to an unused code, ",
    "or add a row to tests/testthat/check-code-allowlist.csv if it is the very same check): ",
    paste(sprintf("%s [%s]", new$code, new$file), collapse = "; ")))
})

test_that("the allowlist has no stale rows", {
  root <- testthat::test_path("..", "..")
  skip_if_not(dir.exists(file.path(root, "scripts")) && dir.exists(file.path(root, "R")),
              "scripts/ not shipped in the check build")
  allow <- utils::read.csv(testthat::test_path("check-code-allowlist.csv"), stringsAsFactors = FALSE)
  cur <- scan_check_codes(root)
  key <- function(x) paste(x$code, x$file)
  stale <- allow[!key(allow) %in% key(cur), , drop = FALSE]
  expect(nrow(stale) == 0L, paste0(
    "allowlist rows that no longer match a shared code (delete them): ",
    paste(sprintf("%s [%s]", stale$code, stale$file), collapse = "; ")))
})

test_that("the scan catches a deliberate collision", {
  tmp <- tempfile("codes")
  dir.create(file.path(tmp, "R"), recursive = TRUE); dir.create(file.path(tmp, "scripts"))
  writeLines('cat(sprintf("ZZ1  first meaning\\n"))', file.path(tmp, "R", "a.R"))
  writeLines('cat("\\nZZ1  second meaning\\n")', file.path(tmp, "scripts", "b.R"))
  writeLines('# cat("ZZ2  only in a comment")', file.path(tmp, "scripts", "c.R"))
  writeLines('f(code = "ZZ3")', file.path(tmp, "scripts", "d.R"))
  writeLines('stop("ZZ3! second meaning")', file.path(tmp, "scripts", "e.R"))
  got <- scan_check_codes(tmp)
  expect_setequal(unique(got$code), c("ZZ1", "ZZ3"))
  expect_equal(sort(got$file[got$code == "ZZ1"]), c("R/a.R", "scripts/b.R"))
})

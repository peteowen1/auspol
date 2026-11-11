# The VEC results website as the night source (the VEC refused the feed, 11 Nov 2026). Fixtures: the Nepean
# by-election (May 2026) "results by voting centre" pages, saved 11 Nov 2026.
fx <- function(k) testthat::test_path("fixtures", sprintf("vec-web-nepean-%s.html", k))

test_that("vec_web_parse reads the 2026 page layout and matches the page's own totals", {
  fp <- vec_web_parse(fx("fp"), "Nepean")
  expect_equal(data.table::uniqueN(fp$candidate), 8L)
  expect_equal(sum(fp$votes), 40545L)
  expect_equal(data.table::uniqueN(fp$booth[fp$booth_type == "ordinary"]), 13L)
  expect_setequal(unique(fp$booth_type), c("ordinary", "early", "absent", "marked_as_voted", "postal", "provisional"))
  expect_equal(unique(fp$party[fp$candidate == "HUTCHISON, Tracee"]), "")                # independent: blank party
  tc <- vec_web_parse(fx("2cp"), "Nepean")
  expect_equal(sum(tc$votes), 40652L)
})

test_that("vec_web_booth_table takes 2CP parties from the first-preference page (the VEC page mislabels Hutchison)", {
  fp <- vec_web_parse(fx("fp"), "Nepean"); tc <- vec_web_parse(fx("2cp"), "Nepean")
  expect_equal(unique(tc$party[tc$candidate == "HUTCHISON, Tracee"]), "Liberal")        # what the VEC page says
  w <- suppressMessages(vec_web_booth_table(fp, tc))
  expect_equal(unique(w$tcp$party_raw[w$tcp$candidate == "HUTCHISON, Tracee"]), "")      # what we use
  expect_false(any(w$live$booth_type %in% c("absent", "provisional", "marked_as_voted"))) # night base, as the feed path
  expect_true(all(c("district", "booth", "booth_type", "candidate", "party", "votes") %in% names(w$live)))
  expect_equal(nrow(w$counted), data.table::uniqueN(w$counted))
  # a voting centre in the list but not on the page becomes a zero-vote placeholder (an uncounted unit)
  w2 <- suppressMessages(vec_web_booth_table(fp, tc, places = data.table::data.table(district = "Nepean", booth = c("Rye", "New Centre"))))
  expect_equal(w2$n_placeholder_booths, 1L)
  expect_true("New Centre" %in% w2$live$booth)
})

test_that("vec_web_parse stops on a truncated page and on totals that do not add up", {
  tf <- tempfile(fileext = ".html"); on.exit(unlink(tf))
  writeLines(substr(paste(readLines(fx("fp"), warn = FALSE), collapse = "\n"), 1, 100000), tf)
  expect_error(vec_web_parse(tf, "Nepean"), "VWB1!")
  h <- paste(readLines(fx("2cp"), warn = FALSE), collapse = "\n")
  writeLines(sub("1,219", "1,300", h, fixed = TRUE), tf)
  expect_error(vec_web_parse(tf, "Nepean"), "VWB2!")
})

test_that("a district with nothing counted yet keeps its candidates and gets placeholders (one empty page must not stop the state)", {
  tf <- tempfile(fileext = ".html"); on.exit(unlink(tf))
  h <- paste(readLines(fx("fp"), warn = FALSE), collapse = "\n")
  # the 2026 layout cut to its header row: the table's first <tr> kept, every later row dropped
  tb <- regmatches(h, regexpr("(?s)<table.*?</table>", h, perl = TRUE))
  first_tr <- regmatches(tb, regexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))
  writeLines(sub(tb, sub("(?s)(<table[^>]*>).*$", paste0("\\1", first_tr, "</table>"), tb, perl = TRUE), h, fixed = TRUE), tf)
  e <- vec_web_parse(tf, "Nepean")
  expect_equal(nrow(e), 8L); expect_true(all(e$booth_type == "none")); expect_equal(sum(e$votes), 0L)
  fp <- rbind(vec_web_parse(fx("fp"), "Nepean"), data.table::copy(e)[, district := "Empty"])
  w <- suppressMessages(vec_web_booth_table(fp, places = data.table::data.table(district = "Empty", booth = c("A", "B"))))
  expect_true("Empty" %in% w$live$district)                                  # so night_check_coverage sees it
  expect_false(any(w$live$booth_type == "none"))
  expect_setequal(w$live$booth[w$live$district == "Empty" & w$live$booth_type == "ordinary"], c("A", "B"))
  expect_false(any(w$counted$district == "Empty"))                           # nothing counted there
})

test_that("night_web_latest takes the newest finished snapshot and night_web_read reads it", {
  root <- tempfile(); on.exit(unlink(root, recursive = TRUE))
  mk <- function(stamp, done = TRUE) { d <- file.path(root, stamp); dir.create(d, recursive = TRUE)
    file.copy(fx("fp"), file.path(d, "nepean-fp.html")); file.copy(fx("2cp"), file.path(d, "nepean-2cp.html"))
    data.table::fwrite(data.table::data.table(district = "Nepean", fp = "nepean-fp.html", tcp = "nepean-2cp.html"), file.path(d, "manifest.csv"))
    if (done) writeLines("x", file.path(d, "DONE")); d }
  expect_true(is.na(night_web_latest(root)))
  a <- mk("20261128_190000"); mk("20261128_191000", done = FALSE)   # still being fetched: no DONE
  expect_identical(night_web_latest(root), a)
  b <- mk("20261128_192000")
  expect_identical(night_web_latest(root), b)
  w <- night_web_read(b)
  expect_equal(sum(w$fp$votes), 40545L); expect_equal(sum(w$tcp$votes), 40652L)
  unlink(file.path(b, "nepean-2cp.html"))
  expect_error(night_web_read(b), "VWB7!")
})

test_that(".night_seat_names puts the VEC's district names into the model's seat names", {
  seats <- c("South West Coast", "Nepean", "Narre Warren South")
  expect_identical(.night_seat_names(c("South-West Coast", "Nepean District", "NARRE WARREN SOUTH"), seats), seats)
  expect_identical(.night_seat_names("Atlantis", seats), "Atlantis")                 # unchanged, so NW7 still stops
  expect_error(.night_seat_names("x", c("South West Coast", "South-West Coast")), "NW22!")
})

test_that("the live night uses cand_ref copy on the website source and off on the feed unless told", {
  expect_identical(.night_cand_ref_cfg(NULL, TRUE), "copy")
  expect_false(.night_cand_ref_cfg(NULL, FALSE))
  expect_false(.night_cand_ref_cfg("off", TRUE))
  expect_identical(.night_cand_ref_cfg("move", FALSE), "move")
  expect_error(.night_cand_ref_cfg("both", TRUE), "NW20!")
})

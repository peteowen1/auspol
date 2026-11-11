# 2026 enrolment by district, for the election-night expected-votes denominator on the VEC website source (the
# website candidate list has no enrolment column; the feed did). Source: the VEC's "District statistics - October
# 2026" spreadsheet from https://www.vec.vic.gov.au/enrolment/electoral-roll-statistics, saved raw as
# external/reference/vec/2026/enrolment/district-statistics-2026-10.xls (downloaded 11 Nov 2026; "Date Extracted"
# 5 Nov 2026, the close of rolls).
#
#   Rscript scripts/build_vec_enrolment_2026.R
#
# Writes external/reference/vec/2026/enrolment/enrolment-2026.csv (district, enrolment). Checks (VEN1-VEN2): 88
# districts, unique names, and the sum equal to the file's own "Total number of electors".
suppressMessages(library(data.table))
f <- "external/reference/vec/2026/enrolment/district-statistics-2026-10.xls"
x <- as.data.frame(readxl::read_excel(f, col_names = FALSE, .name_repair = "minimal"))
cell <- function(r, c) { v <- x[r, c]; if (is.na(v)) "" else as.character(v) }
hdr <- which(vapply(seq_len(nrow(x)), function(r) cell(r, 1) == "Area No", logical(1)))
cnt <- which(vapply(seq_len(ncol(x)), function(c) cell(hdr, c) == "Elector Count", logical(1)))
if (length(hdr) != 1 || length(cnt) != 1) stop("VEN1! header row or 'Elector Count' column not found in ", f)
num <- suppressWarnings(as.integer(x[[1]])); rows <- which(!is.na(num) & seq_len(nrow(x)) > hdr)
d <- data.table(district = trimws(as.character(x[rows, 2])), enrolment = as.integer(x[rows, cnt]))
tot_r <- which(vapply(seq_len(nrow(x)), function(r) any(grepl("^Total number of electors", unlist(x[r, ]))), logical(1)))
tot <- if (length(tot_r)) suppressWarnings(as.integer(na.omit(as.numeric(unlist(x[tot_r[1], ]))))[1]) else NA_integer_
ext <- as.character(as.Date(as.numeric(x[which(vapply(seq_len(nrow(x)), function(r) cell(r, 1) == "Date Extracted:", logical(1)))[1], 2]), origin = "1899-12-30"))
cat(sprintf("VEN1 %d districts, %d electors (file total %s), extracted %s\n", nrow(d), sum(d$enrolment), tot, ext))
if (nrow(d) != 88L || anyDuplicated(d$district) || anyNA(d$enrolment)) stop("VEN2! expected 88 unique districts with an enrolment")
if (!isTRUE(sum(d$enrolment) == tot)) stop("VEN2! districts sum to ", sum(d$enrolment), " but the file's total is ", tot)
out <- "external/reference/vec/2026/enrolment/enrolment-2026.csv"
fwrite(d, out); cat(sprintf("VEN2 wrote %s\n", out))

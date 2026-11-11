# VEC RESULTS WEBSITE -> night booth tables, for one district's two saved pages (the VEC refused the results feed,
# 11 Nov 2026). The parsing lives in the package: vec_web_parse() and vec_web_booth_table() (R/vec_web.R), which
# read the 2026 page layout and the 2022 one (checked against the 2022 feed's final count: every booth cell equal).
#
#   Rscript scripts/vec_web_booths.R <fp.html> <2cp.html> <district> [out prefix]
#
# Writes <prefix>-fp.csv (district, booth, booth_type, candidate, party, votes) and <prefix>-2cp.csv (district, booth,
# vote_type, candidate, party_raw, votes; parties from the first-preference page). Check codes VWB1-VWB5 (package), VWB6 (this summary).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
a <- commandArgs(trailingOnly = TRUE)
if (length(a) < 3) stop("usage: vec_web_booths.R <fp.html> <2cp.html> <district> [out prefix]")
fp <- vec_web_parse(a[1], a[3]); tc <- vec_web_parse(a[2], a[3])
w <- vec_web_booth_table(fp, tc, include_late = TRUE)
for (x in list(list("fp", fp), list("2cp", tc)))
  cat(sprintf("VWB6 %s %s: %d rows, %d ordinary booths, types %s, %d candidates, %d votes\n", a[3], x[[1]], nrow(x[[2]]),
              uniqueN(x[[2]]$booth[x[[2]]$booth_type == "ordinary"]), paste(unique(x[[2]]$booth_type), collapse = "/"),
              uniqueN(x[[2]]$candidate), sum(x[[2]]$votes, na.rm = TRUE)))
if (length(a) >= 4) { fwrite(fp, paste0(a[4], "-fp.csv")); fwrite(w$tcp, paste0(a[4], "-2cp.csv")) }

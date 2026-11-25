# Never let a test write the cross-seat memo to output/cache/ (R/cross_seat_vote.R).
#
# ONLY while testthat is running. devtools::load_all() sources tests/testthat/helper*.R too,
# and every pipeline script starts with load_all(): unguarded, this pointed each
# fit_seats_full.R process at its own fresh temp directory, so the disk memo never
# survived a process and no two processes ever shared an entry (found 2026-11-25:
# every CI what-if scenario recomputed the independent person cells, ~60 s each).
if (identical(Sys.getenv("TESTTHAT"), "true"))
  Sys.setenv(AUSPOL_CROSS_SEAT_CACHE_DIR = tempfile("cross-seat-cache-"))

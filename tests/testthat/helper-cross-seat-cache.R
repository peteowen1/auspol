# Never let a test write the cross-seat memo to output/cache/ (R/cross_seat_vote.R).
Sys.setenv(AUSPOL_CROSS_SEAT_CACHE_DIR = tempfile("cross-seat-cache-"))

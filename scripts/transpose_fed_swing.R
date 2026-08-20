# Federal two-party SWING, transposed onto state district boundaries.
#
# WHY. `fed_swing` -- how a seat swung at the preceding federal election -- is
# the strongest seat-level predictor in this model at t = 8.46, better than
# anything else measured. It exists in exactly two "before" seat files, so
# **every feature ever proposed as an addition to it can only be tested on 180
# seats.** That is the binding limit on feature testing here, and it showed up
# today when a seat-type variable could only be rejected at F = 0.36 on a sample
# too small to say much.
#
# The AEC publishes two-party-preferred by polling place with its own per-booth
# swing column, and the anchor ships booth-to-district correspondences. Joining
# them computes `fed_swing` for any state cycle with a correspondence file,
# rather than waiting for one to appear in a seat file.
#
# VALIDATION IS THE POINT. Two cycles -- vic2022 and nsw2023 -- already have
# `fed_swing` in their seat files. Those are computed here too and compared. If
# the transposed figure does not reproduce the published one, the method is
# wrong and the two new cycles cannot be trusted either.
#
# Emits FSW* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "aec", "booths")
CORR <- file.path("external", "aus-polling-analyser", "analysis", "Federal-State")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

FED_ID <- c("2013" = 17496, "2016" = 20499, "2019" = 24310,
            "2022" = 27966, "2025" = 31496)

# (correspondence, region, state cycle, the federal election that PRECEDED it)
JOBS <- list(
  list(corr = "booths-2018vic.txt", region = "vic", cycle = 2018, fed = 2016),
  list(corr = "booths-2019nsw.txt", region = "nsw", cycle = 2019, fed = 2016),
  list(corr = "booths-2022vic.txt", region = "vic", cycle = 2022, fed = 2022),
  list(corr = "booths-2023nsw.txt", region = "nsw", cycle = 2023, fed = 2022),
  list(corr = "booths-2026vic.txt", region = "vic", cycle = 2026, fed = 2025),
  list(corr = "booths-2027nsw.txt", region = "nsw", cycle = 2027, fed = 2025))

read_corr <- function(f) {
  ln <- readLines(file.path(CORR, f), warn = FALSE); ln <- ln[nzchar(ln)]
  d <- NA_character_; out <- list()
  for (l in ln) {
    if (startsWith(l, "#")) { d <- substring(l, 2); next }
    p <- strsplit(l, ",", fixed = TRUE)[[1]]
    if (length(p) < 2 || is.na(d)) next
    out[[length(out) + 1L]] <- data.table(district = d, division = trimws(p[1]),
                                          booth = trimws(paste(p[-1], collapse = ",")))
  }
  rbindlist(out)
}

tpp_booths <- function(year) {
  dest <- file.path(RAW, sprintf("tpp-fed%d.csv", year))
  if (!file.exists(dest) || file.info(dest)$size < 100000) {
    id <- FED_ID[[as.character(year)]]
    utils::download.file(
      sprintf("https://results.aec.gov.au/%d/Website/Downloads/HouseTppByPollingPlaceDownload-%d.csv", id, id),
      dest, mode = "wb", quiet = TRUE, headers = c("User-Agent" = UA))
  }
  d <- fread(dest, skip = 1L, showProgress = FALSE)
  setnames(d, make.names(names(d)))
  swing_col <- grep("^Swing$", names(d), value = TRUE)
  tot_col <- grep("TotalVotes|Total.Votes", names(d), value = TRUE)
  if (!length(swing_col) || !length(tot_col)) {
    stop("TPP booth file for ", year, " lacks a Swing or TotalVotes column. ",
         "Columns: ", paste(names(d), collapse = ", "))
  }
  # SIGN. The AEC's Swing column in the two-party file runs the opposite way to
  # this repo's convention, which is always "toward Labor" -- the validation
  # against the published fed_swing returned a correlation of -0.952, near
  # perfect in magnitude and inverted. Left unflipped this would have silently
  # reversed the strongest predictor in the seat model.
  d[, `:=`(swing = -as.numeric(get(swing_col[1])),
           tot = as.numeric(get(tot_col[1])))]
  d[is.finite(swing) & is.finite(tot) & tot > 0]
}

res <- list()
for (J in JOBS) {
  corr <- read_corr(J$corr)
  bo <- tpp_booths(J$fed)
  # The correspondence files are keyed to the federal boundaries CURRENT when
  # they were written, not to the boundaries at the election being transposed.
  # booths-2018vic.txt names Macnamara, Monash, Cooper, Nicholls and Fraser --
  # all renamed or created in the 2019 redistribution -- while the election that
  # precedes the November 2018 state poll is federal 2016. Using 2019 instead
  # would match the names and LEAK, because it came after.
  #
  # So renames are mapped back, and anything still unmatched falls back to
  # matching on booth name within the state, which is what a new division like
  # Fraser needs: its booths existed in 2016 under other divisions.
  renames <- c(Macnamara = "Melbourne Ports", Monash = "McMillan",
               Cooper = "Batman", Nicholls = "Murray")
  corr[, division_hist := fifelse(division %in% names(renames),
                                  unname(renames[division]), division)]
  m <- merge(corr, bo, by.x = c("division_hist", "booth"),
             by.y = c("DivisionNm", "PollingPlace"), allow.cartesian = TRUE)
  missed <- corr[!paste(division_hist, booth) %in%
                   m[, paste(division_hist, booth)]]
  if (nrow(missed)) {
    # Name-only fallback, restricted to booth names that are UNIQUE in the
    # state -- an ambiguous name would otherwise attach one district's booth to
    # another's swing.
    uniq <- bo[, .N, by = PollingPlace][N == 1L, PollingPlace]
    fb <- merge(missed[, .(district, booth)], bo[PollingPlace %in% uniq],
                by.x = "booth", by.y = "PollingPlace")
    if (nrow(fb)) {
      m <- rbind(m, fb, fill = TRUE)
      cat(sprintf("FSW0 %s: %d booths matched by name after a division rename
",
                  J$corr, nrow(fb)))
    }
  }
  # Vote-weighted, because a district's swing is its voters' swing and booths
  # differ hugely in size. The AEC's own per-booth swing is used rather than
  # differencing two elections' shares, which would silently drop every booth
  # that did not exist at both.
  agg <- m[, .(fed_swing = sum(swing * tot) / sum(tot), booths = .N,
               votes = sum(tot)), by = .(seat = district)]
  agg[, `:=`(region = J$region, cycle = J$cycle, fed = J$fed)]
  cat(sprintf("\nFSW1 %s %d <- federal %d swing: %d districts, %d booths, %s votes\n",
              toupper(J$region), J$cycle, J$fed, nrow(agg), sum(agg$booths),
              format(sum(agg$votes), big.mark = ",")))
  want <- uniqueN(corr$district)
  if (nrow(agg) < want) {
    stop(J$corr, ": only ", nrow(agg), " of ", want, " districts matched a booth.")
  }
  cat(sprintf("FSW1 transposed swing: mean %+.2f, sd %.2f, range %+.1f..%+.1f\n",
              mean(agg$fed_swing), stats::sd(agg$fed_swing),
              min(agg$fed_swing), max(agg$fed_swing)))
  res[[length(res) + 1L]] <- agg
}
R <- rbindlist(res)

# ---- validation: reproduce the two cycles that already have fed_swing -------
cat("\nFSW2 validation -- does this reproduce the seat files' own fed_swing?\n")
ok <- TRUE
for (K in list(c(2022, "vic"), c(2023, "nsw"))) {
  yr <- as.integer(K[1]); rg <- K[2]
  sf <- as.data.table(load_seats(yr, rg))[, .(seat, published = fed_swing)]
  m <- merge(R[region == rg & cycle == yr, .(seat, computed = fed_swing)],
             sf[is.finite(published)], by = "seat")
  if (!nrow(m)) { cat(sprintf("     %s %d: no overlap to check\n", rg, yr)); next }
  r <- stats::cor(m$computed, m$published)
  cat(sprintf("     %s %d: n = %d, correlation %+.3f, mean |difference| %.2f points\n",
              toupper(rg), yr, nrow(m), r, mean(abs(m$computed - m$published))))
  if (r < 0.9) ok <- FALSE
  if (r < -0.9) {
    cat("     a NEGATIVE correlation this strong means a sign convention is ",
        "reversed, not that the method is wrong.
")
  }
}
if (!ok) {
  stop("The transposed swing does not reproduce the published one. The two new ",
       "cycles cannot be trusted until it does.")
}
cat("FSW2 reproduces the published figures, so the two NEW cycles are usable.\n")

fwrite(R, file.path(OUT, "fed-swing-transposed.csv"))
cat(sprintf("\nFSW3 wrote %s: %d district-cycles across %d state cycles\n",
            file.path(OUT, "fed-swing-transposed.csv"), nrow(R),
            uniqueN(R[, .(region, cycle)])))
cat(sprintf("FSW3 seats now available to test a feature against fed_swing: %d\n",
            nrow(R[cycle %in% c(2018, 2019, 2022, 2023)])))
cat("FSW3 before this, that number was 180.\n")

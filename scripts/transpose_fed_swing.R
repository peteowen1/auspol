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
# Two kinds of correspondence, and they are joined differently.
#
# The six the anchor ships map a booth to a district by federal division NAME,
# and those names carry whichever redistribution was current when the file was
# written -- so they need the rename map and the booth-name fallback below.
#
# The Queensland ones are built by scripts/build_correspondence.R from polling
# place coordinates and carry PollingPlaceID, so they join exactly and need
# neither. That script validates the method by reproducing two of the shipped
# files from coordinates alone, at 97.8% and 97.7% booth agreement.
#
# Queensland votes in October, so the federal election preceding its 2020 poll
# is 2019 and the one preceding 2024 is 2022.
BUILT <- file.path("external", "reference", "correspondences")
JOBS <- list(
  list(corr = "booths-2018vic.txt", region = "vic", cycle = 2018, fed = 2016),
  list(corr = "booths-2019nsw.txt", region = "nsw", cycle = 2019, fed = 2016),
  list(corr = "booths-2022vic.txt", region = "vic", cycle = 2022, fed = 2022),
  list(corr = "booths-2023nsw.txt", region = "nsw", cycle = 2023, fed = 2022),
  list(corr = "booths-2020qld.csv", region = "qld", cycle = 2020, fed = 2019),
  list(corr = "booths-2024qld.csv", region = "qld", cycle = 2024, fed = 2022),
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
  # SIGN, AND IT IS NOT A CONSTANT. The AEC's Swing column refers to whichever
  # party its columns list FIRST, and the AEC CHANGED THAT ORDER in 2025:
  #
  #   2016, 2022:  ...,Liberal/National Coalition Votes,...,Australian Labor Party Votes,...,Swing
  #   2025:        ...,Australian Labor Party Votes,...,Liberal/National Coalition Votes,...,Swing
  #
  # This repo's convention is always "toward Labor". A fixed negation was
  # correct for 2016 and 2022 -- and it validated, because the only two cycles
  # with a published fed_swing to check against both draw on those elections.
  # Applied to 2025 it inverted every booth, which showed up as a mean swing of
  # -6.76 toward the Coalition at an election Labor won with a 3-point swing,
  # and as a -55 point booth that cannot exist.
  #
  # So the reference party is read from the column order rather than assumed.
  # setnames(make.names()) above has already turned the spaces into dots, so
  # these patterns must tolerate either form.
  lab_at <- grep("Australian.Labor.Party.Votes", names(d))[1]
  lnp_at <- grep("Coalition.Votes", names(d))[1]
  if (is.na(lab_at) || is.na(lnp_at)) {
    stop("TPP booth file for ", year, " has neither a Labor nor a Coalition ",
         "votes column, so the Swing column's reference party is unknowable. ",
         "Columns: ", paste(names(d), collapse = ", "))
  }
  swing_is_labor <- lab_at < lnp_at
  d[, `:=`(swing = if (swing_is_labor) as.numeric(get(swing_col[1]))
                   else -as.numeric(get(swing_col[1])),
           tot = as.numeric(get(tot_col[1])))]
  cat(sprintf("FSWS fed%d: Swing column is toward %s (%s listed first)
",
              year, if (swing_is_labor) "LABOR" else "the COALITION",
              if (swing_is_labor) "Labor" else "Coalition"))

  # A national mean this far from zero means the sign is still wrong, whichever
  # way it was read. Federal two-party swings do not average 8 points.
  chk <- d[is.finite(swing) & is.finite(tot) & tot > 0]
  natl <- sum(chk$swing * chk$tot) / sum(chk$tot)
  cat(sprintf("FSWS fed%d: national vote-weighted swing to Labor %+.2f
",
              year, natl))
  if (abs(natl) > 8) {
    stop("fed", year, ": national swing of ", round(natl, 2), " points is not ",
         "a real federal swing. The Swing column's reference party is being ",
         "read wrong.")
  }
  d[is.finite(swing) & is.finite(tot) & tot > 0]
}

res <- list()
for (J in JOBS) {
  bo <- tpp_booths(J$fed)
  built <- endsWith(J$corr, ".csv")
  if (built) {
    # Built from coordinates, so the join is on PollingPlaceID and is exact.
    # An ID present in the correspondence but missing from the two-party file
    # is a real gap -- a booth whose TPP was not published -- and is counted
    # rather than dropped, because a district losing half its booths silently
    # is precisely what the name-matching path used to do.
    corr <- fread(file.path(BUILT, J$corr), showProgress = FALSE)
    m <- merge(corr[, .(district, place_id)], bo,
               by.x = "place_id", by.y = "PollingPlaceID")
    lost <- nrow(corr) - nrow(m)
    cat(sprintf("FSW0 %s: joined on PollingPlaceID, %d of %d booths matched%s\n",
                J$corr, nrow(m), nrow(corr),
                if (lost) sprintf(" (%d had no two-party result)", lost) else ""))
    if (nrow(m) < 0.9 * nrow(corr)) {
      stop(J$corr, ": only ", nrow(m), " of ", nrow(corr), " booths have a ",
           "two-party result. The correspondence and the federal file do not ",
           "describe the same election.")
    }
  } else {
  corr <- read_corr(J$corr)
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
      cat(sprintf("FSW0 %s: %d booths matched by name after a division rename\n",
                  J$corr, nrow(fb)))
    }
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
  want <- uniqueN(corr[["district"]])
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
            nrow(R[paste(region, cycle) %in%
                     c("vic 2018", "nsw 2019", "vic 2022", "nsw 2023",
                       "qld 2020", "qld 2024")])))
cat("FSW3 before this, that number was 180.\n")

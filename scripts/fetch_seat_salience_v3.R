# Whole-seat salience, v3: TWO QUERIES PER SEAT.
#
#   query 1  the seat's non-major candidates alone       -> full resolution
#   query 2  the PM plus that seat's loudest candidate   -> a scale factor
#
# WHY TWO. Trends renormalises 0-100 WITHIN each query, so a candidate's level
# is not comparable across seats. Pete's fix is to put the PM in every query as
# a common barometer, and measured, that works but costs two things:
#
#   RESOLUTION. Trends returns integers. With the PM in the query, Kylea Tink
#   reads a mean of 1.88 -- weekly points of 1, 2, 2, 3. A real candidate
#   measured on a four-value scale. Alone she reads 26.75.
#
#   A STATE-SIZE CONFOUND. Against Morrison, Kate Chaney reads 10.00 and Tink
#   1.88 -- five-fold apart, on 29.5% and 25.2% of the vote. WA has a third of
#   NSW's population, so one WA seat is a far larger share of WA's search
#   traffic than a Sydney seat is of NSW's. Anchoring on a national figure
#   imports that difference as if it were political.
#
# Using the PM as a LINK rather than an anchor keeps the barometer and dodges
# both: resolution comes from the candidates-only query, comparability from the
# scale factor. The PM also always has volume, so he is a safe stitch overlap --
# unlike the loudest-candidate overlap that returned zero on Maria Vamvakinou.
#
# WHAT IS QUERIED. Non-majors only. The hazard is about non-major emergence, and
# the incumbent-anchored `ratio` lost to the raw `level` on the unbiased sample
# (0.880 against 0.925), so the majors no longer need a slot.
#
# THE STATISTIC. `jump` = campaign mean - pre-campaign baseline. Level and jump
# tie on the unbiased sample (0.925 vs 0.921), but jump is the one that survives
# a namesake: Cameron Smith the footballer outranks every teal on level and
# falls below them on jump. A live 88-seat run will contain several such names.
#
# NO LEAKAGE: every window ends the day before polling day.
#
# Emits S3* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))

MAJ   <- c("ALP", "LNP", "NAT")
SPAN  <- 300L          # forces weekly buckets
WEEKS <- 8L            # campaign slice
MAXKW <- 5L
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "4"))
MAX_SEATS <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MAX", "20"))
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

POLL <- c(fed2010 = "2010-08-21", fed2013 = "2013-09-07", fed2016 = "2016-07-02",
          fed2019 = "2019-05-18", fed2022 = "2022-05-21", fed2025 = "2025-05-03",
          vic2022 = "2022-11-26", vic2026 = "2026-11-28")
PM <- function(d) {
  d <- as.Date(d)
  if (d < as.Date("2010-06-24")) "Kevin Rudd"
  else if (d < as.Date("2013-06-27")) "Julia Gillard"
  else if (d < as.Date("2013-09-18")) "Kevin Rudd"
  else if (d < as.Date("2015-09-15")) "Tony Abbott"
  else if (d < as.Date("2018-08-24")) "Malcolm Turnbull"
  else if (d < as.Date("2022-05-23")) "Scott Morrison"
  else "Anthony Albanese"
}
GEO_OF <- c(NSW = "AU-NSW", VIC = "AU-VIC", QLD = "AU-QLD", SA = "AU-SA",
            WA = "AU-WA", TAS = "AU-TAS", NT = "AU-NT", ACT = "AU-ACT")

# One cached query. Stores the RAW SERIES -- never the aggregate alone, which
# cost 259 refetches when the baseline turned out to be needed.
qry <- function(kw, geo, to) {
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("v3-%s-%s-%s", geo, to, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$series) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = geo,
                          time = paste(as.Date(to) - SPAN, to), onlyInterest = TRUE),
                  error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(12 * att)
  }
  if (is.null(r) || is.null(r$interest_over_time)) {
    saveRDS(list(empty = TRUE), f); return(NULL)
  }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  out <- d[, .(keyword, date, hits)]
  saveRDS(list(series = out, empty = FALSE, fetched = Sys.Date()), f)
  out
}

camp_base <- function(series) {
  cutoff <- max(series$date) - WEEKS * 7L
  a <- series[date >  cutoff, .(camp = mean(hits)), by = keyword]
  b <- series[date <= cutoff, .(base = mean(hits)), by = keyword]
  merge(a, b, by = "keyword", all.x = TRUE)[is.na(base), base := 0]
}

seat_salience <- function(kw, geo, poll) {
  to <- as.Date(poll) - 1
  s1 <- qry(utils::head(kw, MAXKW), geo, to)          # candidates alone
  if (is.null(s1)) return(NULL)
  m1 <- camp_base(s1)
  m1[, jump := camp - base]
  loudest <- m1[which.max(camp), keyword]
  # The link. If every candidate is silent there is nothing to calibrate and
  # the seat is reported rather than given a fabricated scale.
  if (!is.finite(m1[keyword == loudest, camp]) || m1[keyword == loudest, camp] <= 0) {
    m1[, scale := NA_real_]; return(m1[])
  }
  Sys.sleep(SLEEP)
  s2 <- qry(c(PM(poll), loudest), geo, to)
  if (is.null(s2)) { m1[, scale := NA_real_]; return(m1[]) }
  m2 <- camp_base(s2)
  pm_v  <- m2[keyword == PM(poll), camp]
  cnd_v <- m2[keyword == loudest,  camp]
  # scale = how loud the seat's loudest candidate is ON THE PM's SCALE, divided
  # by how loud they are on the seat's own scale. Multiplying a seat-scale value
  # by this puts it on the PM scale and therefore on a common footing.
  m1[, scale := if (length(pm_v) && length(cnd_v) && is.finite(pm_v) && pm_v > 0 &&
                    is.finite(cnd_v) && m1[keyword == loudest, camp] > 0)
    (cnd_v / pm_v) / m1[keyword == loudest, camp] else NA_real_]
  m1[]
}

# ---- run --------------------------------------------------------------------
C <- fread("output/candidacies.csv", showProgress = FALSE)
EL <- Sys.getenv("AUSPOL_SALIENCE_ELECTION", "fed2022")
yr <- as.integer(sub("^[a-z]+", "", EL))
rg <- sub("[0-9]+$", "", EL)
D <- C[region == rg & year == yr & !party %in% MAJ]
if (!nrow(D)) stop("no non-major candidates for ", EL)
D[, kw := search_form(given, surname, name)]
PRIO <- c(IND = 1, GRN = 2, ONP = 3, OTH_RIGHT = 4, OTH = 5)
D[, prio := as.integer(PRIO[party])][is.na(prio), prio := 5L]

WANT <- Sys.getenv("AUSPOL_SALIENCE_SEATS", "")
seats <- if (nzchar(WANT)) trimws(strsplit(WANT, ",")[[1]]) else {
  set.seed(20260826L); sample(sort(unique(D$seat)))
}
cat(sprintf("S3-1 %s: %d seats, non-majors only | 2 queries per seat\n", EL, length(seats)))

out <- list(); done <- 0L
for (s in seats) {
  d <- D[seat == s][order(prio)]
  geo <- GEO_OF[[as.character(d$state[1])]]
  if (is.null(geo) || is.na(geo)) next
  probe <- gsub("[^A-Za-z0-9]", "_",
                sprintf("v3-%s-%s-%s", geo, as.Date(POLL[[EL]]) - 1,
                        paste(utils::head(d$kw, MAXKW), collapse = "-")))
  if (!file.exists(file.path(CACHE, paste0(substr(probe, 1, 150), ".rds")))) {
    if (done >= MAX_SEATS) next
    done <- done + 1L
  }
  m <- seat_salience(d$kw, geo, POLL[[EL]])
  if (is.null(m)) { cat(sprintf("S3!  %s: no data\n", s)); next }
  m <- merge(m, d[, .(keyword = kw, party, pcv, elected)], by = "keyword", all.x = TRUE)
  m[, `:=`(election = EL, seat = s)]
  m[, jump_cal := jump * scale]          # on the PM's scale, comparable across seats
  out[[s]] <- m
  Sys.sleep(SLEEP)
}
if (!length(out)) { cat("S3-9 nothing fetched\n"); quit(save = "no") }
R <- rbindlist(out, fill = TRUE)
fwrite(R, sprintf("output/seat-salience-v3-%s.csv", EL))
cat(sprintf("\nS3-9 %d candidates across %d seats | %d with a usable scale\n",
            nrow(R), uniqueN(R$seat), sum(is.finite(R$scale))))
cat("S3-9 loudest 15 by calibrated jump\n")
print(utils::head(R[order(-jump_cal),
      .(seat, keyword, party, pct = round(pcv, 1), won = elected,
        jump = round(jump, 2), jump_cal = signif(jump_cal, 3))], 15),
      row.names = FALSE)

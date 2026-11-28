# RAW COUNT side output for election night (Pete via ITG, 28 Nov 2026): watches the fetcher's snapshot folders and, for
# each new finished one, writes and uploads a small file of the counted votes as the VEC pages show them. NO model
# numbers. A SEPARATE process: it only READS <web dir> and never touches the night loop, its files or the forecast key.
#   Rscript raw_watch.R <web dir> <out.json> <r2 key under auspol/night/> [--once] [--no-upload]
# Run from the repo root. Stops by itself never; kill it by PID. Log lines start RAW.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
a <- commandArgs(trailingOnly = TRUE); web <- a[1]; out <- a[2]; key <- a[3]; once <- "--once" %in% a; noup <- "--no-upload" %in% a
stopifnot(length(a) >= 3, grepl("^auspol/night/[a-z0-9-]*raw[a-z0-9-]*\\.json$", key))   # can never be the forecast key
say <- function(...) cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " RAW ", ..., "\n", sep = "")
enr <- tryCatch(fread("external/reference/vec/2026/enrolment/enrolment-2026.csv"), error = function(e) NULL)
lk <- function(x) gsub("[^a-z]", "", tolower(x))
.pc <- new.env()   # classify each distinct party name once (it was the slow step)
pcl <- function(p) vapply(p, function(x) { k <- paste0("p:", x); if (is.null(.pc[[k]])) .pc[[k]] <- classify_party(x); .pc[[k]] }, character(1), USE.NAMES = FALSE)
places <- tryCatch(fread("external/reference/vec/2026/voting-locations/places-2026.csv", select = c("district", "booth")), error = function(e) NULL)
build <- function(snap) {
  w <- night_web_read(snap); fp <- as.data.table(w$fp)[booth_type != "marked_as_voted"]
  tcp <- if (is.null(w$tcp)) NULL else as.data.table(w$tcp)[booth_type != "marked_as_voted"]
  seats <- lapply(sort(unique(c(w$districts, fp$district))), function(d) {
    f <- fp[district == d]; tot <- sum(f$votes)
    P <- f[, .(votes = sum(votes)), by = .(candidate, party)][order(-votes)]
    en <- if (is.null(enr)) NA_real_ else { h <- enr$enrolment[lk(enr$district) == lk(d)]; if (length(h)) h[1] else NA_real_ }
    bo <- f[booth_type == "ordinary", .(v = sum(votes)), by = booth]
    ty <- f[booth_type != "ordinary", .(v = sum(votes)), by = booth_type]
    two <- NULL; tv <- 0L
    if (!is.null(tcp)) { T2 <- tcp[district == d, .(votes = sum(votes)), by = .(candidate)][order(-votes)]; tv <- sum(T2$votes)
      # party from the FIRST-PREFERENCE page: the VEC's two-candidate page prints the same party under both names (28 Nov, 7pm: both bars drew orange)
      T2[, party := { pm <- P$party[match(candidate, P$candidate)]; pm[is.na(pm)] <- ""; pm }]
      if (nrow(T2) && tv > 0) two <- lapply(seq_len(nrow(T2)), function(i) list(candidate = T2$candidate[i], party = T2$party[i], party_class = pcl(T2$party[i]),
                                                                           votes = T2$votes[i], pct = round(100 * T2$votes[i] / tv, 2))) }
    # ADDED 4:50pm (additive; readers of the first shape are unaffected): every unit with votes, and the 2026 voting
    # centres (VEC list) with none yet. Centre names are matched on letters only; an unmatched name just stays "outstanding".
    U <- f[, .(votes = sum(votes)), by = .(booth, booth_type, candidate, party)][votes > 0]
    units <- if (nrow(U)) { UT <- U[, .(votes = sum(votes), lead = candidate[which.max(votes)], lead_party = party[which.max(votes)], lead_votes = max(votes)), by = .(booth, booth_type)][order(-votes)]
      lapply(seq_len(nrow(UT)), function(i) list(booth = if (!is.na(UT$booth[i]) && nzchar(UT$booth[i])) UT$booth[i] else UT$booth_type[i], type = UT$booth_type[i], votes = UT$votes[i],
                                                 leader = UT$lead[i], leader_class = pcl(UT$lead_party[i]), leader_pct = round(100 * UT$lead_votes[i] / UT$votes[i], 1))) } else list()
    pl <- if (is.null(places)) character(0) else places$booth[lk(places$district) == lk(d)]
    outst <- pl[!lk(pl) %in% lk(bo$booth[bo$v > 0])]
    list(seat = d, enrolment = en, formal_votes = tot, counted_pct_of_enrolment = if (is.na(en) || en <= 0) NA else round(100 * tot / en, 1),
         booths_reported = sum(bo$v > 0), booths_total = if (length(pl)) length(pl) else NA, booths_outstanding = as.list(sort(outst)),
         vote_types_reported = as.list(ty$booth_type[ty$v > 0]), vote_types_outstanding = as.list(setdiff(c("early", "postal", "absent", "provisional"), ty$booth_type[ty$v > 0])),
         units = units,
         primary = lapply(seq_len(nrow(P)), function(i) list(candidate = P$candidate[i], party = P$party[i], party_class = pcl(P$party[i]),
                                                             votes = P$votes[i], pct = if (tot > 0) round(100 * P$votes[i] / tot, 2) else NA)),
         two_candidate_votes = tv, two_candidate = two)
  })
  tot_all <- sum(fp$votes)
  list(election = "vic2026", kind = "raw_count", built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), snapshot_stamp = basename(snap),
       note = "Votes counted so far as shown on the VEC results pages. Not a forecast: early booths are not typical of a seat.",
       seats_with_votes = sum(vapply(seats, function(s) s$formal_votes > 0, logical(1))), formal_votes = tot_all, seats = seats)
}
last <- ""
repeat {
  snap <- tryCatch(night_web_latest(web), error = function(e) NA_character_)
  if (!is.na(snap) && !identical(basename(snap), last)) {
    t0 <- proc.time()[["elapsed"]]
    ok <- tryCatch({ doc <- build(snap); tmp <- paste0(out, ".tmp")
      writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", na = "null", digits = NA), tmp, useBytes = TRUE); file.rename(tmp, out)
      up <- if (noup) "not uploaded" else { r <- suppressWarnings(system2("wrangler", c("r2", "object", "put", shQuote(paste0("inthegame-data/", key)), "--file", shQuote(out),
          "--content-type", "application/json", "--cache-control", shQuote("public, max-age=30"), "--remote"), stdout = TRUE, stderr = TRUE))
        if (is.null(attr(r, "status")) && any(grepl("Upload complete", r))) paste("uploaded to", key) else paste("UPLOAD FAILED:", paste(utils::tail(r, 1), collapse = " ")) }
      say(basename(snap), ": ", doc$seats_with_votes, " of ", length(doc$seats), " seats with votes, ", doc$formal_votes, " votes, ", round(proc.time()[["elapsed"]] - t0, 1), "s; ", up); TRUE },
      error = function(e) { say("FAILED ", basename(snap), ": ", conditionMessage(e)); FALSE })
    last <- basename(snap)   # a failed snapshot is not retried; the next one is
  }
  if (once) break
  Sys.sleep(10)
}

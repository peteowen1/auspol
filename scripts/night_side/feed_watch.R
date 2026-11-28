# "LATEST BOOTHS IN" feed for election night (Pete via ITG, 28 Nov 2026, 6:35pm). A third side process: reads the
# fetcher's snapshot folders only, never the night loop or the forecast key. For every finished snapshot, in order, it
# records the first snapshot where each booth / vote type had votes (first_seen) and the last where its total changed
# (last_changed), kept in <state.csv> so a restart loses nothing; then writes the newest <cap> items and uploads them.
#   Rscript feed_watch.R <web dir> <out.json> <state.csv> <r2 key under auspol/night/> [--once] [--no-upload] [--cap=150]
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("external/reference/benchmarks/vic2026-night/booths_fn.R")
a <- commandArgs(trailingOnly = TRUE); web <- a[1]; out <- a[2]; statef <- a[3]; key <- a[4]; once <- "--once" %in% a; noup <- "--no-upload" %in% a
cap <- { h <- grep("^--cap=", a, value = TRUE); if (length(h)) as.integer(sub("^--cap=", "", h[1])) else 150L }
stopifnot(length(a) >= 4, grepl("^auspol/night/[a-z0-9-]*booth-feed[a-z0-9-]*\\.json$", key))   # can never be the forecast key
say <- function(...) cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " FEED ", ..., "\n", sep = "")
.pc <- new.env(); pcl <- function(p) vapply(p, function(x) { k <- paste0("p:", x); if (is.null(.pc[[k]])) .pc[[k]] <- classify_party(x); .pc[[k]] }, character(1), USE.NAMES = FALSE)
iso <- function(st) format(as.POSIXct(st, format = "%Y%m%d_%H%M%S", tz = "Australia/Melbourne"), "%Y-%m-%dT%H:%M:%S+1100")
ST <- if (file.exists(statef)) fread(statef, colClasses = list(character = c("k", "first_seen", "last_changed", "done"))) else
  data.table(k = character(), first_seen = character(), last_changed = character(), votes = integer(), done = character())
done <- unique(ST$done[nzchar(ST$done)]); ST <- ST[nzchar(k), .(k, first_seen, last_changed, votes)]
units_of <- function(D) { D <- as.data.table(D)[!booth_type %in% c("marked_as_voted", "none")]
  D[, unit := fifelse(is.na(booth) | !nzchar(booth), booth_type, booth)]; D[, k := paste(district, booth_type, unit, sep = "|")]; D }
repeat {
  snaps <- sort(basename(dirname(Sys.glob(file.path(web, "*", "DONE"))))); todo <- setdiff(snaps, done); did <- FALSE
  for (st in todo) {
    r <- tryCatch({ w <- night_web_read(file.path(web, st)); fp <- units_of(w$fp)
      U <- fp[, .(v = sum(votes, na.rm = TRUE)), by = k][v > 0]
      new <- U[!k %in% ST$k]; if (nrow(new)) ST <- rbind(ST, data.table(k = new$k, first_seen = st, last_changed = st, votes = as.integer(new$v)))
      ch <- merge(ST, U, by = "k"); ch <- ch[ch$votes != ch$v]
      if (nrow(ch)) { ST[ch, on = "k", `:=`(last_changed = st, votes = as.integer(i.v))] }
      list(w = w, fp = fp, n_new = nrow(new)) }, error = function(e) { say("FAILED ", st, ": ", conditionMessage(e)); NULL })
    done <- c(done, st); did <- TRUE
    fwrite(rbind(ST[, .(k, first_seen, last_changed, votes, done = "")], data.table(k = "", first_seen = "", last_changed = "", votes = 0L, done = done)), statef)
    if (is.null(r) || st != utils::tail(snaps, 1)) { if (!is.null(r)) say(st, ": ", r$n_new, " new unit(s) (catching up)"); next }
    t0 <- proc.time()[["elapsed"]]
    top <- ST[order(-first_seen, -votes)][seq_len(min(cap, nrow(ST)))]
    fp <- r$fp[k %in% top$k]; tc <- if (is.null(r$w$tcp) || !nrow(r$w$tcp)) NULL else units_of(r$w$tcp)[k %in% top$k]
    items <- lapply(seq_len(nrow(top)), function(i) { f <- fp[k == top$k[i], .(votes = sum(votes, na.rm = TRUE)), by = .(candidate, party)][order(-votes)]; tot <- sum(f$votes)
      pr <- strsplit(top$k[i], "|", fixed = TRUE)[[1]]
      two <- NULL; if (!is.null(tc)) { t2 <- tc[k == top$k[i], .(votes = sum(votes, na.rm = TRUE)), by = candidate][order(-votes)]; tv <- sum(t2$votes)
        if (nrow(t2) && tv > 0) { pm <- f$party[match(t2$candidate, f$candidate)]; pm[is.na(pm)] <- ""
          two <- lapply(seq_len(nrow(t2)), function(j) list(candidate = t2$candidate[j], party_class = pcl(pm[j]), votes = t2$votes[j], pct = round(100 * t2$votes[j] / tv, 1))) } }
      list(seat = pr[1], booth = pr[3], type = pr[2], first_seen = iso(top$first_seen[i]), last_changed = iso(top$last_changed[i]), votes = tot,
           leader = if (nrow(f)) f$candidate[1] else NA, leader_class = if (nrow(f)) pcl(f$party[1]) else NA, leader_pct = if (tot > 0) round(100 * f$votes[1] / tot, 1) else NA,
           primary = lapply(seq_len(nrow(f)), function(j) list(candidate = f$candidate[j], party_class = pcl(f$party[j]), votes = f$votes[j], pct = if (tot > 0) round(100 * f$votes[j] / tot, 1) else NA)),
           two_candidate = two) })
    doc <- list(election = "vic2026", kind = "booth_feed", built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), snapshot_stamp = st, units_with_votes = nrow(ST),
                note = "Booths and vote types in the order they first showed votes on the VEC pages; first_seen is the time of that fetch, so it is late by up to one fetch period.", items = items)
    tmp <- paste0(out, ".tmp"); writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", na = "null", digits = NA), tmp, useBytes = TRUE); file.rename(tmp, out)
    do_up <- function() { x <- suppressWarnings(system2("wrangler", c("r2", "object", "put", shQuote(paste0("inthegame-data/", key)), "--file", shQuote(out),
        "--content-type", "application/json", "--cache-control", shQuote("public, max-age=30"), "--remote"), stdout = TRUE, stderr = TRUE))
      if (is.null(attr(x, "status")) && any(grepl("Upload complete", x))) paste("uploaded to", key) else paste("UPLOAD FAILED:", paste(utils::tail(x, 1), collapse = " ")) }
    # 7:28pm: one upload failed when the raw file uploaded in the same second; try once more after a pause
    up <- if (noup) "not uploaded" else { u <- do_up(); if (grepl("UPLOAD FAILED", u, fixed = TRUE)) { Sys.sleep(5); u <- paste(do_up(), "(second try)") }; u }
    say(st, ": ", r$n_new, " new, ", nrow(ST), " units with votes, ", length(items), " in the feed, ", round(proc.time()[["elapsed"]] - t0, 1), "s to build; ", up)
    # BOOTH BY BOOTH (booths_fn.R), same snapshot, its own file; a failure here never stops the feed
    tb <- proc.time()[["elapsed"]]
    bu <- tryCatch(bb_upload(build_booths(r$w, st), file.path(dirname(out), "booths-vic2026.json"), sub("booth-feed", "booths", key), noup), error = function(e) paste("FAILED:", conditionMessage(e)))
    say(st, ": booths file ", round(proc.time()[["elapsed"]] - tb, 1), "s; ", bu)
  }
  if (once) break
  Sys.sleep(10)
}

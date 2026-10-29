# ELECTION-NIGHT RUNNER (map #148): one cycle of poll -> archive -> parse -> convert -> update -> simulate -> JSON.
#
# The pieces are separate functions so each can be tested alone; scripts/night_runner.R runs one cycle and
# scripts/night_loop.R polls. Nothing here holds a credential: the SOURCE of snapshots is one function,
# `night_fetch_snapshot()`, which today reads a folder of ZIPs (the VEC's 2026 sample) and on the night is
# swapped for the SharePoint download (needs the token and site from the access request, 4 Nov; the token
# goes in an environment variable on the laptop, never in the repo).
#
# Check codes: NW1 (feed fails a sanity check), NW2 (bad conversion input), NW3 (no affiliation lookup),
# NW4 (output failed validation, nothing published), NW5 (no snapshot in the source).

#' Newest snapshot in the source (THE function to swap for the real feed)
#'
#' Today: the newest `verboselhv2` ZIP or XML in a folder. On the night: download whatever the VEC site
#' lists that is newer than the newest archived snapshot, save it into a folder, and return its path.
#' @param source A folder of snapshots.
#' @return Path of the newest snapshot, or `NA`.
#' @export
night_fetch_snapshot <- function(source) vec_feed_latest(source)

#' Stamp (`YYYYMMDD_HHMMSS`) in a snapshot's file name
#' @param path Snapshot file path.
#' @export
night_snapshot_stamp <- function(path) {
  m <- regmatches(basename(path), regexpr("[0-9]{8}_[0-9]{6}", basename(path)))
  if (!length(m)) NA_character_ else m
}

#' Copy a snapshot, byte for byte, into the dated raw archive (before anything parses it)
#'
#' Layout `<archive>/<YYYY-MM-DD>/<file name>`; the date is the one in the file name. An identical copy already
#' there is left alone; a DIFFERENT file with the same name is kept too (renamed `.v2`, `.v3`), so no raw
#' snapshot is ever overwritten.
#' @return List: `path` (the archived copy), `new` (TRUE when a copy was made).
#' @param path Snapshot file to archive.
#' @param archive_dir Root of the raw archive.
#' @export
night_archive_snapshot <- function(path, archive_dir) {
  stamp <- night_snapshot_stamp(path)
  day <- if (is.na(stamp)) "undated" else sub("^([0-9]{4})([0-9]{2})([0-9]{2}).*$", "\\1-\\2-\\3", stamp)
  dest_dir <- file.path(archive_dir, day); dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dest_dir, basename(path)); k <- 1L
  repeat {
    if (!file.exists(dest)) { ok <- file.copy(path, dest); if (!isTRUE(ok)) stop("NW2! could not copy ", path, " to ", dest, call. = FALSE)
      return(list(path = dest, new = TRUE)) }
    if (unname(tools::md5sum(dest)) == unname(tools::md5sum(path))) return(list(path = dest, new = FALSE))
    k <- k + 1L; dest <- file.path(dest_dir, sprintf("%s.v%d", basename(path), k))
  }
}

#' Affiliation id -> registered party name, from the VEC set-up "Candidates" file
#'
#' @param setup_dir Folder holding `*MediaFileCandidates*.xml` (set-up files; on the sample, in the sample folder).
#' @return data.table `affiliation_id, registered_name`, or `NULL` when the file is not there.
#' @export
night_party_lookup <- function(setup_dir) {
  f <- list.files(setup_dir, pattern = "Candidates.*\\.xml$", full.names = TRUE, ignore.case = TRUE)
  if (!length(f)) return(NULL)
  doc <- xml2::read_xml(f[1])
  aff <- xml2::xml_find_all(doc, "//*[local-name()='AffiliationIdentifier']")
  if (!length(aff)) return(NULL)
  out <- data.table::data.table(
    affiliation_id = xml2::xml_attr(aff, "Id"),
    registered_name = vapply(aff, function(a) xml2::xml_text(xml2::xml_find_first(a, "*[local-name()='RegisteredName']")), ""))
  out <- unique(out[!is.na(out$affiliation_id) & nzchar(out$affiliation_id), ])
  dup <- out[, list(n = data.table::uniqueN(registered_name)), by = "affiliation_id"]
  if (any(dup$n > 1L)) stop("NW2! affiliation ids with two names in ", basename(f[1]), ": ", paste(dup$affiliation_id[dup$n > 1L], collapse = ", "), call. = FALSE)
  unique(out, by = "affiliation_id")
}

#' STUB affiliation lookup, used only when the set-up file is missing and the caller allows it
#'
#' Every party candidate becomes "UNMAPPED" (which `classify_party()` files under OTH). Results from this are
#' NOT a usable update: it exists so the pipeline can be exercised without the set-up files (due 10 Nov).
#' @param ids Affiliation ids to map.
#' @export
night_affiliation_stub <- function(ids) {
  ids <- unique(ids[!is.na(ids)])
  data.table::data.table(affiliation_id = ids, registered_name = rep("UNMAPPED", length(ids)))
}

# VEC booth classification -> the booth_type night_booth_update() expects. An early voting centre is one
# unit per district ("early"), as are mobile teams; anything unrecognised is treated as ordinary and said so.
.night_class_map <- c(VotingCentre = "ordinary", EarlyVotingCentre = "early", MobileVoting = "early")
# District-level vote types (counts the VEC gives per district instead of per booth).
.night_type_map <- c(Ordinary = "ordinary", EVCEarly = "early", MobileVotingEarly = "early", Early = "early",
                     Postal = "postal", Absent = "absent", Provisional = "provisional", MarkedAsVoted = "marked_as_voted")
.night_unit_types <- c("early", "postal", "absent", "provisional", "marked_as_voted")
# Counted later than election night (the VEC guide: declaration votes admitted after checking). The night base is
# ordinary + early + postal, so with include_late = FALSE these are left out of the numerator AND the projected units.
.night_late_types <- c("absent", "provisional", "marked_as_voted")

#' Sanity-check a parsed snapshot; stops (NW1) rather than let a damaged one reach the model
#' @param feed Output of [vec_feed_read_lh()].
#' @export
night_check_feed <- function(feed) {
  if (is.null(feed$contests) || !nrow(feed$contests)) stop("NW1! snapshot has no contests", call. = FALSE)
  if (is.null(feed$candidates) || !nrow(feed$candidates)) stop("NW1! snapshot has no candidates", call. = FALSE)
  for (nm in c("candidates", "booths", "by_type")) {
    v <- feed[[nm]]$votes
    if (length(v) && (anyNA(v) || any(v < 0))) stop("NW1! snapshot table '", nm, "' has missing or negative votes", call. = FALSE)
  }
  cs <- feed$candidates[, list(s = sum(votes)), by = "district_id"]
  m <- merge(cs, feed$contests[, c("district_id", "formal")], by = "district_id")
  bad <- m$district_id[!is.finite(m$formal) | abs(m$s - m$formal) > 0.5]
  if (length(bad)) stop("NW1! candidate votes do not add to the formal total in district id(s): ", paste(bad, collapse = ", "), call. = FALSE)
  nocand <- setdiff(feed$contests$district_id, feed$candidates$district_id)
  if (length(nocand)) stop("NW1! contest(s) with no candidates in snapshot (district id ", paste(nocand, collapse = ", "), "): a seat would silently drop out", call. = FALSE)
  if (anyDuplicated(feed$contests$district)) stop("NW1! duplicate district names in snapshot", call. = FALSE)
  invisible(TRUE)
}

.norm_booth <- function(x) {
  x <- tolower(x); x <- gsub("[^a-z0-9 ]", " ", x)
  x <- gsub("\\bmt\\b", "mount", x); x <- gsub("\\bst\\b", "saint", x)
  trimws(gsub(" +", " ", x))
}

#' Stop (NW10) when a state seat has no voting centre in the polling list
#'
#' With the list in use, a seat with none listed would have no way to know its unreported booths (and its district-level
#' ordinary count is dropped), so its counted share would read as complete.
#' @param seats State seat names.
#' @param places [night_polling_places()] output.
#' @param allow `TRUE` to report the missing seats instead of stopping.
#' @export
night_check_places <- function(seats, places, allow = FALSE) {
  have <- sub(" District$", "", places$district[places$booth_class == "VotingCentre"])
  miss <- setdiff(seats, have)
  if (length(miss) && !isTRUE(allow))
    stop(sprintf("NW10! %d state seat(s) have no voting centre in the polling-locations list (%s)", length(miss), paste(utils::head(miss, 8), collapse = ", ")), call. = FALSE)
  invisible(miss)
}

#' Every polling place the VEC lists, from the set-up "PollingLocations" file
#'
#' A snapshot carries booth rows only for booths that have reported (checked on the 2026 sample: the first
#' snapshot has none, the second one per district), so this list is what says which booths are still to come.
#' @return data.table `district_id, district, booth_id, booth, booth_class`, or `NULL` when the file is not there.
#' @param setup_dir Folder holding the VEC set-up files.
#' @export
night_polling_places <- function(setup_dir) {
  f <- list.files(setup_dir, pattern = "PollingLocations.*[.]xml$", full.names = TRUE, ignore.case = TRUE)
  if (!length(f)) return(NULL)
  doc <- xml2::read_xml(f[1])
  pds <- xml2::xml_find_all(doc, "//*[local-name()='PollingDistrict']")
  out <- data.table::rbindlist(lapply(pds, function(pd) {
    id <- xml2::xml_find_first(pd, "*[local-name()='PollingDistrictIdentifier']")
    pp <- xml2::xml_find_all(pd, ".//*[local-name()='PollingPlaceIdentifier']")
    if (!length(pp)) return(NULL)
    data.table::data.table(district_id = xml2::xml_attr(id, "Id"), district = xml2::xml_text(xml2::xml_find_first(id, "*[local-name()='Name']")),
                           booth_id = xml2::xml_attr(pp, "Id"), booth = xml2::xml_attr(pp, "Name"), booth_class = xml2::xml_attr(pp, "Classification"))
  }))
  if (is.null(out) || !nrow(out)) NULL else out
}

#' Convert a parsed Assembly snapshot into the booth table shape the night update expects
#'
#' @param feed Output of [vec_feed_read_lh()].
#' @param lookup [night_party_lookup()] output (or [night_affiliation_stub()]).
#' @param include_late Keep absent, provisional and marked-as-voted rows (counted after election night). `FALSE` (default)
#'   drops them from the table, so they are neither counted nor projected: the night base is ordinary + early + postal.
#' @param places [night_polling_places()] output. Ordinary booths listed there but absent from the snapshot get a
#'   zero-vote row (unreported units, so they can be projected); `NULL` adds none.
#' @return List: `live` (`district, booth, booth_type, party, votes`; every unit of every district, reported
#'   or not), `counted` (`district, unit` of units with votes), `tcp` (`district, booth, vote_type, party_raw,
#'   votes`: the VEC's 2CP in booths, empty when none), `unmapped` (affiliation ids with no name),
#'   `n_placeholder_booths` (listed booths with no row in the snapshot).
#'   District names lose a trailing " District" (2026 contests are "Bass District", our seats "Bass").
#'   Counts per booth where the district has booth rows of that kind, per district vote type otherwise: never both.
#' @export
night_booth_table <- function(feed, lookup, places = NULL, include_late = FALSE) {
  dn <- function(x) sub(" District$", "", x)
  cd <- data.table::copy(feed$candidates)
  cd[, affiliation_id := as.character(affiliation_id)]
  cd <- merge(cd, lookup, by = "affiliation_id", all.x = TRUE, sort = FALSE)
  unmapped <- unique(cd$affiliation_id[!cd$independent & is.na(cd$registered_name) & !is.na(cd$affiliation_id)])
  cd[, party := data.table::fifelse(independent, "Independent", data.table::fifelse(is.na(registered_name), "UNMAPPED", registered_name))]
  dis <- feed$contests[, c("district_id", "district")]; dis[, seat := dn(district)]
  cd <- merge(cd, dis[, c("district_id", "seat")], by = "district_id", sort = FALSE)
  cmap <- cd[, c("district_id", "candidate_id", "seat", "party")]

  rows <- list()
  bo <- feed$booths
  if (!is.null(bo) && nrow(bo)) {
    bt <- unname(.night_class_map[bo$booth_class])
    unk <- is.na(bt)
    if (any(unk)) { message("NW2  unrecognised booth classification(s) treated as ordinary: ", paste(unique(bo$booth_class[unk]), collapse = ", ")); bt[unk] <- "ordinary" }
    bo <- data.table::copy(bo); bo[, booth_type := bt]
    bo <- merge(bo, cmap, by = c("district_id", "candidate_id"), all.x = TRUE, sort = FALSE)
    if (anyNA(bo$party)) stop("NW2! booth votes for a candidate id that is not in the district's candidate list", call. = FALSE)
    rows[[1]] <- bo[, list(district = seat, booth, booth_type, party, votes)]
  }
  have_booth <- if (length(rows)) unique(rows[[1]][, c("district", "booth_type")]) else data.table::data.table(district = character(), booth_type = character())
  bty <- feed$by_type
  if (!is.null(bty) && nrow(bty)) {
    bty <- bty[!bty$candidate_id %in% c("FORMAL", "INFORMAL"), ]
    tt <- unname(.night_type_map[bty$vote_type])
    if (anyNA(tt)) { message("NW2  unrecognised vote type(s) skipped: ", paste(unique(bty$vote_type[is.na(tt)]), collapse = ", ")) }
    bty <- data.table::copy(bty); bty[, booth_type := tt]; bty <- bty[!is.na(bty$booth_type), ]
    bty <- merge(bty, cmap, by = c("district_id", "candidate_id"), all.x = TRUE, sort = FALSE)
    if (anyNA(bty$party)) stop("NW2! district vote-type counts for a candidate id that is not in the district's list", call. = FALSE)
    # booth rows of a kind exist for the district -> its per-type district count would count the same votes twice
    # (only the three types a booth can carry; postal, absent etc. exist only at district level)
    covered <- paste(have_booth$district, have_booth$booth_type)
    # "Early" is deliberately NOT in this list: the VEC guide defines it as early votes cast OUTSIDE the elector's
    # district (not EVCEarly), which no in-district booth row carries. It is 0 on every 2026 sample snapshot, so this
    # is from the guide, not confirmed on data; revisit on the 25 Nov trial.
    carried <- bty$vote_type %in% c("Ordinary", "EVCEarly", "MobileVotingEarly")
    drop <- carried & paste(bty$seat, bty$booth_type) %in% covered
    # ordinary votes exist only in booths: for a district with listed voting centres a district-level "Ordinary" row would be a
    # phantom unit; a district with none listed keeps it (night_check_places() stops the cycle on that anyway, NW10)
    if (!is.null(places)) {
      listed <- merge(places[places$booth_class == "VotingCentre", "district_id"], cmap[!duplicated(cmap$district_id), c("district_id", "seat")], by = "district_id")$seat
      drop <- drop | (bty$vote_type == "Ordinary" & bty$seat %in% listed)
    }
    bty <- bty[!drop, ]
    rows[[length(rows) + 1L]] <- bty[, list(district = seat, booth = paste0("(district ", booth_type, ")"), booth_type, party, votes)]
  }
  live <- data.table::rbindlist(rows, use.names = TRUE)
  if (!nrow(live)) live <- data.table::data.table(district = character(), booth = character(), booth_type = character(), party = character(), votes = numeric())
  n_placeholder_booths <- 0L; n_unlisted <- 0L
  if (!is.null(places)) {
    pl <- places[places$booth_class == "VotingCentre", ]
    pl <- merge(pl, cmap[!duplicated(cmap$district_id), c("district_id", "seat", "party")], by = "district_id")
    # snapshot booths the polling list does not know (a renamed or missing entry): logged, never stopping (NW11)
    ob <- unique(live[live$booth_type == "ordinary", c("district", "booth")])
    ob <- ob[!paste(ob$district, .norm_booth(ob$booth)) %in% paste(pl$seat, .norm_booth(pl$booth)), ]
    if (nrow(ob)) message("NW11  ", nrow(ob), " snapshot booth(s) not in the polling list (no placeholder made for them): ", paste(utils::head(paste0(ob$booth, " [", ob$district, "]"), 8), collapse = "; "))
    n_unlisted <- nrow(ob)
    # no placeholder where a reported booth matches by name after normalising (Mt/Mount, St/Saint, case, punctuation)
    pl <- pl[!paste(pl$seat, .norm_booth(pl$booth)) %in% paste(live$district, .norm_booth(live$booth)), ]
    if (nrow(pl)) { n_placeholder_booths <- nrow(pl)
      live <- rbind(live, pl[, list(district = seat, booth, booth_type = "ordinary", party, votes = 0)]) }
  }
  if (!include_late) live <- live[!live$booth_type %in% .night_late_types, ]
  # placeholders: a district-level unit with no rows at all still has to exist (uncounted) so it is projected
  p1 <- cmap[!duplicated(cmap$seat), c("seat", "party")]
  ph <- data.table::rbindlist(lapply(if (include_late) .night_unit_types else setdiff(.night_unit_types, .night_late_types), function(ty) {
    have <- live$district[live$booth_type == ty]
    x <- p1[!p1$seat %in% have, ]
    if (!nrow(x)) NULL else x[, list(district = seat, booth = paste0("(district ", ty, ")"), booth_type = ty, party, votes = 0)]
  }))
  if (!is.null(ph) && nrow(ph)) live <- rbind(live, ph)
  live[, unit := data.table::fifelse(booth_type == "ordinary", booth, booth_type)]
  tot <- live[, list(tv = sum(votes)), by = c("district", "unit")]
  counted <- tot[tot$tv > 0, c("district", "unit")]
  live[, unit := NULL]

  tcp <- data.table::data.table(district = character(), booth = character(), vote_type = character(), party_raw = character(), votes = numeric())
  bt2 <- feed$booth_tcp
  if (!is.null(bt2) && nrow(bt2)) {
    btt <- unname(.night_class_map[bt2$booth_class]); btt[is.na(btt)] <- "ordinary"
    bt2 <- data.table::copy(bt2); bt2[, vote_type := btt]
    bt2 <- merge(bt2, cmap, by = c("district_id", "candidate_id"), all.x = TRUE, sort = FALSE)
    bt2 <- bt2[!is.na(bt2$party), ]
    tcp <- bt2[, list(district = seat, booth, vote_type, party_raw = party, votes)]
  }
  list(live = live[], counted = counted[], tcp = tcp[], unmapped = unmapped, n_placeholder_booths = n_placeholder_booths, n_unlisted_booths = n_unlisted)
}

#' Per-booth results for the live page's map: every ordinary booth that has reported
#'
#' Only booths with counted votes appear; an unreported booth is absent (the page draws it from last time's file). First
#' preferences are in the map's four classes (`ALP`, `LNP`, `GRN`, `OTH`: One Nation, independents and minor-right all fall in
#' `OTH`, as in the page's `booths-vic2022.json`). The two-candidate count keeps [classify_party()]'s class, so an independent
#' in the final two reads as `IND`.
#' @param conv [night_booth_table()] output.
#' @param ref Booth table of the previous election (`district, booth, booth_type, party, votes`), for `sn`; `NULL` leaves
#'   `sn` out.
#' @return Named list by district of lists `{n, counted = TRUE, now = {ALP, LNP, GRN, OTH}, tn = [[party, votes], [party, votes]] | NULL, sn}`
#'   (`tn` classes are [classify_party()]'s, so `ONP` and `OTH_RIGHT` can appear there, unlike `now`),
#'   `tn` larger first and `NULL` until the VEC posts that booth's two-candidate count (or when two candidates share a class).
#'   `sn` is the booth's swing toward Labor ([night_seat_swing()] has the measure), `NULL` when the booth has no match last time.
#' @export
night_booth_results <- function(conv, ref = NULL) {
  lv <- conv$live[conv$live$booth_type == "ordinary", ]
  if (!nrow(lv)) return(stats::setNames(list(), character()))
  # a damaged reference table costs the swing (NW14), never the booths themselves
  prev <- if (is.null(ref)) NULL else tryCatch(.night_ref_four(ref), error = function(e) { message("NW14  booth swing skipped: ", conditionMessage(e)); NULL })
  cls4 <- classify_party(lv$party); cls4[!cls4 %in% c("ALP", "LNP", "GRN")] <- "OTH"
  fp <- data.table::data.table(district = lv$district, booth = lv$booth, cls = cls4, votes = lv$votes)[, list(votes = sum(votes)), by = c("district", "booth", "cls")]
  tot <- fp[, list(tv = sum(votes)), by = c("district", "booth")]
  tot <- tot[tot$tv > 0, ]
  tc <- conv$tcp
  tc <- if (!is.null(tc) && nrow(tc)) tc[tc$vote_type == "ordinary", ] else tc
  tkey <- if (!is.null(tc) && nrow(tc)) paste(tc$district, tc$booth, sep = "\r") else character()
  tcls <- if (length(tkey)) classify_party(tc$party_raw) else character()
  fkey <- paste(fp$district, fp$booth, sep = "\r")
  by_f <- split(seq_len(nrow(fp)), fkey); by_t <- split(seq_along(tkey), tkey)
  rows <- lapply(seq_len(nrow(tot)), function(i) {
    k <- paste(tot$district[i], tot$booth[i], sep = "\r"); r <- by_f[[k]]
    now <- lapply(c(ALP = "ALP", LNP = "LNP", GRN = "GRN", OTH = "OTH"), function(p) sum(fp$votes[r][fp$cls[r] == p]))
    tn <- NULL; hit <- by_t[[k]]
    if (length(hit)) {
      v <- tapply(tc$votes[hit], tcls[hit], sum)
      if (length(v) == 2L && sum(v) > 0) { v <- sort(v, decreasing = TRUE); tn <- lapply(seq_along(v), function(j) list(names(v)[j], unname(v[[j]]))) }
    }
    out <- list(n = tot$booth[i], counted = TRUE, now = now, tn = tn)
    if (!is.null(prev)) {
      j <- match(paste(.night_norm(tot$district[i]), .night_norm(tot$booth[i]), sep = "\r"), prev$key4)
      out["sn"] <- list(if (is.na(j)) NULL else round(.night_gap(now$ALP, now$LNP, tot$tv[i]) - .night_gap(prev$alp[j], prev$lnp[j], prev$tot[j]), 2))
    }
    out
  })
  split(rows, tot$district)
}

# Letters and digits only, lower case: the booth-name match the page's builder uses (ITG politics/night-maps/build-booths.py).
.night_norm <- function(x) gsub("[^a-z0-9]", "", tolower(x))
# Labor minus Coalition, in points of every first preference (other candidates stay in the denominator).
.night_gap <- function(alp, lnp, total) (alp - lnp) / total * 100
# The previous election's ordinary booths as Labor, Coalition and all votes, keyed by normalised district and booth; booths
# with no votes are dropped so a match always has a denominator.
.night_ref_four <- function(ref) {
  miss <- setdiff(c("district", "booth", "booth_type", "party", "votes"), names(ref))
  if (length(miss)) stop("previous-election booth table lacks ", paste(miss, collapse = ", "), call. = FALSE)
  r <- ref[ref$booth_type == "ordinary", ]
  cls <- classify_party(r$party)
  d <- data.table::data.table(key4 = paste(.night_norm(r$district), .night_norm(r$booth), sep = "\r"),
                              is_alp = cls == "ALP", is_lnp = cls == "LNP", v = as.numeric(r$votes))
  d <- d[, list(alp = sum(v[is_alp]), lnp = sum(v[is_lnp]), tot = sum(v)), by = "key4"]
  d[d$tot > 0, ]
}

#' Each seat's swing toward Labor so far, for the live map's district arrows
#'
#' The measure the page's replay file carries (`s` per booth, `dswing` per district; ITG
#' `politics/night-maps/build-booths.py`): the change in Labor's share minus the Coalition's share of ordinary first
#' preferences, in points, positive toward Labor, every other candidate kept in the denominator. Like for like: only the
#' seat's reported booths that match a booth last time (by district and booth name, letters and digits, case ignored),
#' summed tonight against the same booths last time, so a partial count is never set against a whole-district total.
#' @param booths [night_booth_results()] output.
#' @param ref Booth table of the previous election (`district, booth, booth_type, party, votes`).
#' @return Named numeric by district, rounded to 2 dp; a seat with no matched booth is absent.
#' @export
night_seat_swing <- function(booths, ref) {
  prev <- .night_ref_four(ref)
  sw <- vapply(names(booths), function(d) {
    a <- c(0, 0, 0); o <- c(0, 0, 0)
    for (b in booths[[d]]) {
      j <- match(paste(.night_norm(d), .night_norm(b$n), sep = "\r"), prev$key4)
      if (is.na(j)) next
      a <- a + c(b$now$ALP, b$now$LNP, sum(unlist(b$now))); o <- o + c(prev$alp[j], prev$lnp[j], prev$tot[j])
    }
    if (a[3] > 0 && o[3] > 0) round(.night_gap(a[1], a[2], a[3]) - .night_gap(o[1], o[2], o[3]), 2) else NA_real_
  }, numeric(1))
  sw[!is.na(sw)]
}

#' [night_booth_results()] that never stops a cycle: on any error the map's booth block is left out (`NULL`, logged NW13)
#' and the seats still publish.
#' @param conv [night_booth_table()] output.
#' @param ref See [night_booth_results()].
#' @export
night_booth_results_safe <- function(conv, ref = NULL) {
  tryCatch(night_booth_results(conv, ref), error = function(e) { message("NW13  booth block skipped: ", conditionMessage(e)); NULL })
}

#' [night_seat_swing()] that never stops a cycle: no booths, no reference table or any error gives `NULL` (an error is
#' logged NW14), and the seats publish without `swing`.
#' @inheritParams night_seat_swing
#' @export
night_seat_swing_safe <- function(booths, ref) {
  if (is.null(booths) || is.null(ref) || !length(booths)) return(NULL)
  tryCatch(night_seat_swing(booths, ref), error = function(e) { message("NW14  seat swing skipped: ", conditionMessage(e)); NULL })
}

#' Stop (NW7) unless the saved state's seats and the feed's districts are the same set
#'
#' A seat missing from the feed would silently keep its prior as if nothing had been counted there, and a feed
#' district the state does not know would be ignored; either means the wrong state, a renamed district or a damaged
#' conversion, so the cycle refuses to publish. `allow` is for exercising the pipeline on mismatched data (the
#' 2026 sample against the vic2022 state) only.
#' @param seats Seat names in the saved state.
#' @param feed_districts District names in the converted feed.
#' @param allow `TRUE` to report the mismatch instead of stopping.
#' @export
night_check_coverage <- function(seats, feed_districts, allow = FALSE) {
  miss <- setdiff(seats, feed_districts); extra <- setdiff(feed_districts, seats)
  if ((length(miss) || length(extra)) && !isTRUE(allow))
    stop(sprintf("NW7! seats and feed districts differ: %d state seat(s) not in the feed (%s); %d feed district(s) not in the state (%s)",
                 length(miss), paste(utils::head(miss, 6), collapse = ", "), length(extra), paste(utils::head(extra, 6), collapse = ", ")), call. = FALSE)
  invisible(list(missing = miss, extra = extra))
}

#' Refuse a snapshot that is older than the one the last published JSON came from (NW8)
#' @return `"ok"`, or `"same"` when it is the snapshot already published.
#' @param stamp Stamp of the snapshot about to be used ([night_snapshot_stamp()]).
#' @param out_file The published JSON.
#' @export
night_check_fresh <- function(stamp, out_file) {
  if (!file.exists(out_file)) return("ok")
  doc <- tryCatch(jsonlite::fromJSON(out_file, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(doc)) stop("NW8! the published JSON ", out_file, " exists but cannot be read; not overwriting it blindly (inspect or move it)", call. = FALSE)
  prev <- doc$night$snapshot_stamp
  if (is.null(prev) || is.na(stamp)) return("ok")
  if (identical(prev, stamp)) return("same")
  if (stamp < prev) stop("NW8! snapshot ", stamp, " is older than the published JSON's (", prev, "): stale or reordered file, not published", call. = FALSE)
  "ok"
}

#' Previous election's Assembly votes per district, as a turnout table
#'
#' The turnout base must be the Assembly count the night counts: `rbvc_formal` in the council stats file is the
#' UPPER-HOUSE formal count (1.026x the Assembly booth-file total in 2022, n = 86), so it is not used. Enrolment is a
#' district roll and is taken from the council stats file.
#' @param stats Data frame `district` (names ending " District"), `enrolment` (previous election's council stats file).
#' @param booths_prev Previous election's booth table (`district, booth, booth_type, party, votes`).
#' @return data.table `district, enrolment, total_votes` (all vote types, final), `night_votes` (ordinary + early +
#'   postal: what is counted on the night; absent, provisional and marked-as-voted come later).
#' @export
night_turnout_table <- function(stats, booths_prev) {
  b <- data.table::as.data.table(booths_prev)
  v <- ifelse(is.na(b$votes), 0, b$votes)
  tot <- data.table::data.table(district = b$district, v = v, night = b$booth_type %in% c("ordinary", "early", "postal"))
  agg <- tot[, list(total_votes = sum(v), night_votes = sum(v[night])), by = "district"]
  e <- data.table::data.table(district = sub(" District$", "", stats$district), enrolment = stats$enrolment)
  merge(e, agg, by = "district")
}

#' Expected votes per seat: enrolment x the seat's Assembly turnout at the previous election
#'
#' `basis = "final"`: the final all-vote-type Assembly total. `basis = "night"`: the part counted on the night
#' (ordinary + early + postal), i.e. expected-final times the seat's previous night share. A seat not in the
#' table takes the statewide rate.
#' @param enrolment Named numeric: enrolment per seat now (the feed's contests carry it).
#' @param prev [night_turnout_table()] output.
#' @param basis `"night"` or `"final"`.
#' @export
night_expected_votes <- function(enrolment, prev, basis = c("night", "final")) {
  basis <- match.arg(basis)
  col <- if (basis == "night") prev$night_votes else prev$total_votes
  rate <- col / prev$enrolment
  state_rate <- sum(col) / sum(prev$enrolment)
  r <- rate[match(names(enrolment), prev$district)]; r[is.na(r)] <- state_rate
  stats::setNames(unname(enrolment) * r, names(enrolment))
}

#' Run the night update, simulation and 2CP flow update from a prior state and a live booth table
#'
#' The same steps as `scripts/night_replay.R` (`run_one`), driven by a table of reported units instead of a
#' simulated fraction. A seat with no feed data (or none that matches a reference booth) keeps the prior.
#' @param st Saved prior state (`AUSPOL_NIGHT_DUMP` shape).
#' @param conv [night_booth_table()] output.
#' @param ref Booth table of the election before the one being counted (`output/booths-vicYYYY.csv`).
#' @param gap_k Pooled vote-type gap shrinkage (5 = the setting rehearsed in #160); `NULL` off.
#' @param total Counted-share denominator: `"expected"` (live: enrolment x turnout, see [night_expected_votes()], night basis),
#'   `"projected"` (from previous-election booth sizes; the over-confident fallback) or `"table"` (replay equivalence).
#' @param expected Named numeric of expected final votes per seat, for `total = "expected"`.
#' @param sims Simulations (default the state's).
#' @param use_tcp Condition on the VEC's 2CP flow where its pair is plausible.
#' @return List: `sim`, `nu` (the update), `shares`, `sd`, `matched` (seats in both state and feed),
#'   `n_updated`.
#' @export
night_run_update <- function(st, conv, ref, gap_k = 5, total = c("projected", "table", "expected"), expected = NULL, sims = NULL, use_tcp = TRUE) {
  total <- match.arg(total)
  if (is.null(sims)) sims <- st$n_sims
  if (!is.null(st$swd) && nrow(st$swd) != sims) stop("NW2! the saved state has ", nrow(st$swd), " statewide draws; sims must equal that (dump the state at the sim count wanted)", call. = FALSE)
  seats <- rownames(st$shares)
  matched <- intersect(seats, unique(conv$live$district))
  shares <- st$shares; sdo <- st$sdo; swd <- st$swd
  nu <- night_booth_update(shares, night_prior_sd(shares, st$level_sd, st$level_mult, sdo), 1, conv$live, ref,
                           gap_k = gap_k, reported = conv$counted, total = total, expected = expected)
  if (nu$n_updated > 0L) {
    shares <- nu$shares; sdo <- nu$sd; swd <- night_shrink_draws(swd, 1 - nu$resolved)
  }
  sim <- simulate_seat_contests(level_sd = st$level_sd, sd_override = sdo, level_mult = st$level_mult, shares, st$fm,
                                party_sd = st$psd, statewide_draws = swd, seat_sd = st$seat_sd, n_sims = sims,
                                breakout_p = st$bo$p, breakout_q = st$bo$q, coalition_split = st$coalition_split, error_q = st$error_q,
                                smooth = st$smooth, seed = st$seed, party_cor = st$party_cor, shrink = st$shrink,
                                conditional_override = st$htv_ov, conditional_override_sd = attr(st$htv_ov, "sd"),
                                fallback_smooth = st$fb_smooth, shrink_k = st$shrink_k, flow_sd = st$flow_sd,
                                surge_h = st$surge_h, surge_party = st$surge_party, surge_from_zero = st$surge_from_zero,
                                surge_mu = st$surge_mu, surge_sd = st$surge_sd)
  n_tcp <- 0L
  if (use_tcp && nu$n_updated > 0L && nrow(conv$tcp)) {
    obs <- night_tcp_obs(conv$tcp, conv$live, nu$units, shares)
    n_tcp <- nrow(obs)
    sim <- night_apply_tcp(sim, obs)
  }
  list(sim = sim, nu = nu, shares = shares, sd = sdo, matched = matched, n_updated = nu$n_updated, n_tcp = n_tcp)
}

#' Build the published-shape JSON document from a night update
#'
#' Same top-level keys as `forecast-vic2026.json` (scripts/build_forecast_json.R) plus `counted_pct` per seat and
#' a `night` block (built_at, the snapshot it came from, how many seats had feed data). Fields the night
#' model does not recompute (`track_record`, `poll_source`, `region`) are copied from `base` when given, else NULL.
#' `primary_q` is not produced (the update gives a posterior sd, not draws); `primary_sd` is given instead.
#' Added for the live page (#162), all additive: per party `chamber$parties[[p]]$hist` (draws giving k seats, k = 0..`chamber_seats`),
#' per seat party `primary_prior` (the afternoon first preference, so the page can show movement) and per seat `vec_2cp`
#' (the VEC's two-candidate count where the update used it, else `null`: `vec_share_a` is the RAW counted share of `a` over `a` + `b`
#' in the booths reported, `flow_share_a` the flow-based projection of the final share from first preferences and flow, `model_share_a` the
#' simulated posterior mean, and `wrong_pair` TRUE when the VEC's pair is not one the model expected).
#' @param base A parsed published `forecast-vic2026.json` (list), or `NULL`.
#' @param st Saved afternoon state (an `AUSPOL_NIGHT_DUMP` RDS, read).
#' @param res Result of [night_run_update()].
#' @param snapshot Path of the snapshot the update came from.
#' @param election Election label.
#' @param election_date Polling day, `YYYY-MM-DD`.
#' @param booths [night_booth_results()] output, written as top-level `booths` (by district: the booths reported so far); `NULL` writes `"booths": null`, which the page reads as none reported.
#' @param swing [night_seat_swing()] output, written as `swing` on each seat it names (points toward Labor); a seat it
#'   does not name, or `NULL`, writes `"swing": null`, which the page draws without an arrow.
#' @export
night_build_json <- function(st, res, snapshot, base = NULL, election = "vic2026", election_date = "2026-11-28", booths = NULL,
                             swing = NULL) {
  sim <- res$sim; tot <- as.data.frame(sim$totals); parties <- colnames(sim$totals)
  seats <- rownames(res$shares); n_seats <- length(seats)
  majority <- if (!is.null(base$majority)) base$majority else floor(n_seats / 2) + 1L
  q <- function(x) as.list(round(stats::quantile(x, c(0.05, 0.25, 0.5, 0.75, 0.95), type = 1), 1))
  row_max <- do.call(pmax, as.list(tot)); n_at_max <- Reduce(`+`, lapply(parties, function(p) tot[[p]] == row_max))
  chamber <- lapply(parties, function(p) list(party = p, expected = round(mean(tot[[p]]), 2),
                                              p_majority = round(mean(tot[[p]] >= majority), 4),
                                              p_most_seats = round(mean(tot[[p]] == row_max), 4),
                                              p_most_seats_strict = round(mean(tot[[p]] == row_max & n_at_max == 1L), 4),
                                              quantiles = q(tot[[p]]),
                                              # draws that gave this party k seats, k = 0..chamber_seats (index k + 1): the page's histograms
                                              hist = unname(as.integer(table(factor(as.integer(tot[[p]]), levels = 0:n_seats))))))
  names(chamber) <- parties
  maj_l <- if ("LNP" %in% parties) tot$LNP else 0; maj_a <- if ("ALP" %in% parties) tot$ALP else 0
  onp <- if ("ONP" %in% parties) tot$ONP else 0
  onp_bop <- mean(pmax(maj_l, maj_a) < majority & pmax(maj_l, maj_a) + onp >= majority & onp > 0)
  region <- if (!is.null(base$seats)) stats::setNames(vapply(base$seats, function(s) if (is.null(s$region)) NA_character_ else s$region, ""), vapply(base$seats, `[[`, "", "seat")) else NULL
  wp <- as.data.frame(sim$win_prob)
  nt <- attr(sim, "night_tcp"); if (!is.null(nt)) nt <- as.data.frame(nt)
  tw <- sim$tcp_winner; tr <- sim$tcp_runnerup
  seat_rows <- lapply(seats, function(s) {
    w <- wp[wp$seat == s, ]
    ps <- lapply(colnames(res$shares), function(p) list(party = p, win_prob = round(if (p %in% w$party) w$prob[w$party == p] else 0, 4),
                                                         primary = round(res$shares[s, p], 2), primary_sd = round(res$sd[s, p], 2),
                                                         primary_prior = if (!is.null(st$shares) && s %in% rownames(st$shares) && p %in% colnames(st$shares)) round(st$shares[s, p], 2) else NULL,
                                                         candidate = NULL, sitting = NULL))
    ps <- ps[order(-vapply(ps, `[[`, numeric(1), "win_prob"))]
    ft <- NULL
    if (!is.null(tw) && s %in% colnames(tw)) {
      pr <- paste(pmin(tw[, s], tr[, s]), pmax(tw[, s], tr[, s]), sep = "|"); top <- names(sort(table(pr), decreasing = TRUE))[1]
      hit <- pr == top; ab <- strsplit(top, "|", fixed = TRUE)[[1]]
      lead <- names(sort(table(tw[hit, s]), decreasing = TRUE))[1]
      ft <- list(leader = lead, other = setdiff(ab, lead), p_pair = round(mean(hit), 4), p_leader_wins_pair = round(mean(tw[hit, s] == lead), 4))
      if (!length(ft$other)) ft$other <- NULL
    }
    # the VEC's two-candidate count where the update used it: `wrong_pair` TRUE = the VEC's pair is not one the model expected
    v2 <- NULL
    if (!is.null(nt) && s %in% nt$seat) { r <- nt[nt$seat == s, ][1L, ]
      v2 <- list(a = r$a, b = r$b, vec_share_a = if (is.finite(r$raw_a)) round(r$raw_a, 4) else NULL, flow_share_a = round(r$obs_a, 4), model_share_a = if (is.finite(r$post_a)) round(r$post_a, 4) else NULL,
                 pair_share = round(r$pair_share, 4), wrong_pair = isTRUE(r$flag)) }
    list(seat = s, vec_2cp = v2, region = if (!is.null(region) && s %in% names(region) && !is.na(region[[s]])) region[[s]] else NULL,
         favourite = ps[[1]]$party, favourite_prob = ps[[1]]$win_prob, final_two = ft,
         counted_pct = round(100 * unname(res$nu$counted[s]), 1), parties = ps,
         swing = if (!is.null(swing) && s %in% names(swing)) unname(swing[s]) else NULL)
  })
  list(election = election, election_date = election_date, built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
       git_sha = tryCatch(trimws(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)), error = function(e) NA_character_),
       models_promoted_at = base$models_promoted_at, track_record = base$track_record, poll_source = base$poll_source,
       chamber_seats = n_seats, seats_simulated = n_seats, seats_not_simulated = I(character()), majority = majority,
       n_sims = nrow(tot),
       chamber = list(parties = chamber, p_hung = round(mean(row_max < majority), 4), p_onp_balance_of_power = round(onp_bop, 4),
                      p_tie_most = round(mean(n_at_max > 1L), 4)),
       night = list(snapshot = snapshot$file, snapshot_stamp = snapshot$stamp, snapshot_archived = snapshot$archived,
                    seats_with_feed_data = length(res$matched), seats_updated = res$n_updated, seats_with_2cp = res$n_tcp,
                    prior_state = st$pair, counted_denominator = res$denominator, unreported_booths_listed = res$n_placeholder, snapshot_booths_not_listed = res$n_unlisted, seats_on_projected_denominator = length(res$nu$fallback_projected), mean_counted_pct = round(100 * mean(res$nu$counted), 1)),
       seats = seat_rows, booths = booths)
}

#' Write a JSON document atomically and validated: temp file, read it back, then rename over the target
#' @return The target path. Stops (NW4) without touching the target if the document does not read back as expected.
#' @param doc The document (a list) to write.
#' @param out_file Target path.
#' @param min_seats Fewest seats the read-back document must hold.
#' @export
night_publish_json <- function(doc, out_file, min_seats = 1L) {
  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(out_file, ".tmp-", Sys.getpid())
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", digits = 4), tmp)
  back <- tryCatch(jsonlite::fromJSON(tmp, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(back) || length(back$seats) < min_seats || is.null(back$chamber) || is.null(back$night))
    stop("NW4! output did not read back as a full document; nothing published", call. = FALSE)
  if (!isTRUE(file.rename(tmp, out_file))) stop("NW4! could not rename ", tmp, " to ", out_file, call. = FALSE)
  out_file
}

#' One election-night cycle
#'
#' @param cfg List: `source`, `archive`, `setup`, `state` (RDS path or already-read list), `ref` (booth CSV path),
#'   `out` (JSON path), optional `base_json`, `gap_k` (5), `sims`, `use_tcp` (TRUE), `allow_stub` (FALSE),
#'   `turnout` (previous-election `council-district-stats-<year>.csv`, for its enrolment; turnout comes from the `ref` Assembly table; without it the cycle falls
#'   back to the over-confident projected one and says so), `allow_unmatched` (NW7 and NW10 off; sample-vs-vic2022 test only), `allow_projected` (accept the over-confident
#'   projected denominator when `turnout` is missing; otherwise NW9 stops the cycle),
#'   `last_stamp` (skip when the newest snapshot has this stamp), `cache` (environment for the state and lookup).
#' @return List: `status` ("ok", "no_new" or "failed"), `stamp`, `timings` (seconds per step), `message`, `summary`.
#' @export
night_cycle <- function(cfg) {
  tm <- list(); t0 <- proc.time()[["elapsed"]]; stamp_t <- function(nm) { t1 <- proc.time()[["elapsed"]]; tm[[nm]] <<- round(t1 - t0, 2); t0 <<- t1 }
  cache <- if (is.null(cfg$cache)) new.env() else cfg$cache
  fail <- function(e, stamp = NA_character_) list(status = "failed", stamp = stamp, timings = tm, message = conditionMessage(e),
                                                   summary = sprintf("FAILED %s: %s", stamp, conditionMessage(e)))
  snap <- night_fetch_snapshot(cfg$source); stamp_t("fetch")
  if (is.na(snap)) return(list(status = "failed", stamp = NA_character_, timings = tm, message = "NW5! no snapshot in source",
                               summary = "FAILED: NW5! no snapshot in source"))
  stamp <- night_snapshot_stamp(snap)
  if (!is.null(cfg$last_stamp) && identical(stamp, cfg$last_stamp)) return(list(status = "no_new", stamp = stamp, timings = tm, message = "", summary = paste("no new snapshot after", stamp)))
  tryCatch({
    arch <- night_archive_snapshot(snap, cfg$archive); stamp_t("archive")
    feed <- vec_feed_read_lh(arch$path); stamp_t("parse")
    night_check_feed(feed)
    if (identical(night_check_fresh(stamp, cfg$out), "same"))
      return(list(status = "no_new", stamp = stamp, timings = tm, message = "", summary = paste("snapshot", stamp, "is already published")))
    if (!isTRUE(cache$places_done)) {
      pl <- night_polling_places(cfg$setup)
      if (is.null(pl)) {
        if (!isTRUE(cfg$allow_stub)) stop("NW6! no *PollingLocations*.xml set-up file in ", cfg$setup, ": unreported booths cannot be known, so counted share would read 100%", call. = FALSE)
        message("NW6  NO POLLING LOCATIONS FILE (stub allowed): unreported booths are unknown and counted share is overstated")
        pl <- NULL
      }
      cache$places <- pl; cache$places_done <- TRUE
    }
    if (is.null(cache$lookup)) {
      lk <- night_party_lookup(cfg$setup)
      if (is.null(lk)) {
        if (!isTRUE(cfg$allow_stub)) stop("NW3! no *Candidates*.xml set-up file in ", cfg$setup, " (party names unknown); pass allow_stub only to exercise the pipeline", call. = FALSE)
        message("NW3  USING THE STUB AFFILIATION LOOKUP: every party is UNMAPPED; the update below is NOT meaningful")
        lk <- night_affiliation_stub(feed$candidates$affiliation_id)
      }
      cache$lookup <- lk
    }
    if (is.null(cache$st)) cache$st <- if (is.character(cfg$state)) readRDS(cfg$state) else cfg$state
    if (is.null(cache$ref)) cache$ref <- if (is.character(cfg$ref)) data.table::fread(cfg$ref, showProgress = FALSE) else cfg$ref
    if (is.null(cache$base) && !is.null(cfg$base_json)) cache$base <- jsonlite::fromJSON(cfg$base_json, simplifyVector = FALSE)
    stamp_t("load")
    conv <- night_booth_table(feed, cache$lookup, cache$places); stamp_t("convert")
    night_check_coverage(rownames(cache$st$shares), conv$live$district, cfg$allow_unmatched)
    if (!is.null(cache$places)) night_check_places(rownames(cache$st$shares), cache$places, cfg$allow_unmatched)
    if (length(conv$unmapped)) message("NW3  affiliation ids with no name: ", paste(conv$unmapped, collapse = ", "))
    expected <- NULL; denom <- "projected"
    if (!is.null(cfg$turnout)) {
      if (is.null(cache$turnout)) cache$turnout <- data.table::fread(cfg$turnout, showProgress = FALSE)
      enr <- stats::setNames(feed$contests$enrolment, sub(" District$", "", feed$contests$district))
      expected <- night_expected_votes(enr, night_turnout_table(cache$turnout, cache$ref), "night"); denom <- "expected"
    } else if (!isTRUE(cfg$allow_projected)) {
      stop("NW9! no turnout file: the live counted share would fall back to previous-election booth sizes, which over-states it (vic2022 check: 56.5% vs 33.8%). Pass --turnout, or --allow-projected=1 to accept that", call. = FALSE)
    } else message("NW9  --allow-projected: counted share projected from previous-election booth sizes, which over-states it")
    res <- night_run_update(cache$st, conv, cache$ref, gap_k = if (is.null(cfg$gap_k)) 5 else cfg$gap_k, total = denom, expected = expected,
                            sims = cfg$sims, use_tcp = !isFALSE(cfg$use_tcp)); stamp_t("update_simulate")
    res$denominator <- denom; res$n_placeholder <- conv$n_placeholder_booths; res$n_unlisted <- conv$n_unlisted_booths
    if (length(res$nu$fallback_projected)) message("NW12  ", length(res$nu$fallback_projected), " seat(s) fell back to the projected denominator (no usable expected votes): ", paste(res$nu$fallback_projected, collapse = ", "))
    bk <- night_booth_results_safe(conv, cache$ref)
    doc <- night_build_json(cache$st, res, list(file = basename(snap), stamp = stamp, archived = arch$new), base = cache$base, booths = bk,
                            swing = night_seat_swing_safe(bk, cache$ref))
    night_publish_json(doc, cfg$out, min_seats = nrow(cache$st$shares)); stamp_t("publish")
    sm <- sprintf("OK %s | seats with feed data %d of %d, updated %d, 2CP %d | mean counted %.1f%% | chamber ALP %.1f LNP %.1f | %s",
                  stamp, length(res$matched), nrow(cache$st$shares), res$n_updated, res$n_tcp, 100 * mean(res$nu$counted),
                  doc$chamber$parties$ALP$expected, if (is.null(doc$chamber$parties$LNP)) NA_real_ else doc$chamber$parties$LNP$expected,
                  paste(sprintf("%s %.1fs", names(tm), unlist(tm)), collapse = ", "))
    list(status = "ok", stamp = stamp, timings = tm, message = "", summary = sm, doc = doc, res = res)
  }, error = function(e) fail(e, stamp))
}

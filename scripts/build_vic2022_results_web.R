# Victoria 2022 results by district and by booth, for the ITG seat pages.
#
# Source: the VEC's own per-district results pages, already on disk
# (external/reference/vec/2022/booths/<district>-fp.html and -2cp.html, 87
# districts; Narracan's 2022 election was a later supplementary and has no
# page here). Each page is one table: candidates, their party as the VEC
# prints it, one row per voting centre, then the other vote types (postal,
# provisional, early...), a Total row and the percentage row.
#
# Writes (committed, uploaded to R2 by forecast.yaml):
#   web/vic2022-results.json -- per district: every candidate's first
#     preferences and the final two-candidate count, with votes and percent.
#   web/vic2022-booths.json  -- per district, one row per voting centre
#     (type "venue") and per vote type ("vote_type": postal, early, absent,
#     provisional, marked as voted) plus the venues' subtotal ("subtotal"):
#     each candidate's first preferences and two-candidate votes; venues also
#     carry venue, address, lat, lon from the VEC's voting-centre file.
#     Venues plus vote types = the district.
#
# Checked against two independent sources before writing: district first
# preferences against external/elections/vec-2022-vic-firstprefs.csv (by
# class), and the two-candidate percentages against the 74 official VEC rows
# in output/aef7-final-two-and-tcp-reference.csv.
#
# Run from repo root: powershell.exe -Command 'Rscript scripts/build_vic2022_results_web.R'
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({ library(data.table); library(jsonlite) })

DIR <- file.path("external", "reference", "vec", "2022", "booths")
unent <- function(x) {
  x <- gsub("&amp;", "&", x, fixed = TRUE); x <- gsub("&#39;", "'", x, fixed = TRUE)
  x <- gsub("&nbsp;", " ", x, fixed = TRUE); x <- gsub("&quot;", "\"", x, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", x))
}
cells_of <- function(row) {
  m <- regmatches(row, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", row, perl = TRUE))[[1]]
  unent(gsub("(?s)<[^>]*>", "", m, perl = TRUE))
}
num <- function(x) suppressWarnings(as.numeric(gsub("[,%]", "", x)))

# One page -> list(cands, parties, rows = data.table of named-row x candidate votes)
read_page <- function(f) {
  s <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  tb <- regmatches(s, gregexpr("(?s)<table.*?</table>", s, perl = TRUE))[[1]]
  if (length(tb) != 1L) stop(basename(f), ": expected one table, found ", length(tb))
  rows <- lapply(regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]], cells_of)
  hdr <- rows[[1]]; pty <- rows[[2]]
  ci <- which(nzchar(hdr))                       # candidate columns
  cand <- hdr[ci]; party_raw <- pty[ci]
  i_inf <- which(tolower(pty) == "informal votes"); i_tot <- which(tolower(pty) == "total votes polled")
  body <- rows[-(1:2)]
  keep <- vapply(body, function(r) length(r) >= max(ci) && nzchar(r[1]) && !startsWith(r[1], "Percentage"), logical(1))
  pct_row <- body[vapply(body, function(r) length(r) && startsWith(r[1], "Percentage"), logical(1))]
  b <- body[keep]
  d <- rbindlist(lapply(b, function(r) data.table(name = r[1], candidate = cand, votes = num(r[ci]),
                                                   informal = if (length(i_inf)) num(r[i_inf]) else NA_real_,
                                                   total = if (length(i_tot)) num(r[i_tot]) else NA_real_)))
  list(cand = cand, party_raw = party_raw, rows = d,
       pct = if (length(pct_row)) num(pct_row[[1]][ci]) else rep(NA_real_, length(ci)))
}

files <- list.files(DIR, pattern = "-fp[.]html$")
slug <- sub("-fp[.]html$", "", files)
cat(sprintf("VR0  %d districts with a first-preference page\n", length(slug)))
fpc <- fread(file.path("external", "elections", "vec-2022-vic-firstprefs.csv"))
seat_names <- unique(fpc$seat)
norm <- function(x) gsub("[^a-z]", "", tolower(x))
seat_of <- setNames(seat_names, norm(seat_names))

res <- list(); booths <- list(); bad <- character(0)
for (k in seq_along(slug)) {
  st <- seat_of[norm(slug[k])]
  if (is.na(st)) { bad <- c(bad, slug[k]); next }
  fp <- read_page(file.path(DIR, paste0(slug[k], "-fp.html")))
  f2 <- file.path(DIR, paste0(slug[k], "-2cp.html"))
  tc <- if (file.exists(f2)) read_page(f2) else NULL
  cls <- classify_party(ifelse(nzchar(fp$party_raw), fp$party_raw, "Independent"))
  tot_fp <- fp$rows[name == "Total"]
  if (nrow(tot_fp) != length(fp$cand)) stop(st, ": no Total row on the first-preference page")
  prim <- data.table(candidate = fp$cand, party_raw = fp$party_raw, party = cls,
                     votes = tot_fp$votes, pct = round(100 * tot_fp$votes / sum(tot_fp$votes), 2))
  tcp <- NULL
  if (!is.null(tc)) {
    tt <- tc$rows[name == "Total"]
    tcp <- data.table(candidate = tc$cand, party_raw = tc$party_raw,
                      party = classify_party(ifelse(nzchar(tc$party_raw), tc$party_raw, "Independent")),
                      votes = tt$votes, pct = round(100 * tt$votes / sum(tt$votes), 2))
  }
  res[[st]] <- list(seat = unname(st), primary = prim, final_two = tcp,
                    informal = tot_fp$informal[1], total_polled = tot_fp$total[1])
  bb <- fp$rows[name != "Total", .(fp_votes = list(setNames(as.list(votes), candidate)),
                                    informal = informal[1], total = total[1]), by = name]
  if (!is.null(tc)) {
    b2 <- tc$rows[name != "Total", .(tcp_votes = list(setNames(as.list(votes), candidate))), by = name]
    bb <- merge(bb, b2, by = "name", all.x = TRUE)
  }
  bb[, seat := unname(st)]
  booths[[st]] <- bb
}
if (length(bad)) stop("VR0! page(s) with no matching district: ", paste(bad, collapse = ", "))

# ---- checks against independent sources, before anything is written ----
chk <- rbindlist(lapply(res, function(r) r$primary[, .(votes = sum(votes)), by = party][, seat := r$seat]))
m <- merge(chk, fpc[, .(ref = sum(votes)), by = .(seat, party)], by = c("seat", "party"), all = TRUE)
m[is.na(votes), votes := 0]; m[is.na(ref), ref := 0]
d1 <- m[seat %in% names(res)][abs(votes - ref) > 0]
cat(sprintf("VR1  first preferences by class vs vec-2022-vic-firstprefs.csv: %d district-class cells, %d differ\n",
            nrow(m[seat %in% names(res)]), nrow(d1)))
if (nrow(d1)) print(head(d1, 20))
ref2 <- fread(file.path("output", "aef7-final-two-and-tcp-reference.csv"))[pair == "vic2022" & fsrc == "vec-official"]
tc2 <- rbindlist(lapply(res, function(r) if (!is.null(r$final_two)) r$final_two[, .(seat = r$seat, party, pct)]))
m2 <- merge(tc2, ref2[, .(seat, party = f1, ref = f2cp)], by = c("seat", "party"))
cat(sprintf("VR2  two-candidate %% vs %d official VEC reference rows: %d matched, max |diff| %.2f\n",
            nrow(ref2), nrow(m2), max(abs(m2$pct - m2$ref))))
stopifnot(nrow(d1) == 0L, nrow(m2) == nrow(ref2), max(abs(m2$pct - m2$ref)) <= 0.1)

dir.create("web", showWarnings = FALSE)
write_json(unname(lapply(res, function(r) list(seat = r$seat, primary = r$primary, final_two = r$final_two,
                                                informal = r$informal, total_polled = r$total_polled))),
           "web/vic2022-results.json", auto_unbox = TRUE, digits = NA, na = "null")
bt <- rbindlist(booths, fill = TRUE)
# Row types. A voting centre is a "venue"; the VEC's other rows are vote-type
# totals ("Postal votes", "Early votes", ...), and "Ordinary votes total" is
# the venues' subtotal -- so venues + vote types = the district, and adding
# the subtotal too would double-count. "All Votes votes" is an empty row.
bt[, fp_sum := vapply(fp_votes, function(v) sum(unlist(v)), numeric(1))]
bt[, type := data.table::fifelse(name == "Ordinary votes total", "subtotal",
                  data.table::fifelse(grepl(" votes$", name), "vote_type", "venue"))]
bt <- bt[!(name == "All Votes votes" & fp_sum == 0)]
# Venue locations: the VEC's own 2022 voting-centre file (downloaded
# 2026-10-01 from vec.vic.gov.au/electoral-boundaries/download-boundary-maps,
# kept raw). A venue serving several districts is listed once with all of them
# ("Albert Park District, Prahran District"), so it is split per district and
# matched on district + location name. Every venue must match.
vcf <- file.path("external", "reference", "vec", "2022", "voting-centre-locations-2022.xlsx")
vc <- as.data.table(readxl::read_excel(vcf, sheet = "VC Locations"))
vc <- vc[, .(seat = trimws(sub(" District$", "", trimws(unlist(strsplit(Electorates, ","))))),
             name = VotingLocationName, venue = VenueName,
             address = paste0(PhysicalAddressLine1, ", ", PhysicalSuburb), lat = Lat, lon = Long),
         by = seq_len(nrow(vc))][, seq_len := NULL]
key_of <- function(st, nm) paste(st, gsub("[^a-z0-9]", "", tolower(nm)))
vc[, k := key_of(seat, name)]
stopifnot(anyDuplicated(vc$k) == 0L)
bt[, k := key_of(seat, name)]
bt <- merge(bt, vc[, .(k, venue, address, lat, lon)], by = "k", all.x = TRUE)[, k := NULL]
nloc <- bt[type == "venue", sum(is.finite(lat))]
cat(sprintf("VR5  venue locations from the VEC file: %d of %d venues matched
", nloc, bt[type == "venue", .N]))
stopifnot(nloc == bt[type == "venue", .N])
chk3 <- bt[type != "subtotal", .(rows = sum(fp_sum)), by = seat][
  , ref := vapply(seat, function(s) sum(res[[s]]$primary$votes), numeric(1))]
chk4 <- bt[, .(v = sum(fp_sum[type == "venue"]), sub = sum(fp_sum[type == "subtotal"])), by = seat]
cat(sprintf("VR4  venues + vote types = district formal vote in %d of %d districts; venues = subtotal in %d of %d
",
            sum(chk3$rows == chk3$ref), nrow(chk3), sum(chk4$v == chk4$sub), nrow(chk4)))
stopifnot(all(chk3$rows == chk3$ref), all(chk4$v == chk4$sub))
write_json(lapply(split(bt, bt$seat), function(d) lapply(seq_len(nrow(d)), function(i)
  list(booth = d$name[i], type = d$type[i],
       venue = if (d$type[i] == "venue") d$venue[i] else NULL, address = if (d$type[i] == "venue") d$address[i] else NULL,
       lat = if (d$type[i] == "venue") round(d$lat[i], 5) else NULL, lon = if (d$type[i] == "venue") round(d$lon[i], 5) else NULL,
       fp_votes = d$fp_votes[[i]], tcp_votes = if ("tcp_votes" %in% names(d)) d$tcp_votes[[i]] else NULL,
       informal = d$informal[i], total = d$total[i]))),
  "web/vic2022-booths.json", auto_unbox = TRUE, digits = NA, na = "null")
cat(sprintf("VR3  wrote web/vic2022-results.json (%d districts, %.0f KB) and web/vic2022-booths.json (%d rows, %.0f KB)\n",
            length(res), file.size("web/vic2022-results.json") / 1024, nrow(bt), file.size("web/vic2022-booths.json") / 1024))

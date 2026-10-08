# New South Wales 2023 results by district and by voting place, for the ITG
# seat pages. The same JSON shape as scripts/build_vic2022_results_web.R, so
# politics/seat.qmd can read either state.
#
# Sources (all raw files kept under external/reference/nsw/):
#   sge2023-la-final-votes.xlsx  -- the NSWEC's own final first-preference
#     votes, one row per district x venue/vote type x candidate (sheet "Data";
#     sheet "Pivot" gives statewide formal/informal by vote type, used as a check).
#   tallyroom-NSW-2023-Pollingplaces.xlsx -- Ben Raue / The Tally Room's polling
#     place table (pp_id, premises, address, suburb, latitude, longitude). The
#     NSWEC publishes no coordinates file. Every one of the 2,620 election-day
#     voting centres matches the NSWEC venue name one-to-one and has
#     coordinates; the 464 early voting centres carry premises but NO
#     coordinates in that table (lat/lon are null for them, not invented).
#     Downloaded 2026-10-08 from the Tally Room data page
#     (tallyroom.com.au/data -> "New South Wales 2023" Drive folder, which the
#     site says is free to access). Third-party, not NSWEC.
#   tallyroom-NSW-2023-LA-2CP-Pollingplace.xlsx -- the Tally Room's
#     two-candidate-preferred count by venue (the NSWEC TCP tool's figures; the
#     Albury venues were spot-checked against the NSWEC page by hand,
#     pastvtr.elections.nsw.gov.au/SG2301/LA/albury/TCP). Votes per finalist
#     plus "Exhausted"; exhausted is not written (formal - two-candidate votes).
#   tallyroom-NSW-2023-LA-Candidates.xlsx -- surname/first name per candidate,
#     used to turn the NSWEC's "ROWLAND Marcus" into the Victorian-file style
#     "ROWLAND, Marcus" (seat.qmd splits on the comma to get the surname).
#
# Writes (committed, uploaded to R2 by forecast.yaml):
#   web/nsw2023-results.json -- per district: every candidate's first
#     preferences and the final two-candidate count (votes, percent).
#   web/nsw2023-booths.json  -- per district, one row per voting centre
#     (type "venue": election-day centres and early voting centres) and per
#     vote type ("vote_type": absent, enrolment / provisional, postal,
#     declared facility) plus the venues' subtotal ("subtotal"): each
#     candidate's first preferences and the final two's two-candidate votes.
#     Venues plus vote types = the district.
#
# Differences from the Victorian files: NSW counts exhausted preferences in its
# two-candidate tables (so two-candidate votes < formal votes at a booth, the
# same as Victoria in effect); early voting centres are named venues here (in
# Victoria early votes are one central vote type) and have null coordinates.
#
# Checked before writing: first preferences by class against
# external/elections/nswec-2023-nsw-firstprefs.csv, the final-two percentages
# against the official rows in output/aef7-final-two-and-tcp-reference.csv,
# statewide formal/informal by vote type against the xlsx's own Pivot sheet,
# and venues + vote types = district. The check functions are proved to FAIL
# on a booth-dropped copy before they are trusted.
#
# Run from repo root: powershell.exe -Command 'Rscript scripts/build_nsw2023_results_web.R'
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({ library(data.table); library(jsonlite); library(readxl) })

NSW <- file.path("external", "reference", "nsw")
rd <- function(f, ...) as.data.table(read_excel(file.path(NSW, f), ...))

x <- rd("sge2023-la-final-votes.xlsx", sheet = "Data")
setnames(x, c("seat", "vt", "st", "name", "fi", "cand_raw", "acr", "party_raw", "votes"))
x[is.na(party_raw), party_raw := ""]
cat(sprintf("NR0  xlsx Data: %d rows, %d districts, %d formal candidates-rows, %d informal rows\n",
            nrow(x), uniqueN(x$seat), sum(x$fi == "Formal"), sum(x$fi == "Informal")))
stopifnot(uniqueN(x$seat) == 93L, all(x$fi %in% c("Formal", "Informal")), !anyNA(x$votes), all(x$votes >= 0))

# ---- district names must match the map / forecast district names ----
topo <- fromJSON("web/nsw2027-districts.topojson", simplifyVector = FALSE)
topo_seats <- vapply(topo$objects[[1]]$geometries, function(g) g$properties$seat, character(1))
only_x <- setdiff(unique(x$seat), topo_seats); only_t <- setdiff(topo_seats, unique(x$seat))
cat(sprintf("NR0b district names vs web/nsw2027-districts.topojson (the 93 names scripts/check_nsw_districts_topojson.R pins to forecast-nsw2027.json): %d in results only, %d in map only\n",
            length(only_x), length(only_t)))
if (length(only_x)) cat("     results only:", paste(only_x, collapse = ", "), "\n")
if (length(only_t)) cat("     map only:    ", paste(only_t, collapse = ", "), "\n")
stopifnot(!length(only_x), !length(only_t))

# ---- candidate names: "ROWLAND Marcus" -> "ROWLAND, Marcus" (candidate file) ----
cands <- rd("tallyroom-NSW-2023-LA-Candidates.xlsx")
# One typo in the Tally Room file: Terrigal's candidate is stored as
# "da SILVA, SILVA Imogen" (surname "da SILVA SILVA"); the NSWEC has "da SILVA Imogen".
fix <- cands$candidate_name == "da SILVA, SILVA Imogen"
cat(sprintf("     candidate-file typo corrected for %d row(s) (da SILVA, SILVA Imogen -> da SILVA, Imogen)\n", sum(fix)))
stopifnot(sum(fix) == 1L)
cands[fix, `:=`(candidate_name = "da SILVA, Imogen", surname = "da SILVA", first_name = "Imogen")]
nk <- function(s) gsub("[^a-z]", "", tolower(s))
cands[, key := paste(district_name, nk(paste0(surname, first_name)))]
stopifnot(anyDuplicated(cands$key) == 0L)
x[, key := paste(seat, nk(cand_raw))]
nm <- setNames(cands$candidate_name, cands$key)
inf <- x$fi == "Informal"
x[, candidate := nm[key]]
miss <- unique(x[!inf & is.na(candidate), .(seat, cand_raw)])
cat(sprintf("NR0c candidate names: %d of %d district-candidates matched to the candidate file\n",
            uniqueN(x[!inf, key]) - nrow(miss), uniqueN(x[!inf, key])))
if (nrow(miss)) print(miss)
stopifnot(!nrow(miss))
# the candidate file's party for the few rows the xlsx leaves blank (checked below)
cp <- setNames(cands$party_name, cands$key)
blank <- x[!inf & party_raw == "", unique(key)]
cat(sprintf("     %d candidates have a blank party in the xlsx; the candidate file calls them: %s\n",
            length(blank), paste(unique(cp[blank]), collapse = " / ")))

# ---- venue table with coordinates ----
pp <- rd("tallyroom-NSW-2023-Pollingplaces.xlsx")
stopifnot(anyDuplicated(pp[, .(district_name, pp_name)]) == 0L)
vlist <- unique(x[, .(seat, vt, st, name)])
vlist <- merge(vlist, pp[, .(seat = district_name, name = pp_name, pp_id, premises, address, suburb, latitude, longitude)],
               by = c("seat", "name"), all.x = TRUE)
cat(sprintf("NR5  venue table: %d of %d xlsx venue/vote-type rows matched; coordinates on %d of %d election-day centres, %d of %d early centres\n",
            vlist[!is.na(pp_id), .N],
            nrow(vlist),
            vlist[vt == "PP", sum(is.finite(latitude))], vlist[vt == "PP", .N],
            vlist[vt == "PR", sum(is.finite(latitude))], vlist[vt == "PR", .N]))
stopifnot(nrow(vlist) == nrow(pp), vlist[vt == "PP", all(is.finite(latitude) & is.finite(longitude))])

# ---- two-candidate counts by venue ----
t2 <- rd("tallyroom-NSW-2023-LA-2CP-Pollingplace.xlsx")
t2f <- t2[party_code != "EXH"]
fin <- t2f[, .(cands = list(unique(candidate_name))), by = district_name]
stopifnot(nrow(fin) == 93L, all(lengths(fin$cands) == 2L))
cat(sprintf("NR6  two-candidate file: %d rows, finalists found for %d districts (2 each)\n", nrow(t2), nrow(fin)))

# ---- long table -> the per-district pieces ----
# one row per seat x venue x candidate (formal only) and one informal count per seat x venue
fpl <- x[fi == "Formal"]
fpl[, party := classify_party(ifelse(nzchar(party_raw), party_raw, "Independent"))]
infl <- x[fi == "Informal", .(informal = sum(votes)), by = .(seat, name)]
cand_order <- unique(fpl[, .(seat, candidate, party_raw, party)])          # first-appearance (ballot) order
tcpl <- merge(t2f[, .(seat = district_name, name = pp_name, candidate = candidate_name, tcp = votes)],
              unique(x[, .(seat, name, vt)])[, .(seat, name)], by = c("seat", "name"))
stopifnot(nrow(tcpl) == nrow(t2f))
t2f_ok <- all(paste(t2f$district_name, t2f$pp_name) %in% paste(vlist$seat, vlist$name))
stopifnot(t2f_ok)

# ---- checks (functions, so they can be proved on a broken copy) ----
fpc <- fread(file.path("external", "elections", "nswec-2023-nsw-firstprefs.csv"))
ref2 <- fread(file.path("output", "aef7-final-two-and-tcp-reference.csv"))[pair == "nsw2023" & fsrc == "official"]
pivot <- as.data.table(read_excel(file.path(NSW, "sge2023-la-final-votes.xlsx"), sheet = "Pivot", col_names = FALSE, .name_repair = "minimal"))
setnames(pivot, c("lab", "formal", "informal", "total"))
pivot <- pivot[lab %in% c("Declared Facility", "Absent", "Enrolment / Provision", "Postal", "Voting Centre", "Early Voting Centre")]

run_checks <- function(fpl, infl, tcpl, label = "") {
  chk <- fpl[, .(votes = sum(votes)), by = .(seat, party)]
  m <- merge(chk, fpc[, .(ref = sum(votes)), by = .(seat, party)], by = c("seat", "party"), all = TRUE)
  m[is.na(votes), votes := 0]; m[is.na(ref), ref := 0]
  d1 <- m[abs(votes - ref) > 0]
  cat(sprintf("NR1%s first preferences by class vs nswec-2023-nsw-firstprefs.csv: %d district-class cells, %d differ\n",
              label, nrow(m), nrow(d1)))
  tot <- tcpl[, .(v = sum(tcp)), by = .(seat, candidate)]
  tot[, pct := 100 * v / sum(v), by = seat]
  pc <- unique(fpl[, .(seat, candidate, party)])
  tot <- merge(tot, pc, by = c("seat", "candidate"))
  m2 <- merge(tot, ref2[, .(seat, party = f1, ref = f2cp)], by = c("seat", "party"))
  mx <- if (nrow(m2)) max(abs(m2$pct - m2$ref)) else Inf
  cat(sprintf("NR2%s two-candidate %% vs %d official reference rows: %d matched, max |diff| %.2f\n",
              label, nrow(ref2), nrow(m2), mx))
  byst <- merge(unique(x[, .(seat, name, st)]), fpl[, .(formal = sum(votes)), by = .(seat, name)], by = c("seat", "name"), all.x = TRUE)
  byst[is.na(formal), formal := 0]
  sf <- byst[, .(formal = sum(formal)), by = st]
  pvf <- merge(sf, pivot[, .(st = lab, ref = as.numeric(formal))], by = "st", all = TRUE)
  cat(sprintf("NR3%s statewide formal by vote type vs the xlsx Pivot sheet: %d types, %d differ\n",
              label, nrow(pvf), sum(is.na(pvf$formal) | is.na(pvf$ref) | pvf$formal != pvf$ref)))
  ok1 <- nrow(d1) == 0L; ok2 <- nrow(m2) == nrow(ref2) && mx <= 0.1
  ok3 <- !any(is.na(pvf$formal) | is.na(pvf$ref) | pvf$formal != pvf$ref)
  c(ok1, ok2, ok3)
}

# prove the checks fail on a deliberately broken input: drop the busiest venue in one district
victim <- fpl[seat == "Albury", .(v = sum(votes)), by = name][order(-v)][1, name]
cat(sprintf("NR9  broken-input test: dropping '%s' (Albury) from every table; every check below must report FAIL\n", victim))
bk <- run_checks(fpl[!(seat == "Albury" & name == victim)], infl, tcpl[!(seat == "Albury" & name == victim)], "-broken")
stopifnot(!bk[1], !bk[2], !bk[3])
cat("NR9  OK: all three checks flagged the broken copy\n")
okc <- run_checks(fpl, infl, tcpl)
stopifnot(all(okc))

# ---- assemble the per-district objects ----
res <- list(); booths <- list()
# NB: the loop variable is `dist`, never `st` -- `st` is a COLUMN of vlist/fpl (vote sub type), and a bare
# `st` inside `dt[...]` would silently bind to it (data.table NSE trap, CLAUDE.md).
for (dist in sort(unique(x$seat))) {
  co <- cand_order[seat == dist]
  prim <- fpl[seat == dist, .(votes = sum(votes)), by = candidate][co, on = "candidate"][, .(candidate, party_raw, party, votes)]
  prim[, pct := round(100 * votes / sum(votes), 2)]
  fc <- fin[district_name == dist, cands][[1]]
  ft <- tcpl[seat == dist, .(votes = sum(tcp)), by = candidate]
  fin_t <- prim[candidate %in% fc, .(candidate, party_raw, party)]
  fin_t[, votes := ft$votes[match(candidate, ft$candidate)]]
  fin_t[, pct := round(100 * votes / sum(votes), 2)]
  stopifnot(nrow(fin_t) == 2L)
  infs <- infl[seat == dist, sum(informal)]
  res[[dist]] <- list(seat = dist, primary = prim, final_two = fin_t,
                    informal = infs, total_polled = sum(prim$votes) + infs)
  # one row per venue / vote type
  vl <- vlist[seat == dist]
  rows <- lapply(seq_len(nrow(vl)), function(i) {
    nmv <- vl$name[i]
    f <- fpl[seat == dist & name == nmv]
    fv <- setNames(as.list(f$votes[match(co$candidate, f$candidate)]), co$candidate)
    fv <- lapply(fv, function(v) if (is.na(v)) 0 else v)
    tv <- tcpl[seat == dist & name == nmv]
    tcpv <- if (nrow(tv)) setNames(as.list(tv$tcp[match(fc, tv$candidate)]), fc) else NULL
    if (!is.null(tcpv)) tcpv <- lapply(tcpv, function(v) if (is.na(v)) 0 else v)
    inf1 <- infl[seat == dist & name == nmv, informal]
    inf1 <- if (length(inf1)) inf1 else 0
    typ <- if (vl$vt[i] %in% c("PP", "PR")) "venue" else "vote_type"
    bn <- if (typ == "venue") nmv else
      switch(nmv, "Enrolment / Provision" = "Enrolment / provisional votes", "Absent" = "Absent votes",
             "Postal" = "Postal votes", "Declared Facility" = "Declared facility votes",
             stop("unknown vote type: ", nmv))
    list(booth = bn, type = typ,
         venue = if (typ == "venue") (if (is.na(vl$premises[i])) nmv else vl$premises[i]) else NULL,
         address = if (typ == "venue") (if (is.na(vl$address[i])) NA_character_ else paste0(vl$address[i], ", ", vl$suburb[i])) else NULL,
         lat = if (typ == "venue") round(vl$latitude[i], 5) else NULL,
         lon = if (typ == "venue") round(vl$longitude[i], 5) else NULL,
         fp_votes = fv, tcp_votes = tcpv, informal = inf1, total = sum(unlist(fv)) + inf1)
  })
  # the venues' subtotal, as the Victorian files carry ("Ordinary votes total"); never summed again
  vr <- rows[vapply(rows, function(r) r$type == "venue", logical(1))]
  sub <- list(booth = "Ordinary votes total", type = "subtotal", venue = NULL, address = NULL, lat = NULL, lon = NULL,
              fp_votes = setNames(lapply(co$candidate, function(cn) sum(vapply(vr, function(r) r$fp_votes[[cn]], numeric(1)))), co$candidate),
              tcp_votes = setNames(lapply(fc, function(cn) sum(vapply(vr, function(r) if (is.null(r$tcp_votes)) 0 else r$tcp_votes[[cn]], numeric(1)))), fc),
              informal = sum(vapply(vr, function(r) r$informal, numeric(1))),
              total = sum(vapply(vr, function(r) r$total, numeric(1))))
  ord <- vapply(rows, function(r) r$type == "venue", logical(1))
  booths[[dist]] <- c(rows[ord], list(sub), rows[!ord])
}

# ---- structural checks on what will be written ----
chk3 <- rbindlist(lapply(booths, function(b) data.table(
  rows = sum(vapply(b[vapply(b, function(r) r$type != "subtotal", logical(1))], function(r) sum(unlist(r$fp_votes)), numeric(1))),
  v = sum(vapply(b[vapply(b, function(r) r$type == "venue", logical(1))], function(r) sum(unlist(r$fp_votes)), numeric(1))),
  sub = sum(unlist(b[[which(vapply(b, function(r) r$type == "subtotal", logical(1)))]]$fp_votes)),
  tcp_rows = sum(vapply(b[vapply(b, function(r) r$type != "subtotal", logical(1))], function(r) sum(unlist(r$tcp_votes)), numeric(1))))), idcol = "seat")
chk3[, ref := vapply(seat, function(s) sum(res[[s]]$primary$votes), numeric(1))]
chk3[, tcp_ref := vapply(seat, function(s) sum(res[[s]]$final_two$votes), numeric(1))]
cat(sprintf("NR4  venues + vote types = district formal vote in %d of %d districts; venues = subtotal in %d of %d; booth two-candidate votes = district final two in %d of %d\n",
            sum(chk3$rows == chk3$ref), nrow(chk3), sum(chk3$v == chk3$sub), nrow(chk3), sum(chk3$tcp_rows == chk3$tcp_ref), nrow(chk3)))
stopifnot(all(chk3$rows == chk3$ref), all(chk3$v == chk3$sub), all(chk3$tcp_rows == chk3$tcp_ref))
# per-venue: two-candidate votes never exceed formal votes
bad_tcp <- sum(unlist(lapply(booths, function(b) vapply(b, function(r) !is.null(r$tcp_votes) && sum(unlist(r$tcp_votes)) > sum(unlist(r$fp_votes)), logical(1)))))
cat(sprintf("NR7  venue rows where two-candidate votes exceed formal votes: %d\n", bad_tcp))
stopifnot(bad_tcp == 0L)

dir.create("web", showWarnings = FALSE)
write_json(unname(lapply(res, function(r) list(seat = r$seat, primary = r$primary, final_two = r$final_two,
                                                informal = r$informal, total_polled = r$total_polled))),
           "web/nsw2023-results.json", auto_unbox = TRUE, digits = NA, na = "null")
write_json(booths, "web/nsw2023-booths.json", auto_unbox = TRUE, digits = NA, na = "null")
nrows <- sum(lengths(booths))
nven <- sum(unlist(lapply(booths, function(b) vapply(b, function(r) r$type == "venue", logical(1)))))
nll <- sum(unlist(lapply(booths, function(b) vapply(b, function(r) r$type == "venue" && length(r$lat) && is.finite(r$lat), logical(1)))))
cat(sprintf("NR8  wrote web/nsw2023-results.json (%d districts, %.0f KB) and web/nsw2023-booths.json (%d rows, %d venues, %d with real lat/lon, %.0f KB)\n",
            length(res), file.size("web/nsw2023-results.json") / 1024, nrows, nven, nll, file.size("web/nsw2023-booths.json") / 1024))

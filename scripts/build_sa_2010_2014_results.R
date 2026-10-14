# Complete, classify and write South Australia 2010 and 2014 results for the
# sa2014 (prev sa2010) and sa2018 (prev sa2014) backtest pairs.
#
# WHY THIS EXISTS. external/elections/ecsa-20{10,14}-sa-firstprefs-tcp.csv (from
# scripts/fetch_state_distributions.R) are LONG-format, party-CODE files and are
# INCOMPLETE: 2010 has 45 of 47 districts, 2014 has 43 of 47. Nothing in the
# harness can read them as they stand. This script
#   1. adds the districts the index scrape missed (parsed from pages saved under
#      external/reference/ecsa/raw/), and
#   2. classifies the ECSA party codes into the model's classes, and
#   3. derives winners from each district's own two-candidate-preferred table.
#
# OUTPUT (all NEW files, under external/reference/ecsa/sa-backtest/ -- the shared
# external/elections/ files are NOT touched):
#   ecsa-2010-sa-candidates.csv, ecsa-2014-sa-candidates.csv
#       seat, name, party_raw, party, votes     (candidate level, like the sa2018
#       Wikipedia file; the harness collapses to (seat, party) itself)
#   ecsa-2010-sa-winners.csv, ecsa-2014-sa-winners.csv   election, seat, winner
#
# WHAT IS STILL MISSING, and why (each printed as an ES3 line at the end):
#   Fisher, Giles and Stuart 2014 -- ECSA's live index lists no general-election
#                     page for Fisher or Giles and gives Stuart and Taylor the SAME
#                     page id (742), so the scraped "stuart" rows were Taylor's.
#                     All three are parsed from ECSA's own pages as archived by the
#                     Wayback Machine in 2015 (past-state-election-results/7670,
#                     7674, 7697). Cross-checked against the AEF archive
#                     (external/elections/archive/2014sa-*.csv): every cell
#                     agrees (Bob Such won Fisher as an independent, 9,038 first
#                     preferences; the Fisher by-election of 2014 came later).
#   sa2010 Norwood -- not in ECSA's index; taken from Wikipedia's 2010 box
#                     (ECSA-sourced) rather than left out. Port Adelaide 2010 is
#                     parsed from the polling-booth page already on disk.
#
# Check codes: ES1 district coverage, ES2 vote totals vs ECSA's Total Formal,
# ES3 known gaps. ("ES" is unused elsewhere; "SD" is taken by R/state_deviation.R.)

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

EL  <- election_data_path()
REF <- file.path("external", "reference", "ecsa")
OUT <- file.path(REF, "sa-backtest")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

strip_tags <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("&nbsp;", " ", gsub("<[^>]+>", " ", x))))
tables_of  <- function(h) regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
rows_of    <- function(t) regmatches(t, gregexpr("(?s)<tr.*?</tr>", t, perl = TRUE))[[1]]
cells_of   <- function(r) strip_tags(regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]])
num        <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", x)))
read_all   <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# ---- seat names -------------------------------------------------------------
# One spelling per district, matching the 2018 Wikipedia / 2022 ECSA files.
# "ramsey" (2010 slug) and "ramsay" (2014+) are the same district renamed.
seat_name <- function(slug) {
  s <- c(mackillop = "MacKillop", ramsey = "Ramsay")[slug]
  ifelse(!is.na(s), s, vapply(strsplit(gsub("-", " ", slug), " "), function(w)
    paste(paste0(toupper(substring(w, 1, 1)), substring(w, 2)), collapse = " "), ""))
}

# ---- party codes -> modelling class ------------------------------------------
# ECSA publishes a 3-4 letter code only. Resolved against the code meanings the
# pages themselves use; classify_party() stays the single source of truth for
# what a NAME means, and the codes are first translated to a name it understands.
# CLP is "Country Labor" (rural Labor candidates: Breuer in Giles, Corcoran in
# Finniss), NOT the Northern Territory's Country Liberals, so it is spelled out
# here rather than passed to classify_party() as a code. NP is the Nationals SA,
# which classify_party() files with the Coalition (as it does for every other
# election), so Chaffey 2010's Maywald (NP) and Whetstone (LIB) both land in LNP.
CODE_NAME <- c(
  LIB = "Liberal Party of Australia (SA)", ALP = "Australian Labor Party (SA)",
  CLP = "Country Labor", GRN = "SA Greens", FFP = "Family First Party",
  NP = "National Party of Australia (SA)", IND = "Independent", DLP = "Democratic Labor Party",
  DEM = "Australian Democrats", D4D = "Dignity for Disability", RAH = "Save the RAH",
  G4C = "Group for Change", FLT = "Fair Land Tax", FREE = "Free Australia")
class_of_code <- function(code) {
  nm <- unname(CODE_NAME[code])
  if (anyNA(nm)) stop("ES0: unmapped ECSA party code(s): ", paste(unique(code[is.na(nm)]), collapse = ", "))
  classify_party(nm, ifelse(code %in% c("DLP", "IND"), code, ""))
}

# ---- the existing long-format files ------------------------------------------
read_long <- function(year) {
  d <- fread(file.path(EL, sprintf("ecsa-%d-sa-firstprefs-tcp.csv", year)), showProgress = FALSE)
  d[, seat_slug := district]
  d
}

# ---- a district page (2014 template, live or archived) -------------------------
# First table headed "Candidate" is first preferences, the last is the TCP.
parse_page <- function(f, year, slug) {
  tb <- tables_of(read_all(f))
  ct <- Filter(function(t) { r <- rows_of(t); length(r) > 1 && grepl("^Candidate", cells_of(r[1])[1]) }, tb)
  stopifnot(length(ct) >= 2L)
  take <- function(t, label) {
    r <- Filter(function(z) length(z) >= 4L && !grepl("^(Candidate|Total)", z[1]), lapply(rows_of(t), cells_of))
    data.table(year = year, district = slug, table = label, candidate = vapply(r, `[`, "", 1),
               party = vapply(r, `[`, "", 2), votes = num(vapply(r, function(z) z[length(z)], "")))
  }
  rbind(take(ct[[1]], "first_preferences"), take(ct[[length(ct)]], "tcp"))
}

# ---- Port Adelaide 2010: the polling-booth template ---------------------------
parse_pa2010 <- function(f) {
  tb <- tables_of(read_all(f))
  r1 <- rows_of(tb[[1]]); hdr <- cells_of(r1[1]); hdr <- hdr[nzchar(hdr)]
  tot <- Filter(function(z) identical(z[1], "District Total"), lapply(r1, cells_of))[[1]]
  v <- num(tot[2:length(tot)]); v <- v[!is.na(v)]
  stopifnot(length(v) >= length(hdr) + 1L)
  # "SURNAME, Given CODE": the trailing token is the party code
  cand <- sub("\\s+[A-Z0-9]+$", "", hdr); party <- sub("^.*\\s+([A-Z0-9]+)$", "\\1", hdr)
  fp <- data.table(year = 2010L, district = "port-adelaide", table = "first_preferences",
                   candidate = cand, party = party, votes = v[seq_along(hdr)])
  stopifnot(sum(fp$votes) == v[length(hdr) + 1L])   # five candidates must sum to the district's formal total
  r2 <- rows_of(tb[[2]]); h2 <- cells_of(r2[1]); h2 <- sub(" \\.$", "", h2[nzchar(h2)])
  d2 <- Filter(function(z) identical(z[1], "Distributed Votes"), lapply(r2, cells_of))[[1]]
  v2 <- num(d2[2:length(d2)]); v2 <- v2[!is.na(v2)]
  tcp <- data.table(year = 2010L, district = "port-adelaide", table = "tcp",
                    candidate = sub("\\s+[A-Z0-9]+$", "", h2), party = sub("^.*\\s+([A-Z0-9]+)$", "\\1", h2),
                    votes = v2[seq_along(h2)])
  rbind(fp, tcp)
}

# ---- Norwood 2010: Wikipedia's election box (ECSA-sourced) ----------------------
parse_norwood2010 <- function(f) {
  l <- readLines(f, warn = FALSE, encoding = "UTF-8")
  i <- grep("2010 South Australian state election\\]\\]: Norwood", l)[1]
  stopifnot(!is.na(i))
  blk <- l[(i + 1L):min(length(l), i + 120L)]
  stop_at <- grep("Election box (formal|turnout|total|swing|hold|gain|end)|Election box begin", blk)[1]
  blk <- blk[seq_len(if (is.na(stop_at)) length(blk) else stop_at - 1L)]
  cl <- function(k) { x <- sub("^\\|\\s*", "", sub(paste0("^\\|\\s*", k, "\\s*=\\s*"), "", grep(paste0("^\\|\\s*", k, "\\s*="), blk, value = TRUE))); x }
  nm <- gsub("\\[\\[(?:[^|\\]]*\\|)?([^\\]]*)\\]\\]", "\\1", cl("candidate"), perl = TRUE)
  pty <- gsub("\\[\\[(?:[^|\\]]*\\|)?([^\\]]*)\\]\\]", "\\1", cl("party"), perl = TRUE)
  vt <- num(cl("votes"))
  stopifnot(length(nm) == length(pty), length(nm) == length(vt), length(nm) >= 4L, !anyNA(vt))
  # Wikipedia gives "Given Surname"; ECSA's 2010 form is "SURNAME, Given"
  sn <- sub("^.*\\s+(\\S+)$", "\\1", nm); gv <- sub("\\s+\\S+$", "", nm)
  data.table(year = 2010L, district = "norwood", table = "first_preferences",
             candidate = sprintf("%s, %s", toupper(sn), gv), party = pty, votes = vt, wiki_party = TRUE)
}

# ---- assemble ---------------------------------------------------------------
build_year <- function(year) {
  d <- read_long(year)[, .(year, district, table, candidate, party, votes)]
  d <- d[!candidate %in% c("Total Formal", "Informal")]
  extra <- list()
  if (year == 2014L) {
    for (s in c("davenport", "frome"))
      extra[[s]] <- parse_page(file.path(REF, "raw", "2014", paste0(s, ".html")), 2014L, s)
    # Giles, Fisher and Stuart come from ECSA's own pages as archived by the Wayback
    # Machine in 2015 (the live index lists no Giles or Fisher general-election
    # page, and gives Stuart and Taylor the SAME page id, 742).
    for (s in c("giles", "fisher", "stuart"))
      extra[[s]] <- parse_page(file.path(REF, "raw", "2014", paste0(s, "-wayback-2015.html")), 2014L, s)
    # The index bug above means the long file's "stuart" rows are TAYLOR's. Prove it, then drop them.
    fpv <- function(dd) sort(dd[table == "first_preferences", votes])
    stopifnot(identical(fpv(d[district == "stuart"]), fpv(d[district == "taylor"])))
    cat("ES1  sa2014: the long file's stuart rows are an exact copy of taylor's (ECSA index id 742 shared); replaced from the archived Stuart page\n")
    d <- d[district != "stuart"]
  } else {
    extra$pa <- parse_pa2010(file.path(REF, "raw", "2010", "port-adelaide.html"))
    extra$nw <- parse_norwood2010(file.path(REF, "raw", "2010", "norwood-wikipedia.txt"))
  }
  x <- rbindlist(c(list(d[, wiki_party := FALSE]), extra), fill = TRUE)
  x[is.na(wiki_party), wiki_party := FALSE]
  x[, seat := seat_name(district)]
  x
}

res <- list()
for (yr in c(2010L, 2014L)) {
  x <- build_year(yr)
  fpx <- x[table == "first_preferences"]
  fpx[, party_raw := party]
  fpx[, party := NA_character_]
  fpx[wiki_party == TRUE, party := classify_party(party_raw)]
  fpx[wiki_party == FALSE, party := class_of_code(party_raw)]
  # ES2: no zero-vote, duplicated or non-numeric candidate rows
  stopifnot(!anyNA(fpx$votes), all(fpx$votes >= 0), !anyDuplicated(fpx[, .(seat, candidate)]))
  # two districts must never carry the same vote vector (the Stuart/Taylor index bug above)
  vv <- fpx[, .(v = paste(sort(votes), collapse = ",")), by = seat]
  stopifnot(!anyDuplicated(vv$v))
  # tcp candidates must be among the district's first-preference candidates
  tc <- x[table == "tcp"][, key := paste(district, candidate)]
  stopifnot(all(tc$key %in% paste(x[table == "first_preferences"]$district, x[table == "first_preferences"]$candidate)))
  cat(sprintf("ES1  sa%d: %d districts, %d candidates, %s votes\n", yr, uniqueN(fpx$seat), nrow(fpx),
              format(sum(fpx$votes), big.mark = ",")))
  cat(sprintf("ES1  sa%d class totals (votes): %s\n", yr,
              paste(sprintf("%s %s", names(sort(tapply(fpx$votes, fpx$party, sum), TRUE)),
                            format(sort(tapply(fpx$votes, fpx$party, sum), TRUE), big.mark = ",")), collapse = " | ")))
  # winners from the district's own TCP table; Norwood (Wikipedia) has none, and
  # is won by the highest first preference (Marshall, LIB: 46.3% in a 2PP seat)
  tcp <- x[table == "tcp"]
  w <- tcp[, .SD[which.max(votes)], by = seat][, .(seat, party_code = party)]
  w[, winner := class_of_code(party_code)]
  if (yr == 2010L) {
    nw <- fpx[seat == "Norwood"][which.max(votes)]
    w <- rbind(w, data.table(seat = "Norwood", party_code = nw$party_raw, winner = nw$party), fill = TRUE)
    cat("ES3  sa2010 Norwood winner taken as the top first preference (Wikipedia-sourced box), not a TCP table\n")
  }
  stopifnot(!anyDuplicated(w$seat), nrow(w) == 47L)
  cat(sprintf("ES1  sa%d winners: %s\n", yr,
              paste(sprintf("%s %d", names(table(w$winner)), as.integer(table(w$winner))), collapse = ", ")))
  # cross-check the winner against the first-preference leader's class where a major
  fl <- fpx[, .SD[which.max(votes)], by = seat][, .(seat, fp_leader = party)]
  cmp <- merge(w, fl, by = "seat")
  cat(sprintf("ES2  sa%d: winner class differs from first-preference leader in %d seats: %s\n", yr,
              sum(cmp$winner != cmp$fp_leader),
              paste(sprintf("%s (%s->%s)", cmp$seat, cmp$fp_leader, cmp$winner)[cmp$winner != cmp$fp_leader], collapse = ", ")))
  res[[as.character(yr)]] <- list(fp = fpx, w = w)
  fwrite(fpx[, .(seat, name = candidate, party_raw, party, votes)],
         file.path(OUT, sprintf("ecsa-%d-sa-candidates.csv", yr)))
  fwrite(w[, .(election = sprintf("sa%d", yr), seat, winner)],
         file.path(OUT, sprintf("ecsa-%d-sa-winners.csv", yr)))
}
# ---- sa2006 (prev of the sa2010 pair) ---------------------------------------------
# ecsa-2006-sa-firstprefs-detail.csv (Jaensch's compilation of ECSA's 2006 results) is
# already candidate-level with ECSA party classes. Two traps:
#  1. NAMES are a FOURTH format, "SURNAME INITIALS": winners shouted ("LOMAX-SMITH JD"),
#     the rest Title-case ("Carroll D"). Rewritten here as "SURNAME, INITIALS" so the
#     comma rule every name helper already has (surname_of(), given_of(), .key(),
#     name_key() in build_retirement_derived.py) reads it. A bare initials block is not a
#     name: given_stem() already treats a <=3-letter vowel-free run as "no evidence".
#  2. The file's `elected` flag is WRONG: it is blank for 7 seats and marks the Liberal in
#     Hartley, Light, Mawson and Morialta, which Labor won (Portolesi, Piccolo, Bignell,
#     Simmons). Winners are therefore taken from the AEF archive's TCP table (2006sa-tcp.csv,
#     47 seats), the last-resort source, and cross-checked: its class totals must equal the
#     real 2006 result (ALP 28; Liberal and Nationals 16; independents 3) and it must agree
#     with ECSA's own TCP table in the 20 seats that table covers.
d6 <- fread(file.path(EL, "ecsa-2006-sa-firstprefs-detail.csv"), showProgress = FALSE)
stopifnot(uniqueN(d6$seat) == 47L, !anyNA(d6$votes))
CODE_NAME[["NAT"]] <- "National Party of Australia (SA)"
chk <- d6[nzchar(party_code) & party_code %in% names(CODE_NAME)]
stopifnot(all(class_of_code(chk$party_code) == chk$party_class))   # ECSA's class agrees with ours wherever the code is known
# "Scalzi G (J)": the bracket is the preferred name's initial (Joe); put it first so a later
# "SCALZI, Joe" meets "SCALZI, JG" on surname + first initial.
cand6 <- sub("^(.*) ([A-Z]{1,4}) \\(([A-Z])\\)$", "\\1 \\3\\2", d6$candidate)
nm6 <- sub("^(.*) ([A-Z]{1,4})$", "\\1|\\2", cand6)
stopifnot(all(grepl("|", nm6, fixed = TRUE)))
sur6 <- toupper(sub("\\|.*$", "", nm6)); ini6 <- sub("^.*\\|", "", nm6)
c6 <- d6[, .(seat = seat, name = sprintf("%s, %s", sur6, ini6),
             party_raw = ifelse(nzchar(party_code), party_code, "IND"), party = party_class, votes = votes)]
stopifnot(!anyDuplicated(c6[, .(seat, name)]))
a6 <- fread(file.path(EL, "archive", "2006sa-tcp.csv"), showProgress = FALSE)
w6 <- a6[, .SD[which.max(votes)], by = seat][, .(seat, winner = party)]
stopifnot(nrow(w6) == 47L)
tab6 <- table(w6$winner)
cat(sprintf("ES1  sa2006 winners (AEF archive TCP): %s\n", paste(sprintf("%s %d", names(tab6), as.integer(tab6)), collapse = ", ")))
stopifnot(tab6[["ALP"]] == 28L, tab6[["LNP"]] == 16L, tab6[["IND"]] == 3L)
t6 <- fread(file.path(EL, "ecsa-2006-sa-tcp-detail.csv"), showProgress = FALSE)
ow6 <- t6[, .SD[which.max(votes)], by = seat][, .(seat, ecsa = party_class)]
mm6 <- merge(w6, ow6, by = "seat")
cat(sprintf("ES2  sa2006: archive winners agree with ECSA's own TCP table in %d of %d seats\n", sum(mm6$winner == mm6$ecsa), nrow(mm6)))
stopifnot(all(mm6$winner == mm6$ecsa))
cat(sprintf("ES1  sa2006: %d districts, %d candidates, %s votes\n", uniqueN(c6$seat), nrow(c6), format(sum(c6$votes), big.mark = ",")))
fwrite(c6, file.path(OUT, "ecsa-2006-sa-candidates.csv"))
fwrite(w6[, .(election = "sa2006", seat, winner)], file.path(OUT, "ecsa-2006-sa-winners.csv"))
cat("ES9  wrote", OUT, "\n")

# NSW Legislative Assembly distribution of preferences, 2019 and 2023.
#
# Produces the same shape as vec-2022-vic-transfers.csv -- election, seat,
# round, from, to, votes -- so build_flow_matrix() consumes it unchanged.
#
# WHY: the flow matrix currently rests on ONE election (Victoria 2022). That is
# why preference-flow uncertainty could not be answered, and why the seat model
# has no second opinion about how minor-party votes move. NSW adds two.
#
# The NSWEC publishes one distribution-of-preferences page per district:
#   https://pastvtr.elections.nsw.gov.au/{code}/LA/{district}/dop/dop
# Each is an HTML table: one column pair per count, the excluded candidate named
# in the header, and each surviving candidate's VotesDistributed for that count.
#
# 93 districts x 2 elections = 186 requests, fetched once and cached under
# external/reference/nsw/dop/. Both that and external/elections/ are GITIGNORED.
#
# Emits NT* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "nsw", "dop")
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
OUT <- election_data_path()

ELECTIONS <- list(list(year = 2019, code = "SG1901"),
                  list(year = 2023, code = "SG2301"))

districts_of <- function(code) {
  idx <- file.path(RAW, sprintf("index-%s.html", code))
  if (!file.exists(idx)) {
    utils::download.file(sprintf("https://pastvtr.elections.nsw.gov.au/%s/LA/results", code),
                         idx, quiet = TRUE, headers = c("User-Agent" = UA))
  }
  h <- paste(readLines(idx, warn = FALSE), collapse = "\n")
  d <- unique(regmatches(h, gregexpr(sprintf("/%s/LA/[a-z0-9-]+/dop/dop", code), h))[[1]])
  unique(sub(sprintf("^/%s/LA/([a-z0-9-]+)/dop/dop$", code), "\\1", d))
}

strip <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", x)))

parse_dop <- function(html, seat, election) {
  tb <- regmatches(html, regexpr("(?s)<table.*?</table>", html, perl = TRUE))
  if (!length(tb)) return(NULL)
  trs <- regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]
  cells <- lapply(trs, function(tr)
    strip(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]]))
  # Row 2 names the excluded candidate for each count, in count order.
  hdr <- cells[[2]]
  exc <- hdr[grepl("Excluded Candidate", hdr)]
  if (!length(exc)) return(NULL)                 # unopposed / no exclusions
  # An excluded candidate with no "(CODE)" is a genuine independent, not a
  # parse failure -- the NSWEC prints no party for them. Anything else that
  # fails to resolve IS a parse failure and must not be quietly bucketed.
  exc_party <- ifelse(grepl("[(][^)]+[)]", exc),
                      sub(".*[(]([^)]+)[)].*", "\\1", exc), "IND")
  # Candidate rows carry a name+party label then alternating
  # VotesDistributed / ProgressiveTotals per count.
  out <- list()
  for (r in cells) {
    if (length(r) < 4) next
    lab <- r[1]
    if (grepl("^(Candidates|Total|Exhausted|Informal|Absolute)", lab)) next
    if (!grepl("[A-Z]{2,}$", lab)) next
    # The label is "SURNAME GivenNameCODE" with no separator, so a trailing
    # uppercase run is NOT a safe way to read the code: a surname ending in
    # capitals merges with it and yields things like "WYGRN". Match against the
    # authoritative code list instead, longest first so a short code that is a
    # suffix of a longer one cannot win.
    hit <- CODES[vapply(CODES, function(k) endsWith(lab, k), logical(1))]
    to_party <- if (length(hit)) hit[which.max(nchar(hit))] else "IND"
    vals <- r[-1]
    # vals: FirstPreference, then (dist, prog) per count.
    for (k in seq_along(exc_party)) {
      i <- 1L + (k - 1L) * 2L + 1L
      if (i > length(vals)) break
      v <- suppressWarnings(as.numeric(gsub("[^0-9]", "", vals[i])))
      if (!is.finite(v) || v <= 0) next
      out[[length(out) + 1L]] <- data.table(
        election = election, seat = seat, round = k,
        from_raw = exc_party[k], to_raw = to_party, votes = v)
    }
  }
  if (!length(out)) return(NULL)
  rbindlist(out)
}

# The DOP pages print party ACRONYMS only. Passing those to classify_party()
# with no name is not a partial mapping -- it is a WRONG one: an unrecognised
# code leaves the name empty, and the classifier's `!nzchar(n)` branch buckets
# every such party as IND. SFF, LDP, SAP and AJP all became independents, which
# showed up as IND being the largest single source of transfers in the state.
# So the acronym -> name lookup is rebuilt from the first-preference workbooks,
# which carry both, and a code with no known name is refused rather than guessed.
fp_files <- file.path(OUT, sprintf("nswec-%d-nsw-firstprefs.csv", c(2019, 2023)))
if (!all(file.exists(fp_files))) {
  stop("Run scripts/fetch_preferences_nsw.R first: the acronym -> party-name ",
       "lookup is built from its workbooks, and without it every unrecognised ",
       "code is silently classified as IND.")
}
lut <- rbindlist(lapply(c(2019, 2023), function(y) {
  d <- as.data.table(readxl::read_excel(
    file.path(RAW, "..", sprintf("sge%d-la-final-votes.xlsx", y)), sheet = "Data"))
  setnames(d, make.names(names(d)))
  unique(d[, .(code = toupper(trimws(Party.Acronym)),
               name = trimws(Party.Name))])
}))
# nzchar AND !is.na. The comment above describes a bug caused by an EMPTY name
# reaching classify_party()'s !nzchar branch, so filtering only NA would leave
# the exact hole this lookup exists to close.
lut <- unique(lut[nzchar(code) & !is.na(name) & nzchar(name)], by = "code")
name_of <- setNames(lut$name, lut$code)
CODES <- lut$code[order(-nchar(lut$code))]

all_rows <- list()
for (E in ELECTIONS) {
  ds <- districts_of(E$code)
  cat(sprintf("\nNT1  %d: %d districts listed\n", E$year, length(ds)))
  stopifnot(length(ds) == 93L)
  got <- 0L; empty <- character(0)
  for (dn in ds) {
    f <- file.path(RAW, sprintf("%s-%s.html", E$code, dn))
    if (!file.exists(f)) {
      url <- sprintf("https://pastvtr.elections.nsw.gov.au/%s/LA/%s/dop/dop", E$code, dn)
      try(utils::download.file(url, f, quiet = TRUE,
                               headers = c("User-Agent" = UA)), silent = TRUE)
      Sys.sleep(0.2)
    }
    if (!file.exists(f)) { empty <- c(empty, dn); next }
    h <- paste(readLines(f, warn = FALSE), collapse = "\n")
    p <- parse_dop(h, dn, sprintf("nsw%d", E$year))
    if (is.null(p)) { empty <- c(empty, dn); next }
    all_rows[[length(all_rows) + 1L]] <- p; got <- got + 1L
  }
  cat(sprintf("NT1  %d: parsed %d districts, %d with no exclusions or no table\n",
              E$year, got, length(empty)))
  if (length(empty)) cat("     ", paste(head(empty, 10), collapse = ", "), "\n")
}

tx <- rbindlist(all_rows)
# Party CODES here, not names -- classify_party() takes codes as its second
# argument and they are what the NSWEC prints. Computed outside the brackets.

unknown <- setdiff(unique(c(tx$from_raw, tx$to_raw)), names(name_of))
unknown <- unknown[nzchar(unknown)]
if (length(unknown)) {
  stop("Party codes in the preference distributions with no name in the ",
       "first-preference workbooks: ", paste(unknown, collapse = ", "),
       ". Classifying them without a name would silently make them IND.")
}
tx[, from := classify_party(unname(name_of[from_raw]), from_raw)]
tx[, to := classify_party(unname(name_of[to_raw]), to_raw)]
# The DOP URLs use slugs ("badgerys-creek"); everything else in this repo uses
# the commission's district name ("Badgerys Creek"). Mapped from the
# first-preference workbooks rather than by un-slugging, which would guess
# wrong on any name whose punctuation does not round-trip. A slug that fails to
# resolve is refused: an unmatched seat would silently drop its transfers.
fpn <- unique(rbindlist(lapply(c(2019, 2023), function(y)
  fread(file.path(OUT, sprintf("nswec-%d-nsw-firstprefs.csv", y)))[, .(seat)]))$seat)
slug_of <- tolower(gsub(" ", "-", fpn))
name_by_slug <- setNames(fpn, slug_of)
bad <- setdiff(unique(tx$seat), names(name_by_slug))
if (length(bad)) {
  stop("Preference-distribution slugs with no matching district name: ",
       paste(bad, collapse = ", "), ". Their transfers would be dropped.")
}
tx[, seat := unname(name_by_slug[seat])]

tx <- tx[, .(votes = sum(votes)), by = .(election, seat, round, from, to)]

cat(sprintf("\nNT2  %d transfer rows across %d seat-elections, %s votes moved\n",
            nrow(tx), uniqueN(paste(tx$election, tx$seat)),
            format(sum(tx$votes), big.mark = ",")))
print(tx[, .(votes = sum(votes)), by = from][order(-votes)])
stopifnot(nrow(tx) > 0, all(tx$votes > 0))

f <- file.path(OUT, "nswec-nsw-transfers.csv")
fwrite(tx, f)
cat(sprintf("NT3  wrote %s\n", f))
fm <- build_flow_matrix(tx, min_n = 3L)
cat(sprintf("NT4  flow matrix: %d conditional cells, %d pooled rows\n",
            length(fm$conditional), length(fm$pooled)))

# ---- the DECLARED winner of each district ----------------------------------
# Truth for a backtest must not come from our own exclusion machinery. Running
# the actual votes through distribute_preferences() to decide who won means any
# systematic flaw in the flow matrix cancels between truth and prediction, and
# the model scores better than it deserves. The NSWEC marks the winner ELECTED
# in the distribution table; that is the commission's declaration and is
# independent of anything this package computes.
elected <- rbindlist(lapply(ELECTIONS, function(E) {
  rbindlist(lapply(districts_of(E$code), function(dn) {
    f <- file.path(RAW, sprintf("%s-%s.html", E$code, dn))
    if (!file.exists(f)) return(NULL)
    h <- paste(readLines(f, warn = FALSE), collapse = "
")
    tb <- regmatches(h, regexpr("(?s)<table.*?</table>", h, perl = TRUE))
    if (!length(tb)) return(NULL)
    for (tr in regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]) {
      cs <- strip(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]])
      if (!length(cs)) next
      if (grepl("^(Candidates|Total|Exhausted|Informal|Absolute)", cs[1])) next
      if (!any(grepl("ELECTED", cs[-1]))) next
      hit <- CODES[vapply(CODES, function(k) endsWith(cs[1], k), logical(1))]
      if (!length(hit)) next
      code <- hit[which.max(nchar(hit))]
      return(data.table(election = sprintf("nsw%d", E$year), slug = dn,
                        code = code,
                        winner = classify_party(unname(name_of[code]), code)))
    }
    NULL
  }))
}))
elected[, seat := unname(name_by_slug[slug])]
stopifnot(nrow(elected) == 186L, !any(is.na(elected$seat)))
cat(sprintf("NT5  declared winners: %d districts across %d elections
",
            uniqueN(elected$seat), uniqueN(elected$election)))
print(elected[, .N, by = .(election, winner)][order(election, -N)])
fwrite(elected[, .(election, seat, code, winner)],
       file.path(OUT, "nswec-nsw-winners.csv"))
cat(sprintf("NT5  wrote %s
", file.path(OUT, "nswec-nsw-winners.csv")))

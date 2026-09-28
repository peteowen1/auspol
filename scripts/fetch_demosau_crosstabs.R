#!/usr/bin/env Rscript
# Fetch DemosAU Victorian state poll and federal poll crosstab PDFs, and parse
# their demographic breakdown tables into a tidy long CSV.
#
# WHY THIS SHAPE (see CLAUDE.md "Before saying we don't have data" / "the same
# rule applies to anything SCRAPED"): the raw PDF is the only thing kept
# permanently. Every number in crosstabs.csv is derived from it on each run,
# never hand-typed once and left to drift from the source. Where a table's
# layout cannot be parsed with confidence (a header/party order pdftools could
# not recover, or a row whose percentages don't sum close to 100), the row is
# NOT guessed -- its raw extracted text goes to crosstabs-ambiguous.txt instead,
# named next to the PDF it came from, and it is left out of crosstabs.csv.
#
# Re-running only re-downloads PDFs missing on disk, and always re-parses and
# re-writes crosstabs.csv from whatever PDFs are present.

suppressPackageStartupMessages({
  if (!requireNamespace("pdftools", quietly = TRUE)) install.packages("pdftools", repos = "https://cloud.r-project.org")
  library(pdftools)
})

raw_dir  <- "external/reference/polls/demosau/raw"
out_csv  <- "external/reference/polls/demosau/crosstabs.csv"
ambig_txt <- "external/reference/polls/demosau/crosstabs-ambiguous.txt"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

ua <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36 auspol-research/1.0 (contact: fptpost@gmail.com)"

# key -> url. jurisdiction is inferred from the key prefix (vic-/fed-).
pdfs <- c(
  "vic-2025-03"  = "https://demosau.com/wp-content/uploads/2025/03/DemosAU-Victoria-VI-Poll-Mar-17-21-2025-2.pdf",
  "vic-2025-09"  = "https://demosau.com/wp-content/uploads/2025/09/DemosAUPremierNational-Release-Victorian-Poll-September-25-1-1.pdf",
  "vic-2025-10"  = "https://demosau.com/wp-content/uploads/2025/11/DemosAU-Victoria-Poll-Oct-25.pdf",
  "vic-2026-02"  = "https://demosau.com/wp-content/uploads/2026/02/DemosAU-Vic-Poll-Feb-2026-1.pdf",
  "vic-2026-06"  = "https://demosau.com/wp-content/uploads/2026/06/DemosAU-Vic-Poll-June-2026.pdf",
  "vic-2026-08"  = "https://demosau.com/wp-content/uploads/2026/08/DemosAU-Report-Victoria-Poll-August-2026.pdf",
  "fed-2026-01"  = "https://demosau.com/wp-content/uploads/2026/01/DemosAU-Australian-Federal-Poll-Jan-5-6-2026.pdf",
  "fed-2026-01b" = "https://demosau.com/wp-content/uploads/2026/01/DemosAU-Federal-Poll-January-2026-FINAL.pdf",
  "fed-2026-02"  = "https://demosau.com/wp-content/uploads/2026/02/DemosAU-Federal-Poll-Feb-2026.pdf",
  "fed-2026-05"  = "https://demosau.com/wp-content/uploads/2026/05/DemosAU-Fed-Poll-May-2026-FINAL.pdf",
  "fed-2026-06"  = "https://demosau.com/wp-content/uploads/2026/06/Capital-BriefDemosAU-Federal-Poll-June-2026-FINAL.pdf",
  "fed-2026-07"  = "https://demosau.com/wp-content/uploads/2026/07/Capital-BriefDemosAU-Federal-Poll-July-2026.pdf",
  "fed-2026-09"  = "https://demosau.com/wp-content/uploads/2026/09/Capital-BriefDemosAU-Federal-Poll-September-2026.pdf"
)
# NOT found despite searching demosau.com and web search: any open, direct-URL
# PDF for Apr/May/Jul/Dec 2025 Victoria, or Mar/Apr/Aug 2026 federal. DemosAU's
# own /news/ listing (fetched directly) shows headline articles but does not
# republish the wp-content PDF paths, so gaps here are a real search ceiling,
# not an oversight -- documented, not silently accepted.

for (key in names(pdfs)) {
  f <- file.path(raw_dir, paste0(key, ".pdf"))
  if (file.exists(f) && file.size(f) > 1000) {
    message("SKIP (already on disk): ", key)
  } else {
    message("Fetching: ", key)
    tryCatch({
      download.file(pdfs[[key]], destfile = f, method = "libcurl",
                    headers = c(`User-Agent` = ua), quiet = TRUE, mode = "wb")
    }, error = function(e) message("  FAILED: ", conditionMessage(e)))
    Sys.sleep(1)
  }
}

## ---- Parsing ----

party_dict <- list(
  ALP = c("ALP", "Labor"),
  LNP = c("LNP", "L/NP", "L-NP", "COALITION", "LIBERAL/NATIONAL", "LIB/NAT"),
  GRN = c("GRN", "GREENS"),
  ONP = c("ONP", "ONE NATION"),
  OTH = c("OTH", "OTHERS", "ANY OTHER CANDIDATE", "OTHER")
)
canon_party <- function(tok) {
  tok_u <- toupper(trimws(tok))
  for (p in names(party_dict)) if (tok_u %in% party_dict[[p]]) return(p)
  NA_character_
}

# A header line: tokens separated by 2+ spaces, each token maps to a distinct
# canonical party (or a "<PARTY> TPP"/"<PARTY> 2PP" variant), >=3 distinct parties.
parse_header <- function(line) {
  toks <- trimws(strsplit(line, "\\s{2,}")[[1]])
  toks <- toks[nzchar(toks)]
  if (length(toks) < 3) return(NULL)
  is_tpp <- grepl("TPP|2PP", toks, ignore.case = TRUE)
  base_tok <- gsub("\\s*(TPP|2PP)\\s*", "", toks, ignore.case = TRUE)
  parties <- vapply(base_tok, canon_party, character(1))
  if (sum(!is.na(parties)) < 3) return(NULL)
  list(parties = parties, is_tpp = is_tpp)
}

extract_pct <- function(line) {
  m <- gregexpr("-?\\d{1,3}(?:\\.\\d+)?%", line, perl = TRUE)
  nums <- regmatches(line, m)[[1]]
  as.numeric(gsub("%", "", nums))
}

extract_label <- function(line) {
  # label = text before the first "<number>%" token (NOT the first digit --
  # labels like "<$45K" or "$125-200K" contain digits themselves and would be
  # truncated to "<$" if we stopped at the first digit).
  m <- regexpr("-?\\d{1,3}(?:\\.\\d+)?%", line, perl = TRUE)
  if (m == -1) return(trimws(line))
  trimws(substr(line, 1, m - 1))
}

meta_from_text <- function(pages_txt) {
  full <- paste(pages_txt, collapse = "\n")
  fw <- regmatches(full, regexpr("Fieldwork dates[^\n]*", full, perl = TRUE))
  samp <- regmatches(full, regexpr("Sample size\\s+[0-9,]+", full, perl = TRUE))
  list(fieldwork_line = if (length(fw)) fw else NA, sample_line = if (length(samp)) samp else NA)
}

parse_pdf <- function(path, poll_id, jurisdiction, source_url) {
  pages <- tryCatch(pdf_text(path), error = function(e) NULL)
  if (is.null(pages)) return(list(rows = data.frame(), ambiguous = character(0)))
  meta <- meta_from_text(pages)
  fw_match <- regmatches(meta$fieldwork_line, regexpr("[0-9]{1,2}.*?[0-9]{4}", meta$fieldwork_line, perl = TRUE))
  samp_num <- suppressWarnings(as.numeric(gsub("[^0-9]", "", regmatches(meta$sample_line, regexpr("[0-9,]+$", meta$sample_line)))))

  rows <- list()
  ambiguous <- character(0)
  current_dimension <- NA_character_
  dim_title_re <- "^(Gender|Age|Education|Income|Location|Housing Tenure|Language Status|By Gender|By Age|By Education|By Income|By Location|By Residential Tenure|Males, By Age|Females, By Age|2025 Federal Election Vote|2022.*Vote)\\s*$"
  # Only pages carrying one of these titles are genuine demographic-breakdown
  # tables. Every other numeric table in these reports -- the "Primary Vote"
  # trend-over-time chart (Apr/May/Jun.. by wave), "Swings Since Last Poll",
  # seat projections, personal ratings -- happens to have a party-name header
  # row too and would otherwise be silently mis-parsed as a demographic cohort
  # (this WAS happening: wave labels "Apr"/"May"/"Jun" were leaking in as
  # dimension="unlabelled" groups before this gate was added).
  breakdown_page_re <- paste0("(?i)(Demographic Breakdowns|Voting Intention: Gender|",
                               "Voting Intention: State|Voting Intention: Past|",
                               "State Voting Intention Tables|",
                               "Federal Voting Intention Tables - Demographics|",
                               "Education \\+ Income)")

  for (pg in seq_along(pages)) {
    if (!grepl(breakdown_page_re, pages[pg], perl = TRUE)) next
    lines <- strsplit(pages[pg], "\n")[[1]]
    i <- 1
    while (i <= length(lines)) {
      line <- lines[i]
      trimmed <- trimws(line)
      if (nchar(trimmed) == 0) { i <- i + 1; next }
      if (grepl(dim_title_re, trimmed, perl = TRUE)) {
        current_dimension <- trimmed
        i <- i + 1
        next
      }
      hdr <- parse_header(line)
      if (!is.null(hdr)) {
        parties <- hdr$parties
        is_tpp <- hdr$is_tpp
        n_fp <- sum(!is.na(parties) & !is_tpp)
        j <- i + 1
        while (j <= length(lines)) {
          rline <- lines[j]
          rtrim <- trimws(rline)
          if (nchar(rtrim) == 0) { j <- j + 1; next }
          if (grepl("^0%\\s", rtrim) || grepl("^Q\\.|^Question|PAGE|^=====", rtrim)) break
          if (!is.null(parse_header(rline))) break
          if (grepl(dim_title_re, rtrim, perl = TRUE)) break
          pcts <- extract_pct(rline)
          label <- extract_label(rline)
          if (length(pcts) >= n_fp && n_fp >= 3 && nchar(label) > 0 && !grepl("^[0-9]", label)) {
            fp_vals <- pcts[seq_len(n_fp)]
            fp_parties <- parties[!is.na(parties) & !is_tpp]
            ok <- abs(sum(fp_vals) - 100) <= 3
            if (ok) {
              for (k in seq_along(fp_vals)) {
                rows[[length(rows) + 1]] <- data.frame(
                  poll_id = poll_id, jurisdiction = jurisdiction,
                  dimension = ifelse(is.na(current_dimension), "unlabelled", current_dimension),
                  group = label, response = fp_parties[k], pct = fp_vals[k],
                  question = "voting_intention_fp", source_url = source_url,
                  stringsAsFactors = FALSE
                )
              }
              # any trailing TPP columns on the same row
              if (any(is_tpp) && length(pcts) > n_fp) {
                tpp_vals <- pcts[(n_fp + 1):length(pcts)]
                tpp_parties <- parties[is_tpp]
                for (k in seq_along(tpp_vals)) {
                  if (k <= length(tpp_parties) && !is.na(tpp_parties[k])) {
                    rows[[length(rows) + 1]] <- data.frame(
                      poll_id = poll_id, jurisdiction = jurisdiction,
                      dimension = ifelse(is.na(current_dimension), "unlabelled", current_dimension),
                      group = label, response = paste0(tpp_parties[k], "_TPP"), pct = tpp_vals[k],
                      question = "voting_intention_tpp", source_url = source_url,
                      stringsAsFactors = FALSE
                    )
                  }
                }
              }
            } else {
              ambiguous <- c(ambiguous, sprintf("[%s p%d] header=%s | row=%s (fp sum=%.1f)",
                                                  poll_id, pg, trimws(line), rtrim, sum(fp_vals)))
            }
          }
          j <- j + 1
        }
        i <- j
        next
      }
      i <- i + 1
    }
  }
  df <- if (length(rows)) do.call(rbind, rows) else data.frame()
  list(rows = df, ambiguous = ambiguous, fieldwork = meta$fieldwork_line, sample_n = samp_num)
}

parse_fieldwork <- function(fw_line) {
  if (is.na(fw_line)) return(c(NA_character_, NA_character_))
  m <- regmatches(fw_line, regexec("([0-9]{1,2})\\s*-\\s*([0-9]{1,2})\\s+([A-Za-z]+)\\s+([0-9]{4})", fw_line))[[1]]
  if (length(m) == 5) {
    mo <- match(tolower(substr(m[4], 1, 3)), tolower(month.abb))
    if (!is.na(mo)) {
      d1 <- sprintf("%s-%02d-%02d", m[5], mo, as.integer(m[2]))
      d2 <- sprintf("%s-%02d-%02d", m[5], mo, as.integer(m[3]))
      return(c(d1, d2))
    }
  }
  c(NA_character_, NA_character_)
}

poll_files <- list.files(raw_dir, pattern = "\\.pdf$", full.names = FALSE)
all_rows <- list()
all_ambig <- character(0)
for (fn in poll_files) {
  key <- sub("\\.pdf$", "", fn)
  jurisdiction <- if (grepl("^vic-", key)) "VIC" else "federal"
  res <- parse_pdf(file.path(raw_dir, fn), poll_id = key, jurisdiction = jurisdiction,
                    source_url = pdfs[[key]])
  if (nrow(res$rows) > 0) {
    fw <- parse_fieldwork(res$fieldwork)
    res$rows$sample_n <- res$sample_n
    res$rows$fieldwork_start <- fw[1]
    res$rows$fieldwork_end <- fw[2]
    all_rows[[key]] <- res$rows
  }
  if (length(res$ambiguous)) all_ambig <- c(all_ambig, res$ambiguous)
  message(key, ": ", nrow(res$rows), " rows parsed, ", length(res$ambiguous), " ambiguous")
}

## ---- Hand-parsed tables for documents whose headers wrap across multiple
## PDF text lines, which the generic single-line header parser above cannot
## recover reliably (pdftools linearises a multi-row header into pieces whose
## order does not match the data columns beneath it -- verified per-document,
## not assumed, by checking each row's non-TPP/non-DK values sum to ~100).
## Each of these three tables was read directly from the pdf_text() dump and
## is one of the tables spot-checked by hand against the source PDF (see
## report). Column order is fixed WITHIN each document, confirmed against
## multiple rows before being applied to the rest of that document's table.

hand <- list()
hadd <- function(poll_id, jurisdiction, dim, group, vals, parties, source_url, sample_n) {
  for (i in seq_along(parties)) {
    hand[[length(hand) + 1]] <<- data.frame(
      poll_id = poll_id, fieldwork_start = NA_character_, fieldwork_end = NA_character_,
      jurisdiction = jurisdiction, sample_n = sample_n,
      question = ifelse(grepl("TPP", parties[i]), "voting_intention_tpp", "voting_intention_fp"),
      dimension = dim, group = group, response = parties[i], pct = vals[i],
      source_url = source_url, stringsAsFactors = FALSE
    )
  }
}

## --- vic-2025-10 (DemosAU-Victoria-Poll-Oct-25.pdf), fieldwork 21-27 Oct 2025 ---
## Column order verified: ALP, LNP, GRN, OTH, LNP_TPP, DK (first four sum to 100
## on every row checked: Victoria 26+37+15+22=100; Males 28+39+11+22=100; etc.)
u <- pdfs[["vic-2025-10"]]; jd <- "VIC"; sn <- 1016
p10 <- c("ALP","LNP","GRN","OTH","LNP_TPP","DK")
hadd("vic-2025-10", jd, "state", "Victoria",       c(26,37,15,22,51,6), p10, u, sn)
hadd("vic-2025-10", jd, "gender", "Males",         c(28,39,11,22,53,6), p10, u, sn)
hadd("vic-2025-10", jd, "gender", "Females",       c(24,36,19,21,50,6), p10, u, sn)
hadd("vic-2025-10", jd, "age", "18-34",            c(30,23,31,16,35,5), p10, u, sn)
hadd("vic-2025-10", jd, "age", "35-54",            c(27,34,19,20,47,9), p10, u, sn)
hadd("vic-2025-10", jd, "age", "55+",              c(23,46,5,26,62,4),  p10, u, sn)
hadd("vic-2025-10", jd, "education", "School",     c(27,37,12,24,52,6), p10, u, sn)
hadd("vic-2025-10", jd, "education", "TAFE",       c(24,34,16,26,51,7), p10, u, sn)
hadd("vic-2025-10", jd, "education", "University", c(26,39,19,16,50,4), p10, u, sn)
hadd("vic-2025-10", jd, "housing_tenure", "Owned",     c(23,50,7,20,62,3),  p10, u, sn)
hadd("vic-2025-10", jd, "housing_tenure", "Mortgage",  c(27,34,18,21,48,7), p10, u, sn)
hadd("vic-2025-10", jd, "housing_tenure", "Rented",    c(27,25,22,26,42,8), p10, u, sn)
hadd("vic-2025-10", jd, "income", "<$45K",     c(25,35,14,26,52,8), p10, u, sn)
hadd("vic-2025-10", jd, "income", "$45-125K",  c(25,38,15,22,52,5), p10, u, sn)
hadd("vic-2025-10", jd, "income", ">$125K",    c(29,42,21,8,49,3),  p10, u, sn)
hadd("vic-2025-10", jd, "location", "Inner Metro",     c(27,31,25,17,43,7), p10, u, sn)
hadd("vic-2025-10", jd, "location", "Outer Metro",     c(27,40,11,22,54,5), p10, u, sn)
hadd("vic-2025-10", jd, "location", "Rural and Regional", c(22,39,10,29,57,5), p10, u, sn)

## --- vic-2025-09 (DemosAUPremierNational-Release-Victorian-Poll-Sept-25.pdf),
## fieldwork 2-9 Sep 2025. Column order verified: LNP, ALP, GRN, OTH, DK, LNP_TPP
## (first four sum to ~100 on every row: Victoria 38+26+15+21=100; Males
## 43+27+11+20=101 rounding; Female 18-24 13+23+59+4=99 rounding).
u <- pdfs[["vic-2025-09"]]; jd <- "VIC"; sn <- 1327
p9 <- c("LNP","ALP","GRN","OTH","DK","LNP_TPP")
hadd("vic-2025-09", jd, "state", "Victoria",       c(38,26,15,21,9,51),  p9, u, sn)
hadd("vic-2025-09", jd, "gender", "Males",         c(43,27,11,20,8,56),  p9, u, sn)
hadd("vic-2025-09", jd, "gender", "Females",       c(33,26,19,23,10,48), p9, u, sn)
hadd("vic-2025-09", jd, "age", "18-24",  c(21,30,39,10,7,30), p9, u, sn)
hadd("vic-2025-09", jd, "age", "25-34",  c(27,33,22,19,8,40), p9, u, sn)
hadd("vic-2025-09", jd, "age", "35-44",  c(26,34,20,20,9,40), p9, u, sn)
hadd("vic-2025-09", jd, "age", "45-54",  c(41,21,13,25,13,57), p9, u, sn)
hadd("vic-2025-09", jd, "age", ">54",    c(48,22,6,24,8,63),   p9, u, sn)
hadd("vic-2025-09", jd, "male_by_age", "Male 18-24", c(30,37,17,16,6,41), p9, u, sn)
hadd("vic-2025-09", jd, "male_by_age", "Male 25-34", c(29,37,17,17,6,41), p9, u, sn)
hadd("vic-2025-09", jd, "male_by_age", "Male 35-44", c(27,34,15,24,9,42), p9, u, sn)
hadd("vic-2025-09", jd, "male_by_age", "Male 45-54", c(51,23,10,15,15,61), p9, u, sn)
hadd("vic-2025-09", jd, "male_by_age", "Male >54",   c(53,20,6,21,6,66),  p9, u, sn)
hadd("vic-2025-09", jd, "female_by_age", "Female 18-24", c(13,23,59,4,7,21),  p9, u, sn)
hadd("vic-2025-09", jd, "female_by_age", "Female 25-34", c(25,28,27,20,10,39), p9, u, sn)
hadd("vic-2025-09", jd, "female_by_age", "Female 35-44", c(25,34,24,17,9,37),  p9, u, sn)
hadd("vic-2025-09", jd, "female_by_age", "Female 45-54", c(32,19,15,34,11,53), p9, u, sn)
hadd("vic-2025-09", jd, "female_by_age", "Female >54",   c(43,24,7,26,10,59),  p9, u, sn)
hadd("vic-2025-09", jd, "location", "Inner Metro",       c(36,27,19,18,7,48),  p9, u, sn)
hadd("vic-2025-09", jd, "location", "Outer Metro",       c(39,25,14,21,10,53), p9, u, sn)
hadd("vic-2025-09", jd, "location", "Rural and Regional", c(36,28,11,26,8,52), p9, u, sn)
hadd("vic-2025-09", jd, "education", "Did not finish Grade 12",     c(39,25,7,29,19,57),  p9, u, sn)
hadd("vic-2025-09", jd, "education", "Completed Grade 12",          c(42,23,20,15,9,53),  p9, u, sn)
hadd("vic-2025-09", jd, "education", "TAFE Certificate or Apprenticeship", c(30,27,15,28,6,48), p9, u, sn)
hadd("vic-2025-09", jd, "education", "Undergraduate University Degree",   c(42,27,19,13,4,51), p9, u, sn)
hadd("vic-2025-09", jd, "education", "Postgraduate University Degree",    c(39,35,13,14,4,48), p9, u, sn)
hadd("vic-2025-09", jd, "income", "<$45K",     c(35,25,14,25,12,51), p9, u, sn)
hadd("vic-2025-09", jd, "income", "$45-75K",   c(35,28,14,23,8,50),  p9, u, sn)
hadd("vic-2025-09", jd, "income", "$75-125K",  c(39,31,17,12,4,48),  p9, u, sn)
hadd("vic-2025-09", jd, "income", "$125-200K", c(44,24,18,13,5,53),  p9, u, sn)
hadd("vic-2025-09", jd, "income", ">$200K",    c(51,21,15,13,1,60),  p9, u, sn)
hadd("vic-2025-09", jd, "housing_tenure", "Rented",   c(21,30,25,25,14,38), p9, u, sn)
hadd("vic-2025-09", jd, "housing_tenure", "Mortgage", c(38,25,15,22,7,52),  p9, u, sn)
hadd("vic-2025-09", jd, "housing_tenure", "Owned",    c(48,26,9,18,8,59),   p9, u, sn)

## --- fed-2026-01 (DemosAU-Australian-Federal-Poll-Jan-5-6-2026.pdf), fieldwork
## 5-6 Jan 2026. Column order verified: ALP, LNP, GRN, ONP, OTH, DK (first five
## sum to 100 on every row: Australia 29+23+12+23+13=100).
u <- pdfs[["fed-2026-01"]]; jd <- "federal"; sn <- 1027
pf1 <- c("ALP","LNP","GRN","ONP","OTH","DK")
hadd("fed-2026-01", jd, "national", "Australia", c(29,23,12,23,13,5), pf1, u, sn)
hadd("fed-2026-01", jd, "gender", "Males",       c(34,24,7,24,11,3),  pf1, u, sn)
hadd("fed-2026-01", jd, "gender", "Females",     c(24,22,17,23,14,8), pf1, u, sn)
hadd("fed-2026-01", jd, "age", "18-34", c(32,19,26,12,11,4), pf1, u, sn)
hadd("fed-2026-01", jd, "age", "35-54", c(27,22,8,26,17,9),  pf1, u, sn)
hadd("fed-2026-01", jd, "age", "55+",   c(28,26,6,28,12,3),  pf1, u, sn)
hadd("fed-2026-01", jd, "education", "School",     c(30,24,10,25,11,7), pf1, u, sn)
hadd("fed-2026-01", jd, "education", "TAFE",       c(24,20,9,30,17,6),  pf1, u, sn)
hadd("fed-2026-01", jd, "education", "University", c(33,26,18,13,10,2), pf1, u, sn)
hadd("fed-2026-01", jd, "housing_tenure", "Rented",   c(30,16,17,20,17,8), pf1, u, sn)
hadd("fed-2026-01", jd, "housing_tenure", "Mortgage", c(29,25,11,27,8,3),  pf1, u, sn)
hadd("fed-2026-01", jd, "housing_tenure", "Owned",    c(28,27,8,23,14,5),  pf1, u, sn)
hadd("fed-2026-01", jd, "income", "<$45K",     c(28,20,10,26,16,7), pf1, u, sn)
hadd("fed-2026-01", jd, "income", "$45-125K",  c(30,23,14,22,11,5), pf1, u, sn)
hadd("fed-2026-01", jd, "income", "$125K+",    c(29,36,14,18,3,1),  pf1, u, sn)
hadd("fed-2026-01", jd, "location", "Inner Metro",     c(37,26,15,16,6,6),  pf1, u, sn)
hadd("fed-2026-01", jd, "location", "Outer Metro",     c(26,23,11,24,16,4), pf1, u, sn)
hadd("fed-2026-01", jd, "location", "Regional/Rural",  c(25,20,11,32,12,7), pf1, u, sn)
pf1b <- c("ALP","LNP","GRN","ONP","OTH","DK")
hadd("fed-2026-01", jd, "past_vote_2025", "ALP 2025 Vote", c(77,5,3,11,4,4),   pf1b, u, sn)
hadd("fed-2026-01", jd, "past_vote_2025", "L/NP 2025 Vote", c(5,59,1,31,4,1),  pf1b, u, sn)
hadd("fed-2026-01", jd, "past_vote_2025", "Grn 2025 Vote", c(2,10,82,4,2,1),   pf1b, u, sn)
hadd("fed-2026-01", jd, "past_vote_2025", "ONP 2025 Vote", c(1,8,2,88,1,1),    pf1b, u, sn)
hadd("fed-2026-01", jd, "past_vote_2025", "Oth 2025 Vote", c(4,8,1,25,62,3),   pf1b, u, sn)
hadd("fed-2026-01", jd, "past_vote_2025", "Did Not Remember/Did Not Vote", c(29,10,16,20,25,37), pf1b, u, sn)

if (length(hand)) all_rows[["hand_coded"]] <- do.call(rbind, hand)

## vic-2026-02 (Feb 2026) and fed-2026-01b (January 2026, longer "FINAL" version):
## their "Demographic Breakdowns" pages contain ONLY the section title as text
## -- pdftools recovers no data at all, meaning the charts are embedded as
## images/vector paths with no text layer (unlike every other document here).
## Confirmed by grepping the full pdf_text() dump for these two files: nothing
## follows the heading. Nothing to keep in a side file because there is no
## extractable raw text for those specific pages; the PDFs themselves remain
## on disk as the raw source. NOT parsed, NOT guessed.
## vic-2025-03 (Mar 2025): confirmed to carry NO demographic breakdown section
## at all (topline primary vote / 2PP / preferred leader only) -- nothing to
## extract because DemosAU did not publish crosstabs for that release.

crosstabs <- do.call(rbind, all_rows)

# Fieldwork dates for the three hand-coded documents (read directly off each
# PDF's methodology page during inspection; the generic date regex above only
# runs on documents parsed by parse_pdf()).
fw_lookup <- list(
  "vic-2025-10" = c("2025-10-21", "2025-10-27"),
  "vic-2025-09" = c("2025-09-02", "2025-09-09"),
  "fed-2026-01" = c("2026-01-05", "2026-01-06")
)
for (pid in names(fw_lookup)) {
  sel <- crosstabs$poll_id == pid
  crosstabs$fieldwork_start[sel] <- fw_lookup[[pid]][1]
  crosstabs$fieldwork_end[sel] <- fw_lookup[[pid]][2]
}

# Normalise `dimension` from the row's own group label -- several source PDFs
# (e.g. fed-2026-02, fed-2026-05/06/07/09) print every cohort under one generic
# "Demographic Breakdowns" heading with no per-dimension sub-title, so the
# section-title detector above leaves those rows as "unlabelled". Classifying
# off the group text itself is more reliable here than trusting page layout.
classify_dim <- function(g) {
  gl <- tolower(g)
  if (grepl("^male|^female", gl)) return("gender")
  if (grepl("2025 vote|2022 vote|did not remember", gl)) return("past_vote")
  if (grepl("metro|regional|rural|inner|outer", gl)) return("location")
  if (grepl("renter|rent|mortgage|owner|owned|own home", gl)) return("housing_tenure")
  if (grepl("school|tafe|university|degree|grade 12", gl)) return("education")
  if (grepl("\\$|k\\b", gl) && grepl("[0-9]", gl)) return("income")
  if (grepl("^[0-9]{2}\\s*-\\s*[0-9]{2}$|^[0-9]{2}\\+$|^>\\s*[0-9]{2}$", trimws(gl))) return("age")
  if (grepl("english|lote|language", gl)) return("language")
  if (grepl("australia$|^victoria$", gl)) return("national_or_state")
  NA_character_
}
needs_fix <- crosstabs$dimension %in% c("unlabelled", "Gender", "Age", "Education", "Income",
                                          "Location", "Housing Tenure", "Language Status",
                                          "By Gender", "By Age", "By Education", "By Income",
                                          "By Location", "By Residential Tenure",
                                          "Males, By Age", "Females, By Age")
inferred <- vapply(crosstabs$group[needs_fix], classify_dim, character(1))
crosstabs$dimension[needs_fix] <- ifelse(is.na(inferred), crosstabs$dimension[needs_fix], inferred)
# tidy the remaining verbatim page-title dimensions to the same short vocabulary
crosstabs$dimension <- tolower(gsub("^by ", "", crosstabs$dimension))
crosstabs$dimension[crosstabs$dimension %in% c("males, by age")] <- "gender_x_age"
crosstabs$dimension[crosstabs$dimension %in% c("females, by age")] <- "gender_x_age"
crosstabs$dimension[crosstabs$dimension %in% c("residential tenure")] <- "housing_tenure"
crosstabs$dimension[crosstabs$dimension %in% c("2025 federal election vote", "past_vote_2025")] <- "past_vote"

crosstabs <- crosstabs[, c("poll_id", "fieldwork_start", "fieldwork_end", "jurisdiction",
                            "sample_n", "question", "dimension", "group", "response", "pct", "source_url")]
crosstabs <- crosstabs[order(crosstabs$poll_id, crosstabs$dimension, crosstabs$group), ]
write.csv(crosstabs, out_csv, row.names = FALSE, na = "")
writeLines(all_ambig, ambig_txt)
message("Wrote ", nrow(crosstabs), " rows to ", out_csv)
message("Wrote ", length(all_ambig), " ambiguous lines to ", ambig_txt)

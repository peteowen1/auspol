# Measured NSW exhaust rates per excluded party class, 2015 / 2019 / 2023, from NSWEC's own
# distribution-of-preferences pages cached under external/reference/nsw/dop
# (SGE2015-*, SG1901-*, SG2301-*; fetch_transfers_nsw.R).
#
# WHY (8 Nov 2026): the shipped NSW exhaustion (AUSPOL_NSW_EXHAUST) reads the anchor's hand-made
# preference-estimates.csv, whose NSW rows before 2019 carry no exhaust rate at all, so once the
# rates were made time-forward (AUSPOL_NSW_EXHAUST_TF) nsw2019 got no exhaustion. Its 2023 rows
# are partly copies (Greens 2023 = the 2019 row; reviews/nsw-onp-flows-measured-2026-10-07.md).
# The simulator removes the exhausted share of the pot AT EACH EXCLUSION, which is exactly what a
# DOP page prints, so the per-exclusion rate measured here is the simulator's own quantity.
#
# Rate per (election, class) = exhausted / (exhausted + votes distributed to candidates), summed
# over every exclusion of a candidate of that class (bulk exclusions are refused by the parser).
# SE across seats (seat-level ratios, clustered). Writes output/nsw-exhaust-measured.csv and
# output/nsw-exhaust-measured-exclusions.csv (every exclusion, so other cuts need no re-parse).
# Emits NXM codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
RAW <- file.path("external", "reference", "nsw", "dop")
strip <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", x)))
num <- function(s) suppressWarnings(as.numeric(gsub("[^0-9]", "", s)))

# One row per exclusion: who was excluded (name, code), votes to candidates, votes exhausted.
parse_exclusions <- function(f, election, seat) {
  h <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  tb <- regmatches(h, regexpr("(?s)<table.*?</table>", h, perl = TRUE))
  if (!length(tb)) return(NULL)
  trs <- regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]
  cells <- lapply(trs, function(tr) strip(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]]))
  hdr <- cells[[2]]
  exc <- hdr[grepl("Excluded Candidate", hdr)]
  if (!length(exc)) return(NULL)
  if (any(lengths(regmatches(exc, gregexpr("Excluded Candidate", exc))) > 1)) stop("bulk exclusion in ", f)
  exc_code <- ifelse(grepl("[(][^)]+[)]", exc), sub(".*[(]([^)]+)[)].*", "\\1", exc), "IND")
  exc_name <- trimws(sub("\\(.*", "", sub("Excluded Candidate", "", exc)))
  K <- length(exc)
  cand <- list(); ex_row <- NULL
  for (r in cells) {
    if (length(r) < 4) next
    lab <- r[1]
    if (grepl("^Exhausted", lab)) { ex_row <- r[-1]; next }
    if (grepl("^(Candidates|Total|Informal|Absolute|Counts)", lab) || !nzchar(lab)) next
    cand[[length(cand) + 1L]] <- r
  }
  if (is.null(ex_row)) stop("no Exhausted row in ", f)
  rbindlist(lapply(seq_len(K), function(k) {
    i <- 2L * (k - 1L) + 2L   # VotesDistributed column of exclusion k within r[-1]
    to_c <- sum(vapply(cand, function(r) { v <- r[-1]; x <- if (i <= length(v)) v[i] else ""
      if (x %in% c("", "EXCLUDED")) 0 else { y <- num(x); if (is.na(y)) 0 else y } }, 0))
    data.table(election = election, seat = seat, k = k, exc_name = exc_name[k], exc_code = exc_code[k],
               to_candidates = to_c, exhausted = num(ex_row[i]), n_cand = length(cand))
  }))
}

files <- list.files(RAW, pattern = "^(SGE2015|SG1901|SG2301)-.*\\.html$", full.names = TRUE)
files <- files[!grepl("index", files)]
cat(sprintf("NXM0 %d DOP pages on disk\n", length(files)))
yr_of <- function(b) if (startsWith(b, "SGE2015")) "nsw2015" else if (startsWith(b, "SG1901")) "nsw2019" else "nsw2023"
X <- rbindlist(lapply(files, function(f) {
  b <- sub("[.]html$", "", basename(f))
  tryCatch(parse_exclusions(f, yr_of(b), sub("^SGE?[0-9]+-", "", b)),
           error = function(e) { cat(sprintf("NXM1! %s: %s\n", b, conditionMessage(e))); NULL })
}))
stopifnot(nrow(X) > 0)
print(X[, .(seats = uniqueN(seat), exclusions = .N, na_exhausted = sum(is.na(exhausted))), by = election])

# Party class from the code. NSWEC codes are short party abbreviations; LAB and CLP (Country
# LABOR in NSW) are Labor, which classify_party() will not read from "CLP" (NT Country Liberals).
code_map <- c(LAB = "ALP", CLP = "ALP", ALP = "ALP", LIB = "LNP", NAT = "LNP", GRN = "GRN", ON = "ONP", PHON = "ONP",
              ONP = "ONP", SFF = "OTH_RIGHT", IND = "IND", CDP = "OTH_RIGHT", FF = "OTH_RIGHT",
              LDP = "OTH_RIGHT", AC = "OTH_RIGHT", KSO = "OTH_RIGHT")
X[, cls := unname(code_map[exc_code])]
X[is.na(cls), cls := "OTH"]
cat("NXM2 codes by class (exclusions):\n")
print(X[, .N, by = .(cls, exc_code)][order(cls, -N)], nrows = 200)

X[, distributed := to_candidates + exhausted]
X <- X[is.finite(distributed) & distributed > 0]
fwrite(X, file.path("output", "nsw-exhaust-measured-exclusions.csv"))
seat_r <- X[, .(ex = sum(exhausted), d = sum(distributed)), by = .(election, cls, seat)]
pooled <- seat_r[, .(seats = .N, distributed = sum(d), exhausted = sum(ex),
                     rate = 100 * sum(ex) / sum(d),
                     se = if (.N > 1) 100 * sd(ex / d) / sqrt(.N) else NA_real_), by = .(election, cls)]
setorder(pooled, election, cls)
cat("NXM3 measured exhaust rate (% of votes distributed at that class's exclusions; SE across seats):\n")
print(pooled[, .(election, cls, seats, distributed, rate = round(rate, 1), se = round(se, 1))], nrows = 100)
fwrite(pooled, file.path("output", "nsw-exhaust-measured.csv"))
cat("NXM4 wrote output/nsw-exhaust-measured.csv and -exclusions.csv\n")

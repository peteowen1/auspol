# The VEC's final candidate list, from its media-feed set-up file `*MediaFileCandidates*.xml`, Lower House only.
#
#   Rscript scripts/fetch_vec_candidates.R --file=<path to the Candidates xml> --year=2026
#
# Nomination day (9 November 2026; docs/PIPELINE.md section E): the VEC publishes the set-up files once the
# ballot draw is done. Point --file at the downloaded Candidates file. Writes
#   external/reference/vec/<year>/raw/<file name>.<md5 first 8>.xml   the file exactly as received (never overwritten)
#   external/reference/vec/<year>/vec-candidates-<year>.csv           one row per Lower House candidate, every field
# scripts/build_candidacies.R then takes vic<year>'s rows from that CSV instead of the provisional Wikipedia/ABC
# union. Every field the file carries is kept (contest and candidate ids, enrolment, ballot position, the historic
# elected flag, the affiliation id and registered name); nothing is classified here: party classes are
# classify_party()'s job in the builder.
#
# Proven on the real 2022 file (external/reference/vec/2026/feed-docs/inner22/pz/State2022MediaFileCandidates/),
# whose rows are compared with candidacies.csv's vic2022 rows by scripts/check_vec_candidates_vic2022.R.
suppressPackageStartupMessages({ library(data.table); library(xml2) })
a <- commandArgs(trailingOnly = TRUE)
arg <- function(k, d = NULL) { v <- sub(paste0("^--", k, "="), "", a[startsWith(a, paste0("--", k, "="))]); if (length(v)) v[1] else d }
f <- arg("file"); yr <- arg("year")
out_dir <- arg("out", file.path("external", "reference", "vec", yr))
if (is.null(f) || is.null(yr)) stop("usage: fetch_vec_candidates.R --file=<Candidates xml> --year=<YYYY> [--out=<dir>]")
if (!file.exists(f)) stop("VC0! no such file: ", f)
txt <- readLines(f, warn = FALSE, encoding = "UTF-8")
# a size floor is not a completeness check: the closing tag is (CLAUDE.md, the 65536-byte truncation)
if (!any(grepl("</EML>\\s*$", txt))) stop("VC1! ", basename(f), " has no closing </EML>: truncated or not a VEC set-up file")

dir.create(file.path(out_dir, "raw"), recursive = TRUE, showWarnings = FALSE)
md5 <- unname(tools::md5sum(f))
raw_path <- file.path(out_dir, "raw", sprintf("%s.%s.xml", tools::file_path_sans_ext(basename(f)), substr(md5, 1, 8)))
if (!file.exists(raw_path) && !file.copy(f, raw_path)) stop("VC2! could not copy the raw file to ", raw_path)
cat(sprintf("VC2  raw copy: %s (md5 %s)\n", raw_path, md5))

doc <- read_xml(f)
lname <- function(node, path) xml_text(xml_find_first(node, path))
el <- xml_find_all(doc, "//*[local-name()='Election']")
eid <- vapply(el, function(e) xml_attr(xml_find_first(e, "*[local-name()='ElectionIdentifier']"), "Id"), "")
cat(sprintf("VC3  elections in file: %s (Lower House is Id L)\n", paste(eid, collapse = ", ")))
if (sum(eid == "L") != 1L) stop("VC3! expected exactly one Lower House election (Id L), found ", sum(eid == "L"))
lh <- el[[which(eid == "L")]]
event <- xml_text(xml_find_first(doc, "//*[local-name()='EventName']"))
contests <- xml_find_all(lh, ".//*[local-name()='Contest']")
rows <- rbindlist(lapply(contests, function(ct) {
  cn <- lname(ct, "*[local-name()='ContestIdentifier']/*[local-name()='ContestName']")
  cands <- xml_find_all(ct, "*[local-name()='Candidate']")
  if (!length(cands)) return(data.table(contest_name = cn, candidate_id = NA_character_))
  data.table(
    contest_id = xml_attr(xml_find_first(ct, "*[local-name()='ContestIdentifier']"), "Id"),
    contest_name = cn,
    polling_district_id = xml_attr(xml_find_first(ct, "*[local-name()='PollingDistrictIdentifier']"), "Id"),
    enrolment = as.integer(lname(ct, "*[local-name()='Enrolment']")),
    candidate_id = vapply(cands, function(c) xml_attr(xml_find_first(c, "*[local-name()='CandidateIdentifier']"), "Id"), ""),
    name = vapply(cands, function(c) lname(c, "*[local-name()='CandidateIdentifier']/*[local-name()='CandidateName']"), ""),
    independent = vapply(cands, function(c) xml_attr(c, "Independent"), ""),
    affiliation_id = vapply(cands, function(c) xml_attr(xml_find_first(c, ".//*[local-name()='AffiliationIdentifier']"), "Id"), ""),
    registered_name = vapply(cands, function(c) lname(c, ".//*[local-name()='AffiliationIdentifier']/*[local-name()='RegisteredName']"), ""),
    ballot_position = as.integer(vapply(cands, function(c) lname(c, "*[local-name()='BallotPosition']"), "")),
    elected_historic = vapply(cands, function(c) xml_attr(xml_find_first(c, "*[local-name()='Elected']"), "Historic"), ""))
}), fill = TRUE)
rows[, district := trimws(sub("\\s+District$", "", contest_name))]
rows[, `:=`(event = event, year = as.integer(yr), source_file = basename(f), source_md5 = md5)]

# ---- checks: say what is wrong, never write a partial list ------------------------------------------------------
nd <- uniqueN(rows$district)
cat(sprintf("VC4  %s: %d Lower House candidates in %d districts\n", event, sum(!is.na(rows$candidate_id)), nd))
empty <- rows[is.na(candidate_id), district]
if (length(empty)) stop("VC4! districts with no candidate: ", paste(empty, collapse = ", "))
if (nd != 88) stop("VC4! ", nd, " districts, Victoria has 88: a partial or wrong file")
if (anyNA(rows$name) || any(!nzchar(rows$name))) stop("VC5! candidates with no name")
if (!all(grepl(",", rows$name))) stop("VC5! names not in 'SURNAME, Given' form: ", paste(head(rows$name[!grepl(",", rows$name)], 5), collapse = "; "))
if (!all(rows$independent %in% c("yes", "no"))) stop("VC6! Independent attribute not yes/no: ", paste(unique(rows$independent), collapse = ", "))
bad_aff <- rows[independent == "no" & (is.na(registered_name) | !nzchar(registered_name))]
if (nrow(bad_aff)) stop("VC6! ", nrow(bad_aff), " party candidate(s) with no registered party name")
if (anyDuplicated(rows$candidate_id)) stop("VC7! duplicate candidate ids")
# build_candidacies.R keys a person on seat + surname + first initial (BC11 stops on a duplicate), so say it here, on
# fetch day, rather than at the build
.pk <- paste(tolower(rows$district), gsub("[^a-z]", "", tolower(sub(",.*$", "", rows$name))),
             substr(gsub("[^a-z]", "", tolower(sub("^[^,]*,", "", rows$name))), 1, 1))
if (anyDuplicated(.pk)) stop("VC7! two candidates in one district share surname and first initial: ",
                             paste(rows$district[duplicated(.pk) | duplicated(.pk, fromLast = TRUE)], rows$name[duplicated(.pk) | duplicated(.pk, fromLast = TRUE)], collapse = "; "),
                             " -- build_candidacies.R's person key needs a second given-name letter for them")
pos <- rows[, list(ok = identical(sort(ballot_position), seq_len(.N))), by = district]
if (!all(pos$ok)) stop("VC7! ballot positions not 1..n in: ", paste(pos[ok == FALSE, district], collapse = ", "))
cat(sprintf("VC8  %d independents; parties: %s\n", sum(rows$independent == "yes"),
            paste(sprintf("%s %d", names(sort(table(rows$registered_name), decreasing = TRUE)), sort(table(rows$registered_name), decreasing = TRUE)), collapse = "; ")))

setcolorder(rows, c("year", "district", "ballot_position", "name", "independent", "registered_name", "affiliation_id",
                    "candidate_id", "contest_id", "contest_name", "polling_district_id", "enrolment", "elected_historic",
                    "event", "source_file", "source_md5"))
setorder(rows, district, ballot_position)
out <- file.path(out_dir, sprintf("vec-candidates-%s.csv", yr))
tmp <- paste0(out, ".tmp"); fwrite(rows, tmp)
back <- fread(tmp, showProgress = FALSE)
if (nrow(back) != nrow(rows)) stop("VC9! read-back has ", nrow(back), " rows, wrote ", nrow(rows))
if (!file.rename(tmp, out)) stop("VC9! could not move ", tmp, " to ", out)
cat(sprintf("VC9  wrote %s (%d rows)\n", out, nrow(rows)))

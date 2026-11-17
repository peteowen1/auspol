# Turn a VEC results website snapshot into the results file scripts/score_benchmarks_vic2026.R reads.
#
#   Rscript scripts/build_vec_results_2026.R --source=<snapshot root> [--out=output/vec-results-2026.csv]
#   Rscript scripts/build_vec_results_2026.R --snap=<one snapshot folder> [--out=...]
#
# Snapshots come from scripts/fetch_vec_web_snapshot.R (one first-preference and one two-candidate page per district,
# manifest.csv, DONE). With --source the newest folder holding DONE is read (night_web_latest()).
#
# Each district's winner is the "Elected member" block the VEC prints on its results pages once it declares the
# district (vec_web_elected()). Both pages are read; when both name a member they must agree (VRS3!). A district whose
# pages name nobody is written `status = pending` with a blank winner: the scorer holds it out, never guesses it.
# The elected name must be one of that district's 2026 candidates (VRS4!), so a page from the wrong district or a
# stale page cannot score.
#
# Output columns: district, winner (party as the VEC prints it; "Independent" for a blank party), status
# (declared / pending), elected (the name), page (which page named them). Then:
#   Rscript scripts/score_benchmarks_vic2026.R --results=output/vec-results-2026.csv
# Check codes VRS1-VRS6.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
snap <- flag("snap")
if (is.null(snap)) {
  src <- flag("source"); if (is.null(src)) stop("VRS1! give --source=<snapshot root> or --snap=<snapshot folder>")
  snap <- night_web_latest(src); if (is.na(snap)) stop("VRS1! no complete snapshot (folder with DONE) under ", src)
}
out <- flag("out", "output/vec-results-2026.csv")
cands_file <- flag("candidates", "external/reference/vec/2026/vec-candidates-2026.csv")
N_DISTRICTS <- 88L

mf <- file.path(snap, "manifest.csv")
if (!file.exists(mf)) stop("VRS1! no manifest.csv in ", snap)
m <- fread(mf, showProgress = FALSE)
cat(sprintf("VRS1 snapshot %s: %d districts in the manifest\n", snap, nrow(m)))
if (nrow(m) != N_DISTRICTS || anyDuplicated(m$district))
  stop(sprintf("VRS1! the manifest must name %d districts once each (has %d rows, %d unique)", N_DISTRICTS, nrow(m), uniqueN(m$district)))

cands <- fread(cands_file, showProgress = FALSE)
cands[, district := sub(" District$", "", district)]
norm <- function(x) toupper(gsub("[^A-Za-z]", "", x))
if (!all(m$district %in% cands$district))
  stop("VRS2! districts in the manifest but not in ", cands_file, ": ", paste(setdiff(m$district, cands$district), collapse = ", "))

rows <- lapply(seq_len(nrow(m)), function(i) {
  d <- m$district[i]
  e_tcp <- vec_web_elected(file.path(snap, m$tcp[i]))
  e_fp  <- vec_web_elected(file.path(snap, m$fp[i]))
  if (!is.na(e_tcp$name) && !is.na(e_fp$name) && norm(e_tcp$name) != norm(e_fp$name))
    stop(sprintf("VRS3! %s: the two pages name different members (2CP %s, first preferences %s)", d, e_tcp$name, e_fp$name))
  e <- if (!is.na(e_tcp$name)) e_tcp else e_fp
  page <- if (!is.na(e_tcp$name)) "2cp" else if (!is.na(e_fp$name)) "fp" else NA_character_
  if (!is.na(e$name)) {
    dist_now <- d
    dcand <- cands[district == dist_now]
    hit <- match(norm(e$name), norm(dcand$name))
    if (is.na(hit))
      stop(sprintf("VRS4! %s: elected member '%s' is not one of the district's %d candidates", d, e$name, nrow(dcand)))
    # a blank party on the page reads as "Independent"; the candidate list must agree, or a layout change that drops
    # the party would score a party member as IND without a word
    if (identical(e$party, "Independent") && !identical(tolower(dcand$independent[hit]), "yes"))
      stop(sprintf("VRS4! %s: the page gives '%s' no party, but the candidate list has them standing for '%s'",
                   d, e$name, dcand$registered_name[hit]))
  }
  data.table(district = d, winner = if (is.na(e$party)) "" else e$party,
             status = if (is.na(e$name)) "pending" else "declared", elected = if (is.na(e$name)) "" else e$name, page = page)
})
res <- rbindlist(rows)[order(district)]

dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
fwrite(res, out)
nd <- sum(res$status == "declared")
cat(sprintf("VRS5 %d of %d declared, %d pending -> %s\n", nd, nrow(res), nrow(res) - nd, out))
if (nd) {
  tab <- res[status == "declared", .N, by = winner][order(-N)]
  cat("VRS5 declared winners by party as printed:", paste(sprintf("%s %d", tab$winner, tab$N), collapse = ", "), "\n")
}
if (nd < nrow(res)) cat("VRS6 pending:", paste(res[status == "pending", district], collapse = ", "), "\n")

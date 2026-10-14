# AUSPOL_POLL_ARCHIVE measurement (2026-10-14): (1) switch off = the pre-change load_polls() for every region,
# (2) polls carrying AE's numbers per election, off vs on, (3) archive polls disagreeing with AE's copy by > 1 point.
# Run: powershell.exe -Command 'Rscript "scripts/measure_poll_archive.R"'
suppressMessages(devtools::load_all(quiet = TRUE))
regions <- c("fed", "nsw", "vic", "qld", "wa", "sa", "nt")
Sys.setenv(AUSPOL_POLL_ARCHIVE = "0")
quiet <- function(e) suppressMessages(e)
new_off <- lapply(setNames(regions, regions), function(r) quiet(load_polls(r)))
# the HEAD version of the layer code, sourced over the namespace
old_src <- tempfile(fileext = ".R")
system2("git", c("show", "HEAD:R/poll_source.R"), stdout = old_src)
ns <- asNamespace("auspol")
writeLines(grep("^\\.ps_memo <-", readLines(old_src), value = TRUE, invert = TRUE), old_src)   # locked binding
for (e in parse(old_src)) { f <- eval(e[[3]], ns); nm <- as.character(e[[2]]); unlockBinding(nm, ns); assign(nm, f, ns) }
old <- lapply(setNames(regions, regions), function(r) quiet(load_polls(r)))
cat("== off = HEAD code (identical() incl. attributes), per region\n")
for (r in regions) cat(sprintf("  %-4s identical=%s  rows=%d\n", r, isTRUE(all.equal(new_off[[r]], old[[r]], check.attributes = TRUE)) && identical(new_off[[r]], old[[r]]), nrow(old[[r]])))
devtools::load_all(quiet = TRUE)   # back to the working tree

windows <- list(fed2007 = c("2004-10-10", "2007-11-23"), fed2010 = c("2007-11-25", "2010-08-20"))
Sys.setenv(AUSPOL_POLL_ARCHIVE = "1")
on <- quiet(load_polls("fed"))
Sys.setenv(AUSPOL_POLL_ARCHIVE = "0"); off <- quiet(load_polls("fed"))
po <- attr(on, "provenance"); pf <- attr(off, "provenance")
cat("\n== fed: rows by whose numbers they carry (origin), off vs on\n")
for (w in names(windows)) {
  d <- as.Date(windows[[w]])
  a <- table(pf$origin[pf$date >= d[1] & pf$date <= d[2]]); b <- table(po$origin[po$date >= d[1] & po$date <= d[2]])
  cat(sprintf("%s  off: %s\n        on: %s\n", w, paste(names(a), a, collapse = ", "), paste(names(b), b, collapse = ", ")))
}
cat("\n== other regions: switch on changes nothing?\n")
for (r in setdiff(regions, "fed")) cat(sprintf("  %-4s identical=%s\n", r, identical(quiet(load_polls(r)), new_off[[r]])))
Sys.setenv(AUSPOL_POLL_ARCHIVE = "0")

# disagreements with AE's copy
ae <- quiet({ Sys.setenv(AUSPOL_POLL_SOURCE = "ae"); x <- load_polls("fed"); Sys.setenv(AUSPOL_POLL_SOURCE = "layered"); x })
parties <- attr(ae, "parties")
arch <- archive_polls("fed", parties, file.path(pkg_root(), "external", "reference", "polls", "archive", "fed_archive_polls.csv"))
alias <- data.table::fread(file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "firm_alias.csv"))
ae$canon <- auspol:::.ps_canon(ae$firm, alias); arch$canon <- auspol:::.ps_canon(arch$firm_raw, alias)
cand <- auspol:::.ps_pair_candidates(arch, ae, 4L)
data.table::setnames(cand, c("ai", "d_a", "bi", "d_b"), c("ri", "d_r", "ei", "d_e"))
num <- abs(arch$ALP[cand$ri] - ae$ALP[cand$ei]) + abs(arch$LNP[cand$ri] - ae$LNP[cand$ei])
cand$score <- abs(as.integer(cand$d_r - cand$d_e)) + ifelse(is.finite(num), num, 50) / 2
data.table::setorderv(cand, "score")
ur <- logical(nrow(arch)); ue <- logical(nrow(ae)); pr <- integer(0); pe <- integer(0)
for (k in seq_len(nrow(cand))) { r <- cand$ri[k]; e <- cand$ei[k]; if (ur[r] || ue[e]) next; ur[r] <- ue[e] <- TRUE; pr <- c(pr, r); pe <- c(pe, e) }
cmp <- data.table::data.table(firm = arch$firm_raw[pr], arch_mid = arch$date[pr], arch_end = arch$end[pr], ae_date = ae$date[pe], ae_firm = ae$firm[pe],
  dALP = round(arch$ALP[pr] - ae$ALP[pe], 1), dLNP = round(arch$LNP[pr] - ae$LNP[pe], 1), dGRN = round(arch$GRN[pr] - ae$GRN[pe], 1),
  arch_ALP = arch$ALP[pr], ae_ALP = ae$ALP[pe], arch_LNP = arch$LNP[pr], ae_LNP = ae$LNP[pe], arch_tpp = arch$tpp_published[pr], ae_tpp = ae$tpp_published[pe])
cmp$gt1 <- (abs(cmp$dALP) > 1 | abs(cmp$dLNP) > 1) & !is.na(cmp$dALP + cmp$dLNP)
cat(sprintf("\n== archive vs AE: %d archive polls (Morgan %d, Newspoll %d); matched to an AE poll %d; archive-only %d; AE polls in the archive's window unmatched %d\n",
  nrow(arch), sum(arch$canon == "roymorgan"), sum(arch$canon == "newspoll"), length(pr), sum(!ur),
  sum(!ue & ae$date >= min(arch$date) - 4 & ae$date <= max(arch$date) + 4 & ae$canon %in% c("roymorgan", "newspoll"))))
cat(sprintf("   matched pairs differing by > 1 point on Labor or Coalition: %d\n", sum(cmp$gt1)))
cat("   by firm (matched / differ):\n"); print(cmp[, .(matched = .N, differ_gt1 = sum(gt1), median_abs_dALP = median(abs(dALP), na.rm = TRUE)), by = .(firm)])
data.table::fwrite(cmp, file.path(pkg_root(), "external", "reference", "polls", "archive", "archive_vs_ae_pairs.csv"))
print(cmp[gt1 == TRUE][order(arch_mid)], nrow = 200)
unm <- arch[!ur, .(date, end, firm_raw, ALP, LNP)]
cat("\n== archive polls with no AE match\n"); print(unm, nrow = 200)
aeun <- ae[!ue & date >= min(arch$date) - 4 & date <= max(arch$date) + 4 & canon %in% c("roymorgan", "newspoll"), .(date, firm, ALP, LNP)]
cat("\n== AE Morgan/Newspoll polls with no archive match\n"); print(aeun, nrow = 300)

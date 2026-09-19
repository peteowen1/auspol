# THE AEF-7 LEDGER AS ONE HTML FILE. Rebuild stage 8, after
# build_aef7_ledger_data.R: substitutes the two JSON files into the template
# and writes output/aef7-ledger.html, which publish_shipped_release.R uploads
# to the shipped-models release so the comparison is public and always
# describes the models that ship. Until 2026-09-19 this lived in a scratchpad
# script and the ledger was only ever a claude.ai artifact.
options(auspol.root = normalizePath("."))
TPL <- "scripts/templates/aef7-ledger.template.html"
SEATS <- "output/aef7-ledger-data.json"; SUMM <- "output/aef7-ledger-summary.json"
for (f in c(TPL, SEATS, SUMM)) if (!file.exists(f)) stop("LH0! missing ", f, " -- run scripts/build_aef7_ledger_data.R first")
rd <- function(f) readChar(f, file.size(f), useBytes = TRUE)
tpl <- rd(TPL); s <- rd(SEATS); u <- rd(SUMM)
# the data must be newer than the template's inputs' vintage check upstream;
# here only sanity: both parse as JSON with the expected top-level shape
js <- jsonlite::fromJSON(s, simplifyVector = FALSE); ju <- jsonlite::fromJSON(u, simplifyVector = FALSE)
if (!length(js)) stop("LH0! ", SEATS, " is empty")
stopifnot(grepl("= __SEATS_JSON__;", tpl, fixed = TRUE), grepl("= __SUMMARY_JSON__;", tpl, fixed = TRUE))
out <- sub("= __SEATS_JSON__;", paste0("= ", s, ";"), tpl, fixed = TRUE)
out <- sub("= __SUMMARY_JSON__;", paste0("= ", u, ";"), out, fixed = TRUE)
if (grepl("= __SEATS_JSON__;|= __SUMMARY_JSON__;", out)) stop("LH0! placeholder survived substitution")
OUT <- "output/aef7-ledger.html"
writeChar(out, OUT, eos = NULL, useBytes = TRUE)
cat(sprintf("LH1  wrote %s (%.0f KB): %d seat rows, summary keys %s\n", OUT, file.size(OUT) / 1024,
            length(js), paste(head(names(ju), 6), collapse = ",")))

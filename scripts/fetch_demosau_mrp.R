#!/usr/bin/env Rscript
# Fetch DemosAU federal MRP report PDFs into external/reference/polls/demosau/raw/mrp/.
# STATUS 2026-10-13: demosau.com returned HTTP 403 to every request from this
# machine (article, PDF and home page, two user agents), so nothing is on disk
# and NO PARSER EXISTS yet (a parser written without the PDF would be a guess).
# See docs/reviews/demosau-mrp-2026-10-13.md. This script fetches only what is
# missing, checks the %PDF magic bytes and page count, and stops on 403.
suppressPackageStartupMessages(library(pdftools))
raw_dir <- "external/reference/polls/demosau/raw/mrp"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
ua <- "auspol-research/1.0 (non-commercial election forecasting research)"
pdfs <- c(
  "mrp-2026-08-09" = "https://demosau.com/wp-content/uploads/2026/10/DemosAU-Report-Aug-Sept-2026-MRP-Model-1.pdf"
  # earlier MRP report URLs: add here once found on demosau.com/news
)
for (key in names(pdfs)) {
  f <- file.path(raw_dir, paste0(key, ".pdf"))
  if (file.exists(f) && identical(readBin(f, "raw", 5L), charToRaw("%PDF-"))) {
    message("SKIP (on disk): ", key); next
  }
  h <- curl::new_handle(useragent = ua, followlocation = TRUE)
  res <- tryCatch(curl::curl_fetch_disk(pdfs[[key]], f, h), error = function(e) NULL)
  if (is.null(res) || res$status_code != 200L ||
      !identical(readBin(f, "raw", 5L), charToRaw("%PDF-"))) {
    if (file.exists(f)) file.remove(f)
    stop("BLOCKED or not a PDF (HTTP ", if (is.null(res)) "error" else res$status_code,
         "): ", key, " -- do not work around; fetch in a browser.")
  }
  message(key, ": ", pdf_info(f)$pages, " pages")
  Sys.sleep(1)
}

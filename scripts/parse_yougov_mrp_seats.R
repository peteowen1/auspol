#!/usr/bin/env Rscript
# YouGov's Victorian MRP (for Common Threads, fieldwork 16 Jun - 10 Jul 2026, n 4,003): every column of the
# per-seat table, read by word POSITION with pdftools::pdf_data(). pdftotext -layout floats some figures onto
# the lines above and below (Dandenong summed to 110 that way), which is why scripts/parse_yougov.py kept only
# winner and margin. docs/plans/prereg-mrp-seat-pattern-2026-11-23.md.
#
#   curl -sL -o external/reference/yougov-vic-mrp-2026.pdf \
#     https://actionnetwork.org/user_files/user_files/000/146/615/original/yougov-vic-mrp-treaty-report-state-voting-intetion-treaty-support.pdf
#   Rscript scripts/parse_yougov_mrp_seats.R [--selftest]
#
# Writes (both under external/, GITIGNORED: YouGov's numbers are not committed to this public repo):
#   external/reference/polls/seat-polls/raw/sources/yougov-vic-mrp-2026-07-full.csv   every column as published
#   external/reference/polls/seat-polls/mrp_extra.csv   seat-poll rows (seat_polls.csv columns) the blend reads
# Stops unless: 88 seats, unique names, every row's seven primaries sum to 100 +/- 2, the seat means sit within
# 2.5 points of the published headline (ALP 23, Coalition 26, GRN 13, ONP 24), every seat name matches a
# vic2026 district, and the winner column agrees with the earlier extract (external/reference/yougov-seats.csv).
# --selftest shifts one figure by 10 points and must be refused. Prints YGM codes.
suppressMessages({ library(pdftools); library(data.table) })
args <- commandArgs(TRUE)
pdf <- "external/reference/yougov-vic-mrp-2026.pdf"
if (!file.exists(pdf)) stop("Missing ", pdf, " -- fetch it with the curl line in this script's header")
pages <- which(grepl("Detailed MRP projection of results in each seat", pdf_text(pdf)))
cat(sprintf("YGM0 %s: %d pages; seat table on pages %s\n", pdf, pdf_info(pdf)$pages, paste(pages, collapse = ", ")))
if (length(pages) != 4L) stop("expected the seat table on 4 pages, found ", length(pages))

# column x-centres from the header words, read from the first table page (all four share the layout)
num_cols <- c(alp = "Labor", coalition = "Coalition", grn = "Greens", onp = "One", ind = "Independent",
              oth_left = "Other", oth_right = "Other")
rows <- rbindlist(lapply(pages, function(pg) {
  d <- as.data.table(pdf_data(pdf)[[pg]])
  hdr <- d[d$y > 120 & d$y < 160]
  other_x <- sort(hdr$x[hdr$text == "Other"])
  cx <- c(alp = hdr$x[hdr$text == "Labor"][1], coalition = hdr$x[hdr$text == "Coalition"][1],
          grn = hdr$x[hdr$text == "Greens"][1], onp = hdr$x[hdr$text == "One"][1],
          ind = hdr$x[hdr$text == "Independent"][1], oth_left = other_x[1], oth_right = other_x[2])
  if (anyNA(cx) || length(other_x) != 2L) stop("page ", pg, ": header columns not found")
  tx <- c(winner_2022 = hdr$x[hdr$text == "2022"][1], status = hdr$x[hdr$text == "Seat"][1])
  # the three "2026" header words start the projected winner, runner-up and winner's 2pp % columns; cells sit up
  # to ~5 points left of their header, status words up to ~15
  pj <- sort(d$x[d$text == "2026" & d$y > 120 & d$y < 160]) - 7
  if (length(pj) != 3L) stop("page ", pg, ": expected three '2026' header words, found ", length(pj))
  tx[["status"]] <- tx[["status"]] - 10
  body <- d[d$y >= 170]
  # one row per line of FIGURES (fixed y-bands split rows on a band edge; anchoring on the name loses two-line
  # names such as "Narre Warren / North", whose figures sit between the two name lines). Figures: words within 3
  # points of the line; name: left-column words within 8 points, read top to bottom (rows are ~15 points apart).
  is_pct <- grepl("^[0-9]+(\\.[0-9]+)?%$", body$text) & body$x < tx[["winner_2022"]] - 5
  anchors <- sort(unique(body$y[is_pct]))
  anchors <- anchors[c(TRUE, diff(anchors) > 3)]
  out <- list()
  for (y0 in anchors) {
    w <- body[abs(body$y - y0) <= 3]
    w <- w[order(w$x)]
    pct <- w[grepl("^[0-9]+(\\.[0-9]+)?%$", w$text) & w$x < tx[["winner_2022"]] - 5]
    if (nrow(pct) < 3) next
    nw <- body[abs(body$y - y0) <= 8 & body$x < cx[["alp"]] - 5]
    nw <- nw[order(nw$y, nw$x)]
    name <- paste(nw$text, collapse = " ")
    v <- setNames(rep(NA_real_, 7), names(cx))
    for (k in seq_len(nrow(pct))) {
      j <- names(cx)[which.min(abs(cx - pct$x[k]))]
      if (!is.na(v[[j]])) stop("page ", pg, " '", name, "': two figures fall in column ", j)
      v[[j]] <- as.numeric(sub("%", "", pct$text[k]))
    }
    rest <- w[w$x >= tx[["winner_2022"]] - 5]
    grab <- function(lo, hi) paste(rest$text[rest$x >= lo & rest$x < hi], collapse = " ")
    out[[length(out) + 1L]] <- data.table(page = pg, seat = name, t(v),
      winner_2022 = grab(tx[["winner_2022"]] - 5, pj[1]), proj_winner = grab(pj[1], pj[2]),
      proj_runner_up = grab(pj[2], pj[3]), winner_2pp = grab(pj[3], tx[["status"]]),
      seat_status = grab(tx[["status"]], Inf))
  }
  rbindlist(out)
}))
setnames(rows, names(num_cols), names(num_cols))
for (j in names(num_cols)) rows[[j]][is.na(rows[[j]])] <- 0   # a blank cell is printed as no figure: 0%
rows$winner_2pp <- as.numeric(sub("%", "", rows$winner_2pp))
txt_bad <- rows$seat[!is.finite(rows$winner_2pp) | !nzchar(rows$proj_winner) | !nzchar(rows$proj_runner_up) | !nzchar(rows$seat_status)]
if (length(txt_bad)) stop("YGM5! text columns not read for: ", paste(txt_bad, collapse = ", "))
cat(sprintf("YGM5 text columns read for all rows; projected winners: %s\n",
            paste(sprintf("%s %d", names(table(rows$proj_winner)), as.integer(table(rows$proj_winner))), collapse = ", ")))

check <- function(r) {
  bad <- character(0)
  tot <- rowSums(as.matrix(r[, names(num_cols), with = FALSE]))
  if (nrow(r) != 88L) bad <- c(bad, sprintf("%d seats, not 88 (rows read: %s)", nrow(r), paste(sort(r$seat), collapse = ", ")))
  if (anyDuplicated(r$seat)) bad <- c(bad, paste("duplicate seat names:", paste(r$seat[duplicated(r$seat)], collapse = ", ")))
  off <- which(abs(tot - 100) > 2)
  if (length(off)) bad <- c(bad, paste("primaries not summing to 100 +/- 2:", paste(sprintf("%s %.0f", r$seat[off], tot[off]), collapse = ", ")))
  head <- c(alp = 23, coalition = 26, grn = 13, onp = 24)
  m <- colMeans(r[, names(head), with = FALSE])
  far <- names(head)[abs(m - head) > 2.5]
  if (length(far)) bad <- c(bad, paste("seat means far from the headline:", paste(sprintf("%s %.1f vs %d", far, m[far], head[far]), collapse = ", ")))
  list(bad = bad, tot = tot, means = m)
}
if ("--selftest" %in% args) {
  broken <- copy(rows); broken$alp[5] <- broken$alp[5] + 10
  if (!length(check(broken)$bad)) stop("YGM9! self-test: a row shifted by 10 points PASSED the checks")
  cat(sprintf("YGM9 self-test: shifted row refused (%s)\n", check(broken)$bad[1]))
}
ck <- check(rows)
cat(sprintf("YGM1 %d seats; primary totals %.0f-%.0f; seat means ALP %.1f, Coalition %.1f, GRN %.1f, ONP %.1f, IND %.1f, other left %.1f, other right %.1f\n",
            nrow(rows), min(ck$tot), max(ck$tot), mean(rows$alp), mean(rows$coalition), mean(rows$grn), mean(rows$onp),
            mean(rows$ind), mean(rows$oth_left), mean(rows$oth_right)))
if (length(ck$bad)) stop("YGM1! ", paste(ck$bad, collapse = " | "))

# seat names against our vic2026 districts
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
ours <- unique(fread("output/candidacies.csv", showProgress = FALSE)[election == "vic2026"]$seat)
miss <- rows$seat[!normalise_seat(rows$seat) %in% normalise_seat(ours)]
if (length(ours) != 88L || length(miss)) stop("YGM2! seat names not matching vic2026 (", length(ours), " districts): ", paste(miss, collapse = ", "))
cat("YGM2 all 88 seat names match vic2026 districts\n")
# the earlier winner-only extract (parse_yougov.py) as an independent second reading
if (file.exists("external/reference/yougov-seats.csv")) {
  old <- fread("external/reference/yougov-seats.csv")
  m <- merge(rows[, list(k = normalise_seat(seat), proj_winner)], old[, list(k = normalise_seat(seat), winner)], by = "k")
  dis <- m[m$proj_winner != m$winner]
  cat(sprintf("YGM3 winner agrees with yougov-seats.csv in %d of %d matched seats%s\n", nrow(m) - nrow(dis), nrow(m),
              if (nrow(dis)) paste0(": DISAGREE ", paste(dis$k, dis$proj_winner, dis$winner, collapse = "; ")) else ""))
  if (nrow(dis)) stop("YGM3! the two extracts disagree on the projected winner")
}

src_dir <- "external/reference/polls/seat-polls/raw/sources"
dir.create(src_dir, recursive = TRUE, showWarnings = FALSE)
fwrite(rows, file.path(src_dir, "yougov-vic-mrp-2026-07-full.csv"))
src <- "https://actionnetwork.org/user_files/user_files/000/146/615/original/yougov-vic-mrp-treaty-report-state-voting-intetion-treaty-support.pdf"
party <- c(alp = "ALP", coalition = "L/NP", grn = "GRN", onp = "ONP", ind = "IND", oth_left = "OTH", oth_right = "OTH")
long <- rbindlist(lapply(names(party), function(j) data.table(
  election = "vic2026", seat = rows$seat, pollster = "YouGov (MRP)", client = "Common Threads",
  fieldwork_start = "2026-06-16", fieldwork_end = "2026-07-10", date_raw = "16 Jun – 10 Jul 2026", published = "2026-08-06",
  sample_n = 4003L, party = party[[j]], fp = rows[[j]], tcp_party_a = NA_character_, tcp_party_b = NA_character_,
  tcp_a = NA_real_, source_url = src, row_type = "poll", seat_name = rows$seat)))
# the two "other" columns are one catch-all to the blend: summed, so a poll carries one OTH row per seat
long <- long[, list(fp = sum(fp)), by = setdiff(names(long), "fp")]
# A 0 for a party the model expects to stand is not a measurement: Labor did not contest the 2022 Narracan
# supplementary election, so the MRP (built on 2022 results) prints Labor 0% there. Dropped and listed.
zero <- long$party %in% c("ALP", "L/NP", "GRN", "ONP") & long$fp == 0
cat(sprintf("YGM6 %d zero cell(s) for a major party dropped: %s\n", sum(zero), paste(long$seat[zero], long$party[zero], collapse = "; ")))
long <- long[!zero]
setcolorder(long, c("election", "seat", "pollster", "client", "fieldwork_start", "fieldwork_end", "date_raw", "published",
                    "sample_n", "party", "fp", "tcp_party_a", "tcp_party_b", "tcp_a", "source_url", "row_type", "seat_name"))
fwrite(long, "external/reference/polls/seat-polls/mrp_extra.csv")
cat(sprintf("YGM4 wrote %d seat-poll rows (%d seats x %d parties) to external/reference/polls/seat-polls/mrp_extra.csv and the full table beside the PDF sources\n",
            nrow(long), uniqueN(long$seat), uniqueN(long$party)))

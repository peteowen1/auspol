# List seat polls whose primaries contradict their own two-party pairing (no model change; codes TCC0-TCC2).
#   Rscript scripts/check_seat_poll_tcp_consistency.R
# A poll's leading party on first preferences must be one of the two parties in its published two-party figure:
# the primary leader all but always makes the final two, and a row with figures in the wrong columns fails at once
# (Wikipedia's RedBridge Melbourne Nov 2024: LIB 44 leads, its own 2CP is GRN 55 v ALP 45; Accent's PDF has GRN 44).
# Also reported: primaries that do not sum to 95-105. Corrections in seat_poll_corrections.csv are applied first.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
f <- file.path("external", "reference", "polls", "seat-polls", "seat_polls.csv")
s <- NULL; invisible(capture.output(s <- .read_seat_polls_file_impl(f)))
s <- as.data.table(s)[row_type == "poll"]
s[, fpn := suppressWarnings(as.numeric(fp))]
p <- toupper(trimws(s$party))
s[, cls := ifelse(p == "ALP", "ALP", ifelse(p %in% c("LIB", "NAT", "LNP", "L/NP", "CLP"), "LNP", ifelse(p == "GRN", "GRN",
           ifelse(p %in% c("ON", "ONP"), "ONP", ifelse(p == "IND" | grepl("[(]IND[)]$", p), "IND", ifelse(p %in% c("UAP", "KAP"), "OTH_RIGHT", "OTH"))))))]
norm_tcp <- function(x) { x <- toupper(trimws(x)); ifelse(x %in% c("LIB", "NAT", "LNP", "L/NP", "CLP"), "LNP", ifelse(x %in% c("ON", "ONP"), "ONP", x)) }
s[, poll_key := paste(election, seat_name, pollster, fieldwork_end)]
P <- s[is.finite(fpn), .(n_rows = .N, total = sum(fpn), lead = cls[cls != "OTH"][which.max(fpn[cls != "OTH"])],
                         lead_fp = max(fpn[cls != "OTH"]), tcp_a = norm_tcp(tcp_party_a[1]), tcp_b = norm_tcp(tcp_party_b[1]),
                         prims = paste(sprintf("%s %s", party, fp), collapse = ", ")), by = .(poll_key, election, seat_name, pollster)]
cat(sprintf("TCC0 %d polls with primaries; %d carry a two-party pairing\n", nrow(P), sum(nzchar(P$tcp_a) & nzchar(P$tcp_b))))
# row by row: `lead %in% c(tcp_a, tcp_b)` compares each leader with EVERY poll's pairing and passed everything
# (caught by running this with the Melbourne correction off, 2026-10-18)
bad_tcp <- P[nzchar(tcp_a) & nzchar(tcp_b) & lead != tcp_a & lead != tcp_b]
cat(sprintf("TCC1 primary leader is NOT in the poll's own two-party pairing: %d poll(s)\n", nrow(bad_tcp)))
if (nrow(bad_tcp)) print(bad_tcp[, .(election, seat_name, pollster, lead, lead_fp, tcp = paste(tcp_a, "v", tcp_b), prims)], nrows = 200)
bad_sum <- P[n_rows >= 3 & (total < 95 | total > 105)]
cat(sprintf("TCC2 primaries summing outside 95-105: %d poll(s)\n", nrow(bad_sum)))
if (nrow(bad_sum)) print(bad_sum[, .(election, seat_name, pollster, total = round(total, 1), prims)], nrows = 60)
# REPORT ONLY (2026-10-18): over 1,017 polls with a pairing the rule flagged 6; one was a real error (Melbourne RedBridge
# Nov 2024, now in seat_poll_corrections.csv) and the rest legitimate: three-way contests (Brisbane 2025 YouGov), an
# independent inside a poll's OTH (Clark, Fowler RedBridge), a candidate-named pairing label (Mount Gambier
# "FATCHEN(IND)"), a one-figure row (Goldstein uComms). So it never drops a poll: check each flag against its source.

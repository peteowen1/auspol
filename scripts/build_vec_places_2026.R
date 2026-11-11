# 2026 voting centres by district, for the election-night website source's --places list (the centres a district's
# results page has not reported yet become zero-vote placeholders, i.e. uncounted units). Without it the night runner
# falls back to the 2022 reference table's booths (NW21), so centres closed since 2022 sit uncounted all night and new
# ones are never expected.
#
# Source: the VEC's "venues spreadsheet" linked from https://www.vec.vic.gov.au/voting/2026-state-election/voting-locations
# ("Information correct as at 7th Nov 8:00am"), saved raw as
# external/reference/vec/2026/voting-locations/raw-<stamp>/voting-locations.xlsx (11 Nov 2026). Re-download it before
# the night; the VEC says the list may change until voting starts (Change Log sheet).
#
#   Rscript scripts/build_vec_places_2026.R [<xlsx>]     (default: the newest raw-* folder)
#
# Writes, next to the raw folder:
#   places-2026.csv        election-day voting centres (sheet VCs): district, booth, joint, then every spreadsheet column
#   early-centres-2026.csv early voting centres (sheet EVCs), same shape
# `booth` is the spreadsheet's "Voting Location Name" without its joint-centre suffix: "St Kilda (JVC)" is reported as
# "St Kilda" on the results page (checked on the 2022 Albert Park page, which lists St Kilda, Southbank, South Melbourne
# Park and St Kilda Park, all joint centres in 2026). `joint` is "", "JVC" (this district is a guest at another
# district's venue) or "HJVC" (host).
# Checks (VPL1-VPL4): every sheet and column present; 88 districts; district+booth unique after the suffix comes off; the
# ordinary and early estimated-vote columns complete (a missing absent-vote estimate is printed, not fatal); and a printed match against the 2022 reference table's ordinary booths.
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
root <- "external/reference/vec/2026/voting-locations"
f <- if (length(a)) a[1] else tail(sort(Sys.glob(file.path(root, "raw-*", "voting-locations.xlsx"))), 1)
if (!length(f) || !file.exists(f)) stop("VPL1! no venues spreadsheet found under ", root, "/raw-*")
sheets <- readxl::excel_sheets(f)
if (!all(c("Definitions", "VCs", "EVCs") %in% sheets)) stop("VPL1! expected sheets Definitions, VCs, EVCs in ", f, "; found ", paste(sheets, collapse = ", "))
def <- unlist(readxl::read_excel(f, sheet = "Definitions", col_names = FALSE, .name_repair = "minimal")[, 1])
asof <- grep("^Information correct as at", def, value = TRUE)[1]
cat(sprintf("VPL1 %s: %s\n", f, if (is.na(asof)) "(no 'Information correct as at' line)" else asof))

read_sheet <- function(sh, est, est_opt = character(0)) {
  x <- as.data.table(readxl::read_excel(f, sheet = sh))
  need <- c("District", "Voting Location Name", est)
  if (!all(need %in% names(x))) stop("VPL1! sheet ", sh, " lacks ", paste(setdiff(need, names(x)), collapse = ", "))
  nm <- trimws(x[["Voting Location Name"]])
  jt <- sub("^.*\\((H?JE?VC)\\)\\s*$", "\\1", nm); jt[jt == nm] <- ""
  out <- data.table(district = sub(" District$", "", trimws(x[["District"]])), booth = trimws(sub("\\s*\\((H?JE?VC)\\)\\s*$", "", nm)), joint = jt)
  out <- cbind(out, x)   # every spreadsheet column kept, decided on later
  if (uniqueN(out$district) != 88L) stop("VPL2! sheet ", sh, ": ", uniqueN(out$district), " districts, expected 88")
  if (anyDuplicated(out[, .(district, booth)])) stop("VPL3! sheet ", sh, ": district+booth not unique once the joint suffix is removed: ",
                                                     paste(head(out[duplicated(out[, .(district, booth)]), paste(district, booth)], 5), collapse = "; "))
  for (e in est) if (anyNA(out[[e]])) stop("VPL3! sheet ", sh, ": ", sum(is.na(out[[e]])), " rows with no '", e, "'")
  for (e in est_opt) if (!e %in% names(out)) stop("VPL1! sheet ", sh, " lacks ", e) else if (anyNA(out[[e]]))
    cat(sprintf("VPL3 sheet %s: %d rows with no '%s' (kept as NA): %s\n", sh, sum(is.na(out[[e]])), e, paste(out[is.na(out[[e]]), paste(district, booth)], collapse = "; ")))
  cat(sprintf("VPL2 %s: %d centres in %d districts (%d joint-guest, %d host); %s %s\n", sh, nrow(out), uniqueN(out$district),
              sum(grepl("^J", out$joint)), sum(grepl("^H", out$joint)), paste(est, collapse = " + "),
              paste(format(vapply(est, function(e) sum(out[[e]]), numeric(1)), big.mark = ","), collapse = " + ")))
  out
}
vc <- read_sheet("VCs", "Est. Ord Votes", "Est. Absent Votes")   # 11 Nov: three small guest centres carry no absent estimate
ev <- read_sheet("EVCs", "Est. Early Votes")

# against the 2022 reference table (what the night runner uses without --places)
ref <- fread("output/booths-vic2026-ref.csv", showProgress = FALSE)
# district names compared letters-only, as the night runner does (.night_seat_names: the VEC's "South-West Coast")
dk <- function(v) gsub("[^a-z]", "", tolower(v))
rb <- unique(ref[booth_type == "ordinary" & nzchar(booth), .(dk = dk(district), booth)])
if (!setequal(dk(unique(vc$district)), unique(rb$dk))) stop("VPL4! districts differ from the reference table: ", paste(setdiff(dk(unique(vc$district)), unique(rb$dk)), collapse = ", "))
both <- merge(vc[, .(dk = dk(district), booth)], rb, by = c("dk", "booth"))
cat(sprintf("VPL4 2026 centres %d; also a 2022 reference booth %d; new since 2022 %d; 2022 booths not open in 2026 %d (of %d)\n",
            nrow(vc), nrow(both), nrow(vc) - nrow(both), nrow(rb) - nrow(both), nrow(rb)))
fwrite(vc, file.path(root, "places-2026.csv")); fwrite(ev, file.path(root, "early-centres-2026.csv"))
cat(sprintf("VPL4 wrote %s and %s\n", file.path(root, "places-2026.csv"), file.path(root, "early-centres-2026.csv")))

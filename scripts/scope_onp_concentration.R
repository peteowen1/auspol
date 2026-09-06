options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
PREF <- election_data_path()

# How concentrated is One Nation's district vote, and how does that vary with
# the statewide level? This is the input the concentration step needs, and
# CLAUDE.md records that CV-constant and SD-constant disagree by 4.4x across
# the gap from federal (4-9%) to Victoria (~20%).
fs <- list.files(PREF, pattern = "firstprefs\\.csv$", full.names = TRUE)
rows <- list()
for (f in fs) {
  d <- fread(f, showProgress = FALSE)
  if (!all(c("seat","party","votes") %in% names(d))) next
  d[, tot := sum(votes), by = seat]; d[, pc := 100*votes/tot]
  o <- d[party == "ONP"]
  if (nrow(o) < 10) next
  # districts the party did NOT contest count as 0: concentration is about the
  # spread across the whole chamber, and dropping them would understate it.
  allseats <- unique(d$seat)
  v <- rep(0, length(allseats)); names(v) <- allseats
  v[o$seat] <- o$pc
  sw <- 100*sum(o$votes)/sum(d[!duplicated(paste(seat,party)), votes])
  rows[[length(rows)+1L]] <- data.table(
    file = basename(f), seats = length(allseats), contested = nrow(o),
    statewide = round(sw,2), mean_pc = round(mean(v),2),
    sd_pts = round(sd(v),2), cv = round(sd(v)/mean(v),3),
    max_pc = round(max(v),1))
}
r <- rbindlist(rows)[order(-statewide)]
cat("=== One Nation district-level concentration, every available election ===\n")
print(r)

cat("\n=== how does concentration scale with the statewide level? ===\n")
u <- r[statewide >= 1]
if (nrow(u) >= 4) {
  cat(sprintf("cor(statewide, sd_pts) = %+.3f\n", cor(u$statewide, u$sd_pts)))
  cat(sprintf("cor(statewide, cv)     = %+.3f\n", cor(u$statewide, u$cv)))
  cat("\nIf SD is roughly constant, transport SD. If CV is roughly constant,\n")
  cat("transport CV. The published model transports a target CV of 0.327.\n")
  cat(sprintf("\nobserved CV range: %.3f to %.3f (mean %.3f)\n",
              min(u$cv), max(u$cv), mean(u$cv)))
  cat(sprintf("observed SD range: %.2f to %.2f points (mean %.2f)\n",
              min(u$sd_pts), max(u$sd_pts), mean(u$sd_pts)))
}
cat("\n=== what SA 2026 actually had, the target any transport must reproduce ===\n")
print(r[grepl("2026-sa", file)])

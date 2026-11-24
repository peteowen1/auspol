# The data behind the "type every primary" what-if page: this run's own simulations, one row per simulation,
# as statewide first-preference votes and seats won, for five groups (Labor, Coalition, One Nation, Greens, Others).
#
#   Rscript scripts/build_whatif_sims.R [--target=vic2026]
# In:   output/night-state-<stem>.rds        (its `swd`: statewide primary draws, n_sims x classes)
#       output/seat-sims-full-<stem>.csv     (seats won by class in each simulation)
#       output/forecast-<target>.json        (only for built_at, if present)
# Out:  output/whatif-sims-<target>.json     (uploaded to R2 by the daily workflow for the site)
#
# Row i of both inputs is the same simulation (fit_seats_full.R writes them from one `sim`). That pairing is the
# whole tool, so it is checked: the Coalition's statewide vote must correlate strongly with its seats.
# Check codes: WIS1! (input missing or wrong shape), WIS2 (what was written).
suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default) { hit <- grep(paste0("^--", name, "="), args, value = TRUE); if (length(hit)) sub("^[^=]*=", "", hit[1]) else default }
TARGETS <- c(vic2026 = "vic-2026", nsw2027 = "nsw-2027")
TARGET <- arg("target", "vic2026")
if (!TARGET %in% names(TARGETS)) stop("WIS1! unknown --target ", TARGET)
STEM <- TARGETS[[TARGET]]
dir_in <- arg("dir", "output")
f_state <- file.path(dir_in, sprintf("night-state-%s.rds", STEM)); f_seats <- file.path(dir_in, sprintf("seat-sims-full-%s.csv", STEM))
for (f in c(f_state, f_seats)) if (!file.exists(f)) stop("WIS1! ", f, " missing -- run scripts/fit_seats_full.R first")
ns <- readRDS(f_state)
# swd_all: every statewide draw when the forecast ran more sims than the night state keeps (fit_seats_full.R, 25 Nov 2026)
swd <- as.matrix(if (!is.null(ns$swd_all)) ns$swd_all else ns$swd); seats <- as.matrix(fread(f_seats))
cols <- c("ALP", "LNP", "ONP", "GRN")
if (!all(cols %in% colnames(swd)) || !all(cols %in% colnames(seats))) stop("WIS1! a named class is missing from the draws or the seat totals")
if (nrow(swd) != nrow(seats) || nrow(swd) < 1000L) stop(sprintf("WIS1! %d vote draws against %d seat rows", nrow(swd), nrow(seats)))
chamber <- unique(rowSums(seats))
if (length(chamber) != 1L) stop("WIS1! seat totals do not sum to one chamber size in every simulation")
pairing <- stats::cor(swd[, "LNP"], seats[, "LNP"])
if (!is.finite(pairing) || pairing < 0.5) stop(sprintf("WIS1! Coalition vote and Coalition seats correlate %.2f: the two files are not the same simulations row for row", pairing))
grp <- function(m) cbind(Labor = m[, "ALP"], Coalition = m[, "LNP"], OneNation = m[, "ONP"], Greens = m[, "GRN"],
                         Others = rowSums(m[, setdiff(colnames(m), cols), drop = FALSE]))
v <- grp(swd); s <- grp(seats)
fj <- file.path(dir_in, sprintf("forecast-%s.json", TARGET))
built_at <- if (file.exists(fj)) tryCatch(jsonlite::fromJSON(fj)$built_at, error = function(e) NA_character_) else NA_character_
out <- list(election = TARGET, built_at = if (is.null(built_at)) NA_character_ else built_at, saved_at = as.character(ns$saved_at),
            parties = colnames(v), n = nrow(v), seats_total = chamber, majority = as.integer(floor(chamber / 2) + 1L),
            vote_means = as.list(round(colMeans(v), 3)), seat_means = as.list(round(colMeans(s), 3)),
            votes = lapply(seq_len(ncol(v)), function(j) round(v[, j], 1)), seats = lapply(seq_len(ncol(s)), function(j) as.integer(s[, j])))
f_out <- file.path(dir_in, sprintf("whatif-sims-%s.json", TARGET))
writeLines(jsonlite::toJSON(out, auto_unbox = TRUE, digits = NA, na = "null"), f_out)
cat(sprintf("WIS2 wrote %s: %d simulations, %d seats, built_at %s, vote/seat pairing r = %.2f, %d bytes\n", f_out, nrow(v), chamber, out$built_at, pairing, file.size(f_out)))
cat(sprintf("WIS2 mean votes: %s | mean seats: %s\n", paste(sprintf("%s %.1f", colnames(v), colMeans(v)), collapse = ", "), paste(sprintf("%s %.1f", colnames(s), colMeans(s)), collapse = ", ")))

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
swd <- as.matrix(ns$swd); seats <- as.matrix(fread(f_seats))
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
# The statewide preference flows the forecast itself uses (the FL0 line of fit_seats_full.R), so the page can show
# the two-party-preferred figure a set of primaries implies: Labor + each group's vote x its share flowing to Labor.
# Optional: if the package or its flow table cannot be loaded, `flows_to_labor` is null and the page shows no
# two-party line. Independents and every other party use the model's "other" flow.
flows <- tryCatch({
  options(auspol.root = normalizePath("."))
  suppressMessages(devtools::load_all(quiet = TRUE))
  ft <- as.data.frame(flows_for(load_preference_flows(), as.integer(sub("^[a-z]+", "", TARGET)), sub("[0-9]+$", "", TARGET), quiet = TRUE))
  pick <- function(k) { r <- ft$flow_alp[ft$party == k]; if (length(r) == 1L && is.finite(r) && r >= 0 && r <= 100) r / 100 else NA_real_ }
  fl <- c(Greens = pick("GRN"), OneNation = pick("ONP"), Others = pick("OTH"))
  if (anyNA(fl)) stop("a flow is missing: ", paste(names(fl)[is.na(fl)], collapse = ", "))
  fl
}, error = function(e) { cat("WIS1! statewide flows not read (", conditionMessage(e), "); the file carries no two-party flows\n", sep = ""); NULL })
tpp_labor <- function(m, f) 100 * (m[, "Labor"] + f[["Greens"]] * m[, "Greens"] + f[["OneNation"]] * m[, "OneNation"] + f[["Others"]] * m[, "Others"]) / rowSums(m)
fj <- file.path(dir_in, sprintf("forecast-%s.json", TARGET))
built_at <- if (file.exists(fj)) tryCatch(jsonlite::fromJSON(fj)$built_at, error = function(e) NA_character_) else NA_character_
out <- list(election = TARGET, built_at = if (is.null(built_at)) NA_character_ else built_at, saved_at = as.character(ns$saved_at),
            parties = colnames(v), n = nrow(v), seats_total = chamber, majority = as.integer(floor(chamber / 2) + 1L),
            vote_means = as.list(round(colMeans(v), 3)), seat_means = as.list(round(colMeans(s), 3)),
            flows_to_labor = if (is.null(flows)) NULL else as.list(round(flows, 4)),
            tpp_labor_mean = if (is.null(flows)) NULL else round(mean(tpp_labor(v, flows)), 2),
            votes = lapply(seq_len(ncol(v)), function(j) round(v[, j], 1)), seats = lapply(seq_len(ncol(s)), function(j) as.integer(s[, j])))
f_out <- file.path(dir_in, sprintf("whatif-sims-%s.json", TARGET))
writeLines(jsonlite::toJSON(out, auto_unbox = TRUE, digits = NA, na = "null"), f_out)
cat(sprintf("WIS2 wrote %s: %d simulations, %d seats, built_at %s, vote/seat pairing r = %.2f, %d bytes\n", f_out, nrow(v), chamber, out$built_at, pairing, file.size(f_out)))
cat(sprintf("WIS2 mean votes: %s | mean seats: %s\n", paste(sprintf("%s %.1f", colnames(v), colMeans(v)), collapse = ", "), paste(sprintf("%s %.1f", colnames(s), colMeans(s)), collapse = ", ")))

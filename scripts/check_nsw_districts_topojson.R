# Every district in web/nsw2027-districts.topojson must match a `seat` in
# forecast-nsw2027.json exactly, and vice versa, or the map shows a hole.
#   Rscript scripts/check_nsw_districts_topojson.R [path/to/forecast-nsw2027.json]
suppressMessages(library(jsonlite))
args <- commandArgs(trailingOnly = TRUE)
fc_f <- if (length(args)) args[1] else file.path("output", "forecast-nsw2027.json")
topo <- fromJSON("web/nsw2027-districts.topojson", simplifyVector = FALSE)
obj <- topo$objects[[1]]
geo_seats <- vapply(obj$geometries, function(g) g$properties$seat, character(1))
fc <- fromJSON(fc_f)
fc_seats <- fc$seats$seat
cat(sprintf("ND1 topojson: %d districts (%s geometry types: %s); forecast: %d seats\n", length(geo_seats),
            names(topo$objects)[1], paste(unique(vapply(obj$geometries, function(g) g$type, character(1))), collapse = "/"), length(fc_seats)))
only_geo <- setdiff(geo_seats, fc_seats); only_fc <- setdiff(fc_seats, geo_seats)
if (length(only_geo)) cat("ND1! in the map, not the forecast: ", paste(only_geo, collapse = ", "), "\n")
if (length(only_fc)) cat("ND1! in the forecast, not the map: ", paste(only_fc, collapse = ", "), "\n")
stopifnot(identical(names(topo$objects)[1], "districts"), length(geo_seats) == 93L,
          anyDuplicated(geo_seats) == 0L, !length(only_geo), !length(only_fc))
cat(sprintf("ND1 OK: all 93 names match exactly (%.0f KB)\n", file.size("web/nsw2027-districts.topojson") / 1024))

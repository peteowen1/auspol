# Every district in web/vic2026-districts.topojson must match a `seat` in
# forecast-vic2026.json exactly, and vice versa, or the map shows a hole.
suppressMessages(library(jsonlite))
topo <- fromJSON("web/vic2026-districts.topojson", simplifyVector = FALSE)
obj <- topo$objects[[1]]
geo_seats <- vapply(obj$geometries, function(g) g$properties$seat, character(1))
fc <- fromJSON(file.path("output", "forecast-vic2026.json"))
fc_seats <- fc$seats$seat
cat(sprintf("VD1 topojson: %d districts (%s geometry types: %s); forecast: %d seats\n", length(geo_seats),
            names(topo$objects)[1], paste(unique(vapply(obj$geometries, function(g) g$type, character(1))), collapse = "/"), length(fc_seats)))
only_geo <- setdiff(geo_seats, fc_seats); only_fc <- setdiff(fc_seats, geo_seats)
if (length(only_geo)) cat("VD1! in the map, not the forecast: ", paste(only_geo, collapse = ", "), "\n")
if (length(only_fc)) cat("VD1! in the forecast, not the map: ", paste(only_fc, collapse = ", "), "\n")
stopifnot(length(geo_seats) == 88L, anyDuplicated(geo_seats) == 0L, !length(only_geo), !length(only_fc))
cat(sprintf("VD1 OK: all 88 names match exactly (%.0f KB)\n", file.size("web/vic2026-districts.topojson") / 1024))

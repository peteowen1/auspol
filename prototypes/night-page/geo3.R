suppressMessages(library(sf)); sf_use_s2(FALSE)
m <- "C:/Users/peteo/AppData/Local/Temp/claude/C--dev-auspol/39010bb2-4069-4b67-8612-d07117b76033/scratchpad/maps"
x <- st_read("C:/dev/auspol/external/reference/boundaries/SED_2022_dl/SED_2022_AUST_GDA2020.shp", quiet = TRUE)
x <- x[x$STE_NAME21 == "Victoria" & !grepl("Migratory|No usual", x$SED_NAME22), ]
x$name <- trimws(sub("[(].*$", "", x$SED_NAME22))
stopifnot(nrow(x) == 88, !anyDuplicated(x$name))
d <- st_transform(st_make_valid(x[, "name"]), 3111)
d <- st_simplify(d, preserveTopology = TRUE, dTolerance = as.numeric(Sys.getenv("TOL", "250")))
d <- st_transform(st_make_valid(d), 4326)
out <- file.path(m, "vic-districts.geojson")
if (file.exists(out)) file.remove(out)
st_write(d, out, driver = "GeoJSON", layer_options = "COORDINATE_PRECISION=4", quiet = TRUE)
cat("features:", nrow(d), " bytes:", file.size(out), "\n")

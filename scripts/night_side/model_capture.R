# Per-booth MODEL estimates for the live night (Pete via ITG, 28 Nov). Sourced by a COPY of scripts/night_loop.R right
# after load_all(). It rebuilds project_seat_from_booths() with ONE extra statement, placed just before the function
# adds the booths up: stash the uncounted-unit grid, which by then holds each unit's projected votes per class (`proj`)
# and its expected size, after every model step (look-alike booths, vote-type gaps, the lean for a class that did not
# stand last time). Nothing else in the function changes, and its result is returned untouched. Each seat's grid is saved
# to <MODELCAP_DIR>/<seat>.rds.
local({
  ns <- environment(night_booth_update); CAP <- Sys.getenv("MODELCAP_DIR")
  f <- get("project_seat_from_booths", ns); b <- as.list(body(f))
  i <- which(vapply(b, function(e) grepl("out <- rbind(live[unit %in% counted_units", paste(deparse(e), collapse = ""), fixed = TRUE), logical(1)))
  if (length(i) != 1L) stop("MODELCAP! could not find the summing statement in project_seat_from_booths (found ", length(i), ")")
  b <- append(b, list(quote(assign(".CUR_GRID", data.table::copy(grid), envir = globalenv()))), after = i - 1L)
  body(f) <- as.call(b)
  pj <- function(live, ref, counted_units, ...) {
    assign(".CUR_GRID", NULL, envir = globalenv()); p <- f(live, ref, counted_units, ...)
    g <- get(".CUR_GRID", envir = globalenv())
    if (!is.null(g) && nzchar(CAP)) { s <- as.character(live$district[1])
      saveRDS(list(seat = s, grid = g[, intersect(c("unit", "booth_type", "cls", "size", "proj"), names(g)), with = FALSE]), file.path(CAP, paste0(gsub("[^A-Za-z]", "", s), ".rds"))) }
    p }
  unlockBinding("project_seat_from_booths", ns); assign("project_seat_from_booths", pj, ns)
})

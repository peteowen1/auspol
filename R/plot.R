#' Plot fitted trends with their polls
#'
#' @param fits Named list from [fit_cycle_trends()].
#' @param polls The cycle polls the fits were made from.
#' @param tpp Optional TPP trend from [derive_tpp()].
#' @param title Plot title.
#' @return ggplot object.
#' @export
plot_trends <- function(fits, polls, tpp = NULL, title = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 needed for plotting")

  # Only the share-scale columns; fits also carry model-scale diagnostics that
  # a derived series like TPP has no equivalent of.
  cols <- c("date", "mean", "sd", "lo95", "hi95")
  trend_dt <- data.table::rbindlist(lapply(names(fits), function(p) {
    data.table::data.table(series = p, fits[[p]]$trend[, cols, with = FALSE])
  }))
  poll_dt <- data.table::rbindlist(lapply(names(fits), function(p) {
    d <- polls[!is.na(polls[[p]]), c("date", p), with = FALSE]
    data.table::setnames(d, p, "value")
    data.table::data.table(series = p, d)
  }))
  if (!is.null(tpp)) {
    trend_dt <- rbind(trend_dt,
                      data.table::data.table(series = "TPP (ALP)",
                                             tpp[, cols, with = FALSE]))
    tpp_polls <- polls[!is.na(polls$tpp_published), c("date", "tpp_published"), with = FALSE]
    data.table::setnames(tpp_polls, "tpp_published", "value")
    poll_dt <- rbind(poll_dt, data.table::data.table(series = "TPP (ALP)", tpp_polls))
  }

  # Party colours: conventional Australian palette
  cols <- c(
    ALP = "#E13940", LNP = "#1C4F9C", LIB = "#1C4F9C", NAT = "#00843D",
    GRN = "#10C25B", ONP = "#F36D24", UAP = "#FFD700", "TPP (ALP)" = "#8B0000"
  )
  present <- unique(trend_dt$series)
  pal <- cols[present]
  pal[is.na(pal)] <- "#888888"
  names(pal) <- present

  ggplot2::ggplot(trend_dt, ggplot2::aes(x = date, colour = series, fill = series)) +
    ggplot2::geom_point(
      data = poll_dt, ggplot2::aes(y = value),
      alpha = 0.35, size = 0.8, show.legend = FALSE
    ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lo95, ymax = hi95),
      alpha = 0.18, colour = NA, show.legend = FALSE
    ) +
    ggplot2::geom_line(ggplot2::aes(y = mean), linewidth = 0.7) +
    ggplot2::scale_colour_manual(values = pal) +
    ggplot2::scale_fill_manual(values = pal) +
    ggplot2::labs(
      title = title, x = NULL, y = "Vote share (%)", colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom")
}

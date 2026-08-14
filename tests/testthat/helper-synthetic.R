# Shared synthetic poll generator for trend/hyperparameter tests.
make_synthetic <- function(seed = 42, n_polls = 120, T_days = 400,
                           house = c(A = 2, B = -2, C = 0),
                           sigma_obs = 1.2, sigma_rw = 0.08,
                           firm_noise = NULL, level = 35) {
  set.seed(seed)
  latent <- level + cumsum(rnorm(T_days + 1, 0, sigma_rw))
  dates <- as.Date("2024-01-01") + 0:T_days
  poll_t <- sort(sample(0:T_days, n_polls, replace = TRUE))
  firm <- sample(names(house), n_polls, replace = TRUE)
  noise_sd <- sigma_obs * if (is.null(firm_noise)) 1 else firm_noise[firm]
  y <- latent[poll_t + 1] + house[firm] + rnorm(n_polls, 0, noise_sd)
  polls <- data.table::data.table(
    date = dates[poll_t + 1], firm = firm, tpp_published = NA_real_, ALP = y
  )
  data.table::setattr(polls, "parties", "ALP")
  data.table::setattr(polls, "region", "test")
  data.table::setattr(polls, "cycle_year", 2025)
  data.table::setattr(polls, "cycle_start", dates[1])
  data.table::setattr(polls, "cycle_end", dates[T_days + 1])
  list(polls = polls, latent = latent, dates = dates, house = house)
}

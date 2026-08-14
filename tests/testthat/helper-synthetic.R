# Shared synthetic poll generators for trend/hyperparameter tests.

wrap_polls <- function(dates, firm, value, T_days) {
  polls <- data.table::data.table(
    date = dates, firm = firm, tpp_published = NA_real_, ALP = value
  )
  data.table::setattr(polls, "parties", "ALP")
  data.table::setattr(polls, "region", "test")
  data.table::setattr(polls, "cycle_year", 2025)
  data.table::setattr(polls, "cycle_start", min(dates))
  data.table::setattr(polls, "cycle_end", min(dates) + T_days)
  polls
}

# Points-scale generator: latent path and noise both in percentage points.
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
  list(polls = wrap_polls(dates[poll_t + 1], firm, y, T_days),
       latent = latent, dates = dates, house = house)
}

# Logit-scale generator: the latent path walks in log-odds and is observed as
# a percentage, which is what the logit model actually assumes. `drift` lets a
# minor party climb steadily (the ONP case) rather than only wander.
make_synthetic_logit <- function(seed = 42, n_polls = 200, T_days = 500,
                                 house = c(A = 0.15, B = -0.15, C = 0),
                                 sigma_obs = 0.10, sigma_rw = 0.006,
                                 start_pct = 4, drift = 0) {
  set.seed(seed)
  z0 <- log(start_pct / (100 - start_pct))
  latent_z <- z0 + cumsum(rnorm(T_days + 1, drift, sigma_rw))
  dates <- as.Date("2024-01-01") + 0:T_days
  poll_t <- sort(sample(0:T_days, n_polls, replace = TRUE))
  firm <- sample(names(house), n_polls, replace = TRUE)
  z_obs <- latent_z[poll_t + 1] + house[firm] + rnorm(n_polls, 0, sigma_obs)
  list(polls = wrap_polls(dates[poll_t + 1], firm, 100 / (1 + exp(-z_obs)), T_days),
       latent_z = latent_z, latent = 100 / (1 + exp(-latent_z)),
       dates = dates, house = house)
}

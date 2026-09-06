# Full analysis: how does an incumbent's own primary vote transfer from one
# election to the next, and what predicts the change? Both major AND minor
# party incumbents, across the whole candidacies.csv corpus.
#
# Deliberately does NOT use personal_prior_vote() -- that function excludes a
# prior MAJOR-party registration on purpose (R/candidate_returns.R, the
# McBride/Ward finding), because the SHIPPED model needs a conservative
# default. This script is the opposite: it needs major-party incumbents IN,
# with "did they switch party" as a REGRESSOR to test, not a hard exclusion.
#
# Emits AIT* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
SAL <- fread("output/salience-v6.csv", showProgress = FALSE)
MAJ <- c("ALP", "LNP", "NAT")

PAIRS <- list(
  c("fed2010","fed2007"), c("fed2013","fed2010"), c("fed2016","fed2013"),
  c("fed2019","fed2016"), c("fed2022","fed2019"), c("fed2025","fed2022"),
  c("nsw2023","nsw2019"),
  c("sa2026","sa2022"),
  c("vic2018","vic2014"), c("vic2022","vic2018"),
  c("qld2024","qld2020"),
  c("wa2001","wa1996"), c("wa2005","wa2001"), c("wa2008","wa2005"),
  c("wa2013","wa2008"), c("wa2017","wa2013"), c("wa2021","wa2017"),
  c("wa2025","wa2021")
)

ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))

# ---- unfiltered personal-return match (major party included) ---------------
own_prior_any_party <- function(target, prev) {
  NOWT <- C[C$election == target]; PREVT <- C[C$election == prev]
  kf <- function(d) match_key(
    surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
              if ("name" %in% names(d)) d$name else NA_character_),
    given_of(if ("given" %in% names(d)) d$given else NA_character_,
            if ("name" %in% names(d)) d$name else NA_character_), "initial")
  NOWT <- copy(NOWT)[, .k := kf(.SD), .SDcols = names(NOWT)]
  PREVT <- copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]
  NOWT[, .s := ns(seat)]; PREVT[, .s := ns(seat)]
  setorder(NOWT, seat, party, -pcv)
  lead <- NOWT[nzchar(.k), .SD[1], by = .(seat, party)]
  prev_best <- PREVT[nzchar(.k), .(own_prev_pcv = max(pcv, na.rm = TRUE), prev_party_class = party[which.max(pcv)]),
                     by = .(.s, .k)]
  out <- merge(lead[, .(seat, .s, party, .k, name, given, surname, pcv, elected)], prev_best, by = c(".s", ".k"), all.x = TRUE)
  out[, .(seat, party, name, given, surname, cur_pcv = pcv, cur_elected = elected, own_prev_pcv, prev_party_class)]
}

tpp_swing <- function(target, prev) {
  t_alp <- sum(C[C$election==target & C$party=="ALP", pcv]); t_lnp <- sum(C[C$election==target & C$party %in% c("LNP","NAT"), pcv])
  p_alp <- sum(C[C$election==prev   & C$party=="ALP", pcv]); p_lnp <- sum(C[C$election==prev   & C$party %in% c("LNP","NAT"), pcv])
  100*t_alp/(t_alp+t_lnp) - 100*p_alp/(p_alp+p_lnp)
}
party_swing_of <- function(target, prev, cls) {
  # MEAN pcv per contesting seat, not summed across all seats -- summing
  # scales with how many seats the party fielded a candidate in (hundreds),
  # not a genuine percentage-point swing, and silently inflated this
  # coefficient's units while leaving sign/significance intact.
  t <- mean(C[C$election==target & C$party==cls, pcv]); p <- mean(C[C$election==prev & C$party==cls, pcv])
  if (!is.finite(t) || !is.finite(p)) return(NA_real_)
  t - p
}
# Per-PERSON salience percentile, matched by name (not "loudest in the seat" --
# that was a seat-level proxy, not this specific incumbent's own value, and
# cannot support a same-person delta at all).
person_jump_pctile <- function(election_label, given_, surname_, name_, seat_) {
  s <- SAL[SAL$election == election_label]
  if (!nrow(s)) return(NA_real_)
  s <- copy(s)[, jp := rank(jump, ties.method = "average") / .N]
  target_key <- search_form(given_, surname_, name_)
  s[, sk := keyword]
  hit <- s[sk == target_key & ns(seat) == ns(seat_)]
  if (!nrow(hit)) return(NA_real_)
  max(hit$jp)
}

build_one <- function(p) {
  target <- p[1]; prev <- p[2]
  region <- sub("[0-9]+$", "", target)
  own <- own_prior_any_party(target, prev)
  own <- own[!is.na(own_prev_pcv)]  # personally returning, ANY party last time
  if (!nrow(own)) return(NULL)
  own[, switched_party := party != prev_party_class]
  own[, tpp_swing := tpp_swing(target, prev)]
  own[, party_swing := mapply(function(cls) party_swing_of(target, prev, cls), party)]
  own[, jump_pctile := mapply(function(g, s, n, se) person_jump_pctile(target, g, s, n, se),
                              given, surname, name, seat)]
  own[, jump_pctile_prev := mapply(function(g, s, n, se) person_jump_pctile(prev, g, s, n, se),
                                   given, surname, name, seat)]
  own[, jump_delta := jump_pctile - jump_pctile_prev]
  own[, target := target]; own[, prev_el := prev]
  own[, delta := cur_pcv - own_prev_pcv]
  own[, is_major := party %in% MAJ]
  own
}

POP <- rbindlist(lapply(PAIRS, build_one), fill = TRUE)
cat(sprintf("AIT1  total personally-returning incumbents (any party): %d across %d elections\n",
            nrow(POP), uniqueN(POP$target)))
cat(sprintf("AIT1  major-party: %d | minor/IND: %d | switched party: %d (%.1f%%)\n",
            sum(POP$is_major), sum(!POP$is_major), sum(POP$switched_party),
            100*mean(POP$switched_party)))
cat(sprintf("AIT1  salience coverage: %d of %d (%.1f%%) have a jump_pctile\n",
            sum(!is.na(POP$jump_pctile)), nrow(POP), 100*mean(!is.na(POP$jump_pctile))))

fwrite(POP, "output/incumbent-transfer-population.csv")
cat("AIT2  wrote output/incumbent-transfer-population.csv\n")

# ---- regression 1: MAJOR party incumbents -----------------------------------
cat("\n=== MAJOR PARTY incumbents: delta ~ features ===\n")
maj <- POP[is_major == TRUE]
fit_maj <- lm(delta ~ own_prev_pcv + tpp_swing + party_swing, data = maj)
print(summary(fit_maj))

# ---- regression 2: MINOR/IND incumbents -------------------------------------
cat("\n=== MINOR/IND incumbents: delta ~ features (no salience) ===\n")
minr <- POP[is_major == FALSE]
fit_min <- lm(delta ~ own_prev_pcv + tpp_swing + party_swing + switched_party, data = minr)
print(summary(fit_min))

cat("\n=== MINOR/IND incumbents WITH salience LEVEL (restricted to coverage) ===\n")
minr_sal <- minr[!is.na(jump_pctile)]
cat(sprintf("n with salience coverage: %d\n", nrow(minr_sal)))
if (nrow(minr_sal) > 20) {
  fit_min_sal <- lm(delta ~ own_prev_pcv + tpp_swing + party_swing + switched_party + jump_pctile, data = minr_sal)
  print(summary(fit_min_sal))
}

cat("\n=== MINOR/IND incumbents WITH salience DELTA (both-years coverage) ===\n")
minr_sal2 <- minr[!is.na(jump_pctile) & !is.na(jump_pctile_prev)]
cat(sprintf("n with BOTH-years salience coverage: %d\n", nrow(minr_sal2)))
if (nrow(minr_sal2) > 20) {
  fit_min_delta <- lm(delta ~ own_prev_pcv + tpp_swing + party_swing + switched_party + jump_pctile + jump_delta, data = minr_sal2)
  print(summary(fit_min_delta))
}

cat("\n=== switched_party effect size, minor/IND only ===\n")
print(minr[, .(n=.N, mean_delta=round(mean(delta),2), sd_delta=round(sd(delta),2)), by=switched_party])

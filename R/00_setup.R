## Shared settings, data readers and model helpers.
## The whole analysis is run from the repository root with:  Rscript run_all.R

suppressPackageStartupMessages({
  library(MASS)      # glm.nb, negative.binomial, mvrnorm
  library(sandwich)  # vcovHC (HC3)
})

YEARS     <- 2015:2024
BASE_YRS  <- 2015:2019                     # pre-COVID baseline
POST_YRS  <- 2022:2024                     # post-full-scale-invasion period
SERIES    <- c("heterosexual", "msm", "pwid", "mtc", "female", "male")
LABEL     <- c(heterosexual = "Heterosexual", msm = "MSM", pwid = "PWID", mtc = "MTC",
               female = "Female (total)", male = "Male (total)")
SEEDS     <- c(heterosexual = 20260420, msm = 20260421, pwid = 20260422, mtc = 20260423,
               female = 20260424, male = 20260425)
N_SIM     <- 350000                       # Monte Carlo draws per series and year
THRESHOLD <- c(heterosexual = 20, msm = 20, pwid = 20, mtc = 5, female = 20, male = 20)
REGIONAL  <- c("Bulgaria", "Croatia", "Czechia", "Estonia", "Hungary", "Latvia", "Lithuania",
               "Poland", "Romania", "Slovakia", "Slovenia")   # study-defined CEE host-country group
OUT       <- Sys.getenv("HIV_OUT", "output")   # output folder (check_outputs.R writes to output_check)
dir.create(file.path(OUT, "tables"), recursive = TRUE, showWarnings = FALSE)

## ---- data ----------------------------------------------------------------------------------------
## ECDC/WHO 2025 report, Tables 2-7: annual diagnoses 2015-2024 by country (long format)
read_counts <- function() {
  d <- read.csv("data/raw/ecdc2025_tables2to7.csv", check.names = FALSE, stringsAsFactors = FALSE)
  out <- do.call(rbind, lapply(YEARS, function(y)
    data.frame(series = d$series, country = d$country, year = y, n = as.numeric(d[[as.character(y)]]),
               stringsAsFactors = FALSE)))
  out[order(out$series, out$country, out$year), ]
}
## one series as a country x year matrix
counts_matrix <- function(counts, s) {
  x <- counts[counts$series == s, ]
  tapply(x$n, list(x$country, x$year), sum)
}
## Eurostat migr_asytpspop (Ukrainian citizens, per 1,000 persons); flags such as [d] are dropped
read_tp <- function() {
  d <- read.csv("data/raw/eurostat_migr_asytpspop_UA_dec2022-2024.csv", check.names = FALSE,
                stringsAsFactors = FALSE)
  num <- function(v) as.numeric(sub("\\[.*\\]$", "", v))
  tp <- data.frame(country = d$country, dec2022 = num(d[["2022-12"]]), dec2023 = num(d[["2023-12"]]),
                   dec2024 = num(d[["2024-12"]]), stringsAsFactors = FALSE)
  tp$tp_mean   <- (tp$dec2022 + tp$dec2023 + tp$dec2024) / 3   # no intermediate rounding
  tp$tp_change <- tp$dec2024 - tp$dec2022
  tp
}

## ---- models --------------------------------------------------------------------------------------
## Negative binomial GLM (log link, linear year index 2015 = 0) fitted to five baseline counts;
## glm.nb warnings are kept with the fit instead of being printed.
fit_nb <- function(y5) {
  df <- data.frame(y = y5, t = 0:4)
  warn <- character(0)
  fit <- withCallingHandlers(glm.nb(y ~ t, data = df), warning = function(w) {
    warn <<- c(warn, conditionMessage(w)); invokeRestart("muffleWarning") })
  fit$fit_warnings <- unique(warn)
  fit
}
## Prediction limits for 2020-2024 (t = 5..9): coefficients ~ MVN(b, V), counts ~ NB(theta, mu).
## The outcome-specific seed is set once; one block of N_SIM draws per projection year.
sim_limits_nb <- function(b, V, theta, seed, t_new = 5:9) {
  set.seed(seed)
  t(vapply(t_new, function(tt) {
    B <- mvrnorm(N_SIM, b, V)
    quantile(rnbinom(N_SIM, size = theta, mu = exp(B[, 1] + B[, 2] * tt)), c(0.025, 0.975), names = FALSE)
  }, numeric(2)))
}
## Quasi-Poisson limits: coefficients ~ MVN, response ~ Normal(mu, max(phi, 1) mu), rounded, truncated at 0
sim_limits_qp <- function(b, V, phi, seed, t_new = 5:9) {
  set.seed(seed)
  t(vapply(t_new, function(tt) {
    B <- mvrnorm(N_SIM, b, V)
    mu <- exp(B[, 1] + B[, 2] * tt)
    sim <- round(rnorm(N_SIM, mu, sqrt(max(phi, 1) * mu)))
    sim[sim < 0] <- 0
    quantile(sim, c(0.025, 0.975), names = FALSE)
  }, numeric(2)))
}
classify <- function(o, lo, hi) ifelse(o > hi, "above", ifelse(o < lo, "below", "within"))

## Country-years 2015-2024 in which diagnoses were reported but none had a reported transmission mode (the
## four transmission series are all zero). Such a zero is missing data, not an observed count (Iceland 2015,
## Malta 2019 and Liechtenstein 2022 in the 2025 report).
no_mode_years <- function(counts) {
  tr  <- aggregate(n ~ country + year, data = counts[counts$series %in% c("heterosexual", "msm", "pwid", "mtc"), ], FUN = sum)
  sx  <- aggregate(n ~ country + year, data = counts[counts$series %in% c("female", "male"), ], FUN = sum)
  chk <- merge(tr, sx, by = c("country", "year"), suffixes = c("_mode", "_sex"))
  chk <- chk[chk$year %in% YEARS & chk$n_mode == 0 & chk$n_sex > 0 & chk$country != "Total EU/EEA", ]
  chk[order(chk$country, chk$year), c("country", "year", "n_sex")]
}
## Countries with such a year. Their transmission-category series are excluded from all country-level
## analyses; the female and male totals do not depend on transmission mode and are not affected.
no_mode_countries <- function(counts) sort(unique(no_mode_years(counts)$country))

## Profile-likelihood interval for theta (coefficients re-estimated at each theta). theta has no finite
## maximum-likelihood estimate (Poisson limit) when the Poisson fit gives sum((y - mu)^2 - y) <= 0.
theta_profile <- function(y5, nb, level = 0.95) {
  df <- data.frame(y = y5, t = 0:4)
  pois <- glm(y ~ t, family = poisson, data = df)
  infinite <- sum((y5 - fitted(pois))^2 - y5) <= 0
  ll <- function(th) if (th >= 1e8) as.numeric(logLik(pois)) else
    as.numeric(logLik(suppressWarnings(glm(y ~ t, family = negative.binomial(th), data = df))))
  th_hat <- if (infinite) 1e8 else nb$theta
  crit <- qchisq(level, 1) / 2
  f <- function(lt) ll(th_hat) - ll(exp(lt)) - crit
  lower <- exp(uniroot(f, c(log(1e-3), log(th_hat)), tol = 1e-10)$root)
  upper <- if (infinite || f(log(1e8)) < 0) Inf else exp(uniroot(f, c(log(th_hat), log(1e8)), tol = 1e-10)$root)
  list(infinite = infinite, lower = lower, upper = upper)
}

## Countries in which more than half of the 2024 diagnoses had no reported transmission mode (ECDC 2025
## report, Table 8): Estonia, Latvia and Poland. Used in the completeness sensitivity analyses.
high_unknown_mode_countries <- function(threshold = 0.5) {
  t8 <- read.csv("data/raw/ecdc2025_table8_2024.csv", check.names = FALSE, stringsAsFactors = FALSE)
  t8 <- t8[t8$country != "Total EU/EEA", ]
  sort(t8$country[as.numeric(t8$unk_total) / as.numeric(t8$total) > threshold])
}

## Country-level association models used in Table S3 (and for the observed/predicted outcome).
## d: data frame with columns country, outcome, tp_mean, base_mean, regional.
association <- function(d, regional_models = TRUE) {
  pe <- cor.test(d$tp_mean, d$outcome)
  sp <- cor.test(d$tp_mean, d$outcome, method = "spearman", exact = FALSE)   # t approximation for p
  slope <- function(m) c(est = unname(coef(m)[2]), lo = confint(m)[2, 1], hi = confint(m)[2, 2])
  m0 <- lm(outcome ~ tp_mean, data = d)
  mb <- lm(outcome ~ tp_mean + base_mean, data = d)
  mw <- lm(outcome ~ tp_mean, data = d, weights = base_mean)
  res <- data.frame(n = nrow(d), pearson_r = unname(pe$estimate), pearson_p = pe$p.value,
                    spearman_rho = unname(sp$estimate), spearman_p = sp$p.value,
                    unadj = slope(m0)[1], unadj_lo = slope(m0)[2], unadj_hi = slope(m0)[3],
                    burden = slope(mb)[1], burden_lo = slope(mb)[2], burden_hi = slope(mb)[3],
                    weighted = slope(mw)[1], weighted_lo = slope(mw)[2], weighted_hi = slope(mw)[3],
                    adj = NA, adj_lo = NA, adj_hi = NA, hc3_lo = NA, hc3_hi = NA, hc3_p = NA,
                    loo_min = NA, loo_max = NA, loo_influential = NA, loo_without_influential = NA, row.names = NULL)
  if (regional_models) {
    ma <- lm(outcome ~ tp_mean + regional, data = d)
    b <- unname(coef(ma)[2]); ci <- confint(ma)[2, ]
    se <- sqrt(vcovHC(ma, type = "HC3")[2, 2]); df <- df.residual(ma); q <- qt(0.975, df)
    loo <- vapply(seq_len(nrow(d)), function(i) unname(coef(lm(outcome ~ tp_mean + regional, data = d[-i, ]))[2]), 0)
    res$adj <- b; res$adj_lo <- ci[[1]]; res$adj_hi <- ci[[2]]
    res$hc3_lo <- b - q * se; res$hc3_hi <- b + q * se; res$hc3_p <- 2 * pt(-abs(b / se), df)
    k <- which.max(abs(loo - b))           # most influential country: largest change in the slope
    res$loo_min <- min(loo); res$loo_max <- max(loo)
    res$loo_influential <- d$country[k]; res$loo_without_influential <- loo[k]
  }
  res
}

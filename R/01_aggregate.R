## EU/EEA aggregate benchmarks: Table S2, Figures 1 and 2 (top panels), theta and its sensitivity
## analysis, cumulative observed minus expected, period means and the female share.

counts <- read_counts()
tot <- counts[counts$country == "Total EU/EEA", ]
series_years <- list(); theta_rows <- list(); cum_rows <- list()

for (s in SERIES) {
  y   <- tot$n[tot$series == s][order(tot$year[tot$series == s])]   # 2015..2024
  obs <- y[6:10]
  df  <- data.frame(y = y[1:5], t = 0:4)
  new <- data.frame(t = 5:9)

  ## primary negative binomial benchmark
  nb   <- fit_nb(y[1:5])
  e_nb <- as.numeric(predict(nb, newdata = new, type = "response"))
  L_nb <- sim_limits_nb(coef(nb), vcov(nb), nb$theta, SEEDS[[s]])

  ## quasi-Poisson and OLS sensitivity models
  qp   <- glm(y ~ t, family = quasipoisson, data = df)
  phi  <- summary(qp)$dispersion
  e_qp <- as.numeric(predict(qp, newdata = new, type = "response"))
  L_qp <- sim_limits_qp(coef(qp), vcov(qp), phi, SEEDS[[s]])
  ols  <- lm(y ~ t, data = df)
  P    <- predict(ols, newdata = new, interval = "prediction", level = 0.95)

  ## theta: 95% profile-likelihood interval; sensitivity analysis with theta at its lower limit
  pr   <- theta_profile(y[1:5], nb)
  nbL  <- glm(y ~ t, family = negative.binomial(pr$lower), data = df)
  L_lo <- sim_limits_nb(coef(nbL), summary(nbL, dispersion = 1)$cov.scaled, pr$lower, SEEDS[[s]] + 2)

  series_years[[s]] <- data.frame(series = s, year = 2020:2024, observed = obs,
    nb_expected = e_nb, nb_lo = L_nb[, 1], nb_hi = L_nb[, 2], nb_class = classify(obs, L_nb[, 1], L_nb[, 2]),
    pct_of_expected = 100 * obs / e_nb,
    qp_expected = e_qp, qp_lo = L_qp[, 1], qp_hi = L_qp[, 2], qp_class = classify(obs, L_qp[, 1], L_qp[, 2]),
    ols_expected = unname(P[, "fit"]), ols_lo = unname(P[, "lwr"]), ols_hi = unname(P[, "upr"]),
    ols_class = classify(obs, P[, "lwr"], P[, "upr"]),
    thetaL_lo = L_lo[, 1], thetaL_hi = L_lo[, 2], thetaL_class = classify(obs, L_lo[, 1], L_lo[, 2]))

  theta_rows[[s]] <- data.frame(series = s, theta = nb$theta, theta_se = nb$SE.theta,
    theta_estimable = !pr$infinite, theta_ci_lower = pr$lower, theta_ci_upper = pr$upper,
    glm_nb_warnings = paste(nb$fit_warnings, collapse = "; "), qp_phi = phi,
    beta0 = unname(coef(nb)[1]), beta1 = unname(coef(nb)[2]), beta1_se = sqrt(vcov(nb)[2, 2]),
    annual_change_pct = 100 * (exp(unname(coef(nb)[2])) - 1),
    base_mean = mean(y[1:5]), post_mean = mean(y[8:10]), ratio = mean(y[8:10]) / mean(y[1:5]))

  ## cumulative observed minus expected: one coefficient draw per simulated path for all five years
  set.seed(SEEDS[[s]] + 3)
  B   <- mvrnorm(N_SIM, coef(nb), vcov(nb))
  SIM <- matrix(rnbinom(N_SIM * 5, size = nb$theta, mu = exp(B %*% rbind(1, 5:9))), N_SIM)
  for (p in list(2020:2021, 2022:2024, 2020:2024)) {
    j <- p - 2019
    l <- quantile(rowSums(SIM[, j, drop = FALSE]), c(0.025, 0.975), names = FALSE)
    cum_rows[[length(cum_rows) + 1]] <- data.frame(series = s, period = paste0(min(p), "-", max(p)),
      observed = sum(obs[j]), expected = sum(e_nb[j]), obs_minus_exp = sum(obs[j]) - sum(e_nb[j]),
      pct_of_expected = 100 * (sum(obs[j]) / sum(e_nb[j]) - 1), lo = l[1], hi = l[2],
      class = classify(sum(obs[j]), l[1], l[2]))
  }
}

benchmarks <- do.call(rbind, series_years); rownames(benchmarks) <- NULL
theta_tab  <- do.call(rbind, theta_rows);   rownames(theta_tab)  <- NULL
cumulative <- do.call(rbind, cum_rows);     rownames(cumulative) <- NULL

## female share among diagnoses recorded as female or male
fm <- merge(tot[tot$series == "female", c("year", "n")], tot[tot$series == "male", c("year", "n")],
            by = "year", suffixes = c("_female", "_male"))
fm$female_share_pct <- 100 * fm$n_female / (fm$n_female + fm$n_male)

write.csv(benchmarks, file.path(OUT, "tables", "benchmarks_2020_2024.csv"), row.names = FALSE)
write.csv(theta_tab,  file.path(OUT, "tables", "theta_and_period_means.csv"), row.names = FALSE)
write.csv(cumulative, file.path(OUT, "tables", "cumulative_observed_minus_expected.csv"), row.names = FALSE)
write.csv(fm,         file.path(OUT, "tables", "female_share.csv"), row.names = FALSE)

## Sensitivity analysis: transmission-category benchmarks refitted to the EU/EEA total without the countries
## in which more than half of the 2024 diagnoses had no reported transmission mode. The female and male
## totals do not depend on transmission mode and are not repeated. Seed: the outcome-specific seed plus 4.
high_unknown <- high_unknown_mode_countries()
hu_rows <- list()
for (s in c("heterosexual", "msm", "pwid", "mtc")) {
  m   <- counts_matrix(counts, s)
  y   <- unname(colSums(m[setdiff(rownames(m), c("Total EU/EEA", high_unknown)), as.character(YEARS), drop = FALSE]))
  obs <- y[6:10]
  nb  <- fit_nb(y[1:5])
  e   <- as.numeric(predict(nb, newdata = data.frame(t = 5:9), type = "response"))
  L   <- sim_limits_nb(coef(nb), vcov(nb), nb$theta, SEEDS[[s]] + 4)
  hu_rows[[s]] <- data.frame(series = s, excluded = paste(high_unknown, collapse = ", "), year = 2020:2024,
    observed = obs, nb_expected = e, nb_lo = L[, 1], nb_hi = L[, 2], nb_class = classify(obs, L[, 1], L[, 2]),
    pct_of_expected = 100 * obs / e, base_mean = mean(y[1:5]), post_mean = mean(y[8:10]),
    ratio = mean(y[8:10]) / mean(y[1:5]), theta = nb$theta,
    glm_nb_warnings = paste(nb$fit_warnings, collapse = "; "))
}
benchmarks_hu <- do.call(rbind, hu_rows); rownames(benchmarks_hu) <- NULL
write.csv(benchmarks_hu, file.path(OUT, "tables", "benchmarks_without_high_unknown_mode.csv"), row.names = FALSE)

## Convergence checks of the negative binomial models (Additional file 3, section S1.6).
## glm.nb (MASS) warns "iteration limit reached" when the maximum-likelihood estimation of theta stops at its
## iteration limit, and "alternation limit reached" when the alternation between estimating theta and the
## regression coefficients stops before meeting its tolerance (both limits are glm.control()$maxit = 25).
## Every negative binomial model of the study is refitted with a higher iteration limit, a stricter tolerance,
## other starting values of theta and other starting coefficients, and compared with the reported fit:
## coefficients, standard errors, expected values, simulated 95% prediction limits and classifications.
## Series without overdispersion relative to the Poisson distribution (theta has no finite estimate) are also
## compared with an explicit Poisson GLM.
## Run after R/00_setup.R and R/04_new_analyses.R (run_all.R sources it last).

counts <- read_counts()
tot <- counts[counts$country == "Total EU/EEA", ]

## model variants: name -> function(df) returning a glm.nb fit
VARIANTS <- list(
  reported        = function(df) glm.nb(y ~ t, data = df),
  maxit_100       = function(df) glm.nb(y ~ t, data = df, control = glm.control(maxit = 100)),
  maxit_1000_tol  = function(df) glm.nb(y ~ t, data = df, control = glm.control(maxit = 1000, epsilon = 1e-12)),
  theta_start_1   = function(df) glm.nb(y ~ t, data = df, init.theta = 1, control = glm.control(maxit = 1000)),
  theta_start_1e3 = function(df) glm.nb(y ~ t, data = df, init.theta = 1e3, control = glm.control(maxit = 1000)),
  theta_start_1e7 = function(df) glm.nb(y ~ t, data = df, init.theta = 1e7, control = glm.control(maxit = 1000)),
  coef_start_flat = function(df) glm.nb(y ~ t, data = df, start = c(log(mean(df$y)), 0), control = glm.control(maxit = 1000))
)
quiet_fit <- function(f, df) {
  warn <- character(0)
  fit <- tryCatch(withCallingHandlers(f(df), warning = function(w) {
    warn <<- c(warn, conditionMessage(w)); invokeRestart("muffleWarning") }), error = function(e) e)
  list(fit = fit, warnings = paste(unique(warn), collapse = "; "))
}
## no overdispersion relative to the Poisson fit: theta has no finite estimate (the test used in 04_new_analyses.R)
no_overdispersion <- function(y5) {
  pois <- glm(y ~ t, family = poisson, data = data.frame(y = y5, t = 0:4))
  sum((y5 - fitted(pois))^2 - y5) <= 0
}
## simulated prediction limits from a Poisson GLM: coefficients ~ MVN, counts ~ Poisson (same seed as the NB)
sim_limits_pois <- function(b, V, seed, t_new = 5:9) {
  set.seed(seed)
  t(vapply(t_new, function(tt) {
    B <- mvrnorm(N_SIM, b, V)
    quantile(rpois(N_SIM, exp(B[, 1] + B[, 2] * tt)), c(0.025, 0.975), names = FALSE)
  }, numeric(2)))
}

## Refit one series (10 annual counts 2015-2024) with every variant and an explicit Poisson GLM; prediction limits
## are simulated as in the article (same seed), and each fit is compared with the reported fit.
check_series <- function(y, seed, set, series) {
  df <- data.frame(y = y[1:5], t = 0:4)
  obs <- y[8:10]
  lim_names <- c("lo_2022", "hi_2022", "lo_2023", "hi_2023", "lo_2024", "hi_2024")
  one_row <- function(variant, fit, warnings, theta, limits) {
    b <- coef(fit); se <- sqrt(diag(vcov(fit)))
    e <- as.numeric(predict(fit, newdata = data.frame(t = 5:9), type = "response"))
    cls <- classify(obs, limits[3:5, 1], limits[3:5, 2])
    data.frame(set = set, series = series, variant = variant, converged_without_error = TRUE, warnings = warnings,
      theta = theta, b0 = unname(b[1]), b1 = unname(b[2]), se_b0 = unname(se[1]), se_b1 = unname(se[2]),
      expected_2020 = e[1], expected_2021 = e[2], expected_2022 = e[3], expected_2023 = e[4], expected_2024 = e[5],
      lo_2022 = limits[3, 1], hi_2022 = limits[3, 2], lo_2023 = limits[4, 1], hi_2023 = limits[4, 2],
      lo_2024 = limits[5, 1], hi_2024 = limits[5, 2], class_2022 = cls[1], class_2023 = cls[2], class_2024 = cls[3],
      stringsAsFactors = FALSE)
  }
  rows <- list()
  for (v in names(VARIANTS)) {
    r <- quiet_fit(VARIANTS[[v]], df)
    if (inherits(r$fit, "error")) {
      rows[[length(rows) + 1]] <- data.frame(set = set, series = series, variant = v, converged_without_error = FALSE,
                                             warnings = conditionMessage(r$fit), stringsAsFactors = FALSE)
      next
    }
    L <- sim_limits_nb(coef(r$fit), vcov(r$fit), r$fit$theta, seed)
    rows[[length(rows) + 1]] <- one_row(v, r$fit, r$warnings, r$fit$theta, L)
  }
  pf <- glm(y ~ t, family = poisson, data = df)
  rows[[length(rows) + 1]] <- one_row("poisson_glm", pf, "", Inf, sim_limits_pois(coef(pf), vcov(pf), seed))
  cols <- names(rows[[1]])
  out <- do.call(rbind, lapply(rows, function(r) { for (k in setdiff(cols, names(r))) r[[k]] <- NA; r[cols] }))
  ref <- out[out$variant == "reported", ]
  ex <- paste0("expected_", 2020:2024)
  out$max_abs_diff_coef <- pmax(abs(out$b0 - ref$b0), abs(out$b1 - ref$b1))
  out$max_rel_diff_se <- pmax(abs(out$se_b0 / ref$se_b0 - 1), abs(out$se_b1 / ref$se_b1 - 1))
  out$max_rel_diff_expected_2020_2024 <- apply(abs(sweep(as.matrix(out[, ex]), 2, unlist(ref[ex]), "/") - 1), 1, max)
  out$max_abs_diff_limits_2022_2024 <- apply(abs(sweep(as.matrix(out[, lim_names]), 2, unlist(ref[lim_names]), "-")), 1, max)
  out$classifications_same <- with(out, class_2022 == ref$class_2022 & class_2023 == ref$class_2023 &
                                         class_2024 == ref$class_2024)
  out$no_overdispersion <- no_overdispersion(y[1:5])
  out
}

## ---- aggregate series (primary benchmarks, completeness sensitivity benchmarks) ------------------
agg <- list()
for (s in SERIES) {
  y <- tot$n[tot$series == s][order(tot$year[tot$series == s])]
  agg[[length(agg) + 1]] <- check_series(y, SEEDS[[s]], "primary", s)
}
high_unknown <- high_unknown_mode_countries()
for (s in c("heterosexual", "msm", "pwid", "mtc")) {
  m <- counts_matrix(counts, s)
  y <- unname(colSums(m[setdiff(rownames(m), c("Total EU/EEA", high_unknown)), as.character(YEARS), drop = FALSE]))
  agg[[length(agg) + 1]] <- check_series(y, SEEDS[[s]] + 4, "without Estonia, Latvia, Poland", s)
}
conv_agg <- do.call(rbind, agg)
write.csv(conv_agg, file.path(OUT, "tables", "convergence_aggregate.csv"), row.names = FALSE)

## ---- illustrative four-country comparator (Additional file 6: Figure S1; seeds as in 03_descriptive.R) --
het <- counts_matrix(counts, "heterosexual")
conv_cmp <- do.call(rbind, lapply(names(COMPARATOR_SEEDS), function(cn)
  check_series(as.numeric(het[cn, as.character(YEARS)]), COMPARATOR_SEEDS[[cn]], "comparator", cn)))
write.csv(conv_cmp, file.path(OUT, "tables", "convergence_comparator.csv"), row.names = FALSE)

## ---- country series (observed/projected analysis, Additional file 7) -------------------------------
## Only expected values enter this analysis, so the projected 2022-2024 totals are compared.
counts2 <- rbind(counts, transform(aggregate(n ~ country + year, data = counts[counts$series %in% c("female", "male"), ], FUN = sum),
                                   series = "total")[, c("series", "country", "year", "n")])
op <- read.csv(file.path(OUT, "tables", "country_observed_predicted.csv"), stringsAsFactors = FALSE)
exp_tot <- function(fit) sum(as.numeric(predict(fit, newdata = data.frame(t = 7:9), type = "response")))
cty_rows <- list()
for (i in seq_len(nrow(op))) {
  s <- op$series[i]; cn <- op$country[i]
  y <- as.numeric(counts_matrix(counts2, s)[cn, as.character(YEARS)])
  df <- data.frame(y = y[1:5], t = 0:4)
  fits <- lapply(VARIANTS, quiet_fit, df = df)
  res <- vapply(fits, function(r) if (inherits(r$fit, "error")) NA_real_ else exp_tot(r$fit), 0)
  pois <- exp_tot(glm(y ~ t, family = poisson, data = df))
  cty_rows[[i]] <- data.frame(series = s, country = cn, included = op$included[i], poisson_limit = op$poisson_limit[i],
    warnings = fits$reported$warnings, expected_2022_2024_reported = res[["reported"]],
    max_rel_diff_variants = max(abs(res / res[["reported"]] - 1), na.rm = TRUE),
    variants_failed = sum(is.na(res)),
    rel_diff_poisson = pois / res[["reported"]] - 1, stringsAsFactors = FALSE)
}
conv_cty <- do.call(rbind, cty_rows)
write.csv(conv_cty, file.path(OUT, "tables", "convergence_country.csv"), row.names = FALSE)

## ---- summary (Additional file 3, section S1.6) ---------------------------------------------------
## Refits are the six variants other than the reported fit; for the series without overdispersion the explicit
## Poisson GLM is summarised separately. Failed refits (errors) are counted and excluded from the maxima.
summ_fixed <- function(d, label) {
  ser <- unique(d[, c("set", "series")])
  ref <- d[d$variant == "reported", ]
  ref_ <- d[d$variant %in% names(VARIANTS)[-1], ]
  ok <- ref_[ref_$converged_without_error, ]
  pg <- d[d$variant == "poisson_glm", ]
  nod <- all(d$no_overdispersion)
  data.frame(group = label, series_n = nrow(ser), series_with_warnings = sum(ref$warnings != ""),
    refits_n = nrow(ref_), refits_failed = sum(!ref_$converged_without_error),
    max_rel_diff_expected = max(ok$max_rel_diff_expected_2020_2024), max_rel_diff_se = max(ok$max_rel_diff_se),
    max_abs_diff_limits = max(ok$max_abs_diff_limits_2022_2024), classification_changes = sum(!ok$classifications_same),
    poisson_max_rel_diff_expected = if (nod) max(pg$max_rel_diff_expected_2020_2024) else NA,
    poisson_max_abs_diff_limits = if (nod) max(pg$max_abs_diff_limits_2022_2024) else NA,
    poisson_classification_changes = if (nod) sum(!pg$classifications_same) else NA, stringsAsFactors = FALSE)
}
summ_cty <- function(d, label, nod) {
  data.frame(group = label, series_n = nrow(d), series_with_warnings = sum(d$warnings != ""),
    refits_n = 6 * nrow(d), refits_failed = sum(d$variants_failed),
    max_rel_diff_expected = max(d$max_rel_diff_variants), max_rel_diff_se = NA, max_abs_diff_limits = NA,
    classification_changes = NA,
    poisson_max_rel_diff_expected = if (nod) max(abs(d$rel_diff_poisson)) else NA,
    poisson_max_abs_diff_limits = NA, poisson_classification_changes = NA, stringsAsFactors = FALSE)
}
inc <- conv_cty[conv_cty$included, ]
conv_summary <- rbind(
  summ_fixed(conv_agg[!conv_agg$no_overdispersion, ], "EU/EEA benchmarks with overdispersion"),
  summ_fixed(conv_agg[conv_agg$no_overdispersion, ], "EU/EEA benchmarks without overdispersion"),
  summ_fixed(conv_cmp[!conv_cmp$no_overdispersion, ], "Four-country comparator with overdispersion"),
  summ_fixed(conv_cmp[conv_cmp$no_overdispersion, ], "Four-country comparator without overdispersion"),
  summ_cty(inc[!inc$poisson_limit, ], "Country series with overdispersion", FALSE),
  summ_cty(inc[inc$poisson_limit, ], "Country series without overdispersion", TRUE))
write.csv(conv_summary, file.path(OUT, "tables", "convergence_summary.csv"), row.names = FALSE)

## Additional exploratory analyses (Additional file 7; methods in Additional file 3, section S5):
##  (1) trajectory deviation map of the six EU/EEA series;
##  (2) country-level observed/predicted ratios from country-specific pre-COVID benchmarks (called
##      observed/projected ratios in the article), and their association with temporary-protection intensity;
##  (3) exploratory clustering of countries.

## ---- (1) trajectory deviation map ---------------------------------------------------------------
dev_map <- merge(theta_tab[, c("series", "beta1", "beta1_se", "annual_change_pct")],
                 cumulative[cumulative$period == "2022-2024", c("series", "observed", "expected", "pct_of_expected", "lo", "hi")],
                 by = "series")
dev_map$change_lo <- 100 * (exp(dev_map$beta1 - qnorm(0.975) * dev_map$beta1_se) - 1)
dev_map$change_hi <- 100 * (exp(dev_map$beta1 + qnorm(0.975) * dev_map$beta1_se) - 1)
names(dev_map)[names(dev_map) == "pct_of_expected"] <- "deviation_pct"
dev_map$deviation_lo <- 100 * (dev_map$observed / dev_map$hi - 1)   # observed total against the limits
dev_map$deviation_hi <- 100 * (dev_map$observed / dev_map$lo - 1)   # of the projected 2022-2024 total
write.csv(dev_map, file.path(OUT, "tables", "deviation_map.csv"), row.names = FALSE)

## ---- (2) country-level observed/predicted ---------------------------------------------------------
counts <- read_counts()
tot_c <- counts[counts$series %in% c("female", "male"), ]
tot_c <- aggregate(n ~ country + year, data = tot_c, FUN = sum); tot_c$series <- "total"
counts2 <- rbind(counts, tot_c[, c("series", "country", "year", "n")])
countries <- setdiff(sort(unique(counts$country)), "Total EU/EEA")
tp <- read_tp()

op_rows <- list()
for (s in c(SERIES, "total")) {
  m <- counts_matrix(counts2, s)[countries, as.character(YEARS), drop = FALSE]
  for (cn in countries) {
    y <- as.numeric(m[cn, ])
    base <- mean(y[1:5])
    if (base < (if (s == "mtc") 5 else 20)) next
    nb <- tryCatch(fit_nb(y[1:5]), error = function(e) NULL)
    model <- "negative binomial"
    if (is.null(nb)) {                      # fallback: Poisson GLM (the negative binomial limit)
      nb <- glm(y ~ t, family = poisson, data = data.frame(y = y[1:5], t = 0:4)); model <- "Poisson (fallback)"
    }
    e <- as.numeric(predict(nb, newdata = data.frame(t = 5:9), type = "response"))
    ## no overdispersion relative to the Poisson fit: theta has no finite estimate (same test as theta_profile)
    pois <- glm(y ~ t, family = poisson, data = data.frame(y = y[1:5], t = 0:4))
    poisson_limit <- sum((y[1:5] - fitted(pois))^2 - y[1:5]) <= 0
    op_rows[[length(op_rows) + 1]] <- data.frame(series = s, country = cn, model = model,
      warnings = if (!is.null(nb$fit_warnings)) paste(nb$fit_warnings, collapse = "; ") else "",
      poisson_limit = poisson_limit,
      base_mean = base, expected_2020_2021 = sum(e[1:2]), observed_2020_2021 = sum(y[6:7]),
      expected_2022_2024 = sum(e[3:5]), observed_2022_2024 = sum(y[8:10]),
      op_2020_2021 = sum(y[6:7]) / sum(e[1:2]), op_2022_2024 = sum(y[8:10]) / sum(e[3:5]),
      period_ratio = mean(y[8:10]) / base, stringsAsFactors = FALSE)
  }
}
op <- do.call(rbind, op_rows)
op <- merge(op, tp[, c("country", "tp_mean", "tp_change")], by = "country", all.x = TRUE)
op$regional <- op$country %in% REGIONAL
## the same country sets as the period-ratio analyses (sex analyses: both female and male >= 20)
sex_set <- intersect(op$country[op$series == "female"], op$country[op$series == "male"])
op$included <- ifelse(op$series %in% c("female", "male"), op$country %in% sex_set, TRUE)
## As in the period-ratio analyses, transmission-category series of countries with a year in which no
## diagnosis had a reported transmission mode (Iceland 2015, Malta 2019, Liechtenstein 2022) are excluded:
## the zero is missing data and would also distort the country-specific trend.
nm_years <- no_mode_years(counts)
flag <- op$series %in% c("heterosexual", "msm", "pwid", "mtc") & op$country %in% nm_years$country
op$included[flag] <- FALSE
yrs_of <- function(cn) paste(nm_years$year[nm_years$country == cn], collapse = ", ")
write.csv(data.frame(country = op$country[flag], series = op$series[flag],
                     reason = vapply(op$country[flag], function(cn)
                       paste("no diagnosis with a reported transmission mode in", yrs_of(cn)), "")),
          file.path(OUT, "tables", "observed_predicted_exclusions.csv"), row.names = FALSE)
op <- op[order(op$series, op$country), ]; rownames(op) <- NULL
write.csv(op, file.path(OUT, "tables", "country_observed_predicted.csv"), row.names = FALSE)

op_assoc <- do.call(rbind, lapply(SERIES, function(s) {
  d <- op[op$series == s & op$included, ]
  d$outcome <- d$op_2022_2024
  cbind(series = s, association(d, regional_models = s != "mtc"))
}))
write.csv(op_assoc, file.path(OUT, "tables", "observed_predicted_associations.csv"), row.names = FALSE)

## summary of the country-level observed/predicted ratios and of the country-specific model fits
op_summary <- do.call(rbind, lapply(c(SERIES, "total"), function(s) {
  d <- op[op$series == s & op$included, ]
  data.frame(series = s, n = nrow(d),
             n_above_1_2022_2024 = sum(d$op_2022_2024 > 1), median_2022_2024 = median(d$op_2022_2024),
             min_2022_2024 = min(d$op_2022_2024), min_country = d$country[which.min(d$op_2022_2024)],
             max_2022_2024 = max(d$op_2022_2024), max_country = d$country[which.max(d$op_2022_2024)],
             n_below_1_2020_2021 = sum(d$op_2020_2021 < 1), median_2020_2021 = median(d$op_2020_2021),
             n_poisson_limit = sum(d$poisson_limit), n_not_converged = sum(grepl("NaNs produced", d$warnings)),
             n_poisson_fallback = sum(d$model != "negative binomial"))
}))
write.csv(op_summary, file.path(OUT, "tables", "observed_predicted_summary.csv"), row.names = FALSE)

## ---- (3) exploratory clustering -------------------------------------------------------------------
## Countries with observed/predicted values for heterosexual, MSM, female and male diagnoses.
## PWID (15 countries) and MTC (9) are not used because they would remove most countries.
get_op <- function(s, col = "op_2022_2024") setNames(op[[col]][op$series == s & op$included], op$country[op$series == s & op$included])
cl_countries <- Reduce(intersect, list(names(get_op("heterosexual")), names(get_op("msm")),
                                       names(get_op("female")), names(get_op("male")), names(get_op("total"))))
tpi <- setNames(tp$tp_mean, tp$country); tpc <- setNames(tp$tp_change, tp$country)
cl_raw <- data.frame(country = cl_countries, tp_mean = tpi[cl_countries], tp_change = tpc[cl_countries],
                     op_heterosexual = get_op("heterosexual")[cl_countries], op_msm = get_op("msm")[cl_countries],
                     op_female = get_op("female")[cl_countries], op_male = get_op("male")[cl_countries],
                     op_disruption_total = get_op("total", "op_2020_2021")[cl_countries], row.names = NULL)
## log scale for ratios and for the right-skewed intensity; then z-scores
X <- with(cl_raw, cbind(log_tp_mean = log(tp_mean), tp_change = tp_change, log_op_heterosexual = log(op_heterosexual),
                        log_op_msm = log(op_msm), log_op_female = log(op_female), log_op_male = log(op_male),
                        log_op_disruption = log(op_disruption_total)))
Z <- scale(X); rownames(Z) <- cl_countries; colnames(Z) <- paste0("z_", colnames(X))

silhouette_mean <- function(cl, D) {
  D <- as.matrix(D); n <- nrow(D)
  s <- vapply(seq_len(n), function(i) {
    own <- cl == cl[i]
    if (sum(own) == 1) return(0)
    a <- mean(D[i, own & seq_len(n) != i])
    b <- min(vapply(setdiff(unique(cl), cl[i]), function(k) mean(D[i, cl == k]), 0))
    (b - a) / max(a, b)
  }, 0)
  mean(s)
}
adjusted_rand <- function(a, b) {
  tab <- table(a, b); n <- sum(tab); s2 <- function(x) sum(choose(x, 2))
  idx <- s2(tab); ea <- s2(rowSums(tab)); eb <- s2(colSums(tab)); ex <- ea * eb / choose(n, 2)
  (idx - ex) / ((ea + eb) / 2 - ex)
}
D  <- dist(Z)
hc <- hclust(D, method = "ward.D2")
sil <- data.frame(k = 2:6, mean_silhouette = vapply(2:6, function(k) silhouette_mean(cutree(hc, k), D), 0))
k_best <- sil$k[which.max(sil$mean_silhouette)]
cl_ward <- cutree(hc, k_best)
set.seed(20260430)
km <- kmeans(Z, centers = k_best, nstart = 200)
Z_epi <- Z[, setdiff(colnames(Z), c("z_log_tp_mean", "z_tp_change"))]
cl_epi <- cutree(hclust(dist(Z_epi), method = "ward.D2"), k_best)
agreement <- data.frame(comparison = c("Ward vs k-means (same variables)", "Ward: all variables vs diagnosis variables only"),
                        adjusted_rand_index = c(adjusted_rand(cl_ward, km$cluster), adjusted_rand(cl_ward, cl_epi)))
cl_out <- cbind(cl_raw, Z, cluster_ward = cl_ward, cluster_kmeans = km$cluster, cluster_diagnosis_only = cl_epi)
profiles <- do.call(rbind, lapply(sort(unique(cl_ward)), function(k) {
  r <- cl_raw[cl_ward == k, -1]
  data.frame(cluster = k, n = sum(cl_ward == k), countries = paste(cl_raw$country[cl_ward == k], collapse = ", "),
             t(vapply(r, median, 0)), row.names = NULL)
}))
write.csv(cl_out,    file.path(OUT, "tables", "clustering_countries.csv"), row.names = FALSE)
write.csv(sil,       file.path(OUT, "tables", "clustering_silhouette.csv"), row.names = FALSE)
write.csv(profiles,  file.path(OUT, "tables", "clustering_profiles.csv"), row.names = FALSE)
write.csv(agreement, file.path(OUT, "tables", "clustering_agreement.csv"), row.names = FALSE)
## Ward merge history (for drawing the dendrogram): negative entries are countries in the order of
## clustering_countries.csv, positive entries are earlier merge steps
write.csv(data.frame(merge1 = hc$merge[, 1], merge2 = hc$merge[, 2], height = hc$height),
          file.path(OUT, "tables", "clustering_ward_merge.csv"), row.names = FALSE)

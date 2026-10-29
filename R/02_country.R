## Country-level 2022-2024/2015-2019 diagnosis ratios, inclusion (Table S1), temporary-protection
## intensity, and the secondary associations (Table S3, Figures 2 bottom panels and 3).

counts <- read_counts()
tp <- read_tp()
countries <- setdiff(sort(unique(counts$country)), "Total EU/EEA")

ratios <- do.call(rbind, lapply(SERIES, function(s) {
  m <- counts_matrix(counts, s)[countries, , drop = FALSE]
  base <- rowMeans(m[, as.character(BASE_YRS)])
  post <- rowMeans(m[, as.character(POST_YRS)])
  data.frame(series = s, country = countries, base_mean = base, post_mean = post, ratio = post / base,
             stringsAsFactors = FALSE)
}))
ratios <- merge(ratios, tp[, c("country", "dec2022", "dec2023", "dec2024", "tp_mean", "tp_change")],
                by = "country", all.x = TRUE)
ratios$regional <- ratios$country %in% REGIONAL
## inclusion: 2015-2019 mean >= 20 (>= 5 for MTC); the sex analysis needs both female and male >= 20
ratios$meets_threshold <- ratios$base_mean >= THRESHOLD[ratios$series]
sex_ok <- with(ratios[ratios$series %in% c("female", "male"), ], tapply(base_mean >= 20, country, all))
ratios$meets_threshold[ratios$series %in% c("female", "male")] <- sex_ok[ratios$country[ratios$series %in% c("female", "male")]]
## Transmission-category series of countries with a year in which no diagnosis had a reported transmission
## mode are excluded: the zero is missing data. Among the series meeting the thresholds this excludes only
## Malta's MSM series (2019); the analysis including it is a sensitivity analysis (table_s3_sens).
no_mode <- no_mode_countries(counts)
ratios$no_mode_year <- ratios$series %in% c("heterosexual", "msm", "pwid", "mtc") & ratios$country %in% no_mode
ratios$included <- ratios$meets_threshold & !ratios$no_mode_year
ratios <- ratios[order(ratios$series, ratios$country), ]; rownames(ratios) <- NULL

## Table S1 ("No (missing mode)": meets the threshold but excluded for a year without any reported mode)
yn <- function(x, nm) ifelse(x, "Yes", ifelse(nm, "No (missing mode)", "No"))
inc <- function(s, col = "included") setNames(ratios[[col]][ratios$series == s], ratios$country[ratios$series == s])[countries]
s1 <- function(s) yn(inc(s), inc(s, "meets_threshold") & inc(s, "no_mode_year"))
table_s1 <- data.frame(country = countries, heterosexual = s1("heterosexual"), msm = s1("msm"),
                       pwid = s1("pwid"), mtc = s1("mtc"), sex = s1("female"))
write.csv(no_mode_years(counts), file.path(OUT, "tables", "no_transmission_mode_years.csv"), row.names = FALSE)

## Table S3
table_s3 <- do.call(rbind, lapply(SERIES, function(s) {
  d <- ratios[ratios$series == s & ratios$included, ]
  d$outcome <- d$ratio
  cbind(series = s, association(d, regional_models = s != "mtc"))
}))

## Sensitivity analysis: transmission-category associations including the series excluded for a year
## without any reported transmission mode (in the sets meeting the thresholds: Malta, MSM)
table_s3_sens <- do.call(rbind, lapply(c("heterosexual", "msm", "pwid", "mtc"), function(s) {
  d <- ratios[ratios$series == s & ratios$meets_threshold, ]
  add <- intersect(d$country, no_mode)
  if (length(add) == 0) return(NULL)
  d$outcome <- d$ratio
  cbind(series = s, included_no_mode = paste(add, collapse = ", "), association(d, regional_models = s != "mtc"))
}))

## Sensitivity analysis: associations without the countries in which more than half of the 2024 diagnoses
## had no reported transmission mode (Estonia, Latvia and Poland), for every series that includes them
high_unknown <- high_unknown_mode_countries()
table_s3_hu <- do.call(rbind, lapply(SERIES, function(s) {
  d <- ratios[ratios$series == s & ratios$included, ]
  drop <- intersect(d$country, high_unknown)
  if (length(drop) == 0) return(NULL)
  d <- d[!d$country %in% drop, ]
  d$outcome <- d$ratio
  cbind(series = s, excluded = paste(drop, collapse = ", "), association(d, regional_models = s != "mtc"))
}))

## Table S4: annual MTC diagnoses in the countries of the MTC analysis, their sum, and the EU/EEA total
mtc_m <- counts_matrix(counts, "mtc")
mtc_c <- ratios$country[ratios$series == "mtc" & ratios$included]
mtc_in   <- colSums(mtc_m[mtc_c, as.character(YEARS), drop = FALSE])
mtc_rows <- rbind(mtc_m[mtc_c, as.character(YEARS), drop = FALSE],
                  "Countries in the MTC analysis" = mtc_in,
                  "Other EU/EEA countries" = mtc_m["Total EU/EEA", as.character(YEARS)] - mtc_in,
                  "Total EU/EEA" = mtc_m["Total EU/EEA", as.character(YEARS)])
table_s4 <- data.frame(country = rownames(mtc_rows), mtc_rows, check.names = FALSE, row.names = NULL)
table_s4$base_mean <- rowMeans(mtc_rows[, as.character(BASE_YRS)])
table_s4$post_mean <- rowMeans(mtc_rows[, as.character(POST_YRS)])
table_s4$ratio     <- table_s4$post_mean / table_s4$base_mean

## Unadjusted OLS fits with and without Czechia (solid and dashed lines in Figures 2C-D and 3A-B)
fits_cz <- do.call(rbind, lapply(SERIES, function(s) {
  d <- ratios[ratios$series == s & ratios$included, ]
  if (!"Czechia" %in% d$country) return(NULL)
  w <- d[d$country != "Czechia", ]
  f_all <- lm(ratio ~ tp_mean, data = d); f_wo <- lm(ratio ~ tp_mean, data = w)
  data.frame(series = s, n_all = nrow(d), intercept_all = unname(coef(f_all)[1]), slope_all = unname(coef(f_all)[2]),
             n_without = nrow(w), intercept_without = unname(coef(f_wo)[1]), slope_without = unname(coef(f_wo)[2]),
             pearson_r_without = cor(w$tp_mean, w$ratio))
}))

write.csv(ratios,   file.path(OUT, "tables", "country_ratios.csv"), row.names = FALSE)
write.csv(table_s3_sens, file.path(OUT, "tables", "table_s3_sensitivity_missing_mode.csv"), row.names = FALSE)
write.csv(table_s3_hu, file.path(OUT, "tables", "table_s3_sensitivity_high_unknown_mode.csv"), row.names = FALSE)
write.csv(table_s4, file.path(OUT, "tables", "table_s4_mtc_counts.csv"), row.names = FALSE)
write.csv(fits_cz,  file.path(OUT, "tables", "ols_fits_with_without_czechia.csv"), row.names = FALSE)
write.csv(table_s1, file.path(OUT, "tables", "table_s1_inclusion.csv"), row.names = FALSE)
write.csv(table_s3, file.path(OUT, "tables", "table_s3_associations.csv"), row.names = FALSE)
write.csv(tp,       file.path(OUT, "tables", "temporary_protection_intensity.csv"), row.names = FALSE)

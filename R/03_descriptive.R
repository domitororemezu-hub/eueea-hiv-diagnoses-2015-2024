## Descriptive analyses: 2024 completeness, CEE-origin series (Figure 4) and the illustrative
## four-country comparator (Additional file 6: Figure S1).

## ---- 2024 completeness (ECDC 2025 report, Tables 2, 3, 8 and 10) -------------------------------
t8  <- read.csv("data/raw/ecdc2025_table8_2024.csv", check.names = FALSE, stringsAsFactors = FALSE)
t10 <- read.csv("data/raw/ecdc2025_table10_2024.csv", check.names = FALSE, stringsAsFactors = FALSE)
counts <- read_counts()
eu8  <- t8[t8$country == "Total EU/EEA", ]
eu10 <- t10[t10$country == "Total EU/EEA", ]
n_all    <- as.numeric(eu10$total)                                     # all 2024 diagnoses
n_female <- counts$n[counts$series == "female" & counts$country == "Total EU/EEA" & counts$year == 2024]
n_male   <- counts$n[counts$series == "male" & counts$country == "Total EU/EEA" & counts$year == 2024]
n_trans  <- sum(as.numeric(eu8[grep("_trans$", names(eu8))]))
n_t8     <- as.numeric(eu8$total)                                      # records with a male, female or transgender category
c8 <- t8[t8$country != "Total EU/EEA", ]
c10 <- t10[t10$country != "Total EU/EEA", ]
completeness <- data.frame(
  measure = c("all diagnoses", "female or male", "transgender", "unknown gender",
              "records in Table 8", "unknown transmission mode", "unknown region of origin"),
  n = c(n_all, n_female + n_male, n_trans, n_all - n_t8, n_t8, as.numeric(eu8$unk_total), as.numeric(eu10$unknown_n)),
  denominator = c(n_all, n_all, n_all, n_all, n_all, n_t8, n_all))
completeness$pct <- 100 * completeness$n / completeness$denominator
unknown_mode_by_country <- data.frame(country = c8$country, unknown = as.numeric(c8$unk_total),
                                      total = as.numeric(c8$total))
unknown_mode_by_country$pct <- 100 * unknown_mode_by_country$unknown / unknown_mode_by_country$total
unknown_origin_by_country <- data.frame(country = c10$country, unknown = as.numeric(c10$unknown_n),
                                        total = suppressWarnings(as.numeric(c10$total)))
unknown_origin_by_country$pct <- 100 * unknown_origin_by_country$unknown / unknown_origin_by_country$total

write.csv(completeness, file.path(OUT, "tables", "completeness_2024.csv"), row.names = FALSE)
write.csv(unknown_mode_by_country, file.path(OUT, "tables", "unknown_transmission_2024_by_country.csv"), row.names = FALSE)
write.csv(unknown_origin_by_country, file.path(OUT, "tables", "unknown_origin_2024_by_country.csv"), row.names = FALSE)

## ---- CEE-origin diagnoses, nine host countries (Figure 4) --------------------------------------
origin <- read.csv("data/raw/ecdc_origin_cee_2015-2024.csv", stringsAsFactors = FALSE)
FIG4_COUNTRIES <- c("Germany", "Poland", "Czechia", "Netherlands", "Italy", "Belgium", "Ireland", "Spain", "Slovakia")
cee <- origin[origin$country %in% FIG4_COUNTRIES, c("year", "country", "cee_n", "unknown_n", "total_n")]
write.csv(cee, file.path(OUT, "tables", "cee_origin_nine_countries.csv"), row.names = FALSE)

## ---- illustrative four-country comparator (heterosexual series) --------------------------------
COMPARATOR_SEEDS <- c(Spain = 20260426, Czechia = 20260427, Poland = 20260428, Germany = 20260429)
het <- counts_matrix(counts, "heterosexual")
comparator <- do.call(rbind, lapply(names(COMPARATOR_SEEDS), function(cn) {
  y <- as.numeric(het[cn, as.character(YEARS)])
  nb <- fit_nb(y[1:5])
  e <- as.numeric(predict(nb, newdata = data.frame(t = 5:9), type = "response"))
  L <- sim_limits_nb(coef(nb), vcov(nb), nb$theta, COMPARATOR_SEEDS[[cn]])
  data.frame(country = cn, year = YEARS, observed = y, expected = c(rep(NA, 5), e),
             lo = c(rep(NA, 5), L[, 1]), hi = c(rep(NA, 5), L[, 2]),
             class = c(rep(NA, 5), classify(y[6:10], L[, 1], L[, 2])),
             theta = nb$theta, glm_nb_warnings = paste(nb$fit_warnings, collapse = "; "))
}))
write.csv(comparator, file.path(OUT, "tables", "comparator_four_countries.csv"), row.names = FALSE)

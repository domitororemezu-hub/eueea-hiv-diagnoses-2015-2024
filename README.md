# Persistent departures from pre-COVID HIV diagnosis trends in the EU/EEA, 2022–2024: code and data

Analysis code, extracted public data and results for:

> Remez D, Mori H, Krokva D, Lumjiaktase P, Frutos R, Cornillot E, Hadano Y, Itoh N, Naito T. Persistent departures
> from pre-COVID HIV diagnosis trends in the EU/EEA, 2022–2024: an ecological analysis by transmission category, sex,
> and country. [Journal, year, DOI — to be added on publication.]

Code author: Dmytro Remez. Each release of this repository is archived on Zenodo; the DOI of the version used in
the article (1.0.0) is given in its Availability of data and materials section.

The analysis uses only published, aggregate, country-level data: annual HIV diagnoses from the ECDC/WHO Regional
Office for Europe *HIV/AIDS surveillance in Europe* reports (data years 2015–2024) and Ukrainian beneficiaries of
temporary protection per 1,000 persons from Eurostat (dataset `migr_asytpspop`). No individual-level data are used.

## Contents

| Path | Content |
|---|---|
| `data/raw/` | The extracted source data (5 CSV files); provenance, tables, pages and access dates in `data/SOURCES.md` |
| `R/00_setup.R` | Settings, data readers and model functions shared by all scripts |
| `R/01_aggregate.R` | EU/EEA benchmarks (negative binomial, quasi-Poisson, OLS), θ and its sensitivity analysis, cumulative totals, period means, female share, benchmarks without the countries with largely unknown transmission mode |
| `R/02_country.R` | Country-level period ratios, inclusion (Table S1), associations with temporary-protection intensity and their sensitivity analyses (Table S3), MTC counts (Table S4), fits without Czechia |
| `R/03_descriptive.R` | 2024 completeness, region-of-origin series (Figure 4), four-country comparator (Figure S1) |
| `R/04_new_analyses.R` | Additional exploratory analyses: trajectory deviation map, country-level observed/projected ratios, clustering |
| `R/05_convergence_checks.R` | Convergence checks of every negative binomial model: refits with other iteration limits, tolerance and starting values, and explicit Poisson models (Additional file 3, S1.6) |
| `run_all.R` | Runs the five scripts in order and writes all result tables to `output/tables` |
| `check_outputs.R` | Re-runs everything into `output_check/` and compares every table with the reference results in `output/` |
| `figures/make_figures.py` | Draws Figures 1–4 and S1–S4 from the result tables, at print size (170 mm wide, text ≥ 8 pt, 600 dpi) |
| `output/tables/` | Reference results (33 CSV files); every number in the article and its additional files comes from these tables |
| `output/figures/` | The figures as submitted |
| `output/sessionInfo.txt` | R and package versions of the reference run |

## How to run

Requirements: R (≥ 4.0) with the CRAN packages MASS and sandwich; for the figures, Python 3 with matplotlib, numpy
and scipy. From the repository root:

```
Rscript run_all.R                  # result tables -> output/tables (about three minutes)
python3 figures/make_figures.py    # figures -> output/figures
Rscript check_outputs.R            # optional: re-run into output_check/ and compare with output/
```

## Where the results in the article come from

| Article | Script | Result table(s) |
|---|---|---|
| Figure 1, Figure 2A–B, Additional file 4 (Table S2) | `R/01_aggregate.R` | `benchmarks_2020_2024.csv`, `theta_and_period_means.csv` |
| Benchmarks without Estonia, Latvia and Poland (Results; Table S2, last block; Additional file 3, S1.5) | `R/01_aggregate.R` | `benchmarks_without_high_unknown_mode.csv` |
| Fitted θ and the θ sensitivity analysis (Additional file 3, S1.1 and S1.3; Limitations) | `R/01_aggregate.R` | `theta_and_period_means.csv`; `thetaL_*` columns of `benchmarks_2020_2024.csv` |
| Cumulative observed − projected diagnoses (Discussion; Figure S2B) | `R/01_aggregate.R` | `cumulative_observed_minus_expected.csv` |
| Female share (Results) | `R/01_aggregate.R` | `female_share.csv` |
| Additional file 2 (Table S1), including the years without any reported transmission mode | `R/02_country.R` | `table_s1_inclusion.csv`, `no_transmission_mode_years.csv` |
| Country ratios (Results), Figure 2C–D, Figure 3 | `R/02_country.R` | `country_ratios.csv`, `temporary_protection_intensity.csv`, `ols_fits_with_without_czechia.csv` (dashed lines) |
| Additional file 5 (Table S3), including the MSM analysis with Malta and the analyses without Estonia, Latvia and Poland | `R/02_country.R` | `table_s3_associations.csv`, `table_s3_sensitivity_missing_mode.csv`, `table_s3_sensitivity_high_unknown_mode.csv` |
| Additional file 5 (Table S4): annual MTC diagnoses in the nine countries | `R/02_country.R` | `table_s4_mtc_counts.csv` |
| Data completeness, 2024 (Results) | `R/03_descriptive.R` | `completeness_2024.csv`, `unknown_transmission_2024_by_country.csv`, `unknown_origin_2024_by_country.csv` |
| Figure 4 | `R/03_descriptive.R` | `cee_origin_nine_countries.csv` |
| Additional file 6 (Figure S1) | `R/03_descriptive.R` | `comparator_four_countries.csv` |
| Additional file 7: Figure S2A | `R/04_new_analyses.R` | `deviation_map.csv` |
| Additional file 7: Figure S3, Tables S5–S6 | `R/04_new_analyses.R` | `country_observed_predicted.csv`, `observed_predicted_associations.csv`, `observed_predicted_summary.csv`, `observed_predicted_exclusions.csv` |
| Additional file 7: Figure S4 | `R/04_new_analyses.R` | `clustering_*.csv` |
| Convergence checks (Methods; Additional file 3, S1.6) | `R/05_convergence_checks.R` | `convergence_summary.csv`, `convergence_aggregate.csv`, `convergence_comparator.csv`, `convergence_country.csv` |

File and column names use "observed/predicted" (`op_`) for what the article calls observed/projected ratios.

Missing transmission mode. In three country-years (Iceland 2015, Malta 2019, Liechtenstein 2022) diagnoses were
reported but none had a reported transmission mode, so the four transmission-category counts are zero
(`no_transmission_mode_years.csv`). Such a zero is missing data, so the transmission-category series of these
countries are excluded from all country-level analyses (`included` = FALSE, `no_mode_year` = TRUE in
`country_ratios.csv`; "No (missing mode)" in `table_s1_inclusion.csv`, shown as "No" with the reason in Table S1).
Among the series meeting the inclusion thresholds this excludes only Malta's MSM series; the MSM analysis including
Malta is the sensitivity analysis in `table_s3_sensitivity_missing_mode.csv`. The female and male totals do not
depend on transmission mode, and the EU/EEA aggregate series are used as published.

## Reproducibility notes

- All random numbers come from fixed seeds: 20260420–20260425 for the six EU/EEA series (heterosexual, MSM, PWID,
  MTC, female, male), the same seeds plus 2 for the θ sensitivity analysis, plus 3 for the cumulative totals and plus 4
  for the benchmarks without Estonia, Latvia and Poland, 20260426–20260429 for the four-country comparator (Spain,
  Czechia, Poland, Germany) and 20260430 for k-means. R's default random-number generators are assumed (R ≥ 3.6.0).
- The reference results were produced with a standard build of R 4.4.1 on x86_64 Linux with R's reference BLAS and
  LAPACK, MASS 7.3-65 and sandwich 3.1-1 (`output/sessionInfo.txt`). `check_outputs.R` reproduces every table exactly
  in that setting and also with R 4.3.3, MASS 7.3-60.0.1 and sandwich 3.1-0 (Ubuntu 24.04 packages).
- Everything except the Monte Carlo prediction limits is deterministic. Two things can move a simulated limit by one
  or a few diagnoses on other systems:
  - For series without overdispersion (MSM and PWID, and many country series), θ has no finite estimate and `glm.nb`
    stops at a very large, arbitrary value that depends on floating-point details. In the WebAssembly build of R used
    by webR 0.4.2, this moves the MSM 2024 limits and two cumulative MSM upper limits by one diagnosis.
  - `MASS::mvrnorm` draws through an eigendecomposition; with an optimised linear-algebra library (OpenBLAS, MKL,
    Apple Accelerate) the eigenvector signs can differ from R's reference LAPACK.
  `check_outputs.R` lists the tables affected. In our tests no classification and no other result changed.
- `glm.nb` reports "iteration limit reached" when a series shows no overdispersion relative to the Poisson
  distribution (θ has no finite estimate and the model equals a Poisson model) and sometimes "alternation limit
  reached"; these warnings are expected and are stored in the result tables instead of being printed.
  `R/05_convergence_checks.R` refits every negative binomial model with `maxit` = 100 and 1,000 (tolerance 1e-12),
  starting θ of 1, 1,000 and 10^7 and flat starting coefficients, and fits explicit Poisson models to the series
  without overdispersion. No projection changed by more than 0.002%, no simulated prediction limit by more than two
  diagnoses, and no classification changed (`convergence_summary.csv`). When θ has no finite estimate it diverges
  during estimation, and some refits of each kind stop with a numerical error (221 of 972, all in series without
  overdispersion); they are counted in `refits_failed`, and for these series the explicit Poisson fits provide the
  comparison. With the 1e-12 tolerance, glm.fit itself reports non-convergence for some series, because that tolerance
  is close to machine precision; the estimates nevertheless agree to the precision shown.
- Spearman p-values use the asymptotic t approximation (`cor.test(..., exact = FALSE)`).

## Licence

Code: MIT licence (`LICENSE`). Data: extracted from the cited ECDC/WHO and Eurostat publications; the reuse
conditions of each source are given in `data/SOURCES.md`.

## Citation

Please cite the article; `CITATION.cff` describes this repository.

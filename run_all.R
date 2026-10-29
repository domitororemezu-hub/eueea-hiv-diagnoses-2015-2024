## Runs the complete analysis from the raw data files in data/raw and writes all result tables to
## output/tables. Run from the repository root:  Rscript run_all.R   (about three minutes)
## Requires R (>= 4.0) with the MASS and sandwich packages.

source("R/00_setup.R")
source("R/01_aggregate.R")       # Table S2, Figures 1-2 (top), theta, cumulative observed - expected,
                                 #   benchmarks without the countries with largely unknown transmission mode
source("R/02_country.R")         # Tables S1, S3 and S4, Figures 2 (bottom) and 3 (with the fits without Czechia)
source("R/03_descriptive.R")     # 2024 completeness, Figure 4, Figure S1
source("R/04_new_analyses.R")    # deviation map, country observed/predicted, clustering
source("R/05_convergence_checks.R") # convergence checks of all negative binomial fits (Additional file 3, S1.6)
writeLines(capture.output(sessionInfo()), file.path(OUT, "sessionInfo.txt"))
cat("Done. Tables written to", file.path(OUT, "tables"), "\n")

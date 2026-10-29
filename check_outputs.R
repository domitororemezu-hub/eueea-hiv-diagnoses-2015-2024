## Re-runs the complete analysis into output_check/ and compares every result table with the reference
## results in output/. Run from the repository root:  Rscript check_outputs.R
## Numbers are compared with a relative tolerance of 1e-9; text and whole numbers must match exactly.
Sys.setenv(HIV_OUT = "output_check")
source("run_all.R")

ref_dir <- file.path("output", "tables")
new_dir <- file.path("output_check", "tables")
files <- sort(list.files(ref_dir, pattern = "\\.csv$"))
compare <- function(a, b) {
  if (!identical(dim(a), dim(b)) || !identical(names(a), names(b))) return("different structure")
  bad <- 0
  for (j in seq_along(a)) {
    x <- a[[j]]; y <- b[[j]]
    if (is.numeric(x) && is.numeric(y)) {
      same <- (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & (x == y | abs(x - y) <= 1e-9 * pmax(1, abs(x))))
    } else {
      same <- (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & as.character(x) == as.character(y))
    }
    bad <- bad + sum(!same)
  }
  if (bad == 0) "identical" else paste(bad, "value(s) differ")
}
result <- vapply(files, function(f) {
  if (!file.exists(file.path(new_dir, f))) return("missing")
  compare(read.csv(file.path(ref_dir, f), stringsAsFactors = FALSE),
          read.csv(file.path(new_dir, f), stringsAsFactors = FALSE))
}, "")
print(data.frame(table = files, result = unname(result)), row.names = FALSE)
cat(if (all(result == "identical")) "\nAll result tables were reproduced.\n" else
      "\nSome tables differ (see above and the README section on reproducibility).\n")

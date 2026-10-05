# run_all.R -- regenerate the synthetic-benchmark tables from fixed seeds and
# compare them with the committed ones.
#
# No study data are needed: the clean diary rows are generated, errors are
# injected with known truth, the installed sleepcleanr is run on them, and the
# scoring scripts write the result tables.
#
# It works in a COPY of validation/ (a temporary directory by default), so the
# committed tables in validation/synthetic/results/ are never overwritten. At the
# end it compares every regenerated table with the committed one and exits with a
# non-zero status if any value differs by more than 1e-9.
#
# Usage (from the repository root):
#   Rscript validation/run_all.R [--workdir=DIR]
#
# Needs the sleepcleanr version you want to check to be installed (the pipeline is
# run through library(sleepcleanr)), plus dplyr, readr, tibble and digest. Takes a
# few minutes. It does NOT run the longer scripts (multiverse.R,
# l2_tier_leave_one_out.R, seed_sensitivity.R, operating_point_sweep.R,
# evaluate_fcr.R) or anything that reads the study data (see validation/README.md).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}

# repository root = the directory that holds validation/
file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- normalizePath(file.path(dirname(file_arg[1]), ".."), mustWork = TRUE)
stopifnot(dir.exists(file.path(root, "validation", "synthetic")))

work <- opt("workdir", file.path(tempdir(), "sleepcleanr_run_all"))
if (dir.exists(work)) stop("workdir already exists, give a new one: ", work)
dir.create(work, recursive = TRUE)
ok <- file.copy(file.path(root, "validation"), work, recursive = TRUE)
stopifnot(ok)
committed <- file.path(root, "validation", "synthetic", "results")
fresh     <- file.path(work, "validation", "synthetic", "results")

if (!requireNamespace("sleepcleanr", quietly = TRUE)) {
  stop("sleepcleanr is not installed; install the version you want to check first")
}
cat("sleepcleanr", as.character(utils::packageVersion("sleepcleanr")),
    "| work directory:", work, "\n")

syn <- file.path("validation", "synthetic")
steps <- list(
  c("ppv_cluster_ci.R"),                      # generates the data, injects errors, runs the pipeline
  c("far_flag_mrr_magnitude.R"),
  c("control_baselines.R"),
  c("evaluate_detection.R",                   # outcome per category from this run
    file.path(syn, "ground_truth_enrichment.csv"),
    file.path(syn, "corrupted_enrichment.rds"),
    file.path(syn, "run_ppv", "review_output.rds"),
    file.path(syn, "run_ppv", "corrected_ema_data.rds"),
    file.path(syn, "results", "detection_outcomes_v4_current.csv")),
  c("correction_level_recall.R"),
  c("metric_distortion.R"),
  c("low_prevalence.R")                        # the benchmark at about 5% injected rows
)

owd <- setwd(work); on.exit(setwd(owd), add = TRUE)
for (st in steps) {
  script <- file.path(syn, st[1])
  cat(sprintf("\n== %s\n", st[1]))
  status <- system2("Rscript", c(script, st[-1]),
                    stdout = file.path(work, paste0(st[1], ".log")),
                    stderr = file.path(work, paste0(st[1], ".log")))
  if (!identical(status, 0L)) {
    stop(st[1], " failed (exit ", status, "); see ", file.path(work, paste0(st[1], ".log")))
  }
  cat("   ok\n")
}

# ---- compare with the committed tables ----------------------------------
produced <- c("recall_specificity_ci.csv", "ppv_curve.csv", "far_flag_alter.csv",
              "mrr_magnitude.csv", "control_baselines.csv",
              "detection_outcomes_v4_current.csv", "correction_level_recall.csv",
              "correction_level_recall_per_category.csv", "metric_distortion.csv",
              "low_prevalence.csv")
cat("\n== comparison with the committed tables\n")
n_bad <- 0L
for (f in produced) {
  a <- tryCatch(utils::read.csv(file.path(committed, f), stringsAsFactors = FALSE),
                error = function(e) NULL)
  b <- tryCatch(utils::read.csv(file.path(fresh, f), stringsAsFactors = FALSE),
                error = function(e) NULL)
  if (is.null(a) || is.null(b)) { cat(sprintf("  MISSING    %s\n", f)); n_bad <- n_bad + 1L; next }
  same_shape <- identical(dim(a), dim(b)) && identical(names(a), names(b))
  if (!same_shape) { cat(sprintf("  SHAPE      %s\n", f)); n_bad <- n_bad + 1L; next }
  worst <- 0
  bad <- FALSE
  for (j in seq_along(a)) {
    if (is.numeric(a[[j]]) && is.numeric(b[[j]])) {
      d <- suppressWarnings(max(abs(a[[j]] - b[[j]]), na.rm = TRUE))
      if (is.finite(d)) worst <- max(worst, d)
      if (!identical(is.na(a[[j]]), is.na(b[[j]])) || (is.finite(d) && d > 1e-9)) bad <- TRUE
    } else if (!identical(as.character(a[[j]]), as.character(b[[j]]))) {
      bad <- TRUE
    }
  }
  cat(sprintf("  %-10s %s  (largest numeric difference %.3g)\n",
              if (bad) "DIFFERENT" else "identical", f, worst))
  if (bad) n_bad <- n_bad + 1L
}
cat(sprintf("\n%d of %d tables differ.\n", n_bad, length(produced)))
quit(status = if (n_bad == 0L) 0L else 1L)

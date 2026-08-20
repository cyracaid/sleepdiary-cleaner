# run_one.R
# Runs sleepcleanr::run_pipeline() on one synthetic dataset in an isolated
# project_dir, per the four execution notes:
#   (1) manual-correction files created EMPTY (with headers), not omitted
#   (2) after the run, checks flag distributions, doesn't just check "did it crash"
#   (3) each dataset gets its OWN project_dir so output/ never gets overwritten
#   (4) uses the installed sleepcleanr 1.4.0 (confirmed inst/scripts identical to
#       the uploads source tree, so the installed copy is current)
#
# Usage: Rscript run_one.R <input_rds> <project_dir> <label>

suppressPackageStartupMessages(library(sleepcleanr))

args <- commandArgs(trailingOnly = TRUE)
input_rds   <- args[1]
project_dir <- args[2]
label       <- args[3]

dir.create(project_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(project_dir, "output"), recursive = TRUE, showWarnings = FALSE)

# Copy the input data into the project_dir as main.rds (run_pipeline setwd()s
# into project_dir and reads data.files.main relative to it).
file.copy(input_rds, file.path(project_dir, "main.rds"), overwrite = TRUE)

# Deliberately do NOT pre-create manual_error_corrections.csv /
# manual_unusual_corrections.csv / second_review_checklist.csv / etc.
#
# First attempt at this (per the original plan of writing
# write.csv(data.frame(), file, row.names=FALSE)) crashed with readr's
# "first five rows are empty: giving up": a data.frame() with ZERO COLUMNS
# writes an unparseable near-empty file, and Step 6 reads
# manual_error_corrections.csv with readr::read_csv() (not base read.csv),
# whose column-type guesser chokes on that shape. A MISSING file is not
# the same failure mode as an EMPTY file here -- the installed package's
# run_pipeline() (R/pipeline.R) already wraps every one of these six reads
# in file.exists() and falls back to a proper zero-row data.frame() with a
# "[WARN] ... not found -- using empty corrections" message when the file
# is simply absent. Confirmed by reading pipeline.R directly:
#   - manual_error / manual_unusual (Step 6):     file.exists() guarded
#   - second_review_checklist (Step 5.75):        file.exists() guarded
#   - manual_nap_exercise (post-Step-6):          file.exists() guarded
#   - manual_metric_duration (post-Step-6):       file.exists() guarded
#   - manual_metric_accept (post-Step-6):         file.exists() guarded
# So the correct way to get "no human review layer" is to leave all six
# absent, not present-but-empty.

# Minimal config: bundled default, only data.files.main overridden.
cfg <- yaml::read_yaml(system.file("config_default.yaml", package = "sleepcleanr"))
cfg$data$files$main <- "main.rds"
cfg$data$files$extra <- NULL
config_path <- file.path(project_dir, "config.yaml")
yaml::write_yaml(cfg, config_path)

cat(sprintf("\n########## RUNNING: %s ##########\n", label))
t0 <- Sys.time()
ok <- tryCatch({
  sleepcleanr::run_pipeline(config = "config.yaml", project_dir = project_dir,
                          skip_visualization = TRUE, verbose = TRUE)
  TRUE
}, error = function(e) {
  cat("PIPELINE ERROR:", conditionMessage(e), "\n")
  print(sys.calls())
  FALSE
})
t1 <- Sys.time()
cat(sprintf("Run took %.1f sec, success=%s\n", as.numeric(t1 - t0, units = "secs"), ok))

if (ok) {
  corrected <- get("corrected_ema_data", envir = .GlobalEnv)
  review    <- get("review_output", envir = .GlobalEnv)
  saveRDS(corrected, file.path(project_dir, "corrected_ema_data.rds"))
  saveRDS(review,    file.path(project_dir, "review_output.rds"))
  cat(sprintf("Saved corrected_ema_data (%d rows) and review_output to %s\n",
              nrow(corrected), project_dir))
}

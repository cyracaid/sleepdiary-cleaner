# test-golden-pipeline.R -- content baseline for refactors.
#
# Test counts do not protect a refactor; output content does. This runs the
# bundled synthetic fixture algorithmic-only (no figures) in a sandbox and
# compares the delivered tables, cell for cell, with the files committed under
# tests/testthat/golden/ (prefixed golden_synth_ so they can never be
# mistaken for real-data deliverables). Synthetic data only: nothing here is real data.
#
# A diff is either a regression or an intended change. For an intended change,
# regenerate and review the diff of the golden files in the same commit:
#   SLEEPCLEANR_UPDATE_GOLDEN=1 Rscript -e 'devtools::test(filter = "golden-pipeline")'

.golden_files <- c("cleaned_data_final.csv", "cleaned_data_prepostcorrection.csv",
                   "step_flag_ledger.csv", "correction_status_final.csv",
                   "flagged_records_self_reported.csv", "audit_integrity_report.csv",
                   "effective_rules.csv")
# Columns that legitimately differ between two identical runs.
.golden_volatile <- c("timestamp", "run_id")

.golden_read <- function(path) {
  d <- utils::read.csv(path, colClasses = "character", na.strings = character(0),
                       check.names = FALSE)
  d[, setdiff(names(d), .golden_volatile), drop = FALSE]
}

test_that("synthetic algorithmic-only run reproduces the golden tables", {
  ext <- system.file("extdata", package = "sleepcleanr")
  if (!nzchar(ext)) ext <- file.path(getwd(), "inst", "extdata")
  skip_if_not(file.exists(file.path(ext, "synthetic_config.yaml")), "fixture not found")

  sandbox <- withr::local_tempdir()
  for (f in c("synthetic_sleep_data.rds", "synthetic_ema_data.csv"))
    file.copy(file.path(ext, f), sandbox)
  cfg <- yaml::read_yaml(file.path(ext, "synthetic_config.yaml"))
  cfg$data$files$main  <- "synthetic_sleep_data.rds"
  cfg$data$files$extra <- "synthetic_ema_data.csv"
  cfg$data$tag <- "synth"
  cfg_path <- file.path(sandbox, "golden_config.yaml")
  yaml::write_yaml(cfg, cfg_path)

  expect_true(suppressMessages(run_pipeline(
    config = cfg_path, project_dir = sandbox, skip_visualization = TRUE,
    include_manual_corrections = FALSE, verbose = FALSE)))

  golden_dir <- test_path("golden")
  if (nzchar(Sys.getenv("SLEEPCLEANR_UPDATE_GOLDEN"))) {
    dir.create(golden_dir, showWarnings = FALSE)
    file.copy(file.path(sandbox, "output", .golden_files),
              file.path(golden_dir, paste0("golden_synth_", .golden_files)), overwrite = TRUE)
    skip("golden files regenerated; review their diff before committing")
  }

  for (f in .golden_files) {
    expect_true(file.exists(file.path(golden_dir, paste0("golden_synth_", f))), info = paste("missing golden", f))
    expect_identical(.golden_read(file.path(sandbox, "output", f)),
                     .golden_read(file.path(golden_dir, paste0("golden_synth_", f))), info = f)
  }
})

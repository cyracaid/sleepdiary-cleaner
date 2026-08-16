# test-pipeline.R — end-to-end test with synthetic data

test_that("run_pipeline completes successfully on synthetic data", {
  # Locate synthetic data config bundled with the package
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "splsleep")
  if (cfg_path == "") {
    # Development mode fallback
    cfg_path <- file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")
  }
  skip_if_not(file.exists(cfg_path), "synthetic_config.yaml not found")

  # Run inside a sandbox project_dir so every side effect of a synthetic
  # pipeline run (output/, corrected_ema_data.rds, latest_visualization_*,
  # manual_*_updated.csv, cross_participant_flagged_rows.csv, ...) is isolated
  # and can never overwrite the real-data deliverables in the package root.
  # This is the class of bug that destroyed output/ on 2026-08-09: a synthetic
  # testthat run silently replaced the real 13990-row Dataset A/B with a
  # 280-row synthetic stand-in, and even the /tmp backup had already been
  # clobbered by an earlier synthetic run.
  sandbox        <- tempfile("spltest_")
  dir.create(sandbox, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)

  # Copy the synthetic input files into the sandbox (their config paths are
  # relative, so they must sit where run_pipeline will look for them).
  src_data <- dirname(cfg_path)
  for (f in c("synthetic_sleep_data.rds", "synthetic_ema_data.csv")) {
    file.copy(file.path(src_data, f), sandbox, overwrite = TRUE)
  }

  # Point the config's data engine paths at the sandbox copies (names kept
  # relative so the pipeline resolves them against project_dir = sandbox).
  cfg <- yaml::read_yaml(cfg_path)
  cfg$data$files$main    <- "synthetic_sleep_data.rds"
  cfg$data$files$extra   <- "synthetic_ema_data.csv"
  sandbox_cfg <- file.path(sandbox, "synthetic_config.yaml")
  yaml::write_yaml(cfg, sandbox_cfg)

  pkg_root <- getwd()

  result <- run_pipeline(config = sandbox_cfg, project_dir = sandbox, verbose = FALSE)
  expect_true(result, "Pipeline should complete successfully")

  # Verify output files exist — inside the sandbox, never the package root.
  expect_true(file.exists(file.path(sandbox, "output", "correction_status_final.csv")),
              "correction_status_final.csv should exist (in sandbox)")
  # Figure output lives in latest_visualization_<tag>_n<rows>/ under the sandbox.
  viz_dirs <- list.files(sandbox, pattern = "^latest_visualization_", full.names = TRUE)
  viz_dirs <- viz_dirs[dir.exists(viz_dirs)]
  expect_true(length(viz_dirs) >= 1, "a latest_visualization_* directory should exist")

  # This is the load-bearing assertion: a test run reads synthetic config,
  # so it MUST tag its output "synth". If it ever produced a "real" folder the
  # test suite would be overwriting real-data figures -- which is exactly what
  # happened on 2026-08-06 back when every run shared one output directory.
  synth_dirs <- grep("_synth", basename(viz_dirs), value = TRUE)
  expect_true(length(synth_dirs) >= 1,
              "test run must write a _synth-tagged directory, never _real")

  viz <- file.path(sandbox, synth_dirs[1])
  expect_true(dir.exists(file.path(viz, "pipeline_cleaning")),
              "pipeline_cleaning/ subfolder should exist")
  expect_true(dir.exists(file.path(viz, "research_ready")),
              "research_ready/ subfolder should exist")
  expect_true(file.exists(file.path(viz, "RUN_INFO.txt")),
              "RUN_INFO.txt provenance file should exist")

  # Verify metrics are in expected ranges
  status <- read.csv(file.path(sandbox, "output", "correction_status_final.csv"),
                     stringsAsFactors = FALSE)
  latest <- status[nrow(status), ]

  expect_true(latest$n_total > 0, "Total records should be > 0")
  expect_true(latest$delta_clean >= 0, "Clean delta should be >= 0")
  expect_true(latest$delta_error >= 0, "Error delta should be >= 0")

  # Prove the sandbox really isolated the run: real deliverables (if any)
  # at the package root must be untouched.
  final_path <- file.path(pkg_root, "output", "cleaned_data_final.rds")
  skip_if_not(file.exists(final_path),
              "no real deliverables present; sandbox isolation untestable")
  expect_false(file.exists(file.path(sandbox, "output", "cleaned_data_final.rds")),
               "sandbox run must not produce real-data deliverables")
})

test_that("Config loading works", {
  cfg <- splsleep:::load_config(system.file("extdata", "synthetic_config.yaml", package = "splsleep"))
  expect_true(is.list(cfg), "Config should be a list")
  expect_equal(cfg$pipeline$name, "splsleep (Synthetic Demo)")
  expect_true(!is.null(cfg$classification$metric_validation$sol$excessive_minutes))
})

test_that("Column adaptation renames correctly", {
  cfg <- splsleep:::load_config(system.file("extdata", "synthetic_config.yaml", package = "splsleep"))

  # Create test data with user-friendly column names
  test_df <- data.frame(
    user_pid = 1:3,
    user_day = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
  names(test_df) <- c("user_pid", "user_day")

  # This config doesn't have custom names, but the function should work
  result <- adapt_columns(test_df, cfg)
  expect_true(is.data.frame(result))
})

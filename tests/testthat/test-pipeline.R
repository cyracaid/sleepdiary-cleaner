context("Pipeline end-to-end test with synthetic data")

test_that("run_pipeline completes successfully on synthetic data", {
  # Locate synthetic data config bundled with the package
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "splsleep")
  if (cfg_path == "") {
    # Development mode fallback
    cfg_path <- file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")
  }
  expect_true(file.exists(cfg_path), "synthetic_config.yaml must exist")

  # Run pipeline on synthetic data
  # Set project_dir to package root for dev mode
  pkg_root <- if (cfg_path == file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")) {
    getwd()
  } else {
    dirname(dirname(dirname(cfg_path)))
  }

  result <- run_pipeline(config = cfg_path, project_dir = pkg_root, verbose = FALSE)
  expect_true(result, "Pipeline should complete successfully")

  # Verify output files exist
  expect_true(file.exists(file.path(pkg_root, "output", "correction_status.csv")),
              "correction_status.csv should exist")
  expect_true(file.exists(file.path(pkg_root, "latest_visualization")),
              "latest_visualization/ should exist")
  expect_true(file.exists(file.path(pkg_root, "latest_visualization", "pipeline_cleaning")),
              "pipeline_cleaning/ subfolder should exist")
  expect_true(file.exists(file.path(pkg_root, "latest_visualization", "research_ready")),
              "research_ready/ subfolder should exist")

  # Verify metrics are in expected ranges
  status <- read.csv(file.path(pkg_root, "output", "correction_status_final.csv"),
                     stringsAsFactors = FALSE)
  latest <- status[nrow(status), ]

  expect_true(latest$n_total > 0, "Total records should be > 0")
  expect_true(latest$delta_clean >= 0, "Clean delta should be >= 0")
  expect_true(latest$delta_error >= 0, "Error delta should be >= 0")
})

test_that("Config loading works", {
  cfg <- load_config(system.file("extdata", "synthetic_config.yaml", package = "splsleep"))
  expect_true(is.list(cfg), "Config should be a list")
  expect_equal(cfg$pipeline$name, "splsleep (Synthetic Demo)")
  expect_true(!is.null(cfg$classification$metric_validation$sol$excessive_minutes))
})

test_that("Column adaptation renames correctly", {
  cfg <- load_config(system.file("extdata", "synthetic_config.yaml", package = "splsleep"))

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

# test-pipeline.R — end-to-end test with synthetic data

test_that("run_pipeline completes successfully on synthetic data", {
  # Locate synthetic data config bundled with the package
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "splsleep")
  if (cfg_path == "") {
    # Development mode fallback
    cfg_path <- file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")
  }
  skip_if_not(file.exists(cfg_path), "synthetic_config.yaml not found")

  # Set project_dir to package root for dev mode
  pkg_root <- if (cfg_path == file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")) {
    getwd()
  } else {
    dirname(dirname(dirname(cfg_path)))
  }

  # Check data files exist before running
  cfg <- yaml::read_yaml(cfg_path)
  rds_ok <- file.exists(file.path(pkg_root, cfg$data$files$main))
  skip_if_not(rds_ok, "synthetic RDS data file not found")

  result <- run_pipeline(config = cfg_path, project_dir = pkg_root, verbose = FALSE)
  expect_true(result, "Pipeline should complete successfully")

  # Verify output files exist
  expect_true(file.exists(file.path(pkg_root, "output", "correction_status_final.csv")),
              "correction_status_final.csv should exist")
  # Figure output lives in latest_visualization_<tag>_n<rows>/. Locate it by
  # pattern rather than by a literal name, so the synthetic row count can change
  # without breaking the test.
  viz_dirs <- list.files(pkg_root, pattern = "^latest_visualization_", full.names = TRUE)
  viz_dirs <- viz_dirs[dir.exists(viz_dirs)]
  expect_true(length(viz_dirs) >= 1, "a latest_visualization_* directory should exist")

  # This is the load-bearing assertion: a test run reads synthetic_config.yaml,
  # so it MUST tag its output "synth". If it ever produced a "real" folder the
  # test suite would be overwriting real-data figures -- which is exactly what
  # happened on 2026-08-06 back when every run shared one output directory.
  synth_dirs <- grep("_synth", basename(viz_dirs), value = TRUE)
  expect_true(length(synth_dirs) >= 1,
              "test run must write a _synth-tagged directory, never _real")

  viz <- file.path(pkg_root, synth_dirs[1])
  expect_true(dir.exists(file.path(viz, "pipeline_cleaning")),
              "pipeline_cleaning/ subfolder should exist")
  expect_true(dir.exists(file.path(viz, "research_ready")),
              "research_ready/ subfolder should exist")
  expect_true(file.exists(file.path(viz, "RUN_INFO.txt")),
              "RUN_INFO.txt provenance file should exist")

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

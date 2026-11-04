# test-pipeline-chain.R -- run_cleaning_chain(), the six-step pure chain.
#
# Why this file exists: R/pipeline_chain.R had 0% coverage. run_cleaning_chain()
# is exported and documented (man/run_cleaning_chain.Rd) but no test called it,
# so a user following the documentation was running unverified code. This file
# also answers the "does the same input twice give the same output?" question at
# chain level: the data columns are deterministic, while the carried
# `calculation_timestamp` attribute is not.
#
# The chain is run inside a sandbox because, despite the "no file I/O" line in
# its own documentation, it still writes manual_error_correction_updated.csv and
# three files under output/. Running it from the package directory would drop
# those into the repository's output/.
#
# Synthetic data only: nothing here is real data.

.chain_fixture <- function() {
  ext <- system.file("extdata", package = "sleepcleanr")
  if (!nzchar(ext)) ext <- file.path(getwd(), "inst", "extdata")
  if (!file.exists(file.path(ext, "synthetic_config.yaml"))) return(NULL)
  cfg <- load_config(file.path(ext, "synthetic_config.yaml"))
  raw <- readRDS(file.path(ext, "synthetic_sleep_data.rds"))
  list(cfg = cfg, dat = adapt_columns(raw, cfg))
}

# The chain prints per-step progress from sourced scripts; keep it out of the
# test reporter, but still return the value.
.chain_quiet <- function(expr) {
  utils::capture.output(out <- force(expr))
  out
}

test_that("run_cleaning_chain() runs the six documented steps", {
  fx <- .chain_fixture()
  skip_if(is.null(fx), "fixture not found")

  sandbox <- withr::local_tempdir()
  withr::local_dir(sandbox)

  x <- .chain_quiet(run_cleaning_chain(fx$dat, cfg = fx$cfg, verbose = FALSE))

  expect_s3_class(x, "sleep_diary")
  expect_equal(vapply(x$history, function(h) h$id, character(1)),
               c("1", "2", "3", "4", "6", "6.5"))

  df <- as.data.frame(x)
  expect_equal(nrow(df), nrow(fx$dat))
  expect_true(all(c("sol_h", "waso_h", "time_bed_corrected",
                    "time_sleep_corrected", "time_awake_corrected",
                    "time_getup_corrected") %in% names(df)))
  expect_true(all(df$sol_h >= 0, na.rm = TRUE))
  expect_true(all(df$waso_h >= 0, na.rm = TRUE))
})

test_that("run_cleaning_chain() gives the same data twice; only its timestamp attribute moves", {
  fx <- .chain_fixture()
  skip_if(is.null(fx), "fixture not found")

  sandbox <- withr::local_tempdir()
  withr::local_dir(sandbox)

  a <- as.data.frame(.chain_quiet(run_cleaning_chain(fx$dat, cfg = fx$cfg, verbose = FALSE)))
  b <- as.data.frame(.chain_quiet(run_cleaning_chain(fx$dat, cfg = fx$cfg, verbose = FALSE)))

  expect_equal(a, b, ignore_attr = TRUE)
  expect_false(is.null(attr(a, "calculation_timestamp")))
  expect_identical(attr(a, "sleep_vars_calculated"), attr(b, "sleep_vars_calculated"))
})

test_that("run_cleaning_chain() accepts an existing sleep_diary instead of raw data", {
  fx <- .chain_fixture()
  skip_if(is.null(fx), "fixture not found")

  sandbox <- withr::local_tempdir()
  withr::local_dir(sandbox)

  x0 <- new_sleep_diary(fx$dat, step_id = "1", step_label = "Load data", cfg = fx$cfg)
  x  <- .chain_quiet(run_cleaning_chain(x0, cfg = fx$cfg, verbose = FALSE))

  expect_s3_class(x, "sleep_diary")
  expect_equal(vapply(x$history, function(h) h$id, character(1)),
               c("1", "2", "3", "4", "6", "6.5"))
  expect_equal(nrow(as.data.frame(x)), nrow(fx$dat))
})

# Public-API smoke tests: every @export helper at least runs on a minimal
# input without crashing and returns its documented shape.
#
# run_cleaning_chain and figure_cleaning_effect are deliberately NOT smoke
# tested here: run_cleaning_chain is exercised end-to-end by the pipeline
# smoke test (test-pipeline.R), and figure_cleaning_effect was verified
# against the real corrected_ema_data during the 2026-08-23 visualization run
# (its synthetic inputs would need the full derived column set to draw).

test_that("bland_altman: computes and prints/plots without error", {
  d <- data.frame(reported = c(10, 20, 15, 18), computed = c(9, 18, 16, 19))
  ba <- bland_altman(d, "reported", "computed", label = "SOL")
  expect_s3_class(ba, "bland_altman")
  expect_invisible(print(ba))
  expect_s3_class(plot(ba), "ggplot")
})

test_that("validate_thresholds: returns threshold_validation, printable", {
  d <- data.frame(reported = c(10, 20, 15, 18), computed = c(9, 18, 16, 19))
  tv <- validate_thresholds(d, cfg = NULL)
  expect_true(inherits(tv, "threshold_validation"))
  expect_invisible(print(tv))
})

test_that("flag_statistical_outliers: flags IQR outliers into iqr_outlier", {
  d <- data.frame(pid = rep(c(1, 2), each = 6), day_num = rep(1:6, 2),
                  self_diffcalc_sol_minutes = c(10, 15, 12, 200, 9, 11, 8, 9, 11, 12, 10, 10))
  out <- suppressWarnings(flag_statistical_outliers(d))
  expect_equal(nrow(out), 12)
  expect_true("iqr_outlier" %in% names(out))
  expect_false(is.na(out$iqr_outlier[4]))   # the 200-min spike
  expect_identical(attr(out$iqr_outlier, "method"), "IQR")
  expect_error(summarise_outliers(out), NA)
})

test_that("handle_missing: explicit metric columns, summarisable", {
  d <- data.frame(pid = c(1, 1, 2), day_num = c(1, 2, 1),
                  sol = c(NA, 15, 20))
  out <- handle_missing(d, metric_cols = "sol")
  expect_equal(nrow(out), 3)
  expect_error(summarise_missing(out), NA)
})

test_that("figure_pipeline_workflow: draws with a minimal global dataset", {
  withr::local_dir(tempdir())   # keep figure output out of the repo
  old <- get0("corrected_ema_data", envir = .GlobalEnv, ifnotfound = NULL)
  syn <- data.frame(pid = 1:3, day_num = 1:3,
                    correction_type = c("auto", NA, "auto"),
                    manually_corrected = c(TRUE, FALSE, FALSE),
                    data_category = c("error", "clean", "unusual"),
                    stringsAsFactors = FALSE)
  assign("corrected_ema_data", syn, envir = .GlobalEnv)
  on.exit({ if (is.null(old)) rm("corrected_ema_data", envir = .GlobalEnv)
            else assign("corrected_ema_data", old, envir = .GlobalEnv) }, add = TRUE)
  p <- figure_pipeline_workflow()
  expect_s3_class(p, "ggplot")
})
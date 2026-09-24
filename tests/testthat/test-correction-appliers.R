# Tests: correction_appliers.R — nap/exercise, sleep-metric-duration, metric-acceptance
# =============================================================================
# These three internalised functions (moved from inst/scripts into the package)
# had NO functional tests — only a sync test. Cover the apply path + skip paths.

test_that("apply_nap_exercise_corrections applies verified rows and skips others", {
  df <- data.frame(
    pid = c(1, 1, 2), day_num = c(1, 2, 1), row_id = c(10, 11, 12),
    nap_mincalc = c(30, 45, 60), nap_checkforerrors = c(TRUE, TRUE, TRUE),
    exercise_Light_mincalc = c(10, 20, 30),
    stringsAsFactors = FALSE)
  # row_id 10 nap: verified -> 15; row_id 12 nap: not corrected -> skip
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    pid = c(1, 2), day_num = c(1, 1), row_id = c(10, 12),
    variable = c("nap", "nap"), corrected_mincalc = c(15, 999),
    manually_corrected = c("verified_recode", "FALSE"),
    stringsAsFactors = FALSE), tmp, row.names = FALSE)

  opts <- options(sleepcleanr.verbose = FALSE)
  on.exit(options(opts), add = TRUE)
  out <- withr::with_options(
    c(sleepcleanr.audit_manual_corrections = ""),
    apply_nap_exercise_corrections(df, cfg = list(data = list(files = list(manual_nap_exercise = tmp))))
  )
  # row 10 corrected to 15
  expect_equal(out$nap_mincalc[out$row_id == 10], 15)
  # row 12 untouched (manually_corrected FALSE)
  expect_equal(out$nap_mincalc[out$row_id == 12], 60)
})

test_that("apply_nap_exercise_corrections returns data unchanged when file missing", {
  df <- data.frame(pid = 1, day_num = 1, row_id = 1, nap_mincalc = 30)
  out <- apply_nap_exercise_corrections(df, cfg = list(data = list(files = list(manual_nap_exercise = "/nonexistent.csv"))))
  expect_identical(out, df)
})

test_that("apply_sleep_metric_duration_corrections applies and skips", {
  df <- data.frame(
    pid = c(1, 1), day_num = c(1, 2), row_id = c(20, 21),
    duration_totalmin_sol_estimate_am_mincalc = c(30, 45),
    duration_totalmin_sol_estimate_am_checkforerrors = c(TRUE, TRUE),
    stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    pid = 1, day_num = 1, row_id = 20,
    variable = "duration_totalmin_sol_estimate_am",
    corrected_mincalc = 10, manually_corrected = TRUE,
    stringsAsFactors = FALSE), tmp, row.names = FALSE)
  out <- apply_sleep_metric_duration_corrections(df, cfg = list(data = list(files = list(manual_metric_duration = tmp))))
  expect_equal(out$duration_totalmin_sol_estimate_am_mincalc[out$row_id == 20], 10)
  expect_equal(out$duration_totalmin_sol_estimate_am_mincalc[out$row_id == 21], 45)
})

test_that("apply_sleep_metric_duration_corrections handles unmatched row gracefully", {
  df <- data.frame(pid = 1, day_num = 1, row_id = 99, duration_totalmin_sol_estimate_am_mincalc = 30)
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    pid = 1, day_num = 1, row_id = 98,  # no match in df
    variable = "duration_totalmin_sol_estimate_am",
    corrected_mincalc = 10, manually_corrected = TRUE,
    stringsAsFactors = FALSE), tmp, row.names = FALSE)
  out <- apply_sleep_metric_duration_corrections(df, cfg = list(data = list(files = list(manual_metric_duration = tmp))))
  expect_equal(out$duration_totalmin_sol_estimate_am_mincalc, 30)
})

test_that("apply_metric_review_acceptances attaches review status", {
  df <- data.frame(
    pid = c(1, 1, 2), day_num = c(1, 2, 1), row_id = c(30, 31, 32),
    duration_totalmin_sol_estimate_am_mincalc = c(30, 45, 60),
    stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    pid = c(1, 1), day_num = c(1, 2), row_id = c(30, 31),
    human_metric_review_status = "confirmed_not_error_do_not_correct",
    human_metric_review_note = "reviewed, reasonable",
    stringsAsFactors = FALSE), tmp, row.names = FALSE)
  out <- apply_metric_review_acceptances(df, cfg = list(data = list(files = list(manual_metric_accept = tmp))))
  # rows 30,31 got the accepted status
  expect_equal(out$human_metric_review_status[out$row_id == 30], "confirmed_not_error_do_not_correct")
  expect_equal(out$human_metric_review_status[out$row_id == 31], "confirmed_not_error_do_not_correct")
  # row 32 not in accept file -> NA status
  expect_true(is.na(out$human_metric_review_status[out$row_id == 32]))
  # note attached
  expect_equal(out$human_metric_review_note[out$row_id == 30], "reviewed, reasonable")
})

test_that("apply_metric_review_acceptances returns data unchanged on missing file", {
  df <- data.frame(pid = 1, day_num = 1, row_id = 1)
  out <- apply_metric_review_acceptances(df, cfg = list(data = list(files = list(manual_metric_accept = "/nonexistent.csv"))))
  expect_identical(out, df)
})
test_that("apply_nap_exercise_corrections skips when variable column missing", {
  df <- data.frame(pid = 1, day_num = 1, row_id = 10, stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    pid = 1, day_num = 1, row_id = 10,
    variable = "nap", corrected_mincalc = 15,
    manually_corrected = "verified_recode",
    stringsAsFactors = FALSE), tmp, row.names = FALSE)
  out <- apply_nap_exercise_corrections(df, cfg = list(data = list(files = list(manual_nap_exercise = tmp))))
  expect_identical(names(out), names(df))  # unchanged
})

test_that("apply_nap_exercise_corrections skips when no row matches", {
  df <- data.frame(pid = 1, day_num = 1, row_id = 10, nap_mincalc = 30, stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    pid = 999, day_num = 99, row_id = 1,
    variable = "nap", corrected_mincalc = 15,
    manually_corrected = "verified_recode",
    stringsAsFactors = FALSE), tmp, row.names = FALSE)
  out <- apply_nap_exercise_corrections(df, cfg = list(data = list(files = list(manual_nap_exercise = tmp))))
  expect_equal(out$nap_mincalc, 30)
})

test_that("apply_nap_exercise_corrections skips on duplicate match", {
  df <- data.frame(pid = c(1, 1), day_num = c(1, 1), row_id = c(10, 10),
                   nap_mincalc = c(30, 40), stringsAsFactors = FALSE)
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(
    pid = 1, day_num = 1, row_id = 10,
    variable = "nap", corrected_mincalc = 15,
    manually_corrected = "verified_recode",
    stringsAsFactors = FALSE), tmp, row.names = FALSE)
  out <- apply_nap_exercise_corrections(df, cfg = list(data = list(files = list(manual_nap_exercise = tmp))))
  expect_equal(out$nap_mincalc, c(30, 40))  # untouched
})

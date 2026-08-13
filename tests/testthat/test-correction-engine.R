context("Correction engine — recalculate_and_mark_errors thresholds")

# Thin wrapper over the PRODUCTION classifier (R/manual_corrections.R, formerly
# inst/scripts/error_unusual_sleep_time_corrections.R). Previously this file
# hand-transcribed the classification logic, which tested a copy, not the
# shipped code. Now every scenario runs the real internalised function via
# splsleep:::, so threshold drift in production fails these tests.
.classify <- function(bed, sleep, awake, getup) {
  df <- data.frame(
    time_bed_corrected   = as.POSIXct(bed,   tz = "UTC"),
    time_sleep_corrected = as.POSIXct(sleep, tz = "UTC"),
    time_awake_corrected = as.POSIXct(awake, tz = "UTC"),
    time_getup_corrected = as.POSIXct(getup, tz = "UTC")
  )
  res <- suppressOutput(
    splsleep:::recalculate_and_mark_errors(
      df,
      bed_corr_col   = "time_bed_corrected",
      sleep_corr_col = "time_sleep_corrected",
      awake_corr_col = "time_awake_corrected",
      getup_corr_col = "time_getup_corrected"
    )
  )
  list(
    is_error     = res$is_error[1],
    error_type   = res$error_type[1],
    is_unusual   = res$is_unusual[1],
    unusual_type = res$unusual_type[1],
    data_category = res$data_category[1],
    has_na       = res$has_na[1]
  )
}

suppressOutput <- function(expr) {
  capture.output(res <- expr, type = "output")
  res
}

test_that("clean record: normal sleep, no flags", {
  r <- .classify("2026-01-01 22:00", "2026-01-01 22:30",
                 "2026-01-02 06:00", "2026-01-02 06:30")
  expect_false(r$is_error)
  expect_false(r$is_unusual)
  expect_equal(r$data_category, "clean")
})

test_that("order_error: sleep before bed", {
  r <- .classify("2026-01-01 22:00", "2026-01-01 21:00",
                 "2026-01-02 06:00", "2026-01-02 06:30")
  expect_true(r$is_error)
  expect_equal(r$error_type, "order_error")
})

test_that("bed_sleep_diff_error: gap > 7 hours", {
  r <- .classify("2026-01-01 20:00", "2026-01-02 05:00",
                 "2026-01-02 07:00", "2026-01-02 07:30")
  expect_true(r$is_error)
  expect_equal(r$error_type, "bed_sleep_diff_error")
})

test_that("awake_getup_diff_error: gap > 7 hours", {
  r <- .classify("2026-01-01 22:00", "2026-01-01 23:00",
                 "2026-01-02 06:00", "2026-01-02 14:00")
  expect_true(r$is_error)
  expect_equal(r$error_type, "awake_getup_diff_error")
})

test_that("sleep_awake_24h_error: sleep period > 24h", {
  r <- .classify("2026-01-01 22:00", "2026-01-01 23:00",
                 "2026-01-03 00:00", "2026-01-03 01:00")
  expect_true(r$is_error)
  expect_equal(r$error_type, "sleep_awake_24h_error")
})

test_that("equal_time_ok: bed == sleep and awake == getup", {
  r <- .classify("2026-01-01 23:00", "2026-01-01 23:00",
                 "2026-01-02 07:00", "2026-01-02 07:00")
  expect_equal(r$data_category, "equal_time_ok")
  expect_false(r$is_error)
})

test_that("unusual: sleep period < 3 hours", {
  r <- .classify("2026-01-01 23:00", "2026-01-01 23:30",
                 "2026-01-02 01:00", "2026-01-02 01:30")
  expect_true(r$is_unusual)
  expect_match(r$unusual_type, "sleep_awake_suspicious")
})

test_that("skipped_na: NA timestamp skips all classification", {
  r <- .classify("2026-01-01 22:00", NA,
                 "2026-01-02 06:00", "2026-01-02 06:30")
  expect_true(r$has_na)
  expect_equal(r$data_category, "skipped_na")
})

test_that("order_error wins over bed_sleep_diff when both violated", {
  # Sleep (14:00) is before bed (22:00) by 8 hours -> order AND latency
  # violated. Production error_type is first-match-wins (case_when), so the
  # temporal-order branch reports "order_error", not "multiple_errors".
  r <- .classify("2026-01-01 22:00", "2026-01-01 14:00",
                 "2026-01-02 06:00", "2026-01-02 07:00")
  expect_true(r$is_error)
  expect_equal(r$error_type, "order_error")
})

test_that("bed_sleep_suspicious: latency > 3 hours", {
  r <- .classify("2026-01-01 22:00", "2026-01-02 02:00",
                 "2026-01-02 07:00", "2026-01-02 07:30")
  expect_true(r$is_unusual)
  expect_match(r$unusual_type, "bed_sleep_suspicious")
})

test_that("awake_getup_suspicious: > 3h gap after waking", {
  r <- .classify("2026-01-01 22:00", "2026-01-02 00:30",
                 "2026-01-02 06:00", "2026-01-02 10:00")
  expect_true(r$is_unusual)
  expect_match(r$unusual_type, "awake_getup_suspicious")
})

test_that("internalised vs script-copy: non-empty corrections bit-identical", {
  root <- if (basename(getwd()) == "testthat") dirname(dirname(getwd())) else getwd()

  # 20-row synthetic diary. apply_manual_corrections_and_recalculate matches
  # corrections by pid + day_num (not row_id) and expects the fixed legacy
  # column names: *_am_hhmm_ampm (raw, only selected) and *_corrected (POSIXct,
  # actually recalculated). A numeric duration column is required: its absence
  # makes find_duration_columns() fall back to grepl and pick up the recalc
  # output column reasonable_sleep_duration (logical), which breaks the
  # duration-join mutate.
  bed <- as.POSIXct("2026-01-01 22:00", tz = "UTC") + 0:19 * 3600
  df <- data.frame(
    pid = rep(1:5, each = 4),
    day_num = rep(1:4, times = 5),
    row_id = 1:20,
    duration = rep(480, 20),
    time_bed_am_hhmm_ampm   = bed,
    time_sleep_am_hhmm_ampm = bed + 3600,
    time_awake_am_hhmm_ampm = bed + 9 * 3600,
    time_getup_am_hhmm_ampm = bed + 9.5 * 3600,
    time_bed_corrected   = bed,
    time_sleep_corrected = bed + 3600,
    time_awake_corrected = bed + 9 * 3600,
    time_getup_corrected = bed + 9.5 * 3600,
    stringsAsFactors = FALSE
  )
  # Row 1 (pid=1, day_num=1): sleep BEFORE bed -> genuine order error that the
  # case3 swap must fix. correct_value equals the current value, so the swap
  # alone changes the data (bed <-> sleep exchange).
  df$time_sleep_corrected[1] <- as.POSIXct("2026-01-01 21:00", tz = "UTC")

  corrections_df <- data.frame(
    pid = 1, day_num = 1, row_id = 1,
    correction_type = "case3",
    solution_humanidentified = "bed/sleep switch",
    column_to_correct = "time_sleep_corrected",
    correct_value = "21:00",
    column_to_correct_2 = NA_character_,
    correct_value_2 = NA_character_,
    stringsAsFactors = FALSE
  )

  script_env <- new.env(parent = globalenv())
  sys.source(file.path(root, "inst/scripts", "error_unusual_sleep_time_corrections.R"),
             envir = script_env)

  # write_csv side effect goes to cwd; run in a throwaway dir so the test
  # tree stays clean.
  withr::local_dir(tempdir())
  capture.output(
    out_script <- script_env$apply_manual_corrections_and_recalculate(df, corrections_df, NULL),
    type = "output"
  )
  capture.output(
    out_pkg <- splsleep:::apply_manual_corrections_and_recalculate(df, corrections_df, NULL),
    type = "output"
  )

  expect_identical(out_pkg, out_script)

  # Prove the branch actually fired: row 1 corrected, order fixed post-swap.
  expect_true(out_pkg$updated_corrections$manually_corrected[1])
  corr_row <- out_pkg$corrected_ema_data[1, ]
  expect_false(corr_row$is_error)
  expect_equal(corr_row$time_bed_corrected,   as.POSIXct("2026-01-01 21:00", tz = "UTC"))
  expect_equal(corr_row$time_sleep_corrected, as.POSIXct("2026-01-01 22:00", tz = "UTC"))
})

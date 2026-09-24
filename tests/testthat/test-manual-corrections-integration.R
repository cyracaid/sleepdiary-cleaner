# Integration: apply_manual_corrections_and_recalculate — the main entry
# =============================================================================
# Runs a real corrections_df through the full application engine (case3
# path): column_to_correct/correct_value + second pair, undo, unmatched row.

.mk_ema <- function() {
  data.frame(
    pid = c(1, 1, 2), day_num = c(1, 2, 1), row_id = c(10, 11, 12),
    time_bed_am_hhmm_ampm = as.POSIXct(c("2020-01-01 23:00:00", "2020-01-01 22:00:00", "2020-01-01 23:30:00"), tz = "UTC"),
    time_sleep_am_hhmm_ampm = as.POSIXct(c("2020-01-01 23:30:00", "2020-01-01 22:30:00", "2020-01-01 00:00:00"), tz = "UTC"),
    time_awake_am_hhmm_ampm = as.POSIXct(c("2020-01-02 07:00:00", "2020-01-02 06:30:00", "2020-01-02 08:00:00"), tz = "UTC"),
    time_getup_am_hhmm_ampm = as.POSIXct(c("2020-01-02 07:30:00", "2020-01-02 07:00:00", "2020-01-02 08:30:00"), tz = "UTC"),
    time_bed_corrected = as.POSIXct(c("2020-01-01 23:00:00", "2020-01-01 22:00:00", "2020-01-01 23:30:00"), tz = "UTC"),
    time_sleep_corrected = as.POSIXct(c("2020-01-01 23:30:00", "2020-01-01 22:30:00", "2020-01-01 00:00:00"), tz = "UTC"),
    time_awake_corrected = as.POSIXct(c("2020-01-02 07:00:00", "2020-01-02 06:30:00", "2020-01-02 08:00:00"), tz = "UTC"),
    time_getup_corrected = as.POSIXct(c("2020-01-02 07:30:00", "2020-01-02 07:00:00", "2020-01-02 08:30:00"), tz = "UTC"),
    duration_totalmin_sol_estimate_am_mincalc = c(30, 45, 60),
    stringsAsFactors = FALSE)
}

test_that("apply_manual_corrections_and_recalculate applies case3 corrections", {
  ema <- .mk_ema()
  corr <- data.frame(
    pid = 1, day_num = 1,
    column_to_correct = "time_sleep_corrected",
    correct_value = "Minus 12 hours",
    column_to_correct_2 = NA, correct_value_2 = NA,
    solution_humanidentified = NA,
    stringsAsFactors = FALSE)
  out <- apply_manual_corrections_and_recalculate(ema, corr)
  expect_true("time_sleep_manual" %in% names(out$corrected_ema_data))
  # sleep 23:30 minus 12h -> 11:30
  expect_equal(format(out$corrected_ema_data$time_sleep_manual[out$corrected_ema_data$row_id == 10], "%H:%M"), "11:30")
  expect_true(out$corrected_ema_data$manually_corrected[out$corrected_ema_data$row_id == 10])
})

test_that("apply_manual_corrections_and_recalculate applies second correction pair", {
  ema <- .mk_ema()
  corr <- data.frame(
    pid = 1, day_num = 1,
    column_to_correct = "time_sleep_corrected",
    correct_value = "Minus 12 hours",
    column_to_correct_2 = "time_awake_corrected",
    correct_value_2 = "Same Day 06:00:00 AM",
    solution_humanidentified = NA,
    stringsAsFactors = FALSE)
  out <- apply_manual_corrections_and_recalculate(ema, corr)
  expect_equal(format(out$corrected_ema_data$time_awake_manual[out$corrected_ema_data$row_id == 10], "%H:%M"), "06:00")
})

test_that("apply_manual_corrections_and_recalculate handles unmatched correction row", {
  ema <- .mk_ema()
  corr <- data.frame(
    pid = 999, day_num = 99,
    column_to_correct = "time_sleep_corrected",
    correct_value = "Minus 12 hours",
    column_to_correct_2 = NA, correct_value_2 = NA,
    solution_humanidentified = NA,
    stringsAsFactors = FALSE)
  # Should not error; other rows untouched
  out <- apply_manual_corrections_and_recalculate(ema, corr)
  expect_equal(nrow(out$corrected_ema_data), 3)
  expect_equal(format(out$corrected_ema_data$time_sleep_manual[out$corrected_ema_data$row_id == 10], "%H:%M"), "23:30")
})

test_that("apply_manual_corrections_and_recalculate stops on missing required cols", {
  ema <- data.frame(pid = 1)  # no day_num/row_id
  corr <- data.frame()
  expect_error(apply_manual_corrections_and_recalculate(ema, corr), "missing required columns")
})

# process_manual_unusual_correction — manual unusual record adjustments
# =============================================================================

.mk_data <- function() {
  data.frame(
    pid = c(1, 1), day_num = c(1, 2), row_id = c(10, 11),
    time_bed_am_hhmm_ampm = as.POSIXct(c("2020-01-01 23:00:00", "2020-01-01 22:00:00"), tz = "UTC"),
    time_sleep_am_hhmm_ampm = as.POSIXct(c("2020-01-01 23:30:00", "2020-01-01 22:30:00"), tz = "UTC"),
    time_awake_am_hhmm_ampm = as.POSIXct(c("2020-01-02 07:00:00", "2020-01-02 06:30:00"), tz = "UTC"),
    time_getup_am_hhmm_ampm = as.POSIXct(c("2020-01-02 07:30:00", "2020-01-02 07:00:00"), tz = "UTC"),
    time_bed_manual = as.POSIXct(c("2020-01-01 12:00:00", "2020-01-01 22:00:00"), tz = "UTC"),
    time_sleep_manual = as.POSIXct(c("2020-01-01 13:00:00", "2020-01-01 22:30:00"), tz = "UTC"),
    time_awake_manual = as.POSIXct(c("2020-01-02 07:00:00", "2020-01-02 06:30:00"), tz = "UTC"),
    time_getup_manual = as.POSIXct(c("2020-01-02 07:30:00", "2020-01-02 07:00:00"), tz = "UTC"),
    stringsAsFactors = FALSE)
}

test_that("process_manual_unusual_correction applies AM/PM conversion to a field", {
  df <- .mk_data()
  corr <- data.frame(pid = 1, day_num = 1,
    column_to_adjust = "time_sleep_corrected", correction_value = "Minus 12 hours",
    column_to_adjust_2 = NA, correction_value_2 = NA,
    solution_humanidentified = NA, stringsAsFactors = FALSE)
  out <- process_manual_unusual_correction(df, corr,
    "time_bed_am_hhmm_ampm", "time_sleep_am_hhmm_ampm",
    "time_awake_am_hhmm_ampm", "time_getup_am_hhmm_ampm")
  # sleep 13:00 + Minus 12 hours -> 01:00
  expect_equal(format(out$time_sleep_manual[out$row_id == 10], "%H:%M"), "01:00")
  expect_true(out$manually_corrected[out$row_id == 10])
})

test_that("process_manual_unusual_correction undo restores original", {
  df <- .mk_data()
  corr <- data.frame(pid = 1, day_num = 1,
    column_to_adjust = NA, correction_value = NA,
    column_to_adjust_2 = NA, correction_value_2 = NA,
    solution_humanidentified = "undo correction", stringsAsFactors = FALSE)
  out <- process_manual_unusual_correction(df, corr,
    "time_bed_am_hhmm_ampm", "time_sleep_am_hhmm_ampm",
    "time_awake_am_hhmm_ampm", "time_getup_am_hhmm_ampm")
  # undo restores sleep_manual from sleep_am_hhmm_ampm (23:30)
  expect_equal(format(out$time_sleep_manual[out$row_id == 10], "%H:%M"), "23:30")
})

test_that("process_manual_unusual_correction unmatched pid returns data", {
  df <- .mk_data()
  corr <- data.frame(pid = 999, day_num = 99,
    column_to_adjust = "time_sleep_corrected", correction_value = "Minus 12 hours",
    column_to_adjust_2 = NA, correction_value_2 = NA,
    solution_humanidentified = NA, stringsAsFactors = FALSE)
  out <- process_manual_unusual_correction(df, corr,
    "time_bed_am_hhmm_ampm", "time_sleep_am_hhmm_ampm",
    "time_awake_am_hhmm_ampm", "time_getup_am_hhmm_ampm")
  expect_equal(nrow(out), 2)
})

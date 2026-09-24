# Tests: manual_corrections.R — correction operation handlers
# =============================================================================
# Covers the operation-processing functions (the manual-correction engine)
# that had no direct unit tests: AM/PM conversion, swap, hours, align,
# change, same-day/time-only instruction parsing.

test_that("handle_same_day_instruction parses clock time", {
  base <- as.POSIXct("2020-01-01 22:00:00", tz = "UTC")
  # "Same day 02:00:00 AM" -> same day 02:00
  out <- handle_same_day_instruction(base, "Same day 02:00:00 AM")
  expect_equal(format(out, "%H:%M"), "02:00")
  expect_equal(as.Date(out), as.Date("2020-01-01"))
  # "Same Day 08:40:00 AM"
  out2 <- handle_same_day_instruction(base, "Same Day 08:40:00 AM")
  expect_equal(format(out2, "%H:%M"), "08:40")
})

test_that("handle_time_only_instruction parses bare clock time", {
  base <- as.POSIXct("2020-01-01 22:00:00", tz = "UTC")
  out <- handle_time_only_instruction(base, "23:30")
  expect_equal(format(out, "%H:%M"), "23:30")
})

test_that("process_ampm_conversion flips bed/sleep -12h and awake/getup +12h", {
  df <- data.frame(
    pid = 1, day_num = 1,
    time_bed_manual = as.POSIXct("2020-01-01 12:00:00", tz = "UTC"),
    time_sleep_manual = as.POSIXct("2020-01-01 13:00:00", tz = "UTC"),
    time_awake_manual = as.POSIXct("2020-01-01 06:00:00", tz = "UTC"),
    time_getup_manual = as.POSIXct("2020-01-01 07:00:00", tz = "UTC"))
  sol <- "Bed time AM/PM conversion, Sleep time AM/PM conversion, Awake time AM/PM conversion, Getup time AM/PM conversion"
  res <- process_ampm_conversion(df, 1, sol)
  expect_true(res$applied)
  expect_equal(format(res$data$time_bed_manual[1], "%H:%M"), "00:00")   # -12h
  expect_equal(format(res$data$time_sleep_manual[1], "%H:%M"), "01:00")  # -12h
  expect_equal(format(res$data$time_awake_manual[1], "%H:%M"), "18:00")  # +12h
  expect_equal(format(res$data$time_getup_manual[1], "%H:%M"), "19:00")  # +12h
})

test_that("process_ampm_conversion no-op when text lacks the marker", {
  df <- data.frame(time_bed_manual = as.POSIXct("2020-01-01 12:00:00", tz = "UTC"))
  res <- process_ampm_conversion(df, 1, "Minus 12 hours")
  expect_false(res$applied)
  expect_equal(format(res$data$time_bed_manual[1], "%H:%M"), "12:00")
})

test_that("process_hours_operations applies +/- N hours", {
  df <- data.frame(
    time_sleep_manual = as.POSIXct("2020-01-01 13:00:00", tz = "UTC"),
    time_awake_manual = as.POSIXct("2020-01-01 06:00:00", tz = "UTC"))
  # Minus 12 hours on sleep
  res <- process_hours_operations(df, 1, "Sleep time Minus 12 hours")
  expect_true(res$applied)
  expect_equal(format(res$data$time_sleep_manual[1], "%H:%M"), "01:00")
})

test_that("process_swap_operations swaps a field pair", {
  df <- data.frame(
    time_bed_manual = as.POSIXct("2020-01-01 23:00:00", tz = "UTC"),
    time_sleep_manual = as.POSIXct("2020-01-01 22:00:00", tz = "UTC"))
  res <- process_swap_operations(df, 1, "perform bed-sleep switch")
  expect_true(res$applied)
  expect_equal(format(res$data$time_bed_manual[1], "%H:%M"), "22:00")
  expect_equal(format(res$data$time_sleep_manual[1], "%H:%M"), "23:00")
})

test_that("process_change_operations sets a field to a value", {
  df <- data.frame(
    time_awake_manual = as.POSIXct("2020-01-01 06:00:00", tz = "UTC"))
  res <- process_change_operations(df, 1, "change awake time into 08:00")
  expect_true(res$applied)
  expect_equal(format(res$data$time_awake_manual[1], "%H:%M"), "08:00")
})

test_that("safe_numeric coerces strings and keeps NAs", {
  expect_equal(safe_numeric("12.5"), 12.5)
  expect_equal(safe_numeric("abc"), NA_real_)
  expect_equal(safe_numeric(NA), NA_real_)
})

test_that("corrected_to_manual_col maps corrected names to manual", {
  expect_equal(corrected_to_manual_col("time_sleep_corrected"), "time_sleep_manual")
  expect_equal(corrected_to_manual_col("time_bed_corrected"), "time_bed_manual")
})
test_that("process_align_operations aligns source hour to target", {
  df <- data.frame(
    time_awake_manual = as.POSIXct("2020-01-01 07:30:00", tz = "UTC"),
    time_getup_manual = as.POSIXct("2020-01-01 08:45:00", tz = "UTC"))
  res <- process_align_operations(df, 1, "align awake time's hour to getup time's hour")
  expect_true(res$applied)
  # awake hour set to getup hour (08), minutes preserved (30)
  expect_equal(format(res$data$time_awake_manual[1], "%H:%M"), "08:30")
})

test_that("check_swap_corrections marks swap rows as manually corrected", {
  data_df <- data.frame(
    pid = c(1, 1), day_num = c(1, 2), row_id = c(10, 11),
    time_bed_corrected = as.POSIXct(c("2020-01-01 23:00:00", "2020-01-01 22:00:00"), tz = "UTC"),
    time_sleep_corrected = as.POSIXct(c("2020-01-01 22:00:00", "2020-01-01 23:00:00"), tz = "UTC"),
    manually_corrected = c(FALSE, FALSE),
    stringsAsFactors = FALSE)
  corr_df <- data.frame(
    pid = 1, day_num = 1, row_id = 10,
    correction_type = "bed-sleep swap",
    stringsAsFactors = FALSE)
  res <- check_swap_corrections(data_df, corr_df)
  expect_true(res$manually_corrected[res$pid == 1 & res$day_num == 1])
  expect_false(res$manually_corrected[res$pid == 1 & res$day_num == 2])
})

test_that("process_swap_operations handles case2 pattern set", {
  df <- data.frame(
    time_awake_manual = as.POSIXct("2020-01-01 07:00:00", tz = "UTC"),
    time_getup_manual = as.POSIXct("2020-01-01 08:00:00", tz = "UTC"))
  res <- process_swap_operations(df, 1, "perform awake-getup swap", pattern_set = "case2")
  expect_true(res$applied)
  expect_equal(format(res$data$time_awake_manual[1], "%H:%M"), "08:00")
})

test_that("process_ampm_conversion handles time_type not matching a known field", {
  df <- data.frame(time_bed_manual = as.POSIXct("2020-01-01 12:00:00", tz = "UTC"))
  # "unknown time AM/PM conversion" -> time_type NA -> no-op
  res <- process_ampm_conversion(df, 1, "unknown time am/pm conversion")
  expect_false(res$applied)
})

test_that("ensure_marking_columns adds missing classification columns", {
  df <- data.frame(pid = 1)
  out <- ensure_marking_columns(df)
  expect_true("data_category" %in% names(out))
  expect_true("error_type" %in% names(out))
  expect_true("unusual_type" %in% names(out))
  expect_true(is.na(out$data_category[1]))
})

test_that("parse_columns splits on commas, plus, and whitespace", {
  expect_equal(parse_columns("time_bed_corrected, time_sleep_corrected"), c("time_bed_corrected", "time_sleep_corrected"))
  expect_equal(parse_columns("a+b"), c("a", "b"))
  expect_equal(parse_columns(""), character(0))
  expect_equal(parse_columns(NA), character(0))
})

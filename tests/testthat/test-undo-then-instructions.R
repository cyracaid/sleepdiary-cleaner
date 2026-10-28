# "Undo correction" restores the raw times and the row's other instructions
# are then applied on top (process_case2_correction already did this; the
# case3 and unusual handlers used to stop right after the undo).

t <- function(x) as.POSIXct(x, tz = "UTC")
undo_row <- function() data.frame(
  pid = 1, day_num = 1, manually_corrected = FALSE,
  raw_bed = t("2020-11-17 10:45:00"), raw_sleep = t("2020-11-17 11:00:00"),
  raw_awake = t("2020-11-17 10:45:00"), raw_getup = t("2020-11-17 10:50:00"),
  # an earlier (wrong) automatic correction, to be undone
  time_bed_manual = t("2020-11-17 09:00:00"), time_sleep_manual = t("2020-11-17 09:05:00"),
  time_awake_manual = t("2020-11-17 09:10:00"), time_getup_manual = t("2020-11-17 09:15:00"))

corr <- function(...) {
  base <- list(pid = 1, day_num = 1, solution_humanidentified = NA_character_,
               column_to_correct = NA_character_, correct_value = NA_character_,
               column_to_correct_2 = NA_character_, correct_value_2 = NA_character_,
               column_to_adjust = NA_character_, correction_value = NA_character_,
               column_to_adjust_2 = NA_character_, correction_value_2 = NA_character_)
  as.data.frame(utils::modifyList(base, list(...)), stringsAsFactors = FALSE)
}

test_that("case3: undo, then the column/value instructions of the same row", {
  d <- undo_row()
  c3 <- corr(solution_humanidentified = "Undo correction, then do Bed time AM/PM conversion",
             column_to_correct = "time_bed_corrected, time_sleep_corrected", correct_value = "Minus 12 hours")
  out <- NULL
  capture.output(out <- sleepcleanr:::process_case3_correction(d, c3,
    "raw_bed", "raw_sleep", "raw_awake", "raw_getup"))
  expect_equal(out$time_bed_manual,   t("2020-11-16 22:45:00"))
  expect_equal(out$time_sleep_manual, t("2020-11-16 23:00:00"))
  expect_equal(out$time_awake_manual, t("2020-11-17 10:45:00"))   # restored raw
  expect_equal(out$time_getup_manual, t("2020-11-17 10:50:00"))   # restored raw
  expect_true(out$manually_corrected)
})

test_that("case3: undo, then both instruction pairs", {
  d <- undo_row()
  c3 <- corr(solution_humanidentified = "Undo correction. Use time_getup as time_wakeup",
             column_to_correct = "time_awake_corrected", correct_value = "Same day 10:00:00 AM",
             column_to_correct_2 = "time_getup_corrected", correct_value_2 = "Same day 10:00:00 AM")
  capture.output(out <- sleepcleanr:::process_case3_correction(d, c3,
    "raw_bed", "raw_sleep", "raw_awake", "raw_getup"))
  expect_equal(out$time_bed_manual,   t("2020-11-17 10:45:00"))
  expect_equal(out$time_awake_manual, t("2020-11-17 10:00:00"))
  expect_equal(out$time_getup_manual, t("2020-11-17 10:00:00"))
})

test_that("case3: undo alone still only restores the raw times", {
  d <- undo_row()
  capture.output(out <- sleepcleanr:::process_case3_correction(d,
    corr(solution_humanidentified = "Undo correction"),
    "raw_bed", "raw_sleep", "raw_awake", "raw_getup"))
  expect_equal(out$time_bed_manual, d$raw_bed)
  expect_equal(out$time_getup_manual, d$raw_getup)
  expect_true(out$manually_corrected)
})

test_that("unusual: undo, then the column/value instructions of the same row", {
  d <- undo_row()
  cu <- corr(solution_humanidentified = "Undo correction",
             column_to_adjust = "time_bed_corrected", correction_value = "Minus 12 hours")
  capture.output(out <- sleepcleanr:::process_manual_unusual_correction(d, cu,
    "raw_bed", "raw_sleep", "raw_awake", "raw_getup"))
  expect_equal(out$time_bed_manual,   t("2020-11-16 22:45:00"))
  expect_equal(out$time_sleep_manual, t("2020-11-17 11:00:00"))
  expect_true(out$manually_corrected)
})

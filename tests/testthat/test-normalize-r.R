# R/normalize_sequence.R — the packaged copy (covr counts this one)
# =============================================================================
sdir <- system.file("scripts", package = "sleepcleanr")
if (sdir == "") sdir <- file.path(getwd(), "inst", "scripts")
src <- file.path(sdir, "normalize_sleep_time_sequence.R")
if (file.exists(src)) tryCatch(source(src, local = TRUE), error = function(e) NULL)
# use the PACKAGED function (covr tracks the package namespace copy)

make_row <- function(bed, sleep, awake, getup, pid = 1, day_num = 1, row_id = 1) {
  base_date <- as.POSIXct("2026-01-01", tz = "UTC")
  parse_time <- function(t) {
    if (is.na(t)) return(as.POSIXct(NA, tz = "UTC"))
    as.POSIXct(paste(base_date, t), tz = "UTC")
  }
  data.frame(
    pid = pid, day_num = day_num, row_id = row_id,
    duration_totalmin_sol_estimate_am = NA_real_,
    duration_totalmin_waso_estimate_am = NA_real_,
    duration_totalmin_napstoday_PM = NA_real_,
    time_bed_am_hhmm_ampm = parse_time(bed),
    time_sleep_am_hhmm_ampm = parse_time(sleep),
    time_awake_am_hhmm_ampm = parse_time(awake),
    time_getup_am_hhmm_ampm = parse_time(getup),
    stringsAsFactors = FALSE
  )
}

test_that("R/ copy: normal sequence unchanged", {
  df <- make_row("22:00", "22:30", "06:00", "06:30")
  result <- sleepcleanr:::normalize_sleep_time_sequence(df)
  expect_false(result$corrected[1])
})

test_that("R/ copy: getup 12h loop", {
  df <- make_row("22:00", "22:30", "06:00", "22:00")
  result <- sleepcleanr:::normalize_sleep_time_sequence(df)
  expect_true(grepl("getup_reduce_12h", result$correction_type[1]))
  expect_equal(format(result$time_getup_corrected[1], "%H:%M"), "10:00")
})

test_that("R/ copy: sleep 12h loop", {
  df <- make_row("00:00", "13:00", "06:00", "06:30")
  result <- sleepcleanr:::normalize_sleep_time_sequence(df)
  expect_true(grepl("sleep_reduce_12h", result$correction_type[1]))
  expect_equal(format(result$time_sleep_corrected[1], "%H:%M"), "01:00")
})


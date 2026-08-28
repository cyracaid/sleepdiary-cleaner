# timestamp parsing: study-export AM/PM dialects (C=24h clock, l=12h PM)
#
# The exported bed/sleep ampm column carries "C" (24h clock entry) and "l"
# (12h pre-midnight bed) instead of AM/PM (awake/getup keep real AM/PM).
# process_timestamp() must normalise both before the 12h/24h logic runs.

.fmt <- function(x) format(x, "%Y-%m-%d %H:%M", tz = "America/Los_Angeles")

test_that("l entry parses as PM (evening bed), C parses by 24h clock", {
  df <- data.frame(
    StartDate = "2021-09-27 00:00:00",
    time_bed_am_hhmm = c("9:15", "00:20", "12:30", "13:00"),
    time_bed_am_ampm = c("l", "C", "C", "C"),
    stringsAsFactors = FALSE
  )
  out <- process_timestamp(df, "time_bed_am", format = "timestamp")
  expect_true("time_bed_am_hhmm_ampm" %in% names(out))
  got <- .fmt(out$time_bed_am_hhmm_ampm)
  # l 9:15 -> 21:15 previous evening; C 00:20 -> 00:20; C 12:30 -> 00:30
  # (12h-clock midnight entry); C 13:00 -> 01:00 (13:00 AM folds to 1:00)
  expect_equal(got,
    c("2021-09-26 21:15", "2021-09-27 00:20", "2021-09-27 00:30", "2021-09-27 01:00"))
})

test_that("awake/getup AM/PM are untouched by the dialect normaliser", {
  df <- data.frame(
    StartDate = "2021-09-27 00:00:00",
    time_awake_am_hhmm = c("06:30"),
    time_awake_am_ampm = c("AM"),
    stringsAsFactors = FALSE
  )
  out <- process_timestamp(df, "time_awake_am", format = "timestamp")
  expect_equal(.fmt(out$time_awake_am_hhmm_ampm), "2021-09-27 06:30")
})

test_that("NA ampm rows stay NA (no crash, no fake PM)", {
  df <- data.frame(
    StartDate = "2021-09-27 00:00:00",
    time_bed_am_hhmm = c(NA_character_, "9:15"),
    time_bed_am_ampm = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )
  out <- process_timestamp(df, "time_bed_am", format = "timestamp")
  expect_true(all(is.na(out$time_bed_am_hhmm_ampm)))
})
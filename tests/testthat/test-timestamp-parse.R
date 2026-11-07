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
test_that("a time inside the spring-forward gap is kept, not silently dropped", {
  # On R 4.3.3 parse_date_time() returns 01:30 EST for the gap time instead of
  # NA, so the NA-triggered fallback never runs (seen in CI, 2026-11-07). The
  # behaviour is unverified below R 4.4; the R 4.4 CI job tests that guess.
  skip_if(getRversion() < "4.4.0", "gap-time handling not verified on R < 4.4")
  # 2026-03-08 is a US switch day: 02:00-02:59 never happened, so
  # parse_date_time() has no instant to return for "02:30" and gives NA. Left
  # as NA the night is reported as "not reported" even though the person typed
  # a time. The entry is mapped to the first instant that exists (03:30), which
  # is what RFC 5545 and most calendar libraries do.
  df <- data.frame(
    StartDate = "2026-03-08 00:00:00",
    time_bed_am_hhmm = c("02:30", "03:30"),
    time_bed_am_ampm = c("AM", "AM"),
    stringsAsFactors = FALSE
  )
  out <- process_timestamp(df, "time_bed_am", format = "timestamp")

  expect_false(is.na(out$time_bed_am_hhmm_ampm[1]))
  expect_equal(.fmt(out$time_bed_am_hhmm_ampm[1]), "2026-03-08 03:30")
  # the control row is untouched
  expect_equal(.fmt(out$time_bed_am_hhmm_ampm[2]), "2026-03-08 03:30")
})

test_that("process_timestamp() parses in the zone it is given", {
  skip_if(getRversion() < "4.4.0", "gap-time handling not verified on R < 4.4")
  # Same wall clock, different zone: New York's gap is that day too, and the
  # offset must be EDT, not the historical America/Los_Angeles default.
  df <- data.frame(
    StartDate = "2026-03-08 00:00:00",
    time_bed_am_hhmm = "02:30",
    time_bed_am_ampm = "AM",
    stringsAsFactors = FALSE
  )
  out <- process_timestamp(df, "time_bed_am", format = "timestamp", tz = "America/New_York")
  expect_equal(format(out$time_bed_am_hhmm_ampm, "%Y-%m-%d %H:%M %Z"),
               "2026-03-08 03:30 EDT")
})

test_that("data.timezone in the config reaches the parser", {
  df <- data.frame(
    StartDate = "2026-03-08 00:00:00",
    time_bed_am_hhmm = "23:30",
    time_bed_am_ampm = "PM",
    stringsAsFactors = FALSE
  )
  cfg <- list(data = list(timezone = "America/New_York"))
  x <- new_sleep_diary(df, step_id = "1", step_label = "Load data", cfg = cfg)
  out <- as.data.frame(step_process_timestamps(x, vars = "time_bed_am"))
  expect_equal(format(out$time_bed_am_hhmm_ampm, "%Y-%m-%d %H:%M %Z"),
               "2026-03-07 23:30 EST")
})

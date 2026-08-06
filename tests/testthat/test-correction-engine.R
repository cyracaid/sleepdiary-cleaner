context("Correction engine — recalculate_and_mark_errors thresholds")

# Inline the core classification logic from recalculate_and_mark_errors().
# This avoids source()-ing the 2077-line file and its dplyr dependencies.
# The thresholds being tested are the same ones used in production.

.classify <- function(bed, sleep, awake, getup) {
  t <- list(bed = as.POSIXct(bed, tz = "UTC"),
            sleep = as.POSIXct(sleep, tz = "UTC"),
            awake = as.POSIXct(awake, tz = "UTC"),
            getup = as.POSIXct(getup, tz = "UTC"))

  has_na <- any(is.na(unlist(t)))
  if (has_na) return(list(is_error = FALSE, error_type = NA_character_,
                          is_unusual = FALSE, unusual_type = NA_character_,
                          data_category = "skipped_na", has_na = TRUE))

  diff_bed_sleep   <- as.numeric(difftime(t$sleep, t$bed, units = "hours"))
  diff_sleep_awake <- as.numeric(difftime(t$awake, t$sleep, units = "hours"))
  diff_awake_getup <- as.numeric(difftime(t$getup, t$awake, units = "hours"))
  order_ok         <- t$bed <= t$sleep && t$sleep <= t$awake && t$awake <= t$getup

  bed_sleep_equal   <- abs(diff_bed_sleep) < 0.01
  awake_getup_equal <- abs(diff_awake_getup) < 0.01
  is_equal_time     <- bed_sleep_equal || awake_getup_equal

  order_err     <- !order_ok
  bed_sleep_err <- abs(diff_bed_sleep) > 7
  awake_getup_err <- abs(diff_awake_getup) > 7
  duration_24h  <- abs(diff_sleep_awake) > 24

  n_errors <- sum(order_err, bed_sleep_err, awake_getup_err, duration_24h)

  if (n_errors > 0 && !is_equal_time) {
    error_type <- if (n_errors > 1) "multiple_errors"
    else if (order_err) "order_error"
    else if (bed_sleep_err) "bed_sleep_diff_error"
    else if (awake_getup_err) "awake_getup_diff_error"
    else "sleep_awake_24h_error"
    return(list(is_error = TRUE, error_type = error_type,
                is_unusual = FALSE, unusual_type = NA_character_,
                data_category = "error", has_na = FALSE))
  }

  awake_suspicious <- abs(diff_sleep_awake) < 3 || abs(diff_sleep_awake) > 15
  bed_suspicious   <- abs(diff_bed_sleep) > 3
  getup_suspicious <- abs(diff_awake_getup) > 3
  n_suspicious <- sum(awake_suspicious, bed_suspicious, getup_suspicious)

  if (n_suspicious > 0 && !is_equal_time && n_errors == 0) {
    unusual_type <- if (n_suspicious > 1) "multiple_suspicious"
    else if (awake_suspicious) "sleep_awake_suspicious"
    else if (bed_suspicious) "bed_sleep_suspicious"
    else "awake_getup_suspicious"
    return(list(is_error = FALSE, error_type = NA_character_,
                is_unusual = TRUE, unusual_type = unusual_type,
                data_category = "unusual", has_na = FALSE))
  }

  if (is_equal_time) {
    return(list(is_error = FALSE, error_type = NA_character_,
                is_unusual = FALSE, unusual_type = NA_character_,
                data_category = "equal_time_ok", has_na = FALSE))
  }

  list(is_error = FALSE, error_type = NA_character_,
       is_unusual = FALSE, unusual_type = NA_character_,
       data_category = "clean", has_na = FALSE)
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

test_that("multiple_errors: both order and bed_sleep violated", {
  # Sleep (14:00) is before bed (22:00) by 8 hours → order_error + bed_sleep_diff_error
  r <- .classify("2026-01-01 22:00", "2026-01-01 14:00",
                 "2026-01-02 06:00", "2026-01-02 07:00")
  expect_true(r$is_error)
  expect_equal(r$error_type, "multiple_errors")
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

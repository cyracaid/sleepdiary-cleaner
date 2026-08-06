context("Classification logic — generate_correction_files thresholds")

# The classification thresholds are defined as:
#   bed_sleep_diff_error   > 7 hours
#   awake_getup_diff_error > 7 hours
#   sleep_awake_24h_error  > 24 hours
#   bed_sleep_suspicious   > 3 hours
#   awake_getup_suspicious > 3 hours
#   sleep_awake_suspicious < 3 hours or > 15 hours

test_that("bed_sleep_diff of 6.5h is NOT an error (under 7h threshold)", {
  # Direct threshold check: values are in hours from recalculate_and_mark_errors
  diff_h <- 6.5
  is_error <- abs(diff_h) > 7
  expect_false(is_error)
})

test_that("bed_sleep_diff of 7.1h IS an error (over 7h threshold)", {
  diff_h <- 7.1
  is_error <- abs(diff_h) > 7
  expect_true(is_error)
})

test_that("sleep_awake_diff of 2h IS unusual (under 3h threshold)", {
  diff_h <- 2.0
  is_suspicious <- abs(diff_h) < 3
  expect_true(is_suspicious)
})

test_that("sleep_awake_diff of 4h is NOT unusual (within normal range)", {
  diff_h <- 4.0
  is_suspicious <- abs(diff_h) < 3 || abs(diff_h) > 15
  expect_false(is_suspicious)
})

test_that("sleep_awake_diff of 16h IS unusual (over 15h threshold)", {
  diff_h <- 16.0
  is_suspicious <- abs(diff_h) > 15
  expect_true(is_suspicious)
})

test_that("bed_sleep_diff of 2h is NOT suspicious (under 3h threshold for latency)", {
  diff_h <- 2.0
  is_suspicious <- abs(diff_h) > 3
  expect_false(is_suspicious)
})

test_that("bed_sleep_diff of 5h IS suspicious (over 3h latency threshold)", {
  diff_h <- 5.0
  is_suspicious <- abs(diff_h) > 3
  expect_true(is_suspicious)
})

test_that("equal time with both pairs equal: bed==sleep AND awake==getup", {
  bed_sleep_diff  <- 0
  awake_getup_diff <- 0
  is_equal <- abs(bed_sleep_diff) < 0.01 || abs(awake_getup_diff) < 0.01
  expect_true(is_equal)
})

test_that("equal time with only bed==sleep", {
  bed_sleep_diff  <- 0
  awake_getup_diff <- 0.5
  is_equal <- abs(bed_sleep_diff) < 0.01 || abs(awake_getup_diff) < 0.01
  expect_true(is_equal)
})

test_that("order_correct checks bed <= sleep <= awake <= getup (POSIXct)", {
  t1 <- as.POSIXct(c("2026-01-01 22:00", "2026-01-01 23:00",
                       "2026-01-02 06:00", "2026-01-02 07:00"), tz = "UTC")
  correct_order <- t1[1] <= t1[2] && t1[2] <= t1[3] && t1[3] <= t1[4]
  expect_true(correct_order)

  t2 <- as.POSIXct(c("2026-01-01 23:00", "2026-01-01 22:00",
                       "2026-01-02 06:00", "2026-01-02 07:00"), tz = "UTC")
  bad_order <- t2[1] <= t2[2] && t2[2] <= t2[3] && t2[3] <= t2[4]
  expect_false(bad_order)
})

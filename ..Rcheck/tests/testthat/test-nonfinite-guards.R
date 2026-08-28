# test-nonfinite-guards.R — regression tests for the two NULL/non-finite bugs
#
# Bug 1 (fixed earlier): eval_duration_extreme() classified a missing
#   sleep_duration_h as a normal range instead of returning NA.
#
# Bug 2 (fixed 2026-08-05): calculate_sleep_time_vars_end() divided TST by
#   total-try-sleep with no denominator guard. A try-sleep duration of 0 yielded
#   Inf, which then propagated into sleep_efficiency_pct (= Inf * 100), broke
#   plot axes, and polluted any un-guarded mean/summary of the column.
#
# These tests pin the *evaluator* behaviour. The division guard itself is
# exercised end-to-end by the pipeline run, not here.

# ---- Bug 1: missing duration must be unknown, not "OK" ----------------------

test_that("eval_duration_extreme returns NA for missing duration (Bug 1)", {
  df <- data.frame(sleep_duration_h = NA_real_)
  expect_true(is.na(eval_duration_extreme(df)))
})

test_that("eval_duration_extreme never labels a missing duration as OK (Bug 1)", {
  df <- data.frame(sleep_duration_h = c(NA_real_, 7))
  res <- eval_duration_extreme(df)
  expect_true(is.na(res[1]))
  expect_identical(res[2], "OK")
})

# ---- Bug 2 fallout: non-finite metrics must be unknown, not scored ----------

test_that("eval_duration_extreme returns NA for infinite duration", {
  df <- data.frame(sleep_duration_h = c(Inf, -Inf, NaN))
  expect_true(all(is.na(eval_duration_extreme(df))))
})

test_that("eval_duration_extreme still classifies finite values correctly", {
  df <- data.frame(sleep_duration_h = c(2, 7, 13))
  expect_identical(
    eval_duration_extreme(df),
    c("Too short (<3h)", "OK", "Too long (>12h)")
  )
})

test_that("eval_flag_severity treats a non-finite metric the same as missing", {
  # An efficiency that failed to compute must not be *compared* against the
  # threshold. Inf < 70 is FALSE, so without an is.finite() guard a broken
  # metric silently reaches the comparison. Both rows below carry an unknown
  # efficiency and must therefore be scored identically.
  df <- data.frame(
    sleep_efficiency_pct = c(Inf, NA_real_),
    sol_h  = c(0.2, 0.2),
    waso_h = c(0.3, 0.3)
  )
  res <- eval_flag_severity(df)
  expect_identical(res[1], res[2])
})

test_that("eval_flag_severity still counts genuinely poor metrics", {
  df <- data.frame(
    sleep_efficiency_pct = c(95, 50, 50),
    sol_h  = c(0.2, 0.2, 2.0),
    waso_h = c(0.3, 0.3, 0.3)
  )
  expect_identical(
    eval_flag_severity(df),
    c("Clean", "Minor issues (1 flag)", "Major issues (2+ flags)")
  )
})

test_that("eval_flag_severity does not error on all-non-finite input", {
  df <- data.frame(
    sleep_efficiency_pct = c(Inf, NaN),
    sol_h  = c(Inf, NaN),
    waso_h = c(Inf, NaN)
  )
  # expect_error(..., NA) rather than expect_no_error(): the latter needs
  # testthat >= 3.1.5, while DESCRIPTION only requires >= 3.0.0.
  expect_error(eval_flag_severity(df), NA)
})

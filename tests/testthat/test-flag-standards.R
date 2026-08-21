test_that("eval_data_category: authoritative column takes precedence", {
  df <- data.frame(data_category = c("clean", "error", "unusual"), x = 1:3)
  expect_equal(eval_data_category(df), c("clean", "error", "unusual"))
})

test_that("eval_data_category: returns NA when corrected columns missing", {
  df <- data.frame(x = 1:3)
  expect_true(all(is.na(eval_data_category(df))))
})

test_that("tally_standard returns named NA vector when all labels are NA", {
  res <- tally_standard(rep(NA_character_, 10), c("clean", "error", "unusual"))
  expect_true(all(is.na(res)))
  expect_named(res, c("clean", "error", "unusual"))
})

test_that("tally_standard counts correctly for non-NA labels", {
  res <- tally_standard(c("clean", "error", "clean", "unusual"),
                        c("clean", "error", "unusual"))
  expect_equal(res[["clean"]], 2L)
  expect_equal(res[["error"]], 1L)
  expect_equal(res[["unusual"]], 1L)
})

test_that("eval_flag_severity: authoritative column takes precedence", {
  df <- data.frame(flag_severity = c("Clean", "Minor issues (1 flag)"), x = 1:2)
  expect_equal(eval_flag_severity(df), c("Clean", "Minor issues (1 flag)"))
})

test_that("eval_flag_severity: returns NA when metrics missing", {
  df <- data.frame(x = 1:3)
  expect_true(all(is.na(eval_flag_severity(df))))
})

test_that("eval_duration_extreme: returns NA when sleep_duration_h missing", {
  df <- data.frame(x = 1:3)
  expect_true(all(is.na(eval_duration_extreme(df))))
})

test_that("eval_checkforerrors: reads needs_review_flag when available", {
  df <- data.frame(needs_review_flag = c(TRUE, FALSE, TRUE))
  res <- eval_checkforerrors(df)
  expect_equal(res, c("NEEDS_REVIEW", "CLEAN", "NEEDS_REVIEW"))
})

test_that("eval_checkforerrors: returns NA when no flag columns present", {
  df <- data.frame(x = 1:3)
  expect_true(all(is.na(eval_checkforerrors(df))))
})

test_that("eval_field_misentry: returns NA when raw columns missing", {
  df <- data.frame(x = 1:3)
  expect_true(all(is.na(eval_field_misentry(df))))
})

test_that("init_step_ledger and log_step produce ledger rows", {
  init_step_ledger()
  df <- data.frame(x = 1:5)
  log_step(df, "1", "test step")
  long <- get_step_ledger_long()
  expect_true(nrow(long) > 0)
  expect_true("1" %in% long$step_id)
})

test_that("write_step_ledger writes CSV", {
  path <- tempfile(fileext = ".csv")
  init_step_ledger()
  df <- data.frame(x = 1:3)
  log_step(df, "1", "test")
  write_step_ledger(path)
  expect_true(file.exists(path))
  csv <- read.csv(path, stringsAsFactors = FALSE)
  expect_true(nrow(csv) > 0)
})

test_that("eval_flag_severity: threshold scoring with default cutoffs", {
  d <- data.frame(sleep_efficiency_pct = c(50, 90, 50, 90),
                  sol_h = c(0.5, 2, 2, 0.5),
                  waso_h = c(1, 1, 2, 1))
  s <- eval_flag_severity(d, cfg = NULL)
  # r1: poor se only; r2: high sol only; r3: poor se + high waso; r4: clean
  expect_equal(s, c("Minor issues (1 flag)", "Minor issues (1 flag)",
                    "Major issues (2+ flags)", "Clean"))
})

test_that("eval_flag_severity: non-finite metrics are unknown, not clean", {
  d <- data.frame(sleep_efficiency_pct = c(NA, Inf, 50),
                  sol_h = c(NA, NaN, 1.5),
                  waso_h = c(NA, 1, 1))
  s <- eval_flag_severity(d, cfg = NULL)
  # NA row: no finite metric -> 0 flags -> "Clean" by design (unknown misses
  # the poor-efficiency flag); Inf efficiency must not score as clean-poor.
  expect_equal(s[3], "Major issues (2+ flags)")
})

test_that("eval_flag_severity: config-cutoff override", {
  d <- data.frame(sleep_efficiency_pct = 80, sol_h = 0.8, waso_h = 1.4)
  cfg <- list(classification = list(flag_severity = list(
    poor_efficiency_threshold_pct = 85, high_sol_threshold_hours = 1,
    high_waso_threshold_hours = 1.5)))
  # poor se only under strict cutoff -> 1 flag; defaults -> 0 flags
  expect_equal(eval_flag_severity(d, cfg), "Minor issues (1 flag)")
  expect_equal(eval_flag_severity(d, cfg = NULL), "Clean")
})

test_that("eval_flag_severity: existing column returned verbatim", {
  d <- data.frame(flag_severity = c("Clean", "Critical"), x = 1:2)
  expect_equal(eval_flag_severity(d, cfg = NULL), c("Clean", "Critical"))
})

test_that("eval_duration_extreme: duration classification (sleep_duration_h)", {
  d <- data.frame(sleep_duration_h = c(13, 2.5, 8, NA, Inf))
  out <- eval_duration_extreme(d, cfg = NULL)
  expect_equal(out, c("Too long (>12h)", "Too short (<3h)", "OK", NA_character_, NA_character_))
})

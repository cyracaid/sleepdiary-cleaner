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

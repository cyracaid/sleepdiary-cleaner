test_that("the rule defaults are the long-standing values", {
  thr <- sleepcleanr:::.sc_step5_thresholds(list())
  expect_equal(thr$bed_sleep_error, 7)
  expect_equal(thr$awake_getup_error, 7)
  expect_equal(thr$sleep_awake_error, 24)
  expect_equal(thr$sleep_awake_min, 3)
  expect_equal(thr$sleep_awake_max, 15)
  expect_equal(thr$bed_sleep_unusual, 3)
  expect_equal(thr$awake_getup_unusual, 3)
  expect_equal(sleepcleanr:::.sc_clean_categories(list()),
               c("clean", "equal_time_ok", "reasonable_unusual"))
})

test_that("the shipped config carries the same values as the code defaults", {
  def <- sleepcleanr::load_config(NULL)
  thr <- sleepcleanr:::.sc_step5_thresholds(def)
  expect_equal(thr, sleepcleanr:::.sc_rule_defaults)
  expect_equal(sleepcleanr:::.sc_clean_categories(def), sleepcleanr:::.sc_clean_categories_default)
})

test_that("a configured value is used, and an invalid one stops the run", {
  cfg <- list(classification = list(step5 = list(error = list(bed_to_sleep_max_hours = 5))))
  expect_equal(sleepcleanr:::.sc_step5_thresholds(cfg)$bed_sleep_error, 5)
  bad <- list(classification = list(step5 = list(error = list(bed_to_sleep_max_hours = "seven"))))
  expect_error(sleepcleanr:::.sc_step5_thresholds(bad), "must be a single number")
  badc <- list(review = list(clean_categories = 5))
  expect_error(sleepcleanr:::.sc_clean_categories(badc), "list of category names")
})

test_that("changing a threshold changes the category the evaluator gives", {
  t0 <- as.POSIXct("2026-01-01 22:00:00", tz = "UTC")
  df <- data.frame(
    time_bed_corrected   = t0,
    time_sleep_corrected = t0 + 6 * 3600,      # 6 h to fall asleep
    time_awake_corrected = t0 + 14 * 3600,
    time_getup_corrected = t0 + 14.5 * 3600)
  default_cat <- sleepcleanr::eval_data_category(df, cfg = list())
  loose <- list(classification = list(step5 = list(unusual = list(bed_to_sleep_max_hours = 8))))
  strict <- list(classification = list(step5 = list(error = list(bed_to_sleep_max_hours = 5))))
  expect_equal(default_cat, "unusual")                                  # 6 h > 3 h, <= 7 h
  expect_equal(sleepcleanr::eval_data_category(df, cfg = loose), "clean")
  expect_equal(sleepcleanr::eval_data_category(df, cfg = strict), "error")
})

test_that("every rule is listed with its source, and defaults say so", {
  r <- sleepcleanr:::effective_rules(sleepcleanr::load_config(NULL), FALSE)
  expect_true(all(c("key", "value", "default", "source", "meaning") %in% names(r)))
  expect_true(all(r$source == "default"))
  expect_true("classification.step5.error.bed_to_sleep_max_hours" %in% r$key)
  expect_true("include_manual_corrections" %in% r$key)
})

test_that("a changed rule is reported as coming from the user's config", {
  cfg <- sleepcleanr::load_config(NULL)
  cfg$classification$step5$error$bed_to_sleep_max_hours <- 5
  r <- sleepcleanr:::effective_rules(cfg, TRUE)
  row <- r[r$key == "classification.step5.error.bed_to_sleep_max_hours", ]
  expect_equal(row$value, "5")
  expect_equal(row$default, "7")
  expect_equal(row$source, "your config")
  expect_equal(r$value[r$key == "include_manual_corrections"], "true")
  expect_equal(r$source[r$key == "include_manual_corrections"], "call argument")
})

test_that("the rules are printed and saved with the results", {
  d <- tempfile("rules"); dir.create(d)
  cfg <- sleepcleanr::load_config(NULL); cfg$output$report$dir <- d
  out <- capture.output(sleepcleanr:::report_effective_rules(cfg, FALSE, verbose = TRUE))
  expect_true(any(grepl("Rules in effect for this run", out)))
  saved <- utils::read.csv(file.path(d, "effective_rules.csv"), stringsAsFactors = FALSE)
  expect_true(nrow(saved) >= 20)
  unlink(d, recursive = TRUE)
})

test_that("the closing line says where changed rules come from", {
  d <- tempfile("rules"); dir.create(d)
  cfg <- sleepcleanr::load_config(NULL); cfg$output$report$dir <- d
  out <- capture.output(sleepcleanr:::report_effective_rules(cfg, TRUE, verbose = TRUE))
  expect_true(any(grepl("0 rule\\(s\\) set in your config, 1 set by the call", out)))
  cfg$classification$step5$error$bed_to_sleep_max_hours <- 5
  out2 <- capture.output(sleepcleanr:::report_effective_rules(cfg, FALSE, verbose = TRUE))
  expect_true(any(grepl("1 rule\\(s\\) set in your config, 0 set by the call", out2)))
  unlink(d, recursive = TRUE)
})

test_that("the review rules are listed, and a changed one is reported as the user's", {
  cfg <- sleepcleanr::load_config(NULL)
  keys <- c("review.done_when.max_needs_review", "review.missing_times_ok_after_manual",
            "review.step8_flags_need_review", "review.fail_if_not_done")
  r <- sleepcleanr:::effective_rules(cfg, FALSE)
  expect_true(all(keys %in% r$key))
  expect_equal(r$value[r$key == "review.missing_times_ok_after_manual"], "FALSE")
  cfg$review$missing_times_ok_after_manual <- TRUE
  r2 <- sleepcleanr:::effective_rules(cfg, FALSE)
  row <- r2[r2$key == "review.missing_times_ok_after_manual", ]
  expect_equal(row$value, "TRUE")
  expect_equal(row$source, "your config")
  # a config without a review block reports the defaults
  cfg$review <- NULL
  r3 <- sleepcleanr:::effective_rules(cfg, FALSE)
  expect_true(all(r3$source[r3$key %in% keys] == "default"))
})

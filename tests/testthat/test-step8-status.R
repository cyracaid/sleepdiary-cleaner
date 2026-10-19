test_that("a manually corrected row is fixed only when Step 8 and the re-check both pass", {
  raw    <- c("CLEAN", "CLEAN", "DURATION_ISSUE", "CLEAN",  "TIMESTAMP_ISSUE", "CLEAN")
  manual <- c(TRUE,    TRUE,    TRUE,             FALSE,    FALSE,             TRUE)
  cat    <- c("clean", "error", "clean",          "error",  "clean",           "equal_time_ok")
  out <- sleepcleanr:::step8_final_status(raw, manual, cat)
  expect_equal(out, c("CLEAN (Manually Fixed)", "STILL FAILS (Manually Corrected)",
                      "DURATION_ISSUE", "CLEAN", "TIMESTAMP_ISSUE", "CLEAN (Manually Fixed)"))
})

test_that("a missing data_category counts as failing, NA manually_corrected as not corrected", {
  out <- sleepcleanr:::step8_final_status(c("CLEAN", "CLEAN"), c(TRUE, NA), c(NA, "error"))
  expect_equal(out, c("STILL FAILS (Manually Corrected)", "CLEAN"))
  # without data_category only the Step 8 checks are used
  expect_equal(sleepcleanr:::step8_final_status("CLEAN", TRUE), "CLEAN (Manually Fixed)")
})

test_that("the status counts put every row in one category and add up to the total", {
  rs <- data.frame(final_status = c("CLEAN", "CLEAN (Manually Fixed)",
    "STILL FAILS (Manually Corrected)", "DURATION_ISSUE", "SELF_REPORTED_FLAG", "CLEAN"))
  cnt <- sleepcleanr:::step8_status_counts(rs)
  expect_equal(sum(cnt$Count), nrow(rs))
  expect_equal(cnt$Count[cnt$Category == "CLEAN"], 2L)
  expect_equal(cnt$Count[cnt$Category == "SELF-REPORTED FLAG"], 1L)
  expect_equal(cnt$Count[cnt$Category == "STILL FAILS (Manually Corrected)"], 1L)
  expect_equal(cnt$Category, c("TIMESTAMP_ISSUE", "DURATION_ISSUE", "AMOUNT_FLAG",
    "SELF-REPORTED FLAG", "CLEAN", "CLEAN (Manually Fixed)", "STILL FAILS (Manually Corrected)"))
})

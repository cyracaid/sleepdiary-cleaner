# test-interval.R — process_interval colon edge cases
# process_interval lives in inst/scripts/, sourced at runtime by pipeline
sdir <- system.file("scripts", package = "splsleep")
if (sdir == "") sdir <- file.path(getwd(), "inst", "scripts")
src <- file.path(sdir, "process_interval.R")
if (file.exists(src)) source(src, local = TRUE)

test_that("00:000 normalizes to 00:00 with mincalc=0", {
  skip_if_not(exists("process_interval"), "process_interval function not available")
  df <- data.frame(vigorous = c("00:000", "000:45"), stringsAsFactors = FALSE)
  result <- process_interval(df, "vigorous", "interval_hhmm")
  expect_equal(result$vigorous[1], "00:00")
  expect_equal(result$vigorous_mincalc[1], 0)
  expect_false(isTRUE(result$vigorous_checkforerrors[1]))
  expect_equal(result$vigorous[2], "00:45")
  expect_equal(result$vigorous_mincalc[2], 45)
  expect_false(isTRUE(result$vigorous_checkforerrors[2]))
})

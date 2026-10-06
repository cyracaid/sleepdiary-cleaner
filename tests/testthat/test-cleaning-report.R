# test-cleaning-report.R -- the generated description states only counts present in
# the results, and fails clearly when there are no results.

fake <- function(manual = 0) {
  n <- 20
  x <- data.frame(pid = rep(1:4, each = 5), day_num = rep(1:5, 4), row_id = seq_len(n),
                  corrected = c(rep(TRUE, 6), rep(FALSE, 14)),
                  correction_type = c(rep("sleep_reduce_12h_loop", 4), rep("bed_sleep_swap_3h", 2),
                                      rep(NA_character_, 14)),
                  manually_corrected = c(rep(TRUE, manual), rep(FALSE, n - manual)),
                  self_diffcalc_totalsleeptime_minutes = c(rep(420, 15), rep(NA, 5)),
                  stringsAsFactors = FALSE)
  list(corrected_ema_data = x,
       review_output = list(checkforerrors_df = data.frame(row_id = 1:3)),
       pipeline_config = NULL)
}

test_that("cleaning_report counts what is in the results", {
  out <- capture.output(rep <- cleaning_report(fake(manual = 2)))
  txt <- paste(rep$text, collapse = " ")
  expect_match(txt, "20 entries from 4 participants")
  expect_match(txt, "15 entries \\(75.0%\\) had a computable total sleep time")
  expect_match(txt, "corrected 6 entries")
  expect_match(txt, "sleep_reduce_12h_loop \\(4\\)")
  expect_match(txt, "bed_sleep_swap_3h \\(2\\)")
  expect_match(txt, "A reviewer corrected 2 entries")
  expect_match(txt, "3 entries \\(15.0%\\) remained in the review queue")
  expect_equal(rep$counts$entries, c(4L, 2L))
})

test_that("cleaning_report says so when no reviewer corrections were applied", {
  capture.output(rep <- cleaning_report(fake(manual = 0)))
  expect_match(paste(rep$text, collapse = " "), "No reviewer corrections were applied")
})

test_that("cleaning_report fails clearly without results and can write a file", {
  expect_error(cleaning_report(list()), "No pipeline results")
  f <- tempfile(fileext = ".md"); on.exit(unlink(f), add = TRUE)
  capture.output(cleaning_report(fake(), file = f))
  expect_true(file.exists(f)); expect_length(readLines(f), 2L)
})

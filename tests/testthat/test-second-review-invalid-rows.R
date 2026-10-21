# Second-review rows whose pid or day_num is not a number cannot identify a record.
# What happens to them is the user's choice: skip (and list) or stop.

load_second_review <- function(cfg) {
  src <- system.file("scripts", "apply_second_review.R", package = "sleepcleanr")
  if (!nzchar(src)) src <- file.path(testthat::test_path("..", ".."), "inst", "scripts", "apply_second_review.R")
  env <- new.env(parent = asNamespace("sleepcleanr"))
  env$pipeline_config <- cfg
  sys.source(src, envir = env)
  env
}

mk_checklist <- function(path) {
  utils::write.csv(data.frame(
    target_csv = "manual_error_corrections",
    pid = c("1001", " not format error. Person said it was MM:SS", "1003"),
    day_num = c("2", " but exercise uses HH:MM format", "5"),
    row_id = c(10, NA, 30), consensus_reached = TRUE, final_action = "apply_correction",
    stringsAsFactors = FALSE), path, row.names = FALSE)
}

test_that("by default invalid rows are left out, listed, and the rest is used", {
  d <- tempfile("sr"); dir.create(d); f <- file.path(d, "chk.csv"); mk_checklist(f)
  old <- setwd(d); on.exit(setwd(old), add = TRUE)
  env <- load_second_review(list(output = list(report = list(dir = file.path(d, "out")))))
  out <- capture.output(env$apply_second_review(f))
  expect_true(any(grepl("verify|VERIFY", out)))
  expect_true(any(grepl("file line 3", out)))
  expect_false(any(grepl("not format error", out)))                 # the text is not echoed as an id
  expect_equal(sum(grepl("pid=1001|pid=1003", out)), 2)
  sk <- utils::read.csv(file.path(d, "out", "second_review_rows_skipped.csv"))
  expect_equal(sk$file_line, 3)
})

test_that("with stop the run stops and names the lines", {
  d <- tempfile("sr"); dir.create(d); f <- file.path(d, "chk.csv"); mk_checklist(f)
  old <- setwd(d); on.exit(setwd(old), add = TRUE)
  env <- load_second_review(list(second_review = list(on_invalid_rows = "stop"),
                                 output = list(report = list(dir = file.path(d, "out")))))
  expect_error(env$apply_second_review(f), "file line 3")
})

test_that("an unknown choice is an error, and a clean file writes a header-only list", {
  d <- tempfile("sr"); dir.create(d); f <- file.path(d, "chk.csv")
  utils::write.csv(data.frame(target_csv = "manual_error_corrections", pid = "1", day_num = "2",
    row_id = 3, consensus_reached = TRUE, final_action = "x"), f, row.names = FALSE)
  old <- setwd(d); on.exit(setwd(old), add = TRUE)
  bad <- load_second_review(list(second_review = list(on_invalid_rows = "ignore")))
  expect_error(bad$apply_second_review(f), "must be \"skip\" or \"stop\"")
  ok <- load_second_review(list(output = list(report = list(dir = file.path(d, "out")))))
  invisible(capture.output(ok$apply_second_review(f)))
  expect_equal(nrow(utils::read.csv(file.path(d, "out", "second_review_rows_skipped.csv"))), 0)
})

mk_ws <- function(ids) data.frame(pid = rep(1, length(ids)), day_num = ids, row_id = ids,
  error_type = rep("order", length(ids)), problem_humanidentified = rep("", length(ids)),
  in_manual_file = rep("", length(ids)), review_resolution = rep("", length(ids)),
  resolved_at = rep("", length(ids)), resolved_by = rep("", length(ids)),
  stringsAsFactors = FALSE)

test_that("post_correction_review separates remaining, resolved and new", {
  ws <- mk_ws(1:4)
  final <- data.frame(pid = 1, day_num = c(1:4, 9), row_id = c(1:4, 9),
    data_category = c("clean", "error", "equal_time_ok", "error", "error"),
    stringsAsFactors = FALSE)
  r <- sleepcleanr:::post_correction_review(ws, mk_ws(integer(0)), final)
  expect_equal(r$n_before, 4)
  expect_equal(r$n_resolved, 2)
  expect_equal(sort(r$remaining$row_id), c(2, 4))
  expect_equal(r$new$row_id, 9)
})

test_that("a row on the unusual worksheet is not reported as a new error", {
  final <- data.frame(pid = 1, day_num = 1:2, row_id = 1:2,
    data_category = c("error", "error"), stringsAsFactors = FALSE)
  r <- sleepcleanr:::post_correction_review(mk_ws(1L), mk_ws(2L), final)
  expect_equal(nrow(r$new), 0)
  expect_equal(r$remaining$row_id, 1)
})

test_that("write_post_correction_review writes status, keeps columns, handles none", {
  old <- setwd(tempdir()); on.exit(setwd(old), add = TRUE)
  ws <- mk_ws(1:2)
  final <- data.frame(pid = 1, day_num = c(1, 2, 7), row_id = c(1, 2, 7),
    data_category = c("clean", "error", "error"), error_type = c(NA, "order", "gap"),
    stringsAsFactors = FALSE)
  f <- "[NEW]test_review.csv"
  sleepcleanr:::write_post_correction_review(list(error = ws), final, file = f, verbose = FALSE)
  out <- utils::read.csv(f, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(out$review_status, c("remaining", "new_after_correction"))
  expect_equal(out$row_id, c(2, 7))
  expect_true(all(names(ws) %in% names(out)))
  expect_equal(out$error_type, c("order", "gap"))

  final$data_category <- "clean"
  sleepcleanr:::write_post_correction_review(list(error = ws), final, file = f, verbose = FALSE)
  expect_equal(nrow(utils::read.csv(f, check.names = FALSE)), 0)
  unlink(f)
})

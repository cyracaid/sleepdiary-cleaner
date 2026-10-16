mk_ws <- function(ids, in_file = rep("", length(ids))) data.frame(
  pid = rep(1, length(ids)), day_num = ids, row_id = ids,
  error_type = rep("order", length(ids)), problem_humanidentified = rep("", length(ids)),
  in_manual_file = in_file, review_resolution = rep("", length(ids)),
  resolved_at = rep("", length(ids)), resolved_by = rep("", length(ids)),
  stringsAsFactors = FALSE)

test_that("only old rows not yet incorporated stay on the worksheet", {
  # rows 1-5: 1 clean now, 2 and 3 still errors and not in a manual file,
  # 4 still an error but already in a manual file, 5 passes; row 9 is new.
  ws <- mk_ws(1:5, in_file = c("", "", "", "manual_error_corrections.csv", "manual_error_corrections.csv"))
  final <- data.frame(pid = 1, day_num = c(1:5, 9), row_id = c(1:5, 9),
    data_category = c("clean", "error", "error", "error", "clean", "error"),
    stringsAsFactors = FALSE)
  r <- sleepcleanr:::post_correction_review(ws, mk_ws(integer(0)), final)
  expect_equal(r$n_before, 5)
  expect_equal(r$n_resolved, 2)
  expect_equal(sort(r$remaining$row_id), c(2, 3))
  expect_equal(r$incorporated_open$row_id, 4)
  expect_equal(r$new$row_id, 9)
})

test_that("a row on the unusual worksheet is not reported as a new error", {
  final <- data.frame(pid = 1, day_num = 1:2, row_id = 1:2,
    data_category = c("error", "error"), stringsAsFactors = FALSE)
  r <- sleepcleanr:::post_correction_review(mk_ws(1L), mk_ws(2L), final)
  expect_equal(nrow(r$new), 0)
  expect_equal(r$remaining$row_id, 1)
})

test_that("write_post_correction_review writes the worksheet and the incorporated file", {
  old <- setwd(tempdir()); on.exit(setwd(old), add = TRUE)
  ws <- mk_ws(1:3, in_file = c("", "", "manual_error_corrections.csv"))
  final <- data.frame(pid = 1, day_num = c(1, 2, 3, 7), row_id = c(1, 2, 3, 7),
    data_category = c("clean", "error", "error", "error"),
    error_type = c(NA, "order", "order", "gap"), stringsAsFactors = FALSE)
  f <- "[NEW]test_review.csv"; g <- file.path("out_test", "inc.csv")
  sleepcleanr:::write_post_correction_review(list(error = ws), final, file = f,
                                             incorporated_file = g, verbose = FALSE)
  out <- utils::read.csv(f, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(out$review_status, c("remaining", "new_after_correction"))
  expect_equal(out$row_id, c(2, 7))
  expect_true(all(names(ws) %in% names(out)))
  inc <- utils::read.csv(g, check.names = FALSE)
  expect_equal(inc$row_id, 3)

  final$data_category <- "clean"
  sleepcleanr:::write_post_correction_review(list(error = ws), final, file = f,
                                             incorporated_file = g, verbose = FALSE)
  expect_equal(nrow(utils::read.csv(f, check.names = FALSE)), 0)
  unlink(c(f, "out_test"), recursive = TRUE)
})

mk_ws <- function(ids, in_file = rep("", length(ids))) data.frame(
  pid = rep(1, length(ids)), day_num = ids, row_id = ids,
  error_type = rep("order", length(ids)), problem_humanidentified = rep("", length(ids)),
  in_manual_file = in_file, review_resolution = rep("", length(ids)),
  resolved_at = rep("", length(ids)), resolved_by = rep("", length(ids)),
  stringsAsFactors = FALSE)

test_that("every row gets one explicit status and none is dropped", {
  # 1 clean now (not in a manual file), 2 and 3 still errors (not in a manual file),
  # 4 still an error but in a manual file, 5 clean now and in a manual file, 9 is new.
  ws <- mk_ws(1:5, in_file = c("", "", "", "manual_error_corrections.csv", "manual_error_corrections.csv"))
  final <- data.frame(pid = 1, day_num = c(1:5, 9), row_id = c(1:5, 9),
    data_category = c("clean", "error", "error", "error", "clean", "error"),
    stringsAsFactors = FALSE)
  out <- sleepcleanr:::build_review_status_table(ws, mk_ws(integer(0)), final)
  expect_equal(nrow(out), 6)
  st <- setNames(out$status_after_corrections, out$row_id)
  expect_equal(unname(st[c("1", "2", "3", "4", "5", "9")]),
               c("not_in_manual_file_now_passes", "not_in_manual_file_still_fails",
                 "not_in_manual_file_still_fails", "in_manual_file_still_fails",
                 "in_manual_file_now_passes", "new_after_corrections"))
  expect_equal(out$source[out$row_id == 9], "new_after_corrections")
  expect_equal(out$category_before_corrections[out$row_id == 9], "not_on_step5_list")
  expect_equal(out$category_after_corrections[out$row_id == 4], "error")
})

test_that("rows that still need a person come first, in a fixed order", {
  ws <- mk_ws(1:4, in_file = c("manual_error_corrections.csv", "", "", "manual_error_corrections.csv"))
  final <- data.frame(pid = 1, day_num = 1:4, row_id = 1:4,
    data_category = c("clean", "error", "clean", "error"), stringsAsFactors = FALSE)
  out <- sleepcleanr:::build_review_status_table(ws, mk_ws(integer(0)), final)
  expect_equal(out$status_after_corrections,
               c("not_in_manual_file_still_fails", "in_manual_file_still_fails",
                 "not_in_manual_file_now_passes", "in_manual_file_now_passes"))
  # same input again gives the same table
  expect_identical(out, sleepcleanr:::build_review_status_table(ws, mk_ws(integer(0)), final))
})

test_that("a row on the unusual worksheet is not reported as a new error", {
  final <- data.frame(pid = 1, day_num = 1:2, row_id = 1:2,
    data_category = c("error", "error"), stringsAsFactors = FALSE)
  out <- sleepcleanr:::build_review_status_table(mk_ws(1L), mk_ws(2L), final)
  expect_equal(nrow(out), 1)
  expect_equal(out$status_after_corrections, "not_in_manual_file_still_fails")
})

test_that("Step 8 flags go in their own column and do not change the status", {
  ws <- mk_ws(1:2)
  final <- data.frame(pid = 1, day_num = 1:2, row_id = 1:2,
    data_category = c("clean", "clean"), stringsAsFactors = FALSE)
  flags <- data.frame(pid = 1, day_num = 1:2, row_id = 1:2,
    needs_review_flag = c(TRUE, FALSE), auto_error_desc = c("SOL excessive", NA),
    stringsAsFactors = FALSE)
  out <- sleepcleanr:::build_review_status_table(ws, mk_ws(integer(0)), final, flags)
  expect_equal(out$status_after_corrections, rep("not_in_manual_file_now_passes", 2))
  expect_equal(out$step8_flags_after_corrections[out$row_id == 1], "SOL excessive")
  expect_equal(out$step8_flags_after_corrections[out$row_id == 2], "")
})

test_that("write_review_status_table writes the columns in the agreed order, also when empty", {
  old <- setwd(tempdir()); on.exit(setwd(old), add = TRUE)
  ws <- mk_ws(1:2)
  final <- data.frame(pid = 1, day_num = c(1, 2, 7), row_id = c(1, 2, 7),
    data_category = c("clean", "error", "error"), error_type = c(NA, "order", "gap"),
    stringsAsFactors = FALSE)
  f <- "[NEW]test_status.csv"
  sleepcleanr:::write_review_status_table(list(error = ws), final, file = f, verbose = FALSE)
  out <- utils::read.csv(f, check.names = FALSE, stringsAsFactors = FALSE)
  expect_equal(names(out)[1:9], c("pid", "day_num", "row_id", "source", "status_after_corrections",
    "in_manual_file", "category_before_corrections", "category_after_corrections",
    "step8_flags_after_corrections"))
  expect_equal(nrow(out), 3)
  expect_true(all(names(ws) %in% names(out)))

  bare <- mk_ws(integer(0))[, c("pid", "day_num", "row_id", "error_type")]   # no annotation columns
  sleepcleanr:::write_review_status_table(list(error = bare), final[0, ], file = f, verbose = FALSE)
  empty <- utils::read.csv(f, check.names = FALSE)
  expect_equal(nrow(empty), 0)
  expect_true("in_manual_file" %in% names(empty))
  unlink(f)
})

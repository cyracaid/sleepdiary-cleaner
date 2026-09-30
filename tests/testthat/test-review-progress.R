# [NEW] worksheet annotation and review-state counts (pure functions; no
# pipeline run). Files are only touched inside withr::local_tempdir().

ws_error <- data.frame(pid = c(1, 1, 2, 3), day_num = c(1, 2, 1, 1), row_id = c(10, 11, 12, 13),
                       error_type = "order_error", stringsAsFactors = FALSE)
manual_error <- data.frame(
  pid = c(1, 1, 3), day_num = c(1, 2, 1), row_id = c(10, 11, 13),
  review_resolution = c("corrected", "resolution_unknown_legacy", "flagged_unresolved"),
  resolved_at = c("2026-09-01", NA, NA), resolved_by = c("cd_mtb", "", "pending"),
  stringsAsFactors = FALSE
)

test_that("annotate copies the existing resolution columns onto matching rows", {
  out <- annotate_review_worksheet(ws_error, manual_error, "manual_error_corrections.csv")
  expect_equal(out$in_manual_file, c(rep("manual_error_corrections.csv", 2), "",
                                     "manual_error_corrections.csv"))
  expect_equal(out$review_resolution, c("corrected", "resolution_unknown_legacy", "", "flagged_unresolved"))
  expect_equal(out$resolved_by, c("cd_mtb", "", "", "pending"))
  expect_equal(nrow(out), nrow(ws_error))
  expect_true(all(names(ws_error) %in% names(out)))
})

test_that("a row that is in no manual file has all four new columns empty", {
  out <- annotate_review_worksheet(ws_error, manual_error, "m.csv")
  expect_equal(unlist(out[out$row_id == 12, c("in_manual_file", "review_resolution",
                                              "resolved_at", "resolved_by")], use.names = FALSE),
               rep("", 4))
})

test_that("annotating twice gives the same columns, not duplicates", {
  once <- annotate_review_worksheet(ws_error, manual_error, "m.csv")
  twice <- annotate_review_worksheet(once, manual_error, "m.csv")
  expect_identical(names(once), names(twice))
})

test_that("an empty or missing manual file leaves every row unhandled", {
  out <- annotate_review_worksheet(ws_error, data.frame(), "m.csv")
  expect_true(all(out$in_manual_file == ""))
  expect_equal(nrow(annotate_review_worksheet(ws_error[0, ], manual_error, "m.csv")), 0)
})

test_that("BOM-prefixed column names in the manual file still match", {
  m <- manual_error; names(m)[1] <- "\ufeffpid"
  out <- annotate_review_worksheet(ws_error, m, "m.csv")
  expect_equal(sum(out$in_manual_file != ""), 3)
})

final <- data.frame(pid = c(1, 1, 2, 3), day_num = c(1, 2, 1, 1), row_id = c(10, 11, 12, 13),
                    data_category = c("clean", "equal_time_ok", "error", "error"),
                    stringsAsFactors = FALSE)
flags <- data.frame(pid = final$pid, day_num = final$day_num, row_id = final$row_id,
                    needs_review_flag = c(FALSE, TRUE, FALSE, FALSE))

test_that("counts separate not handled, pending, legacy, corrected and still-a-problem", {
  ws <- list(error = annotate_review_worksheet(ws_error, manual_error, "m.csv"))
  cnt <- review_state_counts(ws, final, flags)
  expect_equal(cnt$rows, 4)
  expect_equal(cnt$not_handled, 1)
  expect_equal(cnt$pending, 1)
  expect_equal(cnt$legacy, 1)
  expect_equal(cnt$corrected, 1)
  # row 11 is still flagged by the check; row 13 is still an error after correction
  expect_equal(cnt$still_problem_after_check, 2)
})

test_that("nothing to count gives NULL", {
  expect_null(review_state_counts(list(error = ws_error[0, ]), final, flags))
  expect_null(review_state_counts(list(), final, flags))
})

test_that("annotate_review_worksheets rewrites the files with the same rows", {
  dir <- withr::local_tempdir(); withr::local_dir(dir)
  utils::write.csv(ws_error, "[NEW]manual_error_correction_review.csv", row.names = FALSE)
  out <- annotate_review_worksheets(manual_error, data.frame(), verbose = FALSE)
  back <- utils::read.csv("[NEW]manual_error_correction_review.csv", stringsAsFactors = FALSE)
  expect_equal(nrow(back), nrow(ws_error))
  expect_true(all(.rp_added_cols %in% names(back)))
  expect_equal(nrow(out$error), nrow(ws_error))
  expect_null(out$unusual)
})

test_that("an unusual row that stays unusual after review is not a problem, an error row is", {
  wu <- data.frame(pid = 5, day_num = 1, row_id = 30)
  mu <- data.frame(pid = 5, day_num = 1, row_id = 30, review_resolution = "corrected",
                   resolved_at = "", resolved_by = "x", stringsAsFactors = FALSE)
  fin <- data.frame(pid = 5, day_num = 1, row_id = 30, data_category = "unusual")
  cnt <- review_state_counts(list(unusual = annotate_review_worksheet(wu, mu, "m")), fin, NULL)
  expect_equal(cnt$still_problem_after_check, 0)
  cnt2 <- review_state_counts(list(error = annotate_review_worksheet(wu, mu, "m")), fin, NULL)
  expect_equal(cnt2$still_problem_after_check, 1)
})

test_that("a manual row with no row_id still marks its pid/day record as handled", {
  m <- data.frame(pid = c(1, 2), day_num = c(1, 1), row_id = c(NA, 12),
                  review_resolution = c("resolution_unknown_legacy", "corrected"),
                  stringsAsFactors = FALSE)
  out <- annotate_review_worksheet(ws_error, m, "f.csv")
  expect_equal(out$in_manual_file, c("f.csv", "", "f.csv", ""))
  expect_equal(out$review_resolution[1], "resolution_unknown_legacy")
  # a different day of the same participant is not matched by the fallback
  expect_equal(out$in_manual_file[2], "")
})

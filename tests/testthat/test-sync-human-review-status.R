# test-sync-human-review-status.R -- sync_human_review_status()
#
# R/sync_human_review_status.R had 0% coverage, and the function threw on the
# first call: case_when() evaluated has_human_trace() with no `row` argument.
# These tests exercise the documented call (README) on a synthetic CSV and pin
# the resolution rules. Synthetic data only: nothing here is real data.

.sync_fixture <- function(dir) {
  d <- data.frame(
    pid = 1:4,
    day_num = 1:4,
    review_resolution = c("legacy", "corrected", "legacy", "flagged_unresolved"),
    human_metric_review_note = c("looks fine", "", "", ""),
    resolved_at = c("", "2026-10-01", "", ""),
    resolved_by = c("", "cyra", "", ""),
    stringsAsFactors = FALSE
  )
  path <- file.path(dir, "manual_metric_review_acceptances.csv")
  utils::write.csv(d, path, row.names = FALSE, na = "")
  path
}

test_that("sync_human_review_status() resolves rows from human traces", {
  path <- .sync_fixture(withr::local_tempdir())
  out <- sync_human_review_status(path, overwrite = FALSE)

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 4)
  expect_true(all(c("has_human_trace", "review_resolution",
                    "resolved_at", "resolved_by") %in% names(out)))

  expect_equal(out$review_resolution[out$pid == 1], "flagged_unresolved")
  expect_equal(out$review_resolution[out$pid == 2], "corrected")
  expect_equal(out$review_resolution[out$pid == 3], "legacy")
  expect_true(out$has_human_trace[out$pid == 1])
  expect_false(out$has_human_trace[out$pid == 3])
})

test_that("sync_human_review_status() keeps what a person already recorded", {
  path <- .sync_fixture(withr::local_tempdir())
  out <- sync_human_review_status(path, overwrite = FALSE)

  # pid 2 is corrected and already carries resolved_at = 2026-10-01,
  # resolved_by = cyra: the sync must not restamp it with today / "system".
  expect_equal(out$resolved_at[out$pid == 2], "2026-10-01")
  expect_equal(out$resolved_by[out$pid == 2], "cyra")
})

test_that("sync_human_review_status() fills blanks and refreshes its own pending", {
  d <- data.frame(
    pid = 1:3,
    day_num = 1:3,
    review_resolution = c("corrected", "corrected", "legacy"),
    human_metric_review_note = c("", "", ""),
    resolved_at = c("", "", ""),
    resolved_by = c("", "pending", ""),
    stringsAsFactors = FALSE
  )
  path <- file.path(withr::local_tempdir(), "accept.csv")
  utils::write.csv(d, path, row.names = FALSE, na = "")

  out <- sync_human_review_status(path, overwrite = FALSE)

  # blank + corrected -> stamped by the system
  expect_equal(out$resolved_by[out$pid == 1], "system")
  expect_equal(out$resolved_at[out$pid == 1], format(Sys.Date(), "%Y-%m-%d"))
  # "pending" is this function's placeholder, so it is refreshed
  expect_equal(out$resolved_by[out$pid == 2], "system")
  # legacy without traces stays legacy
  expect_equal(out$resolved_by[out$pid == 3], "legacy")
})

test_that("sync_human_review_status() writes only when overwrite = TRUE", {
  path <- .sync_fixture(withr::local_tempdir())
  before <- readLines(path)

  invisible(sync_human_review_status(path, overwrite = FALSE))
  expect_identical(readLines(path), before)

  invisible(sync_human_review_status(path, overwrite = TRUE))
  after <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_true("has_human_trace" %in% names(after))
  expect_equal(after$review_resolution[after$pid == 1], "flagged_unresolved")
})

test_that("sync_human_review_status() warns and returns NULL without the note column", {
  path <- file.path(withr::local_tempdir(), "no_note.csv")
  utils::write.csv(data.frame(pid = 1L, review_resolution = "legacy"),
                   path, row.names = FALSE)

  expect_warning(out <- sync_human_review_status(path, overwrite = FALSE),
                 "Missing human_metric_review_note column")
  expect_null(out)
})

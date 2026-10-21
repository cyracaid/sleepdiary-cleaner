# "Did a person look at this row, and what came of it" reaches the delivered data.

test_that("mark_reasonable_unusual marks the main data, not a copy", {
  d <- data.frame(pid = c(1, 1, 2), row_id = c(10, 11, 12),
                  data_category = c("unusual", "unusual", "clean"),
                  is_unusual = c(TRUE, TRUE, FALSE), stringsAsFactors = FALSE)
  m <- data.frame(pid = c(1, 2), row_id = c(10, 12),
                  problem_humanidentified = c("Reasonable unusual record. Seen it.", "Fixed AM/PM"),
                  stringsAsFactors = FALSE)
  out <- sleepcleanr:::mark_reasonable_unusual(d, m)
  expect_equal(out$data_category, c("reasonable_unusual", "unusual", "clean"))
  expect_equal(out$is_reasonable_unusual, c(TRUE, FALSE, FALSE))
  expect_equal(out$is_unusual, c(FALSE, TRUE, FALSE))
  # nothing to mark: the data come back unchanged
  expect_identical(sleepcleanr:::mark_reasonable_unusual(d, NULL), d)
  expect_identical(sleepcleanr:::mark_reasonable_unusual(d, m[2, ]), d)
})

test_that("human_review says waiting, corrected, accepted or none; an explicit acceptance is not turned back into waiting", {
  dict_path <- system.file("extdata", "column_dictionary.csv", package = "sleepcleanr")
  if (!nzchar(dict_path)) dict_path <- file.path(testthat::test_path("..", ".."), "inst", "extdata", "column_dictionary.csv")
  dict <- utils::read.csv(dict_path, stringsAsFactors = FALSE, colClasses = "character", na.strings = NULL)
  impl <- dict[dict$status == "implemented" & (nzchar(dict$name_a) | nzchar(dict$name_b)), ]
  n <- 6
  mk <- function(spec) {
    if (!nrow(spec)) return(NULL)
    out <- lapply(spec$source_column, function(cn) {
      if (cn == "pid") return(rep(1001L, n))
      if (cn == "day_num" || cn == "row_id") return(seq_len(n))
      seq_len(n) + 0.5
    })
    names(out) <- spec$source_column
    as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
  }
  options(sleepcleanr.audit_ledger = file.path(tempdir(), "none.csv"),
          sleepcleanr.audit_manual_corrections = file.path(tempdir(), "none2.csv"))
  d <- mk(impl[impl$source_object == "corrected_ema_data", ]); d$human_review <- NULL
  rev <- mk(impl[impl$source_object == "review_output", ])
  if (is.null(rev)) rev <- data.frame(needs_review_flag = rep(FALSE, n))
  d$data_category <- c("clean", "reasonable_unusual", "clean", "clean", "clean", "clean")
  d$manually_corrected <- c(FALSE, FALSE, TRUE, TRUE, FALSE, FALSE)
  d$human_metric_review_status <- c(NA, NA, NA, NA, "confirmed_not_error_do_not_correct", NA)
  # row 2 is flagged by Step 8 but a person already accepted it; row 4 is flagged and nobody has
  rev$needs_review_flag <- c(FALSE, TRUE, FALSE, TRUE, FALSE, FALSE)
  res <- sleepcleanr::finalize_columns(d, review_data = rev, dict_path = dict_path,
                                       write = FALSE, verbose = FALSE)
  expect_equal(res$final$human_review,
               c("none", "accepted", "corrected", "waiting", "accepted", "none"))
  expect_false("needs_review" %in% names(res$final))
  expect_false("is_reasonable_unusual" %in% names(res$final))
})

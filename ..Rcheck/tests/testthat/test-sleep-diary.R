# Unit tests for the sleep_diary S3 class.
#
# These deliberately use synthetic data only, so they run on CI without the
# real dataset and without any Suggests package being installed.

make_df <- function(n = 3) {
  data.frame(
    pid = seq_len(n),
    day_num = rep(1L, n),
    value = as.numeric(seq_len(n)),
    stringsAsFactors = FALSE
  )
}

test_that("constructor builds a valid object", {
  x <- new_sleep_diary(make_df(5), step_id = "1", step_label = "Load data")

  expect_s3_class(x, "sleep_diary")
  expect_true(is_sleep_diary(x))
  expect_equal(x$step$id, "1")
  expect_equal(x$step$label, "Load data")
  expect_equal(x$step$n_rows, 5L)
  expect_equal(x$step$version, "1.3.0")
  expect_length(x$history, 0L)
})

test_that("constructor rejects malformed input", {
  expect_error(new_sleep_diary(list(a = 1)), "must be a data frame")
  expect_error(new_sleep_diary(make_df(), step_id = 1), "single character")
  expect_error(new_sleep_diary(make_df(), step_label = c("a", "b")),
               "single character")
})

test_that("validator catches structural damage", {
  x <- new_sleep_diary(make_df())

  expect_silent(validate_sleep_diary(x))
  expect_error(validate_sleep_diary(make_df()), "Expected a <sleep_diary>")

  broken <- x
  broken$data <- NULL
  expect_error(validate_sleep_diary(broken), "missing component")

  broken2 <- x
  broken2$data <- "not a data frame"
  expect_error(validate_sleep_diary(broken2), "must be a data frame")

  broken3 <- x
  broken3$step <- list()
  expect_error(validate_sleep_diary(broken3), "at least an `id`")
})

test_that("as_sleep_diary is idempotent and coerces data frames", {
  df <- make_df(4)
  x <- as_sleep_diary(df)

  expect_s3_class(x, "sleep_diary")
  expect_identical(as_sleep_diary(x), x)
  expect_equal(nrow(as.data.frame(x)), 4L)
})

test_that("as.data.frame returns the untouched working data", {
  df <- make_df(7)
  x <- new_sleep_diary(df)

  expect_identical(as.data.frame(x), df)
})

test_that("dim/nrow/ncol dispatch through the class", {
  x <- new_sleep_diary(make_df(6))

  expect_equal(dim(x), c(6L, 3L))
  expect_equal(nrow(x), 6L)
  expect_equal(ncol(x), 3L)
})

test_that("print returns its input invisibly and mentions the step", {
  x <- new_sleep_diary(make_df(2), step_id = "4",
                       step_label = "Normalize sequence")

  expect_output(print(x), "step 4")
  expect_output(print(x), "Normalize sequence")
})

test_that("summary tabulates the recorded chain", {
  s1 <- new_sleep_diary(make_df(10), step_id = "1", step_label = "Load data")
  s2 <- new_sleep_diary(make_df(10), step_id = "2",
                        step_label = "Process timestamps",
                        history = c(s1$history, list(s1$step)),
                        extra = list(n_rows_in = 10L,
                                     cols_added = c("a", "b"),
                                     duration_ms = 12.5))

  sm <- summary(s2)
  expect_s3_class(sm, "data.frame")
  expect_equal(nrow(sm), 2L)
  expect_equal(sm$step_id, c("1", "2"))
  expect_equal(sm$n_cols_added, c(0L, 2L))
})

test_that("assert_contract_columns enforces the Step 7 contract", {
  bad <- new_sleep_diary(make_df())
  expect_error(assert_contract_columns(bad), "Contract columns missing")
  expect_equal(assert_contract_columns(bad, error = FALSE),
               c("sleep_efficiency_pct", "sol_h", "waso_h", "sleep_duration_h"))

  good_df <- make_df()
  good_df$sleep_efficiency_pct <- 90
  good_df$sol_h <- 0.5
  good_df$waso_h <- 0.2
  good_df$sleep_duration_h <- 7.5
  good <- new_sleep_diary(good_df)

  expect_silent(assert_contract_columns(good))
  expect_length(assert_contract_columns(good, error = FALSE), 0L)
})

test_that("a step rejects a non-data-frame return value", {
  x <- new_sleep_diary(make_df())

  expect_error(
    sleepcleanr:::.run_step(x, "9", "Bad step", function(df) "oops",
                         verbose = FALSE),
    "not a data frame"
  )
})

test_that("a step records provenance and grows the history", {
  x <- new_sleep_diary(make_df(5), step_id = "1", step_label = "Load data")

  y <- sleepcleanr:::.run_step(x, "2", "Add a column", function(df) {
    df$new_col <- 1
    df
  }, verbose = FALSE)

  expect_s3_class(y, "sleep_diary")
  expect_equal(y$step$id, "2")
  expect_equal(y$step$n_rows_in, 5L)
  expect_equal(y$step$n_rows, 5L)
  expect_equal(y$step$cols_added, "new_col")
  expect_true(!is.na(y$step$duration_ms))
  expect_length(y$history, 1L)
  expect_equal(y$history[[1]]$id, "1")
})

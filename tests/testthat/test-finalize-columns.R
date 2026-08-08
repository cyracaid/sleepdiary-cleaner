# test-finalize-columns.R
#
# Guards the v1.4 delivery contract. Three properties matter:
#   1. the delivered column names match the dictionary exactly
#   2. A and B join on (pid, day_num, row_id) without row multiplication
#   3. unit transforms are actually applied
#
# Property 2 is why row_id was added to Dataset B on 2026-08-09: the pipeline
# itself matches on the pid+day_num+row_id triple, so pid+day_num alone is not
# a safe key.

.dict_path <- function() {
  p <- system.file("extdata", "column_dictionary.csv", package = "splsleep")
  if (!nzchar(p)) p <- file.path("..", "..", "inst", "extdata", "column_dictionary.csv")
  if (!file.exists(p)) p <- file.path("inst", "extdata", "column_dictionary.csv")
  p
}

# Minimal frame carrying every column the dictionary marks 'implemented'.
.fake_data <- function(n = 3) {
  dict <- utils::read.csv(.dict_path(), stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = NULL)
  spec <- dict[(nzchar(dict$name_a) | nzchar(dict$name_b)) &
                 dict$status == "implemented" &
                 dict$source_object == "corrected_ema_data", ]
  out <- lapply(spec$source_column, function(cn) {
    if (cn == "pid")     return(rep(1001L, n))
    if (cn == "day_num") return(seq_len(n))
    if (cn == "row_id")  return(seq_len(n))
    seq_len(n) + 0.5     # numeric placeholder; transforms must survive it
  })
  names(out) <- spec$source_column
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}

.fake_review <- function(n = 3) {
  dict <- utils::read.csv(.dict_path(), stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = NULL)
  spec <- dict[dict$source_object == "review_output" & dict$status == "implemented", ]
  if (!nrow(spec)) return(NULL)
  out <- lapply(spec$source_column, function(cn) rep(FALSE, n))
  names(out) <- spec$source_column
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}

test_that("dictionary is internally consistent", {
  skip_if_not(file.exists(.dict_path()), "column_dictionary.csv not found")
  dict <- utils::read.csv(.dict_path(), stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = NULL)

  expect_false(any(duplicated(dict$source_column)))

  a <- dict$name_a[nzchar(dict$name_a)]
  b <- dict$name_b[nzchar(dict$name_b)]
  expect_false(any(duplicated(a)), info = "Dataset A has duplicate column names")
  expect_false(any(duplicated(b)), info = "Dataset B has duplicate column names")

  expect_true(all(dict$status %in% c("implemented", "pending")))
  expect_true(all(dict$transform == "none" | grepl("^x[0-9.]+$", dict$transform)))
})

test_that("delivered column names match the dictionary exactly", {
  skip_if_not(file.exists(.dict_path()), "column_dictionary.csv not found")
  dict <- utils::read.csv(.dict_path(), stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = NULL)
  res  <- finalize_columns(.fake_data(), review_data = .fake_review(), dict_path = .dict_path(),
                           write = FALSE, verbose = FALSE)

  expected_a <- dict$name_a[nzchar(dict$name_a) & dict$status == "implemented"]
  expected_b <- dict$name_b[nzchar(dict$name_b) & dict$status == "implemented"]

  expect_identical(names(res$final),   expected_a)
  expect_identical(names(res$prepost), expected_b)
})

test_that("A and B join on the full key without multiplying rows", {
  skip_if_not(file.exists(.dict_path()), "column_dictionary.csv not found")
  res <- finalize_columns(.fake_data(n = 5), review_data = .fake_review(5), dict_path = .dict_path(),
                          write = FALSE, verbose = FALSE)

  key <- c("pid", "day_num", "row_id")
  expect_true(all(key %in% names(res$final)))
  expect_true(all(key %in% names(res$prepost)),
              info = "Dataset B must carry row_id or the join is ambiguous")

  joined <- merge(res$final, res$prepost, by = key)
  expect_equal(nrow(joined), nrow(res$final))
})

test_that("unit transforms are applied", {
  skip_if_not(file.exists(.dict_path()), "column_dictionary.csv not found")
  dict <- utils::read.csv(.dict_path(), stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = NULL)
  tf   <- dict[dict$transform != "none" & nzchar(dict$name_a), ]
  skip_if(nrow(tf) == 0, "no transforms defined")

  d   <- .fake_data(n = 3)
  res <- finalize_columns(d, review_data = .fake_review(3), dict_path = .dict_path(), write = FALSE, verbose = FALSE)

  for (i in seq_len(nrow(tf))) {
    factor_ <- as.numeric(sub("^x", "", tf$transform[i]))
    expect_equal(res$final[[tf$name_a[i]]],
                 as.numeric(d[[tf$source_column[i]]]) * factor_,
                 info = paste("transform not applied for", tf$name_a[i]))
  }
})

test_that("a missing promised column stops the build", {
  skip_if_not(file.exists(.dict_path()), "column_dictionary.csv not found")
  d <- .fake_data()
  d$tst_col_removed <- NULL
  d[["self_diffcalc_totalsleeptime_minutes"]] <- NULL

  expect_error(
    finalize_columns(d, review_data = .fake_review(), dict_path = .dict_path(), write = FALSE, verbose = FALSE),
    "not available"
  )
})

test_that("declared defaults fill legitimately-optional columns", {
  skip_if_not(file.exists(.dict_path()), "column_dictionary.csv not found")
  dict <- utils::read.csv(.dict_path(), stringsAsFactors = FALSE,
                  colClasses = "character", na.strings = NULL)
  opt  <- dict[nzchar(dict$default_if_absent) & nzchar(dict$name_a) &
                 dict$status == "implemented", ]
  skip_if(nrow(opt) == 0, "no optional columns declared")

  # is_reasonable_unusual is only created when the data contains at least one
  # reasonable-unusual record, so a dataset with none must still deliver it.
  d <- .fake_data()
  for (cn in opt$source_column) d[[cn]] <- NULL

  res <- finalize_columns(d, review_data = .fake_review(), dict_path = .dict_path(),
                          write = FALSE, verbose = FALSE)
  for (i in seq_len(nrow(opt))) {
    expect_true(opt$name_a[i] %in% names(res$final))
    expect_equal(unique(res$final[[opt$name_a[i]]]),
                 as.logical(opt$default_if_absent[i]))
  }
})

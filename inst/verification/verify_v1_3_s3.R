# Standalone verification for the v1.3.0 sleep_diary S3 layer.
#
# Zero dependencies: base R only. No devtools, no testthat, no renv, no
# tidyverse. Run it when the normal toolchain is unavailable:
#
#   source("verify_v1_3_s3.R")
#
# It sources the four R/ files the S3 layer needs, runs the same assertions as
# tests/testthat/test-sleep-diary.R, and prints one PASS/FAIL line per check.

cat("\n=== splsleep v1.3.0 S3 layer verification (base R only) ===\n")
cat("R version:", R.version.string, "\n")
cat("Working dir:", getwd(), "\n\n")

# --- Source the layer ------------------------------------------------------

needed <- c("R/flag_standards.R", "R/log_step.R", "R/sleep_diary.R", "R/steps.R")
for (f in needed) {
  if (!file.exists(f)) {
    stop("Cannot find ", f, ". Run this from the splsleep project root.")
  }
}
# steps.R references scripts_dir() at call time only; stub it so sourcing is
# safe without pipeline.R (which pulls in yaml via config.R).
if (!exists("scripts_dir")) scripts_dir <- function() getwd()
for (f in needed) {
  res <- tryCatch({ source(f); "ok" }, error = function(e) conditionMessage(e))
  if (!identical(res, "ok")) {
    cat("FAIL  could not source", f, "\n      ", res, "\n")
    stop("Sourcing failed; fix the above before continuing.")
  }
  cat("ok    sourced", f, "\n")
}
cat("\n")

# --- Tiny assertion harness ------------------------------------------------

.pass <- 0L
.fail <- 0L
.failures <- character(0)

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    structure(FALSE, msg = conditionMessage(e))
  })
  msg <- attr(ok, "msg")
  if (isTRUE(ok)) {
    .pass <<- .pass + 1L
    cat(sprintf("PASS  %s\n", label))
  } else {
    .fail <<- .fail + 1L
    .failures <<- c(.failures, label)
    cat(sprintf("FAIL  %s%s\n", label,
                if (is.null(msg)) "" else paste0("\n      error: ", msg)))
  }
}

check_error <- function(label, expr, pattern) {
  got <- tryCatch({ force(expr); NA_character_ },
                  error = function(e) conditionMessage(e))
  ok <- !is.na(got) && grepl(pattern, got, fixed = TRUE)
  if (ok) {
    .pass <<- .pass + 1L
    cat(sprintf("PASS  %s\n", label))
  } else {
    .fail <<- .fail + 1L
    .failures <<- c(.failures, label)
    cat(sprintf("FAIL  %s\n      expected error containing '%s', got: %s\n",
                label, pattern, if (is.na(got)) "no error" else got))
  }
}

make_df <- function(n = 3) {
  data.frame(pid = seq_len(n), day_num = rep(1L, n),
             value = as.numeric(seq_len(n)), stringsAsFactors = FALSE)
}

# --- 1. Constructor --------------------------------------------------------

cat("-- constructor --\n")
x <- new_sleep_diary(make_df(5), step_id = "1", step_label = "Load data")
check("inherits from sleep_diary",     inherits(x, "sleep_diary"))
check("is_sleep_diary() is TRUE",      is_sleep_diary(x))
check("step id recorded",              identical(x$step$id, "1"))
check("step label recorded",           identical(x$step$label, "Load data"))
check("row count recorded",            x$step$n_rows == 5L)
check("version stamped as 1.3.0",      identical(x$step$version, "1.3.0"))
check("history starts empty",          length(x$history) == 0L)

cat("\n-- constructor rejects bad input --\n")
check_error("non-data-frame data rejected",
            new_sleep_diary(list(a = 1)), "must be a data frame")
check_error("numeric step_id rejected",
            new_sleep_diary(make_df(), step_id = 1), "single character")
check_error("vector step_label rejected",
            new_sleep_diary(make_df(), step_label = c("a", "b")), "single character")

# --- 2. Validator ----------------------------------------------------------

cat("\n-- validator --\n")
check("valid object passes", {
  validate_sleep_diary(x); TRUE
})
check_error("plain data frame rejected",
            validate_sleep_diary(make_df()), "Expected a <sleep_diary>")
b1 <- x; b1$data <- NULL
check_error("missing component caught", validate_sleep_diary(b1), "missing component")
b2 <- x; b2$data <- "not a data frame"
check_error("non-data-frame data caught", validate_sleep_diary(b2), "must be a data frame")
b3 <- x; b3$step <- list()
check_error("step without id caught", validate_sleep_diary(b3), "at least an `id`")

# --- 3. Coercion and accessors --------------------------------------------

cat("\n-- coercion and accessors --\n")
df4 <- make_df(4)
check("as_sleep_diary() coerces a data frame",
      inherits(as_sleep_diary(df4), "sleep_diary"))
check("as_sleep_diary() is idempotent",
      identical(as_sleep_diary(x), x))
df7 <- make_df(7)
check("as.data.frame() returns data untouched",
      identical(as.data.frame(new_sleep_diary(df7)), df7))
x6 <- new_sleep_diary(make_df(6))
check("dim() dispatches",  identical(dim(x6), c(6L, 3L)))
check("nrow() dispatches", nrow(x6) == 6L)
check("ncol() dispatches", ncol(x6) == 3L)

# --- 4. print and summary --------------------------------------------------

cat("\n-- print and summary --\n")
x4 <- new_sleep_diary(make_df(2), step_id = "4", step_label = "Normalize sequence")
out <- capture.output(print(x4))
check("print mentions the step id",    any(grepl("step 4", out)))
check("print mentions the step label", any(grepl("Normalize sequence", out)))

s1 <- new_sleep_diary(make_df(10), step_id = "1", step_label = "Load data")
s2 <- new_sleep_diary(make_df(10), step_id = "2", step_label = "Process timestamps",
                      history = c(s1$history, list(s1$step)),
                      extra = list(n_rows_in = 10L, cols_added = c("a", "b"),
                                   duration_ms = 12.5))
sm <- summary(s2)
check("summary is a data frame",       is.data.frame(sm))
check("summary has one row per step",  nrow(sm) == 2L)
check("summary step ids in order",     identical(sm$step_id, c("1", "2")))
check("summary counts added columns",  identical(sm$n_cols_added, c(0L, 2L)))

# --- 5. Step 7 contract ----------------------------------------------------

cat("\n-- Step 7 contract --\n")
bad <- new_sleep_diary(make_df())
check_error("missing contract columns raise",
            assert_contract_columns(bad), "Contract columns missing")
check("missing columns listed when error = FALSE",
      identical(assert_contract_columns(bad, error = FALSE),
                c("sleep_efficiency_pct", "sol_h", "waso_h", "sleep_duration_h")))
gdf <- make_df()
gdf$sleep_efficiency_pct <- 90; gdf$sol_h <- 0.5
gdf$waso_h <- 0.2;              gdf$sleep_duration_h <- 7.5
check("complete contract passes",
      length(assert_contract_columns(new_sleep_diary(gdf), error = FALSE)) == 0L)

# --- 6. Step runner --------------------------------------------------------

cat("\n-- step runner --\n")
check_error("non-data-frame return rejected",
            .run_step(x, "9", "Bad step", function(df) "oops", verbose = FALSE),
            "not a data frame")

y <- .run_step(new_sleep_diary(make_df(5), step_id = "1", step_label = "Load data"),
               "2", "Add a column",
               function(df) { df$new_col <- 1; df }, verbose = FALSE)
check("result is a sleep_diary",   inherits(y, "sleep_diary"))
check("new step id recorded",      identical(y$step$id, "2"))
check("rows in recorded",          y$step$n_rows_in == 5L)
check("rows out recorded",         y$step$n_rows == 5L)
check("added column detected",     identical(y$step$cols_added, "new_col"))
check("elapsed time recorded",     !is.na(y$step$duration_ms))
check("history grew by one",       length(y$history) == 1L)
check("history keeps prior step",  identical(y$history[[1]]$id, "1"))

# --- Result ----------------------------------------------------------------

cat("\n", strrep("=", 60), "\n", sep = "")
cat(sprintf("RESULT: %d passed, %d failed\n", .pass, .fail))
if (.fail > 0) {
  cat("\nFailed checks:\n")
  for (f in .failures) cat("  -", f, "\n")
} else {
  cat("All checks passed. The S3 layer behaves as specified.\n")
}
cat(strrep("=", 60), "\n\n", sep = "")

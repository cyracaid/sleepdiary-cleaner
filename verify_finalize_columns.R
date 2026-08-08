#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# verify_finalize_columns.R
#
# Zero-dependency structural check for the v1.4 delivery contract, in the same
# spirit as verify_v1_3_s3.R. Base R only -- no testthat, no devtools -- so it
# still runs when the renv library has been cleared.
#
#   Rscript verify_finalize_columns.R
#
# The equivalent testthat file (tests/testthat/test-finalize-columns.R) stays
# for CI; this one is for the working machine.
# ---------------------------------------------------------------------------

.pass <- 0L
.fail <- 0L

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
    cat(sprintf("FAIL  %s%s\n", label,
                if (!is.null(msg)) paste0("  [", msg, "]") else ""))
  }
  invisible(isTRUE(ok))
}

cat("\n=== finalize_columns structural verification ===\n\n")

# ---- Locate the pieces -----------------------------------------------------
dict_path <- file.path("inst", "extdata", "column_dictionary.csv")
fn_path   <- file.path("R", "finalize_columns.R")

check("column_dictionary.csv exists", file.exists(dict_path))
check("R/finalize_columns.R exists",  file.exists(fn_path))
if (!file.exists(dict_path) || !file.exists(fn_path)) {
  cat("\nCannot continue.\n"); quit(status = 1)
}

source(fn_path)
dict <- read.csv(dict_path, stringsAsFactors = FALSE,
                 colClasses = "character", na.strings = NULL)

# ---- Dictionary integrity --------------------------------------------------
cat("\n-- dictionary --\n")

required <- c("source_column", "source_object", "default_if_absent",
              "name_a", "name_b", "transform", "unit", "status", "description")
check("has all required fields", all(required %in% names(dict)))
check("no duplicate source_column", !any(duplicated(dict$source_column)))

a_names <- dict$name_a[nzchar(dict$name_a)]
b_names <- dict$name_b[nzchar(dict$name_b)]
check("Dataset A has no duplicate names", !any(duplicated(a_names)))
check("Dataset B has no duplicate names", !any(duplicated(b_names)))
check("status is implemented|pending",
      all(dict$status %in% c("implemented", "pending")))
check("source_object is a known object",
      all(dict$source_object %in% c("corrected_ema_data", "review_output")))
check("transform is 'none' or x<number>",
      all(dict$transform == "none" | grepl("^x[0-9.]+$", dict$transform)))

# Decisions taken on 2026-08-09 -- these are the ones easiest to lose in a
# later edit, so they are pinned explicitly rather than checked generically.
cat("\n-- 2026-08-09 decisions --\n")
check("trysleep_minutes removed from A (identical to sleepperiod_minutes)",
      !("trysleep_minutes" %in% a_names))
check("sleepperiod_minutes kept in A (TST input and TST upper bound)",
      "sleepperiod_minutes" %in% a_names)
check("waso_computed_minutes present in A (S1)",
      "waso_computed_minutes" %in% a_names)
check("waso_computed_minutes converts hours to minutes",
      identical(dict$transform[dict$name_a == "waso_computed_minutes"], "x60"))
check("sol_computed_minutes, not sol_minutes (M2)",
      "sol_computed_minutes" %in% a_names && !("sol_minutes" %in% a_names))
check("waso_avg_bout_selfreport_minutes (M3)",
      "waso_avg_bout_selfreport_minutes" %in% a_names)
check("row_id in Dataset B (S4)", "row_id" %in% b_names)
check("correction_type in Dataset B (M6)", "correction_type" %in% b_names)
check("needs_review_flag sourced from review_output",
      identical(dict$source_object[dict$source_column == "needs_review_flag"],
                "review_output"))
check("is_reasonable_unusual has a declared default",
      nzchar(dict$default_if_absent[dict$source_column == "is_reasonable_unusual"]))

# ---- Build with synthetic input --------------------------------------------
cat("\n-- build --\n")

impl <- dict[dict$status == "implemented" & (nzchar(dict$name_a) | nzchar(dict$name_b)), ]
n <- 5

mk <- function(spec) {
  if (!nrow(spec)) return(NULL)
  out <- lapply(spec$source_column, function(cn) {
    if (cn == "pid")     return(rep(1001L, n))
    if (cn == "day_num") return(seq_len(n))
    if (cn == "row_id")  return(seq_len(n))
    seq_len(n) + 0.5
  })
  names(out) <- spec$source_column
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}

d   <- mk(impl[impl$source_object == "corrected_ema_data", ])
rev <- mk(impl[impl$source_object == "review_output", ])

res <- tryCatch(
  finalize_columns(d, review_data = rev, dict_path = dict_path,
                   write = FALSE, verbose = FALSE),
  error = function(e) structure(list(), msg = conditionMessage(e)))

check("finalize_columns() runs", length(res) == 3L)
if (length(res) != 3L) {
  cat("  error: ", attr(res, "msg"), "\n", sep = "")
  cat(sprintf("\n%d passed, %d failed\n", .pass, .fail)); quit(status = 1)
}

expected_a <- dict$name_a[nzchar(dict$name_a) & dict$status == "implemented"]
expected_b <- dict$name_b[nzchar(dict$name_b) & dict$status == "implemented"]
check("Dataset A columns match the dictionary exactly",
      identical(names(res$final), expected_a))
check("Dataset B columns match the dictionary exactly",
      identical(names(res$prepost), expected_b))
check(sprintf("Dataset A has %d columns", length(expected_a)),
      ncol(res$final) == length(expected_a))
check(sprintf("Dataset B has %d columns", length(expected_b)),
      ncol(res$prepost) == length(expected_b))

# The join key is the whole point of adding row_id to B.
key <- c("pid", "day_num", "row_id")
check("A and B share the full key", all(key %in% names(res$final)) &&
                                    all(key %in% names(res$prepost)))
check("A join B does not multiply rows",
      nrow(merge(res$final, res$prepost, by = key)) == nrow(res$final))

# Unit conversion must actually happen; a silent no-op ships hours labelled as
# minutes, which is the defect this column was added to fix.
tf <- dict[dict$transform != "none" & nzchar(dict$name_a), ]
for (i in seq_len(nrow(tf))) {
  f <- as.numeric(sub("^x", "", tf$transform[i]))
  check(sprintf("%s = %s * %g", tf$name_a[i], tf$source_column[i], f),
        isTRUE(all.equal(res$final[[tf$name_a[i]]],
                         as.numeric(d[[tf$source_column[i]]]) * f)))
}

# ---- Guard rails ------------------------------------------------------------
cat("\n-- guard rails --\n")

d2 <- d
d2[["self_diffcalc_totalsleeptime_minutes"]] <- NULL
check("a missing promised column stops the build",
      inherits(tryCatch(finalize_columns(d2, review_data = rev,
                                         dict_path = dict_path,
                                         write = FALSE, verbose = FALSE),
                        error = function(e) e), "error"))

check("omitting review_data stops the build with a pointer to the fix", {
  e <- tryCatch(finalize_columns(d, dict_path = dict_path,
                                 write = FALSE, verbose = FALSE),
                error = function(e) e)
  inherits(e, "error") && grepl("review_output", conditionMessage(e))
})

opt <- dict[nzchar(dict$default_if_absent) & nzchar(dict$name_a) &
              dict$status == "implemented", ]
if (nrow(opt)) {
  d3 <- d
  for (cn in opt$source_column) d3[[cn]] <- NULL
  r3 <- tryCatch(finalize_columns(d3, review_data = rev, dict_path = dict_path,
                                  write = FALSE, verbose = FALSE),
                 error = function(e) NULL)
  check("optional columns fall back to their declared default",
        !is.null(r3) && all(vapply(seq_len(nrow(opt)), function(i)
          isTRUE(all(r3$final[[opt$name_a[i]]] ==
                       as.logical(opt$default_if_absent[i]))), logical(1))))
}

# ---- Summary ----------------------------------------------------------------
cat(sprintf("\n%d passed, %d failed\n", .pass, .fail))
if (.fail > 0L) {
  cat("Verification FAILED.\n"); quit(status = 1)
}
cat("All checks passed.\n")

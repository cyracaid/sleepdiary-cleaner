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
check("status is implemented|pending|reserved",
      all(dict$status %in% c("implemented", "pending", "reserved")))
check("source_object is a known object (reserved may be empty)",
      all(dict$source_object %in% c("corrected_ema_data", "review_output", "")))
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

# Dataset A shipped 7 error rows with no status column until 2026-08-09 -- one of
# them carried a physically impossible waso_computed_minutes of -716. Without a
# filter column an analyst has no direct way to exclude them.
check("Dataset A carries a record-status column (data_category or record_status)",
      any(c("data_category", "record_status") %in%
            dict$name_a[dict$status == "implemented"]))

# S3 shipped on 2026-08-09. record_status supersedes data_category; carrying
# both would let an analyst filter on the wrong one.
check("record_status is implemented, not pending (S3)",
      identical(dict$status[dict$source_column == "record_status"], "implemented"))
check("data_category is NOT also in Dataset A (one status column only)",
      !("data_category" %in% dict$name_a))

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

# ---- record_status derivation (S3) -----------------------------------------
# These need the fixture, so they live here rather than with the dictionary
# checks above.
cat("\n-- record_status derivation (S3) --\n")

# The derivation must be total. An unmapped data_category level has to stop the
# build -- mapping it to NA would ship a blank in the column analysts filter on.
check("unmapped data_category level stops the build", {
  d4 <- d
  d4$data_category <- rep("a_level_that_does_not_exist", nrow(d4))
  d4$record_status <- NULL
  e <- tryCatch(finalize_columns(d4, review_data = rev, dict_path = dict_path,
                                 write = FALSE, verbose = FALSE),
                error = function(e) e)
  inherits(e, "error") && grepl("record_status mapping", conditionMessage(e))
})

# reasonable_unusual keeps its own level: it records that a human looked at an
# unusual record and accepted it, which is a different claim from "unusual".
check("reasonable_unusual is not folded into unusual", {
  d5 <- d
  d5$data_category <- c("clean", "error", "unusual", "reasonable_unusual",
                        "equal_time_ok")[seq_len(nrow(d5))]
  d5$record_status <- NULL
  r5 <- finalize_columns(d5, review_data = rev, dict_path = dict_path,
                         write = FALSE, verbose = FALSE)
  identical(r5$final$record_status,
            c("clean", "error", "unusual", "reasonable_unusual",
              "equal_time")[seq_len(nrow(d5))])
})

# skipped_na is the only level whose delivered name differs in wording rather
# than punctuation, and it is the largest group in the real data (11,142 rows).
check("skipped_na becomes not_reported", {
  d6 <- d
  d6$data_category <- rep("skipped_na", nrow(d6))
  d6$record_status <- NULL
  r6 <- finalize_columns(d6, review_data = rev, dict_path = dict_path,
                         write = FALSE, verbose = FALSE)
  all(r6$final$record_status == "not_reported")
})

opt <- dict[nzchar(dict$default_if_absent) & nzchar(dict$name_a) &
              dict$status == "implemented", ]
if (nrow(opt)) {
  d3 <- d
  for (cn in opt$source_column) d3[[cn]] <- NULL
  r3 <- tryCatch(finalize_columns(d3, review_data = rev, dict_path = dict_path,
                                  write = FALSE, verbose = FALSE),
                 error = function(e) NULL)
  opt_ok <- !is.null(r3) && all(vapply(seq_len(nrow(opt)), function(i) {
    want <- opt$default_if_absent[i]
    got  <- r3$final[[opt$name_a[i]]]
    if (want == "NA") all(is.na(got))
    else isTRUE(all(got == as.logical(want)))
  }, logical(1)))
  check("optional columns fall back to their declared default", opt_ok)
}

# ---- Affect layer (reserved) and export guard -------------------------------
# The study's emotion/affect EMA layer is NOT cleaned here. Reserved rows in the
# dictionary declare it so the cleaner can never silently destroy those columns:
# present -> passed through untouched, absent -> no fabricated blanks.
cat("\n-- affect layer + export guard --\n")

resv <- dict$source_column[dict$status == "reserved"]
if (length(resv)) {
  check(sprintf("%d reserved affect columns declared", length(resv)),
        length(resv) >= 0)
  r_absent <- finalize_columns(d, review_data = rev, dict_path = dict_path,
                               write = FALSE, verbose = FALSE)
  check("pass-through when absent adds nothing",
        !any(resv %in% names(r_absent$final)))

  d9 <- d
  for (cn in resv) d9[[cn]] <- seq_len(nrow(d9))
  r9 <- finalize_columns(d9, review_data = rev, dict_path = dict_path,
                         write = FALSE, verbose = FALSE)
  check("affect columns pass through untouched when present",
        all(resv %in% names(r9$final)) &&
          all(vapply(resv, function(cn) identical(r9$final[[cn]], d9[[cn]]),
                     logical(1))))
}

# Export guard: a negative duration in any ANALYSABLE row (record_status
# neither error nor not_reported) is impossible. This is the guard that would
# have caught row 8502's -716-minute WASO had it targeted post-error-filter
# rather than the whole column.
d11 <- d
d11$record_status <- c("clean", "error", "clean", "clean", "clean")[seq_len(nrow(d11))]
d11$awake_getup_diff_h <- c(-5/60, 0.5, 0.75, 0.5, 0.5)  # hours; -5 min
e11 <- tryCatch(finalize_columns(d11, review_data = rev, dict_path = dict_path,
                                 write = FALSE, verbose = FALSE),
                error = function(e) e)
check("export guard stops on negative minutes in analyzable rows",
      inherits(e11, "error") && grepl("Export guard", conditionMessage(e11)))

d12 <- d
d12$record_status <- c("clean", "error", "not_reported", "error", "clean")
d12$awake_getup_diff_h <- c(0.5, -716/60, -10/60, 0.75, 0.5)
r12 <- tryCatch(finalize_columns(d12, review_data = rev, dict_path = dict_path,
                                 write = FALSE, verbose = FALSE),
                error = function(e) e)
check("negative inside error or not_reported rows is allowed (guard protects analyzable rows only)",
      !inherits(r12, "error"))

# ---- Summary ----------------------------------------------------------------
cat(sprintf("\n%d passed, %d failed\n", .pass, .fail))
if (.fail > 0L) {
  cat("Verification FAILED.\n"); quit(status = 1)
}
cat("All checks passed.\n")

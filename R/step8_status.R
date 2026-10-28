# Step 8 final status of each row, and the counts shown in the flag report and
# in Figure 13.
#
# Step 8's own checks (raw_category) look at field formats and metric values;
# they do not re-test the order of the corrected times. The order is re-tested
# by the Step 6/7 classification (data_category). A manually corrected row is
# therefore only "CLEAN (Manually Fixed)" when BOTH agree it is clean:
#
#   raw_category != CLEAN                       -> raw_category (keeps its flag)
#   raw_category == CLEAN, data_category fails   -> "STILL FAILS (Manually Corrected)"
#   raw_category == CLEAN, data_category ok      -> "CLEAN (Manually Fixed)"
#   raw_category == CLEAN, data_category skipped_na (a time is missing, so the
#     order cannot be re-checked)               -> "NOT CHECKABLE (Manually Corrected)",
#     or "CLEAN (Manually Fixed)" when review.missing_times_ok_after_manual is true
#
# Rows that were not manually corrected keep raw_category.

.step8_fixed <- "CLEAN (Manually Fixed)"
.step8_still_fails <- "STILL FAILS (Manually Corrected)"
.step8_not_checkable <- "NOT CHECKABLE (Manually Corrected)"

#' Final Step 8 status of each row
#' @param raw_category Character, Step 8 category of each row.
#' @param manually_corrected Logical, was a manual correction applied to the row.
#' @param data_category Character, the row's category after corrections (Step 6/7);
#'   NULL when not available, in which case only raw_category is used.
#' @param missing_ok review.missing_times_ok_after_manual: does a manually corrected
#'   row with a missing time (skipped_na) count as fixed?
#' @param clean_categories review.clean_categories: the final categories that pass.
#' @return Character vector, one status per row.
#' @noRd
step8_final_status <- function(raw_category, manually_corrected, data_category = NULL,
                               missing_ok = FALSE,
                               clean_categories = .sc_clean_categories_default) {
  raw_category <- as.character(raw_category)
  manual <- manually_corrected %in% TRUE
  passes <- if (is.null(data_category)) rep(TRUE, length(raw_category)) else
    !is.na(data_category) & as.character(data_category) %in% clean_categories
  out <- raw_category
  clean <- manual & raw_category %in% "CLEAN"
  missing <- if (is.null(data_category)) rep(FALSE, length(raw_category)) else
    as.character(data_category) %in% "skipped_na"
  out[clean & passes] <- .step8_fixed
  out[clean & !passes & !missing] <- .step8_still_fails
  out[clean & missing] <- if (isTRUE(missing_ok)) .step8_fixed else .step8_not_checkable
  out
}

#' Rows per final Step 8 status; the categories add up to the number of rows
#' @param rs review_summary with `final_status`.
#' @return data.frame with `Category` and `Count`.
#' @noRd
step8_status_counts <- function(rs) {
  cats <- c(TIMESTAMP_ISSUE = "TIMESTAMP_ISSUE", DURATION_ISSUE = "DURATION_ISSUE",
            AMOUNT_FLAG = "AMOUNT_FLAG", SELF_REPORTED_FLAG = "SELF-REPORTED FLAG",
            CLEAN = "CLEAN")
  cats[.step8_fixed] <- .step8_fixed
  cats[.step8_still_fails] <- .step8_still_fails
  cats[.step8_not_checkable] <- .step8_not_checkable
  st <- as.character(rs$final_status)
  data.frame(Category = unname(cats),
             Count = vapply(names(cats), function(k) sum(st == k, na.rm = TRUE), integer(1)),
             row.names = NULL, stringsAsFactors = FALSE)
}

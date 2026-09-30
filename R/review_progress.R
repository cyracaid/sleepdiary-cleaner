# Review progress for the [NEW] review worksheets.
#
# Step 5 writes [NEW]manual_error_correction_review.csv and
# [NEW]manual_unusual_review.csv. They list EVERY record the rules flag on the
# data as it stands BEFORE manual corrections are applied, so they keep listing
# records a reviewer has already handled. These helpers add four columns taken
# from the manual correction files the reviewer already keeps, so each row shows
# where (if anywhere) it has been handled:
#
#   in_manual_file     which manual file holds this record ("" = none)
#   review_resolution  \
#   resolved_at         } copied from that manual row (empty if absent)
#   resolved_by        /
#
# A row with all four empty has never been handled. After Steps 6-8 the final
# data are re-checked, and print_review_summary() reports how many handled rows
# are still a problem.

.rp_clean_names <- function(d) {
  if (is.null(d)) return(data.frame())
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  names(d) <- sub("^\ufeff", "", names(d))
  d
}

.rp_key <- function(d) {
  if (is.null(d) || nrow(d) == 0 || !all(c("pid", "day_num", "row_id") %in% names(d))) {
    return(character(0))
  }
  paste(as.character(d$pid), as.character(d$day_num), as.character(d$row_id), sep = "|")
}

# Categories a corrected record may end in without needing another look.
.rp_ok_categories <- c("clean", "equal_time_ok", "reasonable_unusual")
.rp_added_cols <- c("in_manual_file", "review_resolution", "resolved_at", "resolved_by")

#' Add the four "where was this handled" columns to one worksheet
#' @param ws The [NEW] worksheet (data frame).
#' @param manual The matching manual correction file (data frame; may be empty).
#' @param label Text for the in_manual_file column, e.g. the file name.
#' @noRd
annotate_review_worksheet <- function(ws, manual, label) {
  ws <- .rp_clean_names(ws)
  if (nrow(ws) == 0) return(ws)
  manual <- .rp_clean_names(manual)
  ws <- ws[, setdiff(names(ws), .rp_added_cols), drop = FALSE]
  i <- match(.rp_key(ws), .rp_key(manual))
  # A manual row written without a row_id (older files) still identifies its
  # record by participant and day; use that only for rows the full key missed.
  if (any(is.na(i)) && all(c("pid", "day_num", "row_id") %in% names(manual))) {
    no_id <- which(is.na(manual$row_id))
    if (length(no_id) > 0) {
      pd <- function(d) paste(as.character(d$pid), as.character(d$day_num), sep = "|")
      j <- match(pd(ws), pd(manual[no_id, , drop = FALSE]))
      i[is.na(i) & !is.na(j)] <- no_id[j[is.na(i) & !is.na(j)]]
    }
  }
  ws$in_manual_file <- ifelse(is.na(i), "", label)
  for (col in c("review_resolution", "resolved_at", "resolved_by")) {
    v <- if (col %in% names(manual)) as.character(manual[[col]])[i] else rep(NA_character_, nrow(ws))
    v[is.na(v) | v == "NA"] <- ""
    ws[[col]] <- v
  }
  ws
}

#' Annotate both [NEW] worksheets on disk and return them
#'
#' Reads the worksheets Step 5 just wrote (working directory), adds the four
#' columns, writes them back with the same rows. Never stops the pipeline.
#' @noRd
annotate_review_worksheets <- function(manual_error, manual_unusual, verbose = TRUE) {
  files <- c(error = "[NEW]manual_error_correction_review.csv",
             unusual = "[NEW]manual_unusual_review.csv")
  manual <- list(error = manual_error, unusual = manual_unusual)
  labels <- c(error = "manual_error_corrections.csv",
              unusual = "manual_unusual_corrections.csv")
  out <- list()
  for (w in names(files)) {
    f <- files[[w]]
    if (!file.exists(f)) next
    ws <- utils::read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM",
                          check.names = FALSE)
    ws <- annotate_review_worksheet(ws, manual[[w]], labels[[w]])
    utils::write.csv(ws, f, row.names = FALSE)
    out[[w]] <- ws
  }
  if (verbose && length(out) > 0)
    cat("  [review worksheets] added in_manual_file / review_resolution / resolved_at /",
        "resolved_by to the [NEW] worksheets\n")
  out
}

#' Count where the worksheet rows stand
#' @param ws_list List with elements `error` and/or `unusual` (annotated worksheets).
#' @param final Corrected data with a `data_category` column.
#' @param flags Optional Step 8 data with `needs_review_flag`.
#' @return A data frame with one row per worksheet, or NULL if there is nothing.
#' @noRd
review_state_counts <- function(ws_list, final, flags = NULL) {
  final <- .rp_clean_names(final)
  flags <- if (is.null(flags)) NULL else .rp_clean_names(flags)
  fkey <- .rp_key(final)
  gkey <- if (is.null(flags)) character(0) else .rp_key(flags)
  rows <- lapply(names(ws_list), function(w) {
    ws <- ws_list[[w]]
    if (is.null(ws) || nrow(ws) == 0) return(NULL)
    handled <- ws$in_manual_file != ""
    k <- .rp_key(ws)
    cat_final <- if ("data_category" %in% names(final))
      as.character(final$data_category)[match(k, fkey)] else rep(NA_character_, length(k))
    flagged <- if (!is.null(flags) && "needs_review_flag" %in% names(flags))
      flags$needs_review_flag[match(k, gkey)] %in% TRUE else rep(FALSE, length(k))
    # A reviewed record the pipeline keeps as "unusual" is an accepted outcome of
    # the unusual worksheet (reviewed and kept as reported); on the error
    # worksheet it is not: a corrected error should end up clean / equal-time.
    ok <- if (identical(w, "unusual")) c(.rp_ok_categories, "unusual") else .rp_ok_categories
    still <- handled & (is.na(cat_final) | !(cat_final %in% ok) | flagged)
    res <- tolower(ws$review_resolution)
    data.frame(
      worksheet = w,
      rows = nrow(ws),
      not_handled = sum(!handled),
      pending = sum(handled & (res == "flagged_unresolved" | tolower(ws$resolved_by) == "pending")),
      legacy = sum(handled & grepl("legacy", res)),
      corrected = sum(handled & res == "corrected"),
      still_problem_after_check = sum(still),
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) return(NULL)
  do.call(rbind, rows)
}

#' Print a short summary of where the review stands
#' @noRd
print_review_summary <- function(ws_list, final, flags = NULL, applied = TRUE, verbose = TRUE) {
  if (!verbose) return(invisible(NULL))
  if (!applied) {
    cat("\n  [review progress] manual corrections were not applied in this run,",
        "so review progress is not reported.\n")
    return(invisible(NULL))
  }
  cnt <- review_state_counts(ws_list, final, flags)
  if (is.null(cnt)) {
    cat("\n  [review progress] the review worksheets are empty: nothing left to review.\n")
    return(invisible(NULL))
  }
  cat("\n  [review progress] records the rules flag before correction, by worksheet:\n")
  for (i in seq_len(nrow(cnt))) {
    r <- cnt[i, ]
    cat(sprintf(paste0("    %-8s %3d rows | %3d not in a manual file yet | %3d pending | ",
                       "%3d legacy (no record of who/when) | %3d corrected | ",
                       "%3d handled but still a problem after the re-check\n"),
                r$worksheet, r$rows, r$not_handled, r$pending, r$legacy, r$corrected,
                r$still_problem_after_check))
  }
  if (sum(cnt$not_handled) == 0 && sum(cnt$pending) == 0 && sum(cnt$still_problem_after_check) == 0)
    cat("    Every row is handled and passes the re-check.\n")
  invisible(cnt)
}

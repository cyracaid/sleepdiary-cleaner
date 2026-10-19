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

#' One status table for every row on the Step 5 error worksheet and every row the
#' corrections turned into an error
#'
#' Step 5 lists the records the rules flag BEFORE corrections. This joins that list
#' with the corrected data so that each row says, in one place, what happened to it.
#' Nothing is dropped and nothing is decided for the user: the table only reports.
#'
#' `status_after_corrections` is one of
#' \itemize{
#'   \item `not_in_manual_file_still_fails`: not in any manual file, and not clean now;
#'   \item `in_manual_file_still_fails`: in a manual file, and still not clean;
#'   \item `new_after_corrections`: not on the Step 5 error or unusual list, but an
#'     error now (a correction, or a later step, made it one);
#'   \item `not_in_manual_file_now_passes`: not in a manual file, clean now (the
#'     rules fixed it);
#'   \item `in_manual_file_now_passes`: in a manual file, clean now.
#' }
#' "Clean" means the final `data_category` is clean, equal_time_ok or
#' reasonable_unusual. Step 8 flags are reported in their own column and are not
#' part of the status.
#'
#' @param ws_error,ws_unusual Annotated Step 5 worksheets (data frames).
#' @param final Corrected data with `pid`, `day_num`, `row_id`, `data_category`.
#' @param flags Step 8 data with `needs_review_flag` and `auto_error_desc` (optional).
#' @return A data frame, one row per record, ordered so the rows that still need a
#'   person come first.
#' @noRd
build_review_status_table <- function(ws_error, ws_unusual, final, flags = NULL) {
  final <- .rp_clean_names(final)
  ws_error <- .rp_clean_names(ws_error)
  ws_unusual <- .rp_clean_names(ws_unusual)
  # An empty worksheet comes back without the four "where handled" columns.
  for (nm in .rp_added_cols)
    if (!nm %in% names(ws_error)) ws_error[[nm]] <- rep("", nrow(ws_error))
  fkey <- .rp_key(final)
  cat_after <- function(k) as.character(final$data_category)[match(k, fkey)]

  step8 <- function(k) {
    if (is.null(flags)) return(rep("", length(k)))
    flags <- .rp_clean_names(flags)
    i <- match(k, .rp_key(flags))
    on <- if ("needs_review_flag" %in% names(flags)) flags$needs_review_flag[i] %in% TRUE else rep(FALSE, length(k))
    desc <- if ("auto_error_desc" %in% names(flags)) as.character(flags$auto_error_desc)[i] else rep("", length(k))
    desc[is.na(desc)] <- ""
    ifelse(on, ifelse(nzchar(desc), desc, "flagged"), "")
  }

  statuses <- c("not_in_manual_file_still_fails", "in_manual_file_still_fails",
                "new_after_corrections", "not_in_manual_file_now_passes",
                "in_manual_file_now_passes")

  k_err <- .rp_key(ws_error)
  ca <- cat_after(k_err)
  passes <- !is.na(ca) & ca %in% .rp_ok_categories
  handled <- if ("in_manual_file" %in% names(ws_error))
    !is.na(ws_error$in_manual_file) & ws_error$in_manual_file != "" else rep(FALSE, nrow(ws_error))
  old <- ws_error
  if (nrow(old) > 0) {
    old$source <- "on_step5_list"
    old$status_after_corrections <- ifelse(handled,
      ifelse(passes, "in_manual_file_now_passes", "in_manual_file_still_fails"),
      ifelse(passes, "not_in_manual_file_now_passes", "not_in_manual_file_still_fails"))
    old$category_before_corrections <- "error"
    old$category_after_corrections <- ifelse(is.na(ca), "", ca)
    old$step8_flags_after_corrections <- step8(k_err)
  }

  on_sheet <- c(k_err, .rp_key(ws_unusual))
  is_err <- as.character(final$data_category) %in% "error"
  nw <- final[is_err & !(fkey %in% on_sheet), , drop = FALSE]
  if (nrow(nw) > 0) {
    shared <- intersect(names(nw), names(ws_error))
    add <- ws_error[rep(NA_integer_, nrow(nw)), , drop = FALSE]
    rownames(add) <- NULL
    for (nm in shared) add[[nm]] <- nw[[nm]]
    for (nm in setdiff(names(add), shared)) add[[nm]] <- NA
    if ("in_manual_file" %in% names(add)) add$in_manual_file <- ""
    add$source <- "new_after_corrections"
    add$status_after_corrections <- "new_after_corrections"
    add$category_before_corrections <- "not_on_step5_list"
    add$category_after_corrections <- as.character(nw$data_category)
    add$step8_flags_after_corrections <- step8(.rp_key(nw))
    nw <- add
  }

  out <- if (nrow(old) == 0 && nrow(nw) == 0) {
    x <- ws_error[0, , drop = FALSE]
    for (nm in c("source", "status_after_corrections", "category_before_corrections",
                 "category_after_corrections", "step8_flags_after_corrections"))
      x[[nm]] <- character(0)
    x
  } else rbind(if (nrow(old) > 0) old, if (nrow(nw) > 0) nw)

  front <- intersect(c("pid", "day_num", "row_id", "source", "status_after_corrections",
                       "in_manual_file", "category_before_corrections",
                       "category_after_corrections", "step8_flags_after_corrections"),
                     names(out))
  out <- out[, c(front, setdiff(names(out), front)), drop = FALSE]
  if (nrow(out) > 0) {
    o <- order(match(out$status_after_corrections, statuses), out$pid, out$day_num)
    out <- out[o, , drop = FALSE]
    rownames(out) <- NULL
  }
  out
}

#' Write the review status table
#'
#' Replaces the Step 5 worksheet file with the status table of
#' [build_review_status_table()] and prints how many rows are in each status.
#' @noRd
write_review_status_table <- function(ws_list, final, flags = NULL,
                                      file = "[NEW]manual_error_correction_review.csv",
                                      verbose = TRUE) {
  ws_error <- ws_list[["error"]]
  if (is.null(ws_error)) return(invisible(NULL))
  out <- build_review_status_table(ws_error, ws_list[["unusual"]], final, flags)
  utils::write.csv(out, file, row.names = FALSE, na = "")
  if (verbose) {
    st <- table(factor(out$status_after_corrections,
      levels = c("not_in_manual_file_still_fails", "in_manual_file_still_fails",
                 "new_after_corrections", "not_in_manual_file_now_passes",
                 "in_manual_file_now_passes")))
    cat(sprintf("\n  [review status] %d row(s) in %s\n", nrow(out), file))
    for (nm in names(st)) cat(sprintf("    %-32s %d\n", nm, st[[nm]]))
  }
  invisible(out)
}

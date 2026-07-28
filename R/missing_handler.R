#' Tag missing-data reason codes and optionally carry forward single-day gaps
#'
#' Adds a \code{missing_reason} column that distinguishes why a row has
#' incomplete data, rather than lumping everything into \code{skipped_na}.
#' Optionally applies last-observation-carried-forward (LOCF) to metric
#' columns for single-day gaps.
#'
#' @section Design boundaries:
#'
#' * Timestamp columns are **never** imputed — filling a missing bedtime
#'   would fabricate an event that did not happen.
#' * Only metric columns (SOL, WASO, TST, SE) are eligible for LOCF.
#' * LOCF is capped at \code{max_gap} consecutive days (default 1) to
#'   avoid filling week-long gaps with stale data.
#' * All imputed values carry an \code{_imputed} companion column
#'   (\code{TRUE} / \code{FALSE}) for audit trail.
#'
#' @param data A data frame from the pipeline.
#' @param timestamp_cols Character. Columns that carry the four sleep-event
#'   POSIXct timestamps. If \code{NULL}, auto-detects from common patterns.
#' @param metric_cols Character. Columns eligible for LOCF. If \code{NULL},
#'   auto-detects the standard derived-metric columns.
#' @param group_col Character. Participant identifier. Default \code{"pid"}.
#' @param order_col Character. Within-participant ordering column. Default
#'   \code{"day_num"}.
#' @param max_gap Integer. Maximum consecutive missing days to fill via
#'   LOCF. Default 1. Set to 0 to disable LOCF entirely.
#'
#' @return A copy of \code{data} with:
#'   \describe{
#'     \item{\code{missing_reason}}{Character. One of \code{"all_timestamps_na"},
#'       \code{"partial_timestamps_na"}, \code{"derived_na"}, or \code{NA}
#'       (complete row).}
#'     \item{For each metric column when \code{max_gap > 0}:}{a companion
#'       \code{<col>_imputed} logical column, and the original column may
#'       contain LOCF-filled values.}
#'   }
#'
#' @examples
#' \dontrun{
#' handled <- handle_missing(corrected_ema_data)
#' table(handled$missing_reason)
#'
#' # LOCF disabled — only reason codes
#' handled <- handle_missing(corrected_ema_data, max_gap = 0)
#' }
#'
#' @export
handle_missing <- function(data,
                            timestamp_cols = NULL,
                            metric_cols = NULL,
                            group_col = "pid",
                            order_col = "day_num",
                            max_gap = 1L) {

  stopifnot(is.data.frame(data))
  stopifnot(group_col %in% names(data), order_col %in% names(data))

  # ---- auto-detect columns ----

  if (is.null(timestamp_cols)) {
    candidates <- c("time_bed_am_hhmm_ampm", "time_sleep_am_hhmm_ampm",
                    "time_awake_am_hhmm_ampm", "time_getup_am_hhmm_ampm")
    timestamp_cols <- intersect(candidates, names(data))
  }

  if (is.null(metric_cols)) {
    candidates <- c("self_diffcalc_sol_minutes",
                    "self_diffcalc_totalsleeptime_minutes",
                    "self_diffcalc_sleepefficiency_percent",
                    "avg_waso_estimate_am_minutes",
                    "sleep_efficiency_pct", "sol_h", "waso_h", "sleep_duration_h")
    metric_cols <- intersect(candidates, names(data))
  }

  if (length(timestamp_cols) == 0 && length(metric_cols) == 0) {
    stop("No timestamp or metric columns found. Provide them explicitly.")
  }

  # ---- missing reason codes ----

  n_timestamp_cols <- length(timestamp_cols)

  if (n_timestamp_cols > 0) {
    na_counts <- rowSums(is.na(data[, timestamp_cols, drop = FALSE]))
    data$missing_reason <- ifelse(na_counts == n_timestamp_cols,
                                   "all_timestamps_na",
                                   ifelse(na_counts > 0,
                                          "partial_timestamps_na",
                                          NA_character_))
  } else {
    data$missing_reason <- NA_character_
  }

  # Derived-metric NA (timestamps present, but computation produced NA)
  if (length(metric_cols) > 0) {
    ts_present <- if (n_timestamp_cols > 0) {
      data$missing_reason == "all_timestamps_na" | is.na(data$missing_reason)
    } else {
      rep(TRUE, nrow(data))
    }
    for (col in metric_cols) {
      if (col %in% names(data)) {
        derived_na_idx <- is.na(data[[col]]) & !is.na(data$missing_reason) &
                          data$missing_reason != "all_timestamps_na"
        if (any(derived_na_idx)) {
          data$missing_reason[derived_na_idx] <- "derived_na"
        }
      }
    }
  }

  # ---- LOCF for single-day gaps on metric columns only ----

  if (max_gap > 0L && length(metric_cols) > 0) {
    # Initialise imputed flags
    for (col in metric_cols) {
      if (col %in% names(data)) {
        flag_col <- paste0(col, "_imputed")
        if (!(flag_col %in% names(data))) {
          data[[flag_col]] <- FALSE
        }
      }
    }

    data <- data[order(data[[group_col]], data[[order_col]]), ]
    rownames(data) <- NULL

    for (pid in unique(data[[group_col]])) {
      idx <- which(data[[group_col]] == pid)
      if (length(idx) < 2) next

      for (col in metric_cols) {
        if (!(col %in% names(data))) next
        flag_col <- paste0(col, "_imputed")

        vals <- data[[col]][idx]
        nas  <- is.na(vals)

        if (!any(nas)) next

        # Run-length encode NA stretches
        rle_na <- rle(nas)
        cs <- cumsum(rle_na$lengths)

        for (run in which(rle_na$values)) {
          run_len   <- rle_na$lengths[run]
          run_start <- if (run == 1) 1L else cs[run - 1] + 1L
          run_end   <- cs[run]

          if (run_len > max_gap) next

          # Carry forward from the value before this run
          if (run_start > 1) {
            prev <- vals[run_start - 1]
            if (!is.na(prev)) {
              vals[run_start:run_end] <- prev
              data[[flag_col]][idx[run_start:run_end]] <- TRUE
            }
          }
        }
        data[[col]][idx] <- vals
      }
    }
  }

  data
}

#' Summarise missing-data patterns per participant
#'
#' @param data A data frame after calling \code{handle_missing()}.
#' @param group_col Character. Participant column.
#' @return A data frame: per participant, counts of each missing reason
#'   and the number of LOCF-filled values.
#' @export
summarise_missing <- function(data, group_col = "pid") {
  stopifnot("missing_reason" %in% names(data))

  out <- do.call(rbind, lapply(split(data, data[[group_col]]), function(gp) {
    n <- nrow(gp)
    reasons <- table(factor(gp$missing_reason,
                             levels = c("all_timestamps_na", "partial_timestamps_na",
                                        "derived_na")))
    row <- c(
      pid = as.character(gp[[group_col]][1]),
      n_rows = n,
      n_all_ts_na     = as.integer(reasons["all_timestamps_na"]),
      n_partial_ts_na = as.integer(reasons["partial_timestamps_na"]),
      n_derived_na    = as.integer(reasons["derived_na"])
    )

    # Count imputed columns
    imputed_cols <- grep("_imputed$", names(data), value = TRUE)
    for (ic in imputed_cols) {
      row[[ic]] <- sum(gp[[ic]], na.rm = TRUE)
    }

    row
  }))

  df <- as.data.frame(out, stringsAsFactors = FALSE)
  for (col in names(df)[-1]) {
    df[[col]] <- as.integer(df[[col]])
  }
  rownames(df) <- NULL
  df
}

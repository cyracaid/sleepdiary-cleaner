#' Per-participant statistical outlier detection via IQR
#'
#' Detects within-participant outliers on key sleep metrics using the
#' interquartile range (IQR) method: any value more than \code{1.5 * IQR}
#' below Q1 or above Q3 is flagged.
#'
#' This complements (does NOT replace) the hard-threshold system in the
#' cleaning pipeline. Hard thresholds detect values that are implausible
#' in absolute terms (e.g. SOL > 120 min). IQR flags detect values that
#' are unusual \emph{for that specific participant} -- a person who
#' typically falls asleep in 5 minutes suddenly reporting 45 minutes is
#' worth a closer look even though 45 min is below the hard cutoff.
#'
#' @param data A data frame from the pipeline (typically after Step 7).
#' @param group_col Character. Column identifying participants (default
#'   \code{"pid"}).
#' @param metrics Character vector. Columns to scan for outliers.
#'   Defaults to the four primary derived metrics.
#' @param multiplier Numeric. The IQR multiplier. Default 1.5 (Tukey's
#'   standard). Use 3.0 for "far out" detection only.
#' @param min_rows Integer. Participants with fewer than this many valid
#'   rows are skipped (their IQR is unreliable).
#'
#' @return A copy of \code{data} with one new column:
#'   \describe{
#'     \item{\code{iqr_outlier}}{Character. Names of the metrics that were
#'       out of range, separated by "+" (e.g. \code{"sol+tst"}). \code{NA}
#'       when no metric is flagged or the participant has too few rows.}
#'   }
#'
#' @examples
#' \dontrun{
#' flagged <- flag_statistical_outliers(corrected_ema_data)
#' table(flagged$iqr_outlier)
#' }
#'
#' @export
flag_statistical_outliers <- function(data,
                                       group_col = "pid",
                                       metrics = c(
                                         self_diffcalc_sol_minutes         = "sol",
                                         self_diffcalc_totalsleeptime_minutes = "tst",
                                         self_diffcalc_sleepefficiency_percent = "se",
                                         avg_waso_estimate_am_minutes      = "waso"
                                       ),
                                       multiplier = 1.5,
                                       min_rows = 5L) {

  stopifnot(is.data.frame(data))
  stopifnot(group_col %in% names(data))

  # Normalise metrics to a named character vector (names = columns, values = labels)
  if (is.character(metrics) && is.null(names(metrics))) {
    names(metrics) <- metrics
  } else if (!is.character(metrics)) {
    stop("`metrics` must be a character vector of column names", call. = FALSE)
  }
  missing <- setdiff(names(metrics), names(data))
  if (length(missing)) {
    warning("Columns not found in data, skipping: ", paste(missing, collapse = ", "))
    metrics <- metrics[setdiff(names(metrics), missing)]
  }
  if (length(metrics) == 0) {
    stop("None of the requested metric columns were found in the data.", call. = FALSE)
  }

  groups <- split(data, data[[group_col]])
  labels <- as.character(metrics)

  flagged_list <- lapply(groups, function(gp) {
    n <- nrow(gp)
    outlier <- rep(NA_character_, n)

    for (m in seq_along(metrics)) {
      col_name <- names(metrics)[m]
      lab <- labels[m]
      vals <- gp[[col_name]]
      valid <- !is.na(vals) & is.finite(vals)

      if (sum(valid) < min_rows) next

      q <- stats::quantile(vals[valid], probs = c(0.25, 0.75), na.rm = TRUE)
      iqr <- q[2] - q[1]
      if (iqr == 0) next  # all values identical -- no outliers possible

      lower <- q[1] - multiplier * iqr
      upper <- q[2] + multiplier * iqr

      hit <- valid & (vals < lower | vals > upper)
      if (any(hit)) {
        current <- outlier[hit]
        outlier[hit] <- ifelse(is.na(current), lab, paste(current, lab, sep = "+"))
      }
    }

    outlier
  })

  data[["iqr_outlier"]] <- unsplit(flagged_list, data[[group_col]])
  attr(data[["iqr_outlier"]], "method")   <- "IQR"
  attr(data[["iqr_outlier"]], "multiplier") <- multiplier
  attr(data[["iqr_outlier"]], "group_col")  <- group_col
  attr(data[["iqr_outlier"]], "metrics")    <- metrics

  data
}

#' Summarise IQR outlier flags
#'
#' @param data A data frame after calling \code{flag_statistical_outliers()}.
#' @param group_col Character. Participant column.
#' @return A data frame: one row per participant with flag counts per metric.
#' @export
summarise_outliers <- function(data, group_col = "pid") {
  stopifnot("iqr_outlier" %in% names(data))

  metrics <- attr(data[["iqr_outlier"]], "metrics")
  if (is.null(metrics)) {
    metrics <- c(sol = "sol", tst = "tst", se = "se", waso = "waso")
  }
  labs <- as.character(metrics)

  out <- do.call(rbind, lapply(split(data, data[[group_col]]), function(gp) {
    vals <- gp[["iqr_outlier"]]
    n  <- nrow(gp)
    nz <- sum(!is.na(vals))
    counts <- vapply(labs, function(lab) sum(grepl(lab, vals, fixed = TRUE), na.rm = TRUE), integer(1))
    c(pid = as.character(gp[[group_col]][1]), n = n, n_flagged = nz, counts)
  }))

  df <- as.data.frame(out, stringsAsFactors = FALSE)
  for (col in c("n", "n_flagged", labs)) {
    df[[col]] <- as.integer(df[[col]])
  }
  rownames(df) <- NULL
  df
}

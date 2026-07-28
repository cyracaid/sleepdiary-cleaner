#' The S3 cleaning chain
#'
#' Runs the pure data-in / data-out portion of the pipeline as a single
#' composable chain. These are the six steps that take a data frame and return
#' a data frame with no file I/O and no reliance on the global environment:
#' timestamps, intervals, sequence normalisation, manual corrections, duration
#' corrections and metric computation.
#'
#' The remaining steps of \code{run_pipeline()} -- data loading (1), the
#' field-misentry check (1.5), review-file generation (5), second-review
#' consensus (5.75), auto-detection (8), the cross-participant check (8.5) and
#' visualisation (9) -- are deliberately NOT part of the chain in v1.3.0. They
#' write files or publish objects into the global environment, so folding them
#' in would change behaviour rather than just re-shape it. They stay in
#' \code{run_pipeline()} until snapshot tests cover them.
#'
#' @param data A raw data frame, or an existing \code{sleep_diary} object.
#' @param corrections_df Data frame of manual error corrections (Step 6).
#'   Pass an empty \code{data.frame()} to run without corrections.
#' @param manual_unusual_df Data frame of manual unusual-pattern decisions.
#' @param cfg List or NULL. Pipeline configuration. Defaults to the
#'   \code{pipeline_config} published by \code{run_pipeline()}, if present.
#' @param verbose Logical. Print per-step progress.
#'
#' @return A \code{sleep_diary} object carrying the cleaned data and the full
#'   step history. Call \code{as.data.frame()} on it to recover a plain data
#'   frame identical in shape to the v1.2.0 \code{corrected_ema_data}.
#'
#' @examples
#' \dontrun{
#' cleaned <- run_cleaning_chain(raw_df, corrections, unusual)
#' summary(cleaned)
#' plot(cleaned)
#' corrected_ema_data <- as.data.frame(cleaned)
#' }
#' @export
run_cleaning_chain <- function(data,
                               corrections_df = data.frame(),
                               manual_unusual_df = data.frame(),
                               cfg = NULL,
                               verbose = getOption("splsleep.verbose", TRUE)) {
  if (is.null(cfg)) {
    cfg <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
  }

  x <- if (is_sleep_diary(data)) {
    data
  } else {
    new_sleep_diary(data, step_id = "1", step_label = "Load data", cfg = cfg)
  }
  if (is.null(x$cfg)) x$cfg <- cfg

  old <- options(splsleep.verbose = verbose)
  on.exit(options(old), add = TRUE)

  x <- step_process_timestamps(x)
  x <- step_process_intervals(x)
  x <- step_normalize_sequence(x)
  x <- step_apply_corrections(x, corrections_df, manual_unusual_df)
  x <- step_apply_duration_corrections(x)
  x <- step_compute_metrics(x)

  assert_contract_columns(x)
  x
}

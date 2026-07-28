#' Pipeline step adapters (wrapper layer)
#'
#' Every function here wraps ONE existing pipeline script from \code{v1.2.0}
#' without changing a line of its logic. The adapter is responsible only for:
#'   1. unboxing the data frame from the incoming \code{sleep_diary},
#'   2. calling the unchanged script function,
#'   3. timing the call and diffing rows/columns,
#'   4. calling \code{log_step()} so the flag ledger stays identical to v1.2.0,
#'   5. boxing the result back into a \code{sleep_diary}.
#'
#' This is the "wrapper-first" half of the v1.3.0 S3 migration. Once snapshot
#' tests pin each step's output, the bodies can be internalised one at a time
#' without the caller ever noticing.
#'
#' @name pipeline_steps
NULL

#' Locate and source a pipeline script into a private environment
#'
#' @param script Character. File name inside the scripts directory.
#' @return An environment containing whatever the script defined.
#' @keywords internal
#' @noRd
.load_script <- function(script) {
  sdir <- get0("splsleep_scripts_dir", envir = .GlobalEnv,
               ifnotfound = scripts_dir())
  path <- file.path(sdir, script)
  if (!file.exists(path)) {
    stop("Pipeline script not found: ", path,
         "\nSet options(splsleep.scripts_dir=) or run from the project root.",
         call. = FALSE)
  }
  env <- new.env(parent = globalenv())
  sys.source(path, envir = env, keep.source = FALSE)
  env
}

#' Run one step and record its provenance
#'
#' The single choke point every adapter goes through, so timing, column diffing,
#' ledger logging and validation are guaranteed to behave identically for all
#' steps rather than being re-implemented nine times.
#'
#' @param x A \code{sleep_diary} object.
#' @param step_id Character. Short ordered step id.
#' @param step_label Character. Human-readable step name.
#' @param fn Function taking a data frame and returning a data frame.
#' @param verbose Logical. Print progress. Defaults to the
#'   \code{splsleep.verbose} option.
#' @return A new \code{sleep_diary} object.
#' @keywords internal
#' @noRd
.run_step <- function(x, step_id, step_label, fn,
                      verbose = getOption("splsleep.verbose", TRUE)) {
  validate_sleep_diary(x)

  data_in <- x$data
  cols_in <- names(data_in)
  n_in <- nrow(data_in)

  t0 <- Sys.time()
  data_out <- fn(data_in)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs")) * 1000

  if (!is.data.frame(data_out)) {
    stop(sprintf(paste0("Step %s (%s) returned a %s, not a data frame. ",
                        "The wrapper layer requires every step to return ",
                        "the working data frame."),
                 step_id, step_label, paste(class(data_out), collapse = "/")),
         call. = FALSE)
  }

  # Keep the v1.2.0 ledger behaviour byte-for-byte.
  log_step(data_out, step_id, step_label, x$cfg, verbose = verbose)

  history <- c(x$history, list(x$step))
  out <- new_sleep_diary(
    data       = data_out,
    step_id    = step_id,
    step_label = step_label,
    cfg        = x$cfg,
    history    = history,
    extra      = list(
      n_rows_in   = n_in,
      cols_added  = setdiff(names(data_out), cols_in),
      duration_ms = elapsed
    )
  )
  validate_sleep_diary(out)
}

# ---------------------------------------------------------------------------
# Step 2: parse timestamp strings into POSIXct + *_checkforerrors flags
# ---------------------------------------------------------------------------

#' Step 2 -- parse timestamps
#'
#' @param x A \code{sleep_diary} object.
#' @param vars Character vector of timestamp variables to process.
#' @return A \code{sleep_diary} object.
#' @export
step_process_timestamps <- function(x,
                                    vars = c("time_bed_am", "time_sleep_am",
                                             "time_awake_am", "time_getup_am",
                                             "caffeinetoday_PM", "alcoholtoday_PM",
                                             "nicotine_amount_pm", "cannabis_amount_pm")) {
  env <- .load_script("process_timestamp_emadatarelease_cyra.R")
  .run_step(x, "2", "Process timestamps", function(df) {
    for (varname in vars) {
      df <- env$process_timestamp(df, varname = varname, format = "timestamp")
    }
    df
  })
}

# ---------------------------------------------------------------------------
# Step 3: parse duration/interval strings into numeric minutes
# ---------------------------------------------------------------------------

#' Step 3 -- parse interval durations
#'
#' @param x A \code{sleep_diary} object.
#' @param vars Character vector of interval variables to process.
#' @return A \code{sleep_diary} object.
#' @export
step_process_intervals <- function(x,
                                   vars = c("duration_totalmin_sol_estimate_am",
                                            "duration_totalmin_waso_estimate_am",
                                            "duration_totalmin_napstoday_PM",
                                            "exercisetoday_PM_totalmin_Light",
                                            "exercisetoday_PM_totalmin_Moderate",
                                            "exercisetoday_PM_totalmin_Vigorous",
                                            "exercisetoday_PM_totalmin_Strength")) {
  env <- .load_script("process_interval.R")
  .run_step(x, "3", "Process intervals", function(df) {
    if (!is.function(env$process_interval)) return(df)
    for (varname in vars) {
      df <- env$process_interval(df, varname = varname, format = "interval_hhmm")
    }
    df
  })
}

# ---------------------------------------------------------------------------
# Step 4: normalise the bed -> sleep -> awake -> getup sequence
# ---------------------------------------------------------------------------

#' Step 4 -- normalise sleep time sequence
#'
#' @param x A \code{sleep_diary} object.
#' @param flip_gap_hours Numeric. Gap above which an AM/PM flip is applied.
#'   Defaults to the configured \code{timestamp.sequence.max_gap_hours}, or 12.
#' @return A \code{sleep_diary} object.
#' @export
step_normalize_sequence <- function(x, flip_gap_hours = NULL) {
  if (is.null(flip_gap_hours)) {
    flip_gap_hours <- tryCatch(cfg_get("timestamp.sequence.max_gap_hours", 12, cfg = x$cfg),
                               error = function(e) 12)
  }
  env <- .load_script("normalize_sleep_time_sequence.R")
  .run_step(x, "4", "Normalize sequence", function(df) {
    env$normalize_sleep_time_sequence(AM_rawdata = df,
                                      flip_gap_hours = flip_gap_hours)
  })
}

# ---------------------------------------------------------------------------
# Step 6: apply human correction decisions and recalculate
# ---------------------------------------------------------------------------

#' Step 6 -- apply manual corrections
#'
#' @param x A \code{sleep_diary} object.
#' @param corrections_df Data frame of manual error corrections.
#' @param manual_unusual_df Data frame of manual unusual-pattern decisions.
#' @return A \code{sleep_diary} object.
#' @export
step_apply_corrections <- function(x, corrections_df, manual_unusual_df) {
  env <- .load_script("error_unusual_sleep_time_corrections.R")
  .run_step(x, "6", "Manual corrections", function(df) {
    res <- env$apply_manual_corrections_and_recalculate(
      ema_data          = df,
      corrections_df    = corrections_df,
      manual_unusual_df = manual_unusual_df
    )
    res$corrected_ema_data
  })
}

# ---------------------------------------------------------------------------
# Step 6.5: numeric duration corrections and human acceptances
# ---------------------------------------------------------------------------

#' Step 6.5 -- apply duration corrections
#'
#' Chains the three v1.2.0 correction appliers in their original order:
#' nap/exercise, then sleep-metric durations, then human metric acceptances.
#'
#' @param x A \code{sleep_diary} object.
#' @return A \code{sleep_diary} object.
#' @export
step_apply_duration_corrections <- function(x) {
  nap  <- .load_script("apply_nap_exercise_corrections.R")
  dur  <- .load_script("apply_sleep_metric_duration_corrections.R")
  acc  <- .load_script("apply_metric_review_acceptances.R")
  .run_step(x, "6.5", "Duration corrections", function(df) {
    df <- nap$apply_nap_exercise_corrections(df)
    df <- dur$apply_sleep_metric_duration_corrections(df)
    df <- acc$apply_metric_review_acceptances(df)
    df
  })
}

# ---------------------------------------------------------------------------
# Step 7: derive SOL / TST / sleep efficiency plus the public contract columns
# ---------------------------------------------------------------------------

#' Step 7 -- compute derived sleep metrics
#'
#' Produces the four public contract columns introduced in v1.2.0
#' (\code{sleep_efficiency_pct}, \code{sol_h}, \code{waso_h},
#' \code{sleep_duration_h}) that the flag evaluators consume.
#'
#' @param x A \code{sleep_diary} object.
#' @return A \code{sleep_diary} object.
#' @export
step_compute_metrics <- function(x) {
  env <- .load_script("calculate_sleep_time_end.R")
  .run_step(x, "7", "Compute metrics", function(df) {
    env$calculate_sleep_time_vars_end(df)
  })
}

#' Assert that a sleep_diary carries the public contract columns
#'
#' The interface contract Step 7 promises downstream consumers. Kept separate
#' from \code{step_compute_metrics()} so tests can assert the contract without
#' re-running the step.
#'
#' @param x A \code{sleep_diary} object or data frame.
#' @param error Logical. If TRUE (default) raise on a missing column; if FALSE
#'   return the missing names.
#' @return Character vector of missing columns, invisibly.
#' @export
assert_contract_columns <- function(x, error = TRUE) {
  df <- if (is_sleep_diary(x)) x$data else x
  required <- c("sleep_efficiency_pct", "sol_h", "waso_h", "sleep_duration_h")
  missing <- setdiff(required, names(df))
  if (length(missing) && isTRUE(error)) {
    stop("Contract columns missing after Step 7: ",
         paste(missing, collapse = ", "),
         "\nThese are produced by calculate_sleep_time_vars_end() and are ",
         "consumed by the flag evaluators in flag_standards.R.",
         call. = FALSE)
  }
  invisible(missing)
}

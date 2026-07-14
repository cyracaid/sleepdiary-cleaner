#' Run the full SPL Sleep pipeline
#'
#' Executes the complete sleep EMA data cleaning pipeline:
#' data loading -> timestamp parsing -> interval processing ->
#' temporal correction -> duration correction -> metric computation ->
#' auto-detection -> visualization.
#'
#' @param config Character or list. Path to a YAML config file, or a config
#'   list (from \code{load_config()}). If NULL, uses the bundled default.
#' @param project_dir Character. Path to the project root containing data
#'   files and pipeline scripts. Default: current working directory.
#' @param skip_visualization Logical. If TRUE, skip visualization step.
#' @param verbose Logical. Print progress messages. Default: TRUE.
#'
#' @return Invisibly returns TRUE on successful completion.
#'
#' @examples
#' \dontrun{
#' run_pipeline()
#' run_pipeline("my_config.yaml")
#' run_pipeline("path/to/project")
#' }
#' @export
run_pipeline <- function(config = NULL, project_dir = ".", skip_visualization = FALSE, verbose = TRUE) {
  old_wd <- setwd(project_dir)
  on.exit(setwd(old_wd))

  # Load config
  if (is.character(config) || is.null(config)) {
    cfg <- load_config(config)
  } else if (is.list(config)) {
    cfg <- config
  } else {
    stop("config must be a file path, list, or NULL")
  }

  # Store config globally for other scripts to access
  assign("pipeline_config", cfg, envir = .GlobalEnv)

  if (verbose) cat(sprintf("\n=== SPL Sleep Pipeline (%s) ===\n", cfg$pipeline$name %||% "splsleep"))

  # Source setup (loads data into global env)
  source("00a_setup.R", local = TRUE)

  # Adapt columns: rename user's column names to pipeline-internal names
  if (exists("df", envir = .GlobalEnv)) {
    df <- get("df", envir = .GlobalEnv)
    df <- adapt_columns(df, cfg)
    assign("df", df, envir = .GlobalEnv)
    if (verbose) cat(sprintf("Columns adapted from config mapping (%d columns renamed)\n",
                             sum(names(df) %in% names(config_get(cfg, "column_mapping", list())))))
  }
  if (exists("ema_data_release_timeproc", envir = .GlobalEnv)) {
    assign("ema_data_release_timeproc",
           adapt_columns(get("ema_data_release_timeproc", envir = .GlobalEnv), cfg),
           envir = .GlobalEnv)
  }
  if (exists("ema_data_release_timecalc", envir = .GlobalEnv)) {
    assign("ema_data_release_timecalc",
           adapt_columns(get("ema_data_release_timecalc", envir = .GlobalEnv), cfg),
           envir = .GlobalEnv)
  }

  if (verbose) cat("Setup complete. Starting main pipeline...\n")
  source("00_MAIN_entry.R", local = TRUE)

  # Call the internal pipeline function
  .run_pipeline_internal()

  if (verbose) cat("\n=== Pipeline complete ===\n")
  invisible(TRUE)
}

#' Run only the setup step
#'
#' Loads and validates input data files without running the full pipeline.
#'
#' @param config Character or list. Config path or config list.
#' @param project_dir Character. Path to project root.
#' @export
run_setup <- function(config = NULL, project_dir = ".") {
  old_wd <- setwd(project_dir)
  on.exit(setwd(old_wd))
  if (is.character(config) || is.null(config)) {
    cfg <- load_config(config)
  } else {
    cfg <- config
  }
  assign("pipeline_config", cfg, envir = .GlobalEnv)
  source("00a_setup.R", local = TRUE)
  cat("Setup complete. Data loaded successfully.\n")
  invisible(TRUE)
}

#' Run only the visualization step
#'
#' Generates all figures from previously corrected data.
#' Requires `corrected_ema_data` and `pipeline_config` in global environment.
#'
#' @param config Character or list. Config path or config list.
#' @param project_dir Character. Path to project root.
#' @export
run_visualization <- function(config = NULL, project_dir = ".") {
  old_wd <- setwd(project_dir)
  on.exit(setwd(old_wd))
  if (is.character(config) || is.null(config)) {
    cfg <- load_config(config)
  } else {
    cfg <- config
  }
  assign("pipeline_config", cfg, envir = .GlobalEnv)
  source("sleep_visualization.R", local = TRUE)
  invisible(TRUE)
}

#' Run the correction status report
#'
#' @param config Character or list. Config path or config list.
#' @param project_dir Character. Path to project root.
#' @export
run_report <- function(config = NULL, project_dir = ".") {
  old_wd <- setwd(project_dir)
  on.exit(setwd(old_wd))
  source("report_correction_status.R", local = TRUE)
  invisible(TRUE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

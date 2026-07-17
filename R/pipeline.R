scripts_dir <- function() {
  pkg_dir <- system.file("scripts", package = "splsleep")
  if (nchar(pkg_dir) > 0 && dir.exists(pkg_dir)) return(pkg_dir)
  getwd()
}

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
#'   files. Default: current working directory.
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

  # Locate pipeline scripts (installed package or repo root)
  sdir <- scripts_dir()
  assign("splsleep_scripts_dir", sdir, envir = .GlobalEnv)

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
  assign("splsleep_loaded", TRUE, envir = .GlobalEnv)

  if (verbose) cat(sprintf("\n=== SPL Sleep Pipeline (%s) ===\n",
                           if (is.null(cfg$pipeline$name)) "splsleep" else cfg$pipeline$name))

  # Source setup (loads data into global env)
  source(file.path(sdir, "00a_setup.R"), local = TRUE)

  # Adapt columns only when a custom config with non-default mapping is provided
  if (!is.null(cfg$column_mapping) && !is.null(config)) {
    if (exists("df", envir = .GlobalEnv)) {
      df <- get("df", envir = .GlobalEnv)
      df <- adapt_columns(df, cfg)
      assign("df", df, envir = .GlobalEnv)
      if (verbose) cat(sprintf("Columns adapted from config mapping (%d columns renamed)\n",
                               sum(names(df) %in% names(config_get(cfg, "column_mapping", list())))))
    }
    for (obj in c("ema_data_release_timeproc", "ema_data_release_timecalc")) {
      if (exists(obj, envir = .GlobalEnv)) {
        assign(obj, adapt_columns(get(obj, envir = .GlobalEnv), cfg),
               envir = .GlobalEnv)
      }
    }
  }

  if (verbose) cat("Setup complete. Starting main pipeline...\n")
  source(file.path(sdir, "00_MAIN_entry.R"), local = TRUE)

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
  sdir <- scripts_dir()
  assign("splsleep_scripts_dir", sdir, envir = .GlobalEnv)
  if (is.character(config) || is.null(config)) {
    cfg <- load_config(config)
  } else {
    cfg <- config
  }
  assign("pipeline_config", cfg, envir = .GlobalEnv)
  source(file.path(sdir, "00a_setup.R"), local = TRUE)
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
  sdir <- scripts_dir()
  assign("splsleep_scripts_dir", sdir, envir = .GlobalEnv)
  if (is.character(config) || is.null(config)) {
    cfg <- load_config(config)
  } else {
    cfg <- config
  }
  assign("pipeline_config", cfg, envir = .GlobalEnv)
  source(file.path(sdir, "sleep_visualization.R"), local = TRUE)
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
  sdir <- scripts_dir()
  assign("splsleep_scripts_dir", sdir, envir = .GlobalEnv)
  source(file.path(sdir, "report_correction_status.R"), local = TRUE)
  invisible(TRUE)
}

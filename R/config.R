#' Load pipeline configuration
#'
#' Reads a YAML config file and returns a list of settings.
#' Falls back to the bundled default config if no file is specified.
#'
#' @param config_file Character. Path to a YAML config file, or NULL to use
#'   the bundled default (\code{inst/config_default.yaml}).
#' @return List of pipeline configuration values.
#' @keywords internal
load_config <- function(config_file = NULL) {
  if (is.null(config_file)) {
    config_file <- system.file("config_default.yaml", package = "splsleep")
    if (config_file == "") {
      dev_path <- file.path(getwd(), "inst", "config_default.yaml")
      if (file.exists(dev_path)) config_file <- dev_path
    }
  }
  if (!file.exists(config_file)) {
    stop("Config file not found: ", config_file)
  }
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required to read config. Install with: install.packages('yaml')")
  }
  cfg <- yaml::read_yaml(config_file)

  # Resolve relative data paths against config file's directory
  cfg_dir <- dirname(normalizePath(config_file))
  if (!is.null(cfg$data$files)) {
    for (fname in names(cfg$data$files)) {
      fpath <- cfg$data$files[[fname]]
      if (!is.null(fpath) && nchar(fpath) > 0 && !grepl("^/|^~", fpath)) {
        resolved <- file.path(cfg_dir, fpath)
        if (file.exists(resolved)) {
          cfg$data$files[[fname]] <- normalizePath(resolved)
        }
      }
    }
  }
  cfg
}

#' Get a nested config value by dot-separated key
#'
#' @param config List. Configuration list from \code{load_config()}.
#' @param key Character. Dot-separated key, e.g. \code{"classification.temporal.max_sol_minutes"}.
#' @param default Default value if key not found.
#' @return The config value, or \code{default}.
#' @keywords internal
config_get <- function(config, key, default = NULL) {
  # Fallback: check global env if config not provided
  if (missing(config) || is.null(config)) {
    config <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
  }
  if (is.null(config)) return(default)
  keys <- strsplit(key, "\\.")[[1]]
  val <- config
  for (k in keys) {
    if (is.list(val) && k %in% names(val)) {
      val <- val[[k]]
    } else {
      return(default)
    }
  }
  val
}

#' Safe config_get — fetches pipeline_config from global env automatically
#'
#' Use this in standalone scripts (sleep_visualization.R, checkforerrors_processing.R)
#' where pipeline_config may not exist in the calling scope.
#'
#' @param key Character. Dot-separated key.
#' @param default Default value if key not found.
#' @return The config value, or \code{default}.
#' @export
cfg_get <- function(key, default = NULL) {
  cfg <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
  config_get(cfg, key, default)
}

#' Get column mapping from config
#'
#' Returns the user's column name for a given pipeline-internal column.
#'
#' @param config List. Configuration list.
#' @param internal_name Character. Pipeline-internal column name.
#' @return Character. User's column name, or \code{internal_name} if not mapped.
#' @keywords internal
config_col <- function(config, internal_name) {
  mapping <- config_get(config, "column_mapping", list())
  for (section in names(mapping)) {
    if (internal_name %in% names(mapping[[section]])) {
      return(mapping[[section]][[internal_name]])
    }
  }
  # Try flat lookup
  for (section in names(mapping)) {
    for (key in names(mapping[[section]])) {
      if (key == internal_name) {
        return(mapping[[section]][[key]])
      }
    }
  }
  internal_name  # fallback: use as-is
}

#' Apply column mapping to a data frame
#'
#' Renames columns in \code{data} according to the mapping defined in config.
#' Columns whose mapped name is NULL are skipped.
#'
#' @param data Data frame. Raw input data with user's column names.
#' @param config List. Configuration list from \code{load_config()}.
#' @return Data frame with columns renamed to pipeline-internal names.
#' @export
adapt_columns <- function(data, config) {
  mapping <- config_get(config, "column_mapping", list())
  reverse_map <- list()

  # Build reverse map: user_col_name -> internal_name
  for (section in names(mapping)) {
    for (internal_name in names(mapping[[section]])) {
      user_name <- mapping[[section]][[internal_name]]
      if (!is.null(user_name) && !is.na(user_name) && user_name != "") {
        reverse_map[[user_name]] <- internal_name
      }
    }
  }

  # Rename columns that exist in the data
  for (user_name in names(reverse_map)) {
    if (user_name %in% names(data)) {
      internal_name <- reverse_map[[user_name]]
      names(data)[names(data) == user_name] <- internal_name
    }
  }

  data
}

#' Validate that required columns exist
#'
#' @param data Data frame.
#' @param required Character vector of column names that must exist.
#' @param label Character. Description of what's being checked (for error message).
#' @return Invisibly TRUE. Stops with error if columns are missing.
#' @export
validate_columns <- function(data, required, label = "data") {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(sprintf("Missing required columns in %s: %s",
                 label, paste(missing, collapse = ", ")))
  }
  invisible(TRUE)
}

#' Validate column types in a data frame
#'
#' Checks that specified columns have the expected R types.
#'
#' @param data Data frame.
#' @param type_spec Named list mapping column names to expected types
#'   (e.g. \code{list(pid = "numeric", StartDate = "Date")}).
#'   Use \code{"numeric"}, \code{"character"}, \code{"POSIXct"}, \code{"Date"}.
#' @param label Character. Description of data being checked.
#' @return Invisibly TRUE. Stops with error on mismatch.
#' @export
validate_column_types <- function(data, type_spec, label = "data") {
  for (col in names(type_spec)) {
    if (!col %in% names(data)) next
    expected <- type_spec[[col]]
    actual <- class(data[[col]])[1]
    ok <- switch(expected,
      numeric = actual %in% c("numeric", "integer"),
      character = actual == "character",
      POSIXct = actual == "POSIXct" || actual == "Date",
      Date = actual == "Date",
      logical = actual == "logical",
      actual == expected
    )
    if (!ok) {
      stop(sprintf("Column '%s' in %s: expected %s, got %s", col, label, expected, actual))
    }
  }
  invisible(TRUE)
}

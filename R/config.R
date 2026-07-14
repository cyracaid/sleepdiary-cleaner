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
    # Use bundled default
    config_file <- system.file("config_default.yaml", package = "splsleep")
    if (config_file == "") {
      # Development mode: check project root
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
  yaml::read_yaml(config_file)
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

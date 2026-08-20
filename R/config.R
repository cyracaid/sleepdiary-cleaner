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
    config_file <- system.file("config_default.yaml", package = "sleepcleanr")
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
  if (is.null(val)) return(default)
  val
}

#' Safe config_get -- fetches pipeline_config from global env automatically
#'
#' Use this in standalone scripts (sleep_visualization.R, checkforerrors_processing.R)
#' where pipeline_config may not exist in the calling scope.
#'
#' @param key Character. Dot-separated key.
#' @param default Default value if key not found.
#' @param cfg Optional. A pipeline configuration list. When provided, this
#'   is used directly instead of falling back to the global environment.
#'   **From v1.3.1, passing \code{cfg} explicitly is the preferred path.**
#'   The global-environment fallback is deprecated and will emit a warning.
#' @return The config value, or \code{default}.
#' @export
cfg_get <- function(key, default = NULL, cfg = NULL) {
  if (is.null(cfg)) {
    cfg <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
    if (!is.null(cfg)) {
      warning("cfg_get(\"", key, "\") read from .GlobalEnv$pipeline_config. ",
              "Pass cfg explicitly. Deprecated in v1.4.0.",
              call. = FALSE)
    }
  }
  config_get(cfg, key, default)
}

#' Resolve the figure output directory for a run
#'
#' Builds the run-specific visualization directory name:
#' \code{<root>/latest_visualization_<tag>_n<records>}. The base root comes from
#' config (\code{output.figure.root_dir} for real data, \code{output.figure.synth_root_dir}
#' for synthetic/test AND unresolved data). Only a data_tag that has been
#' positively confirmed as \code{"real"} is trusted with the \code{output/}
#' root -- \code{"synth"} and \code{"unknown"} both stay outside \code{output/}
#' by default. This is a fail-closed choice: \code{"unknown"} means the tag
#' detector could not read \code{data.files.main} from the config (see
#' \code{sleep_visualization.R}), i.e. we genuinely do not know what was
#' loaded. Routing it next to confirmed real-data figures would silently
#' extend real-data trust (gitignored, "never leaves the study team" handling)
#' to data whose identity is unverified. Before 2026-08-11, "unknown" fell
#' into the \code{else} branch and was treated exactly like "real"; that has
#' been fixed so only "real" gets the privileged path.
#'
#' @param cfg Optional. Pipeline configuration list (preferred; falls back to
#'   the global environment when omitted).
#' @param data_tag Character. "real", "synth", or "unknown".
#' @param n_records Numeric or NULL. Row count appended to the directory name.
#' @return Character. Relative path to the figure output directory.
#' @export
figure_run_dir <- function(cfg = NULL, data_tag, n_records = NULL) {
  base <- if (identical(data_tag, "real")) {
    cfg_get("output.figure.root_dir", "output", cfg = cfg)
  } else {
    # "synth" and "unknown" both land here -- see the fail-closed rationale above.
    cfg_get("output.figure.synth_root_dir", "", cfg = cfg)
  }
  nm <- paste0("latest_visualization_", data_tag,
               if (!is.null(n_records) && !is.na(n_records)) paste0("_n", n_records) else "")
  if (nzchar(base)) file.path(base, nm) else nm
}

#' Resolve the stable, never-wiped verification directory for a run
#'
#' Verification artifacts (S3-vs-legacy snapshot \code{.rds} pairs, the
#' Markdown verification report, advisory analyses such as Bland-Altman
#' plots) must survive the *next* pipeline run. The figure run directory
#' returned by \code{\link{figure_run_dir}} does not survive it -- every run
#' of \code{sleep_visualization.R} deletes and rebuilds that directory from
#' scratch.
#'
#' Earlier, \code{verification/} was nested *inside* the wiped run directory
#' and rescued around each wipe with a rename-out/rename-back dance
#' implemented once, in \code{sleep_visualization.R}. That single
#' implementation was the only thing standing between the wipe and data loss;
#' on 2026-08-11 a wipe ran before the dance existed and permanently deleted
#' that day's verification report (it was gitignored, so it could not be
#' recovered from git either -- see the "History note" in
#' \code{output/verification/real_n13990/VERIFICATION_2026-08-10.md}). This
#' function fixes the root cause instead of guarding the symptom: it returns
#' a path that is a *sibling* of the run directory, not a child of it, so no
#' wipe -- current or future, in this script or any other -- can reach it.
#' No preserve logic is required anywhere, and none can be forgotten.
#'
#' @inheritParams figure_run_dir
#' @return Character. Relative path to the stable verification directory,
#'   e.g. \code{"output/verification/real_n13990"} or
#'   \code{"verification/synth_n280"}.
#' @keywords internal
verification_run_dir <- function(cfg = NULL, data_tag, n_records = NULL) {
  run_dir <- figure_run_dir(cfg = cfg, data_tag = data_tag, n_records = n_records)
  suffix  <- paste0(data_tag,
                     if (!is.null(n_records) && !is.na(n_records)) paste0("_n", n_records) else "")
  file.path(dirname(run_dir), "verification", suffix)
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
  # Config keys are LOGICAL column names (e.g. time_bed_hhmm); the pipeline's
  # canonical data columns carry the AM/PM suffix (e.g. time_bed_am_hhmm).
  # consumer code (flag_standards.R etc.) hardcodes the long form, so a mapped
  # user column must land on the canonical name, not on the logical key.
  .CANONICAL_NAMES <- c(
    time_bed_hhmm    = "time_bed_am_hhmm",
    time_bed_ampm    = "time_bed_am_ampm",
    time_sleep_hhmm  = "time_sleep_am_hhmm",
    time_sleep_ampm  = "time_sleep_am_ampm",
    time_awake_hhmm  = "time_awake_am_hhmm",
    time_awake_ampm  = "time_awake_am_ampm",
    time_getup_hhmm  = "time_getup_am_hhmm",
    time_getup_ampm  = "time_getup_am_ampm"
  )

  mapping <- config_get(config, "column_mapping", list())
  reverse_map <- list()

  # Build reverse map: user_col_name -> internal (canonical) name
  for (section in names(mapping)) {
    for (internal_name in names(mapping[[section]])) {
      user_name <- mapping[[section]][[internal_name]]
      if (!is.null(user_name) && !is.na(user_name) && user_name != "") {
        canonical <- unname(.CANONICAL_NAMES[internal_name])
        if (!is.na(canonical)) internal_name <- canonical
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
      integer = actual %in% c("integer", "numeric"),
      character = actual %in% c("character", "hms"),
      POSIXct = actual == "POSIXct" || actual == "Date",
      Date = actual == "Date",
      logical = actual == "logical",
      any = TRUE,  # accept any type
      actual == expected
    )
    if (!ok) {
      stop(sprintf("Column '%s' in %s: expected %s, got %s", col, label, expected, actual))
    }
  }
  invisible(TRUE)
}

#' Validate config file paths for R code expressions
#'
#' Checks that data file paths in the config are absolute paths, not
#' R expressions like paste0(...) or file.path(...). Call during
#' pipeline setup to catch config errors early.
#' @param cfg Config list (from load_config)
#' @export
validate_no_r_code_in_paths <- function(cfg) {
  rds <- config_get(cfg, "data.files.main", "")
  csv <- config_get(cfg, "data.files.extra", "")
  for (path in c(rds, csv)) {
    if (is.character(path) && grepl("paste0|file\\.path|~\\$|getwd", path)) {
      stop("Config paths must be absolute paths, not R expressions. Found: ", path)
    }
  }
  invisible(TRUE)
}

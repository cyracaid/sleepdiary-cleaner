# Package-private run state.
#
# run_pipeline() used to leave its working objects (config, corrected data,
# review output, ...) in the user's global environment. They now live in this
# environment instead; pipeline_results() returns them, and run_pipeline(
# export_env = ) copies them into an environment the caller names.

.sc_state <- new.env(parent = emptyenv())

.sc_set <- function(name, value) {
  assign(name, value, envir = .sc_state)
  invisible(value)
}

.sc_get <- function(name, default = NULL) {
  get0(name, envir = .sc_state, inherits = FALSE, ifnotfound = default)
}

.sc_has <- function(name) exists(name, envir = .sc_state, inherits = FALSE)

.sc_clear <- function() {
  rm(list = ls(.sc_state, all.names = TRUE), envir = .sc_state)
  invisible(NULL)
}

# The active pipeline config: this run's, else one the user placed in their own
# global environment (the legacy source()-based workflow). Reading only.
.sc_config <- function() {
  cfg <- .sc_get("pipeline_config")
  if (is.null(cfg)) cfg <- get0("pipeline_config", envir = globalenv(), ifnotfound = NULL)
  cfg
}

# An object of the current run, falling back to the user's global environment
# (reading only) for the legacy workflow.
.sc_obj <- function(name) {
  if (.sc_has(name)) return(.sc_get(name))
  get0(name, envir = globalenv(), ifnotfound = NULL)
}

# Copy the run's objects into a frame so the sourced step scripts (which run in
# that frame) find them by name, as they used to find them in the global environment.
.sc_restore <- function(frame) {
  nm <- c("ema_data_release_timecalc", "corrected_ema_data", "review_output",
          "checkforerrors_summary", "clean_df", "error_df", "unusual_df",
          "equal_time_df", "reasonable_unusual_df", "substance_decimal_anomalies")
  for (n in nm) if (.sc_has(n) && !exists(n, envir = frame, inherits = FALSE)) {
    assign(n, .sc_get(n), envir = frame)
  }
  invisible(NULL)
}

#' Objects left by the last pipeline run
#'
#' \code{run_pipeline()} keeps its main results in the package, not in the
#' global environment. This returns them.
#'
#' @return A named list with \code{corrected_ema_data} (the data after
#'   corrections and metrics), \code{review_output} (the review queue and the
#'   flagged data), \code{checkforerrors_summary} and \code{pipeline_config};
#'   elements not available for the last run are \code{NULL}.
#' @export
#' @examples
#' \dontrun{
#' run_pipeline(config = "my_study.yaml")
#' res <- pipeline_results()
#' head(res$corrected_ema_data)
#' }
pipeline_results <- function() {
  nm <- c("corrected_ema_data", "review_output", "checkforerrors_summary",
          "pipeline_config")
  stats::setNames(lapply(nm, .sc_get), nm)
}

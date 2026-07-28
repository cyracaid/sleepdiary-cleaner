#' The sleep_diary S3 class
#'
#' A thin, non-invasive container that travels through the cleaning pipeline.
#' It carries the working data frame plus the provenance of every step that has
#' touched it, so that any step can be inspected with the same three verbs:
#' \code{print()}, \code{summary()} and \code{plot()}.
#'
#' Design note (v1.3.0, wrapper-first strategy): this class does NOT reimplement
#' any cleaning logic. Each pipeline step remains exactly the script it was in
#' v1.2.0; the step adapters in \code{steps.R} only box and unbox the data frame
#' around those unchanged calls. That keeps behaviour bit-identical while giving
#' the package a real interface contract to test against.
#'
#' Internal structure:
#' \describe{
#'   \item{data}{data.frame -- the working data}
#'   \item{step}{list -- provenance of the most recent step}
#'   \item{history}{list of step records, oldest first}
#'   \item{cfg}{list or NULL -- the pipeline config in force}
#' }
#'
#' @name sleep_diary
NULL

#' Class version stamped into every step record
#' @keywords internal
#' @noRd
.SLEEP_DIARY_VERSION <- "1.3.0"

# Columns referenced inside ggplot2::aes(); declared so R CMD check does not
# report them as undefined global variables.
utils::globalVariables(c("step_lab", "n_rows_out"))

#' Construct a sleep_diary object
#'
#' @param data A data frame holding the working records.
#' @param step_id Character. Short ordered step id, e.g. "1", "1.5", "2".
#'   Use "0" for a freshly loaded object that no step has processed yet.
#' @param step_label Character. Human-readable step name.
#' @param cfg List or NULL. Pipeline configuration in force.
#' @param history List of prior step records (oldest first).
#' @param extra List. Optional extra fields merged into the step record,
#'   for example \code{list(n_corrected = 12)}.
#'
#' @return An object of class \code{sleep_diary}.
#' @export
new_sleep_diary <- function(data,
                            step_id = "0",
                            step_label = "raw",
                            cfg = NULL,
                            history = list(),
                            extra = list()) {
  if (!is.data.frame(data)) {
    stop("new_sleep_diary(): `data` must be a data frame, got ",
         paste(class(data), collapse = "/"), call. = FALSE)
  }
  if (!is.character(step_id) || length(step_id) != 1L) {
    stop("new_sleep_diary(): `step_id` must be a single character string.",
         call. = FALSE)
  }
  if (!is.character(step_label) || length(step_label) != 1L) {
    stop("new_sleep_diary(): `step_label` must be a single character string.",
         call. = FALSE)
  }

  step <- list(
    id          = step_id,
    label       = step_label,
    version     = .SLEEP_DIARY_VERSION,
    n_rows      = nrow(data),
    n_cols      = ncol(data),
    n_rows_in   = NA_integer_,
    cols_added  = character(0),
    duration_ms = NA_real_,
    timestamp   = Sys.time()
  )
  if (length(extra)) step[names(extra)] <- extra

  structure(
    list(data = data, step = step, history = history, cfg = cfg),
    class = "sleep_diary"
  )
}

#' Validate a sleep_diary object
#'
#' Checks the structural invariants the pipeline relies on. Called by the step
#' adapters so a malformed object fails loudly at the boundary rather than
#' silently three steps later.
#'
#' @param x An object to validate.
#' @return \code{x}, invisibly, if valid; otherwise an error is raised.
#' @export
validate_sleep_diary <- function(x) {
  if (!inherits(x, "sleep_diary")) {
    stop("Expected a <sleep_diary> object, got ",
         paste(class(x), collapse = "/"), call. = FALSE)
  }
  required <- c("data", "step", "history", "cfg")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop("<sleep_diary> is missing component(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!is.data.frame(x$data)) {
    stop("<sleep_diary>$data must be a data frame.", call. = FALSE)
  }
  if (!is.list(x$step) || is.null(x$step$id)) {
    stop("<sleep_diary>$step must be a list carrying at least an `id`.",
         call. = FALSE)
  }
  if (!is.list(x$history)) {
    stop("<sleep_diary>$history must be a list.", call. = FALSE)
  }
  invisible(x)
}

#' Coerce a data frame into a sleep_diary
#'
#' @param x A data frame, or an existing sleep_diary (returned unchanged).
#' @param ... Passed to \code{new_sleep_diary()}.
#' @return A \code{sleep_diary} object.
#' @export
as_sleep_diary <- function(x, ...) {
  if (inherits(x, "sleep_diary")) return(x)
  new_sleep_diary(x, ...)
}

#' Test whether an object is a sleep_diary
#'
#' @param x Any object.
#' @return Logical scalar.
#' @export
is_sleep_diary <- function(x) inherits(x, "sleep_diary")

#' Extract the working data frame from a sleep_diary
#'
#' The escape hatch for backward compatibility: any v1.2.0 code that expects a
#' plain data frame can call this and carry on unchanged.
#'
#' @param x A \code{sleep_diary} object.
#' @param row.names NULL or a character vector giving row names.
#' @param optional Logical. Unused; present for S3 generic consistency.
#' @param ... Unused.
#' @return A data frame.
#' @export
as.data.frame.sleep_diary <- function(x, row.names = NULL, optional = FALSE, ...) {
  validate_sleep_diary(x)
  x$data
}

#' Dimensions of a sleep_diary
#'
#' Defined so that \code{nrow()} and \code{ncol()} work directly on the object.
#' Note that \code{nrow} itself is not generic in base R -- it dispatches
#' through \code{dim()}, which is why this method exists rather than an
#' \code{nrow.sleep_diary}.
#'
#' @param x A \code{sleep_diary} object.
#' @return Integer vector of length 2: rows, columns.
#' @export
dim.sleep_diary <- function(x) dim(x$data)

#' One-line status of a sleep_diary
#'
#' @param x A \code{sleep_diary} object.
#' @param ... Unused.
#' @return \code{x}, invisibly.
#' @export
print.sleep_diary <- function(x, ...) {
  validate_sleep_diary(x)
  s <- x$step
  cat(sprintf("<sleep_diary> after step %s (%s)\n", s$id, s$label))
  cat(sprintf("  %s records x %s columns", format(s$n_rows, big.mark = ","),
              format(s$n_cols, big.mark = ",")))
  if (!is.na(s$duration_ms)) {
    cat(sprintf("  |  %.0f ms", s$duration_ms))
  }
  cat("\n")
  if (length(s$cols_added)) {
    shown <- utils::head(s$cols_added, 4L)
    more <- length(s$cols_added) - length(shown)
    cat(sprintf("  new columns: %s%s\n", paste(shown, collapse = ", "),
                if (more > 0) sprintf(" (+%d more)", more) else ""))
  }
  cat(sprintf("  chain: %d step(s) recorded\n", length(x$history)))
  invisible(x)
}

#' Tabulate the whole pipeline chain recorded in a sleep_diary
#'
#' Returns one row per step: how many records went in and out, how many columns
#' the step added, and how long it took. When the flag ledger from
#' \code{log_step()} is populated it is joined on, so the same call answers both
#' "what did each step do" and "how many records were flagged after it".
#'
#' @param object A \code{sleep_diary} object.
#' @param ... Unused.
#' @return A data frame with one row per recorded step, invisibly printed.
#' @export
summary.sleep_diary <- function(object, ...) {
  validate_sleep_diary(object)
  steps <- c(object$history, list(object$step))

  out <- do.call(rbind, lapply(steps, function(s) {
    data.frame(
      step_id     = s$id %||% NA_character_,
      label       = s$label %||% NA_character_,
      n_rows_in   = s$n_rows_in %||% NA_integer_,
      n_rows_out  = s$n_rows %||% NA_integer_,
      n_cols      = s$n_cols %||% NA_integer_,
      n_cols_added = length(s$cols_added %||% character(0)),
      duration_ms = s$duration_ms %||% NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL

  ledger <- tryCatch(get_step_ledger_wide("data_category"),
                     error = function(e) data.frame())
  if (is.data.frame(ledger) && nrow(ledger) > 0 && "step_id" %in% names(ledger)) {
    keep <- setdiff(names(ledger), c("label", "n_corrected", "n_suppressed"))
    out <- merge(out, ledger[, keep, drop = FALSE],
                 by = "step_id", all.x = TRUE, sort = FALSE)
    ord <- match(vapply(steps, function(s) s$id %||% NA_character_, character(1)),
                 out$step_id)
    out <- out[stats::na.omit(ord), , drop = FALSE]
    rownames(out) <- NULL
  }

  structure(out, class = c("summary.sleep_diary", "data.frame"))
}

#' Print a sleep_diary summary
#' @param x A \code{summary.sleep_diary} object.
#' @param ... Unused.
#' @return \code{x}, invisibly.
#' @export
print.summary.sleep_diary <- function(x, ...) {
  cat("Pipeline chain summary\n")
  cat(strrep("-", 60), "\n", sep = "")
  print.data.frame(x, row.names = FALSE)
  invisible(x)
}

#' Plot the state of a sleep_diary
#'
#' Degrades gracefully: with ggplot2 available it draws the record count and
#' flag composition across the recorded chain; without it, falls back to a base
#' R barplot. Never errors just because a Suggests package is absent.
#'
#' @param x A \code{sleep_diary} object.
#' @param y Unused; present for S3 generic consistency.
#' @param ... Unused.
#' @return The plot object, invisibly.
#' @export
plot.sleep_diary <- function(x, y = NULL, ...) {
  validate_sleep_diary(x)
  sm <- summary(x)
  if (nrow(sm) == 0) {
    message("Nothing to plot: no steps recorded yet.")
    return(invisible(NULL))
  }

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    graphics::barplot(sm$n_rows_out, names.arg = sm$step_id,
                      main = "Records retained per step",
                      xlab = "step", ylab = "records")
    return(invisible(NULL))
  }

  plot_df <- data.frame(
    step_lab = factor(paste0(sm$step_id, ": ", sm$label),
                      levels = paste0(sm$step_id, ": ", sm$label)),
    n_rows_out = sm$n_rows_out,
    stringsAsFactors = FALSE
  )
  p <- ggplot2::ggplot(plot_df,
                       ggplot2::aes(x = step_lab, y = n_rows_out, group = 1)) +
    ggplot2::geom_line() +
    ggplot2::geom_point() +
    ggplot2::labs(title = "Records retained per pipeline step",
                  x = "step", y = "records") +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
  print(p)
  invisible(p)
}

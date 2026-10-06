#' Describe what a pipeline run changed, in words a Methods section can use
#'
#' Builds a short, factual description of the last pipeline run from the objects the
#' run already produced: how many entries and participants, how many entries a rule
#' corrected (by rule), how many a reviewer corrected, how many remain in the review
#' queue, and the reference thresholds in use. It states only counts that can be read
#' from the run; it makes no claim about accuracy.
#'
#' @param results A list as returned by \code{\link{pipeline_results}()} (the default),
#'   with at least \code{corrected_ema_data}. \code{review_output} and
#'   \code{pipeline_config} are used when present.
#' @param file Optional path. If given, the text is also written there as plain text
#'   (Markdown-compatible).
#' @return Invisibly, a list with \code{text} (a character vector, one element per
#'   paragraph) and \code{counts} (a data frame of corrections by rule). The text is
#'   also printed.
#' @export
#' @examples
#' \dontrun{
#' run_pipeline(config = "my_study.yaml", include_manual_corrections = TRUE)
#' cleaning_report()
#' }
cleaning_report <- function(results = pipeline_results(), file = NULL) {
  x <- results$corrected_ema_data
  if (!is.data.frame(x) || nrow(x) == 0) {
    stop("No pipeline results found. Run run_pipeline() first, or pass `results`.")
  }
  cfg <- results$pipeline_config
  fmt_n <- function(n) format(n, big.mark = ",", trim = TRUE)
  pct <- function(a, b) sprintf("%.1f%%", 100 * a / b)

  n_rows <- nrow(x)
  n_pid <- if ("pid" %in% names(x)) length(unique(x$pid)) else NA_integer_
  tst_col <- "self_diffcalc_totalsleeptime_minutes"
  n_tst <- if (tst_col %in% names(x)) sum(!is.na(x[[tst_col]])) else NA_integer_

  rule_flag <- x$corrected %in% TRUE
  type <- as.character(x$correction_type)
  has_type <- rule_flag & !is.na(type) & nzchar(type)
  counts <- if (any(has_type)) {
    tb <- sort(table(type[has_type]), decreasing = TRUE)
    data.frame(rule = names(tb), entries = as.integer(tb), row.names = NULL,
               stringsAsFactors = FALSE)
  } else {
    data.frame(rule = character(0), entries = integer(0), stringsAsFactors = FALSE)
  }
  n_rule <- sum(has_type)
  n_manual <- if ("manually_corrected" %in% names(x)) sum(x$manually_corrected %in% TRUE) else 0L

  rv <- results$review_output
  n_queue <- if (is.list(rv) && is.data.frame(rv$checkforerrors_df)) nrow(rv$checkforerrors_df) else NA_integer_

  flip <- if (is.list(cfg)) cfg_get("timestamp.sequence.max_gap_hours", 12, cfg = cfg) else 12
  swap <- if (is.list(cfg)) cfg_get("normalize.swap_threshold_hours", 3, cfg = cfg) else 3
  ver <- as.character(utils::packageVersion("sleepcleanr"))

  p1 <- sprintf(
    "The diary data comprised %s entries%s. Times and durations were parsed and checked with sleepcleanr (version %s) using reference thresholds of %s hours for an AM/PM flip and %s hours for a transposed adjacent pair of times. %s entries (%s) had a computable total sleep time.",
    fmt_n(n_rows), if (is.na(n_pid)) "" else sprintf(" from %s participants", fmt_n(n_pid)),
    ver, format(flip), format(swap),
    if (is.na(n_tst)) "Some" else fmt_n(n_tst), if (is.na(n_tst)) "" else pct(n_tst, n_rows))

  rules <- if (nrow(counts) > 0) {
    paste0(": ", paste(sprintf("%s (%s)", counts$rule, fmt_n(counts$entries)), collapse = ", "))
  } else ""
  p2 <- sprintf(
    "A documented rule corrected %s entries%s. %s%s Every change is recorded with its type and the original entry is kept, so raw and corrected values can be compared.",
    fmt_n(n_rule), rules,
    if (n_manual > 0) sprintf("A reviewer corrected %s entries from a correction file. ", fmt_n(n_manual))
    else "No reviewer corrections were applied in this run. ",
    if (is.na(n_queue)) "" else sprintf("%s entries (%s) remained in the review queue after the run.",
                                        fmt_n(n_queue), pct(n_queue, n_rows)))

  text <- c(p1, p2)
  cat(paste(text, collapse = "\n\n"), "\n")
  if (!is.null(file)) writeLines(text, file)
  invisible(list(text = text, counts = counts))
}

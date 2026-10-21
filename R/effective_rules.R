# The rules a run actually used, printed at the start and saved with the results.
#
# Each line says where the value comes from: "default" (the package default) or
# "your config" (your config differs from the default). Nothing here decides
# anything; it only makes the rules in force visible, so two runs can be compared.

.sc_rule_registry <- function() {
  data.frame(
    key = c(
      "timestamp.sequence.max_gap_hours",
      "normalize.swap_threshold_hours",
      unname(.sc_rule_keys),
      "review.clean_categories",
      "review.done_when.max_needs_review",
      "review.missing_times_ok_after_manual",
      "review.step8_flags_need_review",
      "review.fail_if_not_done",
      "classification.metric_validation.sol.excessive_minutes",
      "classification.metric_validation.se.min_valid_percent",
      "classification.metric_validation.se.max_valid_percent",
      "classification.metric_validation.tst_tib_ratio.min_ratio",
      "classification.metric_validation.tst_tib_ratio.max_ratio",
      "classification.flag_severity.poor_efficiency_threshold_pct",
      "classification.flag_severity.high_sol_threshold_hours",
      "classification.flag_severity.high_waso_threshold_hours",
      "manual_corrections.manual_overrides_parser",
      "second_review.on_invalid_rows"),
    meaning = c(
      "Step 4: a gap of at least this many hours between adjacent times triggers an AM/PM flip",
      "Step 4: an out-of-order pair closer than this many hours is swapped",
      "Step 5 error: |sleep - bed| above this many hours",
      "Step 5 error: |getup - awake| above this many hours",
      "Step 5 error: |awake - sleep| above this many hours",
      "Step 5 unusual: sleep period below this many hours",
      "Step 5 unusual: sleep period above this many hours",
      "Step 5 unusual: sleep - bed above this many hours",
      "Step 5 unusual: getup - awake above this many hours",
      "Final categories that count as no longer needing a person",
      "Review is DONE when at most this many rows of review_status.csv are needs_review",
      "TRUE = a record handled in a manual file whose time is still missing counts as incorporated",
      "TRUE = a record that passes but has a Step 8 flag is needs_review",
      "TRUE = stop the run (after every output is written) when the review is NOT DONE",
      "Step 8: SOL above this many minutes is flagged",
      "Step 8: sleep efficiency below this percent is flagged",
      "Step 8: sleep efficiency above this percent is flagged",
      "Step 8: TST/TIB below this ratio is flagged",
      "Step 8: TST/TIB above this ratio is flagged",
      "Flag severity: sleep efficiency below this percent",
      "Flag severity: SOL above this many hours",
      "Flag severity: WASO above this many hours",
      "Manual sleep-metric-duration rows: TRUE = the manual row wins over the interval parser",
      "Second-review rows whose pid or day_num is not a number: skip (list them) or stop"),
    stringsAsFactors = FALSE)
}

.sc_fmt_val <- function(v) {
  if (is.null(v) || length(v) == 0L) return("")
  paste(vapply(unlist(v), function(x) format(x, trim = TRUE), character(1)), collapse = ", ")
}

#' The rules in force for a run
#' @param cfg The run's config list.
#' @param include_manual_corrections The value given to run_pipeline().
#' @return A data frame: key, value, default, source, meaning, plus the run mode.
#' @noRd
effective_rules <- function(cfg, include_manual_corrections = FALSE) {
  def <- load_config(NULL)
  reg <- .sc_rule_registry()
  val <- vapply(reg$key, function(k) .sc_fmt_val(config_get(cfg, k, config_get(def, k, NULL))), character(1))
  dv  <- vapply(reg$key, function(k) .sc_fmt_val(config_get(def, k, NULL)), character(1))
  # Rules the code does not read from the config get their value from the code
  # defaults; show those values rather than blanks.
  rd <- .sc_rule_defaults
  for (nm in names(.sc_rule_keys)) {
    k <- .sc_rule_keys[[nm]]
    if (!nzchar(dv[[k]])) dv[[k]] <- .sc_fmt_val(rd[[nm]])
    if (!nzchar(val[[k]])) val[[k]] <- .sc_fmt_val(.sc_step5_thresholds(cfg)[[nm]])
  }
  k <- "review.clean_categories"
  if (!nzchar(dv[[k]])) dv[[k]] <- .sc_fmt_val(.sc_clean_categories_default)
  if (!nzchar(val[[k]])) val[[k]] <- .sc_fmt_val(.sc_clean_categories(cfg))
  k <- "manual_corrections.manual_overrides_parser"
  if (!nzchar(dv[[k]])) dv[[k]] <- "FALSE"
  if (!nzchar(val[[k]])) val[[k]] <- .sc_fmt_val(isTRUE(config_get(cfg, k, FALSE)))
  k <- "second_review.on_invalid_rows"
  if (!nzchar(dv[[k]])) dv[[k]] <- "skip"
  if (!nzchar(val[[k]])) val[[k]] <- .sc_fmt_val(config_get(cfg, k, "skip"))
  out <- data.frame(key = reg$key, value = unname(val), default = unname(dv),
                    source = ifelse(val == dv, "default", "your config"),
                    meaning = reg$meaning, stringsAsFactors = FALSE)
  mode <- tolower(as.character(include_manual_corrections))
  out <- rbind(out, data.frame(
    key = "include_manual_corrections", value = mode, default = "false",
    source = ifelse(identical(mode, "false"), "default", "call argument"),
    meaning = "Whether human-review files are applied (an argument of run_pipeline(), not a YAML setting)",
    stringsAsFactors = FALSE))
  out
}

#' Print the rules in force and save them with the results
#' @noRd
report_effective_rules <- function(cfg, include_manual_corrections = FALSE, verbose = TRUE) {
  r <- tryCatch(effective_rules(cfg, include_manual_corrections),
                error = function(e) {
                  cat("\n  [rules] WARNING: could not compute the rules report:",
                      conditionMessage(e), "\n")
                  NULL
                })
  if (is.null(r)) return(invisible(NULL))
  out_dir  <- config_get(cfg, "output.report.dir", "output")
  csv_path <- file.path(out_dir, "effective_rules.csv")
  write_ok <- try({
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    utils::write.csv(r, csv_path, row.names = FALSE)
    TRUE
  }, silent = TRUE)
  if (verbose) {
    cat("\n=== Rules in effect for this run ===\n")
    for (i in seq_len(nrow(r)))
      cat(sprintf("  %-62s %-22s [%s]\n", r$key[i], r$value[i], r$source[i]))
    n_cfg <- sum(r$source == "your config")
    n_arg <- sum(r$source == "call argument")
    cat(sprintf("  %d rule(s) set in your config, %d set by the call; the rest are defaults.\n",
                n_cfg, n_arg))
    if (isTRUE(write_ok)) {
      cat(sprintf("  Saved to %s\n", csv_path))
    } else {
      cat(sprintf("  WARNING: could not save %s (report shown above only).\n", csv_path))
    }
  }
  invisible(r)
}

# audit_data_integrity.R
# Run at pipeline end to verify data hasn't been accidentally modified.
# Called from 00_MAIN_entry.R after all processing steps.

run_data_integrity_audit <- function(input_data, output_data) {
  report <- list()

  # 1) Row count check
  report$nrow_input  <- nrow(input_data)
  report$nrow_output <- nrow(output_data)
  report$row_count_ok <- report$nrow_input == report$nrow_output

  # 2) Column name check: all input columns should still exist in output
  input_cols  <- sort(names(input_data))
  output_cols <- sort(names(output_data))
  report$ncol_input  <- length(input_cols)
  report$ncol_output <- length(output_cols)
  report$missing_cols <- setdiff(input_cols, output_cols)
  report$new_cols     <- setdiff(output_cols, input_cols)
  report$col_names_ok <- length(report$missing_cols) == 0

  # 3) Check untouched variables for value consistency
  untouched_vars <- intersect(
    c("caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1",
      "alcoholtoday_PM_NumAlcoholicDrinks_1",
      "nicotine_amount_pm_doses", "cannabis_amount_pm_doses",
      "exercisetoday_PM_totalmin_Light",
      "exercisetoday_PM_totalmin_Moderate",
      "exercisetoday_PM_totalmin_Vigorous",
      "exercisetoday_PM_totalmin_Strength",
      "duration_totalmin_napstoday_PM"),
    names(input_data)
  )
  untouched_vars <- intersect(untouched_vars, names(output_data))

  mismatches <- list()
  for (v in untouched_vars) {
    i <- input_data[[v]]
    o <- output_data[[v]]
    if (is.numeric(i) && is.numeric(o)) {
      diff <- sum(abs(i - o) > 1e-6, na.rm = TRUE)
    } else {
      diff <- sum(is.na(i) != is.na(o)) +
              sum(!is.na(i) & !is.na(o) & i != o, na.rm = TRUE)
    }
    if (diff > 0) mismatches[[v]] <- diff
  }
  report$untouched_var_mismatches <- mismatches
  report$untouched_vars_ok <- length(mismatches) == 0

  # 4) Duplicate row check
  report$n_duplicates <- sum(duplicated(output_data))
  report$duplicates_ok <- report$n_duplicates == 0

  # Format report
  report_df <- data.frame(
    check = c("row_count", "col_names", "untouched_vars", "duplicates"),
    status = c(report$row_count_ok, report$col_names_ok,
               report$untouched_vars_ok, report$duplicates_ok),
    detail = c(
      sprintf("input=%d output=%d", report$nrow_input, report$nrow_output),
      sprintf("missing=%s new=%s",
              paste(report$missing_cols, collapse = ","),
              paste(report$new_cols, collapse = ",")),
      sprintf("mismatches=%d in %s",
              length(report$untouched_var_mismatches),
              paste(names(report$untouched_var_mismatches), collapse = ",")),
      sprintf("n=%d", report$n_duplicates)
    ),
    stringsAsFactors = FALSE
  )

  dir.create("output", showWarnings = FALSE)
  write.csv(report_df, "output/audit_integrity_report.csv", row.names = FALSE)

  all_ok <- report$row_count_ok && report$col_names_ok &&
            report$untouched_vars_ok && report$duplicates_ok
  status_char <- if (all_ok) "✓ PASS" else "✗ FAIL"
  cat(sprintf("\n[Audit %s] rows=%s cols=%s untouched=%s dups=%s\n",
              status_char,
              if (report$row_count_ok) "OK" else "MISMATCH",
              if (report$col_names_ok) "OK" else "CHANGED",
              if (report$untouched_vars_ok) "OK" else paste0(length(mismatches), " MISMATCH"),
              if (report$duplicates_ok) "OK" else paste0(report$n_duplicates, " DUP")))
  cat(sprintf("  Report: output/audit_integrity_report.csv\n"))

  invisible(report)
}

# Auto-run with corrected_ema_data if sourced in pipeline context
if (exists("corrected_ema_data") && exists("ema_data_release_timecalc")) {
  run_data_integrity_audit(ema_data_release_timecalc, corrected_ema_data)
} else if (exists("corrected_ema_data")) {
  cat("  Audit: input reference not available (ema_data_release_timecalc missing), skipping.\n")
}

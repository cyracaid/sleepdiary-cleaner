# ============================================================================
# report_correction_status.R — Per-step correction status reporter
# ============================================================================
# PURPOSE:
#   Prints a formatted status report at each pipeline checkpoint showing
#   how many records are clean/error/unusual/corrected and how the counts
#   change from step to step. Appends to a per-run CSV for history tracking.
#
# USAGE:
#   source("report_correction_status.R", local = TRUE)
#   sA <- report_status(ema_data_release_timecalc, "After Step 4", "A")
#   sB <- report_status(corrected_ema_data, "After Step 6", "B", previous = sA)
#   ...
#   final_summary(list(A = sA, B = sB, C = sC, D = sD, E = sE))
# ============================================================================

SEP <- paste(rep("\u2500", 60), collapse = "")

# ============================================================================
# report_status — Single checkpoint report
# ============================================================================
# INPUT:
#   data       — data.frame at the current pipeline stage
#   label      — human-readable checkpoint label (e.g. "After Step 6")
#   checkpoint — short ID ("A", "B", "C", "D", "E")
#   previous   — snapshot from report_status() at an earlier stage, or NULL
#   extra      — optional list with additional fields to print
#                (e.g. list(nap_corr = 11, metric_accept = 161))
# OUTPUT:
#   Printed report to console.
#   Returns a snapshot list (invisibly) for passing to later calls and final_summary().
# ============================================================================
report_status <- function(data, label, checkpoint = NULL,
                          previous = NULL, extra = NULL) {

  n_total <- nrow(data)

  # ── Count data_category (if available) ──
  has_cat <- "data_category" %in% names(data)
  if (has_cat) {
    n_clean      <- sum(data$data_category == "clean", na.rm = TRUE)
    n_error      <- sum(data$data_category == "error", na.rm = TRUE)
    n_unusual    <- sum(data$data_category == "unusual", na.rm = TRUE)
    n_equal_time <- sum(data$data_category == "equal_time_ok", na.rm = TRUE)
    n_skipped    <- sum(data$data_category == "skipped_na", na.rm = TRUE)
    n_reasonable <- sum(data$data_category == "reasonable_unusual", na.rm = TRUE)
    n_other      <- n_total - (n_clean + n_error + n_unusual + n_equal_time + n_skipped + n_reasonable)
  } else {
    n_clean <- n_error <- n_unusual <- n_equal_time <- n_skipped <- n_reasonable <- n_other <- NA_integer_
  }

  # ── Count manually_corrected (if available) ──
  has_corrected <- "manually_corrected" %in% names(data)
  n_corrected <- if (has_corrected) sum(data$manually_corrected, na.rm = TRUE) else NA_integer_

  # ── Metric summary (if after Step 7) ──
  has_metrics <- all(c("self_diffcalc_totalsleeptime_minutes",
                       "self_diffcalc_sol_minutes") %in% names(data))
  if (has_metrics) {
    tst <- data$self_diffcalc_totalsleeptime_minutes
    sol <- data$self_diffcalc_sol_minutes
    tst_mean <- mean(tst, na.rm = TRUE)
    tst_sd   <- sd(tst, na.rm = TRUE)
    sol_mean <- mean(sol, na.rm = TRUE)
    n_valid  <- sum(!is.na(tst))
  } else {
    tst_mean <- tst_sd <- sol_mean <- NA_real_
    n_valid <- NA_integer_
  }

  snapshot <- list(
    checkpoint        = checkpoint,
    label             = label,
    n_total           = n_total,
    n_clean           = n_clean,
    n_error           = n_error,
    n_unusual         = n_unusual,
    n_equal_time      = n_equal_time,
    n_skipped         = n_skipped,
    n_reasonable      = n_reasonable,
    n_other           = n_other,
    n_corrected       = n_corrected,
    n_valid           = n_valid,
    tst_mean          = tst_mean,
    tst_sd            = tst_sd,
    sol_mean          = sol_mean,
    extra             = extra
  )

  # ── Print ──
  cat(sprintf("\n\u2500\u2500 %s %s %s\n", checkpoint, label,
              paste(rep("\u2500", max(0, 50 - nchar(label) - nchar(checkpoint))), collapse = "")))

  if (has_cat && !is.na(n_clean)) {
    if (!is.null(previous) && !is.na(previous$n_clean)) {
      d_clean <- n_clean - previous$n_clean
      d_error <- n_error - previous$n_error
      d_unusual <- n_unusual - previous$n_unusual
      cat(sprintf("  Total: %d\n", n_total))
      cat(sprintf("  Clean:  %s (%+.0f)  Error:  %s (%+.0f)  Unusual:  %s (%+.0f)\n",
                  format(n_clean, big.mark = ","), d_clean,
                  format(n_error, big.mark = ","), d_error,
                  format(n_unusual, big.mark = ","), d_unusual))
      cat(sprintf("  Equal:  %s  Skipped NA:  %s\n",
                  format(n_equal_time, big.mark = ","),
                  format(n_skipped, big.mark = ",")))
    } else {
      pct_clean <- if (n_total > 0) sprintf("%.1f%%", n_clean / n_total * 100) else "-"
      pct_error <- if (n_total > 0) sprintf("%.1f%%", n_error / n_total * 100) else "-"
      pct_unusual <- if (n_total > 0) sprintf("%.1f%%", n_unusual / n_total * 100) else "-"
      cat(sprintf("  Total: %d\n", n_total))
      cat(sprintf("  Clean:  %s (%s)  Error:  %s (%s)  Unusual:  %s (%s)\n",
                  format(n_clean, big.mark = ","), pct_clean,
                  format(n_error, big.mark = ","), pct_error,
                  format(n_unusual, big.mark = ","), pct_unusual))
      cat(sprintf("  Equal Time:  %s  Skipped NA:  %s\n",
                  format(n_equal_time, big.mark = ","),
                  format(n_skipped, big.mark = ",")))
    }
  }

  if (has_corrected && !is.na(n_corrected) && n_corrected > 0) {
    if (!is.null(previous) && !is.na(previous$n_corrected)) {
      cat(sprintf("  Corrected:  %d (%+d this step)\n", n_corrected,
                  n_corrected - previous$n_corrected))
    } else {
      cat(sprintf("  Corrected:  %d\n", n_corrected))
    }
  }

  if (!is.null(extra)) {
    extra_str <- paste(names(extra), unlist(extra), sep = ": ", collapse = "  ")
    cat(sprintf("  %s\n", extra_str))
  }

  if (has_metrics && !is.na(n_valid) && n_valid > 0) {
    cat(sprintf("  Valid records:  %d  Mean TST:  %.2f h (SD %.2f)  Mean SOL:  %.1f min\n",
                n_valid, tst_mean / 60, tst_sd / 60, sol_mean))
  }

  # ── Write CSV ──
  write_status_csv(snapshot)

  invisible(snapshot)
}


# ============================================================================
# write_status_csv — Append snapshot to per-run CSV
# ============================================================================
write_status_csv <- function(s, dir = "output") {
  if (!dir.exists(dir)) dir.create(dir, showWarnings = FALSE)
  run_id <- format(Sys.time(), "%Y%m%d_%H%M")
  f <- file.path(dir, "correction_status.csv")

  row <- data.frame(
    run_id        = run_id,
    checkpoint    = s$checkpoint %||% NA_character_,
    label         = s$label %||% NA_character_,
    timestamp     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    n_total       = s$n_total %||% NA_integer_,
    n_clean       = s$n_clean %||% NA_integer_,
    n_error       = s$n_error %||% NA_integer_,
    n_unusual     = s$n_unusual %||% NA_integer_,
    n_equal_time  = s$n_equal_time %||% NA_integer_,
    n_skipped     = s$n_skipped %||% NA_integer_,
    n_reasonable  = s$n_reasonable %||% NA_integer_,
    n_corrected   = s$n_corrected %||% NA_integer_,
    n_valid       = s$n_valid %||% NA_integer_,
    tst_mean_h    = if (!is.null(s$tst_mean) && !is.na(s$tst_mean)) round(s$tst_mean / 60, 2) else NA_real_,
    sol_mean_min  = if (!is.null(s$sol_mean) && !is.na(s$sol_mean)) round(s$sol_mean, 1) else NA_real_,
    stringsAsFactors = FALSE
  )

  if (file.exists(f)) {
    suppressWarnings(tryCatch(
      write.table(row, f, append = TRUE, sep = ",", row.names = FALSE, col.names = FALSE),
      error = function(e) NULL
    ))
  } else {
    write.csv(row, f, row.names = FALSE)
  }
}


# ============================================================================
# final_summary — Cross-checkpoint comparison table
# ============================================================================
# INPUT:
#   snapshots — named list of snapshots, e.g. list(A = sA, B = sB, ..., E = sE)
# OUTPUT:
#   Prints a comparison table showing how counts changed from the first
#   checkpoint to the last.
# ============================================================================
final_summary <- function(snapshots) {
  ids <- names(snapshots)
  if (length(ids) < 2) {
    cat("\n  Not enough checkpoints for final summary\n")
    return(invisible(NULL))
  }

  # Find first checkpoint with real data_category (skip early steps that haven't classified yet)
  first_id <- ids[1]
  for (id in ids) {
    if (!is.null(snapshots[[id]]$n_clean) && !is.na(snapshots[[id]]$n_clean) && snapshots[[id]]$n_clean > 0) {
      first_id <- id
      break
    }
  }
  first <- snapshots[[first_id]]
  last  <- snapshots[[ids[length(ids)]]]

  cat(sprintf("\n%s\n", SEP))
  cat(sprintf("  FINAL CORRECTION STATUS  (run %s)\n", format(Sys.time(), "%Y%m%d_%H%M")))
  cat(sprintf("%s\n", SEP))

  rows <- data.frame(
    Metric = c("Total", "Clean", "Error", "Unusual", "Equal Time", "Corrected"),
    stringsAsFactors = FALSE
  )

  rows$first_val <- c(first$n_total %||% "-",
                       first$n_clean %||% "-",
                       first$n_error %||% "-",
                       first$n_unusual %||% "-",
                       first$n_equal_time %||% "-",
                       first$n_corrected %||% "-")

  rows$last_val <- c(last$n_total %||% "-",
                      last$n_clean %||% "-",
                      last$n_error %||% "-",
                      last$n_unusual %||% "-",
                      last$n_equal_time %||% "-",
                      last$n_corrected %||% "-")

  for (i in seq_len(nrow(rows))) {
    f <- suppressWarnings(as.numeric(rows$first_val[i]))
    l <- suppressWarnings(as.numeric(rows$last_val[i]))
    if (!is.na(f) && !is.na(l)) {
      d <- l - f
      rows$delta[i] <- if (d >= 0) sprintf("+%d", d) else as.character(d)
    } else {
      rows$delta[i] <- "-"
    }
  }

  rows$first_val[is.na(rows$first_val)] <- "-"
  rows$last_val[is.na(rows$last_val)]   <- "-"

  # Print aligned table
  cat(sprintf("  %-16s %12s %12s %10s\n", "", paste0(first$checkpoint, " (", first$label, ")"), paste0(last$checkpoint, " (", last$label, ")"), "\u0394"))
  cat(sprintf("  %s\n", paste(rep("\u2500", 54), collapse = "")))
  for (i in seq_len(nrow(rows))) {
    cat(sprintf("  %-16s %12s %12s %10s\n",
                rows$Metric[i], rows$first_val[i], rows$last_val[i], rows$delta[i]))
  }
  cat(sprintf("  %s\n", paste(rep("\u2500", 54), collapse = "")))

  # Extra stats
  if (!is.null(last$n_valid) && !is.na(last$n_valid) && last$n_valid > 0) {
    cat(sprintf("  Mean TST:  %.2f h  Mean SOL:  %.1f min\n",
                last$tst_mean / 60, last$sol_mean))
  }
  if (!is.null(last$extra) && length(last$extra) > 0) {
    extra_str <- paste(names(last$extra), unlist(last$extra), sep = ": ", collapse = "  ")
    cat(sprintf("  %s\n", extra_str))
  }
  cat(sprintf("%s\n\n", SEP))

  # Write final row to CSV
  write_final_csv(first, last)
}


# ============================================================================
# write_final_csv — One-row summary of first-to-last
# ============================================================================
write_final_csv <- function(first, last, dir = "output") {
  if (!dir.exists(dir)) dir.create(dir, showWarnings = FALSE)
  run_id <- format(Sys.time(), "%Y%m%d_%H%M")
  f <- file.path(dir, "correction_status_final.csv")

  safe_diff <- function(a, b) {
    if (is.null(a) || is.null(b) || is.na(a) || is.na(b)) return(NA_integer_)
    as.integer(b) - as.integer(a)
  }

  extra_flags <- if (!is.null(last$extra)) last$extra else list()

  row <- data.frame(
    run_id            = run_id,
    timestamp         = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    checkpoint_first  = first$checkpoint %||% NA_character_,
    checkpoint_last   = last$checkpoint %||% NA_character_,
    n_total           = last$n_total %||% NA_integer_,
    n_clean_first     = first$n_clean %||% NA_integer_,
    n_clean_last      = last$n_clean %||% NA_integer_,
    delta_clean       = safe_diff(first$n_clean, last$n_clean),
    n_error_first     = first$n_error %||% NA_integer_,
    n_error_last      = last$n_error %||% NA_integer_,
    delta_error       = safe_diff(first$n_error, last$n_error),
    n_corrected       = last$n_corrected %||% NA_integer_,
    timestamp_issue   = extra_flags$TIMESTAMP_ISSUE %||% NA_integer_,
    duration_issue    = extra_flags$DURATION_ISSUE %||% NA_integer_,
    amount_flag       = extra_flags$AMOUNT_FLAG %||% NA_integer_,
    self_reported_flag = extra_flags$SELF_REPORTED_FLAG %||% NA_integer_,
    tst_mean_h        = if (!is.null(last$tst_mean) && !is.na(last$tst_mean)) round(last$tst_mean / 60, 2) else NA_real_,
    sol_mean_min      = if (!is.null(last$sol_mean) && !is.na(last$sol_mean)) round(last$sol_mean, 1) else NA_real_,
    stringsAsFactors = FALSE
  )

  if (file.exists(f)) {
    suppressWarnings(tryCatch(
      write.table(row, f, append = TRUE, sep = ",", row.names = FALSE, col.names = FALSE),
      error = function(e) NULL
    ))
  } else {
    write.csv(row, f, row.names = FALSE)
  }
}


# ============================================================================
# `%||%` helper (from purrr, redefined here to avoid dependency)
# ============================================================================
`%||%` <- function(x, y) if (is.null(x)) y else x

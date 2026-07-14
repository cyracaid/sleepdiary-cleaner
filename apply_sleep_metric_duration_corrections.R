# ============================================================================
# SLEEP METRIC DURATION MANUAL CORRECTION APPLICATOR
# ============================================================================
# Reads manual_sleep_metric_duration_corrections.csv and applies targeted
# duration corrections used by Step 7 sleep metric calculations.
#
# This is separate from Step 6 timestamp corrections because these rows have
# valid bed/sleep/awake/getup timestamps. The problem is a duration input
# (usually SOL estimate, occasionally WASO estimate) that was parsed as an
# implausible number of minutes and then made TST/SE impossible.
# ============================================================================

apply_sleep_metric_duration_corrections <- function(data) {

  cat("\n=== Applying sleep metric duration corrections ===\n")

  corr_file <- "manual_sleep_metric_duration_corrections.csv"
  if (!file.exists(corr_file)) {
    cat(sprintf("  No corrections file found (%s) - skipping\n", corr_file))
    return(data)
  }

  corr <- read.csv(corr_file, stringsAsFactors = FALSE)
  cat(sprintf("  Read %d correction records from %s\n", nrow(corr), corr_file))

  applied_count <- 0
  skipped_count <- 0

  for (i in seq_len(nrow(corr))) {
    r <- corr[i, ]

    if (!isTRUE(r$manually_corrected)) {
      skipped_count <- skipped_count + 1
      next
    }

    pid_val <- r$pid
    day_val <- r$day_num
    row_val <- r$row_id
    var_name <- r$variable
    correct_min <- as.numeric(r$corrected_mincalc)

    min_col <- paste0(var_name, "_mincalc")
    err_col <- paste0(var_name, "_checkforerrors")
    audit_col <- paste0(var_name, "_correctionsmade")

    if (!(min_col %in% names(data)) || is.na(correct_min)) {
      cat(sprintf("  Skipping correction row: pid=%s day=%s variable=%s\n",
                  pid_val, day_val, var_name))
      skipped_count <- skipped_count + 1
      next
    }

    idx <- which(data$pid == pid_val & data$day_num == day_val & data$row_id == row_val)
    if (length(idx) != 1) {
      cat(sprintf("  No unique match: pid=%s day=%s row_id=%s - skipped\n",
                  pid_val, day_val, row_val))
      skipped_count <- skipped_count + 1
      next
    }

    before_min <- data[[min_col]][idx]

    # The interval parser now handles the recurring SOL/WASO MM:SS tail case
    # directly (e.g., 10:30 -> 10.5 minutes). Do not let older manual rows that
    # used objective SOL as a workaround overwrite the parser-derived value.
    existing_audit <- if (audit_col %in% names(data)) data[[audit_col]][idx] else NA_character_
    if (!is.na(existing_audit) &&
        grepl("sleep metric duration MM:SS threshold conversion", existing_audit, fixed = TRUE)) {
      if (err_col %in% names(data)) {
        data[[err_col]][idx] <- FALSE
      }
      cat(sprintf("  Parser already converted pid=%s day=%s row_id=%s %s via MM:SS threshold - skipped manual override\n",
                  pid_val, day_val, row_val, var_name))
      skipped_count <- skipped_count + 1
      next
    }

    data[[min_col]][idx] <- correct_min

    if (err_col %in% names(data)) {
      data[[err_col]][idx] <- NA
    }

    if (audit_col %in% names(data)) {
      existing <- data[[audit_col]][idx]
      new_note <- sprintf(
        "Manual metric-duration fix: %s; %s; parsed %.1f min -> %.1f min",
        r$problem_humanidentified,
        r$solution_humanidentified,
        as.numeric(before_min),
        correct_min
      )
      data[[audit_col]][idx] <- if (is.na(existing) || existing == "") {
        new_note
      } else {
        paste(existing, new_note, sep = "; ")
      }
    }

    if ("manually_corrected" %in% names(data)) {
      data$manually_corrected[idx] <- TRUE
    }

    if ("problem_description" %in% names(data)) {
      existing_problem <- data$problem_description[idx]
      data$problem_description[idx] <- if (is.na(existing_problem) || existing_problem == "") {
        r$problem_humanidentified
      } else {
        paste(existing_problem, r$problem_humanidentified, sep = "; ")
      }
    }

    cat(sprintf("  Applied pid=%s day=%s row_id=%s %s: %.1f -> %.1f min\n",
                pid_val, day_val, row_val, var_name, as.numeric(before_min), correct_min))
    applied_count <- applied_count + 1
  }

  cat(sprintf("  Sleep metric duration corrections applied: %d\n", applied_count))
  cat(sprintf("  Correction rows skipped: %d\n", skipped_count))
  return(data)
}

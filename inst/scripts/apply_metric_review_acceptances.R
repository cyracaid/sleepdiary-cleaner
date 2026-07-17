# ============================================================================
# HUMAN-ACCEPTED METRIC REVIEW APPLICATOR
# ============================================================================
# Reads manual_metric_review_acceptances.csv and records rows that a human has
# reviewed and accepted as not errors. This does not modify raw timestamps,
# corrected timestamps, or duration values. It only carries the review decision
# forward so Step 8 can suppress repeated checkforerrors warnings.
# ============================================================================

apply_metric_review_acceptances <- function(data) {

  cat("\n=== Applying human metric review acceptances ===\n")

  accept_file <- cfg_get("data.files.manual_metric_accept", "manual_metric_review_acceptances.csv")
  if (!file.exists(accept_file)) {
    cat(sprintf("  No acceptances file found (%s) - skipping\n", accept_file))
    return(data)
  }

  accept <- read.csv(accept_file, stringsAsFactors = FALSE)
  required_cols <- c("pid", "day_num", "row_id", "human_metric_review_status")
  if (!all(required_cols %in% names(accept))) {
    cat("  Acceptances file missing required columns - skipped\n")
    return(data)
  }

  if (!"human_metric_review_status" %in% names(data)) {
    data$human_metric_review_status <- NA_character_
  }
  if (!"human_metric_review_note" %in% names(data)) {
    data$human_metric_review_note <- NA_character_
  }

  applied_count <- 0
  skipped_count <- 0

  for (i in seq_len(nrow(accept))) {
    rec <- accept[i, ]
    idx <- which(data$pid == rec$pid & data$day_num == rec$day_num & data$row_id == rec$row_id)
    if (length(idx) != 1) {
      skipped_count <- skipped_count + 1
      next
    }

    data$human_metric_review_status[idx] <- rec$human_metric_review_status
    data$human_metric_review_note[idx] <- if ("human_metric_review_note" %in% names(accept)) {
      rec$human_metric_review_note
    } else {
      "Human reviewed metric warning and accepted row as reasonable."
    }
    applied_count <- applied_count + 1
  }

  cat(sprintf("  Human metric review acceptances applied: %d\n", applied_count))
  cat(sprintf("  Acceptance rows skipped: %d\n", skipped_count))
  return(data)
}

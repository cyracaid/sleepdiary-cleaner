# audit_review_propagation.R
# Cross-references historical review CSVs against pipeline-input CSVs
# to detect human decisions that haven't been propagated.
# Usage: Rscript audit_review_propagation.R

review_files <- c(
  "remaining_22_3agent_review.csv",
  "remaining_pipeline_cleanup_review.csv",
  "metrics_ai_review.csv",
  "review_sol_excessive_44_classified.csv",
  "review_remaining_46_classified.csv",
  "review_sol_interval_flags.csv",
  "review_metrics_likely_real_issue.csv"
)

pipeline_input_files <- c(
  "manual_error_corrections.csv",
  "manual_nap_exercise_corrections.csv",
  "manual_sleep_metric_duration_corrections.csv",
  "manual_metric_review_acceptances.csv"
)

decision_cols <- c("final_recommendation", "final_decision", "human_decision",
                   "integration_completed", "decision")

search_dirs <- c(".", "archive_intermediate_review_csvs")

cat("=== Audit Report: Review Decision Propagation ===\n")
cat(sprintf("Date: %s\n\n", Sys.Date()))

pipeline_keys <- character()
pipeline_summaries <- character()

for (f in pipeline_input_files) {
  if (!file.exists(f)) {
    pipeline_summaries <- c(pipeline_summaries, sprintf("  %s: file not found", f))
    next
  }
  d <- read.csv(f, stringsAsFactors = FALSE)
  if (all(c("pid", "day_num", "row_id") %in% names(d))) {
    keys <- paste(d$pid, d$day_num, d$row_id)
    pipeline_keys <- c(pipeline_keys, keys)
    pipeline_summaries <- c(pipeline_summaries, sprintf("  %s: %d rows", f, nrow(d)))
  } else {
    pipeline_summaries <- c(pipeline_summaries, sprintf("  %s: %d rows (missing pid/day_num/row_id)", f, nrow(d)))
  }
}

cat("Pipeline-input CSVs found:\n")
for (s in pipeline_summaries) cat(s, "\n")
cat("\n")

review_summaries <- character()
missing_list <- list()

for (f in review_files) {
  found <- FALSE
  for (dir in search_dirs) {
    path <- file.path(dir, f)
    if (file.exists(path)) {
      found <- TRUE
      d <- read.csv(path, stringsAsFactors = FALSE)
      if (all(c("pid", "day_num", "row_id") %in% names(d))) {
        # Find which column has the decision
        dc <- intersect(decision_cols, names(d))
        has_decision <- rep(FALSE, nrow(d))
        for (col in dc) {
          has_decision <- has_decision | (!is.na(d[[col]]) & d[[col]] != "")
        }
        n_decision <- sum(has_decision)
        n_total <- nrow(d)

        review_summaries <- c(review_summaries,
          sprintf("  %s (%s): %d rows, %d with decisions", f, dir, n_total, n_decision))

        # Find missing propagations
        if (n_decision > 0) {
          for (i in which(has_decision)) {
            key <- paste(d$pid[i], d$day_num[i], d$row_id[i])
            if (!key %in% pipeline_keys) {
              # Gather decision text
              decision_text <- ""
              for (col in dc) {
                if (!is.na(d[[col]][i]) && d[[col]][i] != "") {
                  decision_text <- paste0(decision_text, col, "=", d[[col]][i], "; ")
                }
              }
              missing_list[[length(missing_list) + 1]] <- sprintf(
                "  PID=%-5d Day=%-3d Row=%-6d %s (file: %s)",
                d$pid[i], d$day_num[i], d$row_id[i], decision_text, f
              )
            }
          }
        }
      } else {
        review_summaries <- c(review_summaries,
          sprintf("  %s (%s): %d rows (missing pid/day_num/row_id)", f, dir, nrow(d)))
      }
      break
    }
  }
  if (!found) {
    review_summaries <- c(review_summaries, sprintf("  %s: not found", f))
  }
}

cat("Review CSVs examined:\n")
for (s in review_summaries) cat(s, "\n")
cat("\n")

if (length(missing_list) > 0) {
  cat("=== MISSING PROPAGATIONS ===\n")
  cat(sprintf("Found %d rows with human decisions NOT in any pipeline-input CSV:\n\n", length(missing_list)))
  for (m in missing_list) cat(m, "\n")
  cat("\nAction needed: Add these rows to the appropriate pipeline-input CSV.\n")
  quit(save = "no", status = 1)
} else {
  cat("=== ALL CLEAN ===\n")
  cat("All reviewed rows with human decisions are accounted for in pipeline inputs.\n")
  quit(save = "no", status = 0)
}

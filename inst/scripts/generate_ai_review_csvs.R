library(dplyr)
library(readr)

# Suggested labels come from the user's rules (review.suggestions in the config),
# never from rules written here. They are recomputed on every run so that a rule
# change always takes effect; only the human columns are carried over from the
# previous file. A suggestion is not a decision: a row stays open until
# human_decision is filled in.
.ai_review_rules <- function() {
  cfg <- if (exists("pipeline_config", inherits = TRUE)) get("pipeline_config", inherits = TRUE) else NULL
  sleepcleanr::review_rules(cfg)
}

restore_prior_review_fields <- function(df, old_path, rules = .ai_review_rules()) {
  human_cols <- c("human_decision", "corrected_value", "notes")
  df <- df %>% select(-any_of(c("ai_label", "ai_reason", "ai_rule", human_cols)))
  df <- sleepcleanr::suggest_review_labels(df, rules)
  if (file.exists(old_path)) {
    old <- suppressMessages(readr::read_csv(old_path, show_col_types = FALSE,
                                            col_types = readr::cols(.default = "c")))
    old_review <- old %>%
      select(any_of(c("pid", "day_num", "row_id", human_cols))) %>%
      distinct(pid, day_num, row_id, .keep_all = TRUE) %>%
      mutate(pid = as.character(pid), day_num = as.character(day_num), row_id = as.character(row_id))
    df <- df %>%
      mutate(.k_pid = as.character(pid), .k_day = as.character(day_num), .k_row = as.character(row_id)) %>%
      left_join(old_review, by = c(.k_pid = "pid", .k_day = "day_num", .k_row = "row_id")) %>%
      select(-.k_pid, -.k_day, -.k_row)
  }
  for (col in human_cols) {
    if (!col %in% names(df)) df[[col]] <- ""
    df[[col]] <- ifelse(is.na(df[[col]]), "", as.character(df[[col]]))
  }
  df
}

write_ai_review_csvs <- function(review_df = review_output$checkforerrors_df) {
  metrics_df <- review_df %>%
    filter(grepl("\\[Metrics\\]", auto_error_desc))

  metrics_only <- metrics_df %>%
    filter(!grepl("\\[Temporal\\]", auto_error_desc)) %>%
    restore_prior_review_fields("metrics_ai_review.csv")

  metrics_temporal_overlap <- metrics_df %>%
    filter(grepl("\\[Temporal\\]", auto_error_desc)) %>%
    restore_prior_review_fields("metrics_temporal_overlap_ai_review.csv")

  write.csv(metrics_only, "metrics_ai_review.csv", row.names = FALSE, na = "")
  write.csv(metrics_temporal_overlap, "metrics_temporal_overlap_ai_review.csv", row.names = FALSE, na = "")

  cat(sprintf("Wrote metrics_ai_review.csv: %d rows\n", nrow(metrics_only)))
  cat(sprintf("Wrote metrics_temporal_overlap_ai_review.csv: %d rows\n", nrow(metrics_temporal_overlap)))
  invisible(list(metrics_only = metrics_only, metrics_temporal_overlap = metrics_temporal_overlap))
}

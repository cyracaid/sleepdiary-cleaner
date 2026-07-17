library(dplyr)
library(readr)

label_metrics_issue <- function(auto_error_desc, sol_category, se_category, tst_tib_ratio_category) {
  impossible <- grepl("SE:negative|TST/TIB:exceeds_1|SOL:negative", auto_error_desc)
  long_sol_only <- sol_category == "excessive" &
    se_category == "valid" &
    tst_tib_ratio_category %in% c("normal", "normal_low")

  dplyr::case_when(
    impossible ~ "likely_real_issue",
    long_sol_only ~ "likely_false_positive",
    TRUE ~ "needs_human"
  )
}

reason_metrics_issue <- function(ai_label) {
  dplyr::case_when(
    ai_label == "likely_real_issue" ~
      "Mathematically impossible sleep metric (negative SE, TST/TIB > 1, or negative SOL); likely needs timestamp or WASO/TST review.",
    ai_label == "likely_false_positive" ~
      "SOL exceeds 120 min, but other sleep metrics are internally plausible; likely real long sleep latency rather than input error.",
    TRUE ~
      "Metric flag needs human review because the values are unusual but not automatically classifiable from available fields."
  )
}

restore_prior_review_fields <- function(df, old_path) {
  review_cols <- c("ai_label", "ai_reason", "human_decision", "corrected_value", "notes")
  if (!file.exists(old_path)) {
    df$ai_label <- label_metrics_issue(df$auto_error_desc, df$sol_category, df$se_category, df$tst_tib_ratio_category)
    df$ai_reason <- reason_metrics_issue(df$ai_label)
    df$human_decision <- ""
    df$corrected_value <- ""
    df$notes <- ""
    return(df)
  }

  old <- suppressMessages(readr::read_csv(old_path, show_col_types = FALSE))
  old_review <- old %>%
    select(any_of(c("pid", "day_num", "row_id", review_cols))) %>%
    distinct(pid, day_num, row_id, .keep_all = TRUE)

  df <- df %>%
    select(-any_of(review_cols)) %>%
    left_join(old_review, by = c("pid", "day_num", "row_id"))

  if (!"ai_label" %in% names(df) || all(is.na(df$ai_label))) {
    df$ai_label <- label_metrics_issue(df$auto_error_desc, df$sol_category, df$se_category, df$tst_tib_ratio_category)
  }
  df$ai_reason <- ifelse(is.na(df$ai_reason) | df$ai_reason == "", reason_metrics_issue(df$ai_label), df$ai_reason)
  df$human_decision <- ifelse(is.na(df$human_decision), "", df$human_decision)
  df$corrected_value <- ifelse(is.na(df$corrected_value), "", df$corrected_value)
  df$notes <- ifelse(is.na(df$notes), "", df$notes)
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

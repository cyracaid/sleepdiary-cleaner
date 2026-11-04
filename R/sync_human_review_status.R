#' Sync Human Review Status
#' @description Read manual_metric_review_acceptances.csv and auto-sync review_resolution / resolved_at / resolved_by based on human review traces
#' @param csv_path Path to CSV file
#' @param overwrite Whether to overwrite existing fields (default TRUE)
#' @return Updated data.frame (returned invisibly)
#' @export
#' @importFrom readr read_csv write_csv
#' @importFrom dplyr rowwise mutate ungroup case_when
#' @importFrom utils globalVariables
#' @name sync_human_review_status
NULL
utils::globalVariables(c(
  "human_metric_review_note", "resolved_at", "resolved_by",
  "review_resolution", "has_human_trace"
))
sync_human_review_status <- function(csv_path = "manual_metric_review_acceptances.csv",
                                     overwrite = TRUE) {
  df <- readr::read_csv(csv_path, show_col_types = FALSE)
  
  # Ensure required columns exist
  if (!"human_metric_review_note" %in% names(df)) {
    warning("Missing human_metric_review_note column, skipping sync")
    return(invisible(NULL))
  }
  
  # read_csv() guesses types, so an ISO date column arrives as <date> while the
  # values written below are <character>; case_when() refuses to mix the two.
  # Keep the three synced columns as text.
  for (col in c("review_resolution", "resolved_at", "resolved_by")) {
    if (col %in% names(df)) df[[col]] <- as.character(df[[col]])
  }
  
  # Compute new fields
  result <- df %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      # Whether human review traces exist
      has_human_trace = any(
        !is.na(human_metric_review_note) & human_metric_review_note != "",
        !is.na(resolved_at) & resolved_at != "",
        !is.na(resolved_by) && resolved_by != ""
      ),
      
      # Compute review_resolution
      review_resolution = dplyr::case_when(
        # If resolution exists and is not legacy, keep original (assume human confirmed)
        !is.na(review_resolution) & review_resolution != "legacy" ~ review_resolution,
        # Has traces but resolution is legacy/NA -> mark flagged_unresolved (pending human)
        has_human_trace & (is.na(review_resolution) | review_resolution == "legacy") ~ "flagged_unresolved",
        # No traces and is legacy -> keep legacy
        TRUE ~ "legacy"
      ),
      
      # resolved_at: fill a blank only. A date a person already entered is
      # evidence; replacing it with today loses when the review actually
      # happened, and blanking it on non-corrected rows loses it entirely.
      resolved_at = dplyr::case_when(
        !is.na(resolved_at) & resolved_at != "" ~ resolved_at,
        review_resolution == "corrected" ~ format(Sys.Date(), "%Y-%m-%d"),
        TRUE ~ NA_character_
      ),
      
      # resolved_by: same rule, except "pending" is this function's own
      # placeholder and is refreshed, so a row resolved later stops saying
      # pending.
      resolved_by = dplyr::case_when(
        !is.na(resolved_by) & !resolved_by %in% c("", "pending") ~ resolved_by,
        review_resolution == "corrected" ~ "system",
        review_resolution == "legacy" ~ "legacy",
        # Has traces but not marked resolved -> pending
        TRUE ~ "pending"
      )
    ) %>%
    dplyr::ungroup()
  
  # Write back to CSV
  if (overwrite) {
    readr::write_csv(result, csv_path)
    cat(sprintf("[INFO] Synced %d rows: %d corrected, %d flagged, %d legacy\n",
                nrow(result),
                sum(result$review_resolution == "corrected"),
                sum(result$review_resolution == "flagged_unresolved"),
                sum(result$review_resolution == "legacy", na.rm = TRUE)))
  }
  
  invisible(result)
}

# ============================================================================
# apply_second_review.R — Step 5.75
# ============================================================================
# DESIGN NOTES:
#   3-route routing via second_review_checklist$target_csv.
#   Anti-join on (pid, day_num, row_id) for idempotency — re-runs
#   never duplicate rows.
#
#   For target_csv = "manual_error_corrections" and
#   "manual_nap_exercise_corrections", this script DOES NOT TOUCH the
#   CSV.  Instead it prints a verification message so the operator can
#   confirm the correction was already hand-entered in the CSV.
#
#   "manual_metric_review_acceptances" is the only CSV this script
#   actually appends to.
#
#   This step is between Step 5 and Step 6 so that corrections
#   whose target_csv = "manual_error_corrections" take effect in the
#   same pipeline run.
# ============================================================================

append_with_antijoin <- function(existing_file, new_rows, join_cols = c("pid", "day_num", "row_id")) {
  if (!file.exists(existing_file) || nrow(read.csv(existing_file, nrows = 1)) == 0) {
    existing <- data.frame()
  } else {
    existing <- read.csv(existing_file, stringsAsFactors = FALSE)
  }

  if (nrow(existing) == 0) {
    write.csv(new_rows, existing_file, row.names = FALSE)
    return(invisible(nrow(new_rows)))
  }

  merged <- dplyr::anti_join(new_rows, existing, by = join_cols)
  if (nrow(merged) == 0) {
    cat("  (no new rows to append — all already present)\n")
    return(invisible(0L))
  }

  combined <- dplyr::bind_rows(existing, merged)
  write.csv(combined, existing_file, row.names = FALSE)
  cat(sprintf("  Appended %d row(s) to %s\n", nrow(merged), basename(existing_file)))
  invisible(nrow(merged))
}


apply_second_review <- function(checklist_path = cfg_get("data.files.second_review", "second_review_checklist.csv")) {

  if (!file.exists(checklist_path)) {
    cat("  ⚠", checklist_path, "not found — skipping second-review\n")
    return(invisible(NULL))
  }
  checklist <- read.csv(checklist_path, stringsAsFactors = FALSE)

  stopifnot("target_csv" %in% names(checklist))
  accepted_routes <- c("manual_metric_review_acceptances",
                       "manual_error_corrections",
                       "manual_nap_exercise_corrections")
  unknown <- setdiff(unique(checklist$target_csv), accepted_routes)
  if (length(unknown)) {
    stop("Unknown target_csv value(s) in checklist: ", paste(unknown, collapse = ", "))
  }

  # ── Route A: manual_metric_review_acceptances ──
  route_a <- checklist[checklist$target_csv == "manual_metric_review_acceptances", ]
  if (nrow(route_a) > 0) {
    accept_rows <- data.frame(
      pid = route_a$pid,
      day_num = route_a$day_num,
      row_id = route_a$row_id,
      reason = route_a$decision_type,
      source = "second_review",
      date_added = as.character(Sys.Date()),
      stringsAsFactors = FALSE
    )
    append_with_antijoin("manual_metric_review_acceptances.csv", accept_rows)
  }

  # ── Route B: manual_error_corrections (verify only) ──
  route_b <- checklist[checklist$target_csv == "manual_error_corrections", ]
  if (nrow(route_b) > 0) {
    cat(sprintf("  [VERIFY] %d row(s) should already exist in manual_error_corrections.csv:\n", nrow(route_b)))
    for (i in seq_len(nrow(route_b))) {
      cat(sprintf("    pid=%s day=%s row=%s\n", route_b$pid[i], route_b$day_num[i], route_b$row_id[i]))
    }
  }

  # ── Route C: manual_nap_exercise_corrections (verify only) ──
  route_c <- checklist[checklist$target_csv == "manual_nap_exercise_corrections", ]
  if (nrow(route_c) > 0) {
    cat(sprintf("  [VERIFY] %d row(s) should already exist in manual_nap_exercise_corrections.csv:\n", nrow(route_c)))
    for (i in seq_len(nrow(route_c))) {
      cat(sprintf("    pid=%s day=%s row=%s\n", route_c$pid[i], route_c$day_num[i], route_c$row_id[i]))
    }
  }
}

apply_second_review()

#!/usr/bin/env Rscript
# =============================================================================
# cross_participant_global_check.R — Step 8.5: Cross-participant consistency
# =============================================================================
# PURPOSE:
#   After Step 8's per-row auto-detection, this step looks at each
#   participant's data ACROSS all their days. It identifies patterns
#   that are invisible when checking rows one by one.
#
# THE PROBLEM IT SOLVES:
#   Existing checks are entirely row-local or use global thresholds.
#   Example: pid 6259 normally reports SOL=5-30min across 12 days,
#   but on day 4 their subjective SOL is 400min. Looking only at
#   day 4 in isolation, 400min triggers SOL:excessive. But looking
#   at ALL their days shows the pattern: they always have short SOL
#   → day 4's 400 is almost certainly a data-entry format issue or
#   a genuine behavioral outlier worth flagging for review.
#
# METHOD:
#   For each participant with >=3 days of data, we compute their
#   personal baseline (median) and spread (MAD = Median Absolute
#   Deviation). We then flag any day whose SOL or WASO deviates
#   dramatically from their own norm.
#
# THREE TIERS:
#   Tier 1 - single_day_spike:  SOL/WASO >> personal baseline
#   Tier 2 - consistent_pattern: participant always has high SOL
#   Tier 3 - insufficient_data: <3 days, use global fallback
#
# OUTPUT (written to disk):
#   cross_participant_flagged_rows.csv      — flagged rows with CP context
#   cross_participant_suspicious_slices.csv — ALL rows of flagged PIDs
#
# INTEGRATION:
#   - Reads review_output$data_with_flags from Step 8
#   - Respects existing human_metric_review_status (skips accepted rows)
#   - Appends [CrossParticipant] to auto_error_desc where overlap exists
#   - Updates review_output for downstream use by Step 9
# =============================================================================

cat("\n=== Step 8.5: Cross-participant global consistency check ===\n")

# ── Prerequisites ────────────────────────────────────────────────────────────
required_objects <- c("corrected_ema_data", "review_output")
for (obj in required_objects) {
  if (!exists(obj)) {
    stop(sprintf("Error: %s not found. Run steps 1-8 first.", obj))
  }
}

data <- review_output$data_with_flags
n_total <- nrow(data)
cat(sprintf("  Input: %d rows from review_output$data_with_flags\n", n_total))

# ── Skip already-accepted rows ──────────────────────────────────────────────
if ("human_metric_review_status" %in% names(data)) {
  accepted <- !is.na(data$human_metric_review_status) &
    data$human_metric_review_status == "confirmed_not_error_do_not_correct"
  cat(sprintf("  Excluding %d already-accepted rows\n", sum(accepted, na.rm = TRUE)))
} else {
  accepted <- rep(FALSE, nrow(data))
}

# ── Metrics to check ────────────────────────────────────────────────────────
# Using trust-gated values where available
metrics_to_check <- list(
  # Subjective_SOL is the primary SOL metric.
  # Objective SOL (self_diffcalc_sol_minutes) is included in output columns
  # for side-by-side comparison but is NOT independently flagged.
  subjective_sol = list(
    col = "duration_totalmin_sol_estimate_am_mincalc_for_review",
    label = "Subjective_SOL",
    min_days = 3,
    min_baseline_for_spike = 5,
    spike_multiplier = 4,
    spike_abs_threshold = 120,
    low_baseline_override = list(
      median_lt = 30,
      value_gt = 240,
      label_extra = "low_baseline_extreme"
    )
  ),
  waso = list(
    col = "duration_totalmin_waso_estimate_am_mincalc_used",
    label = "WASO",
    min_days = 3,
    min_baseline_for_spike = 3,
    spike_multiplier = 4,
    spike_abs_threshold = 60,
    low_baseline_override = list(
      median_lt = 15,
      value_gt = 120,
      label_extra = "low_baseline_extreme"
    )
  ),
  nap = list(
    col = "duration_totalmin_napstoday_PM_mincalc",
    label = "Nap",
    min_days = 3,
    min_baseline_for_spike = 5,
    spike_multiplier = 4,
    spike_abs_threshold = 360,           # 6h+ "nap" is definitely an error
    low_baseline_override = list(
      median_lt = 10,
      value_gt = 360,
      label_extra = "low_baseline_extreme"
    )
  ),
  exercise_light = list(
    col = "exercisetoday_PM_totalmin_Light_mincalc",
    label = "Exercise_Light",
    min_days = 3,
    min_baseline_for_spike = 5,
    spike_multiplier = 4,
    spike_abs_threshold = 240,           # 4h+ light exercise is extreme
    low_baseline_override = list(
      median_lt = 15,
      value_gt = 270,
      label_extra = "low_baseline_extreme"
    )
  ),
  exercise_moderate = list(
    col = "exercisetoday_PM_totalmin_Moderate_mincalc",
    label = "Exercise_Moderate",
    min_days = 3,
    min_baseline_for_spike = 5,
    spike_multiplier = 4,
    spike_abs_threshold = 180,           # 3h+ moderate exercise is extreme
    low_baseline_override = list(
      median_lt = 10,
      value_gt = 210,
      label_extra = "low_baseline_extreme"
    )
  ),
  exercise_vigorous = list(
    col = "exercisetoday_PM_totalmin_Vigorous_mincalc",
    label = "Exercise_Vigorous",
    min_days = 3,
    min_baseline_for_spike = 5,
    spike_multiplier = 4,
    spike_abs_threshold = 120,           # 2h+ vigorous is very unusual
    low_baseline_override = list(
      median_lt = 5,
      value_gt = 180,
      label_extra = "low_baseline_extreme"
    )
  ),
  exercise_strength = list(
    col = "exercisetoday_PM_totalmin_Strength_mincalc",
    label = "Exercise_Strength",
    min_days = 3,
    min_baseline_for_spike = 5,
    spike_multiplier = 4,
    spike_abs_threshold = 120,           # 2h+ strength training is extreme
    low_baseline_override = list(
      median_lt = 5,
      value_gt = 150,
      label_extra = "low_baseline_extreme"
    )
  )
)

# Initialize CP flag columns
data$cp_flag_type <- NA_character_
data$cp_deviation_score <- NA_real_
data$cp_pid_median <- NA_real_
data$cp_pid_mad <- NA_real_
data$cp_pid_n_days <- NA_integer_

n_cp_flagged <- 0
all_flagged_rows <- data.frame()
all_suspicious_pids <- c()

# ── Per-metric detection ─────────────────────────────────────────────────────
for (metric_name in names(metrics_to_check)) {
  metric_config <- metrics_to_check[[metric_name]]
  col_name <- metric_config$col
  label <- metric_config$label

  if (!col_name %in% names(data)) {
    cat(sprintf("  Skipping %s: column '%s' not found\n", label, col_name))
    next
  }

  # Filter: non-NA, non-accepted, non-manually-corrected
  ok <- !is.na(data[[col_name]]) & !accepted
  if ("manually_corrected" %in% names(data)) {
    ok <- ok & !data$manually_corrected
  }
  metric_vals <- data[[col_name]][ok]
  n_metric <- length(metric_vals)
  if (n_metric < 2) {
    cat(sprintf("  %s: insufficient data (%d rows), skipping\n", label, n_metric))
    next
  }

  # ── Per-pid baseline ───────────────────────────────────────────────────────
  metric_df <- data[ok, c("pid", "day_num", "row_id", col_name)]
  colnames(metric_df)[4] <- "value"

  baselines <- metric_df %>%
    group_by(pid) %>%
    summarise(
      n_days = n(),
      median_val = median(value, na.rm = TRUE),
      mad_val = max(mad(value, na.rm = TRUE), 1),   # clamp to avoid /0
      iqr_val = IQR(value, na.rm = TRUE),
      .groups = "drop"
    )

  metric_df <- metric_df %>% left_join(baselines, by = "pid")

  # ── Deviation scoring ──────────────────────────────────────────────────────
  metric_df <- metric_df %>%
    mutate(
      deviation = abs(value - median_val) / mad_val,
      fold_change = ifelse(median_val > 0, value / median_val, NA_real_)
    )

  # ── Tier 1: Single-day spike ──────────────────────────────────────────────
  is_spike <- with(metric_df,
    !is.na(deviation) & deviation >= 5 &
    n_days >= metric_config$min_days &
    !is.na(median_val) & median_val >= metric_config$min_baseline_for_spike &
    value >= metric_config$spike_abs_threshold &
    value >= median_val * metric_config$spike_multiplier
  )

  # ── Low-baseline override ─────────────────────────────────────────────────
  low_base <- with(metric_df,
    !is.na(value) & !is.na(median_val) &
    median_val < metric_config$low_baseline_override$median_lt &
    value > metric_config$low_baseline_override$value_gt
  )

  # ── Tier 2: Consistent pattern (exclude from CP) ──────────────────────────
  is_consistent <- metric_df %>%
    group_by(pid) %>%
    summarise(
      n_high = sum(value >= metric_config$spike_abs_threshold, na.rm = TRUE),
      n_total = n(),
      .groups = "drop"
    ) %>%
    mutate(consistent = n_high >= 3 & n_high / n_total >= 0.5)

  metric_df <- metric_df %>% left_join(
    is_consistent %>% select(pid, consistent),
    by = "pid"
  )

  # Flag only: spikes AND not consistent pattern AND not already accepted
  flag_metric <- is_spike & !metric_df$consistent
  flag_metric <- flag_metric | (low_base & !metric_df$consistent)

  n_flag <- sum(flag_metric, na.rm = TRUE)
  if (n_flag == 0) {
    cat(sprintf("  %s: 0 rows flagged\n", label))
    next
  }

  cat(sprintf("  %s: %d rows flagged\n", label, n_flag))

  # Build CP description
  cp_type <- ifelse(
    metric_df$consistent[flag_metric],
    "consistent_pattern",
    ifelse(
      metric_df$n_days[flag_metric] < metric_config$min_days,
      "insufficient_data",
      "single_day_spike"
    )
  )

  # ── Apply flags back to main data ─────────────────────────────────────────
  flagged_indices <- which(ok)[flag_metric]
  for (idx in flagged_indices) {
    # Find the matching metric_df row
    m_idx <- which(metric_df$row_id == data$row_id[idx] &
                    metric_df$pid == data$pid[idx])
    if (length(m_idx) == 0) next
    m_row <- metric_df[m_idx[1], ]

    n_cp_flagged <- n_cp_flagged + 1

    # Store CP metadata
    data$cp_flag_type[idx] <- cp_type[which(flagged_indices == idx)]
    data$cp_pid_median[idx] <- m_row$median_val
    data$cp_pid_mad[idx] <- m_row$mad_val
    data$cp_pid_n_days[idx] <- m_row$n_days
    data$cp_deviation_score[idx] <- m_row$deviation

    # Append to auto_error_desc if already flagged, or create new
    cp_part <- sprintf(
      "[CrossParticipant] %s:%s value=%.0f median=%.0f %.1fx MAD=%.1f",
      label, data$cp_flag_type[idx],
      m_row$value, m_row$median_val,
      m_row$fold_change, m_row$deviation
    )

    existing_desc <- data$auto_error_desc[idx]
    if (is.na(existing_desc) || existing_desc == "") {
      data$auto_error_desc[idx] <- cp_part
      data$needs_review_flag[idx] <- TRUE
    } else {
      # Already flagged by Step 8 — append CP info
      data$auto_error_desc[idx] <- paste(existing_desc, cp_part, sep = "; ")
    }
  }

  # Track suspicious PIDs (those with at least one flagged row)
  suspicious_pids <- unique(data$pid[flagged_indices])
  all_suspicious_pids <- union(all_suspicious_pids, suspicious_pids)
}

# ── Build flagged rows output ───────────────────────────────────────────────
flagged_idx <- which(!is.na(data$cp_flag_type))

if (length(flagged_idx) > 0) {
  # Columns for the flagged rows CSV
  cp_keep_cols <- intersect(c(
    "pid", "day_num", "row_id",
    "time_bed_am_hhmm_ampm", "time_sleep_am_hhmm_ampm",
    "time_awake_am_hhmm_ampm", "time_getup_am_hhmm_ampm",
    "self_diffcalc_sol_minutes",
    "duration_totalmin_sol_estimate_am_mincalc",
    "duration_totalmin_sol_estimate_am_mincalc_for_review",
    "duration_totalmin_waso_estimate_am_mincalc",
    "duration_totalmin_waso_estimate_am_mincalc_used",
    "duration_totalmin_napstoday_PM_mincalc",
    "exercisetoday_PM_totalmin_Light_mincalc",
    "exercisetoday_PM_totalmin_Moderate_mincalc",
    "exercisetoday_PM_totalmin_Vigorous_mincalc",
    "exercisetoday_PM_totalmin_Strength_mincalc",
    "self_diffcalc_totalsleeptime_minutes",
    "self_diffcalc_timeinbed_minutes",
    "self_diffcalc_sleepefficiency_percent",
    "auto_error_desc",
    "cp_flag_type", "cp_deviation_score",
    "cp_pid_median", "cp_pid_mad", "cp_pid_n_days",
    "needs_review_flag",
    "human_metric_review_status"
  ), names(data))

  extra_cols <- intersect(c(
    "sol_category", "se_category", "tst_tib_ratio_category",
    "metric_duration_input_category", "waso_duration_for_metrics_status",
    "sol_duration_for_review_status"
  ), names(data))

  cp_flagged <- data[flagged_idx, unique(c(cp_keep_cols, extra_cols))]
  write.csv(cp_flagged, "cross_participant_flagged_rows.csv", row.names = FALSE)
  cat(sprintf("  Wrote cross_participant_flagged_rows.csv (%d rows)\n", nrow(cp_flagged)))

  # ── Build suspicious slices (ALL rows for flagged PIDs) ───────────────────
  slices_cols <- intersect(c(
    "pid", "day_num", "row_id",
    "self_diffcalc_sol_minutes",
    "duration_totalmin_sol_estimate_am_mincalc",
    "duration_totalmin_sol_estimate_am_mincalc_for_review",
    "duration_totalmin_waso_estimate_am_mincalc",
    "duration_totalmin_waso_estimate_am_mincalc_used",
    "duration_totalmin_napstoday_PM_mincalc",
    "exercisetoday_PM_totalmin_Light_mincalc",
    "exercisetoday_PM_totalmin_Moderate_mincalc",
    "exercisetoday_PM_totalmin_Vigorous_mincalc",
    "exercisetoday_PM_totalmin_Strength_mincalc",
    "self_diffcalc_totalsleeptime_minutes",
    "self_diffcalc_timeinbed_minutes",
    "self_diffcalc_sleepefficiency_percent",
    "self_diffcalc_sleepperiod_minutes",
    "avg_waso_estimate_am_minutes",
    "auto_error_desc",
    "cp_flag_type", "cp_deviation_score", "cp_pid_median",
    "cp_pid_mad", "cp_pid_n_days",
    "needs_review_flag",
    "human_metric_review_status",
    "manually_corrected",
    "data_category"
  ), names(data))

  slices <- data[data$pid %in% all_suspicious_pids, ]
  slices <- slices[order(slices$pid, slices$day_num), ]
  slices <- slices[, unique(c(slices_cols, extra_cols))]

  write.csv(slices, "cross_participant_suspicious_slices.csv", row.names = FALSE)
  cat(sprintf("  Wrote cross_participant_suspicious_slices.csv (%d rows across %d PIDs)\n",
              nrow(slices), length(all_suspicious_pids)))
} else {
  cat("  No cross-participant flags detected\n")
  # Write empty CSVs for downstream tooling
  write.csv(data.frame(), "cross_participant_flagged_rows.csv", row.names = FALSE)
  write.csv(data.frame(), "cross_participant_suspicious_slices.csv", row.names = FALSE)
}

# ── Update review_output ────────────────────────────────────────────────────
review_output$data_with_flags <- data

# Extend checkforerrors_df with CP-flagged rows that aren't already there
existing_flagged <- review_output$checkforerrors_df
cp_newly_flagged <- data[flagged_idx, ]

# For rows already in checkforerrors_df, update their auto_error_desc
# For rows NOT in checkforerrors_df, add them
if (nrow(cp_newly_flagged) > 0) {
  existing_ids <- paste(existing_flagged$pid, existing_flagged$day_num, existing_flagged$row_id)
  cp_ids <- paste(cp_newly_flagged$pid, cp_newly_flagged$day_num, cp_newly_flagged$row_id)
  truly_new <- cp_newly_flagged[!cp_ids %in% existing_ids, ]

  if (nrow(truly_new) > 0) {
    review_output$checkforerrors_df <- bind_rows(existing_flagged, truly_new)
    cat(sprintf("  Added %d new rows to checkforerrors_df\n", nrow(truly_new)))
  }
}

# ── Console summary ─────────────────────────────────────────────────────────
cat(sprintf("\n  Cross-participant check complete:\n"))
cat(sprintf("    Suspicious PIDs:          %d\n", length(all_suspicious_pids)))
cat(sprintf("    Total CP-flagged rows:    %d\n", n_cp_flagged))
cat(sprintf("    checkforerrors_df now:    %d rows\n", nrow(review_output$checkforerrors_df)))

if (length(all_suspicious_pids) > 0 && length(all_suspicious_pids) <= 10) {
  cat(sprintf("    Suspicious PIDs: %s\n", paste(sort(all_suspicious_pids), collapse = ", ")))
} else if (length(all_suspicious_pids) > 10) {
  cat(sprintf("    Suspicious PIDs (first 10): %s ... (+%d more)\n",
              paste(sort(all_suspicious_pids)[1:10], collapse = ", "),
              length(all_suspicious_pids) - 10))
}

cat("\n=== [cross_participant_global_check] Finished ===\n")

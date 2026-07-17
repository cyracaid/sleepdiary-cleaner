library(lubridate)
library(tidyverse)

# Helper: apply a processing function to multiple variables
multi_process <- function(df, var_list, func, format = NULL) {
  for (varname in var_list) {
    df <- func(df, varname = varname, format = format)
  }
  df
}

# ============================================================================
# PIPELINE — Master control function
# ============================================================================
# Run run_pipeline() on the R console to execute all 10 steps sequentially.
#
# What this pipeline does:
#   Takes raw EMA sleep diary data → parses timestamps → detects errors →
#   applies manual corrections → calculates sleep metrics → flags remaining
#   input anomalies → generates 24 diagnostic figures.
#
# Each step sources its own R file with local = TRUE (isolated environment).
# Data flows from one step to the next via the ema_data_release_* / corrected_ema_data objects.
# ============================================================================
.run_pipeline_internal <- function() {
  
  # Load correction status reporter
  sdir <- get0("splsleep_scripts_dir", envir = .GlobalEnv, ifnotfound = getwd())
  source(file.path(sdir, "report_correction_status.R"), local = TRUE)
  
  # ── Step 1: Load data ──
  # INPUT:  deidentified_intervalvars_forCD_111325.rds (processed R data)
  #         sber_ema_anon_20260227.csv (raw survey responses)
  # OUTPUT: df (merged with start dates, WASO columns from CSV)
  # WHAT:   Loads the two data sources and merges the few columns
  #         that live only in the CSV (start date, WASO counts).
  #         The RDS holds the main body of processed EMA variables.
  cat("\n=== Step 1: Loading data ===\n")
  rds_file <- cfg_get("data.files.main_rds", "deidentified_intervalvars_forCD_111325.rds")
  csv_file <- cfg_get("data.files.main_csv", "sber_ema_anon_20260227.csv")
  cat(sprintf("  Reading RDS: %s\n", basename(rds_file)))
  df <- readRDS(rds_file)
  cat(sprintf("  Reading CSV: %s\n", basename(csv_file)))
  full_df <- read.csv(csv_file)
  df <- df %>%
    mutate(
      StartDate = full_df$StartDate,
      num_waso_am = full_df$num_waso,
      num_waso_estimate_am = full_df$num_waso_estimate_am,
    )
  rm(full_df); gc()
  
  # Validate schema right after data loading
  .cfg <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
  if (!is.null(.cfg)) validate_schema(df, .cfg, label = "Step 1 output")
  
  # ── Step 1.5: Cross-participant field-misentry check ──
  # INPUT:  deidentified_intervalvars_forCD_111325.rds (raw data)
  # OUTPUT: cross_participant_field_misentries.csv
  # WHAT:   Detects when SOL values (HH:MM strings) exactly match
  #         time_bed / time_sleep, or WASO matches time_awake / time_getup.
  #         This catches "filling in the wrong field" errors that the
  #         MM:SS parser silently "fixes" (630→10.5) without addressing
  #         the underlying cross-field contamination.
  source(file.path(sdir, "cross_participant_field_misentry_check.R"), local = TRUE)
  
  # ── Step 2: Process timestamps ──
  # INPUT:  df (raw timestamp strings like "7:30 PM")
  # OUTPUT: ema_data_release_timeproc (same df + parsed POSIXct columns +
  #         *_checkforerrors flag columns for each timestamp)
  # WHAT:   Converts human-readable time strings into proper R date-time objects.
  #         Handles: AM/PM detection, missing separators, 12/24-hour formats.
  #         Creates a *_checkforerrors column per variable that captures
  #         parsing issues (ambiguous times, format problems).
  cat("\n=== Step 2: Processing timestamps ===\n")
  source(file.path(sdir, "process_timestamp_emadatarelease_cyra.R"), local = TRUE)
  tstamp.vars.to.proc <- c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am", 
                           "caffeinetoday_PM", "alcoholtoday_PM", "nicotine_amount_pm", "cannabis_amount_pm")
  ema_data_release_timeproc <- df
  ema_data_release_timeproc <- multi_process(ema_data_release_timeproc, tstamp.vars.to.proc, process_timestamp, "timestamp")
  rm(df, tstamp.vars.to.proc); gc()
  
  # NOTE: pid=4024 hardcoded fix was migrated to manual_nap_exercise_corrections.csv
  #       (handled by apply_nap_exercise_corrections() in Step 6.5).
  
  # ── Step 3: Process interval durations ──
  # INPUT:  ema_data_release_timeproc (duration strings like "00:30", "90", ".5")
  # OUTPUT: ema_data_release_timeproc (duration strings parsed to numeric minutes)
  # WHAT:   Converts interval/duration responses (SOL, WASO, exercise, naps)
  #         from various text formats into numeric minutes.
  #         Detects and fixes: missing colons, decimal hours, swapped HH:MM.
  cat("\n=== Step 3: Processing intervals ===\n")
  source(file.path(sdir, "process_interval.R"), local = TRUE)
  interval.vars.to.proc <- c("duration_totalmin_sol_estimate_am", 
                              "duration_totalmin_waso_estimate_am",
                              "duration_totalmin_napstoday_PM",
                              "exercisetoday_PM_totalmin_Light",
                              "exercisetoday_PM_totalmin_Moderate", 
                              "exercisetoday_PM_totalmin_Vigorous",
                              "exercisetoday_PM_totalmin_Strength")
  if (exists("process_interval")) {
    ema_data_release_timeproc <- multi_process(ema_data_release_timeproc, interval.vars.to.proc, process_interval, "interval_hhmm")
  }
  rm(interval.vars.to.proc); gc()
  
  # ── Step 4: Normalize sleep time sequence ──
  # INPUT:  ema_data_release_timeproc (parsed timestamps, may have AM/PM order errors)
  # OUTPUT: ema_data_release_timecalc (same data + corrected timestamps +
  #         is_priority_adjusted, minor_order_error flags)
  # WHAT:   Applies a decision-tree to fix common sleep-log entry problems:
  #         - AM/PM confusion (e.g., bedtime logged as PM when it should be AM)
  #         - Minor order errors (e.g., sleep time before bedtime, within 3 hours)
  #         - Wraparound issues across midnight
  #         Automatically corrects the most common timestamp swap patterns.
  cat("\n=== Step 4: Normalizing sleep time sequence ===\n")
  source(file.path(sdir, "normalize_sleep_time_sequence.R"), local = TRUE)
  flip_gap <- tryCatch(cfg_get("timestamp.sequence.max_gap_hours", 12), error = function(e) 12)
  ema_data_release_timecalc <- normalize_sleep_time_sequence(AM_rawdata = ema_data_release_timeproc, flip_gap_hours = flip_gap)
  rm(ema_data_release_timeproc); gc()
  
  # ── Checkpoint A: raw state before corrections ──
  checkpoint_A <- report_status(ema_data_release_timecalc, "After Step 4 (auto-normalize)", "A")
  
  # ── Step 5: Classify records & generate review files ──
  # INPUT:  ema_data_release_timecalc (normalized timestamps + durations)
  # OUTPUT: [NEW]manual_error_correction_review.csv
  #         [NEW]manual_unusual_review.csv
  #         error_df_pre, unusual_df_pre, equal_time_df_pre (in memory)
  # WHAT:   Compares bed→sleep→awake→getup time differences against
  #         reasonable thresholds. Classifies every record as one of:
  #         - ERROR: temporal order impossible (e.g., getup before bedtime)
  #         - UNUSUAL: plausible but suspicious pattern (e.g., 4-hour sleep)
  #         - EQUAL TIME: identical timestamps (e.g., bed==sleep)
  #         - CLEAN: everything looks reasonable
  #         Creates CSV review files for human annotators.
  cat("\n=== Step 5: Generating correction files ===\n")
  source(file.path(sdir, "generate_correction_files.R"), local = TRUE)
  suppressMessages(generated_files <- generate_correction_files(ema_data_release_timecalc))
  manual_corrections <- if (file.exists("manual_error_corrections.csv")) {
    suppressMessages(read_csv("manual_error_corrections.csv", show_col_types = FALSE))
  } else {
    cat("  ⚠ manual_error_corrections.csv not found — using empty corrections\n"); tibble()
  }
  manual_unusual <- if (file.exists("manual_unusual_corrections.csv")) {
    read.csv("manual_unusual_corrections.csv", fileEncoding = "UTF-8-BOM")
  } else {
    cat("  ⚠ manual_unusual_corrections.csv not found — using empty unusual\n"); data.frame()
  }
  names(manual_unusual) <- gsub("^X\\.\\.\\.|^X\\.|^\\.", "", names(manual_unusual))
  rm(generated_files, generate_correction_files); gc()

  # ── Step 5.75: Apply second-review consensus decisions ──
  # INPUT:  second_review_checklist.csv (13 rows, all consensus_reached)
  #         manual_error_corrections.csv (verify route)
  #         manual_nap_exercise_corrections.csv (verify route)
  # OUTPUT: manual_metric_review_acceptances.csv (appended with anti-join)
  # WHAT:   Write-only step. Reads the checklist and dispatches each row
  #         to the appropriate correction/acceptance CSV based on target_csv.
  #         Uses anti-join on (pid, day_num, row_id) for idempotency.
  #         For manual_error_corrections and manual_nap_exercise_corrections
  #         routes, it only prints a verification message — the actual
  #         correction rows must already exist in those CSVs.
  #         Placed BETWEEN Step 5 and Step 6 so that corrections routed to
  #         manual_error_corrections.csv take effect in the same pipeline run.
  cat("\n=== Step 5.75: Applying second-review consensus ===\n")
  source(file.path(sdir, "apply_second_review.R"), local = TRUE)

  # ── Step 6: Apply manual corrections & recalculate ──
  # INPUT:  corrected_ema_data (post-step-4) + manual_error_corrections.csv +
  #         manual_unusual_corrections.csv
  # OUTPUT: corrected_ema_data (timestamps fixed, metrics recalculated,
  #         is_error, error_type, is_unusual, unusual_type, data_category)
  # WHAT:   The human reviewer's decisions are read from the CSV files and
  #         applied automatically. This step:
  #         - Replaces timestamps according to correction instructions
  #         - Handles "swap" corrections (swapped bed/sleep values)
  #         - Recalculates all time-difference metrics
  #         - Re-classifies corrected records
  #         - Flags reasonable-unusual records (accepted unusual patterns)
  cat("\n=== Step 6: Applying manual corrections ===\n")
  source(file.path(sdir, "error_unusual_sleep_time_corrections.R"), local = TRUE)
  results <- apply_manual_corrections_and_recalculate(
    ema_data = ema_data_release_timecalc,
    corrections_df = manual_corrections,
    manual_unusual_df = manual_unusual
  )
  assign("corrected_ema_data", results$corrected_ema_data, envir = .GlobalEnv)
  rm(manual_corrections, manual_unusual, results); gc()
  
  # ── Checkpoint B: after timestamp corrections ──
  checkpoint_B <- report_status(corrected_ema_data, "After Step 6 (timestamp corrections)", "B", previous = checkpoint_A)
  
  # ── Step 6.5: Apply manual duration corrections ──
  # INPUT:  corrected_ema_data (from step 6)
  #         manual_nap_exercise_corrections.csv
  #         manual_sleep_metric_duration_corrections.csv
  #         manual_metric_review_acceptances.csv
  # OUTPUT: corrected_ema_data with targeted _mincalc values fixed before
  #         Step 7 derives sleep metrics.
  # WHAT:   Applies corrections for duration values where a parser or human
  #         entry made a numeric duration implausible. Nap/exercise and sleep
  #         metric duration corrections are numeric replacements, not timestamp
  #         swaps. It also carries human-accepted metric review decisions
  #         forward so Step 8 does not repeatedly flag rows already judged OK.
  cat("\n=== Step 6.5: Applying manual duration corrections ===\n")
  source(file.path(sdir, "apply_nap_exercise_corrections.R"), local = TRUE)
  corrected_ema_data <- apply_nap_exercise_corrections(corrected_ema_data)
  source(file.path(sdir, "apply_sleep_metric_duration_corrections.R"), local = TRUE)
  corrected_ema_data <- apply_sleep_metric_duration_corrections(corrected_ema_data)
  source(file.path(sdir, "apply_metric_review_acceptances.R"), local = TRUE)
  corrected_ema_data <- apply_metric_review_acceptances(corrected_ema_data)
  assign("corrected_ema_data", corrected_ema_data, envir = .GlobalEnv)
  
  # ── Checkpoint C: after duration corrections ──
  checkpoint_C <- report_status(corrected_ema_data, "After Step 6.5 (duration corrections)", "C", previous = checkpoint_B)
  
  # ── Step 7: Calculate derived sleep variables ──
  # INPUT:  corrected_ema_data (corrected timestamps from step 6)
  # OUTPUT: corrected_ema_data + new columns:
  #         self_diffcalc_sol_minutes (sleep onset latency)
  #         self_diffcalc_sleepefficiency_percent
  #         self_diffcalc_totalsleeptime_minutes (TST)
  #         self_diffcalc_timeinbed_minutes
  #         plus derived: sleep_onset_timestamp, sleep_period, waso_bout_avg
  # WHAT:   Computes the actual sleep metrics used in analysis:
  #         - SOL: minutes from bedtime to sleep onset
  #         - TST: total time asleep (sleep period minus WASO)
  #         - Sleep efficiency: TST ÷ time-in-bed × 100
  #         Also stores calculation metadata for audit trail.
  cat("\n=== Step 7: Calculating sleep variables ===\n")
  source(file.path(sdir, "calculate_sleep_time_end.R"), local = TRUE)
  corrected_ema_data <- calculate_sleep_time_vars_end(corrected_ema_data)
  assign("corrected_ema_data", corrected_ema_data, envir = .GlobalEnv)
  rm(calculate_sleep_time_vars_end, verify_sleep_calculations); gc()
  
  # ── Checkpoint D: after metrics computed ──
  checkpoint_D <- report_status(corrected_ema_data, "After Step 7 (metrics computed)", "D", previous = checkpoint_C)
  
  # ── Step 8: Auto-detect remaining errors & substance input anomalies ──
  # INPUT:  corrected_ema_data (post-step 7, with all metrics + classifications)
  # OUTPUT: checkforerrors_processed (flag data frame)
  #         checkforerrors_summary (counts per flag type)
  #         substance_decimal_anomalies (input anomaly reference table, in global env)
  # WHAT:   Three-part auto-detection:
  #         PART A - Collects existing *_checkforerrors flags from timestamp parsing
  #         PART B - Imports temporal error_type / unusual_type from step 6
  #         PART C - Validates computed sleep metrics (SOL, SE, TST/TIB ratio)
  #         Also flags substance-use input anomalies using raw CSV data:
  #         text entries, decimal precision problems, possible decimal slips.
  #         The output drives Figures 13-18 (auto-detection section).
  cat("\n=== Step 8: Running auto error detection ===\n")
  source(file.path(sdir, "checkforerrors_processing.R"), local = TRUE)
  assign("review_output", review_output, envir = .GlobalEnv)
  assign("checkforerrors_summary", checkforerrors_summary, envir = .GlobalEnv)
  
  # ── Checkpoint E: after auto-detection ──
  rs <- checkforerrors_summary$review_summary
  flag_extra <- list(
    TIMESTAMP_ISSUE = sum(rs$raw_category == "TIMESTAMP_ISSUE", na.rm = TRUE),
    DURATION_ISSUE  = sum(rs$raw_category == "DURATION_ISSUE", na.rm = TRUE),
    AMOUNT_FLAG     = sum(rs$raw_category == "AMOUNT_FLAG", na.rm = TRUE),
    SELF_REPORTED_FLAG = sum(rs$raw_category == "SELF_REPORTED_FLAG", na.rm = TRUE)
  )
  checkpoint_E <- report_status(corrected_ema_data, "After Step 8 (auto-detection)", "E",
                                previous = checkpoint_D, extra = flag_extra)

  # ── Export SELF-REPORTED FLAG records for analysis ──
  needs_idx <- which(rs$raw_category == "SELF_REPORTED_FLAG")
  if (length(needs_idx) > 0) {
    df <- review_output$data_with_flags[needs_idx, ]
    cols <- intersect(c("pid", "day_num", "participant", "date_bed", "study_day",
                        "self_diffcalc_sol_minutes", "self_diffcalc_sleepefficiency_percent",
                        "self_diffcalc_totalsleeptime_minutes", "self_diffcalc_timeinbed_minutes",
                        "sol_category", "se_category", "tst_tib_ratio_category",
                        "metric_duration_input_category", "auto_error_desc"),
                      names(df))
    needs_csv <- df[, cols, drop = FALSE]
    write.csv(needs_csv, "output/flagged_records_self_reported.csv", row.names = FALSE)
    cat(sprintf("  Exported %d SELF-REPORTED FLAG records → output/flagged_records_self_reported.csv\n", nrow(needs_csv)))
  }
  rm(rs, flag_extra, needs_idx, df, cols, needs_csv)

  # ── Step 8.5: Cross-participant global consistency check ──
  # INPUT:  review_output$data_with_flags (flagged data from Step 8)
  #         corrected_ema_data (sleep metrics for per-participant baselines)
  # OUTPUT: cross_participant_flagged_rows.csv (flagged rows with CP context)
  #         cross_participant_suspicious_slices.csv (ALL rows of flagged PIDs)
  #         review_output$data_with_flags (augmented with cp_flag_type etc.)
  # WHAT:  For each participant with enough data, computes their personal
  #        SOL/WASO baseline (median) and variability (MAD). Flags days where
  #        the participant's value deviates dramatically from their own norm.
  #        Also writes a "suspicious slices" CSV that groups ALL rows for
  #        flagged participants so the reviewer can see full context.
  cat("\n=== Step 8.5: Cross-participant global consistency check ===\n")
  source(file.path(sdir, "cross_participant_global_check.R"), local = TRUE)
  assign("review_output", review_output, envir = .GlobalEnv)
  
  # ── Step 9: Generate all figures ──
  # INPUT:  corrected_ema_data + checkforerrors_processed + checkforerrors_summary
  # OUTPUT: 24 PNG files saved to working directory
  # WHAT:   Produces the full figure set:
  #         Figures 1-12:  Final data quality (corrected data)
  #         Figures 13-18: Auto-detection results (pre-correction flags)
  #         Figures 19-21: Unified classification summary
  #         Figures 22-24: Substance use distributions
  cat("\n=== Step 9: Generating visualizations ===\n")
  source(file.path(sdir, "sleep_visualization.R"), local = TRUE)
  
  # ── Final summary ──
  final_summary(list(A = checkpoint_A, B = checkpoint_B, C = checkpoint_C, D = checkpoint_D, E = checkpoint_E))
  
  cat("\n✅ Pipeline complete!\n")
}

# ── Auto-run (non-interactive, when NOT called from splsleep package) ──
if (!interactive() && !exists("splsleep_loaded")) {
  .run_pipeline_internal()
}

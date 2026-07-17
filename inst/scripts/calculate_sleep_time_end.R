# ============================================================================
# FUNCTION: calculate_sleep_time_vars
# ============================================================================
# Description: Calculate sleep variables based on corrected timestamps
# 
# Input: 
#   - data: dataframe containing corrected time columns
# 
# Required columns in input data:
#   - time_bed_corrected
#   - time_sleep_corrected
#   - time_awake_corrected
#   - time_getup_corrected
#   - duration_totalmin_sol_estimate_am_mincalc
#   - duration_totalmin_waso_estimate_am_mincalc
# 
# Output:
#   - Original dataframe with additional calculated sleep variables
#
# --- Computed metrics (plain-language summary) ---
#
#   self_diffcalc_sol_minutes          Sleep Onset Latency (SOL).
#                                      Minutes from bedtime to sleep onset.
#                                      SOL = 0 means the person fell asleep
#                                      immediately (bedtime == sleep onset).
#
#   self_diffcalc_sleeponset           The actual clock time when sleep began,
#                                      taken from time_sleep_corrected.
#
#   self_diffcalc_totaltrysleep_minutes Total time spent "trying to sleep,"
#                                       i.e. from initial sleep onset to the
#                                       final morning awakening (time_awake).
#                                       This excludes both pre-sleep latency
#                                       and the time awake out of bed after
#                                       final awakening.
#
#   self_diffcalc_timeinbed_minutes     Total time physically in bed, from the
#                                       bedtime attempt to the final get-up
#                                       time. This is the broadest interval
#                                       and includes SOL, WASO, and the final
#                                       awake-out-of-bed segment.
#
#   self_diffcalc_sleepperiod_minutes   Sleep Period: the window from actual
#                                       sleep onset (self_diffcalc_sleeponset)
#                                       to the final awakening. Contrast with
#                                       timeinbed, which starts at bedtime
#                                       (before SOL) and ends at get-up time
#                                       (after the final awakening).
#
#   self_diffcalc_totalsleeptime_minutes Total Sleep Time (TST): the amount
#                                        of actual sleep obtained. Equals
#                                        sleep period minus WASO interruptions.
#                                        This is the core metric for quantifying
#                                        sleep quantity.
#
#   self_diffcalc_sleepefficiency_percent Sleep efficiency: TST divided by
#                                         total try-sleep time, expressed as
#                                         a fraction (not percentage). A value
#                                         of 0.85 means 85% of the try-sleep
#                                         period was spent actually asleep.
#
#   avg_waso_estimate_am_minutes         Average length of each WASO
#                                        (Wake After Sleep Onset) interruption.
#                                        Computed as total WASO minutes divided
#                                        by the number of WASO bouts. Larger
#                                        values indicate fewer but longer
#                                        awakenings; smaller values indicate
#                                        many brief awakenings.
# ============================================================================

calculate_sleep_time_vars_end <- function(data) {
  
  # Load required libraries
  library(dplyr)
  library(lubridate)
  
  # Print the name of the dataframe being processed
  data_name <- deparse(substitute(data))
  cat(sprintf("\n=== Calculating sleep time variables for: %s ===\n", data_name))
  
  # --- Input validation ---
  # Check that every required column exists in the input dataframe before
  # attempting any calculations. This prevents cryptic downstream errors and
  # provides a clear, actionable message when columns are missing.
  required_cols <- c(
    "time_bed_corrected",         # Bedtime (when they got into bed)
    "time_sleep_corrected",       # Self-reported sleep onset time
    "time_awake_corrected",       # Final morning awakening time
    "time_getup_corrected",       # Time they got out of bed
    "num_waso_estimate_am",       # Number of WASO bouts (temporarily commented out)
    "duration_totalmin_sol_estimate_am_mincalc",  # Estimated SOL in minutes (from morning questionnaire)
    "duration_totalmin_waso_estimate_am_mincalc"  # Estimated total WASO duration in minutes
  )
  
  missing_cols <- setdiff(required_cols, names(data))
  
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "\n❌ Missing required columns in %s: %s\nPlease ensure these columns exist in the data.",
      data_name,
      paste(missing_cols, collapse = ", ")
    ))
  }
  
  cat(sprintf("\n✓ All required columns found in %s\n", data_name))
  cat("  Starting calculation of sleep variables...\n")

  if (!"duration_totalmin_waso_estimate_am_checkforerrors" %in% names(data)) {
    data$duration_totalmin_waso_estimate_am_checkforerrors <- FALSE
  }
  if (!"duration_totalmin_sol_estimate_am_checkforerrors" %in% names(data)) {
    data$duration_totalmin_sol_estimate_am_checkforerrors <- FALSE
  }
  
  # --- Metric calculations ---
  # Each mutate() step derives a single sleep variable. The pipeline processes
  # one row per sleep episode (one night per participant).
  cleaned_data <- data %>%
    
    # 1. Sleep Onset Latency (SOL)
    # SOL = time_sleep_corrected - time_bed_corrected.
    # Measures how many minutes elapsed between getting into bed and falling
    # asleep. SOL = 0 means the person's self-reported sleep onset coincides
    # exactly with their bedtime (they fell asleep immediately).
    mutate(self_diffcalc_sol_minutes = as.numeric(difftime(time_sleep_corrected, time_bed_corrected, units = "mins"))) %>%

    # 2. Actual sleep onset clock time
    # time_sleep_corrected is already the corrected sleep-onset timestamp.
    # The separate SOL duration field is kept for consistency checks, but
    # should not be added here or SOL gets double-counted.
    mutate(self_diffcalc_sleeponset = time_sleep_corrected) %>%
    
    # 3. Total try-sleep duration
    # The period from self-reported sleep onset (time_sleep_corrected) to the
    # final awakening (time_awake_corrected). This is the window during which
    # the person was attempting to sleep, excluding pre-sleep latency.
    mutate(self_diffcalc_totaltrysleep_minutes = as.numeric(difftime(time_awake_corrected, time_sleep_corrected, units = "mins"))) %>%

    # 3b. SOL duration audit gate
    # The parsed SOL duration is useful for checking questionnaire consistency,
    # but it is not allowed to redefine sleep onset or TST.
    mutate(
      sol_duration_for_review_status = case_when(
        is.na(duration_totalmin_sol_estimate_am_mincalc) ~ "missing",
        duration_totalmin_sol_estimate_am_checkforerrors %in% TRUE ~ "untrusted_interval_flag",
        !is.na(self_diffcalc_totaltrysleep_minutes) & self_diffcalc_totaltrysleep_minutes >= 0 &
          duration_totalmin_sol_estimate_am_mincalc > self_diffcalc_totaltrysleep_minutes ~ "untrusted_exceeds_sleep_to_awake_window",
        duration_totalmin_sol_estimate_am_mincalc < 0 ~ "untrusted_negative",
        TRUE ~ "available_for_review"
      ),
      duration_totalmin_sol_estimate_am_mincalc_for_review = if_else(
        sol_duration_for_review_status == "available_for_review",
        as.numeric(duration_totalmin_sol_estimate_am_mincalc),
        NA_real_
      )
    ) %>%
    
    # 4. Total time in bed
    # The full interval from bedtime attempt (time_bed_corrected) to getting
    # out of bed (time_getup_corrected). This is the broadest sleep-interval
    # metric and includes pre-sleep latency, WASO, and the final awake period.
    mutate(self_diffcalc_timeinbed_minutes = as.numeric(difftime(time_getup_corrected, time_bed_corrected, units = "mins"))) %>%
    
    # 5. Sleep period duration
    # The window from corrected sleep onset (self_diffcalc_sleeponset) to
    # the final morning awakening (time_awake_corrected).
    mutate(self_diffcalc_sleepperiod_minutes = as.numeric(difftime(time_awake_corrected, self_diffcalc_sleeponset, units = "mins"))) %>%

    # 5b. WASO duration trust gate
    # Keep the original WASO mincalc for audit, but only feed it into TST when
    # it passes its own parser flag and is possible inside the sleep period.
    mutate(
      waso_duration_for_metrics_status = case_when(
        is.na(duration_totalmin_waso_estimate_am_mincalc) ~ "missing",
        duration_totalmin_waso_estimate_am_checkforerrors %in% TRUE ~ "untrusted_interval_flag",
        !is.na(self_diffcalc_sleepperiod_minutes) &
          duration_totalmin_waso_estimate_am_mincalc > self_diffcalc_sleepperiod_minutes ~ "untrusted_exceeds_sleep_period",
        duration_totalmin_waso_estimate_am_mincalc < 0 ~ "untrusted_negative",
        TRUE ~ "used"
      ),
      duration_totalmin_waso_estimate_am_mincalc_used = if_else(
        waso_duration_for_metrics_status == "used",
        as.numeric(duration_totalmin_waso_estimate_am_mincalc),
        NA_real_
      )
    ) %>%
    
    # 6. Total Sleep Time (TST)
    # The length of actual sleep obtained during the sleep period. Computed by
    # subtracting estimated total WASO minutes from the sleep period duration.
    # This is the primary outcome for quantifying sleep quantity.
    mutate(self_diffcalc_totalsleeptime_minutes = self_diffcalc_sleepperiod_minutes - duration_totalmin_waso_estimate_am_mincalc_used) %>%
    
    # 7. Sleep efficiency
    # TST divided by total-try-sleep duration, expressed as a proportion.
    # Values range from 0 to 1 (typically 0.70-0.95 in healthy adults).
    # Higher values indicate that a greater proportion of the try-sleep
    # window was actually spent asleep.
    mutate(self_diffcalc_sleepefficiency_percent = self_diffcalc_totalsleeptime_minutes / self_diffcalc_totaltrysleep_minutes) %>% 
   
    # 8. WASO average bout duration
    # Average length of each trusted WASO interruption. If the bout count is
    # missing/zero or WASO is untrusted, leave this derived metric unknown.
    mutate(num_waso_estimate_am = as.numeric(num_waso_estimate_am)) %>%
    mutate(avg_waso_estimate_am_minutes = if_else(
      !is.na(duration_totalmin_waso_estimate_am_mincalc_used) &
        !is.na(num_waso_estimate_am) & num_waso_estimate_am > 0,
      duration_totalmin_waso_estimate_am_mincalc_used / num_waso_estimate_am,
      NA_real_
    ))
  
  # --- Calculation metadata ---
  # Store audit information on the returned dataframe so downstream consumers
  # can verify that sleep calculations have been applied. This is especially
  # useful when chaining multiple processing steps in a pipeline.
  attr(cleaned_data, "sleep_vars_calculated") <- TRUE
  attr(cleaned_data, "calculation_timestamp") <- Sys.time()
  attr(cleaned_data, "source_dataframe") <- data_name
  
  return(cleaned_data)
}

# ============================================================================
# VERIFICATION FUNCTION: verify_sleep_calculations
# ============================================================================
# Checks that all expected derived sleep variables exist in a dataframe after
# calculate_sleep_time_vars_end() has been run. Operates as a post-condition
# assertion: it does NOT recompute values, it only confirms presence.
#
# What it checks:
#   1. Column presence: every variable in expected_vars must exist in the data.
#   2. Metadata attributes: confirms that sleep_vars_calculated, the
#      calculation_timestamp, and source_dataframe attributes are set.
#
# Returns TRUE if all expected variables are present, FALSE otherwise.
# The function prints a detailed report to the console regardless of outcome.
# ============================================================================

verify_sleep_calculations <- function(data) {
  cat("\n=== VERIFYING SLEEP VARIABLES CALCULATION ===\n")
  
  # The definitive list of variables that should have been created
  expected_vars <- c(
    "self_diffcalc_sol_minutes",
    "self_diffcalc_sleeponset", 
    "self_diffcalc_totaltrysleep_minutes",
    "self_diffcalc_timeinbed_minutes",
    "self_diffcalc_sleepperiod_minutes",
    "self_diffcalc_totalsleeptime_minutes",
    "self_diffcalc_sleepefficiency_percent"
    # "avg_waso_estimate_am_minutes"  # Commented out as it requires num_waso_estimate_am
  )
  
  # Partition into found vs. missing
  found_vars <- expected_vars[expected_vars %in% names(data)]
  missing_vars <- expected_vars[!expected_vars %in% names(data)]
  
  cat(sprintf("\nFound %d of %d expected variables:\n", length(found_vars), length(expected_vars)))
  if (length(found_vars) > 0) {
    for (var in found_vars) {
      cat(sprintf("  ✓ %s\n", var))
    }
  }
  
  if (length(missing_vars) > 0) {
    cat("\n❌ Missing variables:\n")
    for (var in missing_vars) {
      cat(sprintf("  ✗ %s\n", var))
    }
  }
  
  # Check attributes — confirms the calculation pipeline ran end-to-end
  if (!is.null(attr(data, "sleep_vars_calculated"))) {
    cat(sprintf("\n✓ Sleep variables calculated: %s\n", attr(data, "sleep_vars_calculated")))
    cat(sprintf("✓ Calculation timestamp: %s\n", attr(data, "calculation_timestamp")))
    cat(sprintf("✓ Source dataframe: %s\n", attr(data, "source_dataframe")))
  } else {
    cat("\n⚠ No calculation metadata found\n")
  }
  
  return(length(missing_vars) == 0)
}

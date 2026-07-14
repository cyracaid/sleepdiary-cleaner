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
#
# Output:
#   - Original dataframe with additional calculated sleep variables
# ============================================================================

calculate_sleep_time_vars_end <- function(data) {
  
  # Load required libraries
  library(dplyr)
  library(lubridate)
  
  # Print the name of the dataframe being processed
  data_name <- deparse(substitute(data))
  cat(sprintf("\n=== Calculating sleep time variables for: %s ===\n", data_name))
  
  # Check if required columns exist (num_waso_estimate_am removed from required list)
  required_cols <- c(
    "time_bed_corrected",
    "time_sleep_corrected", 
    "time_awake_corrected",
    "time_getup_corrected",
    "num_waso_estimate_am",  # Temporarily commented out
    "duration_totalmin_sol_estimate_am_mincalc",
    "duration_totalmin_waso_estimate_am_mincalc"
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
  
  # Calculate sleep variables from corrected timestamps and intervals
  cleaned_data <- data %>%
    # Sleep onset latency in minutes: time_sleep_corrected - time_bed_corrected
    mutate(self_diffcalc_sol_minutes = as.numeric(difftime(time_sleep_corrected, time_bed_corrected, units = "mins"))) %>%
    
    # Calculate sleep onset timestamp from self-report = duration_totalmin_sol + time_sleep_corrected
    mutate(self_diffcalc_sleeponset = lubridate::minutes(duration_totalmin_sol_estimate_am_mincalc) + time_sleep_corrected) %>%
    
    # Duration where they were trying to sleep in minutes = time_awake_corrected - time_sleep_corrected
    mutate(self_diffcalc_totaltrysleep_minutes = as.numeric(difftime(time_awake_corrected, time_sleep_corrected, units = "mins"))) %>%
    
    # Time in bed in minutes = time_getup_corrected - time_bed_corrected
    mutate(self_diffcalc_timeinbed_minutes = as.numeric(difftime(time_getup_corrected, time_bed_corrected, units = "mins"))) %>%
    
    # Sleep period duration from sleep onset
    mutate(self_diffcalc_sleepperiod_minutes = as.numeric(difftime(time_awake_corrected, self_diffcalc_sleeponset, units = "mins"))) %>%
    
    # Total sleep time (TST) in minutes: sleep period - WASO
    mutate(self_diffcalc_totalsleeptime_minutes = self_diffcalc_sleepperiod_minutes - duration_totalmin_waso_estimate_am_mincalc) %>%
    
    # Calculated sleep efficiency: TST / time try sleep
    mutate(self_diffcalc_sleepefficiency_percent = self_diffcalc_totalsleeptime_minutes / self_diffcalc_totaltrysleep_minutes) %>% 
  
   # Commented out: WASO average calculation (requires num_waso_estimate_am)
   # Convert num_waso_estimate_am to numeric if it isn't already
   mutate(num_waso_estimate_am = as.numeric(num_waso_estimate_am)) %>%
   # Calculated avg duration of waking after sleep onset bout in minutes
    mutate(avg_waso_estimate_am_minutes = duration_totalmin_waso_estimate_am_mincalc / num_waso_estimate_am)
  
  # Add attribute to track that sleep variables have been calculated
  attr(cleaned_data, "sleep_vars_calculated") <- TRUE
  attr(cleaned_data, "calculation_timestamp") <- Sys.time()
  attr(cleaned_data, "source_dataframe") <- data_name
  
  return(cleaned_data)
}

# ============================================================================
# VERIFICATION FUNCTION:
# ============================================================================

verify_sleep_calculations <- function(data) {
  cat("\n=== VERIFYING SLEEP VARIABLES CALCULATION ===\n")
  
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
  
  # Check attributes
  if (!is.null(attr(data, "sleep_vars_calculated"))) {
    cat(sprintf("\n✓ Sleep variables calculated: %s\n", attr(data, "sleep_vars_calculated")))
    cat(sprintf("✓ Calculation timestamp: %s\n", attr(data, "calculation_timestamp")))
    cat(sprintf("✓ Source dataframe: %s\n", attr(data, "source_dataframe")))
  } else {
    cat("\n⚠ No calculation metadata found\n")
  }
  
  return(length(missing_vars) == 0)
}


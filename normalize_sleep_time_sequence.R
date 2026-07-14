################################################################################
# normalize_sleep_time_sequence: Decision-Tree Sleep Log Cleaner
#
# Purpose:
#   Applies a rule-based decision tree to correct common sleep-log entry
#   problems, including AM/PM confusion, out-of-order timestamps, and
#   small temporal violations. The algorithm detects implausible gaps
#   between consecutive sleep events and resolves them by shifting or
#   swapping values so the record obeys the natural sequence:
#     bed time < sleep time < awake time < getup time
#
# Input:
#   AM_rawdata – A dataframe containing AM/PM sleep-log variables
#   (time_bed_am_hhmm_ampm, time_sleep_am_hhmm_ampm, ...).
#
# Output:
#   A list with two elements:
#     $cleaned_data       – The corrected dataframe with new columns
#                           (*_corrected, corrected, correction_type, …)
#     $classification_df  – A report of which records were corrected
#                           and what fix was applied.
#
# Columns written to cleaned_data:
#   time_bed_corrected,
#   time_sleep_corrected,
#   time_awake_corrected,
#   time_getup_corrected – Corrected copies of the original timestamps.
#   corrected            – Boolean; TRUE if any fix was applied.
#   correction_type      – Concatenated string naming the applied fix(es).
#   has_na               – TRUE if any of the four raw timestamps is NA.
#   data_category        – "skipped_na" for incomplete rows, NA otherwise.
#   row_id               – Unique row number.
################################################################################

normalize_sleep_time_sequence <- function(AM_rawdata) {
  # Load required libraries
  require(dplyr)
  require(lubridate)

  # ==========================================================================
  # Section 1: Check required duration columns exist
  # ==========================================================================
  # The function optionally uses three duration columns for cross-referencing
  # in downstream logic.  This block identifies which of them are actually
  # present in the input so that later operations can run without error.
  duration_vars <- c(
    "duration_totalmin_sol_estimate_am",    # Sleep onset latency (time to fall asleep)
    "duration_totalmin_waso_estimate_am",   # Wake after sleep onset
    "duration_totalmin_napstoday_PM"        # Nap duration (for cross-reference)
  )
  # Keep only variables that exist in the data
  duration_vars <- duration_vars[duration_vars %in% names(AM_rawdata)]

  # ==========================================================================
  # Section 2-3: Create new dataframe with required columns
  # ==========================================================================
  # We work on a copy of the original data so the raw input is never mutated.
  # New columns are added to hold corrected timestamps, error flags,
  # correction metadata, and a row identifier.

  # 2. Create new dataframe, copy original data
  cleaned_data <- AM_rawdata

  # 3. Create all required columns first
  cleaned_data <- cleaned_data %>% # Create new columns in cleaned_data for recording, marking, and correcting time data
    mutate(
      # Create unique row identifier
      row_id = row_number(),

      # Mark records with NA values (any sleep time variable is NA)
      has_na = is.na(time_bed_am_hhmm_ampm) | is.na(time_sleep_am_hhmm_ampm) | 
        is.na(time_awake_am_hhmm_ampm) | is.na(time_getup_am_hhmm_ampm), 
      # Otherwise NA values would cause errors, but blank entries are actually normal

      # Create corrected time columns (initialized with original values)
      time_bed_corrected = time_bed_am_hhmm_ampm,       # Bed time corrected copy
      time_sleep_corrected = time_sleep_am_hhmm_ampm,   # Sleep time corrected copy  
      time_awake_corrected = time_awake_am_hhmm_ampm,   # Awake time corrected copy
      time_getup_corrected = time_getup_am_hhmm_ampm,   # Getup time corrected copy
      # First create copies to prevent dirty data from overwriting originals

      # Initialize correction flags
      corrected = FALSE, # Boolean flag, initially FALSE, set to TRUE if record is corrected
      correction_type = NA_character_, # Record correction type (e.g., "midnight_correction"), initially NA

      # Set data category for NA records directly, skip subsequent processing
      data_category = ifelse(has_na, "skipped_na", NA_character_)
    )

  # ==========================================================================
  # Section 4: Priority Order Adjustment (main decision tree)
  # ==========================================================================
  # Rationale:
  #   Many sleep-log entry errors stem from AM/PM confusion.  For instance,
  #   a user who goes to bed at 10:00 PM may mistakenly record it as
  #   "time_bed = 10:00 AM" instead of 10:00 PM.  When parsed as a POSIXct
  #   timestamp this produces a value that is ~12 hours earlier than intended,
  #   breaking the expected temporal sequence.
  #
  # The decision tree detects this by checking whether the gap between
  # consecutive events is >= 12 hours.  When such a gap is found, the
  # later event is shifted forward by 12 hours (equivalent to flipping the
  # AM/PM indicator) to restore the plausible sequence.
  #
  # Sub-section 4.1 handles the wake-up segment (awake -> getup).
  # Sub-section 4.2 handles the sleep segment (bed -> sleep).

  # Only process records without missing values
  if (sum(!cleaned_data$has_na) > 0) { # Count number of records without NA values
    # Process only records without NA values - Condition check: are there processable records?
    valid_indices <- which(!cleaned_data$has_na) # Get indices of complete records, skip records with missing values

    for (i in valid_indices) { # Loop framework for row-by-row processing
      # Get current time values from corrected columns
      bed <- cleaned_data$time_bed_corrected[i]
      sleep <- cleaned_data$time_sleep_corrected[i]
      awake <- cleaned_data$time_awake_corrected[i]
      getup <- cleaned_data$time_getup_corrected[i]

      # Initialize correction flags for current row
      corrected_flag <- FALSE # Whether current row is corrected (initially FALSE)
      correction_type <- NA_character_ # Record correction type (initially NA)

      # ------------------------------------------------------------------
      # 4.1 Wake-up section: awake fixed, getup adjusted forward
      #     Rationale: If getup appears >= 12h after awake, the user
      #     likely recorded getup with the wrong AM/PM (e.g., real
      #     getup = 7:00 AM but recorded as 7:00 PM).  We subtract
      #     12 hours repeatedly until the gap is plausible (< 12h).
      # ------------------------------------------------------------------
      awake_getup_diff <- as.numeric(difftime(getup, awake, units = "hours"))

      # Wake-up section: if getup is later than awake and difference >=12h, adjust getup forward
      if (getup > awake && awake_getup_diff >= 12) { 
        # Loop adjustment until difference < 12h
        while (awake_getup_diff >= 12) {
          getup <- getup - hours(12) # Adjust getup forward by 12 hours
          awake_getup_diff <- as.numeric(difftime(getup, awake, units = "hours"))
          corrected_flag <- TRUE
          if (is.na(correction_type)) {
            correction_type <- "getup_reduce_12h_loop"
          } else {
            correction_type <- paste(correction_type, "+ getup_reduce_12h_loop")
          }
        }
      }

      # ------------------------------------------------------------------
      # 4.2 Sleep section: bed fixed, sleep adjusted forward
      #     Rationale: If sleep appears >= 12h after bed, the user
      #     likely recorded sleep with the wrong AM/PM (e.g., real
      #     sleep = 10:30 PM but recorded as 10:30 AM).  We subtract
      #     12 hours repeatedly to bring the gap under the threshold.
      # ------------------------------------------------------------------
      bed_sleep_diff <- as.numeric(difftime(sleep, bed, units = "hours"))

      # Sleep section: if bed is earlier than sleep and difference >=12h, adjust sleep forward
      if (bed < sleep && bed_sleep_diff >= 12) {
        # Loop adjustment until difference < 12h
        while (bed_sleep_diff >= 12) {
          sleep <- sleep - hours(12) # Adjust sleep forward by 12 hours
          bed_sleep_diff <- as.numeric(difftime(sleep, bed, units = "hours"))
          corrected_flag <- TRUE
          if (is.na(correction_type)) {
            correction_type <- "sleep_reduce_12h_loop"
          } else {
            correction_type <- paste(correction_type, "+ sleep_reduce_12h_loop")
          }
        }
      } 

      # Store processed values back to dataframe 
      # This code saves processed values back to dataframe, completing data cleaning process
      cleaned_data$time_bed_corrected[i] <- bed
      cleaned_data$time_sleep_corrected[i] <- sleep
      cleaned_data$time_awake_corrected[i] <- awake
      cleaned_data$time_getup_corrected[i] <- getup
      cleaned_data$corrected[i] <- corrected_flag
      cleaned_data$correction_type[i] <- correction_type
    }
  }

  # ==========================================================================
  # Section 5: Minor Order Error Processing (threshold of 3 hours)
  # ==========================================================================
  # Rationale:
  #   Even after the AM/PM correction above, some records may still violate
  #   the natural order (e.g., bed recorded AFTER sleep).  When the
  #   violation is small (< 3 hours) it almost certainly reflects a
  #   data-entry slip — the user simply wrote down the times in the wrong
  #   columns.  Since the values themselves are plausible (the gap is tiny),
  #   we swap the pair to restore the correct logical order.  Larger
  #   violations (> 3h) could indicate a genuinely unusual sleep pattern
  #   and are left untouched.
  if (sum(!cleaned_data$has_na) > 0) {
    valid_indices <- which(!cleaned_data$has_na)

    for (i in valid_indices) {
      bed <- cleaned_data$time_bed_corrected[i]
      sleep <- cleaned_data$time_sleep_corrected[i]
      awake <- cleaned_data$time_awake_corrected[i]
      getup <- cleaned_data$time_getup_corrected[i]

      # Check minor order errors (threshold changed to 3 hours)
      # 5.1 Check bed-sleep order error (difference less than 3 hours)
      bed_sleep_diff <- as.numeric(difftime(sleep, bed, units = "hours"))
      # bed > sleep: bed time later than sleep time (logical error, should sleep after bed)
      # abs(bed_sleep_diff) < 3: time difference less than 3 hours (small error range)
      if (bed > sleep && abs(bed_sleep_diff) < 3) { 
        # Swap bed and sleep
        temp <- bed
        cleaned_data$time_bed_corrected[i] <- sleep
        cleaned_data$time_sleep_corrected[i] <- temp
        cleaned_data$corrected[i] <- TRUE
        if (is.na(cleaned_data$correction_type[i])) {
          cleaned_data$correction_type[i] <- "bed_sleep_swap_3h"
        } else {
          cleaned_data$correction_type[i] <- paste(cleaned_data$correction_type[i], "+ bed_sleep_swap_3h")
        }
      }

      # 5.2 Check sleep-awake order error (difference less than 3 hours)
      sleep_awake_diff <- as.numeric(difftime(awake, sleep, units = "hours"))
      if (sleep > awake && abs(sleep_awake_diff) < 3) {
        # Swap sleep and awake
        temp <- sleep
        cleaned_data$time_sleep_corrected[i] <- awake
        cleaned_data$time_awake_corrected[i] <- temp
        cleaned_data$corrected[i] <- TRUE
        if (is.na(cleaned_data$correction_type[i])) {
          cleaned_data$correction_type[i] <- "sleep_awake_swap_3h"
        } else {
          cleaned_data$correction_type[i] <- paste(cleaned_data$correction_type[i], "+ sleep_awake_swap_3h")
        }
      }

      # 5.3 Check awake-getup order error (difference less than 3 hours)
      awake_getup_diff <- as.numeric(difftime(getup, awake, units = "hours"))
      # awake > getup: awake time later than getup time (logical error, should get up after awake)
      # abs(awake_getup_diff) < 3: time difference less than 3 hours (small error range)
      if (awake > getup && abs(awake_getup_diff) < 3) {
        # Swap awake and getup
        temp <- awake
        cleaned_data$time_awake_corrected[i] <- getup
        cleaned_data$time_getup_corrected[i] <- temp
        cleaned_data$corrected[i] <- TRUE
        if (is.na(cleaned_data$correction_type[i])) {
          cleaned_data$correction_type[i] <- "awake_getup_swap_3h"
        } else {
          cleaned_data$correction_type[i] <- paste(cleaned_data$correction_type[i], "+ awake_getup_swap_3h")
        }
      }
    }
  }

  # ==========================================================================
  # Section 10: Clear *_checkforerrors when corrected value is valid
  # ==========================================================================
  # Rationale:
  #   The *_checkforerrors variables are generated during the parsing /
  #   reading step when a timestamp string cannot be cleanly interpreted —
  #   they act as a red flag indicating ambiguous or malformed input.
  #   However, once our correction logic has successfully produced a valid
  #   (non-NA) POSIXct value in the corresponding *_corrected column, the
  #   original parse-time warning is no longer actionable: a usable time
  #   was extracted despite the messy input.  Clearing the flag prevents
  #   downstream filters from discarding an otherwise valid record.
  checkforerrors_pairs <- list(
    list(raw = "time_bed_am_checkforerrors", corrected = "time_bed_corrected"),
    list(raw = "time_sleep_am_checkforerrors", corrected = "time_sleep_corrected"),
    list(raw = "time_awake_am_checkforerrors", corrected = "time_awake_corrected"),
    list(raw = "time_getup_am_checkforerrors", corrected = "time_getup_corrected")
  )

  for (pair in checkforerrors_pairs) {
    if (pair$raw %in% names(cleaned_data)) {
      valid_mask <- !is.na(cleaned_data[[pair$corrected]])
      cleaned_data[[pair$raw]][valid_mask] <- NA_character_
    }
  }

  # ==========================================================================
  # Section 12: Return cleaned data
  # ==========================================================================
  # The cleaned_data dataframe is returned with all original columns intact
  # plus the derived columns (*_corrected, corrected, correction_type, etc.).
  # Downstream code should use the *_corrected columns for analysis.
  return(cleaned_data)
}

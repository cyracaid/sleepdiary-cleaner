library(lubridate)
library(tidyverse)
library(stringi)
library(dplyr)

# ============================================================================
# FUNCTION: process_timestamp — Parse raw time strings to datetime objects
# ============================================================================
# PURPOSE:
#   The EMA survey records times as separate hour+minute and AM/PM columns
#   (e.g., time_bed_am_hhmm = "10:30", time_bed_am_ampm = "PM").
#   This function combines them into a proper POSIXct date-time.
#
# WHAT IT HANDLES:
#   - Non-standard separators (periods, semicolons)
#   - Single-digit hours ("7:30" → "07:30")
#   - Hours without minutes ("10" → "10:00")
#   - 24-hour format detection (hours > 12 mean no AM/PM conversion)
#   - The only AM/PM note flagged in *_checkforerrors column:
#     * Evening vars (bed/sleep) marked PM with hour=12 → midnight (converted to AM)
#     * Hour > 24 → invalid entry
# NOTE: Early-morning times (01:00-05:59) are correctly AM, not errors.
#       These were previously flagged as "likely PM" but that was a false positive.
#       Removed 2026-05-28 per Round 2 screening. See work log for details.
#
# OUTPUT (per variable, e.g., time_bed_am):
#   time_bed_am_hhmm_ampm    — POSIXct date-time (combined with StartDate)
#   time_bed_am_checkforerrors — text description of any parsing issue
# ============================================================================

process_timestamp <- function(df, varname, format) {
  
  
  if(format=="timestamp") {
    tstamp.varname <- paste0(varname, "_hhmm")
    ampm.varname <- paste0(varname, "_ampm")
    
    if (!(tstamp.varname %in% names(df))) {
      return(df)
    }
    if (!(ampm.varname %in% names(df))) {
      return(df)
    }
    
    # Coerce hour:minute values to clean "HH:MM" character strings
    tstamp.varname.cstr <- vector(mode = "character", length = dim(df)[1])
    
    # Handle special data types (hms, difftime) before processing
    if (is.logical(df[[tstamp.varname]])) {
      df[[tstamp.varname]] <- NA_character_
    } else if (inherits(df[[tstamp.varname]], "hms") || inherits(df[[tstamp.varname]], "difftime")) {
      df[[tstamp.varname]] <- format(df[[tstamp.varname]], "%H:%M")
    } else {
      df[[tstamp.varname]] <- as.character(df[[tstamp.varname]])
    }
    
    # Clean each row: replace separators, pad single-digit hours
    for (m in 1:dim(df)[1]) {
      df[m,tstamp.varname] <- gsub("\\.", ":", df[m,tstamp.varname])
      df[m,tstamp.varname] <- gsub(";", ":", df[m,tstamp.varname])
      
      if (grepl(":", df[m,tstamp.varname])==TRUE) {
        if (grepl("^[0-9][0-9]:", df[m,tstamp.varname])==TRUE) {
          tstamp.varname.cstr[m] <- paste0(df[m,tstamp.varname])
        } else if (grepl("^[0-9]:", df[m,tstamp.varname])==TRUE) {
          tstamp.varname.cstr[m] <- paste0("0", df[m,tstamp.varname])
        }
      } else if (is.na(df[m,tstamp.varname])==TRUE) {
        tstamp.varname.cstr[m] <- NA
      } else if (grepl(":{1}", df[m,tstamp.varname])==FALSE) {
        if ((nchar(df[m,tstamp.varname])==2)==TRUE) {
          tstamp.varname.cstr[m] <- paste0(df[m,tstamp.varname], ":00")
        } else if ((nchar(df[m,tstamp.varname])==1)==TRUE) {
          tstamp.varname.cstr[m] <- paste0("0", df[m,tstamp.varname], ":00")
        }
      }
    }
    
    # Combine hour+minute with AM/PM, detect 24-hour format usage
    concat.tstamp.ampm.cstr = data.frame(tstamp.varname.cstr, stringsAsFactors = FALSE)
    concat.tstamp.ampm.cstr[[ampm.varname]] <- df[, ampm.varname]
    
    concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
      mutate(!!paste0(varname, "_hhmm_orig") := tstamp.varname.cstr) %>%
      separate(col = !!paste0(varname, "_hhmm_orig"), into = c(paste0(varname, "_h"), paste0(varname, "_m")), sep = ":", fill = "right", extra = "drop") %>%
      mutate(!!paste0(varname, "_h_num") := as.numeric(!!sym(paste0(varname, "_h")))) %>% 
      mutate(!!paste0(varname, "_used24h") := (!!sym(paste0(varname, "_h_num")) > 12 | !!sym(paste0(varname, "_h_num")) == 0)) %>%
      mutate(!!paste0(varname, "_24h_ampm_correct") := (!!sym(ampm.varname)=="PM") & (!!sym(paste0(varname, "_used24h"))==TRUE)) %>%
      mutate(!!paste0(varname, "_24h_ampm_correct") := case_when(
        (!!sym(ampm.varname)=="AM") & (!!sym(paste0(varname, "_h_num")) == 0) & (!!sym(paste0(varname, "_used24h"))==TRUE) ~ TRUE,
        TRUE ~ !!sym(paste0(varname, "_24h_ampm_correct"))
      ))
    
    concat.tstamp.ampm.cstr[which(is.na(concat.tstamp.ampm.cstr[ , paste0(varname, "_h")])), paste0(varname, "_used24h")] <- NA
    
    concat.tstamp.ampm.cstr[which(concat.tstamp.ampm.cstr[, paste0(varname, "_used24h")] == FALSE), paste0(varname, "_24h_ampm_correct")] <- NA
    concat.tstamp.ampm.cstr[which(is.na(concat.tstamp.ampm.cstr[, paste0(varname, "_used24h")])== TRUE), paste0(varname, "_24h_ampm_correct")] <- NA
    
    # Convert 24h times to 12h: subtract 12 from hours > 12 so AM/PM logic works
    concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
      mutate(!!as.symbol(paste0(varname, "_h_num_correct")) := !!as.symbol(paste0(varname, "_h_num")),
             !!as.symbol(paste0(varname, "_h_correct")) := as.character(!!as.symbol(paste0(varname, "_h_num_correct"))),
             !!as.symbol(paste0(varname, "_h_othererrors")) := NA) 
    
    for (r in 1:dim(concat.tstamp.ampm.cstr)[1]) {
      if (is.na(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")])==TRUE) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h")] <- NA
      } else if (concat.tstamp.ampm.cstr[r, paste0(varname, "_used24h")] == TRUE & concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")] != 0 ) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")] <- concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")] - 12
      } else if ( (varname %in% c("time_bed_am", "time_sleep_am")) & (concat.tstamp.ampm.cstr[r, paste0(ampm.varname)] == "PM") & (concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")] == 12) & (concat.tstamp.ampm.cstr[r, paste0(varname, "_used24h")] == FALSE) ) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")] <- concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")]
        concat.tstamp.ampm.cstr[r, paste0(ampm.varname)] <- "AM"
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_othererrors")] <- "evening var h=12 marked PM (likely AM)"
      }
      
      # Flag hours > 24 as impossible
      if (is.na(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")])==TRUE) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_othererrors")] <- NA
      } else if (concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")] >24) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_othererrors")] <- "h>24" 
      }
      
      # Pad hour to 2 digits for final string
      if (is.na(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")])==TRUE) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_correct")] <- NA
      } else if ((nchar(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")])==1)==TRUE) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_correct")] <- paste0("0", as.character(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")]))
      } else {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_correct")] <- as.character(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")])
      }
    }
    
    # No flag needed: AM/PM assignment is correct for valid times.
    # Early-morning bed/sleep (01:00-05:59) are correctly marked as AM.
    # Early-morning awake/getup hours (04:00-11:59) are correctly marked as AM.
    # The parser heuristic of flagging these as "likely PM" produced false positives.
    # (See 2026-05-28 work log: format-level vs content-level screening tiers.)
    
    # Build final "HH:MM AM/PM" string
    concat.tstamp.ampm.cstr <- concat.tstamp.ampm.cstr %>%
      mutate(!!paste0(varname, "_hhmm_ampm") := paste0(!!sym(paste0(varname, "_h_correct")), ":", !!sym(paste0(varname, "_m")), " ", !!sym(ampm.varname)))
    
    concat.tstamp.ampm.cstr[which(concat.tstamp.ampm.cstr[, paste0(varname, "_hhmm_ampm")] == "NA:NA NA"), paste0(varname, "_hhmm_ampm")] <- NA
    concat.tstamp.ampm.cstr[which(grepl("NA", concat.tstamp.ampm.cstr[, paste0(varname, "_hhmm_ampm")]) == TRUE), paste0(varname, "_hhmm_ampm")] <- NA
    
    tstamp.hhmmampm.varname <- concat.tstamp.ampm.cstr[, paste0(varname, "_hhmm_ampm")]
    
    if (dim(df)[1]==dim(concat.tstamp.ampm.cstr)[1]) {
      df_timeproc = df %>%
        mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := tstamp.hhmmampm.varname)
    } else {
      return(df)
    }
    
    # Attach date to create full POSIXct (combine HH:MM AM/PM with StartDate)
    df_timeproc = df_timeproc %>% 
      mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := paste0(substr(StartDate, 1, 10), " ", !!as.symbol(paste0(varname, "_hhmm_ampm"))))
    
    tstamp.hhmmampm.varname.isna <- which(is.na(tstamp.hhmmampm.varname))
    df_timeproc[tstamp.hhmmampm.varname.isna, paste0(varname, "_hhmm_ampm")] <- NA
    
    # Convert to proper date-time object
    df_timeproc = df_timeproc %>% 
      mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := lubridate::parse_date_time(!!as.symbol(paste0(varname, "_hhmm_ampm")), "%Y-%m-%d %H:%M %p", tz = "US/Pacific"))
    
    # Evening variables (bed/sleep): if parsed time > 15:00 (3 PM), subtract one day
    # so bedtimes after midnight map to the correct date
    if (varname %in% c("time_bed_am", "time_sleep_am")) {
      df_timeproc = df_timeproc %>%
        mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~ifelse(lubridate::hour(.) > 15, .-lubridate::days(1), .)) %>%
        mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~as_datetime(., tz="America/Los_Angeles")) 
    }

    # Save parsing issues to *_checkforerrors column for downstream error detection
    df_timeproc = df_timeproc %>% 
      mutate(!!paste0(varname, "_checkforerrors") := concat.tstamp.ampm.cstr[[paste0(varname, "_h_othererrors")]])
    
    rm(concat.tstamp.ampm.cstr, tstamp.varname.cstr, tstamp.hhmmampm.varname, tstamp.varname, ampm.varname)
    
    return(df_timeproc)
  }
  
  return(df_timeproc)
}

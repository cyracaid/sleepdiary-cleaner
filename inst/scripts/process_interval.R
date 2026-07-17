library(lubridate)
library(tidyverse)
library(stringi)

# ---------------------------------------------------------------------------
# HELPER: insert_char_at_position
# ---------------------------------------------------------------------------
# This is a small utility that inserts a character (like ":") into a string
# at a specific position. For example, if you have "1234" and want to turn
# it into "12:34", you call insert_char_at_position("1234", pos = 2, insert = ":").
# 
# How it works:
#   - It uses a "regular expression" to grab everything up to position {pos}
#     as one piece, and everything after that position as a second piece.
#   - Then it re-assembles them with the {insert} text in between.
# ---------------------------------------------------------------------------
insert_char_at_position <- function(x, pos, insert) {       
  gsub(paste0("^(.{", pos, "})(.*)$"),
       paste0("\\1", insert, "\\2"),
       x)
}

format_total_minutes_hhmm <- function(total_minutes) {
  hours <- floor(total_minutes / 60)
  minutes <- total_minutes - (hours * 60)
  if (is.na(minutes)) {
    return(NA_character_)
  }
  if (abs(minutes - round(minutes)) < 1e-8) {
    return(sprintf("%02d:%02d", hours, round(minutes)))
  }
  minute_text <- sub("\\.?0+$", "", sprintf("%.6f", minutes))
  paste0(sprintf("%02d:", hours), minute_text)
}


# ===========================================================================
# MAIN FUNCTION: process_interval
# ===========================================================================
# PURPOSE:
#   This function takes a column of interval / duration values from a data
#   frame and tries to convert them into a number of minutes (e.g. "01:30"
#   becomes 90 minutes, "90" becomes 90 minutes, ".5" becomes 30 minutes).
#
#   It handles many common "messy" entries that people type — like "90" when
#   they mean 90 minutes, or "30.00" when they meant "30:00", or "120" when
#   they actually meant 1 hour and 20 minutes.
#
#   The function keeps track of what corrections it made and flags values
#   that still need a human to check.
#
# PARAMETERS:
#   df      - a data frame
#   varname - the name of the column that contains the interval strings
#   format  - the type of format; currently only "interval_hhmm" is used
#
# RETURNS:
#   The original data frame with new columns added:
#     - {varname}_mincalc      : the calculated minutes (numeric)
#     - {varname}_checkforerrors : TRUE/FALSE — does a human need to look?
#     - {varname}_correctionsmade : a text log of what was fixed
#   The original {varname} column is also replaced with the cleaned-up
#   version of the interval strings.
# ===========================================================================
process_interval<- function(df, varname, format) {
  
  # -------------------------------------------------------------------------
  # If the entire column is already NA, there is nothing to do — return
  # the data frame as-is.
  # -------------------------------------------------------------------------
  if (all(is.na(df[[varname]]))) {
    return(df)
  }
  
  if(format == "interval_hhmm") {
    
    # -----------------------------------------------------------------------
    # SETUP: Create a working data frame
    # -----------------------------------------------------------------------
    # We pull out the column of interest into a temporary data frame so we
    # can safely modify it row by row without affecting the original until
    # we are done.
    # -----------------------------------------------------------------------
    interval_working_df <- data.frame(
      temp_col = df[[varname]],
      stringsAsFactors = FALSE
    )
    names(interval_working_df)[1] <- varname
    
    # Add two tracking columns:
    #   "corrections"       — a text description of what, if anything, was fixed
    #   "needs_manual_check" — a flag that tells us a human should verify this
    interval_working_df <- interval_working_df %>%
      mutate(
        corrections = NA_character_, 
        needs_manual_check = NA
      )
    
    # Make sure everything is treated as plain text (character strings)
    df[[varname]] = as.character(df[[varname]])
    interval_working_df[[varname]] = as.character(interval_working_df[[varname]])
    
    # -----------------------------------------------------------------------
    # MAIN LOOP: Process each value one at a time
    # -----------------------------------------------------------------------
    for (j in 1:dim(interval_working_df)[1]) {
      
      current_corrections <- character(0)
      current_value <- interval_working_df[[varname]][j]
      
      # --- Skip if the value is missing or empty ---------------------------
	      if (is.na(current_value) || current_value == "" || current_value == "NA") {
	        interval_working_df[j, varname] <- NA
	        interval_working_df$corrections[j] <- paste(c(current_corrections, "NA value"), collapse = "; ")
	        next
	      }
	      current_value <- trimws(current_value)
	      if (current_value == "") {
	        interval_working_df[j, varname] <- NA
	        interval_working_df$corrections[j] <- paste(c(current_corrections, "NA value"), collapse = "; ")
	        next
	      }
	      
	      # --- Basic, low-level cleaning of common typos -----------------------
      # Replace semicolons with colons  (e.g. "01;30" → "01:30")
      # Replace periods with colons      (e.g. "01.30" → "01:30")
      # Replace "p" or "P" with "0"      (possibly a mis-typed zero)
	      if (!is.na(current_value)) {
	        if (grepl("^[0-9]*\\.[0-9]+$", current_value)) {
	          integer_part <- sub("\\..*$", "", current_value)
	          decimal_part <- sub("^[0-9]*\\.", "", current_value)
	          if (grepl("^\\.[0-9]+$", current_value) || integer_part == "0" ||
	              nchar(decimal_part) != 2) {
	            total_minutes <- as.numeric(current_value) * 60
	            interval_working_df[j, varname] <- format_total_minutes_hhmm(total_minutes)
	            current_corrections <- c(current_corrections, "decimal hours -> minutes")
	            interval_working_df$corrections[j] <- paste(current_corrections, collapse = "; ")
	            next
	          }
	        }
	        current_value <- gsub(";", ":", current_value)
	        current_value <- gsub("\\.", ":", current_value)
	        current_value <- gsub("p|P", "0", current_value, ignore.case = TRUE)
	      }

      # --- Skip if the value contains only unhandled letters ---------------
      # This check happens after the p/P -> 0 cleanup so a lone "P" can be
      # interpreted as zero instead of becoming a false positive.
      if (grepl("^[a-z]+$", current_value, ignore.case = TRUE)) {
        interval_working_df[j, varname] <- NA
        interval_working_df$corrections[j] <- paste(c(current_corrections, "letters only"), collapse = "; ")
        next
      }
      
      # =====================================================================
      # BRANCH 1: Value already looks like "dd:dd" (two digits, colon, two
      #           digits — e.g. "01:30", "12:00")
      # =====================================================================
	      if (grepl("^[0-9]{1,2}:[0-9]{2,}$", current_value)) {
	        parts <- strsplit(current_value, ":")[[1]]
	        hours <- as.numeric(parts[1])
	        minutes <- as.numeric(parts[2])
	        if (!is.na(minutes) && minutes >= 60) {
	          if (nchar(parts[2]) > 3) {
	            interval_working_df[j, varname] <- current_value
	            interval_working_df$needs_manual_check[j] <- TRUE
	            current_corrections <- c(current_corrections, "minute field too long, manual check")
	            interval_working_df$corrections[j] <- paste(current_corrections, collapse = "; ")
	            next
	          }
	          corrected_value <- format_total_minutes_hhmm((hours * 60) + minutes)
	          interval_working_df[j, varname] <- corrected_value
	          current_corrections <- c(current_corrections, "minute overflow normalized")
	          interval_working_df$corrections[j] <- paste(current_corrections, collapse = "; ")
	          next
	        }
	      }

	      if (grepl("^[0-9]{1,2}:[0-9]{1,2}$", current_value) &&
	          !grepl("^[0-9]{2}:[0-9]{2}$", current_value)) {
	        parts <- strsplit(current_value, ":")[[1]]
	        interval_working_df[j, varname] <- paste0(
	          sprintf("%02d", as.numeric(parts[1])),
	          ":",
	          sprintf("%02d", as.numeric(parts[2]))
	        )
	        current_corrections <- c(current_corrections, "h/m padded")
	        interval_working_df$corrections[j] <- paste(current_corrections, collapse = "; ")
	        next
	      }
	
	      if (grepl("^[0-9]{2}:[0-9]{2}$", current_value)) {
	        parts <- strsplit(current_value, ":")[[1]]
	        hours <- as.numeric(parts[1])
	        minutes <- as.numeric(parts[2])
        
        # --- "dd:00" → "00:dd" conversion --------------------------------
        # If the first number is 10 or greater AND the second number is 0,
        # it looks like someone swapped hours and minutes. For example:
        #   "30:00" probably means 30 minutes, NOT 30 hours.
        # We flip it around to "00:30" so the rest of the code treats it
        # correctly as 30 minutes.
        # -----------------------------------------------------------------
        if (hours >= 10 && minutes == 0) {
          corrected_value <- paste0("00:", sprintf("%02d", hours))
          interval_working_df[j, varname] <- corrected_value
          current_corrections <- c(current_corrections, "dd:00 \u2192 00:dd")
        } else {
          interval_working_df[j, varname] <- current_value
        }
        
        if (length(current_corrections) > 0) {
          interval_working_df$corrections[j] <- paste(current_corrections, collapse = "; ")
        }
        next
      }
      
      # =====================================================================
      # BRANCH 2: No colon at all — the value is just a plain number
      # =====================================================================
      # The tricky part: is "90" meant as 90 minutes, or 90 hours? We have
      # to guess based on how many digits there are.
      # =====================================================================
      else if (!grepl(":", current_value)) {
        
        # --- 5 or more digits (e.g. "12345") ------------------------------
        # We cannot safely interpret this, so it gets flagged for a human.
        if (grepl("^[0-9]{5,}$", current_value)) {
          interval_working_df[j, varname] <- current_value
          interval_working_df$needs_manual_check[j] <- TRUE
          current_corrections <- c(current_corrections, "5+ digits, manual check")
        }
        
        # --- Exactly 4 digits (e.g. "1234") -------------------------------
        # This looks like someone dropped the colon. We assume the first two
        # digits are the hour and the last two are the minutes.
        #   "1234" → "12:34"
        else if (grepl("^[0-9]{4}$", current_value)) {
          interval_working_df[j, varname] <- insert_char_at_position(current_value, pos = 2, insert = ":")
          current_corrections <- c(current_corrections, "dddd")
        }
        
        # --- Exactly 3 digits (e.g. "120", "000") -------------------------
        # "000" is easy — it means zero. Anything else is ambiguous and
        # gets flagged.
        else if (grepl("^[0-9]{3}$", current_value)) {
          if (current_value == "000") {
            interval_working_df[j, varname] <- "00:00"
            current_corrections <- c(current_corrections, "000")
          } else {
            interval_working_df[j, varname] <- current_value
            interval_working_df$needs_manual_check[j] <- TRUE
            current_corrections <- c(current_corrections, "3 digits, manual check")
          }
        }
        
        # --- Exactly 2 digits (e.g. "30", "90", "00") --------------------
        # We assume these are minutes (not hours). "00" → "00:00".
        # Everything else becomes "00:XX" and gets flagged for review in
        # case it was actually meant to be hours (e.g. "12" could be 12
        # hours, not 12 minutes).
        else if (nchar(current_value) == 2) {
          if (current_value == "00") {
            interval_working_df[j, varname] <- "00:00"
            current_corrections <- c(current_corrections, "00")
          } else {
            interval_working_df[j, varname] <- paste0("00:", current_value)
            interval_working_df$needs_manual_check[j] <- TRUE
            current_corrections <- c(current_corrections, "dd, min assumed")
          }
        }
        
        # --- Exactly 1 digit (e.g. "5", "0") -----------------------------
        # We assume these are minutes. "0" → "00:00", everything else is
        # "00:0X" and flagged.
        else if (nchar(current_value) == 1) {
          if (current_value == "0") {
            interval_working_df[j, varname] <- "00:00"
            current_corrections <- c(current_corrections, "converted 0 to 00:00")
          } else {
            interval_working_df[j, varname] <- paste0("00:0", current_value)
            interval_working_df$needs_manual_check[j] <- TRUE
            current_corrections <- c(current_corrections, "d, min assumed")
          }
        }
        
        # --- Anything else that has no colon -----------------------------
        # Edge case we did not anticipate — flag it.
        else {
          interval_working_df[j, varname] <- current_value
          interval_working_df$needs_manual_check[j] <- TRUE
          current_corrections <- c(current_corrections, "other unhandled case")
        }
        
        if (length(current_corrections) > 0) {
          interval_working_df$corrections[j] <- paste(current_corrections, collapse = "; ")
        }
        next
      }
      
      # =====================================================================
      # BRANCH 3: Has a colon, but does NOT match clean "dd:dd" — so the
      #           format is off in some way (extra/missing digits, extra
      #           colon, leading "0:", trailing ":", etc.).
      # =====================================================================
        else {
        # --- Pattern "d:d:dd" (single-digit hour, single-digit minute,
        #      two-digit minute — e.g. "1:2:30" → remove extra colon)
        # ---------------------------------------------------------------
        if (grepl("^[0-9]{1}:[0-9]{1}:[0-9]{2}$", current_value)) {
          interval_working_df[j, varname] <- str_replace(current_value, ":", "")
          current_corrections <- c(current_corrections, "d:d:dd")
        }

        # --- Pattern ":d" or ":dd" — leading colon means zero hours.
        #      In nap/exercise duration fields, ":45" is a common shorthand
        #      for "00:45" (45 minutes), not an error.
        else if (grepl("^:[0-9]{1,2}$", current_value)) {
          minutes <- sub("^:", "", current_value)
          interval_working_df[j, varname] <- paste0("00:", sprintf("%02d", as.numeric(minutes)))
          current_corrections <- c(current_corrections, ":d/:dd -> 00:dd")
        }

        # --- Pattern "00:000" — extra trailing zero in an all-zero duration.
        #      Treat it as "00:00" instead of sending it to manual review.
        else if (grepl("^00:000$", current_value)) {
          interval_working_df[j, varname] <- "00:00"
          current_corrections <- c(current_corrections, "00:000 -> 00:00")
        }

        # --- Pattern "000:dd" — extra leading zero before a minute duration.
        #      Example: "000:45" means 45 minutes.
        else if (grepl("^000:[0-9]{2}$", current_value)) {
          minutes <- sub("^000:", "", current_value)
          interval_working_df[j, varname] <- paste0("00:", minutes)
          current_corrections <- c(current_corrections, "000:dd -> 00:dd")
        }
        
        # --- Exactly 5 characters long — there are many possible
        #      sub-patterns to check (leading colon, trailing colon,
        #      "d:ddd", "ddd:d", etc.).
        # ---------------------------------------------------------------
        else if (nchar(current_value) == 5) {
          value <- current_value
          
          # Pattern ":dddd" — colon at the front
          if (grepl("^:[0-9]{4}$", value)) {
            digits <- substr(value, 2, 5)
            first_two <- substr(digits, 1, 2)
            last_two <- substr(digits, 3, 4)
            
            if (digits == "0000") {
              interval_working_df[j, varname] <- "00:00"
              interval_working_df[j, "corrections"] <- ":0000, all zeros"
            } else if (first_two == "00") {
              interval_working_df[j, varname] <- paste0("00:", last_two)
              interval_working_df[j, "corrections"] <- ":00dd, valid minutes"
            } else if (last_two == "00") {
              interval_working_df[j, varname] <- paste0(first_two, ":00")
              interval_working_df[j, "corrections"] <- ":dd00, valid hours"
            } else {
              interval_working_df[j, varname] <- paste0(first_two, ":", last_two)
              interval_working_df[j, "corrections"] <- ":dddd, valid time format"
            }
            
          # Pattern "d:ddd" — one digit, colon, three digits (e.g. "1:230")
          } else if (grepl("^[0-9]{1}:[0-9]{3}$", value)) {
            parts <- strsplit(value, ":")[[1]]
            hour <- parts[1]
            minutes <- parts[2]
            interval_working_df[j, varname] <- paste0(sprintf("%02d", as.numeric(hour)), ":", substr(minutes,1,2))
            interval_working_df[j, "corrections"] <- "d:ddd, reformatted"
            
          # Pattern "ddd:d" — three digits, colon, one digit (e.g. "123:4")
          } else if (grepl("^[0-9]{3}:[0-9]{1}$", value)) {
            parts <- strsplit(value, ":")[[1]]
            hours <- parts[1]
            minute <- parts[2]
            main_hours <- floor(as.numeric(hours)/10)
            sub_minutes <- as.numeric(hours) %% 10
            interval_working_df[j, varname] <- paste0(sprintf("%02d", main_hours), ":", sprintf("%02d", sub_minutes))
            interval_working_df[j, "corrections"] <- "ddd:d, reformatted"
            
          # Pattern "dddd:" — trailing colon (e.g. "1234:")
          } else if (grepl("^[0-9]{4}:$", value)) {
            digits <- substr(value, 1, 4)
            interval_working_df[j, varname] <- paste0(substr(digits,1,2), ":", substr(digits,3,4))
            interval_working_df[j, "corrections"] <- "dddd:, reformatted"
            
          # Pattern "0:dd:dd" — leading zero and an extra colon (e.g. "0:12:30")
          } else if (grepl("^0:[0-9]{2}:[0-9]{2}$", value)) {
            time_part <- sub("^0:", "", value)
            interval_working_df[j, varname] <- time_part
            interval_working_df[j, "corrections"] <- "0:dd:dd, removed leading 0:"
            
          # Pattern "dd:dd" — this is actually a valid format, but it was
          # not caught by Branch 1 (maybe due to extra spaces or leading 0
          # issues). Apply the same dd:00 → 00:dd logic here.
          } else if (grepl("^[0-9]{2}:[0-9]{2}$", value)) {
            parts <- strsplit(value, ":")[[1]]
            first_dd <- as.numeric(parts[1])
            second_dd <- as.numeric(parts[2])
            
            if (first_dd >= 10 && second_dd == 0) {
              interval_working_df[j, varname] <- paste0("00:", sprintf("%02d", first_dd))
              interval_working_df[j, "corrections"] <- "dd:00 \u2192 00:dd, converted to minutes"
            } else {
              interval_working_df[j, varname] <- value
              interval_working_df[j, "corrections"] <- "dd:dd, valid format"
            }
            
          # Fallback: any other 5-character value — split it into two pairs
          # of digits and insert a colon in the middle.
          } else {
            digits <- value
            interval_working_df[j, varname] <- paste0(substr(digits,1,2), ":", substr(digits,3,4))
            interval_working_df[j, "corrections"] <- "5char, reformatted"
          }
        }
        
        # --- Everything else with a colon that we could not handle --------
        else {
          interval_working_df[j, varname] <- current_value
          interval_working_df$needs_manual_check[j] <- TRUE
          current_corrections <- c(current_corrections, "colon but wrong format")
        }
        
        if (length(current_corrections) > 0) {
          interval_working_df$corrections[j] <- paste(current_corrections, collapse = "; ")
        }
        next
      }
    }
    
    # -----------------------------------------------------------------------
    # FINAL CALCULATION: Convert cleaned "hh:mm" strings into total minutes
    # -----------------------------------------------------------------------
    # Two scenarios:
    #
    # Scenario A — All values are NA or none of them contain a colon:
    #   There is nothing meaningful to split, so we create placeholder
    #   columns with NA values.
    #
    # Scenario B — At least one value has a colon:
    #   We split the "hh:mm" string into hours and minutes, convert them
    #   to numbers, then calculate total minutes:
    #     total_minutes = (hours × 60) + minutes
    # -----------------------------------------------------------------------
    if (all(is.na(interval_working_df[[varname]])) || 
        !any(grepl(":", interval_working_df[[varname]]), na.rm = TRUE)) {
      duration_calculations = data.frame(
        varname = interval_working_df[[varname]],
        corrections = interval_working_df$corrections,
        needs_manual_check = interval_working_df$needs_manual_check,
        stringsAsFactors = FALSE
      ) %>%
        mutate(!!as.symbol(paste0(varname, "_unsep")) := varname,
               !!as.symbol(paste0(varname, "_h")) := NA_character_,
               !!as.symbol(paste0(varname, "_m")) := NA_character_,
               !!as.symbol(paste0(varname, "_h_num")) := NA_real_,
               !!as.symbol(paste0(varname, "_m_num")) := NA_real_,
               !!as.symbol(paste0(varname, "_mincalc")) := NA_real_)
    } else {
      duration_calculations = data.frame(
        temp_col = interval_working_df[, varname],
        corrections = interval_working_df[, "corrections"], 
        needs_manual_check = interval_working_df[, "needs_manual_check"],
        stringsAsFactors = FALSE
      ) %>%
        rename(!!varname := temp_col) %>%
        mutate(!!as.symbol(paste0(varname, "_unsep")) := !!as.symbol(varname)) %>%
        separate(col = !!varname, into = c(paste0(varname, "_h"), paste0(varname, "_m")), sep = ":") %>%
        mutate(!!as.symbol(paste0(varname, "_h_num")) := as.numeric(!!as.symbol((paste0(varname, "_h"))))) %>%
        mutate(!!as.symbol(paste0(varname, "_m_num")) := as.numeric(!!as.symbol((paste0(varname, "_m"))))) %>%
        mutate(!!as.symbol(paste0(varname, "_mincalc")) := (!!as.symbol((paste0(varname, "_h_num")))*60) + !!as.symbol((paste0(varname, "_m_num"))))
    }
    
    # Sleep metric duration fields have one recurring edge case: participants
    # sometimes type MM:SS-like values into SOL/WASO duration fields. A value
    # such as "10:30" should be 10.5 minutes in that context, not 630 minutes.
    # Keep ordinary long SOL values such as "01:30" as HH:MM; only reinterpret
    # the implausible tail where HH:MM would be at least 4 hours.
    if (grepl("duration_totalmin_sol_estimate_am|duration_totalmin_waso_estimate_am", varname)) {
      h_col <- paste0(varname, "_h_num")
      m_col <- paste0(varname, "_m_num")
      min_col <- paste0(varname, "_mincalc")

      if (all(c(h_col, m_col, min_col) %in% names(duration_calculations))) {
        hh <- duration_calculations[[h_col]]
        mm <- duration_calculations[[m_col]]
        mincalc <- duration_calculations[[min_col]]
        mmss_recode <- !is.na(hh) & !is.na(mm) & !is.na(mincalc) &
          hh > 0 & hh <= 59 & mm >= 0 & mm < 60 & mincalc >= 240

        if (any(mmss_recode, na.rm = TRUE)) {
          duration_calculations[[min_col]][mmss_recode] <- hh[mmss_recode] + (mm[mmss_recode] / 60)
          recode_note <- "sleep metric duration MM:SS threshold conversion"
          existing_notes <- duration_calculations$corrections[mmss_recode]
          duration_calculations$corrections[mmss_recode] <- ifelse(
            is.na(existing_notes) | existing_notes == "",
            recode_note,
            paste(existing_notes, recode_note, sep = "; ")
          )
        }
      }
    }

    # -----------------------------------------------------------------------
    # FINAL ASSEMBLY: Attach the results back onto the original data frame
    # -----------------------------------------------------------------------
    # We add three new columns:
    #   {varname}_mincalc        — the calculated total minutes
    #   {varname}_checkforerrors  — whether a human should review this value
    #   {varname}_correctionsmade — a log of any corrections that were applied
    #
    # For nap/exercise variables, a format cleanup alone is not a review-worthy
    # error. Values such as "0:30" or "1:30" are common and parse cleanly.
    # Keep the correction note for audit, but only flag structural anomalies.
    # -----------------------------------------------------------------------
    review_flags <- duration_calculations[, "needs_manual_check"]
    if (grepl("duration_totalmin_sol_estimate_am|duration_totalmin_waso_estimate_am|duration_totalmin_napstoday_PM|exercisetoday_PM_totalmin_", varname)) {
      mincalc <- duration_calculations[, paste0(varname, "_mincalc")]
      raw_nonmissing <- !is.na(df[[varname]]) & trimws(as.character(df[[varname]])) != ""
	      correction_text <- duration_calculations[, "corrections"]
	      unresolved_manual <- (duration_calculations[, "needs_manual_check"] %in% TRUE) &
	        !grepl("^(d, min assumed|dd, min assumed)$", correction_text)
	      mincalc[unresolved_manual] <- NA_real_
	      duration_calculations[, paste0(varname, "_mincalc")] <- mincalc
	      structural_flag <- unresolved_manual |
	        (!is.na(mincalc) & mincalc < 0) |
	        (!is.na(mincalc) & mincalc > 10000) |
        (grepl("duration_totalmin_sol_estimate_am", varname) & !is.na(mincalc) & mincalc > 360) |
        (grepl("duration_totalmin_waso_estimate_am", varname) & !is.na(mincalc) & mincalc > 240) |
        (grepl("duration_totalmin_napstoday_PM", varname) & !is.na(mincalc) & mincalc > 720) |
        (grepl("exercisetoday_PM_totalmin_", varname) & !is.na(mincalc) & mincalc > 360) |
        (raw_nonmissing & is.na(mincalc))
      review_flags <- ifelse(is.na(structural_flag), FALSE, structural_flag)
    }

    if (dim(df)[1] == dim(duration_calculations)[1]) {
      data_with_interval_results = df %>%
        mutate(!!as.symbol(paste0(varname, "_mincalc")) := duration_calculations[, paste0(varname, "_mincalc")],
               !!as.symbol(paste0(varname, "_checkforerrors")) := review_flags,
               !!as.symbol(paste0(varname, "_correctionsmade")) := duration_calculations[, "corrections"])
    } else {
      data_with_interval_results = df %>%
        mutate(!!as.symbol(paste0(varname, "_mincalc")) := NA_real_,
               !!as.symbol(paste0(varname, "_checkforerrors")) := NA,
               !!as.symbol(paste0(varname, "_correctionsmade")) := NA_character_)
    }
    
    # Overwrite the original column with the cleaned-up values
    if (exists("interval_working_df")) {
      data_with_interval_results[[varname]] <- interval_working_df[[varname]]
    }
    
    return(data_with_interval_results)
  }
  
  # If the format was not "interval_hhmm", return the data frame unchanged
  return(df)
}

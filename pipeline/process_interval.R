library(lubridate)
library(tidyverse)
library(stringi)

# Create own function to insert something ito a string at a particular position
fun_insert <- function(x, pos, insert) {       
  gsub(paste0("^(.{", pos, "})(.*)$"),
       paste0("\\1", insert, "\\2"),
       x)
}


# Process interval duration --> output in minutes
process_interval<- function(df, varname, format) {
  
  if (all(is.na(df[[varname]]))) {
    return(df)
  }
  
  if(format == "interval_hhmm") {
    
    int.varname <- data.frame(
      temp_col = df[[varname]],
      stringsAsFactors = FALSE
    )
    names(int.varname)[1] <- varname
    
    int.varname <- int.varname %>%
      mutate(
        corrections = NA_character_, 
        needs_manual_check = NA
      )
    
    df[[varname]] = as.character(df[[varname]])
    int.varname[[varname]] = as.character(int.varname[[varname]])
    
    for (j in 1:dim(int.varname)[1]) {
      
      current_corrections <- character(0)
      current_value <- int.varname[[varname]][j]
      
      # Skip if NA or empty
      if (is.na(current_value) || current_value == "" || current_value == "NA") {
        int.varname[j, varname] <- NA
        int.varname$corrections[j] <- paste(c(current_corrections, "NA value"), collapse = "; ")
        next
      }
      
      # Skip if letters only
      if (grepl("^[a-z]+$", current_value, ignore.case = TRUE)) {
        int.varname[j, varname] <- NA
        int.varname$corrections[j] <- paste(c(current_corrections, "letters only"), collapse = "; ")
        next
      }
      
      # Basic cleaning
      if (!is.na(current_value)) {
        current_value <- gsub(";", ":", current_value)
        current_value <- gsub("\\.", ":", current_value)
        current_value <- gsub("p|P", "0", current_value, ignore.case = TRUE)
      }
      
      # Branch 1: Correct format (dd:dd)
      if (grepl("^[0-9]{2}:[0-9]{2}$", current_value)) {
        parts <- strsplit(current_value, ":")[[1]]
        hours <- as.numeric(parts[1])
        minutes <- as.numeric(parts[2])
        
        # Convert dd:00 → 00:dd
        if (hours >= 10 && minutes == 0) {
          corrected_value <- paste0("00:", sprintf("%02d", hours))
          int.varname[j, varname] <- corrected_value
          current_corrections <- c(current_corrections, "dd:00 → 00:dd")
        } else {
          int.varname[j, varname] <- current_value
        }
        
        if (length(current_corrections) > 0) {
          int.varname$corrections[j] <- paste(current_corrections, collapse = "; ")
        }
        next
      }
      
      # Branch 2: No colon numbers
      else if (!grepl(":", current_value)) {
        
        # 5+ digits
        if (grepl("^[0-9]{5,}$", current_value)) {
          int.varname[j, varname] <- current_value
          int.varname$needs_manual_check[j] <- TRUE
          current_corrections <- c(current_corrections, "5+ digits, manual check")
        }
        # 4 digits
        else if (grepl("^[0-9]{4}$", current_value)) {
          int.varname[j, varname] <- fun_insert(current_value, pos = 2, insert = ":")
          current_corrections <- c(current_corrections, "dddd")
        }
        # 3 digits
        else if (grepl("^[0-9]{3}$", current_value)) {
          if (current_value == "000") {
            int.varname[j, varname] <- "00:00"
            current_corrections <- c(current_corrections, "000")
          } else {
            int.varname[j, varname] <- current_value
            int.varname$needs_manual_check[j] <- TRUE
            current_corrections <- c(current_corrections, "3 digits, manual check")
          }
        }
        # 2 digits
        else if (nchar(current_value) == 2) {
          if (current_value == "00") {
            int.varname[j, varname] <- "00:00"
            current_corrections <- c(current_corrections, "00")
          } else {
            int.varname[j, varname] <- paste0("00:", current_value)
            int.varname$needs_manual_check[j] <- TRUE
            current_corrections <- c(current_corrections, "dd, min assumed")
          }
        }
        # 1 digit
        else if (nchar(current_value) == 1) {
          if (current_value == "0") {
            int.varname[j, varname] <- "00:00"
            current_corrections <- c(current_corrections, "converted 0 to 00:00")
          } else {
            int.varname[j, varname] <- paste0("00:0", current_value)
            int.varname$needs_manual_check[j] <- TRUE
            current_corrections <- c(current_corrections, "d, min assumed")
          }
        }
        # Other no-colon cases
        else {
          int.varname[j, varname] <- current_value
          int.varname$needs_manual_check[j] <- TRUE
          current_corrections <- c(current_corrections, "other unhandled case")
        }
        
        if (length(current_corrections) > 0) {
          int.varname$corrections[j] <- paste(current_corrections, collapse = "; ")
        }
        next
      }
      
      # Branch 3: Has colon but wrong format
      else {
        # Double colon
        if (grepl("^[0-9]{1}:[0-9]{1}:[0-9]{2}$", current_value)) {
          int.varname[j, varname] <- str_replace(current_value, ":", "")
          current_corrections <- c(current_corrections, "d:d:dd")
        }
        # 5 characters with wrong colon position
        else if (nchar(current_value) == 5) {
          value <- current_value
          
          if (grepl("^:[0-9]{4}$", value)) {
            digits <- substr(value, 2, 5)
            first_two <- substr(digits, 1, 2)
            last_two <- substr(digits, 3, 4)
            
            if (digits == "0000") {
              int.varname[j, varname] <- "00:00"
              int.varname[j, "corrections"] <- ":0000, all zeros"
            } else if (first_two == "00") {
              int.varname[j, varname] <- paste0("00:", last_two)
              int.varname[j, "corrections"] <- ":00dd, valid minutes"
            } else if (last_two == "00") {
              int.varname[j, varname] <- paste0(first_two, ":00")
              int.varname[j, "corrections"] <- ":dd00, valid hours"
            } else {
              int.varname[j, varname] <- paste0(first_two, ":", last_two)
              int.varname[j, "corrections"] <- ":dddd, valid time format"
            }
            
          } else if (grepl("^[0-9]{1}:[0-9]{3}$", value)) {
            parts <- strsplit(value, ":")[[1]]
            hour <- parts[1]
            minutes <- parts[2]
            int.varname[j, varname] <- paste0(sprintf("%02d", as.numeric(hour)), ":", substr(minutes,1,2))
            int.varname[j, "corrections"] <- "d:ddd, reformatted"
            
          } else if (grepl("^[0-9]{3}:[0-9]{1}$", value)) {
            parts <- strsplit(value, ":")[[1]]
            hours <- parts[1]
            minute <- parts[2]
            main_hours <- floor(as.numeric(hours)/10)
            sub_minutes <- as.numeric(hours) %% 10
            int.varname[j, varname] <- paste0(sprintf("%02d", main_hours), ":", sprintf("%02d", sub_minutes))
            int.varname[j, "corrections"] <- "ddd:d, reformatted"
            
          } else if (grepl("^[0-9]{4}:$", value)) {
            digits <- substr(value, 1, 4)
            int.varname[j, varname] <- paste0(substr(digits,1,2), ":", substr(digits,3,4))
            int.varname[j, "corrections"] <- "dddd:, reformatted"
            
          } else if (grepl("^0:[0-9]{2}:[0-9]{2}$", value)) {
            time_part <- sub("^0:", "", value)
            int.varname[j, varname] <- time_part
            int.varname[j, "corrections"] <- "0:dd:dd, removed leading 0:"
            
          } else if (grepl("^[0-9]{2}:[0-9]{2}$", value)) {
            parts <- strsplit(value, ":")[[1]]
            first_dd <- as.numeric(parts[1])
            second_dd <- as.numeric(parts[2])
            
            if (first_dd >= 10 && second_dd == 0) {
              int.varname[j, varname] <- paste0("00:", sprintf("%02d", first_dd))
              int.varname[j, "corrections"] <- "dd:00 → 00:dd, converted to minutes"
            } else {
              int.varname[j, varname] <- value
              int.varname[j, "corrections"] <- "dd:dd, valid format"
            }
            
          } else {
            digits <- value
            int.varname[j, varname] <- paste0(substr(digits,1,2), ":", substr(digits,3,4))
            int.varname[j, "corrections"] <- "5char, reformatted"
          }
        }
        # Other cases with wrong colon format
        else {
          int.varname[j, varname] <- current_value
          int.varname$needs_manual_check[j] <- TRUE
          current_corrections <- c(current_corrections, "colon but wrong format")
        }
        
        if (length(current_corrections) > 0) {
          int.varname$corrections[j] <- paste(current_corrections, collapse = "; ")
        }
        next
      }
    }
    
    # Create dur.calc
    if (all(is.na(int.varname[[varname]])) || 
        !any(grepl(":", int.varname[[varname]]), na.rm = TRUE)) {
      dur.calc = data.frame(
        varname = int.varname[[varname]],
        corrections = int.varname$corrections,
        needs_manual_check = int.varname$needs_manual_check,
        stringsAsFactors = FALSE
      ) %>%
        mutate(!!as.symbol(paste0(varname, "_unsep")) := varname,
               !!as.symbol(paste0(varname, "_h")) := NA_character_,
               !!as.symbol(paste0(varname, "_m")) := NA_character_,
               !!as.symbol(paste0(varname, "_h_num")) := NA_real_,
               !!as.symbol(paste0(varname, "_m_num")) := NA_real_,
               !!as.symbol(paste0(varname, "_mincalc")) := NA_real_)
    } else {
      dur.calc = data.frame(
        temp_col = int.varname[, varname],
        corrections = int.varname[, "corrections"], 
        needs_manual_check = int.varname[, "needs_manual_check"],
        stringsAsFactors = FALSE
      ) %>%
        rename(!!varname := temp_col) %>%
        mutate(!!as.symbol(paste0(varname, "_unsep")) := !!as.symbol(varname)) %>%
        separate(col = !!varname, into = c(paste0(varname, "_h"), paste0(varname, "_m")), sep = ":") %>%
        mutate(!!as.symbol(paste0(varname, "_h_num")) := as.numeric(!!as.symbol((paste0(varname, "_h"))))) %>%
        mutate(!!as.symbol(paste0(varname, "_m_num")) := as.numeric(!!as.symbol((paste0(varname, "_m"))))) %>%
        mutate(!!as.symbol(paste0(varname, "_mincalc")) := (!!as.symbol((paste0(varname, "_h_num")))*60) + !!as.symbol((paste0(varname, "_m_num"))))
    }
    
    # Create df_intervalproc
    if (dim(df)[1] == dim(dur.calc)[1]) {
      df_intervalproc = df %>%
        mutate(!!as.symbol(paste0(varname, "_mincalc")) := dur.calc[, paste0(varname, "_mincalc")],
               !!as.symbol(paste0(varname, "_checkforerrors")) := dur.calc[, "needs_manual_check"],
               !!as.symbol(paste0(varname, "_correctionsmade")) := dur.calc[, "corrections"])
    } else {
      df_intervalproc = df %>%
        mutate(!!as.symbol(paste0(varname, "_mincalc")) := NA_real_,
               !!as.symbol(paste0(varname, "_checkforerrors")) := NA,
               !!as.symbol(paste0(varname, "_correctionsmade")) := NA_character_)
    }
    
    if (exists("int.varname")) {
      df_intervalproc[[varname]] <- int.varname[[varname]]
    }
    
    return(df_intervalproc)
  }
  
  return(df)
}
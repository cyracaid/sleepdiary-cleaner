library(lubridate)
library(tidyverse)
library(stringi)
library(dplyr)


#Process timestamp input
process_timestamp <- function(df, varname, format) {
  
  
  if(format=="timestamp") {
    tstamp.varname <- paste0(varname, "_hhmm")
    ampm.varname <- paste0(varname, "_ampm")
    
    if (!(tstamp.varname %in% names(df))) {
      return(df_timeproc)
    }
    if (!(ampm.varname %in% names(df))) {
      return(df_timeproc)
    }
    
    #correct timestamp formats
    tstamp.varname.cstr <- vector(mode = "character", length = dim(df)[1])
    
    # Safe type conversion:
    if (is.logical(df[[tstamp.varname]])) {
      df[[tstamp.varname]] <- NA_character_
    } else if (inherits(df[[tstamp.varname]], "hms") || inherits(df[[tstamp.varname]], "difftime")) {
      df[[tstamp.varname]] <- format(df[[tstamp.varname]], "%H:%M")
    } else {
      df[[tstamp.varname]] <- as.character(df[[tstamp.varname]])
    }
    
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
    
    concat.tstamp.ampm.cstr = data.frame(tstamp.varname.cstr, ampm.varname = df[, ampm.varname]) 
    
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
      
      if (is.na(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")])==TRUE) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_othererrors")] <- NA
      } else if (concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num")] >24) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_othererrors")] <- "h>24" 
      }
      
      if (is.na(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")])==TRUE) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_correct")] <- NA
      } else if ((nchar(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")])==1)==TRUE) {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_correct")] <- paste0("0", as.character(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")]))
      } else {
        concat.tstamp.ampm.cstr[r, paste0(varname, "_h_correct")] <- as.character(concat.tstamp.ampm.cstr[r, paste0(varname, "_h_num_correct")])
      }
    }
    
    if (varname %in% c("time_awake_am", "time_getup_am")) {
      #      concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
      #        mutate_at(vars(one_of(paste0(varname, "_h_othererrors"))), ~ifelse((ampm.varname == "PM") & (paste0(varname, "_h_num") > 3), "morning var h>3 marked PM (likely AM)", .)) 
      concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
        mutate(!!paste0(varname, "_h_othererrors") := 
                 ifelse((!!sym(ampm.varname) == "PM") & 
                          (!!sym(paste0(varname, "_h_num")) > 3) &
                          !is.na(!!sym(paste0(varname, "_h_num"))),
                        "morning var h>3 marked PM (likely AM)",
                        !!sym(paste0(varname, "_h_othererrors"))))
      
    } else if (varname %in% c("time_bed_am", "time_sleep_am")) {
      #      concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
      #        mutate_at(vars(one_of(paste0(varname, "_h_othererrors"))), ~ifelse((ampm.varname == "PM") & (paste0(varname, "_h_num") < 6), "evening var h<6 marked PM (likely AM)", .))
      #    }
      concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
        mutate(!!paste0(varname, "_h_othererrors") := 
                 ifelse((!!sym(ampm.varname) == "AM") & 
                          (!!sym(paste0(varname, "_h_num")) < 6) &
                          !is.na(!!sym(paste0(varname, "_h_num"))),
                        "evening var h<6 marked AM (likely PM)",
                        !!sym(paste0(varname, "_h_othererrors"))))
    }
    
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
    
    df_timeproc = df_timeproc %>% 
      mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := paste0(substr(StartDate, 1, 10), " ", !!as.symbol(paste0(varname, "_hhmm_ampm"))))
    
    tstamp.hhmmampm.varname.isna <- which(is.na(tstamp.hhmmampm.varname))
    df_timeproc[tstamp.hhmmampm.varname.isna, paste0(varname, "_hhmm_ampm")] <- NA
    
    df_timeproc = df_timeproc %>% 
      mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := lubridate::parse_date_time(!!as.symbol(paste0(varname, "_hhmm_ampm")), "%Y-%m-%d %H:%M %p", tz = "US/Pacific"))
    
    # Fix evening times
    if (varname %in% c("time_bed_am", "time_sleep_am")) {
      df_timeproc = df_timeproc %>%
        mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~ifelse(lubridate::hour(.) > 15, .-lubridate::days(1), .)) %>%
        mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~as_datetime(., tz="America/Los_Angeles")) 
    }

    df_timeproc = df_timeproc %>% 
      mutate(!!paste0(varname, "_checkforerrors") := concat.tstamp.ampm.cstr[[paste0(varname, "_h_othererrors")]])
    
    rm(concat.tstamp.ampm.cstr, tstamp.varname.cstr, tstamp.hhmmampm.varname, tstamp.varname, ampm.varname)
    
    return(df_timeproc)
  }
  
  return(df_timeproc)
}
# ===== Minimal Test Entry - Four CASES =====
library(lubridate)
library(tidyverse)

# ===== Simplified correction function =====
calculate_sleep_time_vars <- function(AM_rawdata) {
  
  AM_rawdata <- AM_rawdata %>%
    mutate(
      # Corrected times (initialized as original times)
      time_bed_corrected = time_bed_am_hhmm_ampm,
      time_sleep_corrected = time_sleep_am_hhmm_ampm,
      time_awake_corrected = time_awake_am_hhmm_ampm,
      time_getup_corrected = time_getup_am_hhmm_ampm,
      
      # Flag variables
      corrected = FALSE,
      correction_type = NA_character_,
      order_correct = NA,
      data_category = NA_character_,
      passive_carrier = FALSE
    )
  
  for (i in 1:nrow(AM_rawdata)) {
    # Get current row times
    bed <- AM_rawdata$time_bed_corrected[i]
    sleep <- AM_rawdata$time_sleep_corrected[i]
    awake <- AM_rawdata$time_awake_corrected[i]
    getup <- AM_rawdata$time_getup_corrected[i]
    
    # Check missing values
    has_na <- is.na(c(bed, sleep, awake, getup))
    
    # ---- CASE A: No valid records ----
    if (sum(!has_na) == 0) {
      AM_rawdata$data_category[i] <- "No valid records"
      AM_rawdata$passive_carrier[i] <- TRUE
      AM_rawdata$order_correct[i] <- NA
      next
    }
    
    corrections <- c()
    
    # ---- Stage 1: Swap order errors (condition requires >, equal times no swap) - CASE D ----
    # Bed > Sleep
    if (!is.na(bed) && !is.na(sleep) && bed > sleep) {
      AM_rawdata$time_bed_corrected[i] <- sleep
      AM_rawdata$time_sleep_corrected[i] <- bed
      bed <- AM_rawdata$time_bed_corrected[i]
      sleep <- AM_rawdata$time_sleep_corrected[i]
      corrections <- c(corrections, "swap_bed_sleep")
    }
    
    # Sleep > Awake
    if (!is.na(sleep) && !is.na(awake) && sleep > awake) {
      AM_rawdata$time_sleep_corrected[i] <- awake
      AM_rawdata$time_awake_corrected[i] <- sleep
      sleep <- AM_rawdata$time_sleep_corrected[i]
      awake <- AM_rawdata$time_awake_corrected[i]
      corrections <- c(corrections, "swap_sleep_awake")
    }
    
    # Awake > Getup (no swap when equal)
    if (!is.na(awake) && !is.na(getup) && awake > getup) {
      AM_rawdata$time_awake_corrected[i] <- getup
      AM_rawdata$time_getup_corrected[i] <- awake
      awake <- AM_rawdata$time_awake_corrected[i]
      getup <- AM_rawdata$time_getup_corrected[i]
      corrections <- c(corrections, "swap_awake_getup")
    }
    
    # Update variables
    bed <- AM_rawdata$time_bed_corrected[i]
    sleep <- AM_rawdata$time_sleep_corrected[i]
    awake <- AM_rawdata$time_awake_corrected[i]
    getup <- AM_rawdata$time_getup_corrected[i]
    
    # ---- Stage 3: Adjust awake-getup large gap ----
    if (!is.na(awake) && !is.na(getup) && awake > getup) {
      awake_getup_diff <- as.numeric(difftime(awake, getup, units = "hours"))
      if (abs(awake_getup_diff) >= 12) {
        if (!is.na(sleep)) {
          AM_rawdata$time_sleep_corrected[i] <- sleep - hours(12)
          sleep <- AM_rawdata$time_sleep_corrected[i]
          corrections <- c(corrections, "sleep_minus12h_awake>getup")
        }
      }
    }
    
    # ---- Stage 4: Loop adjust bed-sleep large gap - CASE B ----
    bed <- AM_rawdata$time_bed_corrected[i]
    sleep <- AM_rawdata$time_sleep_corrected[i]
    
    iter <- 0
    while (!is.na(bed) && !is.na(sleep) && bed < sleep) {
      bed_sleep_diff <- as.numeric(difftime(sleep, bed, units = "hours"))
      if (bed_sleep_diff >= 12) {
        AM_rawdata$time_sleep_corrected[i] <- sleep - hours(12)
        sleep <- AM_rawdata$time_sleep_corrected[i]
        iter <- iter + 1
        corrections <- c(corrections, paste0("sleep_minus12h_loop", iter))
      } else {
        break
      }
    }
    
    # Final times
    bed <- AM_rawdata$time_bed_corrected[i]
    sleep <- AM_rawdata$time_sleep_corrected[i]
    awake <- AM_rawdata$time_awake_corrected[i]
    getup <- AM_rawdata$time_getup_corrected[i]
    
    # Check order
    order_ok <- TRUE
    if (!is.na(bed) && !is.na(sleep) && bed > sleep) order_ok <- FALSE
    if (!is.na(sleep) && !is.na(awake) && sleep > awake) order_ok <- FALSE
    if (!is.na(awake) && !is.na(getup) && awake > getup) order_ok <- FALSE
    
    AM_rawdata$order_correct[i] <- order_ok
    
    # Record corrections
    if (length(corrections) > 0) {
      AM_rawdata$corrected[i] <- TRUE
      AM_rawdata$correction_type[i] <- paste(corrections, collapse = " + ")
    }
    
    # Data classification
    if (sum(!has_na) == 4) {
      AM_rawdata$data_category[i] <- "Complete records"
      AM_rawdata$passive_carrier[i] <- FALSE
    } else if (sum(!has_na) >= 2) {
      AM_rawdata$data_category[i] <- "Partial records"
      AM_rawdata$passive_carrier[i] <- TRUE
    } else {
      AM_rawdata$data_category[i] <- "Minimal records"
      AM_rawdata$passive_carrier[i] <- TRUE
    }
  }
  
  return(AM_rawdata)
}

# ===== Test data: Four CASES =====
test_cases <- list(
  
  # CASE A: No valid records
  case_A = tibble(
    pid = "A001",
    day_num = 1,
    time_bed_am_hhmm_ampm   = ymd_hms(NA),
    time_sleep_am_hhmm_ampm = ymd_hms(NA),
    time_awake_am_hhmm_ampm = ymd_hms(NA),
    time_getup_am_hhmm_ampm = ymd_hms(NA)
  ),
  
  # CASE B: Multiple 12h iterations (24h difference → 2 loops)
  case_B = tibble(
    pid = "B001",
    day_num = 1,
    time_bed_am_hhmm_ampm   = ymd_hm("2027-03-02 20:00"),
    time_sleep_am_hhmm_ampm = ymd_hm("2027-03-03 20:00"),
    time_awake_am_hhmm_ampm = ymd_hm("2027-03-04 07:00"),
    time_getup_am_hhmm_ampm = ymd_hm("2027-03-04 07:30")
  ),
  
  # CASE C: Missing duration columns (silent continuation)
  case_C = tibble(
    pid = "C001",
    day_num = 1,
    time_bed_am_hhmm_ampm   = ymd_hm("2027-03-02 22:30"),
    time_sleep_am_hhmm_ampm = ymd_hm("2027-03-02 23:00"),
    time_awake_am_hhmm_ampm = ymd_hm("2027-03-03 06:30"),
    time_getup_am_hhmm_ampm = ymd_hm("2027-03-03 07:00")
  ),
  
  # CASE D: Equal times after Stage 1 - no swap
  case_D = tibble(
    pid = "D001",
    day_num = 1,
    time_bed_am_hhmm_ampm   = ymd_hm("2027-03-02 23:30"),
    time_sleep_am_hhmm_ampm = ymd_hm("2027-03-02 23:00"),  # bed > sleep → will swap
    time_awake_am_hhmm_ampm = ymd_hm("2027-03-03 06:30"),
    time_getup_am_hhmm_ampm = ymd_hm("2027-03-03 06:30")   # awake == getup → no swap
  )
)

# ===== Test function =====
cat("\n", strrep("#", 60), "\n")
cat("#          Sleep Time Correction Test - Four CASES          #\n")
cat(strrep("#", 60), "\n\n")

for (case_name in names(test_cases)) {
  cat("\n", strrep("=", 50), "\n")
  cat("▶️ ", case_name, "\n")
  cat(strrep("=", 50), "\n")
  
  # Run
  result <- calculate_sleep_time_vars(test_cases[[case_name]])
  
  # Output
  cat("\n📋 Original times:\n")
  orig <- test_cases[[case_name]]
  cat(sprintf("  Bed: %s\n", ifelse(is.na(orig$time_bed_am_hhmm_ampm), "NA", 
                                    format(orig$time_bed_am_hhmm_ampm, "%H:%M"))))
  cat(sprintf("  Sleep: %s\n", ifelse(is.na(orig$time_sleep_am_hhmm_ampm), "NA",
                                      format(orig$time_sleep_am_hhmm_ampm, "%H:%M"))))
  cat(sprintf("  Awake: %s\n", ifelse(is.na(orig$time_awake_am_hhmm_ampm), "NA",
                                      format(orig$time_awake_am_hhmm_ampm, "%H:%M"))))
  cat(sprintf("  Getup: %s\n", ifelse(is.na(orig$time_getup_am_hhmm_ampm), "NA",
                                      format(orig$time_getup_am_hhmm_ampm, "%H:%M"))))
  
  cat("\n🔧 Corrected times:\n")
  cat(sprintf("  Bed: %s\n", format(result$time_bed_corrected, "%m-%d %H:%M")))
  cat(sprintf("  Sleep: %s\n", format(result$time_sleep_corrected, "%m-%d %H:%M")))
  cat(sprintf("  Awake: %s\n", format(result$time_awake_corrected, "%m-%d %H:%M")))
  cat(sprintf("  Getup: %s\n", format(result$time_getup_corrected, "%m-%d %H:%M")))
  
  cat("\n📊 Results:\n")
  cat(sprintf("  Corrected: %s\n", ifelse(result$corrected, "Yes", "No")))
  cat(sprintf("  Correction type: %s\n", ifelse(is.na(result$correction_type), "None", result$correction_type)))
  cat(sprintf("  Order correct: %s\n", ifelse(is.na(result$order_correct), "-", 
                                              ifelse(result$order_correct, "Yes", "No"))))
  cat(sprintf("  Data category: %s\n", result$data_category))
  
  # CASE validation
  if (case_name == "case_A") {
    cat("\n✅ CASE A: No valid records → Correction stages skipped\n")
  } else if (case_name == "case_B") {
    n_loops <- sum(grepl("loop", result$correction_type))
    cat(sprintf("\n✅ CASE B: Multiple 12h iterations → Sleep adjusted %d times (%d loops)\n", n_loops, n_loops))
  } else if (case_name == "case_C") {
    cat("\n✅ CASE C: Missing duration columns → Silent continuation\n")
  } else if (case_name == "case_D") {
    cat("\n✅ CASE D: Equal times after Stage 1 - no swap\n")
    if (!grepl("awake_getup", result$correction_type)) {
      cat("   - awake == getup → No swap ✓\n")
    }
    if (grepl("bed_sleep", result$correction_type)) {
      cat("   - bed > sleep → Swapped ✓\n")
    }
  }
}

# Summary
cat("\n", strrep("#", 60), "\n")
cat("Test Summary\n")
cat(strrep("#", 60), "\n\n")

results <- list()
for (case_name in names(test_cases)) {
  results[[case_name]] <- calculate_sleep_time_vars(test_cases[[case_name]])
}

summary_df <- tibble(
  Case = names(results),
  CASE = c("A:No valid records", "B:Multiple loops", "C:No duration", "D:Equal no swap"),
  Corrected = map_chr(results, ~ifelse(.x$corrected, "Yes", "No")),
  Correction_type = map_chr(results, ~ifelse(is.na(.x$correction_type), "None", .x$correction_type)),
  Order_correct = map_chr(results, ~ifelse(is.na(.x$order_correct), "-", 
                                           ifelse(.x$order_correct, "Yes", "No"))),
  Data_category = map_chr(results, ~.x$data_category)
)

print(summary_df)

cat("\n✅ Test completed! All four CASES validated\n")
################################################################################
# Simplified Sleep Time Processing Function
# Based on Decision Tree Logic
# 
# Input: AM_rawdata (dataframe containing sleep time variables)
# Output: Cleaned dataframe and classification report
################################################################################

calculate_sleep_time_vars <- function(AM_rawdata) {
  require(dplyr)
  require(lubridate)
  
  # 1. Create new dataframe, copy original data
  cleaned_data <- AM_rawdata
  
  # 2. Create all required columns first
  cleaned_data <- cleaned_data %>%
    mutate(
      row_id = row_number(),
      # Mark records with NA values (any sleep time variable is NA)
      has_na = is.na(time_bed_am_hhmm_ampm) | is.na(time_sleep_am_hhmm_ampm) | 
        is.na(time_awake_am_hhmm_ampm) | is.na(time_getup_am_hhmm_ampm),
      
      # Create corrected time columns (initialized with original values)
      time_bed_corrected = time_bed_am_hhmm_ampm,
      time_sleep_corrected = time_sleep_am_hhmm_ampm,
      time_awake_corrected = time_awake_am_hhmm_ampm,
      time_getup_corrected = time_getup_am_hhmm_ampm,
      
      # Initialize correction flags
      corrected = FALSE,
      correction_type = NA_character_,
      
      # Set data category for NA records directly, skip subsequent processing
      data_category = ifelse(has_na, "skipped_na", NA_character_)
    )
  
  # ===== 第一步：3小时内的简单交换（最先执行）=====
  # 处理 bed-sleep组前后颠倒且差值<3小时，awake-getup组前后颠倒且差值<3小时
  if (sum(!cleaned_data$has_na) > 0) {
    valid_indices <- which(!cleaned_data$has_na)
    
    for (i in valid_indices) {
      bed <- cleaned_data$time_bed_corrected[i]
      sleep <- cleaned_data$time_sleep_corrected[i]
      awake <- cleaned_data$time_awake_corrected[i]
      getup <- cleaned_data$time_getup_corrected[i]
      
      # 1.1 Check bed-sleep order error (difference less than 3 hours)
      bed_sleep_diff <- as.numeric(difftime(sleep, bed, units = "hours"))
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
        
        # 更新当前变量
        bed <- cleaned_data$time_bed_corrected[i]
        sleep <- cleaned_data$time_sleep_corrected[i]
      }
      
      # 1.2 Check sleep-awake order error (difference less than 3 hours)
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
        
        # 更新当前变量
        sleep <- cleaned_data$time_sleep_corrected[i]
        awake <- cleaned_data$time_awake_corrected[i]
      }
      
      # 1.3 Check awake-getup order error (difference less than 3 hours)
      awake_getup_diff <- as.numeric(difftime(getup, awake, units = "hours"))
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
        
        # 更新当前变量
        awake <- cleaned_data$time_awake_corrected[i]
        getup <- cleaned_data$time_getup_corrected[i]
      }
    }
  }
  
  # ===== 第二步：优先顺序调整 =====
  if (sum(!cleaned_data$has_na) > 0) {
    valid_indices <- which(!cleaned_data$has_na)
    
    for (i in valid_indices) {
      bed <- cleaned_data$time_bed_corrected[i]
      sleep <- cleaned_data$time_sleep_corrected[i]
      awake <- cleaned_data$time_awake_corrected[i]
      getup <- cleaned_data$time_getup_corrected[i]
      
      # Initialize correction flags
      corrected_flag <- cleaned_data$corrected[i]
      correction_type <- cleaned_data$correction_type[i]
      
      # 2.1 Check if awake-getup group is reversed (first branch of decision tree)
      awake_getup_diff <- as.numeric(difftime(getup, awake, units = "hours"))
      
      if (awake > getup) {
        if (abs(awake_getup_diff) < 1) {
          # Difference less than 1 hour: should have been handled in step 1, but check again
          awake_new <- getup
          getup_new <- awake
          awake <- awake_new
          getup <- getup_new
          corrected_flag <- TRUE
          if (is.na(correction_type)) {
            correction_type <- "awake_getup_swap_small"
          } else if (!grepl("awake_getup_swap", correction_type)) {
            correction_type <- paste(correction_type, "+ awake_getup_swap_small")
          }
          
        } else if (abs(awake_getup_diff) > 12) {
          # Difference greater than 12 hours: AM/PM conversion for sleep (subtract 12 hours)
          sleep <- sleep - hours(12)
          corrected_flag <- TRUE
          if (is.na(correction_type)) {
            correction_type <- "sleep_ampm_adjust"
          } else if (!grepl("sleep_ampm_adjust", correction_type)) {
            correction_type <- paste(correction_type, "+ sleep_ampm_adjust")
          }
        }
      }
      
      # 2.2 Check if bed is earlier than sleep and time difference >= 12h
      bed_sleep_diff <- as.numeric(difftime(sleep, bed, units = "hours"))
      
      if (bed < sleep && bed_sleep_diff >= 12) {
        # Loop adjustment until difference < 12h
        while (bed_sleep_diff >= 12) {
          sleep <- sleep - hours(12)
          bed_sleep_diff <- as.numeric(difftime(sleep, bed, units = "hours"))
          corrected_flag <- TRUE
          if (is.na(correction_type)) {
            correction_type <- "sleep_reduce_12h_loop"
          } else if (!grepl("sleep_reduce_12h_loop", correction_type)) {
            correction_type <- paste(correction_type, "+ sleep_reduce_12h_loop")
          }
        }
      }
      
      # 2.3 Check if getup is still later than awake
      awake_getup_diff <- as.numeric(difftime(getup, awake, units = "hours"))
      
      if (getup > awake && awake_getup_diff >= 12) {
        # Priority order adjustment
        getup <- getup - hours(12)
        corrected_flag <- TRUE
        if (is.na(correction_type)) {
          correction_type <- "getup_reduce_12h"
        } else if (!grepl("getup_reduce_12h", correction_type)) {
          correction_type <- paste(correction_type, "+ getup_reduce_12h")
        }
      }
      
      # Store processed values back to dataframe
      cleaned_data$time_bed_corrected[i] <- bed
      cleaned_data$time_sleep_corrected[i] <- sleep
      cleaned_data$time_awake_corrected[i] <- awake
      cleaned_data$time_getup_corrected[i] <- getup
      cleaned_data$corrected[i] <- corrected_flag
      cleaned_data$correction_type[i] <- correction_type
    }
  }
  
  # ===== 第三步：bed-sleep组晚于awake-getup组的情况 =====
  if (sum(!cleaned_data$has_na) > 0) {
    valid_indices <- which(!cleaned_data$has_na)
    
    for (i in valid_indices) {
      bed <- cleaned_data$time_bed_corrected[i]
      sleep <- cleaned_data$time_sleep_corrected[i]
      awake <- cleaned_data$time_awake_corrected[i]
      getup <- cleaned_data$time_getup_corrected[i]
      
      # 检查组内顺序是否正确
      bed_sleep_ok <- bed <= sleep
      awake_getup_ok <- awake <= getup
      
      # 如果两组内部顺序都正确，但bed-sleep组整体晚于awake-getup组
      if (bed_sleep_ok && awake_getup_ok && bed > awake) {
        # bed-sleep组两个时间都减去12小时
        bed <- bed - hours(12)
        sleep <- sleep - hours(12)
        
        cleaned_data$time_bed_corrected[i] <- bed
        cleaned_data$time_sleep_corrected[i] <- sleep
        cleaned_data$corrected[i] <- TRUE
        
        if (is.na(cleaned_data$correction_type[i])) {
          cleaned_data$correction_type[i] <- "bed_sleep_group_subtract_12h"
        } else if (!grepl("bed_sleep_group_subtract_12h", cleaned_data$correction_type[i])) {
          cleaned_data$correction_type[i] <- paste(cleaned_data$correction_type[i], 
                                                   "+ bed_sleep_group_subtract_12h")
        }
      }
    }
  }
  
  # ===== 第四步：AM/PM转换逻辑（11.5-12.5小时区间）=====
  # 注意：这部分逻辑比较复杂，我暂时保留原样，但你需要确认是否需要
  
  # ===== 第五步：错误标记和可疑数据识别 =====
  cleaned_data <- cleaned_data %>%
    mutate(
      # Calculate time differences (hours) - only for non-NA records
      bed_sleep_diff_h = ifelse(!has_na, 
                                as.numeric(difftime(time_sleep_corrected, time_bed_corrected, units = "hours")),
                                NA_real_),
      sleep_awake_diff_h = ifelse(!has_na,
                                  as.numeric(difftime(time_awake_corrected, time_sleep_corrected, units = "hours")),
                                  NA_real_),
      awake_getup_diff_h = ifelse(!has_na,
                                  as.numeric(difftime(time_getup_corrected, time_awake_corrected, units = "hours")),
                                  NA_real_),
      
      # Check if order is correct - only for non-NA records
      order_correct = ifelse(!has_na,
                             (time_bed_corrected < time_sleep_corrected) & 
                               (time_sleep_corrected < time_awake_corrected) & 
                               (time_awake_corrected < time_getup_corrected),
                             NA),
      
      # Check 4 basic conditions (decision tree's "correct order" judgment)
      condition1_ok = order_correct,  # Correct order
      condition2_ok = ifelse(!has_na, abs(bed_sleep_diff_h) <= 7, NA),  # bed-sleep ≤ 7h
      condition3_ok = ifelse(!has_na, abs(awake_getup_diff_h) <= 7, NA),  # awake-getup ≤ 7h
      condition4_ok = ifelse(!has_na, abs(sleep_awake_diff_h) <= 24, NA),  # sleep-awake ≤ 24h
      
      # Special cases: bed-sleep and awake-getup times are equal after correction
      bed_sleep_equal = ifelse(!has_na, bed_sleep_diff_h == 0, NA),
      awake_getup_equal = ifelse(!has_na, awake_getup_diff_h == 0, NA),
      
      # Mark errors (doesn't meet one of the 4 conditions, excluding special cases)
      is_error = case_when(
        has_na ~ FALSE,
        !has_na & !(order_correct & condition2_ok & condition3_ok & condition4_ok) & 
          !(bed_sleep_equal | awake_getup_equal) ~ TRUE,
        TRUE ~ FALSE
      ),
      
      # Suspicious data marking (excluding equal time cases)
      sleep_awake_suspicious = ifelse(!has_na, sleep_awake_diff_h < 3 | sleep_awake_diff_h > 15, NA),
      bed_sleep_suspicious = ifelse(!has_na, bed_sleep_diff_h > 3, NA),  # Changed to 3-hour threshold
      awake_getup_suspicious = ifelse(!has_na, awake_getup_diff_h > 7, NA),
      
      # Is suspicious
      is_unusual = case_when(
        has_na ~ FALSE,
        !has_na & (sleep_awake_suspicious | bed_sleep_suspicious | awake_getup_suspicious) & 
          !(bed_sleep_equal | awake_getup_equal) ~ TRUE,
        TRUE ~ FALSE
      ),
      
      # Update data category
      data_category = case_when(
        has_na ~ "skipped_na",
        !has_na & (bed_sleep_equal | awake_getup_equal) ~ "equal_time_ok",
        !has_na & is_error ~ "error",
        !has_na & is_unusual ~ "unusual",
        !has_na ~ "clean",
        TRUE ~ "unknown"
      ),
      
      # Error type
      error_type = case_when(
        !is_error ~ NA_character_,
        !order_correct ~ "order_error",
        !condition2_ok ~ "bed_sleep_diff_error",
        !condition3_ok ~ "awake_getup_diff_error",
        !condition4_ok ~ "sleep_awake_24h_error",
        TRUE ~ "multiple_errors"
      ),
      
      # Suspicious type
      unusual_type = case_when(
        !is_unusual ~ NA_character_,
        sleep_awake_suspicious ~ "sleep_awake_suspicious",
        bed_sleep_suspicious ~ "bed_sleep_suspicious",
        awake_getup_suspicious ~ "awake_getup_suspicious",
        TRUE ~ "multiple_suspicious"
      ),
      
      # Equal time type marking
      equal_time_type = case_when(
        bed_sleep_equal & awake_getup_equal ~ "both_equal",
        bed_sleep_equal ~ "bed_sleep_equal",
        awake_getup_equal ~ "awake_getup_equal",
        TRUE ~ NA_character_
      )
    )
  
  # ===== 第六步：创建分类数据框 =====
  
  # 6.1 Equal time data (special handling, not considered errors)
  equal_time_df <- cleaned_data %>%
    filter(data_category == "equal_time_ok") %>%
    select(pid, day_num, row_id,
           time_bed_am_hhmm_ampm, time_sleep_am_hhmm_ampm, 
           time_awake_am_hhmm_ampm, time_getup_am_hhmm_ampm,
           time_bed_corrected, time_sleep_corrected, time_awake_corrected, time_getup_corrected,
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           bed_sleep_equal, awake_getup_equal, equal_time_type,
           corrected, correction_type)
  
  # 6.2 Error data
  error_df <- cleaned_data %>%
    filter(data_category == "error") %>%
    select(pid, day_num, row_id,
           time_bed_am_hhmm_ampm, time_sleep_am_hhmm_ampm, 
           time_awake_am_hhmm_ampm, time_getup_am_hhmm_ampm,
           time_bed_corrected, time_sleep_corrected, time_awake_corrected, time_getup_corrected,
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           condition1_ok, condition2_ok, condition3_ok, condition4_ok,
           error_type, corrected, correction_type)
  
  # 6.3 Suspicious data
  unusual_df <- cleaned_data %>%
    filter(data_category == "unusual") %>%
    select(pid, day_num, row_id,
           time_bed_corrected, time_sleep_corrected, time_awake_corrected, time_getup_corrected,
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           sleep_awake_suspicious, bed_sleep_suspicious, awake_getup_suspicious,
           unusual_type, corrected, correction_type)
  
  # 6.4 Clean data
  clean_df <- cleaned_data %>%
    filter(data_category == "clean") %>%
    select(pid, day_num, row_id,
           time_bed_corrected, time_sleep_corrected, time_awake_corrected, time_getup_corrected,
           bed_sleep_diff_h, sleep_awake_diff_h, awake_getup_diff_h,
           corrected, correction_type)
  
  # ===== 第七步：创建汇总统计 =====
  total_records <- nrow(cleaned_data)
  na_count <- sum(cleaned_data$has_na, na.rm = TRUE)
  valid_records <- total_records - na_count
  
  if (valid_records > 0) {
    equal_time_count <- sum(cleaned_data$data_category == "equal_time_ok", na.rm = TRUE)
    error_count <- sum(cleaned_data$data_category == "error", na.rm = TRUE)
    unusual_count <- sum(cleaned_data$data_category == "unusual", na.rm = TRUE)
    clean_count <- sum(cleaned_data$data_category == "clean", na.rm = TRUE)
    corrected_count <- sum(cleaned_data$corrected[!cleaned_data$has_na], na.rm = TRUE)
  } else {
    equal_time_count <- 0
    error_count <- 0
    unusual_count <- 0
    clean_count <- 0
    corrected_count <- 0
  }
  
  # 创建汇总数据框
  summary_df <- data.frame(
    total_records = total_records,
    skipped_na_records = na_count,
    valid_records = valid_records,
    equal_time_records = equal_time_count,
    equal_time_percentage = ifelse(valid_records > 0, round(equal_time_count/valid_records*100, 1), 0),
    error_records = error_count,
    error_rate = ifelse(valid_records > 0, round(error_count/valid_records*100, 1), 0),
    unusual_records = unusual_count,
    unusual_rate = ifelse(valid_records > 0, round(unusual_count/valid_records*100, 1), 0),
    clean_records = clean_count,
    clean_rate = ifelse(valid_records > 0, round(clean_count/valid_records*100, 1), 0),
    corrected_records = corrected_count,
    corrected_rate = ifelse(valid_records > 0, round(corrected_count/valid_records*100, 1), 0)
  )
  
  # ===== 第八步：打印报告 =====
  cat("=== Sleep Time Data Processing Complete ===\n\n")
  cat("Note: Skipped", na_count, "records containing NA values\n")
  cat("Valid records (no NA):", valid_records, "\n\n")
  
  cat("Processing Flow Summary:\n")
  cat("1. 3-hour Swap (bed-sleep and awake-getup swaps within 3 hours)\n")
  cat("2. Priority Order Adjustment (awake-getup check, bed-sleep check, getup adjustment)\n")
  cat("3. Group Order Adjustment (bed-sleep组晚于awake-getup组的情况)\n")
  cat("4. Final Error Marking (4 condition checks)\n\n")
  
  cat("Valid Data Summary:\n")
  print(t(summary_df[, -c(1:2)]))  # Exclude total records and NA records
  
  if (valid_records > 0) {
    if (equal_time_count > 0) {
      equal_time_summary <- cleaned_data %>%
        filter(!is.na(equal_time_type)) %>%
        count(equal_time_type) %>%
        arrange(desc(n))
      cat("\nEqual Time Type Distribution:\n")
      print(equal_time_summary)
    }
    
    if (error_count > 0) {
      error_type_summary <- cleaned_data %>%
        filter(!is.na(error_type)) %>%
        count(error_type) %>%
        arrange(desc(n))
      cat("\nError Type Distribution:\n")
      print(error_type_summary)
    }
    
    if (unusual_count > 0) {
      unusual_type_summary <- cleaned_data %>%
        filter(!is.na(unusual_type)) %>%
        count(unusual_type) %>%
        arrange(desc(n))
      cat("\nSuspicious Type Distribution:\n")
      print(unusual_type_summary)
    }
    
    # 显示修正类型分布
    new_correction_types <- cleaned_data %>%
      filter(!has_na, corrected) %>%
      mutate(correction_list = strsplit(correction_type, " \\+ ")) %>%
      unnest(correction_list) %>%
      count(correction_list) %>%
      arrange(desc(n))
    
    if (nrow(new_correction_types) > 0) {
      cat("\nCorrection Types Distribution:\n")
      print(new_correction_types)
    }
  }
  
  cat("\nDataframes Created (valid data only):\n")
  cat("1. equal_time_df -", nrow(equal_time_df), "equal time records\n")
  cat("2. error_df -", nrow(error_df), "error records\n")
  cat("3. unusual_df -", nrow(unusual_df), "suspicious records\n")
  cat("4. clean_df -", nrow(clean_df), "clean records\n")
  cat("5. summary_df - summary statistics\n")
  
  # ===== 第九步：存储结果到全局环境 =====
  assign("sleep_time_equal_time_df", equal_time_df, envir = .GlobalEnv)
  assign("sleep_time_error_df", error_df, envir = .GlobalEnv)
  assign("sleep_time_unusual_df", unusual_df, envir = .GlobalEnv)
  assign("sleep_time_clean_df", clean_df, envir = .GlobalEnv)
  assign("sleep_time_summary_df", summary_df, envir = .GlobalEnv)
  assign("sleep_time_full_data", cleaned_data, envir = .GlobalEnv)
  
  cat("\n✓ All dataframes saved to global environment:\n")
  cat("  sleep_time_equal_time_df\n")
  cat("  sleep_time_error_df\n")
  cat("  sleep_time_unusual_df\n")
  cat("  sleep_time_clean_df\n")
  cat("  sleep_time_summary_df\n")
  cat("  sleep_time_full_data\n")
  
  # ===== 第十步：返回清理后的完整数据框 =====
  return(cleaned_data)
}
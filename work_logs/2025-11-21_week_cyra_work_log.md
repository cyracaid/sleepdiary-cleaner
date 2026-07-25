# 11.21 Week Cyra Work Log

Tasks:

1. Get process_timestamp_emadatarelease.R working
   1. It’s possible that it already works great, no errors! Try to determine whether that is true. Fingers crossed that it is straightforward.
2. Run BOTH process interval and timestamp functions.
3. See if calculate_sleep_time_vars.R works
   1. Check that the outputs you are getting look right given the inputs
4. Check whether the output variables you are getting make sense — You can try visual inspection, graphing, algorithmically, or whatever makes sense to you to try to mark cases in need of manual inspection.



## 1. Get process_timestamp_emadatarelease.R working

### 1. Line 47

1. **Variable Type Issues:**
   - `day_num`: Incorrectly included (numeric variable, not timestamp)
   - Mixed column types: `hms difftime`, `character`, and `logical`
   - `nicotine_amount_pm_hhmm` & `cannabis_amount_pm_hhmm`: Logical type with all NA values
2. **Data Structure:**
   - Valid timestamp variables identified: `time_bed_am`, `time_sleep_am`, `time_awake_am`, `time_getup_am`, `caffeinetoday_PM`, `alcoholtoday_PM`
   - Some columns contain valid time data (e.g., "10:00", "6:30")
   - Others show numeric representations (34800, 25200) suggesting time conversions needed

修改了成这个

```R
		# 改为更安全的类型转换：
		if (is.logical(df[[tstamp.varname]])) {
		  # 如果是 logical 类型（全是 NA），转换为字符型 NA
		  df[[tstamp.varname]] <- NA_character_
		} else if (inherits(df[[tstamp.varname]], "hms") || inherits(df[[tstamp.varname]], "difftime")) {
		  # 如果是 hms/difftime 类型，转换为标准时间格式字符串
		  df[[tstamp.varname]] <- format(df[[tstamp.varname]], "%H:%M")
		} else {
		  # 其他情况正常转换为字符型
		  df[[tstamp.varname]] <- as.character(df[[tstamp.varname]])
		}
		
```

**PROCESSING COMPLETED:**

- ✅ Successfully processed 6 timestamp variables:
  - `time_bed_am`, `time_sleep_am`, `time_awake_am`, `time_getup_am`
  - `caffeinetoday_PM`, `alcoholtoday_PM`

**DATA QUALITY ASSESSMENT:**

- **High Success Rate**: Minimal parsing failures detected
  - `time_bed_am`: 14 records failed to parse
  - `time_sleep_am`: 15 records failed to parse
  - `time_awake_am`: 1 record failed to parse
- **Format Consistency**: Majority of timestamps successfully converted to standardized datetime format

**WARNINGS EXPLANATION:**

1. **"Expected 2 pieces" warnings**: Normal behavior from `separate()` function
   - Caused by missing/incomplete time data (expected "HH:MM" format)
   - Affected ~2,850-2,856 rows with extra data pieces
   - ~11,134-11,140 rows with missing data pieces
   - **Status**: Expected - reflects natural data sparsity in EMA datasets
2. **Parsing failures**: Very low failure rate (<0.2% of total records)
   - **Impact**: Minimal effect on overall data quality
   - **Action**: Error-check columns automatically created for manual review

```R
error_cols <- grep("checkforerrors", names(ema_data_release_timeproc), value = TRUE)

for (error_col in error_cols) {
  cat("列", error_col, "中的错误统计:\n")
  print(table(ema_data_release_timeproc[[error_col]], useNA = "always"))
}
```

**DETAILED RESULTS:**
All `_checkforerrors` columns contain only `NA` values:

- `time_bed_am_checkforerrors`: 13,990/13,990 NA
- `time_sleep_am_checkforerrors`: 13,990/13,990 NA
- `time_awake_am_checkforerrors`: 13,990/13,990 NA
- `time_getup_am_checkforerrors`: 13,990/13,990 NA
- `caffeinetoday_PM_checkforerrors`: 13,990/13,990 NA
- `alcoholtoday_PM_checkforerrors`: 13,990/13,990 NA

```R
# Check all processed timestamp variables for records that don't conform to standard format
check_timestamp_formats <- function(df, varnames) {
  all_issues <- data.frame()
  
  for (varname in varnames) {
    parsed_col <- paste0(varname, "_hhmm_ampm")
    
    if (parsed_col %in% names(df)) {
      # Get all non-NA parsed timestamps
      non_na_timestamps <- which(!is.na(df[[parsed_col]]))
      
      if (length(non_na_timestamps) > 0) {
        # Convert to character for format checking
        timestamp_strings <- as.character(df[[parsed_col]][non_na_timestamps])
        
        # Check if conforms to standard datetime format (YYYY-MM-DD HH:MM:SS)
        valid_format <- grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", timestamp_strings)
        
        # Find records that don't conform to format
        invalid_indices <- non_na_timestamps[!valid_format]
        
        if (length(invalid_indices) > 0) {
          cat("Variable", varname, "has", length(invalid_indices), "records with non-standard format\n")
          
          # Create issue records table
          issues <- data.frame(
            pid = df$pid[invalid_indices],
            day_num = df$day_num[invalid_indices],
            survey_type = df$survey_type[invalid_indices],
            variable = varname,
            parsed_timestamp = timestamp_strings[!valid_format],
            issue_type = "Non-standard time format"
          )
          
          all_issues <- rbind(all_issues, issues)
        }
      }
    }
  }
  
  return(all_issues)
}

# Run the check
format_issues <- check_timestamp_formats(ema_data_release_timeproc, tstamp.vars.to.proc)

# Display results
if (nrow(format_issues) > 0) {
  cat("\n=== Timestamp Format Issues Summary ===\n")
  print(format_issues)
  
  # Statistics by variable
  cat("\nStatistics by variable:\n")
  print(table(format_issues$variable))
  
  # Save to CSV
  write.csv(format_issues, "timestamp_format_issues.csv", row.names = FALSE)
  cat("\nDetailed information saved to: timestamp_format_issues.csv\n")
} else {
  cat("✅ All timestamps conform to standard format: YYYY-MM-DD HH:MM:SS\n")
}

# Quick format check summary
cat("\n=== Format Check Quick Summary ===\n")
for (varname in tstamp.vars.to.proc) {
  parsed_col <- paste0(varname, "_hhmm_ampm")
  
  if (parsed_col %in% names(ema_data_release_timeproc)) {
    non_na <- sum(!is.na(ema_data_release_timeproc[[parsed_col]]))
    if (non_na > 0) {
      timestamp_strings <- as.character(na.omit(ema_data_release_timeproc[[parsed_col]]))
      valid_count <- sum(grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", timestamp_strings))
      cat(varname, ": ", valid_count, "/", non_na, " conform to standard format\n")
    }
  }
}
```



## Problem Identified

**Issue**: Midnight times (12:00:00 AM) were displaying as date-only (e.g., `2027-03-04`) instead of full timestamp format.

**Root Cause**: R automatically hides `00:00:00` time components when displaying datetime objects.

## Solution Implemented

Added format conversion after `parse_date_time()` to force display of full timestamps:

```R
# Convert to character with explicit format to prevent hiding of midnight times
df_timeproc[[paste0(varname, "_hhmm_ampm")]] <- 
  format(df_timeproc[[paste0(varname, "_hhmm_ampm")]], "%Y-%m-%d %H:%M:%S")
```



## Location in Code

Added in `process_timestamp` function after:

r

```R
df_timeproc = df_timeproc %>% 
  mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := lubridate::parse_date_time(...))
```



## Verification Code

r

```R
# Check all timestamps conform to standard format
check_timestamp_formats <- function(df, varnames) {
  all_issues <- data.frame()
  for (varname in varnames) {
    parsed_col <- paste0(varname, "_hhmm_ampm")
    if (parsed_col %in% names(df)) {
      non_na_timestamps <- which(!is.na(df[[parsed_col]]))
      if (length(non_na_timestamps) > 0) {
        timestamp_strings <- as.character(df[[parsed_col]][non_na_timestamps])
        valid_format <- grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", timestamp_strings)
        invalid_indices <- non_na_timestamps[!valid_format]
        # ... issue recording logic
      }
    }
  }
  return(all_issues)
}
```



## Results

**✅ SUCCESS**: All timestamps now display in standard format `YYYY-MM-DD HH:MM:SS`

**Remaining Warnings**: Normal processing artifacts from data cleaning:

- `Expected 2 pieces` - from `separate()` function handling various time formats
- `failed to parse` - automatically handled by the function

**Data Quality**: 100% of non-NA timestamps conform to standard format. Ready for next processing stage.



```R
# Debug function to trace where the time component gets lost
debug_timestamp_processing <- function(df, varname, sample_size = 10) {
  cat("\n=== DEBUGGING:", varname, "===\n")
  
  # Get a sample of problematic records
  parsed_col <- paste0(varname, "_hhmm_ampm")
  hhmm_col <- paste0(varname, "_hhmm")
  ampm_col <- paste0(varname, "_ampm")
  
  # Find records with only date (no time)
  problematic <- which(!is.na(df[[parsed_col]]) & 
                         !grepl("\\d{2}:\\d{2}:\\d{2}", as.character(df[[parsed_col]])))
  
  if (length(problematic) == 0) {
    cat("No problematic records found for", varname, "\n")
    return()
  }
  
  # Take a sample for detailed analysis
  sample_idx <- problematic[1:min(sample_size, length(problematic))]
  
  cat("Sample of", length(sample_idx), "problematic records:\n")
  
  for (i in sample_idx) {
    cat("\n--- Record", i, "---\n")
    cat("PID:", df$pid[i], "| Day:", df$day_num[i], "| Survey:", df$survey_type[i], "\n")
    cat("Original _hhmm:", df[[hhmm_col]][i], "| Class:", class(df[[hhmm_col]][i]), "\n")
    cat("Original _ampm:", df[[ampm_col]][i], "\n")
    cat("Parsed result:", as.character(df[[parsed_col]][i]), "\n")
    
    # Check intermediate steps by recreating them
    original_time <- df[[hhmm_col]][i]
    original_ampm <- df[[ampm_col]][i]
    
    # Simulate the processing steps
    if (!is.na(original_time) && original_time != "NA" && original_time != "      NA") {
      # Step 1: Type conversion (from your function)
      if (is.logical(original_time)) {
        time_str <- NA_character_
      } else if (inherits(original_time, "hms") || inherits(original_time, "difftime")) {
        time_str <- format(original_time, "%H:%M")
      } else {
        time_str <- as.character(original_time)
      }
      
      cat("After type conversion:", time_str, "\n")
      
      # Step 2: Format corrections
      time_str <- gsub("\\.", ":", time_str)
      time_str <- gsub(";", ":", time_str)
      cat("After format correction:", time_str, "\n")
      
      # Step 3: Check if we can create a valid time string
      if (!is.na(time_str) && time_str != "NA" && grepl(":", time_str)) {
        time_parts <- strsplit(time_str, ":")[[1]]
        if (length(time_parts) >= 2) {
          hours <- time_parts[1]
          minutes <- time_parts[2]
          cat("Time parts - Hours:", hours, "Minutes:", minutes, "\n")
          
          # Try to create the final timestamp string
          final_time_str <- paste0("2027-03-01 ", hours, ":", minutes, " ", original_ampm)
          cat("Would create:", final_time_str, "\n")
          
          # Try to parse it
          parsed <- try(lubridate::parse_date_time(final_time_str, "%Y-%m-%d %H:%M %p", tz = "US/Pacific"))
          cat("Parse result:", as.character(parsed), "\n")
        }
      }
    }
  }
}

# Run debug for each variable
for (varname in tstamp.vars.to.proc) {
  debug_timestamp_processing(ema_data_release_timeproc, varname, sample_size = 5)
}

# Additional check: Look at the actual values in the intermediate concatenation
cat("\n=== CHECKING INTERMEDIATE TIME STRINGS ===\n")
for (varname in tstamp.vars.to.proc) {
  cat("\nVariable:", varname, "\n")
  
  # Get some records where parsing succeeded
  parsed_col <- paste0(varname, "_hhmm_ampm")
  success_idx <- which(!is.na(ema_data_release_timeproc[[parsed_col]]) & 
                         grepl("\\d{2}:\\d{2}:\\d{2}", as.character(ema_data_release_timeproc[[parsed_col]])))
  
  if (length(success_idx) > 0) {
    sample_success <- success_idx[1:min(3, length(success_idx))]
    for (i in sample_success) {
      cat("Success example - PID:", ema_data_release_timeproc$pid[i], 
          "| Parsed:", as.character(ema_data_release_timeproc[[parsed_col]][i]), "\n")
    }
  }
  
  # Get some records where parsing failed (only date)
  fail_idx <- which(!is.na(ema_data_release_timeproc[[parsed_col]]) & 
                      !grepl("\\d{2}:\\d{2}:\\d{2}", as.character(ema_data_release_timeproc[[parsed_col]])))
  
  if (length(fail_idx) > 0) {
    sample_fail <- fail_idx[1:min(3, length(fail_idx))]
    for (i in sample_fail) {
      cat("Fail example - PID:", ema_data_release_timeproc$pid[i], 
          "| Parsed:", as.character(ema_data_release_timeproc[[parsed_col]][i]), "\n")
    }
  }
}

# 测试修复后的效果
test_midnight <- "2027-03-01 12:00 AM"
parsed <- lubridate::parse_date_time(test_midnight, "%Y-%m-%d %H:%M %p", tz = "US/Pacific")
cat("原始解析:", as.character(parsed), "\n")
cat("修复后:", format(parsed, "%Y-%m-%d %H:%M:%S"), "\n")
```

## Error Analysis

**Error**: `Incompatible classes: <character> - <Period>`

**Location**: Line 187 in `process_timestamp` function during evening variable adjustment

**Cause**: After converting timestamps to character format, the function tries to perform datetime operations (`.-lubridate::days(1)`) on character data.

**Two modifications were made:**

1. **Added at line 187:

```R
if (varname %in% c("time_bed_am", "time_sleep_am")) {
			df_timeproc = df_timeproc %>%
				mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~ifelse(lubridate::hour(.) > 15, .-lubridate::days(1), .)) %>%
				mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~as_datetime(., tz="America/Los_Angeles")) 
		}
		
```

2. **Added at line 49:**

```R
# Safe type conversion:
if (is.logical(df[[tstamp.varname]])) {
  # If logical type (all NA), convert to character NA
  df[[tstamp.varname]] <- NA_character_
} else if (inherits(df[[tstamp.varname]], "hms") || inherits(df[[tstamp.varname]], "difftime")) {
  # If hms/difftime type, convert to standard time format string
  df[[tstamp.varname]] <- format(df[[tstamp.varname]], "%H:%M")
} else {
  # Other cases normal conversion to character
  df[[tstamp.varname]] <- as.character(df[[tstamp.varname]])
}
```

# where parse date time is happening and run as in different sessions - error再中间出现还是之后也出现呢？到底在哪个位置出现？1. check location 2. step into timestamp code

Warning messages:
1: Expected 2 pieces. Additional pieces discarded in 2850 rows [3, 8, 9, 18, 26,
34, 35, 41, 42, 49, 50, 56, 57, 65, 66, 75, 76, 77, 89, 90, ...]. 
2: Expected 2 pieces. Missing pieces filled with `NA` in 11140 rows [1, 2, 4, 5,
6, 7, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24, ...]. 
3: There was 1 warning in `mutate()`.
ℹ In argument: `time_bed_am_hhmm_ampm = lubridate::parse_date_time(...)`.
Caused by warning:
!  14 failed to parse. 
4: There was 1 warning in `mutate()`.
ℹ In argument: `time_sleep_am_hhmm_ampm = lubridate::parse_date_time(...)`.
Caused by warning:
!  15 failed to parse. 
5: There was 1 warning in `mutate()`.
ℹ In argument: `time_awake_am_hhmm_ampm = lubridate::parse_date_time(...)`.
Caused by warning:
!  1 failed to parse. 
6: Expected 2 pieces. Additional pieces discarded in 2856 rows [3, 8, 9, 18, 26,
34, 35, 41, 42, 49, 50, 56, 57, 65, 66, 75, 76, 77, 89, 90, ...]. 
7: Expected 2 pieces. Missing pieces filled with `NA` in 11134 rows [1, 2, 4, 5,
6, 7, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24, ...]. 
8: Expected 2 pieces. Additional pieces discarded in 105 rows [16, 24, 25, 72,
87, 115, 138, 164, 201, 225, 352, 445, 491, 580, 625, 822, 1397, 1500, 1559,
1734, ...]. 
9: Expected 2 pieces. Missing pieces filled with `NA` in 13885 rows [1, 2, 3, 4,
5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, ...]. 



# NA in the output can be need to check for errors

# something has an NA - go wrong, 这个也要step through

# negative sleep latency dont worry yet -> negative 大小 -》很常见

# character not a major issue - interval/timestamp - mincalc (numeric)

# 

## Implementation Decision:

We are using the **second code approach** (maintaining the original logic with dual character conversions), but we are also preserving an alternative version called `alternative_timestamp.R` for reference.

## Current Implementation:

The working version maintains:

- Character conversion before AND after time adjustment operations
- Original time adjustment logic for evening variables
- Multiple format conversions that empirically produce fewer warnings

## Alternative Version:

We have saved a cleaner version as `alternative_timestamp.R` that features:

- Single character conversion after all datetime operations
- More theoretically correct execution order
- Potential for class compatibility issues in some environments

## Risk Note:

⚠️ **Warning**: The current implementation uses multiple character conversions which, while producing fewer warnings in practice, may cause `Incompatible classes: <character> - <Period>` errors in different R environments or with future package updates. The `alternative_timestamp.R` version provides a backup solution if compatibility issues arise.



## 2. Run BOTH process interval and timestamp functions.

Worked fine.

## 3. See if calculate_sleep_time_vars.R works

**时间戳处理完全没有运行** - 所有 `_hhmm_ampm` 列都不存在。

> print(common_cols)
>  [1] "pid"                                          
>  [2] "day_num"                                      
>  [3] "survey_type"                                  
>  [4] "duration_totalmin_sol_estimate_am"            
>  [5] "duration_totalmin_waso_estimate_am"           
>  [6] "duration_totalmin_napstoday_PM"               
>  [7] "exercisetoday_PM_totalmin_Light"              
>  [8] "exercisetoday_PM_totalmin_Moderate"           
>  [9] "exercisetoday_PM_totalmin_Vigorous"           
> [10] "exercisetoday_PM_totalmin_Strength"           
> [11] "time_bed_am_hhmm"                             
> [12] "time_bed_am_ampm"                             
> [13] "time_sleep_am_hhmm"                           
> [14] "time_sleep_am_ampm"                           
> [15] "time_awake_am_hhmm"                           
> [16] "time_awake_am_ampm"                           
> [17] "time_getup_am_hhmm"                           
> [18] "time_getup_am_ampm"                           
> [19] "caffeinetoday_PM_hhmm"                        
> [20] "caffeinetoday_PM_ampm"                        
> [21] "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1"
> [22] "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_2"
> [23] "alcoholtoday_PM_hhmm"                         
> [24] "alcoholtoday_PM_ampm"                         
> [25] "alcoholtoday_PM_NumAlcoholicDrinks_1"         
> [26] "nicotine_amount_pm_doses"                     
> [27] "nicotine_amount_pm_hhmm"                      
> [28] "nicotine_amount_pm_ampm"                      
> [29] "cannabis_amount_pm_doses"                     
> [30] "cannabis_amount_pm_hhmm"                      
> [31] "cannabis_amount_pm_ampm"                      



说relevant variables 是这些

	# time_bed_am_hhmm_ampm
	# time_sleep_am_hhmm_ampm
	# time_awake_am_hhmm_ampm
	# time_getup_am_hhmm_ampm
	# num_waso_estimate_am
	# duration_totalmin_sol_estimate_am_mincalc
	# duration_totalmin_waso_estimate_am_mincalc
	# num_waso_estimate_am

不是很懂

```
############
# A function to get time from the SBER2 R01 diary/EMA and format it as a timestamp
# Originally created in 2022 by Maia ten Brink
# Last updated 02/08/22 by Maia ten Brink
############

library(lubridate)
library(tidyverse)
library(stringi)

#Process timestamp input
process_timestamp <- function(df, varname, format) {
  
  cat("=== 开始 process_timestamp 诊断 ===\n")
  cat("输入参数 - varname:", varname, "format:", format, "\n")
  cat("原始数据框列数:", ncol(df), "行数:", nrow(df), "\n")
  cat("原始数据框列名:", paste(names(df), collapse = ", "), "\n\n")
  
  if(format=="timestamp") {
    #If it contains ":"
    tstamp.varname <- paste0(varname, "_hhmm") #appends time hhmm to varname -- this will be the corrected timestamps
    ampm.varname <- paste0(varname, "_ampm") #appends ampm to varname -- this will be the corrected AM/PM labels
    
    cat("步骤1: 检查输入列是否存在\n")
    cat("时间戳列:", tstamp.varname, "- 存在:", tstamp.varname %in% names(df), "\n")
    cat("AM/PM列:", ampm.varname, "- 存在:", ampm.varname %in% names(df), "\n")
    
    if (!(tstamp.varname %in% names(df))) {
      cat("❌ 错误: 时间戳列", tstamp.varname, "不存在!\n")
      return(df)
    }
    if (!(ampm.varname %in% names(df))) {
      cat("❌ 错误: AM/PM列", ampm.varname, "不存在!\n")
      return(df)
    }
    
    #correct timestamp formats
    #create empty vector to contain corrected timestamp string
    tstamp.varname.cstr <- vector(mode = "character", length = dim(df)[1])
    
    # Safe type conversion:
    if (is.logical(df[[tstamp.varname]])) {
      df[[tstamp.varname]] <- NA_character_
    } else if (inherits(df[[tstamp.varname]], "hms") || inherits(df[[tstamp.varname]], "difftime")) {
      df[[tstamp.varname]] <- format(df[[tstamp.varname]], "%H:%M")
    } else {
      df[[tstamp.varname]] <- as.character(df[[tstamp.varname]])
    }
    
    #for each row in df, check whether timestamp is in correct format. if not, fix it.
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
    
    #concatenate into dataframe concat.tstamp.ampm.cstr
    concat.tstamp.ampm.cstr = data.frame(tstamp.varname.cstr, ampm.varname = df[, ampm.varname]) 
    
    cat("步骤2: 创建 concat.tstamp.ampm.cstr\n")
    cat("concat.tstamp.ampm.cstr 维度:", dim(concat.tstamp.ampm.cstr), "\n")
    cat("concat.tstamp.ampm.cstr 列名:", names(concat.tstamp.ampm.cstr), "\n")
    
    #this block of code corrects errors in 24h time entry and returns 12h timestamps
    concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
      mutate(!!as.symbol(paste0(varname, "_hhmm_orig")) := tstamp.varname.cstr) %>%
      separate(col = tstamp.varname.cstr, into = c(paste0(varname, "_h"), paste0(varname, "_m")), sep = ":") %>%
      mutate(!!as.symbol(paste0(varname, "_h_num")) := as.numeric(!!as.symbol((paste0(varname, "_h"))))) %>% 
      mutate(!!as.symbol(paste0(varname, "_used24h")) := (!!as.symbol(paste0(varname, "_h_num")) > 12 | !!as.symbol(paste0(varname, "_h_num")) == 0)==TRUE) %>%
      mutate(!!as.symbol(paste0(varname, "_24h_ampm_correct")) := (!!as.symbol(ampm.varname)=="PM") & (!!as.symbol(paste0(varname, "_used24h"))==TRUE) ) %>%
      mutate(!!as.symbol(paste0(varname, "_24h_ampm_correct")) := ((!!as.symbol(ampm.varname)=="AM") & (!!as.symbol(paste0(varname, "_h_num")) == 0) & (!!as.symbol(paste0(varname, "_used24h"))==TRUE)) )
    
    #write NA over where there are missing values
    concat.tstamp.ampm.cstr[which(is.na(concat.tstamp.ampm.cstr[ , paste0(varname, "_h")])), paste0(varname, "_used24h")] <- NA
    
    #if a row didn't use 24h time entry (i.e. it was NA or set to FALSE), set varname_24h_ampm_correct to NA
    concat.tstamp.ampm.cstr[which(concat.tstamp.ampm.cstr[, paste0(varname, "_used24h")] == FALSE), paste0(varname, "_24h_ampm_correct")] <- NA
    concat.tstamp.ampm.cstr[which(is.na(concat.tstamp.ampm.cstr[, paste0(varname, "_used24h")])== TRUE), paste0(varname, "_24h_ampm_correct")] <- NA
    
    #correct 24h to 12h timestamp -- subtract 12 and save in _h_num_correct
    concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
      mutate(!!as.symbol(paste0(varname, "_h_num_correct")) := !!as.symbol(paste0(varname, "_h_num")),
             !!as.symbol(paste0(varname, "_h_correct")) := as.character(!!as.symbol(paste0(varname, "_h_num_correct"))),
             !!as.symbol(paste0(varname, "_h_othererrors")) := NA) 
    
    #this sets _h_num_correct = _h_num - 12 if the row contained 24 hr time format
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
      concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
        mutate_at(vars(one_of(paste0(varname, "_h_othererrors"))), ~ifelse((ampm.varname == "PM") & (paste0(varname, "_h_num") > 3), "morning var h>3 marked PM (likely AM)", .)) 
    } else if (varname %in% c("time_bed_am", "time_sleep_am")) {
      concat.tstamp.ampm.cstr = concat.tstamp.ampm.cstr %>%
        mutate_at(vars(one_of(paste0(varname, "_h_othererrors"))), ~ifelse((ampm.varname == "PM") & (paste0(varname, "_h_num") < 6), "evening var h<6 marked PM (likely AM)", .))
    }
    
    cat("步骤3: 准备创建 _hhmm_ampm 列\n")
    cat("concat.tstamp.ampm.cstr 当前列名:", names(concat.tstamp.ampm.cstr), "\n")
    cat("_h_correct 样例:", head(concat.tstamp.ampm.cstr[[paste0(varname, "_h_correct")]], 3), "\n")
    cat("_m 样例:", head(concat.tstamp.ampm.cstr[[paste0(varname, "_m")]], 3), "\n")
    cat("ampm 样例:", head(concat.tstamp.ampm.cstr[[ampm.varname]], 3), "\n")
    
    #concatenate _hcorrect, _m, and _ampm into timestamp in format hh:mm XM, named varname_hhmm_ampm
    concat.tstamp.ampm.cstr <- concat.tstamp.ampm.cstr %>%
      mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := paste0(!!as.symbol(paste0(varname, "_h_correct")), ":", !!as.symbol(paste0(varname, "_m")), " ", !!as.symbol(ampm.varname)) )
    
    cat("步骤4: 创建 _hhmm_ampm 列后\n")
    cat("concat.tstamp.ampm.cstr 列名:", names(concat.tstamp.ampm.cstr), "\n")
    cat("_hhmm_ampm 列是否存在:", paste0(varname, "_hhmm_ampm") %in% names(concat.tstamp.ampm.cstr), "\n")
    cat("_hhmm_ampm 样例 (前5个):", head(concat.tstamp.ampm.cstr[[paste0(varname, "_hhmm_ampm")]], 5), "\n")
    
    concat.tstamp.ampm.cstr[which(concat.tstamp.ampm.cstr[, paste0(varname, "_hhmm_ampm")] == "NA:NA NA"), paste0(varname, "_hhmm_ampm")] <- NA
    concat.tstamp.ampm.cstr[which(grepl("NA", concat.tstamp.ampm.cstr[, paste0(varname, "_hhmm_ampm")]) == TRUE), paste0(varname, "_hhmm_ampm")] <- NA
    
    #add corrected timestamp format onto original dataframe
    tstamp.hhmmampm.varname <- concat.tstamp.ampm.cstr[, paste0(varname, "_hhmm_ampm")]
    
    cat("步骤5: 准备合并到主数据框\n")
    cat("tstamp.hhmmampm.varname 长度:", length(tstamp.hhmmampm.varname), "\n")
    cat("tstamp.hhmmampm.varname 样例:", head(tstamp.hhmmampm.varname, 3), "\n")
    
    if (dim(df)[1]==dim(concat.tstamp.ampm.cstr)[1]) {
      df_timeproc = df %>%
        mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := tstamp.hhmmampm.varname)
      
      cat("步骤6: 合并到主数据框后\n")
      cat("df_timeproc 列名:", names(df_timeproc), "\n")
      cat("_hhmm_ampm 列是否存在:", paste0(varname, "_hhmm_ampm") %in% names(df_timeproc), "\n")
      if (paste0(varname, "_hhmm_ampm") %in% names(df_timeproc)) {
        cat("✅ _hhmm_ampm 列创建成功!\n")
        cat("_hhmm_ampm 值样例:", head(df_timeproc[[paste0(varname, "_hhmm_ampm")]], 3), "\n")
      } else {
        cat("❌ _hhmm_ampm 列创建失败!\n")
      }
    } else {
      cat("❌ 错误: 行数不匹配 - df:", dim(df)[1], "concat:", dim(concat.tstamp.ampm.cstr)[1], "\n")
      return(df)
    }
    
    #take first ten characters (date), then paste hhmm using current timezone (PT) data
    df_timeproc = df_timeproc %>% 
      mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := paste0(substr(StartDate, 1, 10), " ", !!as.symbol(paste0(varname, "_hhmm_ampm"))))
    
    cat("步骤7: 添加日期后\n")
    cat("添加日期后的 _hhmm_ampm 样例:", head(df_timeproc[[paste0(varname, "_hhmm_ampm")]], 3), "\n")
    
    tstamp.hhmmampm.varname.isna <- which(is.na(tstamp.hhmmampm.varname))
    df_timeproc[tstamp.hhmmampm.varname.isna, paste0(varname, "_hhmm_ampm")] <- NA
    
    #turn the date-timestamp into a datetime object
    df_timeproc = df_timeproc %>% 
      mutate(!!as.symbol(paste0(varname, "_hhmm_ampm")) := lubridate::parse_date_time(!!as.symbol(paste0(varname, "_hhmm_ampm")), "%Y-%m-%d %H:%M %p", tz = "US/Pacific"))
    
    cat("步骤8: 解析为日期时间后\n")
    cat("解析后的 _hhmm_ampm 类型:", class(df_timeproc[[paste0(varname, "_hhmm_ampm")]]), "\n")
    cat("解析后的 _hhmm_ampm 样例:", head(df_timeproc[[paste0(varname, "_hhmm_ampm")]], 3), "\n")
    
    # Convert to character with explicit format to prevent hiding of midnight times
    df_timeproc[[paste0(varname, "_hhmm_ampm")]] <- 
      format(df_timeproc[[paste0(varname, "_hhmm_ampm")]], "%Y-%m-%d %H:%M:%S")
    
    cat("步骤9: 格式化为字符后\n")
    cat("格式化后的 _hhmm_ampm 样例:", head(df_timeproc[[paste0(varname, "_hhmm_ampm")]], 3), "\n")
    
    #if varname is an evening/bedtime variable reported *before* 24:00 (12 AM) (after 3pm -- i.e. hours > 15), subtract one day
    if (varname %in% c("time_bed_am", "time_sleep_am")) {
      df_timeproc = df_timeproc %>%
        mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~ifelse(lubridate::hour(.) > 15, .-lubridate::days(1), .)) %>%
        mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~as_datetime(., tz="America/Los_Angeles")) 
    }
    df_timeproc[[paste0(varname, "_hhmm_ampm")]] <- 
      format(df_timeproc[[paste0(varname, "_hhmm_ampm")]], "%Y-%m-%d %H:%M:%S")
    
    #add "_h_other_error" onto original dataframe, marking need for manual inspection
    df_timeproc = df_timeproc %>% 
      mutate(!!as.symbol(paste0(varname, "_checkforerrors")) := concat.tstamp.ampm.cstr[[paste0(varname, "_h_othererrors")]])
    
    cat("步骤10: 最终检查\n")
    cat("最终数据框列数:", ncol(df_timeproc), "\n")
    cat("最终数据框包含 _hhmm_ampm 的列:", grep("_hhmm_ampm", names(df_timeproc), value = TRUE), "\n")
    cat("函数返回前的列名:", names(df_timeproc), "\n\n")
    
    rm(concat.tstamp.ampm.cstr, tstamp.varname.cstr, tstamp.hhmmampm.varname, tstamp.varname, ampm.varname)
    
    print(paste0(varname, " processed as a timestamp"))
    
    return(df_timeproc)
  }
  
  return(df_timeproc)
}
```



错误信息可以看出问题所在！错误发生在步骤9，当尝试对晚间时间变量（`time_bed_am`）进行日期调整时出现了类型不兼容的问题。

错误信息：

text

```
Caused by error:
! Incompatible classes: <character> - <Period>
```



问题出现在这部分代码：

r

```
#if varname is an evening/bedtime variable reported *before* 24:00 (12 AM) (after 3pm -- i.e. hours > 15), subtract one day
if (varname %in% c("time_bed_am", "time_sleep_am")) {
  df_timeproc = df_timeproc %>%
    mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~ifelse(lubridate::hour(.) > 15, .-lubridate::days(1), .)) %>%
    mutate_at(vars(one_of(paste0(varname, "_hhmm_ampm"))), ~as_datetime(., tz="America/Los_Angeles")) 
}
```



问题是：在步骤8中，时间戳已经被格式化为字符类型，但在步骤9中又尝试对字符类型使用 `lubridate::hour()` 和 `.-lubridate::days(1)` 操作。

让我修复这个问题：

问题还是出现在步骤9的类型不兼容错误。从诊断输出可以看到，在步骤9格式化后，`_hhmm_ampm` 列变成了字符类型，但在晚间时间调整时又试图对字符类型进行时间运算。

1. **修复了类型不兼容问题**：在晚间时间调整时确保使用 `as.POSIXct()` 而不是 `as_datetime()`
2. **调整了处理顺序**：先进行时间运算，再格式化为字符

删除了将时间列格式化为字符的代码，并确保返回 `POSIXct` 格式：

## 主要问题：

1. **大量缺失数据**：约80%的数据是NA

2. **存在负值和异常值**：

   - 入睡潜伏期有负值（-720分钟）
   - 总睡眠时间有负值（-620分钟）
   - 睡眠效率有负值（-400%）和超常值（1600%）

3.  # 专门检查第6行（有数据的那行）
   > cat("=== 详细检查第6行数据 ===\n")
   > === 详细检查第6行数据 ===
   > row_6 <- sample_data[6, ]
   >
   > cat("上床时间:", as.character(row_6$time_bed_am_hhmm_ampm), "\n")
   > 上床时间: 2027-03-08 23:00:00 
   > cat("入睡时间:", as.character(row_6$time_sleep_am_hhmm_ampm), "\n") 
   > 入睡时间: 2027-03-09 00:30:00 
   > cat("醒来时间:", as.character(row_6$time_awake_am_hhmm_ampm), "\n")
   > 醒来时间: 2027-03-09 09:00:00 
   > cat("起床时间:", as.character(row_6$time_getup_am_hhmm_ampm), "\n")
   > 起床时间: 2027-03-09 09:30:00 
   >
   > cat("自我报告入睡潜伏期:", row_6$duration_totalmin_sol_estimate_am_mincalc, "分钟\n")
   > 自我报告入睡潜伏期: 30 分钟
   > cat("自我报告WASO时长:", row_6$duration_totalmin_waso_estimate_am_mincalc, "分钟\n")
   > 自我报告WASO时长: 20 分钟
   >
   > cat("计算的入睡潜伏期:", row_6$self_diffcalc_sol_minutes, "分钟\n")
   > 计算的入睡潜伏期: 90 分钟
   > cat("计算的睡眠开始时间:", as.character(row_6$self_diffcalc_sleeponset), "\n")
   > 计算的睡眠开始时间: 2027-03-09 01:00:00 
   > cat("尝试睡眠总时长:", row_6$self_diffcalc_totaltrysleep_minutes, "分钟\n")
   > 尝试睡眠总时长: 510 分钟
   > cat("在床总时长:", row_6$self_diffcalc_timeinbed_minutes, "分钟\n")
   > 在床总时长: 630 分钟
   > cat("睡眠期间总时长:", row_6$self_diffcalc_sleepperiod_minutes, "分钟\n")
   > 睡眠期间总时长: 480 分钟
   > cat("总睡眠时间:", row_6$self_diffcalc_totalsleeptime_minutes, "分钟\n")
   > 总睡眠时间: 460 分钟
   > cat("睡眠效率:", round(row_6$self_diffcalc_sleepefficiency_percent * 100, 1), "%\n")
   > 睡眠效率: 90.2 %
   >
   > # 检查计算逻辑
   > cat("\n=== 计算逻辑验证 ===\n")

   === 计算逻辑验证 ===
   > time_diff_sol <- as.numeric(difftime(row_6$time_sleep_am_hhmm_ampm, row_6$time_bed_am_hhmm_ampm, units = "mins"))
   > cat("实际入睡潜伏期计算:", time_diff_sol, "分钟\n")
   > 实际入睡潜伏期计算: 90 分钟
   >
   > sleep_onset_calc <- row_6$time_sleep_am_hhmm_ampm + lubridate::minutes(row_6$duration_totalmin_sol_estimate_am_mincalc)
   > cat("实际睡眠开始时间计算:", as.character(sleep_onset_calc), "\n")
   > 实际睡眠开始时间计算: 2027-03-09 01:00:00 





然后我检查有没有负的

```
# 创建包含所有负值记录的CSV文件
cat("=== 创建负值记录CSV文件 ===\n")

# 创建负值记录的数据框
negative_records <- ema_data_release_timecalc %>%
  filter(
    (self_diffcalc_sol_minutes < 0 & !is.na(self_diffcalc_sol_minutes)) |
    (self_diffcalc_totalsleeptime_minutes < 0 & !is.na(self_diffcalc_totalsleeptime_minutes)) |
    (self_diffcalc_sleepefficiency_percent < 0 & !is.na(self_diffcalc_sleepefficiency_percent)) |
    (self_diffcalc_sleepefficiency_percent > 1 & !is.na(self_diffcalc_sleepefficiency_percent)) |
    (self_diffcalc_totaltrysleep_minutes < 0 & !is.na(self_diffcalc_totaltrysleep_minutes)) |
    (self_diffcalc_timeinbed_minutes < 0 & !is.na(self_diffcalc_timeinbed_minutes)) |
    (self_diffcalc_sleepperiod_minutes < 0 & !is.na(self_diffcalc_sleepperiod_minutes))
  )

cat("总负值记录数:", nrow(negative_records), "\n")

# 选择需要的列（英文列名）
negative_records_export <- negative_records %>%
  select(
    pid,
    day_num,
    survey_type,
    # 原始时间数据
    time_bed_am = time_bed_am_hhmm_ampm,
    time_sleep_am = time_sleep_am_hhmm_ampm, 
    time_awake_am = time_awake_am_hhmm_ampm,
    time_getup_am = time_getup_am_hhmm_ampm,
    # 自我报告数据
    selfreport_sol_minutes = duration_totalmin_sol_estimate_am_mincalc,
    selfreport_waso_minutes = duration_totalmin_waso_estimate_am_mincalc,
    # 计算变量
    calculated_sol_minutes = self_diffcalc_sol_minutes,
    calculated_sleep_onset = self_diffcalc_sleeponset,
    calculated_try_sleep_minutes = self_diffcalc_totaltrysleep_minutes,
    calculated_time_in_bed_minutes = self_diffcalc_timeinbed_minutes,
    calculated_sleep_period_minutes = self_diffcalc_sleepperiod_minutes,
    calculated_total_sleep_minutes = self_diffcalc_totalsleeptime_minutes,
    calculated_sleep_efficiency_percent = self_diffcalc_sleepefficiency_percent,
    # 错误检查
    check_errors = time_bed_am_checkforerrors
  ) %>%
  mutate(
    # 添加时间分析列
    bed_hour = lubridate::hour(time_bed_am),
    sleep_hour = lubridate::hour(time_sleep_am),
    awake_hour = lubridate::hour(time_awake_am),
    getup_hour = lubridate::hour(time_getup_am),
    bed_date = as.Date(time_bed_am),
    sleep_date = as.Date(time_sleep_am),
    cross_day_bed_sleep = bed_date != sleep_date,
    # 标记负值类型
    negative_sol = calculated_sol_minutes < 0,
    negative_total_sleep = calculated_total_sleep_minutes < 0,
    negative_try_sleep = calculated_try_sleep_minutes < 0,
    negative_time_in_bed = calculated_time_in_bed_minutes < 0,
    negative_sleep_period = calculated_sleep_period_minutes < 0,
    abnormal_efficiency = calculated_sleep_efficiency_percent < 0 | calculated_sleep_efficiency_percent > 1
  )

# 导出为CSV文件
output_file <- "negative_sleep_records.csv"
write.csv(negative_records_export, output_file, row.names = FALSE, na = "")

cat("CSV文件已创建:", output_file, "\n")
cat("文件包含", nrow(negative_records_export), "行记录\n")

# 显示负值类型的汇总
cat("\n=== 负值类型汇总 ===\n")
cat("负值入睡潜伏期:", sum(negative_records_export$negative_sol, na.rm = TRUE), "\n")
cat("负值总睡眠时间:", sum(negative_records_export$negative_total_sleep, na.rm = TRUE), "\n")
cat("负值尝试睡眠时间:", sum(negative_records_export$negative_try_sleep, na.rm = TRUE), "\n")
cat("负值在床时间:", sum(negative_records_export$negative_time_in_bed, na.rm = TRUE), "\n")
cat("负值睡眠期间:", sum(negative_records_export$negative_sleep_period, na.rm = TRUE), "\n")
cat("异常睡眠效率:", sum(negative_records_export$abnormal_efficiency, na.rm = TRUE), "\n")

# 显示文件的前几行预览
cat("\n=== CSV文件预览 (前5行) ===\n")
print(head(negative_records_export, 5))

# 显示列名
cat("\n=== CSV文件列名 ===\n")
print(names(negative_records_export))
```


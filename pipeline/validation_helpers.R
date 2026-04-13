# ============================================
# sleep_processing_pipeline.R - 完整版本
# 保存这个为 sleep_processing_pipeline.R 文件
# ============================================

library(lubridate)
library(tidyverse)

# 1. 配置设置 ---------------------------------------------------
options(warn = 2)  # 将警告转为错误，便于调试

# 2. 初始化函数 -------------------------------------------------
initialize_environment <- function() {
  cat("\n" , paste(rep("=", 60), collapse = ""), "\n", sep = "")
  cat("SLEEP DATA PROCESSING PIPELINE - INITIALIZATION\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
  
  # 检查必需文件
  required_files <- c(
    "process_timestamp_emadatarelease_cyra.R",
    "process_interval.R",
    "correct_and_calculate_sleep_time_vars_cyra_MtB.R"
  )
  
  missing_files <- required_files[!file.exists(required_files)]
  if (length(missing_files) > 0) {
    cat("\n❌ MISSING REQUIRED FILES:\n")
    cat(paste("  -", missing_files, collapse = "\n"))
    stop("Please ensure all required files are in the working directory")
  }
  
  # 检查验证助手（可选）
  if (file.exists("validation_helpers.R")) {
    cat("✓ Validation helpers found\n")
  } else {
    cat("⚠️  Validation helpers not found, will use built-in validation\n")
  }
  
  cat("✓ All required files found\n")
}

# 3. 加载数据函数 -----------------------------------------------
load_and_prepare_data <- function() {
  cat("\n📂 LOADING AND PREPARING DATA\n")
  
  # 加载原始数据
  if (!file.exists("deidentified_intervalvars_forCD_111325.rds")) {
    stop("Data file not found: deidentified_intervalvars_forCD_111325.rds")
  }
  
  df <- readRDS("deidentified_intervalvars_forCD_111325.rds")
  df$StartDate <- as.Date("2027-03-01")
  
  cat("✓ Data loaded:", nrow(df), "rows,", ncol(df), "columns\n")
  return(df)
}

# 4. 时间戳处理函数 ---------------------------------------------
process_timestamp_variables <- function(df) {
  cat("\n⏰ PROCESSING TIMESTAMP VARIABLES\n")
  
  source("process_timestamp_emadatarelease_cyra.R")
  
  tstamp.vars.to.proc <- c(
    "time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am", 
    "caffeinetoday_PM", "alcoholtoday_PM", "nicotine_amount_pm", "cannabis_amount_pm"
  )
  
  result_df <- df
  
  for (varname in tstamp.vars.to.proc) {
    cat("  Processing:", varname, "... ")
    result_df <- process_timestamp(
      df = result_df, 
      varname = varname, 
      format = "timestamp"
    )
    cat("Done\n")
  }
  
  # 修正特定值
  result_df$exercisetoday_PM_totalmin_Moderate[3992] <- "01:30"
  cat("✓ Applied manual correction to row 3992\n")
  
  return(result_df)
}

# 5. 时长变量处理函数 -------------------------------------------
process_interval_variables <- function(df) {
  cat("\n⏱️ PROCESSING INTERVAL VARIABLES\n")
  
  source("process_interval.R")
  
  interval.vars.to.proc <- c(
    "duration_totalmin_sol_estimate_am", 
    "duration_totalmin_waso_estimate_am",
    "duration_totalmin_napstoday_PM",
    "exercisetoday_PM_totalmin_Light",
    "exercisetoday_PM_totalmin_Moderate", 
    "exercisetoday_PM_totalmin_Vigorous",
    "exercisetoday_PM_totalmin_Strength"
  )
  
  result_df <- df
  
  for (varname in interval.vars.to.proc) {
    cat("  Processing:", varname, "... ")
    result_df <- process_interval(
      df = result_df, 
      varname = varname, 
      format = "interval_hhmm"
    )
    cat("Done\n")
  }
  
  return(result_df)
}

# 6. 主睡眠处理函数 ---------------------------------------------
run_sleep_processing <- function(df, timeout_seconds = 300) {
  cat("\n" , paste(rep("=", 60), collapse = ""), "\n", sep = "")
  cat("SLEEP TIME PROCESSING (MAIN FUNCTION)\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
  
  source("correct_and_calculate_sleep_time_vars_cyra_MtB.R")
  
  result <- NULL
  processing_start <- Sys.time()
  
  cat("Processing", nrow(df), "records\n")
  cat("Timeout setting:", timeout_seconds, "seconds\n")
  
  tryCatch({
    # 检查是否安装 R.utils
    if (requireNamespace("R.utils", quietly = TRUE)) {
      cat("Using R.utils::withTimeout for timeout control\n")
      R.utils::withTimeout({
        result <- correct_and_calculate_sleep_time_vars(AM_rawdata = df)
      }, timeout = timeout_seconds, onTimeout = "error")
    } else {
      cat("Using base R setTimeLimit for timeout control\n")
      setTimeLimit(elapsed = timeout_seconds, transient = TRUE)
      result <- correct_and_calculate_sleep_time_vars(AM_rawdata = df)
      setTimeLimit(elapsed = Inf, transient = TRUE)
    }
    
    processing_time <- round(as.numeric(difftime(Sys.time(), processing_start, units = "secs")), 1)
    cat("✓ Processing completed in", processing_time, "seconds\n")
    
  }, error = function(e) {
    processing_time <- round(as.numeric(difftime(Sys.time(), processing_start, units = "secs")), 1)
    
    cat("\n❌ PROCESSING ", 
        if(grepl("reached elapsed time limit|timeout", e$message, ignore.case = TRUE)) 
          "TIMED OUT" else "FAILED", 
        "\n", sep = "")
    cat("   Error:", e$message, "\n")
    cat("   Processing time:", processing_time, "seconds\n")
    
    # 尝试保存部分结果
    if (exists("diary_am")) {
      cat("   Saving partial results...\n")
      partial_result <- list(
        all_data = diary_am,
        error_message = e$message,
        processing_time = processing_time,
        status = "partial"
      )
      saveRDS(partial_result, "sleep_processing_partial_result.rds")
      cat("   ✓ Partial results saved\n")
    }
    
    result <- list(
      error = e$message,
      processing_time = processing_time,
      status = "failed"
    )
    
  }, finally = {
    try(setTimeLimit(elapsed = Inf, transient = TRUE), silent = TRUE)
  })
  
  return(list(
    result = result,
    processing_time = round(as.numeric(difftime(Sys.time(), processing_start, units = "secs")), 1)
  ))
}

# 7. 核心验证函数（内置，不依赖外部文件）------------------------
run_comprehensive_validation <- function(result) {
  cat("\n" , paste(rep("=", 60), collapse = ""), "\n", sep = "")
  cat("COMPREHENSIVE VALIDATION ANALYSIS\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
  
  data <- result$all_data
  
  # 1. 基础质量报告
  cat("\n📊 DATA QUALITY OVERVIEW:\n")
  if ("data_quality_flag" %in% names(data)) {
    quality_counts <- table(data$data_quality_flag, useNA = "ifany")
    for (flag in names(quality_counts)) {
      count <- quality_counts[flag]
      percent <- round(count / nrow(data) * 100, 1)
      cat("  ", flag, ": ", count, " (", percent, "%)\n", sep = "")
    }
  }
  
  # 2. 早睡者分析（Maia的核心关切）
  cat("\n🔍 EARLY SLEEPER ANALYSIS (21:30 Rule):\n")
  if ("time_sleep_corrected" %in% names(data)) {
    tryCatch({
      early_sleepers <- data %>%
        mutate(
          sleep_hour = hour(time_sleep_corrected),
          sleep_minute = minute(time_sleep_corrected),
          sleep_decimal = sleep_hour + sleep_minute/60,
          is_early_sleeper = sleep_decimal < 21.5 & !is.na(sleep_decimal)
        ) %>%
        filter(is_early_sleeper == TRUE)
      
      cat("   Early sleepers (<21:30):", nrow(early_sleepers), "\n")
      
      if (nrow(early_sleepers) > 0 && "data_quality_flag" %in% names(early_sleepers)) {
        corrected_early <- early_sleepers %>%
          filter(data_quality_flag == "time_corrected")
        
        cat("   Corrected early sleepers:", nrow(corrected_early), "\n")
        cat("   Percentage corrected:", round(nrow(corrected_early) / nrow(early_sleepers) * 100, 1), "%\n")
        
        if (nrow(corrected_early) > 0) {
          cat("   ⚠️  WARNING: ", nrow(corrected_early), 
              " early sleepers were corrected!\n", sep = "")
          
          # 显示被校正的早睡者样本
          cat("\n   Sample of corrected early sleepers (first 5):\n")
          sample_cases <- corrected_early %>%
            mutate(
              sleep_time = format(time_sleep_corrected, "%H:%M"),
              awake_time = format(time_awake_corrected, "%H:%M")
            ) %>%
            select(any_of(c("row_id", "sleep_time", "awake_time", "data_quality_flag"))) %>%
            head(5)
          print(sample_cases)
        }
      }
    }, error = function(e) {
      cat("   Error in early sleeper analysis:", e$message, "\n")
    })
  }
  
  # 3. 睡眠时长分析
  cat("\n📏 SLEEP DURATION ANALYSIS:\n")
  if ("self_diffcalc_sleepperiod_minutes" %in% names(data)) {
    tryCatch({
      # 数据可用性
      valid_records <- sum(!is.na(data$self_diffcalc_sleepperiod_minutes))
      total_records <- nrow(data)
      
      cat("   Records with sleep duration data:", valid_records, "\n")
      cat("   Percentage with data:", round(valid_records / total_records * 100, 2), "%\n")
      
      if (valid_records > 0) {
        # 描述性统计
        sleep_stats <- data %>%
          filter(!is.na(self_diffcalc_sleepperiod_minutes)) %>%
          mutate(duration_hrs = self_diffcalc_sleepperiod_minutes / 60) %>%
          summarise(
            mean_hrs = round(mean(duration_hrs), 2),
            median_hrs = round(median(duration_hrs), 2),
            sd_hrs = round(sd(duration_hrs), 2),
            min_hrs = round(min(duration_hrs), 2),
            max_hrs = round(max(duration_hrs), 2)
          )
        
        cat("\n   Sleep duration statistics (hours):\n")
        cat("     Mean ± SD: ", sleep_stats$mean_hrs, " ± ", sleep_stats$sd_hrs, "\n")
        cat("     Median: ", sleep_stats$median_hrs, "\n")
        cat("     Range: ", sleep_stats$min_hrs, " to ", sleep_stats$max_hrs, "\n")
        
        # 分布
        duration_dist <- data %>%
          filter(!is.na(self_diffcalc_sleepperiod_minutes)) %>%
          mutate(
            duration_hrs = self_diffcalc_sleepperiod_minutes / 60,
            category = case_when(
              duration_hrs < 3 ~ "Too short (<3h)",
              duration_hrs >= 3 & duration_hrs < 5 ~ "Very short (3-5h)",
              duration_hrs >= 5 & duration_hrs < 7 ~ "Short (5-7h)",
              duration_hrs >= 7 & duration_hrs <= 9 ~ "Normal (7-9h)",
              duration_hrs > 9 & duration_hrs <= 12 ~ "Long (9-12h)",
              duration_hrs > 12 ~ "Extremely long (>12h)",
              TRUE ~ "Unknown"
            )
          ) %>%
          group_by(category) %>%
          summarise(
            count = n(),
            percentage = round(n() / valid_records * 100, 2)
          )
        
        cat("\n   Distribution:\n")
        for (i in 1:nrow(duration_dist)) {
          cat("     ", duration_dist$category[i], ": ", 
              duration_dist$count[i], " (", duration_dist$percentage[i], "%)\n", sep = "")
        }
      }
    }, error = function(e) {
      cat("   Error in sleep duration analysis:", e$message, "\n")
    })
  }
  
  # 4. 保存验证结果
  if (!dir.exists("validation_results")) {
    dir.create("validation_results")
  }
  
  validation_summary <- list(
    early_sleepers_count = if(exists("early_sleepers")) nrow(early_sleepers) else 0,
    corrected_early_count = if(exists("corrected_early")) nrow(corrected_early) else 0,
    sleep_stats = if(exists("sleep_stats")) sleep_stats else NULL
  )
  
  saveRDS(validation_summary, "validation_results/validation_summary.rds")
  cat("\n💾 Validation summary saved to: validation_results/validation_summary.rds\n")
  
  return(validation_summary)
}

# 8. 验证和报告函数 ---------------------------------------------
generate_validation_reports <- function(processing_result) {
  cat("\n" , paste(rep("=", 60), collapse = ""), "\n", sep = "")
  cat("VALIDATION AND REPORTING\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
  
  result <- processing_result$result
  
  if (!is.null(result$error)) {
    cat("❌ Cannot generate reports - processing failed\n")
    cat("   Error:", result$error, "\n")
    return(NULL)
  }
  
  if (is.null(result$all_data)) {
    cat("⚠️  Cannot generate reports - no data in result\n")
    return(NULL)
  }
  
  # 运行内置验证分析
  validation_summary <- run_comprehensive_validation(result)
  
  # 尝试加载外部验证助手（可选）
  tryCatch({
    if (file.exists("validation_helpers.R")) {
      source("validation_helpers.R", local = TRUE)
      cat("✓ External validation helpers loaded\n")
      
      # 尝试运行外部验证函数
      if (exists("generate_maia_validation_report")) {
        cat("✓ Running external validation report...\n")
        external_report <- generate_maia_validation_report(result)
      }
    }
  }, error = function(e) {
    cat("⚠️  External validation skipped:", e$message, "\n")
  })
  
  # 保存完整结果
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  output_file <- paste0("sleep_processing_complete_", timestamp, ".rds")
  saveRDS(result, output_file)
  cat("\n💾 Complete results saved as:", output_file, "\n")
  
  return(validation_summary)
}

# 9. 生成最终摘要 -----------------------------------------------
generate_final_summary <- function(processing_result, validation_report) {
  cat("\n", paste(rep("=", 60), collapse = ""), "\n", sep = "")
  cat("FINAL SUMMARY - MAIA REPORT\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
  
  result <- processing_result$result
  processing_time <- processing_result$processing_time
  
  cat("🎯 PROCESSING RESULTS:\n")
  cat("   Total processing time:", processing_time, "seconds\n")
  cat("   Status: COMPLETED ✓\n\n")
  
  if (!is.null(result$error)) {
    cat("❌ Processing failed:", result$error, "\n")
    return()
  }
  
  if (is.null(result$all_data)) {
    cat("⚠️  No data available\n")
    return()
  }
  
  data <- result$all_data
  
  cat("📊 DATA OVERVIEW:\n")
  cat("   Total records:", nrow(data), "\n")
  
  if ("data_quality_flag" %in% names(data)) {
    clean_count <- sum(data$data_quality_flag == "clean", na.rm = TRUE)
    clean_pct <- round(clean_count / nrow(data) * 100, 1)
    cat("   Clean records:", clean_count, "(", clean_pct, "%)\n")
    
    corrected_count <- sum(data$data_quality_flag == "time_corrected", na.rm = TRUE)
    if (corrected_count > 0) {
      cat("   Time-corrected records:", corrected_count, "\n")
    }
  }
  
  # Maia关心的关键问题
  cat("\n🔍 ANSWERS TO MAIA'S KEY QUESTIONS:\n")
  cat("   ", paste(rep("-", 50), collapse = ""), "\n", sep = "")
  
  if (!is.null(validation_report)) {
    cat("\n1. EARLY SLEEPERS (21:30 Rule):\n")
    cat("   Early sleepers (<21:30):", validation_report$early_sleepers_count, "\n")
    cat("   Corrected early sleepers:", validation_report$corrected_early_count, "\n")
    
    if (validation_report$corrected_early_count > 0) {
      cat("   ⚠️  WARNING: Some genuine early sleepers may have been incorrectly corrected\n")
      cat("   Recommendation: Review these ", validation_report$corrected_early_count, 
          " cases manually\n", sep = "")
    } else {
      cat("   ✅ Good: No early sleepers were incorrectly corrected\n")
    }
    
    cat("\n2. SLEEP DURATION QUALITY:\n")
    if (!is.null(validation_report$sleep_stats)) {
      cat("   Mean sleep duration:", validation_report$sleep_stats$mean_hrs, "hours\n")
      cat("   Median sleep duration:", validation_report$sleep_stats$median_hrs, "hours\n")
      cat("   Sleep duration range:", validation_report$sleep_stats$min_hrs, "to", 
          validation_report$sleep_stats$max_hrs, "hours\n")
    }
    
    # 从原始输出中获取更多信息
    if ("processing_summary" %in% names(result)) {
      cat("\n3. PROCESSING DECISIONS:\n")
      if ("special_treatment_log" %in% names(result)) {
        special_cases <- result$special_treatment_log
        if (!is.null(special_cases) && nrow(special_cases) > 0) {
          cat("   Special treatment cases:", nrow(special_cases), "\n")
          cat("   These are borderline cases that needed manual rules\n")
        }
      }
      
      if ("swap_log" %in% names(result)) {
        swaps <- result$swap_log
        if (!is.null(swaps) && nrow(swaps) > 0) {
          cat("   Time-swap corrections:", nrow(swaps), "\n")
          cat("   (6-hour threshold for obvious errors)\n")
        }
      }
    }
  }
  
  cat("\n💡 RECOMMENDATIONS FOR MAIA:\n")
  cat("   ", paste(rep("-", 50), collapse = ""), "\n", sep = "")
  cat("1. Review the ", if(!is.null(validation_report)) validation_report$corrected_early_count else "unknown", 
      " corrected early sleepers\n", sep = "")
  cat("2. Check if 21:30 threshold is appropriate for this population\n")
  cat("3. Examine validation_results/validation_summary.rds for details\n")
  cat("4. If satisfied, data processing rules are working correctly\n")
  cat("5. If unsure, flag specific cases for discussion\n")
  
  # 列出生成的文件
  cat("\n📁 GENERATED FILES:\n")
  files <- list.files(pattern = "sleep_processing|validation_results|pipeline_error", 
                      full.names = TRUE)
  if (length(files) > 0) {
    for (file in files) {
      if (file.exists(file)) {
        file_info <- file.info(file)
        size_kb <- round(file_info$size/1024, 1)
        mtime <- format(file_info$mtime, "%H:%M")
        cat("   - ", basename(file), " (", size_kb, " KB, ", mtime, ")\n", sep = "")
      }
    }
  }
  
  cat("\n", paste(rep("=", 60), collapse = ""), "\n", sep = "")
  cat("END OF MAIA REPORT\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
}

# 10. 主执行流程 -------------------------------------------------
main <- function() {
  cat(paste(rep("=", 60), collapse = ""), "\n", sep = "")
  cat("STARTING SLEEP DATA PROCESSING PIPELINE\n")
  cat(paste(rep("=", 60), collapse = ""), "\n\n")
  
  tryCatch({
    # 步骤1: 初始化
    initialize_environment()
    
    # 步骤2: 加载数据
    raw_data <- load_and_prepare_data()
    
    # 步骤3: 时间戳处理
    timestamp_processed <- process_timestamp_variables(raw_data)
    
    # 步骤4: 时长变量处理
    interval_processed <- process_interval_variables(timestamp_processed)
    
    # 步骤5: 主睡眠处理
    processing_result <- run_sleep_processing(interval_processed)
    
    # 步骤6: 验证和报告
    if (is.null(processing_result$result$error)) {
      validation_report <- generate_validation_reports(processing_result)
    } else {
      validation_report <- NULL
    }
    
    # 步骤7: 最终摘要（专门为Maia设计的报告）
    generate_final_summary(processing_result, validation_report)
    
    cat("\n", paste(rep("=", 60), collapse = ""), "\n", sep = "")
    cat("🎉 PROCESSING PIPELINE COMPLETED SUCCESSFULLY\n")
    cat(paste(rep("=", 60), collapse = ""), "\n")
    
  }, error = function(e) {
    cat("\n", paste(rep("=", 60), collapse = ""), "\n", sep = "")
    cat("🔥 CRITICAL ERROR IN PROCESSING PIPELINE\n")
    cat(paste(rep("=", 60), collapse = ""), "\n")
    cat("Error:", e$message, "\n")
    
    # 获取traceback信息
    cat("Traceback:\n")
    tb <- tryCatch(traceback(max.lines = 3), error = function(e) NULL)
    if (!is.null(tb) && length(tb) > 0) {
      for (i in seq_along(tb)) {
        if (length(tb[[i]]) > 0) {
          cat(" ", i, ": ", paste(tb[[i]], collapse = " -> "), "\n", sep = "")
        }
      }
    } else {
      cat(" No traceback available\n")
    }
    
    # 尝试保存错误信息
    error_info <- list(
      error = e$message,
      timestamp = Sys.time(),
      traceback = if(!is.null(tb) && length(tb) > 0) tb else NULL
    )
    try(saveRDS(error_info, "pipeline_error.rds"), silent = TRUE)
    cat("\nError details saved to: pipeline_error.rds\n")
  })
}

# 11. 执行主函数 -------------------------------------------------
cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
cat("SLEEP DATA PROCESSING PIPELINE - MAIA-FOCUSED VERSION\n")
cat(paste(rep("=", 80), collapse = ""), "\n\n")

# 记录开始时间
start_time <- Sys.time()
cat("Start time:", format(start_time, "%Y-%m-%d %H:%M:%S"), "\n\n")

# 执行主流程
main()

# 记录结束时间
end_time <- Sys.time()
total_time <- round(as.numeric(difftime(end_time, start_time, units = "mins")), 1)
cat("\n" , paste(rep("-", 60), collapse = ""), "\n", sep = "")
cat("Total pipeline execution time:", total_time, "minutes\n")
cat("End time:", format(end_time, "%Y-%m-%d %H:%M:%S"), "\n")

# 清理临时变量
rm(list = setdiff(ls(), c("main", "initialize_environment", "load_and_prepare_data", 
                          "process_timestamp_variables", "process_interval_variables",
                          "run_sleep_processing", "generate_validation_reports", 
                          "generate_final_summary", "run_comprehensive_validation")))
cat("✓ Pipeline completed. Functions remain in environment for debugging.\n")
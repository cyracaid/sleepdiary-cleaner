library(lubridate)
library(tidyverse)

rm(list = ls())
df <- readRDS("deidentified_intervalvars_forCD_111325.rds")
full_df <- read.csv("sber_ema_anon_20260227.csv")
df <- df %>%
  mutate(
    StartDate = full_df$StartDate,
    num_waso_am = full_df$num_waso,
    num_waso_estimate_am = full_df$num_waso_estimate_am,
  )
#df$StartDate <- as.Date("2027-03-15")
source("process_timestamp_emadatarelease_cyra.R")
source("process_interval.R")

# 选择所有包含时间信息的列
tstamp.vars.to.proc <- c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am", 
                         "caffeinetoday_PM", "alcoholtoday_PM", "nicotine_amount_pm", "cannabis_amount_pm")

ema_data_release_timeproc <- df  # 初始化

# 处理时间戳变量
for (varname.count in 1:length(tstamp.vars.to.proc)) {
  ema_data_release_timeproc <- process_timestamp(
    df = ema_data_release_timeproc, 
    varname = tstamp.vars.to.proc[varname.count], 
    format = "timestamp"
  )
}
rm(varname.count)

# 在已处理的数据上修改，而不是原始数据
ema_data_release_timeproc$exercisetoday_PM_totalmin_Moderate[3992] <- "01:30"

# 定义要处理的时长变量
interval.vars.to.proc <- c("duration_totalmin_sol_estimate_am", 
                           "duration_totalmin_waso_estimate_am",
                           "duration_totalmin_napstoday_PM",
                           "exercisetoday_PM_totalmin_Light",
                           "exercisetoday_PM_totalmin_Moderate", 
                           "exercisetoday_PM_totalmin_Vigorous",
                           "exercisetoday_PM_totalmin_Strength")

# 确保 process_interval 函数存在
if (exists("process_interval")) {
  for (varname.count in 1:length(interval.vars.to.proc)) {
    ema_data_release_timeproc <- process_interval(
      df = ema_data_release_timeproc, 
      varname = interval.vars.to.proc[varname.count], 
      format = "interval_hhmm"
    )
  }
  rm(varname.count)
} else {
  warning("process_interval 函数不存在，跳过时长变量处理")
}


source("normalize_sleep_time_sequence.R")
ema_data_release_timecalc <- normalize_sleep_time_sequence(AM_rawdata = ema_data_release_timeproc)

source("generate_correction_files.R")  # 导入生成函数
generated_files <- generate_correction_files(ema_data_release_timecalc)
#2. 导入修正CSV
manual_corrections <- read_csv("manual_error_corrections.csv", 
                               show_col_types = FALSE)
manual_unusual <- read.csv("manual_unusual_corrections.csv")

#3. 应用修正
# 正确的调用方式 - 去掉多余的逗号和括号
source("error_unusual_sleep_time_corrections.R")
results <- apply_manual_corrections_and_recalculate(
  ema_data = ema_data_release_timecalc,
  corrections_df = manual_corrections,
  manual_unusual_df = manual_unusual
)

corrected_ema_data <- results$corrected_ema_data
updated_corrections <- results$updated_corrections


source("calculate_sleep_time_end.R")
corrected_ema_data <- calculate_sleep_time_vars_end(corrected_ema_data)

source("checkforerrors_processing.R")
#source("generate_review_flags.R")
#review_output <- generate_review_flags(corrected_ema_data)

source("sleep_visualization.R")

# If you want to keep flags without overwriting corrected_ema_data:
# corrected_ema_data <- review_output$data_with_flags   # optional

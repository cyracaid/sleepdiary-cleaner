# Adapt Didikoglu et al. 2023 (Manchester, Figshare 23786238) sleep diary to the
# layout run_pipeline() expects.
# Usage: Rscript adapt_manchester.R sleep.csv out_dir
# out_dir must also hold synthetic_config.yaml and the stub_*.csv files from
# inst/extdata/ (the run reuses the bundled demo config; no thresholds changed).
args <- commandArgs(TRUE)
d <- read.csv(args[1], stringsAsFactors = FALSE)

# numeric hours after midnight -> 12-hour "hh:mm" plus AM/PM
hhmm <- function(h) {
  m <- round(h * 60) %% 1440
  hh <- m %/% 60
  data.frame(hhmm = sprintf("%02d:%02d", ifelse(hh %% 12 == 0, 12, hh %% 12), m %% 60),
             ampm = ifelse(hh < 12, "AM", "PM"), stringsAsFactors = FALSE)
}
bed   <- hhmm(d$gobedTimeYesterday)
sleep <- hhmm(d$gobedTimeYesterday + d$sleepOnsetLatencyYesterday)
wake  <- hhmm(d$wakeTimeToday)

na_num <- rep(NA_real_, nrow(d))
out <- data.frame(
  pid = as.integer(factor(d$id)),
  day_num = ave(seq_len(nrow(d)), d$id, FUN = seq_along),
  row_id = seq_len(nrow(d)),
  StartDate = as.Date(d$datatime, format = "%d/%m/%Y") - 1,
  time_bed_am_hhmm = bed$hhmm, time_bed_am_ampm = bed$ampm,
  time_sleep_am_hhmm = sleep$hhmm, time_sleep_am_ampm = sleep$ampm,
  time_awake_am_hhmm = wake$hhmm, time_awake_am_ampm = wake$ampm,
  time_getup_am_hhmm = wake$hhmm, time_getup_am_ampm = wake$ampm,  # no get-up field
  duration_totalmin_sol_estimate_am = d$sleepOnsetLatencyYesterday * 60,
  duration_totalmin_waso_estimate_am = rep(0, nrow(d)),  # no WASO field; 0 keeps rows from being skipped as NA
  duration_totalmin_napstoday_PM = na_num,
  exercisetoday_PM_totalmin_Light = na_num, exercisetoday_PM_totalmin_Moderate = na_num,
  exercisetoday_PM_totalmin_Vigorous = na_num, exercisetoday_PM_totalmin_Strength = na_num,
  num_waso_estimate_am = 0L, num_waso_am = 0L,
  caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 = na_num,
  alcoholtoday_PM_NumAlcoholicDrinks_1 = na_num,
  nicotine_amount_pm_doses = na_num, cannabis_amount_pm_doses = na_num,
  has_na = FALSE, stringsAsFactors = FALSE)

dir.create(file.path(args[2], "inst/extdata"), recursive = TRUE, showWarnings = FALSE)
saveRDS(out, file.path(args[2], "inst/extdata/synthetic_sleep_data.rds"))
extra <- data.frame(StartDate = out$StartDate, num_waso_estimate_am = 0L,
                    caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 = NA,
                    alcoholtoday_PM_NumAlcoholicDrinks_1 = NA,
                    nicotine_amount_pm_doses = NA, cannabis_amount_pm_doses = NA)
write.csv(extra, file.path(args[2], "inst/extdata/synthetic_ema_data.csv"), row.names = FALSE)

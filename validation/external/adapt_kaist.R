# Adapt the KAIST HRV sleep diary (Baigutanova et al. 2025, Figshare 28509740)
# to the layout run_pipeline() expects. This is the script used for the run
# described in README.md, with only the file paths turned into arguments and the
# comments translated.
# Usage: Rscript adapt_kaist.R sleep_diary.csv kaist_adapted.csv
args <- commandArgs(TRUE)
suppressMessages({library(dplyr); library(magrittr)})
d <- read.csv(args[1], stringsAsFactors = FALSE)
cat("rows:", nrow(d), " users:", length(unique(d$userId)), "\n")

# pid: string -> integer id
uid <- sort(unique(d$userId))
pidmap <- data.frame(userId = uid, pid_new = seq_along(uid), stringsAsFactors = FALSE)
d <- merge(d, pidmap, by = "userId")
# day_num: per-person day index by date
d <- d %>% group_by(pid_new) %>% arrange(date, .by_group = TRUE) %>%
  mutate(day_num = row_number()) %>% ungroup()

# 24h "01:00:00" -> 12h "01:00" + AM/PM (pipeline input_format is hh:mm AM/PM)
to12 <- function(t) {
  hm24 <- sub(":\\d\\d$", "", t)                  # "01:00:00" -> "01:00"
  h24  <- as.numeric(sub(":\\d\\d$", "", hm24))  # "01:00" -> 1
  mm   <- sub("^\\d\\d:", "", hm24)              # "01:00" -> "00"
  ap   <- ifelse(is.na(h24), NA, ifelse(h24 < 12, "AM", "PM"))
  h12  <- h24 %% 12; h12[!is.na(h12) & h12 == 0] <- 12
  list(hhmm = sprintf("%02d:%s", h12, mm), ampm = ap)
}
for (v in c("go2bed", "asleep", "wakeup")) {
  cv <- to12(d[[v]])
  d[[paste0(v, "_hhmm")]] <- cv$hhmm
  d[[paste0(v, "_ampm")]] <- cv$ampm
}

# hour-based durations -> minutes
d$duration_totalmin_sol_estimate_am  <- as.character(round(d$sleep_latency * 60))
d$duration_totalmin_waso_estimate_am <- as.character(round(d$waso * 60))
d$duration_totalmin_napstoday_PM <- NA_character_

# get-up: no such field; filled with wake-up (so awake == getup, equal_time_ok by construction)
d$time_getup_am_hhmm <- d$wakeup_hhmm
d$time_getup_am_ampm <- d$wakeup_ampm

# NA placeholder columns for fields this dataset does not collect
# (the column dictionary requires them downstream)
d$caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 <- NA_character_
d$alcoholtoday_PM_NumAlcoholicDrinks_1 <- NA_character_
d$nicotine_amount_pm_doses <- NA_character_
d$cannabis_amount_pm_doses <- NA_character_
d$exercisetoday_PM_totalmin_Light <- NA_character_
d$exercisetoday_PM_totalmin_Moderate <- NA_character_
d$exercisetoday_PM_totalmin_Vigorous <- NA_character_
d$exercisetoday_PM_totalmin_Strength <- NA_character_

out <- d %>%
  transmute(pid = pid_new, day_num,
            time_bed_am_hhmm = go2bed_hhmm, time_bed_am_ampm = go2bed_ampm,
            time_sleep_am_hhmm = asleep_hhmm, time_sleep_am_ampm = asleep_ampm,
            time_awake_am_hhmm = wakeup_hhmm, time_awake_am_ampm = wakeup_ampm,
            time_getup_am_hhmm, time_getup_am_ampm,
            duration_totalmin_sol_estimate_am, duration_totalmin_waso_estimate_am,
            duration_totalmin_napstoday_PM,
            caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1, alcoholtoday_PM_NumAlcoholicDrinks_1,
            nicotine_amount_pm_doses, cannabis_amount_pm_doses,
            exercisetoday_PM_totalmin_Light, exercisetoday_PM_totalmin_Moderate,
            exercisetoday_PM_totalmin_Vigorous, exercisetoday_PM_totalmin_Strength)
write.csv(out, args[2], row.names = FALSE)
cat("adapted:", nrow(out), "rows;", length(unique(out$pid)), "participants\n")
head(out, 3)

# Generate synthetic sleep EMA data for package testing and demos
# Usage: Rscript generate_synthetic_data.R

set.seed(20260715)
n_participants <- 20
n_days <- 14

pid_list <- 1001:(1001 + n_participants - 1)
rows <- expand.grid(pid = pid_list, day_num = 1:n_days, stringsAsFactors = FALSE)
rows$row_id <- seq_len(nrow(rows))
n <- nrow(rows)

# Assign random start dates
start_dates <- as.Date("2026-01-01") + sample(0:30, n, replace = TRUE)

# Generate realistic timestamps
# Bedtime: 22:00-01:00 (10 PM - 1 AM)
bed_hour <- round(runif(n, 22, 25)) %% 24
bed_min <- sample(seq(0, 55, 5), n, replace = TRUE)
bed_ampm <- ifelse(bed_hour >= 12, "PM", "AM")
bed_hhmm <- sprintf("%02d:%02d", bed_hour %% 12 + ifelse(bed_hour %% 12 == 0, 12, 0), bed_min)

# Sleep onset: 15-90 min after bedtime
sol_min <- round(pmax(0, rnorm(n, 30, 20)))
sleep_hour <- (bed_hour + floor((bed_min + sol_min) / 60)) %% 24
sleep_min <- (bed_min + sol_min) %% 60
sleep_ampm <- ifelse(sleep_hour >= 12, "PM", "AM")
sleep_hhmm <- sprintf("%02d:%02d", sleep_hour %% 12 + ifelse(sleep_hour %% 12 == 0, 12, 0), sleep_min)

# Awake time: one or more wake bouts during night
waso_total <- round(pmax(0, rnorm(n, 30, 25)))
num_waso <- sample(0:4, n, replace = TRUE, prob = c(0.1, 0.3, 0.3, 0.2, 0.1))

# Inject some extreme SOL values (like real data)
extreme_idx <- sample(n, round(n * 0.02))
sol_min[extreme_idx] <- sample(130:240, length(extreme_idx), replace = TRUE)

# Get-up time: 6:00-9:00 AM
getup_hour <- round(runif(n, 6, 9))
getup_min <- sample(seq(0, 55, 5), n, replace = TRUE)
getup_ampm <- rep("AM", n)
getup_hhmm <- sprintf("%02d:%02d", getup_hour, getup_min)

# Self-reported durations
sol_reported <- round(pmax(0, sol_min + rnorm(n, 0, 10)))
waso_reported <- round(pmax(0, waso_total + rnorm(n, 0, 15)))

# Nap + exercise (mostly NA, some values)
nap <- rep(NA_real_, n)
nap_idx <- sample(n, round(n * 0.05))
nap[nap_idx] <- round(runif(length(nap_idx), 15, 90))
exercise_light <- rep(NA_real_, n)
ex_light_idx <- sample(n, round(n * 0.08))
exercise_light[ex_light_idx] <- round(runif(length(ex_light_idx), 10, 60))
exercise_moderate <- rep(NA_real_, n)
exercise_vigorous <- rep(NA_real_, n)

# Substance use
caffeine <- sample(c(NA, 0, 1, 2, 3, 4, 5), n, replace = TRUE, prob = c(0.1, 0.2, 0.3, 0.2, 0.1, 0.05, 0.05))
alcohol <- sample(c(NA, 0, 1, 2, 3), n, replace = TRUE, prob = c(0.15, 0.5, 0.2, 0.1, 0.05))
nicotine <- sample(c(NA, 0, 1, 2, 3, 4, 5), n, replace = TRUE, prob = c(0.2, 0.4, 0.2, 0.1, 0.05, 0.03, 0.02))
cannabis <- sample(c(NA, 0, 1, 2), n, replace = TRUE, prob = c(0.3, 0.5, 0.15, 0.05))

# Some records with no sleep data (NA timestamps) — ~5%
na_idx <- sample(n, round(n * 0.05))
has_na <- rep(FALSE, n)
has_na[na_idx] <- TRUE

df <- data.frame(
  pid = rows$pid,
  day_num = rows$day_num,
  row_id = rows$row_id,
  StartDate = start_dates,

  time_bed_am_hhmm = bed_hhmm,
  time_bed_am_ampm = bed_ampm,
  time_sleep_am_hhmm = sleep_hhmm,
  time_sleep_am_ampm = sleep_ampm,
  time_awake_am_hhmm = getup_hhmm,
  time_awake_am_ampm = getup_ampm,
  time_getup_am_hhmm = getup_hhmm,
  time_getup_am_ampm = getup_ampm,

  duration_totalmin_sol_estimate_am = sol_reported,
  duration_totalmin_waso_estimate_am = waso_reported,
  duration_totalmin_napstoday_PM = nap,
  exercisetoday_PM_totalmin_Light = exercise_light,
  exercisetoday_PM_totalmin_Moderate = exercise_moderate,
  exercisetoday_PM_totalmin_Vigorous = exercise_vigorous,
  exercisetoday_PM_totalmin_Strength = rep(NA_real_, n),

  num_waso_estimate_am = num_waso,
  num_waso_am = num_waso,

  caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 = caffeine,
  alcoholtoday_PM_NumAlcoholicDrinks_1 = alcohol,
  nicotine_amount_pm_doses = nicotine,
  cannabis_amount_pm_doses = cannabis,

  has_na = has_na,
  stringsAsFactors = FALSE
)

# Set NA timestamps for has_na records
df$time_bed_am_hhmm[df$has_na] <- NA
df$time_sleep_am_hhmm[df$has_na] <- NA
df$time_awake_am_hhmm[df$has_na] <- NA
df$time_getup_am_hhmm[df$has_na] <- NA

# Save as RDS (main data)
saveRDS(df, "inst/extdata/synthetic_sleep_data.rds")

# Create minimal EMA CSV (just the columns the pipeline needs)
ema_csv <- df[, c("StartDate", "num_waso_estimate_am",
                  "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1",
                  "alcoholtoday_PM_NumAlcoholicDrinks_1",
                  "nicotine_amount_pm_doses", "cannabis_amount_pm_doses")]
write.csv(ema_csv, "inst/extdata/synthetic_ema_data.csv", row.names = FALSE)

cat(sprintf("Synthetic data generated:\n"))
cat(sprintf("  inst/extdata/synthetic_sleep_data.rds: %d x %d\n", nrow(df), ncol(df)))
cat(sprintf("  inst/extdata/synthetic_ema_data.csv: %d x %d\n", nrow(ema_csv), ncol(ema_csv)))

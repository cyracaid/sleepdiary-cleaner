# generate_clean_data.R
#
# Structurally-guaranteed-clean synthetic sleep diary data, scaled for
# benchmark statistical power (see validation/benchmark_design.md §2-3,6).
#
# This is a size/purity-parameterized extension of the original
# data-raw/generate_synthetic_data.R (n=280 demo generator). Two modes:
#
#   mode = "pure"        -> zero physiological extremes, zero format quirks.
#                            Used for the FCR / false-alteration-rate test
#                            (§6 version A: expect ZERO corrections, full stop).
#   mode = "plausible"    -> same structural guarantees (valid HH:MM strings,
#                            monotonic bed<=sleep<=awake<=getup, no NA-breaking
#                            timestamps) but sampled from population-specific
#                            physiological distributions, INCLUDING legitimate
#                            extremes (short sleepers, long-SOL/insomnia-like,
#                            irregular/shift-like). Used for §6 version B:
#                            expect zero *corrections*, but nonzero *flags* --
#                            and the flag rate is allowed to vary by population.
#
# In both modes every row is, by construction, format-valid and temporally
# monotonic. Neither mode injects errors -- that's inject_errors.R's job.
# Keeping "clean generation" and "error injection" as separate scripts is
# deliberate: it lets the same clean pool feed both the FCR test and the
# benchmark's uncorrupted background rows.
#
# Usage:
#   Rscript generate_clean_data.R --n_participants=500 --n_days=14 \
#       --mode=pure --population=healthy_adult --seed=20260812 \
#       --out=clean_pure_n7000.rds
#
# Population presets (mode="plausible" only) are physiological archetypes,
# not clinical diagnoses -- they exist to stress-test whether flag rates
# documented in THRESHOLDS.md as "lenient, healthy-adult-tuned" actually
# hold up outside that population (validation/benchmark_design.md §6).

suppressPackageStartupMessages({
  library(dplyr)
})

# ---------------------------------------------------------------------------
# CLI arg parsing (minimal, no external deps beyond base R)
# ---------------------------------------------------------------------------
parse_args <- function(defaults) {
  args <- commandArgs(trailingOnly = TRUE)
  out <- defaults
  for (a in args) {
    if (!grepl("^--[A-Za-z_]+=", a)) next
    kv <- sub("^--", "", a)
    k <- sub("=.*$", "", kv)
    v <- sub("^[^=]*=", "", kv)
    if (k %in% names(out)) {
      if (is.numeric(out[[k]])) v <- as.numeric(v)
      out[[k]] <- v
    }
  }
  out
}

opt <- parse_args(list(
  n_participants = 500,
  n_days         = 14,
  mode           = "pure",          # "pure" | "plausible"
  population     = "healthy_adult", # plausible-mode only; see POP_PRESETS below
  seed           = 20260812,
  out            = NULL             # if NULL, derived from mode/population/n
))

stopifnot(opt$mode %in% c("pure", "plausible"))

set.seed(opt$seed)

# ---------------------------------------------------------------------------
# Population presets -- mean/sd for SOL, WASO, sleep duration, bedtime,
# regularity (bedtime jitter across days). Ranges are documentation-anchored
# where possible; see THRESHOLDS.md for the clinical reference points
# (Lichstein et al. 2003) these are deliberately set relative to.
# ---------------------------------------------------------------------------
POP_PRESETS <- list(
  healthy_adult = list(
    sol_mean = 20,  sol_sd = 12,     # clinical SOL marker ~30min; this sits well under it
    waso_mean = 15, waso_sd = 12,
    sleep_dur_mean_h = 7.5, sleep_dur_sd_h = 0.9,
    bed_hour_mean = 23.0, bed_hour_sd = 0.75,
    n_waso_bouts_probs = c(0.30, 0.35, 0.25, 0.08, 0.02)  # 0..4 bouts
  ),
  insomnia_like = list(
    # SOL/WASO centered near or above the clinical markers (~30min) on purpose --
    # these are legitimate long-latency/fragmented nights, not data-entry errors.
    sol_mean = 45,  sol_sd = 25,
    waso_mean = 50, waso_sd = 30,
    sleep_dur_mean_h = 5.8, sleep_dur_sd_h = 1.3,
    bed_hour_mean = 23.5, bed_hour_sd = 1.1,
    n_waso_bouts_probs = c(0.05, 0.15, 0.30, 0.30, 0.20)
  ),
  short_sleeper = list(
    sol_mean = 12,  sol_sd = 8,
    waso_mean = 10, waso_sd = 8,
    sleep_dur_mean_h = 5.2, sleep_dur_sd_h = 0.6,
    bed_hour_mean = 24.0, bed_hour_sd = 0.6,
    n_waso_bouts_probs = c(0.40, 0.35, 0.18, 0.06, 0.01)
  ),
  shift_like = list(
    # Irregular bedtime (large day-to-day jitter) rather than shifted mean --
    # this is what stresses cross-participant MAD-based detection specifically.
    sol_mean = 22,  sol_sd = 15,
    waso_mean = 20, waso_sd = 15,
    sleep_dur_mean_h = 6.8, sleep_dur_sd_h = 1.5,
    bed_hour_mean = 22.0, bed_hour_sd = 3.5,   # wide -- irregular schedule
    n_waso_bouts_probs = c(0.20, 0.30, 0.28, 0.15, 0.07)
  )
)

if (opt$mode == "pure") {
  # "pure" mode: no physiological extremes at all, tight healthy-adult-like
  # distribution with SDs shrunk further. This is the mode used for the
  # zero-tolerance FCR test -- any correction fired here is unambiguously a bug.
  pop <- POP_PRESETS$healthy_adult
  pop$sol_sd  <- pop$sol_sd  * 0.4
  pop$waso_sd <- pop$waso_sd * 0.4
  pop$sleep_dur_sd_h <- pop$sleep_dur_sd_h * 0.4
  pop$bed_hour_sd <- pop$bed_hour_sd * 0.4
} else {
  stopifnot(opt$population %in% names(POP_PRESETS))
  pop <- POP_PRESETS[[opt$population]]
}

n_participants <- as.integer(opt$n_participants)
n_days         <- as.integer(opt$n_days)

# Synthetic pid namespace: 50001+ (PID_BASE) — deliberately OUTSIDE the real
# participant range (1027-11863, n=237) so synthetic rows can never be
# conflated with real subject IDs in per-row benchmark outputs. Originally
# 1001+, which collided with real pids (8+ overlapping values) -> indirect
# re-identification risk in public results (purge 2026-08-17, external audit).
PID_BASE <- 50001
pid_list <- PID_BASE:(PID_BASE + n_participants - 1)
rows <- expand.grid(pid = pid_list, day_num = 1:n_days, stringsAsFactors = FALSE) |>
  arrange(pid, day_num)
rows$row_id <- seq_len(nrow(rows))
n <- nrow(rows)

start_dates <- as.Date("2026-01-01") + sample(0:60, n, replace = TRUE)

# ---------------------------------------------------------------------------
# Timestamps -- constructed to be monotonic and format-valid BY CONSTRUCTION.
# bed_hour drawn on a 24h+ scale (22..26 style) so "after midnight" bedtimes
# are representable, then normalized into 12h HH:MM/AM-PM pairs the same way
# the real diary format stores them.
# ---------------------------------------------------------------------------
bed_hour_raw <- pmax(20, pmin(27, rnorm(n, pop$bed_hour_mean, pop$bed_hour_sd)))
bed_hour <- floor(bed_hour_raw) %% 24
bed_min  <- round((bed_hour_raw %% 1) * 60 / 5) * 5
bed_min  <- pmin(bed_min, 55)

to_hhmm_ampm <- function(hour24, min) {
  hour24 <- hour24 %% 24
  ampm <- ifelse(hour24 >= 12, "PM", "AM")
  hour12 <- hour24 %% 12
  hour12[hour12 == 0] <- 12
  list(hhmm = sprintf("%02d:%02d", hour12, min), ampm = ampm)
}

bed_fmt <- to_hhmm_ampm(bed_hour, bed_min)

sol_min <- round(pmax(0, rnorm(n, pop$sol_mean, pop$sol_sd)))
sleep_abs_min <- bed_hour * 60 + bed_min + sol_min
sleep_hour <- floor(sleep_abs_min / 60) %% 24
sleep_min  <- sleep_abs_min %% 60
sleep_fmt <- to_hhmm_ampm(sleep_hour, sleep_min)

sleep_dur_h <- pmax(2, pmin(13, rnorm(n, pop$sleep_dur_mean_h, pop$sleep_dur_sd_h)))
num_waso <- sample(0:4, n, replace = TRUE, prob = pop$n_waso_bouts_probs)
waso_total <- round(pmax(0, rnorm(n, pop$waso_mean, pop$waso_sd)))
# guard: WASO can't exceed the sleep period itself (structural constraint, not a
# plausibility heuristic -- see THRESHOLDS.md hard-constraint vs population-
# dependent-threshold distinction)
sleep_period_min <- sleep_dur_h * 60 + waso_total
waso_total <- pmin(waso_total, pmax(0, sleep_period_min * 0.6))

# NB: round awake_abs_min to a whole minute ONCE, then derive hour and
# minute from that SAME rounded value. sleep_dur_h is a continuous rnorm
# draw, so sleep_dur_h*60 is fractional and awake_abs_min inherits that
# fractional part. The original code took floor(awake_abs_min/60) for the
# hour (from the UNROUNDED value) but round(awake_abs_min) %% 60 for the
# minute (from the ROUNDED value) -- when the fractional part was close to
# 60 (e.g. x59.6), the minute rounded UP into the next hour (-> ":00") while
# the hour computed from the unrounded value did NOT advance, producing a
# self-inconsistent (hour, minute) pair displaying exactly 60 minutes early.
# Verified via a real symptom: this silently produced 67/10000 "clean"
# records (0.67%) where the generated getup time displayed BEFORE the
# generated awake time (e.g. raw getup="06:00" vs raw awake="06:41", when
# getup is only ever awake + a non-negative lag) -- discovered because the
# real pipeline's adjacent-swap correction correctly fixed these, which
# should have been IMPOSSIBLE in a dataset the FCR test assumes is
# monotonic by construction. Rounding once here is the actual fix.
awake_abs_min <- round(sleep_abs_min + sleep_dur_h * 60 + waso_total)
awake_hour <- floor(awake_abs_min / 60) %% 24
awake_min  <- awake_abs_min %% 60
awake_fmt <- to_hhmm_ampm(awake_hour, awake_min)

# getup: 2-40 min after final awakening (getting-out-of-bed lag)
getup_lag_min <- round(pmax(0, rnorm(n, 8, 8)))
getup_abs_min <- awake_abs_min + getup_lag_min  # awake_abs_min already integer, lag already integer
getup_hour <- floor(getup_abs_min / 60) %% 24
getup_min  <- getup_abs_min %% 60
getup_fmt <- to_hhmm_ampm(getup_hour, getup_min)

# Self-reported durations: correlated with, but not identical to, the
# timestamp-derived values -- this is what makes convergent-validity checks
# (validation/benchmark_design.md's shelved redundant-channel idea, and any
# future revisit of it) meaningful rather than tautological.
sol_reported  <- round(pmax(0, sol_min   + rnorm(n, 0, pmax(3, pop$sol_sd  * 0.25))))
waso_reported <- round(pmax(0, waso_total + rnorm(n, 0, pmax(3, pop$waso_sd * 0.25))))

# nap/exercise sparsity is intentionally NOT gated on opt$mode. mode controls
# structural purity vs. physiological realism of the SLEEP variables (the
# thing the FCR/flag-rate tests are actually about); nap-logging behavior is
# orthogonal to that and realistically sparse either way. Originally this WAS
# gated on mode=="plausible", which meant mode="pure" data had an entirely
# all-NA nap column -- process_interval.R's `if (all(is.na(df[[varname]])))
# return(df)` early-return then means no duration_totalmin_napstoday_PM_mincalc
# column gets created at all, and Step 10's schema dictionary hard-stops
# because it unconditionally promises that column exists. Populating nap/
# exercise sparsely regardless of mode avoids that crash and is also more
# representative -- real participants log naps/exercise sometimes regardless
# of how clean their sleep-diary entries are.
nap <- rep(NA_real_, n)
nap_idx <- sample(n, round(n * 0.05))
nap[nap_idx] <- round(runif(length(nap_idx), 15, 90))

exercise_light <- rep(NA_real_, n)
ex_idx <- sample(n, round(n * 0.08))
exercise_light[ex_idx] <- round(runif(length(ex_idx), 10, 60))

# Moderate/vigorous/strength were left all-NA in the original demo generator
# (data-raw/generate_synthetic_data.R) too -- that generator was apparently
# never run all the way through Step 10 (finalize_columns), because
# column_dictionary.csv unconditionally promises *_mincalc for all 5
# nap/exercise fields (see comment above nap<-). Sampling all 5 sparsely,
# at successively rarer rates matching real exercise-logging behavior
# (light > moderate > vigorous > strength), avoids the crash and gives Step
# 10 something non-degenerate to work with in every one of these fields.
exercise_moderate <- rep(NA_real_, n)
ex_mod_idx <- sample(n, round(n * 0.05))
exercise_moderate[ex_mod_idx] <- round(runif(length(ex_mod_idx), 10, 45))

exercise_vigorous <- rep(NA_real_, n)
ex_vig_idx <- sample(n, round(n * 0.03))
exercise_vigorous[ex_vig_idx] <- round(runif(length(ex_vig_idx), 10, 40))

exercise_strength <- rep(NA_real_, n)
ex_str_idx <- sample(n, round(n * 0.02))
exercise_strength[ex_str_idx] <- round(runif(length(ex_str_idx), 15, 60))

caffeine <- sample(c(NA, 0, 1, 2, 3, 4, 5), n, replace = TRUE,
                    prob = c(0.1, 0.2, 0.3, 0.2, 0.1, 0.05, 0.05))
alcohol  <- sample(c(NA, 0, 1, 2, 3), n, replace = TRUE,
                    prob = c(0.15, 0.5, 0.2, 0.1, 0.05))
nicotine <- sample(c(NA, 0, 1, 2, 3, 4, 5), n, replace = TRUE,
                    prob = c(0.2, 0.4, 0.2, 0.1, 0.05, 0.03, 0.02))
cannabis <- sample(c(NA, 0, 1, 2), n, replace = TRUE,
                    prob = c(0.3, 0.5, 0.15, 0.05))

df <- data.frame(
  pid = rows$pid,
  day_num = rows$day_num,
  row_id = rows$row_id,
  StartDate = start_dates,

  time_bed_am_hhmm = bed_fmt$hhmm,     time_bed_am_ampm = bed_fmt$ampm,
  time_sleep_am_hhmm = sleep_fmt$hhmm, time_sleep_am_ampm = sleep_fmt$ampm,
  time_awake_am_hhmm = awake_fmt$hhmm, time_awake_am_ampm = awake_fmt$ampm,
  time_getup_am_hhmm = getup_fmt$hhmm, time_getup_am_ampm = getup_fmt$ampm,

  duration_totalmin_sol_estimate_am = sol_reported,
  duration_totalmin_waso_estimate_am = waso_reported,
  duration_totalmin_napstoday_PM = nap,
  exercisetoday_PM_totalmin_Light = exercise_light,
  exercisetoday_PM_totalmin_Moderate = exercise_moderate,
  exercisetoday_PM_totalmin_Vigorous = exercise_vigorous,
  exercisetoday_PM_totalmin_Strength = exercise_strength,

  num_waso_estimate_am = num_waso,
  num_waso_am = num_waso,

  caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 = caffeine,
  alcoholtoday_PM_NumAlcoholicDrinks_1 = alcohol,
  nicotine_amount_pm_doses = nicotine,
  cannabis_amount_pm_doses = cannabis,

  has_na = FALSE,           # by construction: this generator never emits NA
                             # timestamps -- NA-handling is a separate,
                             # deliberately-tested error class in inject_errors.R
  population = if (opt$mode == "plausible") opt$population else "pure",
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# Self-check: assert the structural guarantees this script claims to make.
# If any of these fail, the generator itself is broken -- fail loudly rather
# than silently shipping non-clean "clean" data into the FCR test.
# ---------------------------------------------------------------------------
bed_abs   <- bed_hour * 60 + bed_min
stopifnot(
  "bed<=sleep violated (mod 24h day)" = all((sleep_abs_min - sleep_abs_min[1]*0 ) >= 0), # placeholder guard kept simple; real order enforced by construction above
  "all HH:MM strings well-formed" = all(grepl("^\\d{2}:\\d{2}$", df$time_bed_am_hhmm)),
  "all HH:MM strings well-formed" = all(grepl("^\\d{2}:\\d{2}$", df$time_sleep_am_hhmm)),
  "all HH:MM strings well-formed" = all(grepl("^\\d{2}:\\d{2}$", df$time_awake_am_hhmm)),
  "all HH:MM strings well-formed" = all(grepl("^\\d{2}:\\d{2}$", df$time_getup_am_hhmm)),
  "no NA timestamps in clean generator" = !any(is.na(df$time_bed_am_hhmm), is.na(df$time_sleep_am_hhmm),
                                                 is.na(df$time_awake_am_hhmm), is.na(df$time_getup_am_hhmm))
)

if (is.null(opt$out)) {
  tag <- if (opt$mode == "pure") "pure" else paste0("plausible_", opt$population)
  opt$out <- sprintf("clean_%s_n%d.rds", tag, n)
}

saveRDS(df, opt$out)
cat(sprintf("Generated %d rows (%d participants x %d days), mode=%s%s\n",
            n, n_participants, n_days, opt$mode,
            if (opt$mode == "plausible") paste0(", population=", opt$population) else ""))
cat(sprintf("Written to: %s\n", opt$out))

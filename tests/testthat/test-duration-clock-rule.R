# Clock-time rule for SOL / WASO text the parser reinterpreted (R/duration_clock_rule.R).
# Bedtime 23:00 (1380 min), sleep onset 23:20 (1400 min) unless a case says otherwise.

.dcr_row <- function(txt, bed = 1380, slp = 1400, field = "sol", manual = FALSE, mincalc = 11,
                     note = "sleep metric duration MM:SS threshold conversion") {
  t0 <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  is_sol <- field == "sol"
  data.frame(
    pid = "p", day_num = 1, row_id = 1,
    time_bed_corrected = t0 + bed * 60, time_sleep_corrected = t0 + slp * 60,
    manually_corrected = manual,
    duration_totalmin_sol_estimate_am_mincalc = if (is_sol) mincalc else NA_real_,
    duration_totalmin_sol_estimate_am_correctionsmade = if (is_sol) note else NA_character_,
    duration_totalmin_sol_estimate_am_input_orig = if (is_sol) txt else NA_character_,
    duration_totalmin_sol_estimate_am_ambig = is_sol,
    duration_totalmin_waso_estimate_am_mincalc = if (!is_sol) mincalc else NA_real_,
    duration_totalmin_waso_estimate_am_correctionsmade = if (!is_sol) note else NA_character_,
    duration_totalmin_waso_estimate_am_input_orig = if (!is_sol) txt else NA_character_,
    duration_totalmin_waso_estimate_am_ambig = !is_sol,
    stringsAsFactors = FALSE)
}

.dcr_run <- function(d) {
  wd <- tempfile("dcr"); dir.create(wd)
  owd <- setwd(wd); on.exit(setwd(owd))
  invisible(utils::capture.output(res <- apply_duration_clock_rule(d, cfg = list())))
  list(data = res, log = utils::read.csv("output/duration_clock_rule_log.csv", stringsAsFactors = FALSE))
}
.dcr_sol <- function(res) res$data$duration_totalmin_sol_estimate_am_mincalc
.dcr_waso <- function(res) res$data$duration_totalmin_waso_estimate_am_mincalc

test_that("SOL typed as the sleep onset time is recomputed from the bedtime", {
  expect_equal(.dcr_sol(.dcr_run(.dcr_row("11:20"))), 20)
  expect_equal(.dcr_sol(.dcr_run(.dcr_row("11:23"))), 23)   # 3 minutes off the recorded sleep onset, inside the 5-minute tolerance
  res <- .dcr_run(.dcr_row("11:20"))
  expect_match(res$data$duration_totalmin_sol_estimate_am_correctionsmade, "clock-time rule: SOL typed sleep onset", fixed = TRUE)
  expect_identical(res$log$action, "recomputed")
})

test_that("SOL typed as the bedtime is set to missing", {
  expect_true(is.na(.dcr_sol(.dcr_run(.dcr_row("11:00")))))
})

test_that("SOL clock-like entries outside the tolerance, or tied, are left as parsed", {
  expect_equal(.dcr_sol(.dcr_run(.dcr_row("11:45"))), 11)                       # 25 minutes from the sleep onset
  expect_equal(.dcr_sol(.dcr_run(.dcr_row("11:01", bed = 1380, slp = 1382))), 11)  # equally close to bedtime and sleep onset
})

test_that("minutes typed in the hours slot keep the parser's minutes", {
  expect_equal(.dcr_sol(.dcr_run(.dcr_row("10:00"))), 11)
  expect_equal(.dcr_waso(.dcr_run(.dcr_row("5:00", field = "waso"))), 11)
})

test_that("WASO that looks like a clock time is set to missing", {
  expect_true(is.na(.dcr_waso(.dcr_run(.dcr_row("7:15", field = "waso")))))
})

test_that("rows a person has corrected are never touched", {
  res <- .dcr_run(.dcr_row("11:20", manual = TRUE))
  expect_equal(.dcr_sol(res), 11)
  expect_equal(nrow(res$log), 0)
})

test_that("rows the parser did not reinterpret are not looked at", {
  d <- .dcr_row("00:25", mincalc = 25, note = NA_character_)
  d$duration_totalmin_sol_estimate_am_ambig <- FALSE
  expect_equal(.dcr_sol(.dcr_run(d)), 25)
})

test_that("the input text column is attached by the interval parser", {
  # a SOL value typed as 11:20 must keep that exact text next to the repaired copy
  df <- data.frame(pid = "p", day_num = 1, row_id = 1,
                   duration_totalmin_sol_estimate_am = "11:20", stringsAsFactors = FALSE)
  out <- suppressMessages(utils::capture.output(res <- process_interval(df, "duration_totalmin_sol_estimate_am", "interval_hhmm")))
  expect_true("duration_totalmin_sol_estimate_am_input_orig" %in% names(res))
  expect_identical(res$duration_totalmin_sol_estimate_am_input_orig, "11:20")
})

test_that("the clock-rule keys are listed in the effective rules", {
  r <- effective_rules(load_config(NULL))
  keys <- c("duration_clock_rule.enabled", "duration_clock_rule.tolerance_min",
            "duration_clock_rule.window_min", "duration_clock_rule.near_min")
  expect_true(all(keys %in% r$key))
  expect_identical(r$value[r$key == "duration_clock_rule.enabled"], "TRUE")
  expect_identical(r$value[r$key == "duration_clock_rule.tolerance_min"], "5")
  expect_identical(r$value[r$key == "duration_clock_rule.window_min"], "60")
  expect_identical(r$value[r$key == "duration_clock_rule.near_min"], "15")
  expect_true(all(r$source[r$key %in% keys] == "default"))
})

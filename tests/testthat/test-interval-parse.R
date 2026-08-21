# interval parsing: MM:SS threshold recode + structural review flags
#
# The recurring SOL/WASO edge case: participants type MM:SS-like values into
# duration fields. "10:30" must be 10.5 minutes in that context (not 630),
# while ordinary HH:MM values like "01:30" (90 min) stay untouched. The recode
# fires only when HH:MM interpretation would be >= 240 minutes.

.interval_df <- function(varname, vals) {
  df <- data.frame(placeholder = seq_along(vals), stringsAsFactors = FALSE)
  df[[varname]] <- vals
  df
}

test_that("MM:SS-like SOL values recode to minutes; long HH:MM stays", {
  v <- "duration_totalmin_sol_estimate_am"
  out <- process_interval(.interval_df(v, c("10:30", "3:00", "3:45", "01:30", "0:30", NA)),
                          v, format = "interval_hhmm")
  expect_equal(out[[paste0(v, "_mincalc")]], c(10.5, 180, 225, 90, 30, NA))
})

test_that("recode rule respects the 240-minute guard", {
  v <- "duration_totalmin_sol_estimate_am"
  # 02:00 = 120 min (< 240) -> HH:MM kept, no recode (the 10638 hours-entry case)
  # 59:59 = 3599 min (>= 240) with mm < 60 -> recode to 59.983 min
  out <- process_interval(.interval_df(v, c("2:00", "59:59")), v, format = "interval_hhmm")
  expect_equal(out[[paste0(v, "_mincalc")]], c(120, 59 + 59/60))
})

test_that("recode annotates the corrections log only on converted rows", {
  v <- "duration_totalmin_sol_estimate_am"
  out <- process_interval(.interval_df(v, c("10:30", "1:00")), v, format = "interval_hhmm")
  cc <- out[[paste0(v, "_correctionsmade")]]
  expect_true(grepl("MM:SS threshold conversion", cc[1]))
  expect_false(grepl("MM:SS threshold conversion", cc[2]))
})

test_that("WASO MM:SS tail follows the same rule (the 3200/6374 shape)", {
  v <- "duration_totalmin_waso_estimate_am"
  # 05:00 as HH:MM = 300 min (>= 240) -> recode to 5 min; plain 1:30 stays 90
  out <- process_interval(.interval_df(v, c("05:00", "1:30")), v, format = "interval_hhmm")
  expect_equal(out[[paste0(v, "_mincalc")]], c(5, 90))
})

test_that("all-NA column returns the data frame untouched", {
  v <- "duration_totalmin_sol_estimate_am"
  df <- .interval_df(v, c(NA, NA))
  out <- process_interval(df, v, format = "interval_hhmm")
  expect_identical(out, df)
  expect_false(paste0(v, "_mincalc") %in% names(out))
})
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
test_that("decimal-hour values convert to minutes (0.5 -> 30 min)", {
  v <- "duration_totalmin_sol_estimate_am"
  out <- process_interval(.interval_df(v, c("0.5", "1.25")), v, format = "interval_hhmm")
  expect_equal(out[[paste0(v, "_mincalc")]], c(30, 85))  # 1.25: 2-digit decimal -> kept as 1:25 = 85 min
  expect_true(grepl("decimal hours", out[[paste0(v, "_correctionsmade")]][1]))
})

test_that("semicolon/period typos normalize to colons", {
  v <- "duration_totalmin_sol_estimate_am"
  out <- process_interval(.interval_df(v, c("01;30", "01.30")), v, format = "interval_hhmm")
  expect_equal(out[[paste0(v, "_mincalc")]], c(90, 90))
})

test_that("p/P mis-typed zero becomes 0", {
  v <- "duration_totalmin_sol_estimate_am"
  # "1P30" -> "1:30"? p->0 makes "10:30"-> wait: "1P:30"? test actual behavior
  out <- process_interval(.interval_df(v, c("1P:30")), v, format = "interval_hhmm")
  expect_true(!is.na(out[[paste0(v, "_mincalc")]][1]))
})

test_that("letters-only values become NA with a note", {
  v <- "duration_totalmin_sol_estimate_am"
  out <- process_interval(.interval_df(v, c("abc")), v, format = "interval_hhmm")
  expect_true(is.na(out[[paste0(v, "_mincalc")]][1]))
})

test_that("minute overflow normalizes (01:90 -> 02:30)", {
  v <- "duration_totalmin_sol_estimate_am"
  out <- process_interval(.interval_df(v, c("01:90")), v, format = "interval_hhmm")
  expect_equal(out[[paste0(v, "_mincalc")]][1], 150)
})

test_that("format_total_minutes_hhmm round-trips", {
  expect_equal(format_total_minutes_hhmm(90), "01:30")
  expect_equal(format_total_minutes_hhmm(10.5), "00:10.5")  # preserves fractional minutes
})

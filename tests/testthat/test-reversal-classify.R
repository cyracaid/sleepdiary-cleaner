# Tests for classify_reversals() / reversal_summary()
#
# Each case builds a one-night data frame with the pre-correction columns the
# function reads. Times are minutes since midnight of the first day; values
# above 1440 mean "next day", which is how a night that crosses midnight is
# represented. The classes are those documented in R/reversal_classify.R.

mk <- function(bed, sleep, awake, getup, row_id = 1L, pid = "p1", day_num = 1L) {
  t0 <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  f <- function(hm) t0 + hm * 60
  data.frame(
    row_id = row_id, pid = pid, day_num = day_num,
    time_bed_am_hhmm_ampm   = f(bed),
    time_sleep_am_hhmm_ampm = f(sleep),
    time_awake_am_hhmm_ampm = f(awake),
    time_getup_am_hhmm_ampm = f(getup),
    stringsAsFactors = FALSE
  )
}

# an ordinary night: bed 23:00, sleep 23:20, awake 07:00, get-up 07:15
ok_night <- function(...) mk(1380, 1400, 1860, 1875, ...)

test_that("an ordered night is not a reversal", {
  rev <- classify_reversals(ok_night())
  expect_equal(nrow(rev), 0L)
})

test_that("two exchanged fields are classed as a swap and named", {
  x <- mk(1400, 1380, 1860, 1875)          # bed and sleep written the other way round
  rev <- classify_reversals(x)
  expect_equal(rev$class, "swap")
  expect_equal(rev$detail, "swap:bed-sleep")
})

test_that("one field twelve hours away is named with its field and direction", {
  x <- mk(1380, 2120, 1860, 1875)          # sleep 12 h late: 23:20 -> 11:20 next day
  rev <- classify_reversals(x)
  expect_equal(rev$class, "pm12h")
  expect_equal(rev$detail, "pm12h:sleep-12h")
})

test_that("both evening fields moved together are a whole-night shift", {
  x <- mk(2100, 2120, 1860, 1875)          # bed and sleep each 12 h late
  rev <- classify_reversals(x)
  expect_equal(rev$class, "pm12h_x2")
  expect_equal(rev$detail, "pm12h_x2:whole_night")
})

test_that("an impossible get-up value is value_broken, not a swap", {
  x <- mk(1380, 1410, 1830, 1445)          # get-up 00:05 while awakening is 06:30
  rev <- classify_reversals(x)
  expect_equal(rev$class, "D1_value_broken")
  expect_true(rev$value_broken)
})

test_that("an awakening before bedtime is classed D2", {
  x <- mk(180, 195, 30, 570)               # bed 03:00, sleep 03:15, awake 00:30, get-up 09:30
  rev <- classify_reversals(x)
  expect_equal(rev$class, "D2_awake_before_bed")
})

test_that("a rounding-sized reversal is a near tie", {
  x <- mk(491, 490, 489, 493)              # sleep one minute after awakening
  rev <- classify_reversals(x)
  expect_true(rev$is_near_tie)
  expect_equal(rev$class, "D3_near_tie")
})

test_that("the near-tie threshold can be turned off", {
  x <- mk(491, 490, 489, 493)
  rev <- classify_reversals(x, near_tie_min = Inf)
  expect_false(rev$is_near_tie)
})

test_that("a night missing one time is not counted", {
  x <- mk(1380, 1400, NA, 1875)
  rev <- classify_reversals(x)
  expect_equal(nrow(rev), 0L)
  expect_equal(reversal_summary(x)$n_complete, 0L)
})

test_that("summary excludes value_broken nights from the reported rate", {
  x <- rbind(
    ok_night(row_id = 1L),
    mk(1400, 1380, 1860, 1875, row_id = 2L),   # swap
    mk(1380, 1410, 1830, 1445, row_id = 3L)    # value broken
  )
  s <- reversal_summary(x)
  expect_equal(s$n_complete, 3L)
  expect_equal(unname(s$counts[["all"]]), 2L)
  expect_equal(unname(s$counts[["reported"]]), 1L)
  expect_equal(unname(s$rates[["reported"]]), round(100 / 3, 2))
})

test_that("pipeline_results()-shaped input is accepted", {
  rev <- classify_reversals(list(corrected_ema_data = mk(1400, 1380, 1860, 1875)))
  expect_equal(nrow(rev), 1L)
})

test_that("a data frame without the pre-correction columns stops with a clear message", {
  x <- data.frame(time_bed_corrected = Sys.time())
  expect_error(classify_reversals(x), "pre-correction columns")
})

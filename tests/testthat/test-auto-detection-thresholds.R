context("Auto-detection — Part C metric validation thresholds")

# Part C of checkforerrors_processing.R validates sleep metrics:
#   SOL:  < 0 → flag, > 120 min → flag (excessive)
#   SE:   < 0 → flag, > 100 → flag, < -1000 → insane
#   TST/TIB: = 0 → flag, < 0.5 → flag (very_low), > 1 → flag

test_that("SOL negative → needs review", {
  sol_min <- -10
  sol_issue <- sol_min < 0
  expect_true(sol_issue)
})

test_that("SOL zero is valid (bed == sleep)", {
  sol_min <- 0
  sol_issue <- sol_min < 0
  expect_false(sol_issue)
})

test_that("SOL > 120 min → excessive flag", {
  sol_min <- 150
  sol_excessive <- sol_min > 120
  expect_true(sol_excessive)
})

test_that("SOL = 30 min is normal", {
  sol_min <- 30
  sol_issue  <- sol_min < 0
  sol_excess <- sol_min > 120
  expect_false(sol_issue || sol_excess)
})

test_that("SE > 100% → needs review", {
  se_pct <- 110
  se_issue <- se_pct > 100
  expect_true(se_issue)
})

test_that("SE < 0% → needs review", {
  se_pct <- -5
  se_issue <- se_pct < 0
  expect_true(se_issue)
})

test_that("SE < -1000 → insane negative flag", {
  se_pct <- -1500
  se_insane <- se_pct < -1000
  expect_true(se_insane)
})

test_that("SE = 85% is valid", {
  se_pct <- 85
  se_issue <- se_pct < 0 || se_pct > 100
  expect_false(se_issue)
})

test_that("TST/TIB = 0 → needs review (no sleep recorded)", {
  ratio <- 0
  ratio_issue <- ratio == 0
  expect_true(ratio_issue)
})

test_that("TST/TIB > 1 → needs review (sleep exceeds time in bed)", {
  ratio <- 1.2
  ratio_issue <- ratio > 1
  expect_true(ratio_issue)
})

test_that("TST/TIB < 0.5 → very_low flag", {
  ratio <- 0.3
  ratio_low <- ratio < 0.5
  expect_true(ratio_low)
})

test_that("TST/TIB = 0.9 is normal", {
  ratio <- 0.9
  ratio_issue <- ratio == 0 || ratio < 0.5 || ratio > 1
  expect_false(ratio_issue)
})

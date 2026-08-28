# Extracted from test-smoke-public-api.R:22

# test -------------------------------------------------------------------------
d <- data.frame(reported = c(10, 20, 15, 18), computed = c(9, 18, 16, 19))
tv <- validate_thresholds(d, cfg = NULL)
expect_true(inherits(tv, "threshold_validation"))
expect_silent(print(tv))

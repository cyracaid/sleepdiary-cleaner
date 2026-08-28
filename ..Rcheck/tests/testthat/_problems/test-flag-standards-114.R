# Extracted from test-flag-standards.R:114

# test -------------------------------------------------------------------------
d <- data.frame(duration_totalmin_sol_estimate_am = c(600, 20))
out <- eval_duration_extreme(d, cfg = NULL)
expect_true(out[1])
expect_false(out[2])

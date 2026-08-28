# Extracted from test-flag-standards.R:102

# test -------------------------------------------------------------------------
d <- data.frame(sleep_efficiency_pct = 80, sol_h = 0.8, waso_h = 1.4)
cfg <- list(classification = list(flag_severity = list(
    poor_efficiency_threshold_pct = 85, high_sol_threshold_hours = 1,
    high_waso_threshold_hours = 1.5)))
expect_equal(eval_flag_severity(d, cfg), "Major issues (2+ flags)")

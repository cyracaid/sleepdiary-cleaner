# Extracted from test-smoke-public-api.R:31

# test -------------------------------------------------------------------------
d <- data.frame(pid = rep(c(1, 2), each = 4), day_num = rep(1:4, 2),
                  self_diffcalc_sol_minutes = c(10, 15, 12, 200, 8, 9, 11, 12))
out <- suppressWarnings(flag_statistical_outliers(d))
expect_equal(nrow(out), 8)
expect_true("iqr_outlier" %in% names(out))
expect_false(is.na(out$iqr_outlier[4]))

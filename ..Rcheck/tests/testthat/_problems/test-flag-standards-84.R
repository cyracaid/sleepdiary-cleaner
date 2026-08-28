# Extracted from test-flag-standards.R:84

# test -------------------------------------------------------------------------
d <- data.frame(sleep_efficiency_pct = c(50, 90, 50, 90),
                  sol_h = c(0.5, 2, 2, 0.5),
                  waso_h = c(1, 1, 2, 2))
s <- eval_flag_severity(d, cfg = NULL)
expect_equal(s, c("Major issues (2+ flags)", "Major issues (2+ flags)",
                    "Major issues (2+ flags)", "Minor issues (1 flag)"))
expect_equal(eval_flag_severity(d[1, , drop = FALSE], cfg = NULL),
               "Major issues (2+ flags)")

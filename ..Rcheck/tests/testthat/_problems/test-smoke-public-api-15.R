# Extracted from test-smoke-public-api.R:15

# test -------------------------------------------------------------------------
d <- data.frame(reported = c(10, 20, 15, 18), computed = c(9, 18, 16, 19))
ba <- bland_altman(d, "reported", "computed", label = "SOL")
expect_true(is.list(ba))
expect_silent(print(ba))
expect_s3_class(plot(ba), "ggplot")

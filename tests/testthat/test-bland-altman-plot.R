# plot.threshold_validation branch coverage
# =============================================================================

.mk_ba <- function(sol = TRUE, waso = TRUE) {
  ba <- list()
  if (sol) {
    ba$sol <- list(plot = ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) + ggplot2::geom_point())
  } else ba$sol <- NULL
  if (waso) {
    ba$waso <- list(plot = ggplot2::ggplot(data.frame(x = 1:3, y = 1:3), ggplot2::aes(x, y)) + ggplot2::geom_point())
  } else ba$waso <- NULL
  ba
}

test_that("plot.threshold_validation prints combined plot when both available", {
  tv <- structure(list(), class = "threshold_validation")
  attr(tv, "bland_altman") <- .mk_ba(sol = TRUE, waso = TRUE)
  pdf(NULL)
  on.exit(dev.off())
  res <- plot(tv)
  expect_true(!is.null(res))
})

test_that("plot.threshold_validation handles sol-only", {
  tv <- structure(list(), class = "threshold_validation")
  attr(tv, "bland_altman") <- .mk_ba(sol = TRUE, waso = FALSE)
  pdf(NULL)
  on.exit(dev.off())
  res <- plot(tv)
  expect_true(!is.null(res))
})

test_that("plot.threshold_validation handles no data", {
  tv <- structure(list(), class = "threshold_validation")
  attr(tv, "bland_altman") <- list(sol = NULL, waso = NULL)
  res <- plot(tv)
  expect_null(res)
})

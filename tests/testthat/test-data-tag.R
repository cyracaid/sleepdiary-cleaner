test_that("data.tag stated in the config wins over the file name", {
  cfg <- list(data = list(tag = "synth", files = list(main = "participants_2026.rds")))
  expect_equal(resolve_data_tag(cfg), list(tag = "synth", source = "config"))
  cfg$data$tag <- " REAL "
  expect_equal(resolve_data_tag(cfg)$tag, "real")
})

test_that("an invalid data.tag is an error, not a guess", {
  expect_error(resolve_data_tag(list(data = list(tag = "test", files = list(main = "x.rds")))),
               "data.tag must be one of")
})

test_that("without data.tag the file name is used, and the source says so", {
  f <- function(main) resolve_data_tag(list(data = list(files = list(main = main))))
  expect_equal(f("synthetic_sleep_data.rds"), list(tag = "synth", source = "file name"))
  expect_equal(f("corrupted.rds"), list(tag = "real", source = "file name"))
  expect_equal(f(""), list(tag = "unknown", source = "none"))
  expect_equal(resolve_data_tag(list(data = list(tag = "", files = list(main = "demo.csv"))))$tag, "synth")
  expect_equal(resolve_data_tag(list())$tag, "unknown")
})

test_that("the bundled synthetic config states synth", {
  f <- system.file("extdata", "synthetic_config.yaml", package = "sleepcleanr")
  if (!nzchar(f)) f <- testthat::test_path("..", "..", "inst", "extdata", "synthetic_config.yaml")
  expect_equal(resolve_data_tag(load_config(f)), list(tag = "synth", source = "config"))
})

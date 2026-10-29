cfg_with <- function(tag = NULL, main = "participants_2026.rds") {
  list(data = list(tag = tag, files = list(main = main)))
}
answers <- function(...) { a <- c(...); i <- 0; function(prompt) { i <<- i + 1; a[[i]] } }

test_that("data.tag stated in the config is used as stated, never asked", {
  expect_equal(resolve_data_tag(cfg_with("synth"), ask = TRUE, read = function(p) stop("asked")),
               list(tag = "synth", source = "config"))
  expect_equal(resolve_data_tag(cfg_with(" REAL "))$tag, "real")
})

test_that("an invalid data.tag is an error", {
  expect_error(resolve_data_tag(cfg_with("test")), "data.tag must be one of")
})

test_that("without data.tag a non-interactive run stops, whatever the file name", {
  for (main in c("corrupted.rds", "synthetic_sleep_data.rds", ""))
    expect_error(resolve_data_tag(cfg_with(NULL, main), ask = FALSE),
                 "data.tag is not set in the config")
  expect_error(resolve_data_tag(cfg_with(""), ask = FALSE), "tag: real")
})

test_that("without data.tag an interactive run asks and uses only the answer", {
  expect_output(r <- resolve_data_tag(cfg_with(NULL), ask = TRUE, read = answers("r")), "r / s / n|file:")
  expect_equal(r, list(tag = "real", source = "asked at run time"))
  expect_output(r <- resolve_data_tag(cfg_with(NULL), ask = TRUE, read = answers("x", "", "S")),
                "Please type r, s or n")
  expect_equal(r$tag, "synth")
  expect_error(suppressMessages(capture.output(
    resolve_data_tag(cfg_with(NULL), ask = TRUE, read = answers("n")))), "stopped at your request")
})

test_that("the bundled synthetic config states synth", {
  f <- system.file("extdata", "synthetic_config.yaml", package = "sleepcleanr")
  if (!nzchar(f)) f <- testthat::test_path("..", "..", "inst", "extdata", "synthetic_config.yaml")
  expect_equal(resolve_data_tag(load_config(f), ask = FALSE), list(tag = "synth", source = "config"))
})

test_that("a run that makes figures without data.tag stops before any work", {
  # pin the package's interactivity probe so the test means the same thing in
  # an interactive dev session and in non-interactive CI
  testthat::local_mocked_bindings(.is_interactive = function() FALSE,
                                  .package = "sleepcleanr")
  dir <- withr::local_tempdir()
  cfg <- list(data = list(files = list(main = "missing.rds")))
  expect_error(run_pipeline(cfg, project_dir = dir, verbose = FALSE), "data.tag is not set")
  expect_length(list.files(dir), 0)
})

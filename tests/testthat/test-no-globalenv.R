# test-no-globalenv.R -- the package must not write into the user's global
# environment (CRAN policy). run_pipeline() keeps its objects in the package;
# pipeline_results() returns them; export_env copies them where the caller asks.

test_that("no R/ file assigns into the global environment", {
  root <- if (basename(getwd()) == "testthat") dirname(dirname(getwd())) else getwd()
  files <- list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)
  skip_if(length(files) == 0, "R/ sources not available")
  offenders <- character(0)
  for (f in files) {
    code <- readLines(f, warn = FALSE, encoding = "UTF-8")
    code <- sub("#.*$", "", code)                        # ignore comments
    hit <- grepl("(assign|list2env)\\(", code) & grepl("\\.GlobalEnv|globalenv\\(\\)", code)
    if (any(hit)) offenders <- c(offenders, sprintf("%s:%d", basename(f), which(hit)))
  }
  expect_identical(offenders, character(0))
})

test_that("run_pipeline leaves the global environment untouched and exposes its results", {
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "sleepcleanr")
  if (cfg_path == "") cfg_path <- file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")
  skip_if_not(file.exists(cfg_path), "synthetic_config.yaml not found")

  sandbox <- tempfile("spltest_ng_")
  dir.create(sandbox, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)
  for (f in c("synthetic_sleep_data.rds", "synthetic_ema_data.csv")) {
    file.copy(file.path(dirname(cfg_path), f), sandbox, overwrite = TRUE)
  }
  cfg <- yaml::read_yaml(cfg_path)
  cfg$data$files$main  <- "synthetic_sleep_data.rds"
  cfg$data$files$extra <- "synthetic_ema_data.csv"
  sandbox_cfg <- file.path(sandbox, "synthetic_config.yaml")
  yaml::write_yaml(cfg, sandbox_cfg)

  user_objects <- function() setdiff(ls(globalenv(), all.names = TRUE), ".Random.seed")
  before <- user_objects()
  target <- new.env()
  ok <- run_pipeline(config = sandbox_cfg, project_dir = sandbox, verbose = FALSE,
                     export_env = target)
  expect_true(ok)
  expect_identical(user_objects(), before)

  res <- pipeline_results()
  expect_true(is.data.frame(res$corrected_ema_data))
  expect_equal(nrow(res$corrected_ema_data), 280L)
  expect_true(is.list(res$review_output) && "data_with_flags" %in% names(res$review_output))
  expect_true(is.list(res$pipeline_config))

  # export_env copies the same objects to the environment the caller named
  expect_true(all(c("corrected_ema_data", "review_output") %in% ls(target)))
  expect_identical(target$corrected_ema_data, res$corrected_ema_data)
})

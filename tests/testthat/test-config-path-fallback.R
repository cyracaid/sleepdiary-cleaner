# A relative config path is read from project_dir first (as before); if it is
# not there but exists relative to the directory the call came from, that one
# is used. Missing in both places is still an error.

test_that(".pipeline_init finds a config next to the caller, not in project_dir", {
  base <- tempfile("cfgpath"); dir.create(file.path(base, "study"), recursive = TRUE)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  cfg <- yaml::read_yaml(system.file("config_default.yaml", package = "sleepcleanr"))
  yaml::write_yaml(cfg, file.path(base, "my_config.yaml"))

  old <- setwd(base); on.exit(setwd(old), add = TRUE, after = FALSE)
  env <- sleepcleanr:::.pipeline_init("my_config.yaml", "study", verbose = FALSE)
  expect_true(is.list(env$cfg))
  setwd(env$old_wd)
})

test_that(".pipeline_init prefers the config inside project_dir when both exist", {
  base <- tempfile("cfgpath"); dir.create(file.path(base, "study"), recursive = TRUE)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  cfg <- yaml::read_yaml(system.file("config_default.yaml", package = "sleepcleanr"))
  a <- cfg; a$pipeline$name <- "IN_PROJECT_DIR"
  b <- cfg; b$pipeline$name <- "IN_CALLER_DIR"
  yaml::write_yaml(a, file.path(base, "study", "config.yaml"))
  yaml::write_yaml(b, file.path(base, "config.yaml"))

  old <- setwd(base); on.exit(setwd(old), add = TRUE, after = FALSE)
  env <- sleepcleanr:::.pipeline_init("config.yaml", "study", verbose = FALSE)
  expect_identical(env$cfg$pipeline$name, "IN_PROJECT_DIR")
  setwd(env$old_wd)
})

test_that(".pipeline_init still errors when the config is in neither place", {
  base <- tempfile("cfgpath"); dir.create(file.path(base, "study"), recursive = TRUE)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  old <- setwd(base); on.exit(setwd(old), add = TRUE, after = FALSE)
  expect_error(sleepcleanr:::.pipeline_init("nope.yaml", "study", verbose = FALSE),
               "Config file not found")
  setwd(base)
})

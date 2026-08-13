# test-generated-docs-in-sync.R — committed docs match what render_docs.R derives.
#
# Same philosophy as test-script-copies-in-sync.R: derive from the source of
# truth in memory and fail if the committed artifact drifted. Sources are
# DESCRIPTION (version/imports), inst/steps.yaml, and
# inst/extdata/column_dictionary.csv (status == "implemented", non-empty
# name_a = delivered columns). Rendered regions live between AUTO markers in
# SKILL.md and README.md.

test_that("SKILL.md facts region matches render_docs.R output", {
  root <- if (basename(getwd()) == "testthat") dirname(dirname(getwd())) else getwd()
  rdr <- file.path(root, "tools", "render_docs.R")
  skip_if_not(file.exists(rdr), "tools/render_docs.R not found")
  source(rdr, local = TRUE)

  steps <- read_steps(file.path(root, "inst", "steps.yaml"))
  cols  <- read_dictionary_columns(file.path(root, "inst", "extdata", "column_dictionary.csv"))
  ver   <- pkg_version()
  n_imp <- length(pkg_imports())

  rendered <- c(
    "<!-- AUTO:SKILL_FACTS_START -->",
    "",
    render_skill_facts(steps, cols, ver, n_imp),
    "",
    "<!-- AUTO:SKILL_FACTS_END -->"
  )

  skill <- file.path(root, ".opencode", "skills", "splsleep-pipeline", "SKILL.md")
  skip_if_not(file.exists(skill), "SKILL.md not found")
  committed <- readLines(skill, warn = FALSE, encoding = "UTF-8")
  i_start <- which(trimws(committed) == "<!-- AUTO:SKILL_FACTS_START -->")
  i_end   <- which(trimws(committed) == "<!-- AUTO:SKILL_FACTS_END -->")
  expect_identical(length(i_start), 1L, info = "SKILL.md must have one SKILL_FACTS_START marker")
  expect_identical(length(i_end), 1L, info = "SKILL.md must have one SKILL_FACTS_END marker")
  expect_true(i_start < i_end, "markers in order")

  expect_identical(committed[i_start:i_end], rendered,
                   info = paste("SKILL.md facts drifted. Run: Rscript tools/render_docs.R",
                                "(also check inst/steps.yaml / column_dictionary.csv)"))
})

test_that("README architecture region matches render_docs.R output", {
  root <- if (basename(getwd()) == "testthat") dirname(dirname(getwd())) else getwd()
  rdr <- file.path(root, "tools", "render_docs.R")
  skip_if_not(file.exists(rdr), "tools/render_docs.R not found")
  source(rdr, local = TRUE)

  steps <- read_steps(file.path(root, "inst", "steps.yaml"))

  rendered <- c(
    "<!-- AUTO:ARCH_START -->",
    "",
    render_readme_steps(steps),
    "",
    "<!-- AUTO:ARCH_END -->"
  )

  readme <- file.path(root, "README.md")
  skip_if_not(file.exists(readme), "README.md not found")
  committed <- readLines(readme, warn = FALSE, encoding = "UTF-8")
  i_start <- which(trimws(committed) == "<!-- AUTO:ARCH_START -->")
  i_end   <- which(trimws(committed) == "<!-- AUTO:ARCH_END -->")
  expect_identical(length(i_start), 1L, info = "README.md must have one ARCH_START marker")
  expect_identical(length(i_end), 1L, info = "README.md must have one ARCH_END marker")
  expect_true(i_start < i_end, "markers in order")

  expect_identical(committed[i_start:i_end], rendered,
                   info = paste("README architecture drifted. Run: Rscript tools/render_docs.R",
                                "(also check inst/steps.yaml)"))
})

test_that("steps.yaml step ids match run_pipeline step markers", {
  root <- if (basename(getwd()) == "testthat") dirname(dirname(getwd())) else getwd()
  rdr <- file.path(root, "tools", "render_docs.R")
  skip_if_not(file.exists(rdr), "tools/render_docs.R not found")
  source(rdr, local = TRUE)

  steps <- read_steps(file.path(root, "inst", "steps.yaml"))
  ids <- vapply(steps, `[[`, character(1), "id")
  expect_true(length(ids) >= 10, "at least the 10 documented pipeline steps")

  # Every step id used by the S3-chain constructors must exist in the registry.
  pipeline_file <- file.path(root, "R", "pipeline.R")
  skip_if_not(file.exists(pipeline_file), "R/pipeline.R not found")
  src <- readLines(pipeline_file, warn = FALSE, encoding = "UTF-8")
  used <- regmatches(src, gregexpr('step_id = "[0-9.]+"', src))
  used <- unique(sub('step_id = "', "", unlist(used)))
  used <- sub('"$', "", used)
  used <- setdiff(used, c("0"))  # "0" is the pre-step sentinel, not a real step
  expect_true(all(used %in% ids),
              paste("steps.yaml missing step ids used in code:", paste(setdiff(used, ids), collapse = ", ")))
})

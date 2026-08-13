# Extracted from test-generated-docs-in-sync.R:86

# test -------------------------------------------------------------------------
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
rendered_zh <- c(
    "<!-- AUTO:ARCH_ZH_START -->",
    "",
    render_readme_steps_zh(steps),
    "",
    "<!-- AUTO:ARCH_ZH_END -->"
  )
i_zs <- which(trimws(committed) == "<!-- AUTO:ARCH_ZH_START -->")
i_ze <- which(trimws(committed) == "<!-- AUTO:ARCH_ZH_END -->")
expect_identical(length(i_zs), 1L, info = "README.md must have one ARCH_ZH_START marker")
expect_identical(length(i_ze), 1L, info = "README.md must have one ARCH_ZH_END marker")
expect_identical(committed[i_zs:i_ze], rendered_zh,
                   info = paste("README Chinese architecture drifted. Run: Rscript tools/render_docs.R",
                                "(also check inst/steps.yaml)"))

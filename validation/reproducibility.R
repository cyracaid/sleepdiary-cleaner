# reproducibility.R -- does the same input give the same output, every time?
#
# 1. Builds a synthetic diary with injected errors from fixed seeds, twice, and
#    checks the two builds are identical (validation/synthetic generators).
# 2. Runs the pipeline on it several times, each in a NEW R process and a NEW
#    empty directory (a deleted-and-rebuilt environment).
# 3. Runs it once more in the first directory with the old outputs still there
#    (a reset environment that was not cleaned).
# 4. Writes a manual error-correction file from the first run's worksheet (fixed
#    content: six sleep-awake switches marked corrected, one row marked pending),
#    runs twice more with include_manual_corrections = TRUE in new directories,
#    and requires at least one row of each kind: incorporated, pending, and in a
#    manual file but still failing.
# Every output file of every run is compared with the first run of its kind.
#
# What "identical" means, per file -- written here so nothing is excluded silently:
#   * every file not listed below: byte for byte (MD5);
#   * *.rds: the R object, with the attribute `calculation_timestamp` removed
#     (it records the wall-clock time of the run);
#   * output/correction_status.csv, output/correction_status_final.csv: every
#     column except `run_id` and `timestamp` (wall-clock time). These files and
#     output/review_runs.csv (column `run_at_utc` dropped) gain lines on every
#     run in the same directory, so in the re-used directory only the lines the
#     last run added are compared, and the line count must have grown by exactly
#     one run's worth;
#   * figures and RUN_INFO.txt are not produced (skip_visualization = TRUE).
# The script exits with status 1 if anything differs.
#
# Usage (from the repository root):
#   Rscript validation/reproducibility.R [--runs=3] [--workdir=DIR] [--installed]
# By default the package is loaded from this checkout with pkgload::load_all();
# --installed uses library(sleepcleanr) instead. Takes about two minutes.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
runs <- as.integer(opt("runs", "3"))
stopifnot(runs >= 2)
installed <- "--installed" %in% args
root <- normalizePath(".")
syn <- file.path(root, "validation", "synthetic")
if (!dir.exists(syn)) stop("Run from the repository root.")
work <- opt("workdir", tempfile("sleepcleanr_repro_"))
if (dir.exists(work) && length(list.files(work))) stop("workdir must be new or empty: ", work)
dir.create(work, recursive = TRUE, showWarnings = FALSE)
work <- normalizePath(work)
rscript <- file.path(R.home("bin"), "Rscript")
seed <- 20261019

run_r <- function(argv, log) {
  st <- system2(rscript, argv, stdout = log, stderr = log)
  if (!identical(st, 0L)) stop("failed: ", paste(argv, collapse = " "), "\n  see ", log)
}

# -- 1. input data, built twice ---------------------------------------------
build_input <- function(dir) {
  dir.create(dir, showWarnings = FALSE)
  clean <- file.path(dir, "clean.rds")
  run_r(c("--vanilla", file.path(syn, "generate_clean_data.R"), "--n_participants=40",
          "--n_days=14", "--mode=plausible", "--population=healthy_adult",
          paste0("--seed=", seed), paste0("--out=", clean)), file.path(dir, "generate.log"))
  catalog <- readLines(file.path(syn, "error_catalog.yaml"), encoding = "UTF-8")
  hit <- grep("^\\s*enrichment_target_per_category:", catalog)
  catalog[hit] <- sub("[0-9]+", "4", catalog[hit])
  writeLines(catalog, file.path(dir, "catalog.yaml"), useBytes = TRUE)
  run_r(c("--vanilla", file.path(syn, "inject_errors.R"), paste0("--clean_rds=", clean),
          paste0("--catalog=", file.path(dir, "catalog.yaml")),
          paste0("--out_data=", file.path(dir, "corrupted.rds")),
          paste0("--out_truth=", file.path(dir, "truth.csv")), paste0("--seed=", seed)),
        file.path(dir, "inject.log"))
  file.path(dir, "corrupted.rds")
}
cat("building the input data twice from seed", seed, "\n")
input <- build_input(file.path(work, "input_a"))
input_b <- build_input(file.path(work, "input_b"))
problems <- character(0)
if (!identical(readRDS(input), readRDS(input_b)))
  problems <- c(problems, "input: the two builds of the synthetic data differ")

# -- 2./3. pipeline runs ----------------------------------------------------
one_run <- function(dir, manual_error = NULL) {
  dir.create(dir, showWarnings = FALSE)
  manual <- if (is.null(manual_error)) "invisible(NULL)" else paste(
    sprintf("cfg$data$files$manual_error <- %s", deparse(manual_error)),
    "cfg$data$files$manual_unusual <- ''", sep = "; ")
  load <- if (installed) "library(sleepcleanr)" else
    sprintf("pkgload::load_all(%s, quiet = TRUE)", deparse(root))
  code <- paste(load,
    "cfg <- yaml::read_yaml(system.file('config_default.yaml', package = 'sleepcleanr'))",
    sprintf("cfg$data$files$main <- %s", deparse(input)),
    "cfg$data$files$extra <- NULL", manual,
    sprintf(paste0("run_pipeline(config = cfg, project_dir = %s, skip_visualization = TRUE, ",
                   "verbose = TRUE, include_manual_corrections = %s)"),
            deparse(dir), !is.null(manual_error)),
    sep = "; ")
  run_r(c("--vanilla", "-e", shQuote(code)), file.path(work, paste0(basename(dir), ".log")))
}

appended <- c("output/correction_status.csv", "output/correction_status_final.csv",
              "output/review_runs.csv")
time_cols <- c("run_id", "timestamp", "run_at_utc")

# A comparable fingerprint of one file; `tail_n` keeps only the last lines.
fingerprint <- function(path, rel, tail_n = NULL) {
  if (grepl("\\.rds$", rel)) {
    obj <- readRDS(path)
    attr(obj, "calculation_timestamp") <- NULL
    return(list(obj = obj))
  }
  if (rel %in% appended) {
    d <- utils::read.csv(path, colClasses = "character", check.names = FALSE)
    d <- d[, setdiff(names(d), time_cols), drop = FALSE]
    n <- nrow(d)
    if (!is.null(tail_n)) d <- d[seq_len(n) > n - tail_n, , drop = FALSE]
    rownames(d) <- NULL
    return(list(obj = d, n = n))
  }
  list(md5 = unname(tools::md5sum(path)))
}
snapshot <- function(dir, tail_from = NULL) {
  f <- sort(list.files(dir, recursive = TRUE, all.files = TRUE))
  stats::setNames(lapply(f, function(x) {
    tn <- if (!is.null(tail_from) && x %in% appended) tail_from[[x]]$n else NULL
    fingerprint(file.path(dir, x), x, tn)
  }), f)
}
compare <- function(label, ref, got) {
  for (x in setdiff(names(ref), names(got))) problems <<- c(problems, sprintf("%s: %s missing", label, x))
  for (x in setdiff(names(got), names(ref))) problems <<- c(problems, sprintf("%s: %s extra", label, x))
  for (x in intersect(names(ref), names(got)))
    if (!identical(ref[[x]][c("obj", "md5")], got[[x]][c("obj", "md5")]))
      problems <<- c(problems, sprintf("%s: %s differs", label, x))
}

dirs <- file.path(work, sprintf("fresh_%d", seq_len(runs)))
for (i in seq_along(dirs)) {
  cat(sprintf("run %d of %d: new R process, new directory %s\n", i, runs + 1, basename(dirs[i])))
  one_run(dirs[i])
}
ref <- snapshot(dirs[1])
for (d in dirs[-1]) compare(basename(d), ref, snapshot(d))

cat(sprintf("run %d of %d: again in %s, old outputs left in place\n", runs + 1, runs + 1, basename(dirs[1])))
one_run(dirs[1])
again <- snapshot(dirs[1], tail_from = ref)
compare("rerun_in_fresh_1", ref, again)
for (x in intersect(appended, names(ref)))
  if (!identical(again[[x]]$n, 2L * ref[[x]]$n))
    problems <- c(problems, sprintf("rerun_in_fresh_1: %s should have grown from %d to %d lines, has %d",
                                    x, ref[[x]]$n, 2L * ref[[x]]$n, again[[x]]$n))

# -- 4. manual corrections applied ------------------------------------------
ws <- utils::read.csv(file.path(dirs[1], "[NEW]manual_error_correction_review.csv"),
                      check.names = FALSE, colClasses = "character")
ws <- ws[ws$source == "on_step5_list", setdiff(names(ws), c("source", "status_after_corrections",
  "category_before_corrections", "category_after_corrections", "step8_flags_after_corrections",
  "in_manual_file", "review_resolution", "resolved_at", "resolved_by")), drop = FALSE]
ws <- ws[order(as.numeric(ws$row_id)), , drop = FALSE]
swap <- utils::head(ws$row_id, 6)
pend <- ws$row_id[7]
m <- ws[ws$row_id %in% c(swap, pend), , drop = FALSE]
s <- m$row_id %in% swap
m$problem_humanidentified <- ifelse(s, "sleep and awake times in each other's fields", "unclear")
m$solution_humanidentified <- ifelse(s, "Perform sleep-awake switch", "")
m$manually_corrected <- ifelse(s, "TRUE", "FALSE")
m$review_resolution <- ifelse(s, "corrected", "flagged_unresolved")
m$resolved_at <- ifelse(s, "2026-10-19", "")
m$resolved_by <- ifelse(s, "reproducibility.R", "pending")
manual_file <- file.path(work, "manual_error_corrections.csv")
utils::write.csv(m, manual_file, row.names = FALSE, na = "")
mdirs <- file.path(work, c("manual_1", "manual_2"))
for (d in mdirs) {
  cat(sprintf("manual run: new R process, new directory %s\n", basename(d)))
  one_run(d, manual_file)
}
compare(basename(mdirs[2]), snapshot(mdirs[1]), snapshot(mdirs[2]))
ms <- utils::read.csv(file.path(mdirs[1], "review_status.csv"))
need <- c(incorporated = any(ms$review_state == "incorporated"),
          pending = any(grepl("pending", ms$review_state_reason)),
          in_file_still_fails = any(ms$status_after_corrections == "in_manual_file_still_fails"))
for (k in names(need)[!need])
  problems <- c(problems, sprintf("manual run: expected at least one %s row", k))

# -- report -------------------------------------------------------------------
st <- utils::read.csv(file.path(dirs[1], "review_status.csv"))
tab <- table(factor(st$review_state, levels = c("needs_review", "not_incorporated", "incorporated")))
cat(sprintf("\n%d output file(s) compared across %d runs.\n", length(ref), runs + 1))
cat("review_status.csv:", paste(names(tab), tab, sep = " = ", collapse = ", "), "\n")
mtab <- table(factor(ms$review_state, levels = names(tab)))
cat("review_status.csv, manual corrections applied:",
    paste(names(mtab), mtab, sep = " = ", collapse = ", "), "\n")
if (length(problems)) {
  cat("NOT REPRODUCIBLE:\n", paste0("  ", problems, "\n"), sep = "")
  quit(status = 1)
}
cat("REPRODUCIBLE: every output is identical in every run (see the header for what is compared).\n")

library(lubridate)
library(dplyr); library(ggplot2); library(tidyr); library(readr); library(stringr)

# Helper: apply a processing function to multiple variables
multi_process <- function(df, var_list, func, format = NULL) {
  for (varname in var_list) {
    df <- func(df, varname = varname, format = format)
  }
  df
}

# ============================================================================
# PIPELINE — Master control function
# ============================================================================
# Run run_pipeline() on the R console to execute all 10 steps sequentially.
#
# What this pipeline does:
#   Takes raw EMA sleep diary data → parses timestamps → detects errors →
#   applies manual corrections → calculates sleep metrics → flags remaining
#   input anomalies → generates 30 diagnostic figures (14 QC + 16 research).
#
# Each step sources its own R file with local = TRUE (isolated environment).
# Data flows from one step to the next via the ema_data_release_* / corrected_ema_data objects.
# ============================================================================
.run_pipeline_internal <- function() {
  # Thin shim over the packaged pipeline (TECH_DEBT 5): the historical
  # self-contained implementation duplicated run_pipeline()'s ten steps and
  # drifted independently (e.g. .cfg used before assignment, caught by the
  # legacy-entry smoke test). All behaviour now lives in run_pipeline();
  # this entry point only bridges the legacy "source 00_MAIN_entry.R and
  # let it auto-run" calling convention. The config is taken from the
  # .GlobalEnv$pipeline_config the legacy workflow assigns, falling back to
  # the package default when absent.
  cfg <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
  run_pipeline(config = cfg, project_dir = ".", verbose = TRUE)
}

# ── Auto-run (non-interactive, when NOT called from sleepcleanr package) ──
if (!interactive() && !exists("sleepcleanr_loaded")) {
  .run_pipeline_internal()
}

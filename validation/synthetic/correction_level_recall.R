# correction_level_recall.R
#
# B1 (2026-10-05): report correction-level recall (L3) as a primary number,
# alongside detection-level recall (L1). Input is the committed synthetic
# benchmark outcome table; nothing is regenerated.
#
#   Rscript validation/synthetic/correction_level_recall.R

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
})

in_path <- "validation/synthetic/results/detection_outcomes_v4_current.csv"
out_path <- "validation/synthetic/results/correction_level_recall.csv"

d <- read_csv(in_path, show_col_types = FALSE)

# The clean control carries no injected error; exclude it from recall math.
inj <- d %>% filter(category != "no_error_control")

n_injected   <- sum(inj$n)
n_correct    <- sum(inj$CORRECT)
n_flagged    <- sum(inj$FLAGGED_UNRESOLVED)
n_misrepair  <- sum(inj$MISREPAIRED)
n_detected   <- n_correct + n_flagged + n_misrepair

overall <- tibble(
  metric = c(
    "n_injected",
    "detection_recall_L1",
    "correction_recall_L3",
    "flag_only_share",
    "misrepair_rate",
    "false_correction_count"
  ),
  value = c(
    n_injected,
    round(n_detected / n_injected, 4),
    round(n_correct / n_injected, 4),
    round(n_flagged / n_injected, 4),
    round(n_misrepair / n_injected, 4),
    n_misrepair
  )
)

per_cat <- inj %>%
  transmute(
    category,
    n,
    detection_recall_L1 = round((CORRECT + FLAGGED_UNRESOLVED + MISREPAIRED) / n, 4),
    correction_recall_L3 = round(CORRECT / n, 4),
    flagged_unresolved = FLAGGED_UNRESOLVED,
    misrepaired = MISREPAIRED
  )

write_csv(overall, out_path)
write_csv(per_cat, sub("\\.csv$", "_per_category.csv", out_path))

print(overall)
cat("\nWrote:", out_path, "\n")

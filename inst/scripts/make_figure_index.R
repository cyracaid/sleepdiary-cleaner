#!/usr/bin/env Rscript
# make_figure_index.R
# Builds a single contact-sheet index of all pipeline figures, grouped by tier,
# with a one-line caption under each thumbnail. Output: figure_index.png
#
# Usage (standalone):  Rscript make_figure_index.R [viz_dir]
# Usage (sourced):     generate_figure_index("latest_visualization")
#
# Requires: magick  (install.packages("magick"))
# Gracefully skips if magick is not available.

generate_figure_index <- function(viz_dir = "latest_visualization") {
  if (!requireNamespace("magick", quietly = TRUE)) {
    message("magick package not installed, skipping figure_index generation.")
    message("To install: install.packages('magick')")
    return(invisible(FALSE))
  }
  library(magick)
  out_path <- file.path(viz_dir, "figure_index.png")

  reg <- rbind(
    c("pipeline_cleaning/01_Pipeline_Flow_Diagram.png",        1, "Pipeline record flow (counts + percentages)"),
    c("pipeline_cleaning/12_Pipeline_Correction_Progress.png",  1, "Did cleaning converge across all steps?"),
    c("pipeline_cleaning/P26_PerParticipant_Flag_Rate.png",     1, "Per-participant flag rate"),
    c("pipeline_cleaning/A1_Step_Flag_Ledger.png",              2, "Per-step flag tracking ledger"),
    c("pipeline_cleaning/07_Flag_Composition_Stacked.png",      2, "Flag composition at each pipeline step"),
    c("pipeline_cleaning/06_Sleep_Duration_Post_Correction.png",2, "Sleep duration post-correction"),
    c("pipeline_cleaning/08_Sleep_Duration_by_Category.png",    2, "Duration by clean/unusual/error category"),
    c("pipeline_cleaning/10_Extreme_Sleep_Duration.png",        2, "Extreme durations + efficiency context"),
    c("pipeline_cleaning/19_Unified_Quality_Status.png",        2, "Final unified quality status"),
    c("research_ready/02_Correction_Impact.png",                3, "Correction impact (delta lollipops + scatter)"),
    c("research_ready/02_Distribution_Sleep_Variables.png",     3, "Key sleep-variable distributions"),
    c("research_ready/03_Sleep_Duration_Distribution.png",      3, "TST distribution"),
    c("research_ready/04_Sleep_Duration_vs_Time_in_Bed.png",    3, "TST vs Time in Bed"),
    c("research_ready/04B_SOL_vs_Sleep_Duration.png",           3, "SOL vs TST"),
    c("research_ready/05_Variability_Sleep_Variables.png",      3, "Variability of sleep variables"),
    c("research_ready/09_Bedtime_vs_Getup_Distribution.png",    3, "Circadian timing"),
    c("research_ready/R25_Sleep_Regularity_Weekday_Weekend.png",3, "Weekday vs weekend regularity"),
    c("research_ready/R26_Sleep_Composition_TIB_Breakdown.png", 3, "TIB composition breakdown"),
    c("research_ready/R27_Sleep_Metrics_Correlation_Matrix.png",3, "Sleep metrics correlation matrix"),
    c("research_ready/20_SOL_Perception_Bias.png",              3, "Subjective vs objective SOL"),
    c("research_ready/20B_WASO_Perception_Bias.png",            3, "Subjective vs objective WASO"),
    c("research_ready/21_Substance_Use_Availability.png",       3, "Substance-use data coverage"),
    c("research_ready/22_Substance_Use_Distribution.png",       3, "Substance-use distributions"),
    c("research_ready/23_Caffeine_Consumption.png",             3, "Caffeine consumption"),
    c("research_ready/24_Alcohol_Consumption.png",              3, "Alcohol consumption")
  )
  reg <- data.frame(file = reg[, 1], tier = as.integer(reg[, 2]),
                    caption = reg[, 3], stringsAsFactors = FALSE)

  tier_titles <- c("TIER 1 \u2014 60-Second Quality Check",
                   "TIER 2 \u2014 Diagnose What / Where / Who",
                   "TIER 3 \u2014 Research Outputs")

  thumb_w   <- 1000L
  cols      <- 2L
  pad       <- 18L
  cap_h     <- 58L
  hdr_h     <- 60L
  bg        <- "white"

  make_thumb <- function(path, caption) {
    full <- file.path(viz_dir, path)
    if (!file.exists(full)) return(NULL)
    img <- image_read(full)
    img <- image_resize(img, paste0(thumb_w, "x"))
    img <- image_border(img, "gray80", "1x1")
    label <- paste0(sub("\\.png$", "", basename(path)), "  \u2014  ", caption)
    th <- image_blank(image_info(img)$width, cap_h, "gray95")
    th <- image_annotate(th, label, gravity = "west", location = "+8+0",
                         size = 18, color = "gray20", weight = 400)
    image_append(c(img, th), stack = TRUE)
  }

  row_strip <- function(imgs) {
    h <- max(vapply(imgs, function(i) image_info(i)$height, integer(1)))
    imgs <- lapply(imgs, function(i) image_extent(i, paste0(image_info(i)$width, "x", h),
                                                  gravity = "north", color = bg))
    image_append(do.call(c, imgs), stack = FALSE)
  }

  header_bar <- function(text, width) {
    h <- image_blank(width, hdr_h, "gray20")
    h <- image_annotate(h, text, gravity = "west", location = "+14+0",
                   size = 26, color = "white", weight = 700)
  }

  blocks <- list()
  for (t in 1:3) {
    sub <- reg[reg$tier == t, ]
    if (nrow(sub) == 0) next
    thumbs <- Filter(Negate(is.null), Map(make_thumb, sub$file, sub$caption))
    if (length(thumbs) == 0) next
    rows <- list()
    for (start in seq(1, length(thumbs), by = cols)) {
      chunk <- thumbs[start:min(start + cols - 1, length(thumbs))]
      rows[[length(rows) + 1]] <- row_strip(chunk)
    }
    full_w <- max(vapply(rows, function(r) image_info(r)$width, integer(1)))
    rows <- lapply(rows, function(r) image_extent(r, paste0(full_w, "x", image_info(r)$height),
                                                  gravity = "northwest", color = bg))
    body <- image_append(do.call(c, rows), stack = TRUE)
    hdr  <- header_bar(tier_titles[t], full_w)
    blocks[[length(blocks) + 1]] <- image_append(c(hdr, body), stack = TRUE)
  }

  full_w <- max(vapply(blocks, function(b) image_info(b)$width, integer(1)))
  blocks <- lapply(blocks, function(b) image_extent(b, paste0(full_w, "x", image_info(b)$height),
                                                    gravity = "northwest", color = bg))
  sheet <- image_append(do.call(c, blocks), stack = TRUE)
  sheet <- image_border(sheet, bg, paste0(pad, "x", pad))

  image_write(sheet, out_path, format = "png")
  cat(sprintf("Figure index written to: %s  (%d figures)\n", out_path, nrow(reg)))
}

if (interactive() || !exists("splsleep_loaded")) {
  args <- commandArgs(trailingOnly = TRUE)
  viz_dir <- if (length(args) >= 1) args[1] else "latest_visualization"
  generate_figure_index(viz_dir)
}

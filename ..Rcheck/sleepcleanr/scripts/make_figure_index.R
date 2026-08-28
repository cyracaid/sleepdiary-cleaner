# Generate a contact sheet (figure_index.png) from a run's diagnostic figures
# 
# Usage: generate_figure_index("path/to/viz_output")
#        or run_figure_index("path/to/viz_output") from the R console

generate_figure_index <- function(viz_dir) {
  if (!dir.exists(viz_dir)) {
    stop("Visualization directory not found: ", viz_dir)
  }
  
  out_path <- file.path(viz_dir, "figure_index.png")
  
  # Registry: (path, tier, caption)
  reg <- rbind(
    c("pipeline_cleaning/01_Pipeline_Flow_Diagram.png",       1, "Pipeline flow"),
    c("pipeline_cleaning/06_Sleep_Duration_Post_Correction.png", 1, "Sleep duration (post-correction)"),
    c("pipeline_cleaning/07_Flag_Composition_Stacked.png",      1, "Flag composition"),
    c("pipeline_cleaning/08_Sleep_Duration_by_Category.png",    1, "Sleep duration by category"),
    c("pipeline_cleaning/10_Extreme_Sleep_Duration.png",        1, "Extreme sleep duration"),
    c("pipeline_cleaning/12_Pipeline_Correction_Progress.png",  1, "Correction progress"),
    c("pipeline_cleaning/13_Error_Category_Distribution.png",   1, "Error category distribution"),
    c("pipeline_cleaning/15_Error_Timeline.png",                1, "Error timeline"),
    c("pipeline_cleaning/17_Top_Participants_Flags.png",        1, "Top participants by flag count"),
    c("pipeline_cleaning/18_Auto_Detected_Dashboard.png",       1, "Auto-detected issues dashboard"),
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
  
  tier_titles <- c("TIER 1 — 60-Second Quality Check",
                   "TIER 2 — Diagnose What / Where / Who",
                   "TIER 3 — Research Outputs")
  
  thumb_w   <- 1000L
  cols      <- 2L
  pad       <- 18L
  cap_h     <- 58L
  hdr_h     <- 60L
  bg        <- "white"
  
  make_thumb <- function(path, caption) {
    full <- file.path(viz_dir, path)
    if (!file.exists(full)) return(NULL)
    tryCatch({
      img <- magick::image_read(full)
      img <- magick::image_resize(img, paste0(thumb_w, "x"))
      img <- magick::image_border(img, "gray80", "1x1")
      label <- paste0(sub("\\.png$", "", basename(path)), "  — ", caption)
      th <- magick::image_blank(magick::image_info(img)$width, cap_h, "gray95")
      th <- magick::image_annotate(th, label, gravity = "west", location = "+8+0",
                           size = 18, color = "gray20", weight = 400)
      magick::image_append(c(img, th), stack = TRUE)
    }, error = function(e) {
      cat("[WARNING] Failed to process", path, ":", conditionMessage(e), "\n")
      NULL
    })
  }
  
  row_strip <- function(imgs) {
    if (length(imgs) == 0) return(NULL)
    tryCatch({
      h <- max(vapply(imgs, function(i) magick::image_info(i)$height, integer(1)))
      imgs <- lapply(imgs, function(i) magick::image_extent(i, paste0(magick::image_info(i)$width, "x", h),
                                                    gravity = "north", color = bg))
      magick::image_append(do.call(c, imgs), stack = FALSE)
    }, error = function(e) {
      cat("[WARNING] row_strip failed:", conditionMessage(e), "\n")
      NULL
    })
  }
  
  header_bar <- function(text, width) {
    h <- magick::image_blank(width, hdr_h, "gray20")
    h <- magick::image_annotate(h, text, gravity = "west", location = "+14+0",
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
      row <- row_strip(chunk)
      if (!is.null(row)) rows[[length(rows) + 1]] <- row
    }
    if (length(rows) == 0) next
    full_w <- max(vapply(rows, function(r) magick::image_info(r)$width, integer(1)))
    rows <- lapply(rows, function(r) magick::image_extent(r, paste0(full_w, "x", magick::image_info(r)$height),
                                                  gravity = "northwest", color = bg))
    body <- magick::image_append(do.call(c, rows), stack = TRUE)
    hdr  <- header_bar(tier_titles[t], full_w)
    blocks[[length(blocks) + 1]] <- magick::image_append(c(hdr, body), stack = TRUE)
  }
  
  if (length(blocks) == 0) {
    cat("[ERROR] No valid figures found in", viz_dir, "\n")
    return(invisible(FALSE))
  }
  
  full_w <- max(vapply(blocks, function(b) magick::image_info(b)$width, integer(1)))
  blocks <- lapply(blocks, function(b) magick::image_extent(b, paste0(full_w, "x", magick::image_info(b)$height),
                                                    gravity = "northwest", color = bg))
  sheet <- magick::image_append(do.call(c, blocks), stack = TRUE)
  sheet <- magick::image_border(sheet, bg, paste0(pad, "x", pad))
  
  magick::image_write(sheet, out_path, format = "png")
  cat(sprintf("✓ Figure index written to: %s  (%d figures)\n", out_path, nrow(reg)))
  invisible(TRUE)
}

if (interactive() || !exists("sleepcleanr_loaded")) {
  cat("[debug mode] make_figure_index.R loaded but not auto-executing\n")
}

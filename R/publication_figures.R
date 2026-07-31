# Pipeline workflow figure (Figure 1) + Before/After figure (Figure 2)
# Publication-quality. Extracts all numbers from existing pipeline outputs.
# No helper summarise_corrections() -- counts computed inline.
# Dependencies: ggplot2 (already in Imports), no new packages.

library(ggplot2)

# --------------------------------------------------------------
# Data extraction helpers (inline, not exported functions)
# --------------------------------------------------------------

.guard <- function() {
  if (!exists("corrected_ema_data", envir = .GlobalEnv))
    stop("corrected_ema_data not found. Run the pipeline first (run_pipeline()).")
}

.extract_counts <- function(df) {
  total   <- nrow(df)
  n_auto  <- sum(!is.na(df$correction_type) &
                   (is.na(df$manually_corrected) | df$manually_corrected == FALSE), na.rm = TRUE)
  n_manual <- sum(df$manually_corrected == TRUE, na.rm = TRUE)
  n_flagged <- sum(df$data_category %in% c("error", "unusual") &
                     (is.na(df$manually_corrected) | df$manually_corrected == FALSE) &
                     (is.na(df$correction_type) | df$correction_type == ""), na.rm = TRUE)
  n_error   <- sum(df$data_category == "error", na.rm = TRUE)
  n_unusual <- sum(df$data_category == "unusual", na.rm = TRUE)
  n_equal   <- sum(df$data_category == "equal_time_ok", na.rm = TRUE)
  n_skipped <- sum(df$data_category == "skipped_na", na.rm = TRUE)
  n_clean   <- total - n_auto - n_manual - n_flagged - n_skipped - n_equal - n_error - n_unusual
  list(total = total, n_auto = n_auto, n_manual = n_manual,
       n_flagged = n_flagged, n_error = n_error, n_unusual = n_unusual,
       n_equal = n_equal, n_skipped = n_skipped, n_clean = n_clean)
}

# --------------------------------------------------------------
# Figure 1: Pipeline Workflow Flow Diagram
# --------------------------------------------------------------

#' Generate the pipeline workflow figure (Figure 1)
#'
#' Produces a publication-quality flow diagram showing how raw records
#' move through automatic validation, algorithmic correction, manual
#' review, and into the final clean dataset. All counts and percentages
#' are extracted from \code{corrected_ema_data} in the global environment.
#'
#' @return The ggplot object, invisibly.
#' @export
figure_pipeline_workflow <- function() {
  .guard()
  df <- get("corrected_ema_data", envir = .GlobalEnv)
  cc <- .extract_counts(df)

  # Derived categories
  n_removed <- cc$n_error
  n_auto_corrected <- cc$n_auto
  n_manual_corrected <- cc$n_manual
  n_reviewed_unchanged <- cc$n_flagged + cc$n_unusual
  n_final <- cc$n_clean + cc$n_equal
  n_total <- cc$total

  pct <- function(x) round(x / n_total * 100, 1)

  # Build nodes data frame
  nodes <- data.frame(
    id = c("raw", "errors", "algocorrect", "manualcorrect",
           "reviewed", "final"),
    label = c(
      sprintf("Raw Sleep Diary\nRecords\nN = %d", n_total),
      sprintf("Auto-Detected\nErrors Removed\nN = %d (%.1f%%)", n_removed, pct(n_removed)),
      sprintf("Algorithmic\nCorrection\nN = %d (%.1f%%)", n_auto_corrected, pct(n_auto_corrected)),
      sprintf("Manual Review\n& Correction\nN = %d (%.1f%%)", n_manual_corrected, pct(n_manual_corrected)),
      sprintf("Reviewed,\nUnchanged\nN = %d (%.1f%%)", n_reviewed_unchanged, pct(n_reviewed_unchanged)),
      sprintf("Final Clean\nDataset\nN = %d (%.1f%%)", n_final, pct(n_final))
    ),
    x = c(0, -2.5, 2.5, 2.5, -2.5, 0),
    y = c(5, 3.5, 3.5, 2, 2, 0),
    fill = c("#2166AC", "#B2182B", "#F4A582", "#4393C3", "#D1C4E9", "#4DAF4A"),
    width = c(2.8, 2.8, 2.8, 2.8, 2.8, 2.8),
    height = c(0.8, 0.8, 0.8, 0.8, 0.8, 0.8),
    stringsAsFactors = FALSE
  )

  # Build edges data frame
  edges <- data.frame(
    x = c(0, 0, 2.5, 2.5, -1, -1),
    y = c(4.6, 4.6, 3, 3, 2.6, 2.6),
    xend = c(-1.2, 1.2, 0, 3.5, -2.5, 0.5),
    yend = c(3.9, 3.9, 2.4, 2, 1.6, 0.4),
    label = c("", "", "", "",
              sprintf("%.0f (%.1f%%)", cc$n_equal + cc$n_clean, pct(cc$n_equal + cc$n_clean)), ""),
    stringsAsFactors = FALSE
  )

  p <- ggplot(nodes) +
    # Arrow segments
    geom_segment(data = edges,
                 aes(x = x, y = y, xend = xend, yend = yend),
                 arrow = arrow(length = unit(0.08, "inches"), type = "closed"),
                 colour = "grey50", linewidth = 0.5) +

    # Boxes
    geom_tile(aes(x = x, y = y, fill = I(fill)),
              width = nodes$width, height = nodes$height,
              colour = "grey30", linewidth = 0.7) +

    # Labels
    geom_text(aes(x = x, y = y - 0.05, label = label),
              size = 3.8, lineheight = 0.9, colour = "white",
              fontface = "bold") +

    # Legend-like annotation
    annotate("text", x = 0, y = -1.2, size = 3.2, colour = "grey40", lineheight = 0.85,
             label = sprintf(
"Correction summary:
  %d auto-corrected (%.1f%%)
  %d manually corrected (%.1f%%)
  %d reviewed, unchanged (%.1f%%)
  %d auto-detected errors removed (%.1f%%)
  %d clean records (%.1f%%)",
               n_auto_corrected, pct(n_auto_corrected),
               n_manual_corrected, pct(n_manual_corrected),
               n_reviewed_unchanged, pct(n_reviewed_unchanged),
               n_removed, pct(n_removed),
               n_final, pct(n_final))) +

    xlim(-4, 4) + ylim(-1.5, 6) +
    labs(title = "Figure 1. Sleep diary cleaning pipeline workflow",
         subtitle = sprintf("Flow of %d raw records through automatic and manual correction stages", n_total)) +
    theme_void(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
      plot.subtitle = element_text(size = 9, colour = "grey40", hjust = 0.5, margin = margin(b = 10))
    )

  dir.create("figures", showWarnings = FALSE)
  ggsave("figures/Figure_1_Pipeline_Workflow.png", p, width = 8, height = 6, dpi = 300)
  cat("  Saved: figures/Figure_1_Pipeline_Workflow.png\n")
  invisible(p)
}

# --------------------------------------------------------------
# Figure 2: Effect of Cleaning — Before/After TST & SOL
# --------------------------------------------------------------

#' Generate the before/after cleaning effect figure (Figure 2)
#'
#' Three-panel figure showing:\describe{
#'   \item{A}{SOL before (self-reported) vs after (computed) with boxplot + violin.}
#'   \item{B}{TST distribution after cleaning, stacked by flag severity.}
#'   \item{C}{Individual record changes — scatter plot of self-reported vs computed SOL,
#'     coloured by correction type (auto, manual, unchanged).}
#' }
#' All data extracted from \code{corrected_ema_data}. Requires \code{patchwork}
#' for combined layout.
#'
#' @return The combined ggplot object, invisibly.
#' @export
figure_cleaning_effect <- function() {
  .guard()
  df <- get("corrected_ema_data", envir = .GlobalEnv)
  cc <- .extract_counts(df)

  # ---- Panel A: SOL before (self-reported) vs after (computed) ----
  sol_before <- df[["duration_totalmin_sol_estimate_am_mincalc"]]
  sol_after  <- df[["self_diffcalc_sol_minutes"]]

  valid_sol <- !is.na(sol_before) & !is.na(sol_after) & is.finite(sol_before) & is.finite(sol_after)

  sol_plot_df <- data.frame(
    value = c(sol_before[valid_sol], sol_after[valid_sol]),
    time  = rep(c("Before cleaning\n(self-reported)", "After cleaning\n(from timestamps)"),
                each = sum(valid_sol)),
    stringsAsFactors = FALSE
  )

  sol_mean_before <- mean(sol_before[valid_sol], na.rm = TRUE)
  sol_mean_after  <- mean(sol_after[valid_sol], na.rm = TRUE)

  p_sol <- ggplot(sol_plot_df, aes(x = time, y = value, fill = time)) +
    geom_violin(alpha = 0.65, bw = 8) +
    geom_boxplot(width = 0.25, alpha = 0.8, outlier.size = 0.6) +
    stat_summary(fun = mean, geom = "point", shape = 18, size = 3, colour = "black") +
    scale_fill_manual(values = c("Before cleaning\n(self-reported)" = "#D6604D",
                                  "After cleaning\n(from timestamps)" = "#2166AC")) +
    labs(x = NULL, y = "SOL (minutes)",
         title = "A  Sleep Onset Latency") +
    annotate("text", x = 0.55, y = max(sol_plot_df$value, na.rm = TRUE) * 0.9,
             size = 3, colour = "grey30", hjust = 0,
             label = sprintf("Before: %.0f min\nAfter:  %.0f min", sol_mean_before, sol_mean_after)) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "none",
          plot.title = element_text(face = "bold", size = 11))

  # ---- Panel B: TST distribution (after only, coloured by severity) ----
  tst <- df[["self_diffcalc_totalsleeptime_minutes"]]
  sev <- tryCatch(df[["flag_severity"]], error = function(e) rep("Clean", length(tst)))
  sev_clean <- ifelse(is.na(sev) | sev %in% c("Clean", ""), "Clean",
                      ifelse(grepl("Minor", sev), "Minor", "Major"))

  valid_tst <- !is.na(tst) & is.finite(tst)
  tst_plot_df <- data.frame(
    tst = tst[valid_tst],
    severity = sev_clean[valid_tst],
    stringsAsFactors = FALSE
  )
  tst_mean <- mean(tst_plot_df$tst, na.rm = TRUE)

  p_tst <- ggplot(tst_plot_df, aes(x = tst, fill = severity)) +
    geom_histogram(bins = 30, alpha = 0.8, position = "stack") +
    scale_fill_manual(values = c("Clean" = "#4DAF4A", "Minor" = "#F4A582", "Major" = "#B2182B")) +
    geom_vline(xintercept = tst_mean, linetype = "dashed", colour = "grey40", linewidth = 0.6) +
    annotate("text", x = tst_mean + 20, y = Inf, size = 3, colour = "grey40", hjust = 0, vjust = 2,
             label = sprintf("Mean = %.0f min (%.2f h)", tst_mean, tst_mean / 60)) +
    labs(x = "TST (minutes)", y = "Count", fill = "Flag severity",
         title = "B  Total Sleep Time (after cleaning)") +
    theme_minimal(base_size = 11) +
    theme(legend.position = c(0.85, 0.85),
          plot.title = element_text(face = "bold", size = 11))

  # ---- Panel C: Individual record changes (SOL) ----
  df_plot <- data.frame(
    before = sol_before,
    after  = sol_after,
    correction = ifelse(is.na(df$correction_type) | df$correction_type == "", "Unchanged",
                        ifelse(df$manually_corrected == TRUE, "Manual", "Auto")),
    stringsAsFactors = FALSE
  )
  df_plot <- df_plot[valid_sol, ]

  # Create a proper ordered factor
  cor_levels <- c("Unchanged", "Auto", "Manual")
  cor_levels <- intersect(cor_levels, unique(df_plot$correction))
  df_plot$correction <- factor(df_plot$correction, levels = cor_levels)

  # For individual change display, limit to records that actually changed
  df_changed <- df_plot[abs(df_plot$after - df_plot$before) > 1, ]
  n_changed <- nrow(df_changed)
  n_unchanged <- sum(abs(df_plot$after - df_plot$before) <= 1, na.rm = TRUE)

  p_scatter <- ggplot(df_plot, aes(x = before, y = after, colour = correction)) +
    geom_abline(slope = 1, intercept = 0, colour = "grey70", linetype = "dashed", linewidth = 0.4) +
    geom_point(alpha = 0.5, size = 1.2) +
    scale_colour_manual(
      values = c("Unchanged" = "#4DAF4A", "Auto" = "#F4A582", "Manual" = "#4393C3"),
      breaks = cor_levels
    ) +
    coord_fixed() +
    labs(x = "Self-reported SOL (minutes)", y = "Computed SOL (minutes)",
         colour = "Correction type",
         title = "C  Individual record changes") +
    annotate("text", x = Inf, y = -Inf, size = 3, colour = "grey40",
             hjust = 1.1, vjust = -1,
             label = sprintf("%d unchanged, %d changed\n%d auto, %d manual",
                             n_unchanged, n_changed,
                             sum(df_changed$correction == "Auto", na.rm = TRUE),
                             sum(df_changed$correction == "Manual", na.rm = TRUE))) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom",
          plot.title = element_text(face = "bold", size = 11))

  if (requireNamespace("patchwork", quietly = TRUE)) {
    library(patchwork)
    combined <- (p_sol + p_tst) / p_scatter +
      plot_annotation(
        title = "Figure 2. Effect of the cleaning pipeline on sleep metrics",
        subtitle = sprintf(
          "N = %d records. SOL: before = self-reported (mincalc), after = computed from corrected timestamps. TST: after cleaning, coloured by flag severity.",
          nrow(df)),
        tag_levels = "A",
        theme = theme_minimal(base_size = 11)
      ) &
      theme(plot.tag = element_text(face = "bold", size = 12))

    dir.create("figures", showWarnings = FALSE)
    ggsave("figures/Figure_2_Cleaning_Effect.png", combined,
           width = 10, height = 10, dpi = 300)
    cat("  Saved: figures/Figure_2_Cleaning_Effect.png\n")
    invisible(combined)
  }
}

#' Bland-Altman analysis for self-reported vs computed sleep metrics
#'
#' Compares two measurement methods of the same quantity using the method
#' described by Bland & Altman (1986). Computes bias, 95 % limits of
#' agreement, and a proportional-bias test, then plots the result.
#'
#' @section Role in the pipeline:
#'
#' This function is **advisory only**. It does not modify data, it does not
#' override any cleaning threshold, and its output is never fed back into the
#' pipeline decision tree. Think of it as an optional quality report you
#' generate *after* cleaning to answer: "how much do the participant's own
#' estimates disagree with the values my pipeline computed from timestamps?"
#'
#' @param data A data frame. Typically \code{corrected_ema_data} after
#'   \code{run_cleaning_chain()} or \code{run_pipeline()}.
#' @param reported_col Character. Name of the column holding the participant's
#'   self-reported estimate (e.g. \code{"duration_totalmin_sol_estimate_am_mincalc"}).
#' @param computed_col Character. Name of the column holding the pipeline-
#'   computed value (e.g. \code{"self_diffcalc_sol_minutes"}).
#' @param label Character. Human-readable label for the metric, used in plot
#'   titles. Defaults to \code{"Metric"}.
#' @param loa_ci Logical. If \code{TRUE}, compute 95 % confidence intervals
#'   for the limits of agreement via the Bland-Altman method (requires
#'   \code{blandr} or \code{BlandAltmanLeh} if installed; otherwise falls back
#'   to parametric approximation).
#'
#' @return A list with components \code{bias} (mean difference), \code{lower_loa},
#'   \code{upper_loa} (95 % limits of agreement), \code{prop_bias_p} (p-value
#'   from a regression of differences on means, testing for proportional bias),
#'   \code{n_pairs} (number of complete pairs), and \code{plot} (a ggplot
#'   object).
#'
#' @section Known limitations:
#'
#' * True Bland-Altman requires two independent measurement instruments.
#'   In EMA data the "computed" SOL is derived from self-reported bed/sleep
#'   timestamps -- not from an objective device like actigraphy or PSG.
#'   Interpret the bias as an *agreement between two processing methods for
#'   the same source*, not as an accuracy assessment against a gold standard.
#'
#' @references
#' Bland, J. M., & Altman, D. G. (1986). Statistical methods for assessing
#' agreement between two methods of clinical measurement. *The Lancet*,
#' 327(8476), 307-310.
#'
#' @export
bland_altman <- function(data,
                         reported_col,
                         computed_col,
                         label = "Metric",
                         loa_ci = FALSE) {

  stopifnot(is.data.frame(data))
  stopifnot(reported_col %in% names(data),
            computed_col %in% names(data))

  x <- data[[reported_col]]
  y <- data[[computed_col]]

  complete <- !is.na(x) & !is.na(y) & is.finite(x) & is.finite(y)
  n_pairs  <- sum(complete)

  if (n_pairs < 5) {
    warning("Fewer than 5 complete pairs -- Bland-Altman may be unreliable.")
  }
  if (n_pairs == 0) {
    stop("No complete pairs found in ", reported_col, " and ", computed_col, ".")
  }

  mn   <- (x[complete] + y[complete]) / 2
  diff <- y[complete] - x[complete]      # computed minus reported

  bias   <- mean(diff)
  sd_bias <- stats::sd(diff)
  n <- length(diff)

  lower_loa <- bias - 1.96 * sd_bias
  upper_loa <- bias + 1.96 * sd_bias

  # Proportional bias: does the difference change with the mean?
  prop_fit <- stats::lm(diff ~ mn)
  prop_bias_p <- tryCatch(
    stats::coef(summary(prop_fit))["mn", "Pr(>|t|)"],
    error = function(e) NA_real_
  )

  # Limits-of-agreement CIs (Bland & Altman 1986, section 4)
  se_loa <- sqrt(3 * sd_bias^2 / n)
  loa_ci_lower <- lower_loa - 1.96 * se_loa
  loa_ci_upper <- upper_loa + 1.96 * se_loa

  pct_outside <- mean(diff < lower_loa | diff > upper_loa, na.rm = TRUE)

  # Build plot
  plot_df <- data.frame(mean = mn, diff = diff, stringsAsFactors = FALSE)

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = .data$mean, y = .data$diff)) +
    ggplot2::geom_hline(yintercept = bias, linetype = "dashed", colour = "#2166AC", linewidth = 0.8) +
    ggplot2::geom_hline(yintercept = lower_loa, linetype = "dotted", colour = "#B2182B", linewidth = 0.6) +
    ggplot2::geom_hline(yintercept = upper_loa, linetype = "dotted", colour = "#B2182B", linewidth = 0.6) +
    ggplot2::geom_point(alpha = 0.4, size = 1.2, colour = "grey30") +
    ggplot2::geom_smooth(method = "lm", se = TRUE, colour = "#D6604D",
                         linewidth = 0.6, alpha = 0.15) +
    ggplot2::scale_y_continuous(labels = function(z) sprintf("%+.0f", z)) +
    ggplot2::labs(
      title    = sprintf("Bland-Altman: %s (computed \u2212 reported)", label),
      subtitle = sprintf("Bias %+.1f  |  95%% LoA [%+.1f, %+.1f]  |  %.1f%% outside  |  n = %d",
                         bias, lower_loa, upper_loa, pct_outside * 100, n_pairs),
      x        = sprintf("Mean %s (minutes)", label),
      y        = sprintf("Difference (%s)", label),
      caption  = sprintf("Proportional bias p = %.3f%s",
                         prop_bias_p,
                         if (is.na(prop_bias_p)) " (could not compute)" else
                           if (prop_bias_p < 0.05) " *" else "")
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey40"),
      plot.caption  = ggplot2::element_text(size = 8, colour = "grey60")
    )

  invisible(list(
    bias          = bias,
    lower_loa     = lower_loa,
    upper_loa     = upper_loa,
    lower_loa_ci  = if (loa_ci) loa_ci_lower else NULL,
    upper_loa_ci  = if (loa_ci) loa_ci_upper else NULL,
    prop_bias_p   = prop_bias_p,
    n_pairs       = n_pairs,
    pct_outside   = pct_outside,
    plot          = p
  ))
}

#' Print a Bland-Altman summary
#'
#' @param x A list returned by \code{bland_altman()}.
#' @param ... Unused.
#' @return \code{x}, invisibly.
#' @export
print.bland_altman <- function(x, ...) {
  cat(sprintf("Bland-Altman analysis (%d pairs)\n", x$n_pairs))
  cat(sprintf("  Bias (computed - reported): %+.2f\n", x$bias))
  cat(sprintf("  95%% LoA: [%+.2f, %+.2f]\n", x$lower_loa, x$upper_loa))
  if (!is.null(x$lower_loa_ci)) {
    cat(sprintf("  LoA 95%% CI: [%+.2f, %+.2f]\n", x$lower_loa_ci, x$upper_loa_ci))
  }
  cat(sprintf("  %.1f%% of pairs outside limits\n", x$pct_outside * 100))
  if (!is.na(x$prop_bias_p)) {
    cat(sprintf("  Proportional bias p = %.3f%s\n",
                x$prop_bias_p,
                if (x$prop_bias_p < 0.05) " (* significant)" else ""))
  }
  invisible(x)
}

#' Plot a Bland-Altman result
#'
#' @param x A list returned by \code{bland_altman()}.
#' @param ... Passed to \code{print.ggplot}.
#' @return The ggplot object, invisibly.
#' @export
plot.bland_altman <- function(x, ...) {
  if (inherits(x$plot, "ggplot")) {
    print(x$plot)
    invisible(x$plot)
  } else {
    message("No plot available.")
    invisible(NULL)
  }
}

# ---------------------------------------------------------------------------
# Threshold validation -- Bland-Altman vs configured cutoffs
# ---------------------------------------------------------------------------

#' Validate cleaning thresholds against Bland-Altman agreement limits
#'
#' Runs Bland-Altman analysis on the SOL and WASO self-report / computed
#' pairs, then compares each threshold in the pipeline configuration against
#' the 95 % limits-of-agreement half-width (the typical disagreement between
#' the two measurement methods).
#'
#' A threshold is considered \strong{safe} (\eqn{\checkmark}) when it sits
#' at least \strong{3\eqn{\times}} the typical disagreement away from zero bias.
#' Below 2\eqn{\times} the threshold is inside the normal measurement-noise range
#' and will produce many false positives. Between 2\eqn{\times} and 3\eqn{\times} is
#' borderline and warrants a close look at the per-participant data.
#'
#' This function is \strong{advisory only}. It does not change any threshold
#' and its output is never fed back into the pipeline decision tree.
#'
#' @param data A data frame. Typically \code{corrected_ema_data} after
#'   \code{run_cleaning_chain()} or \code{run_pipeline()}.
#' @param cfg A pipeline configuration list (from \code{load_config()} or
#'   \code{yaml::read_yaml()}). If \code{NULL}, reads reasonable defaults
#'   from the current \code{pipeline_config} global.
#'
#' @return A data frame with one row per evaluated threshold. Columns:
#'   \code{threshold_name}, \code{value}, \code{loa_half_width},
#'   \code{ratio}, \code{assessment}. The object also carries a
#'   \code{summary} attribute with free-text interpretation and
#'   \code{bland_altman} attributes holding the raw BA result lists.
#'
#' @export
validate_thresholds <- function(data, cfg = NULL) {

  if (is.null(cfg)) {
    cfg <- get0("pipeline_config", envir = .GlobalEnv, ifnotfound = NULL)
  }

  # Fallback defaults matching the shipped config
  get_threshold <- function(key, default) {
    keys <- strsplit(key, "\\.")[[1]]
    val <- cfg
    for (k in keys) {
      if (is.list(val) && k %in% names(val)) val <- val[[k]] else return(default)
    }
    if (is.null(val)) default else val
  }

  thresholds <- list(
    list(name = "SOL excessive (error)",   value = get_threshold("classification.metric_validation.sol.excessive_minutes", 120),        unit = "min",   metric = "SOL"),
    list(name = "SOL high (severity)",     value = get_threshold("classification.flag_severity.high_sol_threshold_hours", 1) * 60,     unit = "min",   metric = "SOL"),
    list(name = "WASO high (severity)",    value = get_threshold("classification.flag_severity.high_waso_threshold_hours", 1.5) * 60,  unit = "min",   metric = "WASO"),
    list(name = "SE poor (severity)",      value = get_threshold("classification.flag_severity.poor_efficiency_threshold_pct", 70),    unit = "%",     metric = "SE"),
    list(name = "TST/TIB ratio min",       value = get_threshold("classification.metric_validation.tst_tib_ratio.min_ratio", 0.5),      unit = "ratio", metric = "ratio"),
    list(name = "TST/TIB ratio max",       value = get_threshold("classification.metric_validation.tst_tib_ratio.max_ratio", 1.0),      unit = "ratio", metric = "ratio")
  )

  # Run Bland-Altman for SOL and WASO (SE and ratio have no self-report pair)
  ba_sol  <- tryCatch(bland_altman(data,
    reported_col = "duration_totalmin_sol_estimate_am_mincalc",
    computed_col = "self_diffcalc_sol_minutes",
    label = "SOL"), error = function(e) NULL)

  ba_waso <- tryCatch(bland_altman(data,
    reported_col = "duration_totalmin_waso_estimate_am_mincalc",
    computed_col = "avg_waso_estimate_am_minutes",
    label = "WASO"), error = function(e) NULL)

  loa_map <- list(
    SOL   = if (!is.null(ba_sol))  (ba_sol$upper_loa  - ba_sol$lower_loa)  / 2 else NA_real_,
    WASO  = if (!is.null(ba_waso)) (ba_waso$upper_loa - ba_waso$lower_loa) / 2 else NA_real_
  )

  assess <- function(ratio) {
    if (is.na(ratio)) return("N/A -- no BA data")
    if (ratio >= 5)  return("CONSERVATIVE -- flags only extreme outliers")
    if (ratio >= 3)  return("SAFE -- well above measurement noise")
    if (ratio >= 2)  return("BORDERLINE -- close to normal disagreement range, review recommended")
    return("INSIDE NOISE -- threshold within typical measurement error")
  }

  rows <- lapply(thresholds, function(t) {
    hw <- loa_map[[t$metric]]
    if (is.null(hw)) hw <- NA_real_
    ratio <- if (!is.na(hw) && hw > 0) t$value / hw else NA_real_
    data.frame(
      threshold_name = t$name,
      value          = t$value,
      unit           = t$unit,
      loa_half_width  = if (t$metric %in% names(loa_map)) loa_map[[t$metric]] else NA_real_,
      ratio_to_noise = ratio,
      assessment     = assess(ratio),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  class(out) <- c("threshold_validation", "data.frame")

  attr(out, "summary") <- c(
    "Bland-Altman threshold validation summary",
    "--------------------------------------------------",
    if (!is.null(ba_sol))
      sprintf("SOL BA:  bias %+.1f min,  95%% LoA [%+.1f, %+.1f],  half-width %.1f min,  n = %d",
              ba_sol$bias, ba_sol$lower_loa, ba_sol$upper_loa,
              (ba_sol$upper_loa - ba_sol$lower_loa) / 2, ba_sol$n_pairs)
    else "SOL BA: not available",
    if (!is.null(ba_waso))
      sprintf("WASO BA: bias %+.1f min, 95%% LoA [%+.1f, %+.1f], half-width %.1f min, n = %d",
              ba_waso$bias, ba_waso$lower_loa, ba_waso$upper_loa,
              (ba_waso$upper_loa - ba_waso$lower_loa) / 2, ba_waso$n_pairs)
    else "WASO BA: not available",
    "--------------------------------------------------",
    "Rule: threshold / half-width >= 3 means safe (above measurement noise).",
    "SE and ratio thresholds have no self-report counterpart and are shown",
    "for completeness but cannot be validated by Bland-Altman alone."
  )
  attr(out, "bland_altman") <- list(sol = ba_sol, waso = ba_waso)

  out
}

#' Print a threshold validation report
#'
#' @param x A \code{threshold_validation} object from \code{validate_thresholds()}.
#' @param ... Unused.
#' @return \code{x}, invisibly.
#' @export
print.threshold_validation <- function(x, ...) {
  cat("\n=== Threshold Validation via Bland-Altman ===\n\n")
  sm <- attr(x, "summary")
  if (!is.null(sm)) for (line in sm) cat("  ", line, "\n")
  cat("\n")

  # Format as a readable table
  df <- as.data.frame(x)
  fmt_val <- function(v, u) {
    if (u == "ratio") sprintf("%.2f", v) else sprintf("%.0f", v)
  }
  df$value_fmt <- mapply(fmt_val, df$value, df$unit)
  df$loa_hw_fmt <- ifelse(is.na(df$loa_half_width), "--", sprintf("%.1f min", df$loa_half_width))
  df$ratio_fmt  <- ifelse(is.na(df$ratio_to_noise),  "--", sprintf("%.1fx", df$ratio_to_noise))

  cat(sprintf("  %-28s %7s %9s %7s   %s\n",
              "Threshold", "Value", "LoA HW", "Ratio", "Assessment"))
  cat(strrep("-", 95), "\n", sep = "")
  for (i in seq_len(nrow(df))) {
    cat(sprintf("  %-28s %4s %-3s %9s %7s   %s\n",
                df$threshold_name[i],
                df$value_fmt[i], df$unit[i],
                df$loa_hw_fmt[i],
                df$ratio_fmt[i],
                df$assessment[i]))
  }
  cat("\n")
  invisible(x)
}

#' Plot a threshold validation report
#'
#' Draws the Bland-Altman plots for SOL and WASO side by side, overlaid
#' with the configured threshold lines to show their position relative to
#' the measurement-noise envelope.
#'
#' @param x A \code{threshold_validation} object.
#' @param ... Unused.
#' @return The combined ggplot object, invisibly.
#' @export
plot.threshold_validation <- function(x, ...) {
  ba <- attr(x, "bland_altman")
  if (is.null(ba$sol) && is.null(ba$waso)) {
    message("No Bland-Altman data available to plot.")
    return(invisible(NULL))
  }

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    message("ggplot2 is required for plot.threshold_validation()")
    return(invisible(NULL))
  }
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    # Single plot fallback
    p <- ba$sol$plot
    if (!is.null(p)) print(p)
    return(invisible(p))
  }

  p1 <- if (!is.null(ba$sol)) ba$sol$plot + ggplot2::labs(title = "SOL") else NULL
  p2 <- if (!is.null(ba$waso)) ba$waso$plot + ggplot2::labs(title = "WASO") else NULL

  if (!is.null(p1) && !is.null(p2)) {
    combined <- p1 + p2 + patchwork::plot_annotation(
      title = "Threshold validation: Bland-Altman plots",
      subtitle = paste0("Thresholds (not shown on plot -- see print() for assessment) ",
                        "are validated against the LoA band width."),
      theme = ggplot2::theme_minimal(base_size = 11)
    )
    print(combined)
    invisible(combined)
  } else if (!is.null(p1)) {
    print(p1)
    invisible(p1)
  } else if (!is.null(p2)) {
    print(p2)
    invisible(p2)
  }
}

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
#'   timestamps — not from an objective device like actigraphy or PSG.
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
    warning("Fewer than 5 complete pairs — Bland-Altman may be unreliable.")
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

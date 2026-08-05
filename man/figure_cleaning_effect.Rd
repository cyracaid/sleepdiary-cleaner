% Hand-maintained. Deliberately omits the roxygen2 header so that
% devtools::document() skips this file instead of regenerating it --
% man/ in this package uses grouped, hand-written .Rd files.
\name{figure_cleaning_effect}
\alias{figure_cleaning_effect}
\title{Figure 2 --- Effect of cleaning (before vs after)}
\usage{
figure_cleaning_effect()
}
\value{
The combined \code{ggplot} object, invisibly. Called for its side effect of
writing \file{figures/Figure_2_Cleaning_Effect.png}.
}
\description{
Three-panel figure showing what cleaning actually changed.
}
\details{
The three panels are:
\describe{
  \item{A}{SOL before (self-reported) versus after (computed), drawn as a
    combined boxplot and violin.}
  \item{B}{TST distribution after cleaning, stacked by flag severity.}
  \item{C}{Individual record changes --- self-reported versus computed SOL,
    coloured by correction type (automatic, manual, unchanged). This panel
    is the one that shows only corrected observations moved.}
}

Takes no arguments. All data is extracted from \code{corrected_ema_data} in
the global environment, so the pipeline must have been run first ---
otherwise the function stops with an explanatory message.

Requires the \pkg{patchwork} package for the combined layout.
}
\seealso{
\code{\link{figure_pipeline_workflow}} for the companion flow diagram, and
\code{\link{run_pipeline}} to produce the required input.
}

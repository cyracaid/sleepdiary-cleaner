% Hand-maintained. Deliberately omits the roxygen2 header so that
% devtools::document() skips this file instead of regenerating it --
% man/ in this package uses grouped, hand-written .Rd files.
\name{figure_pipeline_workflow}
\alias{figure_pipeline_workflow}
\title{Figure 1 --- Pipeline workflow flow diagram}
\usage{
figure_pipeline_workflow()
}
\value{
The \code{ggplot} object, invisibly. Called for its side effect of
writing \file{figures/Figure_1_Pipeline_Workflow.png}.
}
\description{
Produces a publication-quality left-to-right flow diagram showing how raw
records move through automatic validation, algorithmic correction, manual
review, and into the final clean dataset. Every box carries a record count
and its percentage of the raw total.
}
\details{
Takes no arguments. All counts are extracted from \code{corrected_ema_data}
in the global environment, so the pipeline must have been run first ---
otherwise the function stops with an explanatory message.

The figure is written to \file{figures/Figure_1_Pipeline_Workflow.png} at
11 x 6.5 inches, 300 dpi, suitable for a manuscript Methods section.

Note that counts are reconstructed from the flag columns of the final
dataset, so they describe records that survived to the end of the pipeline.
}
\seealso{
\code{\link{figure_cleaning_effect}} for the companion before/after figure,
and \code{\link{run_pipeline}} to produce the required input.
}

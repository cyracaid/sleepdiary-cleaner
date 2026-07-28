\name{validate_schema}
\alias{validate_schema}
\title{Canonical input schema validator}
\usage{
validate_schema(data, config, label = "raw EMA input (post-adaptation)")
}
\arguments{
  \item{data}{A data frame to validate.}
  \item{config}{Pipeline configuration list.}
  \item{label}{Character label for error messages.}
}
\description{
  Single source of truth for raw input columns. Call right after
  \code{adapt_columns()} so missing or misnamed columns fail loudly.
}
\details{
  Design: each schema entry is a logical field resolved through the config
  column mapping. The validator accepts either the mapped internal key or the
  raw default name, tolerating the current config-key vs hardcoded-name
  mismatch.
}

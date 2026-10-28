# Is the review done, by the user's rule?

Counts the rows of a review status table in each state and compares the
number of \`needs_review\` rows with
\`review.done_when.max_needs_review\`. The answer depends only on the
table and the config.

## Usage

``` r
review_verdict(status = NULL, cfg = NULL)
```

## Arguments

- status:

  A review status table (as written to \`review_status.csv\`), or NULL
  for the last run's (from \[pipeline_results()\]).

- cfg:

  A configuration list, or NULL for the last run's config.

## Value

A list of class \`review_verdict\` with \`done\` (TRUE/FALSE),
\`counts\` (named integer: needs_review, not_incorporated,
incorporated), \`rule\` and \`manual_applied\` (NA when not known).

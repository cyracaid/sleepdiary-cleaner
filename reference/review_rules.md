# The review rules in force for a config

Reads the \`review:\` block of a config and fills any key the config
leaves out with the bundled default. Nothing else decides these values.

## Usage

``` r
review_rules(cfg = NULL)
```

## Arguments

- cfg:

  A configuration list from \[load_config()\], or NULL for the defaults.

## Value

A list with \`clean_categories\` (from \`review.clean_categories\`),
\`max_needs_review\`, \`step8_flags_need_review\`,
\`missing_times_ok_after_manual\`, \`fail_if_not_done\`, \`suggestions\`
and \`suggestion_default\`.

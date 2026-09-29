# Sync Human Review Status

Read manual_metric_review_acceptances.csv and auto-sync
review_resolution / resolved_at / resolved_by based on human review
traces

## Arguments

- csv_path:

  Path to CSV file

- overwrite:

  Whether to overwrite existing fields (default TRUE)

## Value

Updated data.frame (returned invisibly)

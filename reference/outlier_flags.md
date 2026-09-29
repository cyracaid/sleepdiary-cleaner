# Per-participant IQR outlier detection

Detects within-participant outliers on key sleep metrics using the
interquartile range (IQR) method. This complements (does not replace)
the hard-threshold system: hard thresholds catch implausible absolute
values, while IQR flags catch values that are unusual for that specific
participant.

## Details

[`flag_statistical_outliers`](https://cyracaid.github.io/sleepdiary-cleaner/reference/flag_statistical_outliers.md)
and
[`summarise_outliers`](https://cyracaid.github.io/sleepdiary-cleaner/reference/summarise_outliers.md)
are documented individually.

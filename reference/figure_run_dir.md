# Resolve the figure output directory for a run

Builds the run-specific visualization directory name:
`<root>/latest_visualization_<tag>_n<records>`. The base root comes from
config (`output.figure.root_dir` for real data,
`output.figure.synth_root_dir` for synthetic/test AND unresolved data).
Only a data_tag that has been positively confirmed as `"real"` is
trusted with the `output/` root – `"synth"` and `"unknown"` both stay
outside `output/` by default. This is a fail-closed choice: `"unknown"`
means the tag detector could not read `data.files.main` from the config
(see `sleep_visualization.R`), i.e. we genuinely do not know what was
loaded. Routing it next to confirmed real-data figures would silently
extend real-data trust (gitignored, "never leaves the study team"
handling) to data whose identity is unverified. Before 2026-08-11,
"unknown" fell into the `else` branch and was treated exactly like
"real"; that has been fixed so only "real" gets the privileged path.

## Usage

``` r
figure_run_dir(cfg = NULL, data_tag, n_records = NULL)
```

## Arguments

- cfg:

  Optional. Pipeline configuration list (preferred; falls back to the
  global environment when omitted).

- data_tag:

  Character. "real", "synth", or "unknown".

- n_records:

  Numeric or NULL. Row count appended to the directory name.

## Value

Character. Relative path to the figure output directory.

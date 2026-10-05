<div id="main" class="col-md-9" role="main">

# Package index

<div class="section level2">

## All functions

</div>

<div class="section level2">

-   `STANDARD_LEVELS` : Fixed category vocabularies for the ledger
-   `adapt_columns()` : Apply column mapping to a data frame
-   `as.data.frame(<sleep_diary>)` : Extract the working data frame from
    a sleep\_diary
-   `as_sleep_diary()` : Coerce a data frame into a sleep\_diary
-   `assert_contract_columns()` : Assert that a sleep\_diary carries the
    public contract columns
-   `bland_altman()` : Bland-Altman analysis and threshold validation
-   `cfg_get()` : Safe config\_get – fetches pipeline\_config from
    global env automatically
-   `clean_sleep_diary()` : Clean a sleep diary: data-first entry point
-   `cleaning_chain` : Pipeline step adapters and the cleaning chain
-   `dim(<sleep_diary>)` : Dimensions of a sleep\_diary
-   `.step_ledger_env` : Per-step flag ledger (log\_step)
-   `eval_checkforerrors()` : Evaluate checkforerrors (auto-detection
    flags)
-   `eval_data_category()` : Evaluate data\_category (temporal
    classification)
-   `eval_duration_extreme()` : Evaluate duration\_extreme (separate
    from severity count)
-   `eval_field_misentry()` : Evaluate field\_misentry
    (cross-participant field misentry, Step 1.5)
-   `eval_flag_severity()` : Evaluate flag\_severity (computed metric
    flags)
-   `evaluate_all_standards()` : Evaluate ALL standards, returning
    per-record label data frame.
-   `figure12_step_flag_table()` : Figure 12 (new) — Step x Flag ledger
    table
-   `figure_cleaning_effect()` : Figure 2 — Effect of cleaning (before
    vs after)
-   `figure_pipeline_workflow()` : Figure 1 — Pipeline workflow flow
    diagram
-   `figure_run_dir()` : Resolve the figure output directory for a run
-   `finalize_columns()` : Build the analysis-facing datasets from the
    full pipeline output
-   `flag_statistical_outliers()` : Per-participant statistical outlier
    detection via IQR
-   `get_step_ledger_long()` : Flatten the ledger into a long data frame
-   `get_step_ledger_wide()` : Wide ledger for one standard
-   `guess_column_mapping()` : Guess column mapping from raw column
    names
-   `handle_missing()` : Tag missing-data reason codes and optionally
    carry forward single-day gaps
-   `init_step_ledger()` : Start a fresh ledger (call once at the top of
    run\_pipeline).
-   `is_sleep_diary()` : Test whether an object is a sleep\_diary
-   `load_config()` : Load pipeline configuration
-   `log_step()` : Record the flag state after a step.
-   `missing_handler` : Missing-data reason codes and single-day LOCF
-   `new_sleep_diary()` : Construct a sleep\_diary object
-   `outlier_flags` : Per-participant IQR outlier detection
-   `pipeline_steps` : Pipeline step adapters (wrapper layer)
-   `plot(<bland_altman>)` : Plot a Bland-Altman result
-   `plot(<sleep_diary>)` : Plot the state of a sleep\_diary
-   `plot(<threshold_validation>)` : Plot a threshold validation report
-   `print(<bland_altman>)` : Print a Bland-Altman summary
-   `print(<sleep_diary>)` : One-line status of a sleep\_diary
-   `print(<summary.sleep_diary>)` : Print a sleep\_diary summary
-   `print(<threshold_validation>)` : Print a threshold validation
    report
-   `run_cleaning_chain()` : The S3 cleaning chain
-   `run_figure_index()` : Regenerate the figure\_index.png contact
    sheet
-   `run_pipeline()` : Run the full SPL Sleep pipeline
-   `run_report()` : Run the reporting stage
-   `run_setup()` : Run the setup-only stage (package / input-file
    checks)
-   `run_synthetic_demo()` : Run the complete pipeline on bundled
    synthetic demo data
-   `run_visualization()` : Run only the visualization stage on
    already-cleaned data
-   `sleep_diary` : The sleep\_diary S3 class
-   `step_apply_corrections()` : Step 6 – apply manual corrections
-   `step_apply_duration_corrections()` : Step 6.5 – apply duration
    corrections
-   `step_compute_metrics()` : Step 7 – compute derived sleep metrics
-   `step_normalize_sequence()` : Step 4 – normalise sleep time sequence
-   `step_process_intervals()` : Step 3 – parse interval durations
-   `step_process_timestamps()` : Step 2 – parse timestamps
-   `summarise_missing()` : Summarise missing-data patterns per
    participant
-   `summarise_outliers()` : Summarise IQR outlier flags
-   `summary(<sleep_diary>)` : Tabulate the whole pipeline chain
    recorded in a sleep\_diary
-   `sync_human_review_status` : Sync Human Review Status
-   `tally_standard()` : Tally one standard's labels into a fixed-level
    count vector. Returns all-NA (named by levels) if the label vector
    is entirely NA.
-   `validate_column_types()` : Validate column types in a data frame
-   `validate_columns()` : Validate that required columns exist
-   `validate_no_r_code_in_paths()` : Validate config file paths for R
    code expressions
-   `validate_schema()` : Canonical input schema validator
-   `validate_sleep_diary()` : Validate a sleep\_diary object
-   `validate_thresholds()` : Validate cleaning thresholds against
    Bland-Altman agreement limits
-   `write_step_ledger()` : Persist the ledger to CSV (long form)

</div>

</div>

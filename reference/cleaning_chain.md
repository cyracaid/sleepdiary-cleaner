<div id="main" class="col-md-9" role="main">

# Pipeline step adapters and the cleaning chain

<div class="ref-description section level2">

The step adapters wrap the v1.2.0 pipeline scripts without changing
their logic, adding timing, column-diff tracking and ledger logging.
`run_cleaning_chain()` composes them into a single callable chain.

</div>

<div class="section level2">

## Details

Each adapter is documented individually: `run_cleaning_chain`,
`assert_contract_columns`, `step_process_timestamps`,
`step_process_intervals`, `step_normalize_sequence`,
`step_apply_corrections`, `step_apply_duration_corrections`,
`step_compute_metrics`.

</div>

</div>

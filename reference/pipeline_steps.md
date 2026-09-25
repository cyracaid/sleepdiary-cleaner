<div id="main" class="col-md-9" role="main">

# Pipeline step adapters (wrapper layer)

<div class="ref-description section level2">

Every function here wraps ONE existing pipeline script from `v1.2.0`
without changing a line of its logic. The adapter is responsible only
for: 1. unboxing the data frame from the incoming `sleep_diary`, 2.
calling the unchanged script function, 3. timing the call and diffing
rows/columns, 4. calling `log_step()` so the flag ledger stays identical
to v1.2.0, 5. boxing the result back into a `sleep_diary`.

</div>

<div class="section level2">

## Details

This is the "wrapper-first" half of the v1.3.0 S3 migration. Once
snapshot tests pin each step's output, the bodies can be internalised
one at a time without the caller ever noticing.

</div>

</div>

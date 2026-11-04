# cross_protocol — how far the thresholds travel

The pipeline's defaults were set on healthy young adults on one protocol
(`THRESHOLDS.md`). Clinical, older-adult and shift-work diaries have different
distributions, so the same threshold flags a different share of nights. This
directory is for measuring that, one population at a time.

## What is here

| File | What it does |
|---|---|
| `sweep_thresholds.R` | given a vector of nightly values, reports the share flagged at each threshold in the range the pipeline uses |
| `params.csv` | the published distribution parameters for each population — **empty on purpose** |
| `results/sweep_*.csv` | the sweep outputs |

## Status: the machinery is ready, the parameters are not

`params.csv` has a row per population and parameter, with `value` and `source`
both blank. **The sweeps cannot describe another population until those are
filled from sources you can cite.** That is deliberate: a parameter chosen from
memory would make the output look like a finding about insomnia when it is
really a finding about the person typing.

To fill one row: find a published sleep-diary table (mean and SD of SOL, or of
sleep efficiency, in the population), put the values in `params.csv` with the
paper and table number in `source`, then build the distribution and sweep it.

## What has been run so far

Only the study's own sample, as a **method demonstration**, not a clinical
result:

| Metric | n | Threshold | Share of this sample flagged |
|---|---|---|---|
| SOL (min) | 2,850 | > 30 | 26.0% |
| | | > 60 | 10.6% |
| | | > 120 (pipeline default for "excessive") | 2.2% |
| Sleep efficiency (%) | 1,730 | < 85 | 2.7% |
| | | < 70 (pipeline default for "poor") | 0.5% |
| TST (min) | 1,730 | < 360 (short sleep) | 8.1% |

The first row is the point: the clinical marker for SOL (30 min) would flag a
quarter of a healthy sample, so "long SOL" cannot mean the same thing in both
populations. This is why `THRESHOLDS.md` says the defaults are study-specific.

## What this cannot do

- It cannot tell you whether a night is an **error** — only how often a threshold
  fires. Error detection needs the injected benchmark (`validation/synthetic/`).
- It does not run the pipeline. It applies the same numeric rule the pipeline
  applies, to a vector of values.
- It says nothing about a population whose parameters are not in `params.csv`.

## Planned (not started)

Add the insomnia, older-adult and shift-work parameter rows with citations, then
report, per population, the share of nights each default threshold would flag
and the threshold that would restore the study's flag rate.

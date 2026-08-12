# Data Dictionary Validation Prompt

You are auditing the output column schema for an R pipeline that cleans sleep EMA diary data. 

## Research Context

The study investigates **sleep-emotional dynamics**. The most valuable signal is **discrepancy** — the gap between what participants self-report and what the pipeline computes from their raw timestamps. Specifically:

1. **Sleep onset timing discrepancies**: when the participant says "I fell asleep at X" but the diary timestamps suggest Y
2. **Duration perception discrepancies**: the participant estimates SOL took 30 min, but computed SOL from timestamps says 15 min
3. **Nap discrepancies**: the participant reports a nap but the timestamps don't align
4. **WASO perception**: how many times they think they woke up vs. what the timestamps imply

The pipeline takes raw EMA diary responses (bedtime, sleep time, awake time, get-up time as HH:MM + AM/PM strings, plus self-reported SOL/WASO/nap/exercise durations) and runs them through 9 processing steps that parse, validate, correct, classify and compute metrics.

## The Data Dictionary

Read this file: `/Users/sloblucyra/Documents/opencode/proj_splclean/manual_inputs/data_dictionary.md`

It defines:
- **Dataset A** (`cleaned_data_final`): 36 columns. Analysis-ready. Short clean column names. Post-correction values + self-report estimates.
- **Dataset B** (`cleaned_data_prepostcorrection`): 13 columns. Timestamp pre/post pairs for correction traceability.
- **Full** (`cleaned_data_full`): Everything else. Debug and audit. Not for analysis.

## Your Task

Validate the data dictionary against the research goals. Answer these questions:

### 1. Completeness — can every analysis be done?

For each of the following analyses a sleep-emotion researcher would run, confirm whether Dataset A has the necessary columns. If not, state exactly what's missing.

a) "Does self-reported SOL match computed SOL?"  
b) "Does self-reported WASO match computed WASO?"  
c) "How much did algorithmic corrections shift bedtime / sleep onset / awakening / get-up times?"  
d) "Do nap reports correlate with sleep quality metrics?"  
e) "Do substance use counts correlate with sleep disruption?"  
f) "Did exercise intensity affect sleep onset latency?"  
g) "Were some records algorithmically corrected vs manually corrected?"  
h) "Which records have unresolved quality issues?"  
i) "Can I track an individual participant's sleep across study days?"  
j) "Can I plot data on a real calendar timeline?"  

### 2. Naming — will a researcher understand the columns at first sight?

For each of these source columns that exist in the pipeline, state its new name in Dataset A. If the new name is unclear or ambiguous, flag it.

- `duration_totalmin_sol_estimate_am_mincalc`  
- `duration_totalmin_waso_estimate_am_mincalc`  
- `num_waso_estimate_am`  
- `self_diffcalc_sol_minutes`  
- `self_diffcalc_totalsleeptime_minutes`  
- `time_bed_corrected`  
- `self_diffcalc_sleeponset`  
- `has_correction`  

### 3. Redundancy — are there duplicate columns?

- Are `tst_minutes`, `sleep_duration_h`, and `self_diffcalc_totalsleeptime_minutes` the same thing? If so, does only one appear in A?
- Are `sol_minutes` and `sol_h` the same?  
- Are there any other duplicate pairs in A?

### 4. Missing — what should be in A but isn't?

Based on the research goals of sleep-emotional dynamics, are there any pipeline columns that should be promoted from Full to A, or that are entirely absent from both dictionaries?

### 5. Structural — can A and B be used together?

- If a researcher loads both A and B, can they join them? On what keys?
- Is there any information that requires loading B AND Full simultaneously to extract?

### Output format

```
## Summary verdict: [PASS / FAIL] — Dataset A is [adequate / incomplete / wrong] for sleep-emotion research

### Issue 1: ...
### Issue 2: ...
...
```

Be specific. Reference exact column names and row numbers from the data dictionary.

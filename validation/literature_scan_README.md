# Literature scan: how do sleep-diary studies report cleaning of the diary times?

Purpose: support (or refute) the sentence "current practice is manual or ad hoc and
leaves no record of what changed". It is not supported yet.

`literature_scan_candidates.csv` holds 80 open-access PubMed records (2022 to 2026) found
with this query, run 2026-10-11:

```
("sleep diary"[tiab] OR "daily diary"[tiab] OR "ecological momentary assessment"[tiab])
AND sleep[tiab] AND (bedtime[tiab] OR "wake time"[tiab] OR "sleep onset latency"[tiab]
OR "sleep latency"[tiab] OR "time in bed"[tiab]) AND ("2022/01/01"[dp] : "2026/12/31"[dp])
AND "free full text"[filter] AND humans[mh]
```

142 records matched; the 80 most recent are listed. `pre_screen` marks titles that look
like reviews, protocols or trials; check them anyway.

## How to code

1. Two coders, working alone, each fill their own copy of the CSV.
2. **Include** a paper if it analyzes self-reported bedtime, wake time or sleep latency
   collected at least daily for at least 7 days; stop when 30 papers are included.
3. For each included paper, read the Methods (and any supplement) and record:
   - `times_collected_how`: typed clock times, pickers or sliders, wearable, other;
   - `cleaning_reported`: `none`, `exclusion_only` (entries dropped by a rule) or
     `correction` (entries changed);
   - `rule_stated`: the rule, in a few words;
   - `who_performed`: the person or the software;
   - `n_changed_or_excluded_given`: yes or no;
   - `code_or_log_shared`: yes or no.
4. Report the share of papers in each category with an exact interval, and the agreement
   between coders (Cohen's kappa on `cleaning_reported`).

## Limits

The list is a convenience sample of recent open-access papers matching one query, not a
systematic review, and papers that do not use "ecological momentary assessment", "sleep
diary" or "daily diary" are missed. State that where the result is used.

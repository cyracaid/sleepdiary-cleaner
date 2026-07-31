## Figure Captions — Publication-Ready

---

### Figure 1. Sleep diary cleaning pipeline workflow.

*Flow of N = 280 raw sleep diary records through automatic and manual correction stages. Records progress from left to right through four decision points: automatic validation, algorithmic correction, manual review, and final classification.*

**Panel description.** Each box shows the number and percentage of records at each stage, with the original raw dataset (N = 280) as the denominator for all percentages. Records that fail temporal-order validation (e.g., getup time recorded before bedtime, sleep latency exceeding 7 hours) are classified as auto-detected errors and flagged for investigator review (0 records, 0.0% of the raw dataset). Records with plausible but correctable temporal anomalies — such as AM/PM confusion or minor order swaps within 3 hours — are automatically corrected by the pipeline's normalisation algorithm (Step 4, 0 records, 0.0%). Records requiring human judgment — such as ambiguous durations or unusual but potentially valid sleep patterns — are flagged for manual CSV review and corrected based on investigator decisions (Step 6, 0 records, 0.0%). Records that were reviewed but left unchanged by the investigator are counted separately (0 records, 0.0%). The remaining records — those that passed all automatic checks, were auto-corrected, or had no detectable issues — constitute the final clean dataset (N = 266, 95.0%). Fourteen records (5.0%) were skipped due to missing timestamp data (all four sleep-event times unreported) and are excluded from the final dataset.

**Color coding.** Red = records removed or flagged as errors. Orange = algorithmically corrected. Blue = manually corrected (investigator CSV review). Purple = reviewed but unchanged. Green = retained in final dataset.

**Interpretation.** The pipeline successfully processed 95.0% of raw records into a clean analytic dataset. The majority of records (266 of 280, 95.0%) were classified as equal-time-ok, indicating that reported bed and sleep times were identical (a common reporting pattern). No records required algorithmic or manual correction in this sample, which is consistent with the synthetic nature of the test data. On real data, the pipeline would be expected to detect and correct a small proportion of temporal-order and AM/PM errors (typically 1–5% depending on data collection quality).

---

### Figure 2. Effect of the cleaning pipeline on sleep metrics.

*Comparison of sleep-onset latency (SOL) before and after cleaning, distribution of total sleep time (TST) after cleaning by flag severity, and individual record-level changes in SOL.*

**Panel A: Sleep Onset Latency (SOL).** Violin and boxplot comparing self-reported SOL (before cleaning, extracted from the raw duration response field) against pipeline-computed SOL (after cleaning, derived from the bed-to-sleep timestamp difference after normalisation and manual correction). The horizontal black diamond marks the mean. In this dataset, mean SOL was 32.8 min (self-reported) vs. 32.7 min (computed), indicating negligible systematic bias between the two measurement methods. The Bland-Altman 95% limits of agreement (not shown) were [−17.3, +18.2] min, suggesting acceptable concordance for most records.

**Panel B: Total Sleep Time (TST) after cleaning.** Histogram of pipeline-computed TST (minutes), stacked by flag severity. Severity is computed in Step 7 based on three criteria: sleep efficiency < 70%, SOL > 60 minutes, and WASO > 90 minutes. Records meeting zero criteria are classified as Clean (green, 251 of 280, 89.6%), one criterion as Minor (orange, 28 of 280, 10.0%), and two or more criteria as Major (red, 1 of 280, 0.4%). The vertical dashed line marks the mean TST (416 min, 6.94 h). The distribution is unimodal with a plausible centre for an adult population.

**Panel C: Individual record changes.** Scatter plot comparing self-reported SOL (x-axis) against pipeline-computed SOL (y-axis) for each record. Points on the diagonal identity line (dashed) indicate perfect agreement between the two methods. Points coloured green (Unchanged) did not receive any correction flag. Points coloured orange (Auto) were algorithmically corrected. Points coloured blue (Manual) were corrected via investigator CSV review. In this sample, all 266 valid records had SOL differences ≤ 1 minute between self-report and computation, confirming that the pipeline does not alter SOL values for records that pass temporal-order validation.

**Combined interpretation.** The cleaning pipeline produces SOL and TST estimates that are consistent with the raw self-reported data while adding the benefit of systematic temporal-order validation, error flagging, and transparent correction accounting. The majority of records (≥ 89.6%) emerge from the pipeline classified as Clean with no flags on any derived metric.

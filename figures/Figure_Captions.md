## Figure Captions — Publication-Ready

---

### Figure 1. Sleep diary cleaning pipeline workflow.

*Flow of N = 280 raw sleep diary records through automatic correction, automatic validation, and manual review, into the final clean dataset. Records progress left to right through four processing stages; outcome boxes below each stage show where records were directed.*

**Panel description.** The figure is a left-to-right flow diagram with five columns. **Column 1 (Raw Records)** shows the total number of sleep diary records entering the pipeline. **Column 2 (Automatic Correction, Step 4)** applies algorithmic fixes to records with correctable temporal anomalies — AM/PM confusion (e.g., a bedtime recorded 12 h off) and minor order swaps within 3 hours. The branch box below ("Auto-Corrected", orange) counts records the algorithm fixed automatically without human input (0 records, 0.0%). **Column 3 (Automatic Validation, Step 5)** classifies every record against temporal plausibility thresholds. Records that fail validation are *flagged, not removed*: "Errors Flagged" (red, 0 records, 0.0%) are temporally impossible (e.g., getup time before bedtime, sleep latency exceeding 7 h); "Unusual Flagged" (purple, 0 records, 0.0%) are plausible but suspicious. **Column 4 (Manual Review, Step 6)** routes flagged records to investigator review via CSV. "Manually Corrected" (blue, 0 records, 0.0%) were fixed based on investigator decisions; "Reviewed, Unchanged" (purple, 0 records, 0.0%) were examined and accepted as valid without modification. **Column 5 (Final Clean Dataset, green)** contains records that passed all checks, were auto-corrected, or had no detectable issues (N = 266, 95.0%). Fourteen records (5.0%) were excluded because all four sleep-event timestamps were missing (skipped_na).

**Distinction between the two "error" boxes.** "Auto-Detected Errors Flagged" (Column 3, red) and "Algorithmically Corrected" (Column 2, orange) are different outcomes. Algorithmically corrected records were *fixed automatically* by Step 4 — the algorithm repaired the timestamp and the record became clean without human involvement. Auto-detected errors were *flagged but not fixed* — Step 5 identified the record as temporally impossible and routed it to human review, where an investigator decides whether to correct, accept, or exclude it. The distinction matters for the audit trail: algorithmic fixes are fully reproducible and require no human time; flagged errors consume reviewer time and may carry investigator judgment.

**Color coding.** Gray = processing stage. Red = errors flagged for review (not auto-fixed). Orange = algorithmically corrected (Step 4). Blue = manually corrected (investigator CSV review). Purple = unusual or reviewed-but-unchanged. Green = retained in final dataset.

**Interpretation.** The pipeline processed 95.0% of raw records into a clean analytic dataset, with 5.0% excluded for missing timestamps. In this sample no records required algorithmic or manual correction, consistent with the well-formed synthetic test data. On real data, 1–5% of records are typically expected to require algorithmic correction (AM/PM, order) and a smaller fraction to require manual review.

---

### Figure 2. Effect of the cleaning pipeline on sleep metrics.

*Comparison of sleep-onset latency (SOL) before and after cleaning, distribution of total sleep time (TST) after cleaning by flag severity, and individual record-level changes in SOL.*

**Panel A: Sleep Onset Latency (SOL).** Violin and boxplot comparing self-reported SOL (before cleaning, extracted from the raw duration response field) against pipeline-computed SOL (after cleaning, derived from the bed-to-sleep timestamp difference after normalisation and manual correction). The horizontal black diamond marks the mean. In this dataset, mean SOL was 32.8 min (self-reported) vs. 32.7 min (computed), indicating negligible systematic bias between the two measurement methods. The Bland-Altman 95% limits of agreement (not shown) were [−17.3, +18.2] min, suggesting acceptable concordance for most records.

**Panel B: Total Sleep Time (TST) after cleaning.** Histogram of pipeline-computed TST (minutes), stacked by flag severity. Severity is computed in Step 7 based on three criteria: sleep efficiency < 70%, SOL > 60 minutes, and WASO > 90 minutes. Records meeting zero criteria are classified as Clean (green, 251 of 280, 89.6%), one criterion as Minor (orange, 28 of 280, 10.0%), and two or more criteria as Major (red, 1 of 280, 0.4%). The vertical dashed line marks the mean TST (416 min, 6.94 h). The distribution is unimodal with a plausible centre for an adult population.

**Panel C: Individual record changes.** Scatter plot comparing self-reported SOL (x-axis) against pipeline-computed SOL (y-axis) for each record. Points on the diagonal identity line (dashed) indicate perfect agreement between the two methods. Points coloured green (Unchanged) did not receive any correction flag. Points coloured orange (Auto) were algorithmically corrected. Points coloured blue (Manual) were corrected via investigator CSV review. In this sample, all 266 valid records had SOL differences ≤ 1 minute between self-report and computation, confirming that the pipeline does not alter SOL values for records that pass temporal-order validation.

**Combined interpretation.** The cleaning pipeline produces SOL and TST estimates that are consistent with the raw self-reported data while adding the benefit of systematic temporal-order validation, error flagging, and transparent correction accounting. The majority of records (≥ 89.6%) emerge from the pipeline classified as Clean with no flags on any derived metric.

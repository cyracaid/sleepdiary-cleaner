## Reading the Figures — Start Here

The pipeline generates ~27 figures. **You do not need to read all of them.** Use the
three-figure triage below to judge data quality in under a minute, then drill down only
if something looks off.

### ⏱️ 60-second quality check (look at these 3 first)

| # | Figure | The question it answers |
|---|--------|-------------------------|
| 1 | `pipeline_cleaning/01_Final_Data_Quality_Dashboard.png` | **Is my data usable?** Share of records that are clean vs. flagged *after* all corrections. |
| 2 | `pipeline_cleaning/12_Pipeline_Correction_Progress.png` | **Did cleaning actually work?** Per-step metrics across all 8 pipeline steps (convergence). |
| 3 | `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png` | **Who should I exclude?** Per-participant flag rate — spot participants with systematically bad data. |

If all three look reasonable (low residual flag rate, counts converged, no participant
dominating the flags), the dataset is ready. Otherwise, use Tier 2 below to diagnose.

---

### Tier 2 — Diagnose *what / where / who* went wrong (`pipeline_cleaning/`)

| Figure | What decision it informs |
|--------|--------------------------|
| `13_Error_Category_Distribution.png` | Which error types dominate (timestamp / duration / metric). |
| `07_Flag_Composition_Stacked.png` | How data quality varies across sleep-duration ranges. |
| `11_Flag_Cooccurrence_Heatmap.png` | Which quality issues tend to co-occur (root-cause clustering). |
| `16_Common_Error_Patterns.png` | The most frequent specific error patterns to prioritize fixing. |
| `15_Error_Timeline.png` | *When* errors cluster over the study period (device/protocol signal). |
| `17_Top_Participants_Flags.png` | Top 15 participants by auto-detected flags. |
| `18_Auto_Detected_Dashboard.png` | Split of auto-flagged records: still-to-review vs. already-corrected. |
| `19_Unified_Quality_Status.png` | Final unified status (incl. self-reported SOL/WASO anomalies). |
| `06_Sleep_Duration_Post_Correction.png` | Sleep-duration distribution before vs. after manual correction. |
| `14_Sleep_Duration_Pre_Correction.png` | Pre-correction (algorithm-only) distribution, for comparison. |
| `08_Sleep_Duration_by_Category.png` | Sleep duration across clean / unusual / error categories. |
| `10_Extreme_Sleep_Duration.png` | Extreme durations with efficiency context — outlier hunting. |

### Tier 3 — Research outputs (use *after* you trust the data — `research_ready/`)

| Figure | Content |
|--------|---------|
| `02_Distribution_Sleep_Variables.png` | Distributions of key sleep variables. |
| `03_Sleep_Duration_Distribution.png` | Total Sleep Time (TST) distribution. |
| `04_Sleep_Duration_vs_Time_in_Bed.png` | TST vs. Time in Bed (with correlation). |
| `04B_SOL_vs_Sleep_Duration.png` | Sleep-onset latency vs. TST. |
| `09_Bedtime_vs_Getup_Distribution.png` | Circadian timing pattern. |
| `R25_Sleep_Regularity_Weekday_Weekend.png` | Weekday vs. weekend regularity. |
| `R26_Sleep_Composition_TIB_Breakdown.png` | Time-in-bed composition breakdown. |
| `20_SOL_Perception_Bias.png` | Subjective vs. objective SOL bias. |
| `20B_WASO_Perception_Bias.png` | Subjective vs. objective WASO bias. |
| `21_Substance_Use_Availability.png` | Substance-use data availability (non-NA coverage). |
| `22_Substance_Use_Distribution.png` | Substance-use value distributions. |
| `23_Caffeine_Consumption.png` | Caffeine consumption. |
| `24_Alcohol_Consumption.png` | Alcohol consumption. |

> Tip: run `Rscript make_figure_index.R` to generate a single contact-sheet
> (`latest_visualization/figure_index.png`) that thumbnails every figure with its caption
> — handy for scanning all outputs at a glance.

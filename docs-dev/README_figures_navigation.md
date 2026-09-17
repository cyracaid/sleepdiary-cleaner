## Reading the Figures — Start Here

The pipeline generates 29 figures (13 QC + 16 research). **You do not need to read all of them.** Use the
three-figure triage below to judge data quality in under a minute, then drill down only
if something looks off.

### ⏱️ 60-second quality check (look at these 3 first)

| # | Figure | The question it answers |
|---|--------|-------------------------|
| 1 | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | **Is my data usable?** How records moved through cleaning, and the final Clean / Unusual / Error / Equal-Time breakdown. |
| 2 | `pipeline_cleaning/A1_Step_Flag_Ledger.png` | **Did cleaning actually work?** Per-step flag counts and convergence (merges former Fig 12). |
| 3 | `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png` | **Who's worth a second look?** Ranked table of the participants with the highest flagged-record rate. A high rate flags records worth checking by hand -- it is not a verdict that the data is wrong. |

If all three look reasonable (low residual flag rate, counts converged, no participant
dominating the flags), the dataset is ready. Otherwise, use Tier 2 below to diagnose.

---

### Tier 2 — Diagnose *what / where / who* went wrong (`pipeline_cleaning/`)

| Figure | What decision it informs |
|--------|--------------------------|
| `13_Error_Category_Distribution.png` | Which error types dominate (timestamp / duration / metric); includes final-status split (former Fig 19). |
| `07_Flag_Composition_Stacked.png` | How data quality varies across sleep-duration ranges. |
| `11_Flag_Cooccurrence_Heatmap.png` | Which quality issues tend to co-occur (root-cause clustering). |
| `16_Common_Error_Patterns.png` | The most frequent specific error patterns to prioritize fixing. |
| `15_Error_Timeline.png` | *When* flagged temporal patterns (timestamp-order, awake/getup/bed-sleep) occur over the study period (device/protocol signal). Most flagged records were reviewed and kept unchanged, not corrected. |
| `17_Top_Participants_Flags.png` | Top 15 participants by auto-detected flag *rate* (flags / that participant's own observed days). |
| `18_Auto_Detected_Dashboard.png` | Split of auto-flagged records: still-to-review vs. already-corrected. |
| `06_Sleep_Duration_Post_Correction.png` | Sleep-duration distribution before vs. after manual correction. |
| `14_Sleep_Duration_Pre_Correction.png` | Pre-correction (algorithm-only) distribution, for comparison. |
| `10_Extreme_Sleep_Duration.png` | Extreme durations with efficiency context — outlier hunting. |

### Tier 3 — Research outputs (use *after* you trust the data — `research_ready/`)

| Figure | Content |
|--------|---------|
| `02_Correction_Impact.png` | Before/after correction impact (delta lollipops + identity scatter). |
| `02B_Distribution_Sleep_Variables.png` | Distributions of key sleep variables. |
| `03_Sleep_Duration_Distribution.png` | Total Sleep Time (TST) distribution. |
| `04_Sleep_Duration_vs_Time_in_Bed.png` | TST vs. Time in Bed (with correlation). |
| `04B_SOL_vs_Sleep_Duration.png` | Sleep-onset latency vs. TST. |
| `09_Bedtime_vs_Getup_Distribution.png` | Circadian timing pattern. |
| `R25_Sleep_Regularity_Weekday_Weekend.png` | Weekday vs. weekend regularity. |
| `R26_Sleep_Composition_TIB_Breakdown.png` | Time-in-bed composition breakdown. |
| `R27_Sleep_Metrics_Correlation_Matrix.png` | Pairwise correlations among sleep metrics. |
| `20_SOL_Perception_Bias.png` | Subjective vs. objective SOL bias. |
| `20B_WASO_Perception_Bias.png` | Subjective vs. objective WASO bias. |
| `21_Substance_Use_Availability.png` | Substance-use data availability (non-NA coverage). |
| `22_Substance_Use_Distribution.png` | Substance-use value distributions. |
| `23_Caffeine_Consumption.png` | Caffeine consumption. |
| `24_Alcohol_Consumption.png` | Alcohol consumption. |

> Tip: run `Rscript make_figure_index.R` to generate a single contact-sheet
> (`latest_visualization/figure_index.png`) that thumbnails every figure with its caption
> — handy for scanning all outputs at a glance.

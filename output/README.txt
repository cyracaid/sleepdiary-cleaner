SLEEP DATA ANALYSIS EXPORT
==========================
Generated: 2026-02-08 19:28:13.201142

DIRECTORY STRUCTURE:
  sleep_analysis_export/
  ├── plots_png/      - All plots in PNG format (high resolution)
  ├── plots_pdf/      - All plots in PDF format (vector graphics)
  ├── data/           - All data tables in CSV format
  └── reports/        - Summary reports and analysis

CONTENTS:

PLOTS:
  - plot_unusual_type
  - plot_suspicious_conditions
  - plot_unusual_time_diffs
  - plot_latency_comparison
  - plot_top_participants
  - plot_error_type
  - plot_failed_conditions

DATA TABLES:
  - sleep_time_clean_df (1879 rows, 15 columns)
  - sleep_time_equal_time_df (885 rows, 22 columns)
  - sleep_time_error_df (47 rows, 24 columns)
  - sleep_time_full_data (13990 rows, 96 columns)
  - sleep_time_summary_df (1 rows, 13 columns)
  - sleep_time_unusual_df (37 rows, 19 columns)

REPORTS:
  - sleep_analysis_report.html - Comprehensive HTML report
  - summary_statistics.csv     - Overall summary
  - unusual_summary.csv        - Detailed unusual records analysis
  - unusual_by_participant.csv - Participant-level unusual analysis
  - error_summary.csv          - Error records summary
  - error_by_type.csv          - Error analysis by type

NEXT STEPS:
1. Review the HTML report for overview
2. Examine unusual records in data/unusual_records_detailed.csv
3. Check specific participants with multiple issues
4. Validate extreme values against original data

CONTACT:
For questions about this analysis, contact the data analysis team.


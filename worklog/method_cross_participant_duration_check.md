# Methods Fragment: Cross-Participant Duration Consistency Check

## Purpose
After per-row auto-detection of data-entry errors, a cross-participant consistency check was applied to identify duration values that deviate dramatically from each participant's own typical range — patterns invisible when examining rows in isolation.

## Metrics Checked
Eight duration metrics were examined across all available days per participant:
- Subjective Sleep Onset Latency (SOL), minutes
- Wake After Sleep Onset (WASO), minutes
- Nap duration, minutes
- Exercise duration (Light, Moderate, Vigorous, Strength), minutes

## Method

### Personal baseline estimation
For each participant with ≥3 days of non-missing data in a given metric, a personal baseline was computed as the participant-level median. Spread was measured as the Median Absolute Deviation (MAD), clamped to a minimum of 1 to prevent division by zero.

### Flagging criteria
A day was flagged when all three conditions were met:

1. **MAD-scaled deviation ≥ 5**:  
   `|value − median| / MAD ≥ 5`

2. **Metric-specific absolute threshold exceeded**:  

   | Metric | Absolute Threshold |
   |--------|-------------------|
   | Subjective SOL | > 120 min |
   | WASO | > 60 min |
   | Nap | > 360 min (6 h) |
   | Exercise Light | > 240 min (4 h) |
   | Exercise Moderate | > 180 min (3 h) |
   | Exercise Vigorous | > 120 min (2 h) |
   | Exercise Strength | > 120 min (2 h) |

3. **Relative fold-change**:  
   Value ≥ 4× the participant's median

### Low-baseline override
For participants whose median was very low (e.g., median SOL < 30 min), a secondary criterion applied: any value exceeding a higher absolute threshold (e.g., SOL > 240 min) was flagged independently of the MAD-based deviation, capturing extreme outliers that were already implausible relative to the participant's typical near-zero reporting.

### Consistent pattern exclusion
Participants who habitually reported high values (≥50% of days above threshold, with at least 3 such days) were classified as exhibiting a consistent pattern and excluded from cross-participant flags, as these values represent stable individual differences rather than data-entry anomalies.

### Human review and classification
All flagged rows were independently reviewed by three raters using a consensus-based classification system:

| Classification | Meaning |
|---------------|---------|
| `valid_unusual` | Extreme but genuine value (e.g., 4.5 h of light exercise in HH:MM format) |
| `do_not_use` | Confirmed format error; exclude from analysis |
| `review` | Requires further investigation against source data |

### Output files
- `cross_participant_flagged_rows.csv` — flagged rows with per-participant baseline context
- `cp_flagged_review_notes.csv` — human review classifications and explanatory notes

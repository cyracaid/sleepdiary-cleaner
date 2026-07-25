# Calculate_sleep_time_simple Logic

Created by: CAI DONG
Created time: January 4, 2026 4:47 PM
Tags: Neuroimaging

### **1. Data Preparation Phase:**

- **Input**: Raw sleep time data with columns: `time_bed_am_hhmm_ampm`, `time_sleep_am_hhmm_ampm`, `time_awake_am_hhmm_ampm`, `time_getup_am_hhmm_ampm`
- **Process**:
    1. Create working copy of data
    2. Add `row_id` for tracking
    3. Identify records with NA values in any sleep time variable
    4. Initialize corrected time columns with original values
    5. Set `data_category` to "skipped_na" for NA records (skip further processing)
- **Output**: Prepared dataframe with all necessary columns

### **2. Priority Order Adjustment Phase (Step 3 in code):**

**Goal**: Fix major time order issues based on decision tree's first branch

**Logic Chain for Each Non-NA Record**:

text

```
Check awake > getup?
├── Yes, check time difference:
│   ├── If |awake-getup diff| < 1 hour → Direct swap awake and getup
│   └── If |awake-getup diff| > 12 hours → Subtract 12 hours from sleep time (AM/PM conversion)
├── No → Continue
│
Check bed < sleep AND bed-sleep diff ≥ 12 hours?
├── Yes → Loop: Subtract 12 hours from sleep until diff < 12 hours
├── No → Continue
│
Check getup > awake AND awake-getup diff ≥ 12 hours?
├── Yes → Subtract 12 hours from getup time
└── No → No action
```

### **3. Minor Order Error Processing Phase (Step 4 in code):**

**Goal**: Fix small order errors with 3-hour threshold

**Logic Chain for Each Non-NA Record**:

text

```
Check bed > sleep AND |bed-sleep diff| < 3 hours?
├── Yes → Swap bed and sleep times
├── No → Continue
│
Check sleep > awake AND |sleep-awake diff| < 3 hours?
├── Yes → Swap sleep and awake times
├── No → Continue
│
Check awake > getup AND |awake-getup diff| < 3 hours?
└── Yes → Swap awake and getup times
```

### **4. Error Marking & Classification Phase (Step 5 in code):**

**Goal**: Evaluate corrected data and assign classification labels

**Logic Chain**:

text

```
For each non-NA record:
1. Calculate time differences (bed-sleep, sleep-awake, awake-getup)
2. Check if order is correct: bed < sleep < awake < getup
3. Check four conditions:
   - Condition 1: Order correct (from step 2)
   - Condition 2: |bed-sleep diff| ≤ 7 hours
   - Condition 3: |awake-getup diff| ≤ 7 hours
   - Condition 4: |sleep-awake diff| ≤ 24 hours
4. Check special cases:
   - bed-sleep equal (difference = 0)
   - awake-getup equal (difference = 0)
5. Determine classification:
   - If bed-sleep equal OR awake-getup equal → "equal_time_ok"
   - Else if ALL 4 conditions met → "clean"
   - Else if ANY condition failed → "error"
   - Else if suspicious patterns detected → "unusual"
6. Assign error/suspicious types
```

### **5. Data Classification & Output Phase (Steps 6-11):**

**Logic Chain**:

text

```
Create separate dataframes based on classification:
1. equal_time_df → Records with bed=sleep or awake=getup (not considered errors)
2. error_df → Records failing one or more conditions
3. unusual_df → Records with suspicious time patterns
4. clean_df → Records passing all checks
5. summary_df → Statistical summary of processing results

Save all dataframes to global environment
Generate detailed processing report
Return complete cleaned dataframe
```

## **Key Decision Rules:**

### **Priority Adjustment Rules:**

1. **Awake-Getup Reversal**: If awake > getup
    - Difference < 1h → Swap
    - Difference > 12h → Adjust sleep time by -12h
2. **Bed-Sleep Large Difference**: If bed < sleep AND difference ≥ 12h
    - Loop: Subtract 12h from sleep until difference < 12h
3. **Getup-Awake Large Difference**: If getup > awake AND difference ≥ 12h
    - Subtract 12h from getup

### **Minor Error Correction Rules:**

For any adjacent time pair (bed-sleep, sleep-awake, awake-getup):

- If order reversed AND time difference < 3h → Swap times

### **Error Classification Rules:**

A record is marked as **ERROR** if it fails ANY of these AND doesn't have equal times:

1. Order incorrect (bed ≥ sleep OR sleep ≥ awake OR awake ≥ getup)
2. |bed-sleep diff| > 7h
3. |awake-getup diff| > 7h
4. |sleep-awake diff| > 24h

### **Special Case Handling:**

- **Equal times** (bed=sleep or awake=getup) → Treated as valid, not errors
- **Suspicious patterns** → Separate category for improbable but not impossible values

## **Data Flow Visualization:**

text

```
Raw Input
    ↓
[Data Preparation]
    ↓ (Skip NA records)
[Priority Order Adjustment]
    ↓
[Minor Order Error Processing]
    ↓
[Error Marking & Classification]
    ↓
┌───────────────┬───────────────┬───────────────┬───────────────┐
│ equal_time_df │   error_df    │  unusual_df   │   clean_df    │
│ (equal times) │ (failed cond) │ (suspicious)  │ (passed all)  │
└───────────────┴───────────────┴───────────────┴───────────────┘
                      ↓
                [Summary Report]
                      ↓
                Final Output Dataframe
```
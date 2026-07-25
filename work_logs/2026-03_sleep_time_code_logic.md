# Code Processing Logic Explanation

## Overview

This code processes sleep time data by cleaning, correcting, and validating temporal records. The processing follows a structured pipeline with multiple validation and correction stages.

## Detailed Processing Logic

### **Phase 1: Initial Setup and Data Preparation**

1. **Create duration variables vector**
   - `duration_vars`: Contains column names for subjectively recorded sleep time variables
2. **Create new columns in `cleaned_data` dataframe**
   - For **NA value marking**: `has_na` (logical flag for records with NA in core sleep variables)
   - For **time correction**: Modified versions of original time columns (initialized as copies)
   - For **correction tracking**:
     - `corrected` (boolean flag, FALSE initially)
     - `correction_type` (character, NA initially)
3. **Initial processing scope definition**
   - Only process records **without missing values** (`!has_na`)
   - Skip records with NA values entirely

### **Phase 2: Midnight Crossing Correction (Primary Correction)**

#### **A. Pre-processing checks**

```R
IF (number of non-NA records > 0) THEN
    Get indices of valid records: which(!cleaned_data$has_na)
    FOR EACH valid record index i DO
        Extract time values from corrected columns:
            - bed, sleep, awake, getup
        Initialize per-row correction flags:
            - corrected_flag = FALSE
            - correction_type = NA
```



#### **B. Midnight adjustment logic**

The code applies iterative 12-hour adjustments to handle midnight crossing:

```R
REPEAT UNTIL (no more adjustments needed) {
    // Sleep phase adjustment (bed fixed, sleep adjusted backward)
    IF (bed < sleep AND (sleep - bed) ≥ 12 hours) THEN
        sleep = sleep - 12 hours
        corrected_flag = TRUE
        Append "midnight_correction" to correction_type
    
    // Wake phase adjustment (awake fixed, getup adjusted backward)
    IF (getup > awake AND (getup - awake) ≥ 12 hours) THEN
        getup = getup - 12 hours
        corrected_flag = TRUE
        Append "midnight_correction" to correction_type
}
```



#### **C. Post-correction update**

```R
Store corrected values back to dataframe:
    cleaned_data[i, corrected_bed] = bed
    cleaned_data[i, corrected_sleep] = sleep
    cleaned_data[i, corrected_awake] = awake
    cleaned_data[i, corrected_getup] = getup
Update correction metadata:
    cleaned_data[i, "corrected"] = corrected_flag
    cleaned_data[i, "correction_type"] = correction_type
```



### **Phase 3: Small-range Order Error Correction**

#### **A. Bed-Sleep sequence correction**

```R
IF (bed > sleep AND |bed - sleep| < 3 hours) THEN
    // Swap bed and sleep times
    temp = bed
    bed = sleep
    sleep = temp
    corrected_flag = TRUE
    Append "bed_sleep_swap" to correction_type
```



#### **B. Awake-Getup sequence correction**

```R
IF (awake > getup AND |awake - getup| < 3 hours) THEN
    // Swap awake and getup times
    temp = awake
    awake = getup
    getup = temp
    corrected_flag = TRUE
    Append "awake_getup_swap" to correction_type
```



### **Phase 4: Time Difference Calculations and Validation**

#### **A. Compute time differences (for non-NA records only)**

```R
bed_sleep_diff_h = sleep - bed       // Bed to sleep latency (hours)
sleep_awake_diff_h = awake - sleep   // Total sleep duration (hours)
awake_getup_diff_h = getup - awake   // Wake to getup duration (hours)
```



#### **B. Validate temporal sequence**

```R
order_correct = (bed < sleep) AND (sleep < awake) AND (awake < getup)
```



#### **C. Apply four core validation conditions**

```R
condition1_ok = order_correct                              // Sequence must be correct
condition2_ok = |bed_sleep_diff_h| ≤ 7 hours              // Sleep latency ≤ 7h
condition3_ok = |awake_getup_diff_h| ≤ 7 hours            // Wake-to-rise ≤ 7h
condition4_ok = |sleep_awake_diff_h| ≤ 24 hours           // Total sleep ≤ 24h
```



#### **D. Handle special cases**

```R
bed_sleep_equal = (bed_sleep_diff_h == 0)      // Allow bed = sleep
awake_getup_equal = (awake_getup_diff_h == 0)  // Allow awake = getup
```



#### **E. Error flagging logic**

```R
is_error = TRUE IF:
    1. Record has no NA values
    2. AND (NOT condition1_ok OR NOT condition2_ok OR NOT condition3_ok OR NOT condition4_ok)
    3. AND NOT (bed_sleep_equal OR awake_getup_equal)  // Exclude exact equality cases
```



#### **F. Suspicious data flagging (additional quality control)**

```R
sleep_awake_suspicious = (sleep_awake_diff_h < 3) OR (sleep_awake_diff_h > 15)
bed_sleep_suspicious = (bed_sleep_diff_h > 3)
awake_getup_suspicious = (awake_getup_diff_h > 3)

is_unusual = TRUE IF:
    1. Any suspicious condition is TRUE
    2. AND NOT (bed_sleep_equal OR awake_getup_equal)
```

 
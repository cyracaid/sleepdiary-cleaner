# Worklog: Running sleepcleanr Locally (For Maia)

**Date**: 2026-09-09
**Purpose**: Guide Maia through cloning, configuring, and running the pipeline locally
**Expected time**: ~30 min (clone + install + first run)

---

## Step 1: Clone Repository

```bash
git clone https://github.com/cyracaid/sleepdiary-cleaner.git
cd sleepdiary-cleaner
```

Verify you're on main branch:
```bash
git branch -v
# Should show: * main [latest commit hash]
```

---

## Step 2: Install R Package + Dependencies

From within the `sleepdiary-cleaner/` directory, run in R:

```r
# Install renv if needed
if (!requireNamespace("renv")) install.packages("renv")

# Restore the project environment (installs all deps to local cache)
renv::restore()

# Install the package itself
renv::install(getwd())  # or devtools::load_all()

# Verify installation
library(sleepcleanr)
packageVersion("sleepcleanr")
# Should print: 1.4.5 or later
```

**If `renv::restore()` hangs or fails:**
- Check internet connection
- Try: `renv::restore(confirm = FALSE, force = TRUE)`
- Fallback: `remotes::install_deps()` then `devtools::load_all()`

---

## Step 3: Run the Synthetic Demo (Smoke Test)

This uses built-in dummy data — fast, no setup needed.

```r
library(sleepcleanr)

# Run with defaults (synthetic fixture)
run_pipeline()

# Should produce:
# ✓ Step 1: Load data...
# ✓ Step 1.5: Field-misentry check...
# ... (10 steps total)
# ✓ All figures generated
# Output: ./pipeline_output/ directory with CSVs + figures
```

**Expected output:** 
- `pipeline_output/` directory created locally
- Contains: `correction_status_final.csv`, `step_flag_ledger.csv`, 30 figures, etc.
- No errors (0 ERRORs, safe to ignore WARNINGs about vignettes if this is a --no-build-vignettes run)

---

## Step 4: Inspect Output (QC Checklist)

After demo run completes, verify basic structure:

```r
# Check the output files exist
list.files("pipeline_output/", pattern = "*.csv")

# Spot-check key CSVs
head(read.csv("pipeline_output/correction_status_final.csv"))
head(read.csv("pipeline_output/step_flag_ledger.csv"))

# Spot-check figures exist
list.files("pipeline_output/", pattern = "*.png") |> length()
# Should be ~30
```

**If output is missing or errors occur**, capture the full error log and share:
```bash
# Rerun with logging
R CMD BATCH --vanilla run_pipeline_test.R pipeline_test.Rout 2>&1
# Attach pipeline_test.Rout file
```

---

## Step 5: Run Tests (Optional but Recommended)

Verify the codebase hasn't regressed:

```r
library(testthat)
test_dir("tests/testthat/")
```

Expected: **308 tests pass**, 0 failures (some WARNINGs ok; 0 ERRORs critical)

If tests fail, note which ones and share the output.

---

## Step 6: Troubleshooting

| Problem | Diagnosis | Fix |
|---------|-----------|-----|
| `Error: package 'X' not found` | Dependency missing | `install.packages("X")` or `renv::restore()` |
| `Error in run_pipeline()...` | Config or schema issue | Check working directory with `getwd()`; ensure `pipeline_output/` writable |
| `Figures not generated` | Graphics device issue (headless server?) | Set `options(device = "png")` or use `Xvfb` if on Linux |
| `R CMD check NOTE about vignettes` | Expected in --no-build-vignettes mode | Safe to ignore if run_pipeline() works |
| `sync_human_review_status() crash` | Old version? | Verify: `packageVersion("sleepcleanr")` ≥ 1.4.5 (commit 4812fcc+) |

---

## Step 7: Next: Run Real Data (If You Have It)

Once the demo works, map your own dataset:

```r
# Copy config template
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")

# Edit my_study.yaml in your text editor:
# - Set data_input: path to your CSV or RDS
# - Map column names (bed_time, sleep_time, awake_time, getup_time, SOL, WASO, etc.)
# - Set timezone, country code, etc.

# Run against your data
run_pipeline(config = "my_study.yaml")
```

For column-mapping help, see: `vignette("column-mapping")`

---

## Questions / Issues

If anything breaks:
1. **Save full console output** (copy-paste from R, or `sink("log.txt")` + `sink()`)
2. **Note your OS** (Windows / macOS / Linux)
3. **Note R version** (`R --version` or `R.version`)
4. **Share with Cyra** (email or Slack)

---

## Success Criteria

✅ `run_pipeline()` completes without ERRORs  
✅ `pipeline_output/` directory created with >25 files  
✅ `correction_status_final.csv` has >0 rows  
✅ 30 diagnostic figures generated (visible in `pipeline_output/`)  
✅ Tests pass (308/308)

If all ✅, you're good to:
- Run on your real data
- Inspect correction CSVs
- Proceed to method validation

# sleepcleanr — Reproducible cleaning pipeline for sleep EMA diary data

[![GitHub stars](https://img.shields.io/github/stars/cyracaid/sleepdiary-cleaner?style=flat-square)](https://github.com/cyracaid/sleepdiary-cleaner)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](https://opensource.org/licenses/MIT)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23077702.svg)](https://doi.org/10.5281/zenodo.23077702)
[![R-CMD-check](https://img.shields.io/github/actions/workflow/status/cyracaid/sleepdiary-cleaner/R-CMD-check.yaml?style=flat-square&label=R--CMD--check)](https://github.com/cyracaid/sleepdiary-cleaner/actions/workflows/R-CMD-check.yaml)
[![Codecov](https://img.shields.io/codecov/c/github/cyracaid/sleepdiary-cleaner?style=flat-square&color=orange)](https://app.codecov.io/gh/cyracaid/sleepdiary-cleaner)
[![Docs](https://img.shields.io/badge/docs-pkgdown-blue?style=flat-square)](https://cyracaid.github.io/sleepdiary-cleaner/)

> **[English](#english) · [中文](#中文)**

---

<a name="english"></a>

# English

**sleepcleanr** is a reproducible, auditable R pipeline for cleaning sleep EMA
(ecological momentary assessment) diary data: it parses raw
bedtime/sleep/awake/get-up timestamps, detects and corrects temporal and
duration errors through a transparent human-in-the-loop workflow (every
correction stored in re-readable CSVs), computes standard sleep metrics
(TST, SOL, WASO, SE), and generates diagnostic and research-ready figures. A
schema-validated YAML config maps the pipeline to your dataset without
touching code. Developed for the Stanford Psychophysiology Laboratory's
intensive-longitudinal sleep study.

## The Pipeline at a Glance

```
Messy sleep diary data (CSV / RDS)
         ↓
   Timestamp parsing & normalization
         ↓
   Error detection (order, duration, timezone)
         ↓
   Human-in-the-loop review (flagged records only)
         ↓
   Correction ledger (full audit trail)
         ↓
   Sleep metrics (TST, SOL, WASO, SE)
         ↓
   30+ diagnostic & research-ready figures
         ↓
   Dataset A (final clean) + Dataset B (audit ledger)
```

## What makes it different

1. **Human-in-the-loop, not automatic repair.** Deterministic rules correct only
   unambiguous ordering and format errors; value-level disagreements are routed
   to human review. A plausible large SOL is left exactly as reported — it is
   signal, not an error.
2. **No silent corrections.** Every change carries a recorded correction type, and
   flags persist until a human resolves them explicitly. The correction ledger is
   part of the output (`correction_status_final.csv`, `step_flag_ledger.csv`).
3. **Configurable, documented thresholds.** Rule thresholds ship as YAML defaults
   with rationale (see [THRESHOLDS.md](THRESHOLDS.md)) and are meant to be
   re-checked against your own data.
4. **Reproducible.** YAML config, `renv.lock`, and a CI-run test suite
   (R-CMD-check, Codecov).

## Evidence at a glance

Full package in [VALIDATION_REPORT.md](VALIDATION_REPORT.md). Summary:

- **Synthetic ground truth** (4,736 injected errors): detection recall **0.995**
  [0.993, 0.997], specificity 1.0. "Detection" means the record was flagged, not
  that the corrected value was recovered — correction-level recall is lower and is
  reported per error category in the validation report.
- **Real study data** (n = 13,990): in the study's run, the rules applied an
  automatic order or format correction to 93 rows (10 of them were also corrected
  by a reviewer) and reviewers corrected 75 further rows. The review queue at the
  end of a run is 226 rows (1.6%) with the manual files applied and 307 (2.2%)
  without. The 1,048 rows flagged in the v1.4.5 audit came from a report-only
  pass that modified no data.
- **External public datasets**: the pipeline runs on other schemas after a short
  conversion script. These datasets contain no known errors, so they are a
  feasibility check, not accuracy validation.

Earlier automated variants silently misrepaired entries; the synthetic benchmark
found and closed those defects, and the current benchmark reports 0% silent
misrepair for SOL/WASO.

### Why the hybrid (automated + human) design?

sleepcleanr is deliberately **not** fully automated and **not** all-manual-flag:

- **Not fully auto:** high-confidence, order/AM-PM-only rules correct harmlessly; but value-level errors (e.g. SOL vs the bed→sleep window) must not be overwritten — a plausible large SOL is real psychological signal, and silently "fixing" it would bias the sleep–affect associations the pipeline exists to serve.
- **Not all-flag:** a 1,048-row FLAG queue is unmanageable by hand. High-confidence rules chew the deterministic cases; FLAG keeps only the ambiguous ones for human review.

The outcome is not "the pipeline makes a mess clean" — it makes the mess **explicit**: every candidate error is surfaced or logged, never silently hidden.

> **Thresholds are references, not gospel.** The swap/flip thresholds shipped here (e.g. 3-hour adjacent swap, 12-hour AM/PM flip) were validated on our dataset(s) — see VALIDATION_REPORT. Your study's diaries may fall inside or outside these cut-offs; they are YAML-configurable and should be re-checked against your own data, not copied blindly.

### Terminology

| Term | Meaning |
|---|---|
| **Detection recall (L1)** | Share of injected errors for which the pipeline *acted* (flagged or corrected) |
| **Correction-level recall (L3)** | Share of injected errors for which the pipeline recovered the *correct value* |
| **FCR** | False-correction rate: clean records that were altered |
| **FAR** | False-alarm rate: clean records that were flagged |
| **SPEC** | Specificity (clean records left untouched) |
| **M1 / M4 / M5** | Real-data audit rules: M1 order violations, M4 bed→sleep window violations, M5 silent-worsening candidates |
| **AUTO_FIX** | A change applied automatically, with no human review |

### Detection-threshold defaults

| Rule | Default | Rationale |
|---|---|---|
| `timestamp.sequence.max_gap_hours` (AM/PM flip) | 12 h | Assumes no legitimate interval ≥ 12 h |
| adjacent-swap threshold | 3 h | Tuned on the development sample; see VALIDATION_REPORT |
| `metric_validation.sol.excessive_minutes` | 120 | Gross-outlier catch, not a clinical marker |
| `metric_validation.se.min_valid_percent` / `max_valid_percent` | 0 / 100 | Structural impossibility → always flag |
| `interval.mmss_threshold_minutes` | 60 | Heuristic for ambiguous `MM:SS` vs `HH:MM` |
| `timestamp.midnight_threshold_hour` | 6 | Times < 6 AM assigned to the next day |

Full rationale and change guidance: [THRESHOLDS.md](THRESHOLDS.md).

### Flag System & Human Review Workflow

sleepcleanr uses a structured flag system to route records through the human-in-the-loop review process. Every record can carry multiple flags; flags are **additive** (a record may carry several simultaneously) and **never silently cleared** — they persist until explicitly resolved by human action.

| Flag / Column | Trigger | Meaning | Resolution |
|---|---|---|---|
| `needs_review_flag` | Any detection rule fires | Record needs human attention | Human reviews → sets `manually_corrected=TRUE` OR `human_metric_review_status=confirmed_not_error_do_not_correct` |
| `auto_error_desc` | Auto-detection logic | Machine-readable description of why flagged | Reference for human reviewer |
| `error_type` / `unusual_type` | Step 5 classification | Categorized error type (TIMESTAMP, DURATION, SELF_REPORTED, etc.) | Informs reviewer; drives Figure 13 classification |
| `manually_corrected` | Human applied correction via `apply_manual_corrections.R` | Record was explicitly fixed by human | Set to `TRUE` by `apply_manual_corrections.R` |
| `human_metric_review_status` | Human metric review decision | `confirmed_not_error_do_not_correct` = reviewed & confirmed correct | Set by `apply_metric_review_acceptances.R` / `apply_metric_review_acceptances()` |
| `human_metric_review_note` | Reviewer's free-text note | Context for future auditors | Free text |
| `correction_type` | Applied correction type | e.g., `bed_sleep_swap_3h`, `sleep_reduce_12h_loop` | Populated by correction engine |

**Flag lifecycle:**

```
Record flagged (needs_review_flag=TRUE)
    ↓ Human reviews
    ├── Confirmed error → apply_manual_corrections.R → manually_corrected=TRUE
    ├── Confirmed OK → human_metric_review_status="confirmed_not_error_do_not_correct"
    └── Deferred / unsure → needs_review_flag remains TRUE
```

**Key design principles:**

1. **Flags are never silently cleared** — a flag persists until explicit human action (`manually_corrected=TRUE` or `human_metric_review_status=confirmed_not_error_do_not_correct`).
2. **Flags are additive** — a record can carry multiple flags simultaneously (e.g., TIMESTAMP + DURATION + SELF_REPORTED).
3. **Resolution is explicit** — a flag is "resolved" only by setting `manually_corrected=TRUE` or `human_metric_review_status=confirmed_not_error_do_not_correct`; there is no implicit "auto-resolve".
4. **Flags persist in outputs** — Dataset A (full) retains all flags for audit; Dataset B (minimal) includes only `needs_review_flag` and `correction_type` for downstream analysis.

**Current flag categories** (from `checkforerrors_processing.R` and METHODS Stage 7):

| Category | Sub-types | Meaning |
|---|---|---|
| **TIMESTAMP** | Sequence/range violations (bed/sleep/awake/getup times) | e.g., hour>23, malformed colon, inverted sequences |
| **DURATION** | Interval/format errors (SOL, WASO) | e.g., MM:SS vs HH:MM confusion, plausibility violations |
| **AMOUNT** | Substance input anomalies | negative, excessive digits, filler codes (888/999) |
| **SELF_REPORTED** | SOL/WASO vs timestamp-window mismatch | SOL > bed→sleep window, SE>100%, etc. |

**Flag statistics (snapshot at v1.4.5, n=13,990; each run prints the current review queue):** 1,048 records flagged (7.5%); 0 AUTO_FIX; 0 silent corrections. Breakdown: 922 TIMESTAMP (window violations), 140 DURATION (order violations), 1 SELF_REPORTED (extreme), 1 redundancy-confirmed worsening. See `VALIDATION_REPORT.md` for full breakdown.

### Validation Map

```
SYNTHETIC TIER (ground truth)
──────────────────────────────
Step 1  Clean-input specificity ── 10k clean records → 0 changes/flags
Step 2  Injected-error benchmark ── detection recall 0.995 [0.993, 0.997]
Step 3  Detection vs correctness ── L1 vs L3 gap → routes to human
Step 4  Controls ── no_cleaning 0 / naive_rule 0.623 / pipeline 0.995

REAL-DATA TIER (n = 13,990)
──────────────────────────────
Step 5  Redundant-channel ── 80/81 corrections improve (98.8%)
Step 5.5  Bland-Altman ── SOL ±75-min noise band; WASO 3.3× above noise
Step 6  Report-only audit ── 0 AUTO_FIX, 1,048 FLAG
Step 7  Human co-review ── 64–89% agreement

ROBUSTNESS TIER
──────────────────────────────
Step 8  Multiverse + seeds ── recall stable 0.993–0.995
```

> **Naming note:** The R package is called **sleepcleanr** (CRAN convention: no
> hyphens). The GitHub repository is **sleepdiary-cleaner**. They are the same
> project — install via `renv::install("cyracaid/sleepdiary-cleaner")` and then
> `library(sleepcleanr)`.


> **Validation statistics source:** All validation statistics above (recall 0.995, 99% improvement, 0% silent misrepair for SOL/WASO, etc.) are derived from benchmarks run against the current `sleepcleanr` v1.4.5+ codebase (commit fd6bbd0). The synthetic benchmark (`validation/synthetic/results/detection_outcomes_v4_current.csv`, 4,736 injected rows) and real-data audit (n=13,990) were executed against the current codebase (commit fd6bbd0). These statistics reflect the current pipeline behavior and supersede any earlier pre-patch numbers cited in earlier documentation. See `VALIDATION_REPORT.md` and `validation/synthetic/SYNTHETIC_BENCHMARK_RESULTS.md` for the full evidence package.

## Status and data availability

**Status.** sleepcleanr 1.4.9 is research software under active development. It
was built for one longitudinal sleep study, has not yet been peer reviewed, and
is not on CRAN. Treat the shipped thresholds as references to check against your
own data.

**Data availability.** The study data are not public (participant privacy).
What you can use without them:

- a bundled synthetic fixture (`inst/extdata/`, 280 rows, 20 participants) that
  `run_pipeline()` runs on by default;
- the synthetic benchmark, which regenerates its own data from fixed seeds, so
  every benchmark number can be re-run (see
  [`validation/README.md`](validation/README.md));
- two public diary datasets with adaptation scripts
  (`validation/external/`).

The few numbers that come from the study data (for example the redundant-channel
check) are reported in `VALIDATION_REPORT.md` and cannot be re-run without
access to those data.

## Limitations

- **Thresholds are study-specific defaults.** The 3-hour adjacent-swap and
  12-hour AM/PM-flip rules, and the plausibility cut-offs, were tuned on one
  healthy-adult EMA sample. Clinical, shift-work, and elderly samples should
  revisit every rule. Rationale and defaults are in [THRESHOLDS.md](THRESHOLDS.md).
- **Detect, do not infer intent.** The pipeline surfaces candidate errors; it
  cannot recover information that was never entered, and value-level
  disagreements are routed to a human, not resolved automatically.
- **Validation is partly self-referential.** Detection was validated against
  injected synthetic errors and the pipeline's own real-data audit. No
  independent human gold standard for free-text diary entry exists, and some
  reported statistics come from the development data.
- **No native CSD or `.sav` support.** The Consensus Sleep Diary format is not a
  native input; map your columns via YAML (or let the inference guess). Output is
  `.csv` / `.rds`; there is no SPSS `.sav` export.
- **One protocol.** Developed for an intensive-longitudinal morning sleep diary.
  Evening diaries, nap-only logs, and actigraphy are out of scope.
- **Not a substitute for study-specific quality control.**

## Install

```r
# From GitHub (not yet on CRAN)
renv::install("cyracaid/sleepdiary-cleaner")
```

## Quick start

```r
library(sleepcleanr)

# Demo run on the bundled synthetic fixture
run_pipeline()

# Your own study: copy the config template, map your columns, run again
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
# edit my_study.yaml → run_pipeline(config = "my_study.yaml")

# Data-first entry (no config file needed): column names are inferred and
# every schema decision is recorded in the run manifest.
res <- clean_sleep_diary("my_diary.csv")          # .csv / .rds / .xlsx / data.frame
res$cleaned                                       # cleaned Dataset A
res$guesses                                       # how each column was mapped
res$manifest                                      # provenance: input hash, config, step ledger
# Preview the inferred mapping without running anything:
clean_sleep_diary("my_diary.csv", dry_run = TRUE) # writes dry_run_manifest.json, no data written
```

## Citation

Cite the software with its Zenodo DOI (the concept DOI always resolves to the
latest version; each release also has its own version DOI):

> Dong, C., & ten Brink, M. (2026). *sleepcleanr: Reproducible Sleep EMA Diary
> Data Cleaning Pipeline* [R package]. https://doi.org/10.5281/zenodo.23077702

In R: `citation("sleepcleanr")`. Machine-readable metadata: `CITATION.cff`.

## Run the tests, report a problem, contribute

```r
devtools::test()   # from a clone of the repository; the same suite runs in CI
```

Bugs, questions and feature requests: open an
[issue](https://github.com/cyracaid/sleepdiary-cleaner/issues). Contribution
guidelines are in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Learn more

- Full docs site (searchable reference + vignettes, bilingual):
  <https://cyracaid.github.io/sleepdiary-cleaner/>
- **Validation Report** (evidence package, machine-read from result CSVs):
  [`VALIDATION_REPORT.md`](VALIDATION_REPORT.md)
- vignette("pipeline-architecture") — structure, rule families, classification
- vignette("column-mapping") — mapping your dataset via YAML
- vignette("interpreting-output") — reading `correction_status_final.csv` and `step_flag_ledger.csv`
- vignette("validation-methodology") — how the rules were validated (synthetic + real data)
- vignette("testing-coverage") — test suite coverage
- vignette("data-first") — `clean_sleep_diary()`: no-config entry, column auto-guess, run manifest
- Changelog: <https://github.com/cyracaid/sleepdiary-cleaner/releases>

## For developers / AI assistants

The repository ships an agent skill at
`.opencode/skills/sleepcleanr-pipeline/SKILL.md` that documents how to run the
pipeline, interpret checkpoint reports, add manual corrections, and diagnose
issues.

### Pipeline steps

<!-- AUTO:ARCH_START -->

**10 steps** (source: `inst/steps.yaml`):

| Step | Label | Description |
|------|-------|-------------|
| 1 | Load data | .rds/.csv auto-detected; schema validated; optional supplementary file merged |
| 1.5 | Field-misentry check | SOL/WASO clock-time vs duration-field misentry detection on raw data |
| 2-4 | Parse & normalize (S3 chain) | Parse timestamps → parse intervals → normalize sequence |
| 5 | Classify records | Generate manual review CSVs for human approval |
| 5.75 | Second-review consensus | Apply second-review checklist consensus |
| 6-7 | Correct & compute metrics (S3 chain) | Manual + duration corrections; TST/SOL/WASO/SE metrics; has_correction enum |
| 8 | Auto-detect remaining issues | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED flag classification |
| 8.5 | Cross-participant consistency check | Global consistency audit across participants |
| 9 | Generate diagnostic figures | 30 figures (14 QC + 16 research) + figure_index.png contact sheet + RUN_INFO.txt |
| 10 | Build delivered datasets | finalize_columns() selects/renames to Dataset A/B per column dictionary |

<!-- AUTO:ARCH_END -->

## Sync Human Review Status

sleepcleanr provides a utility to synchronize human review status fields in the metric review acceptance CSV file.

> **Resolved (v1.4.5, commit 4812fcc):** The earlier known issue where `sync_human_review_status()` crashed on bootstrap runs and did not reproduce from clean state has been fixed. The function now correctly handles first-time runs and produces reproducible results.

### `sync_human_review_status()`

Automatically synchronizes review status fields in `manual_metric_review_acceptances.csv` based on human review traces.

```r
library(sleepcleanr)
sync_human_review_status("manual_metric_review_acceptances.csv")
```

**What it does:**

1. **Detects human review traces** by checking:
   - `human_metric_review_note` (non-empty reviewer notes)
   - `resolved_at` (resolution timestamp)
   - `resolved_by` (resolution actor)

2. **Updates three columns** based on detected traces:
   - `review_resolution`: `"corrected"` / `"flagged_unresolved"` / `"legacy"`
   - `resolved_at`: Resolution date (only for `corrected`)
   - `resolved_by`: `"system"` / `"pending"` / `"legacy"`

**Resolution Logic:**
| Condition | `review_resolution` | `resolved_at` | `resolved_by` |
|-----------|---------------------|---------------|---------------|
| Explicit `corrected` flag | `"corrected"` | Today | `"system"` |
| Human traces + legacy/NA | `"flagged_unresolved"` | NA | `"pending"` |
| Human traces + legacy/NA | `"flagged_unresolved"` | NA | `"pending"` |
| No traces + legacy | `"legacy"` | NA | `"legacy"` |

**Usage:**
```r
library(sleepcleanr)
sync_human_review_status("manual_metric_review_acceptances.csv")
```

**Output:**
```
✓ Synced 161 rows: 1 corrected, 43 flagged, 117 legacy
```

**Integration in Pipeline:**
Automatically runs at pipeline Step 11 (after all corrections, before visualization):
```r
run_pipeline(config = "my_study.yaml")  # Automatically runs sync_human_review_status() at Step 11
```

**Manual invocation:**
```r
library(sleepcleanr)
sync_human_review_status("manual_metric_review_acceptances.csv")
```


---

<a name="中文"></a>

# 中文

**sleepcleanr** 是一个可复现、可审计的睡眠 EMA 日记数据清洗 R 管线：解析原始
就寝/入睡/醒来/起床时间戳，通过透明的人工审核工作流（每次修正都存为可重读的
CSV）检测并修正时序与时长错误，计算标准睡眠指标（TST、SOL、WASO、SE），并生成
诊断与科研图表。经 schema 校验的 YAML 配置可将管线映射到你的数据集，无需改代码。
为斯坦福心理生理学实验室的高强度纵向睡眠研究开发。

### 为什么是"自动 + 人工"混合设计？

sleepcleanr 刻意**既非全自动、也非全部人工 flag**：

- **不全自动：** 高置信、仅涉时序/AM-PM 的规则才安全自动修正；但值级错误（如 SOL 与就寝→入睡窗口的矛盾）绝不覆盖 — 一个看似偏大的 SOL 是真实的心理信号，静默"修正"会破坏管线所服务的睡眠–情绪关联。
- **不全 flag**：1048 行 FLAG 队列手动看不过来。高置信规则吃掉确定性个案；FLAG 只把歧义个案留给人审。

结果不是"管线把 mess 洗干净"，而是把 mess **显式化**：每个候选错误要么被呈现，要么被记录，永不被静默隐藏。

> **阈值只是参考，不是教条。** 这里的 swap/flip 阈值（如 3 小时相邻对调、12 小时 AM/PM 翻转）在我们的数据集上验证过 — 见 VALIDATION_REPORT。你的研究日记可能落在这区间内或外；它们都是 YAML 可配置的，应按你自己的数据重新审视，而非盲抄。

> **命名说明：** R 包名为 **sleepcleanr**（CRAN 规范不允许连字符），
> GitHub 仓库名为 **sleepdiary-cleaner**。两者是同一项目 — 安装用
> `renv::install("cyracaid/sleepdiary-cleaner")`，加载用 `library(sleepcleanr)`。

## 状态与数据可用性

**状态。** sleepcleanr 1.4.9 是仍在开发中的研究软件，为一项纵向睡眠研究而写，尚未经同行评审，也未上线 CRAN。随包给出的阈值只是参考，请用你自己的数据核对。

**数据可用性。** 研究数据不公开（参与者隐私）。不需要这些数据也能用到的东西：

- 内置合成数据（`inst/extdata/`，280 行、20 名参与者），`run_pipeline()` 默认就跑它；
- 合成基准会按固定随机种子自己生成数据，所以基准里的每个数字都可以重跑（见 [`validation/README.md`](validation/README.md)）；
- 两个公开日记数据集及其转换脚本（`validation/external/`）。

少数来自研究数据的数字（例如冗余通道检查）记录在 `VALIDATION_REPORT.md` 里，没有数据访问权限就无法重跑。

## 局限

- **阈值是研究专属默认值。** 3 小时相邻对调、12 小时 AM/PM 翻转及合理性切点，都在单一健康成人 EMA 样本上调过。临床、倒班、老年样本应重新审视每条规则。见 [THRESHOLDS.md](THRESHOLDS.md)。
- **只检测，不推断意图。** 管线只呈现候选错误，无法恢复从未录入的信息；值级分歧交人工，不自动裁决。
- **验证部分是自证的。** 检出率基于注入的合成错误与本管线自己的真实数据审计。自由文本日记没有独立人工金标准，部分统计来自开发数据。
- **无原生 CSD / `.sav` 支持。** Consensus Sleep Diary 不是原生输入格式，需用 YAML 映射列（或让推断函数猜）。输出为 `.csv` / `.rds`，无 SPSS `.sav` 导出。
- **单一协议。** 为高强度纵向晨间睡眠日记开发；晚间日记、仅小睡日志、actigraphy 不在范围。
- **不能替代研究专属的质量控制。**

## 安装

```r
# 从 GitHub 安装（尚未上线 CRAN，包名 sleepcleanr）
renv::install("cyracaid/sleepdiary-cleaner")
```

## 快速开始

```r
library(sleepcleanr)

# 用内置合成数据跑演示
run_pipeline()

# 自己的研究数据：复制配置模板、映射列名、再跑
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
# 编辑 my_study.yaml → run_pipeline(config = "my_study.yaml")
```

## 引用

请用 Zenodo DOI 引用本软件（总 DOI 永远指向最新版本，每个 release 另有自己的版本 DOI）：

> Dong, C., & ten Brink, M. (2026). *sleepcleanr: Reproducible Sleep EMA Diary
> Data Cleaning Pipeline* [R package]. https://doi.org/10.5281/zenodo.23077702

在 R 里：`citation("sleepcleanr")`。机器可读元数据：`CITATION.cff`。

## 运行测试、反馈问题、参与贡献

```r
devtools::test()   # 在仓库克隆目录中运行；CI 里跑的是同一套测试
```

Bug、问题和功能建议：请开 [issue](https://github.com/cyracaid/sleepdiary-cleaner/issues)。
贡献指南见 [`CONTRIBUTING.md`](CONTRIBUTING.md)。

## 了解更多

- 完整文档站（可检索函数参考 + 双语 vignette）：
  <https://cyracaid.github.io/sleepdiary-cleaner/>
- **验证报告**（证据包，数字从结果 CSV 机器读取）：
  [`VALIDATION_REPORT.md`](VALIDATION_REPORT.md)
- vignette("pipeline-architecture-zh") — 结构、规则族、分类体系
- vignette("column-mapping-zh") — 用 YAML 映射你的数据集
- vignette("interpreting-output-zh") — 读 `correction_status_final.csv` 和 `step_flag_ledger.csv`
- vignette("validation-methodology-zh") — 规则如何验证（合成 + 真实数据）
- vignette("testing-coverage-zh") — 测试覆盖
- 更新日志：<https://github.com/cyracaid/sleepdiary-cleaner/releases>

## 开发/AI 助手

仓库自带 agent skill：`.opencode/skills/sleepcleanr-pipeline/SKILL.md`，说明如何
运行管线、解读检查点报告、添加人工修正与诊断问题。

### 管线步骤

<!-- AUTO:ARCH_ZH_START -->

**10 个步骤**（来源：`inst/steps.yaml`）：

| 步骤 | 名称 | 说明 |
|------|------|------|
| 1 | Load data | .rds/.csv auto-detected; schema validated; optional supplementary file merged |
| 1.5 | Field-misentry check | SOL/WASO clock-time vs duration-field misentry detection on raw data |
| 2-4 | Parse & normalize (S3 chain) | Parse timestamps → parse intervals → normalize sequence |
| 5 | Classify records | Generate manual review CSVs for human approval |
| 5.75 | Second-review consensus | Apply second-review checklist consensus |
| 6-7 | Correct & compute metrics (S3 chain) | Manual + duration corrections; TST/SOL/WASO/SE metrics; has_correction enum |
| 8 | Auto-detect remaining issues | TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED flag classification |
| 8.5 | Cross-participant consistency check | Global consistency audit across participants |
| 9 | Generate diagnostic figures | 30 figures (14 QC + 16 research) + figure_index.png contact sheet + RUN_INFO.txt |
| 10 | Build delivered datasets | finalize_columns() selects/renames to Dataset A/B per column dictionary |

<!-- AUTO:ARCH_ZH_END -->



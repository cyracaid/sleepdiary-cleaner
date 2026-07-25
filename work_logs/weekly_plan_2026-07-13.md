# 工作日志 — splsleep 睡眠 EMA 数据清洗管线

**日期：** 2026-07-13 → 2026-07-15
**项目：** splsleep（sleepdiary-cleaner）

---

## 已完成

### 管线核心功能

| # | 任务 | 状态 |
|---|------|------|
| 1 | 9 步清洗管线（timestamp parsing → correction → metrics → auto-detection → visualization） | ✅ |
| 2 | 人工修正 CSV 工作流（error/unusual/nap/metric 六种 CSV） | ✅ |
| 3 | Second-review 共识合并（Step 5.75） | ✅ |
| 4 | 跨被试一致性检查（Step 8.5） | ✅ |
| 5 | 27 张诊断图（pipeline_cleaning/ + research_ready/） | ✅ |
| 6 | Checkpoint 报告器（`report_correction_status.R`，A→E 五步状态快照） | ✅ |

### Figure 改进

| # | 改动 | 文件 |
|---|------|------|
| 1 | Fig 1: "Clean" → "Cleaned by Algorithm" | `sleep_visualization.R` |
| 2 | Fig 5: `facet_wrap` free_y 独立 Y 轴 | `sleep_visualization.R` |
| 3 | Fig 7: 标注框显示 flag 阈值和 Minor/Major 计数 | `sleep_visualization.R` |
| 4 | Fig 12: 饼图 → Pipeline Progress（checkpoint A→E 条形图） | `sleep_visualization.R` |
| 5 | Fig 1, 6, 13, 19, 20, 20B: subtitle 优化 | `sleep_visualization.R` |
| 6 | 新增 P26: Per-Participant Flag Rate | `sleep_visualization.R` |
| 7 | 新增 R25: Sleep Regularity (Weekday vs Weekend) | `sleep_visualization.R` |
| 8 | 新增 R26: Sleep Composition (TIB = TST+SOL+WASO) | `sleep_visualization.R` |
| 9 | 新增 R27: Sleep Metrics Correlation Matrix | `sleep_visualization.R` |
| 10 | 文件夹拆分: `pipeline_cleaning/` + `research_ready/` | `sleep_visualization.R` |

### 分类系统改进

| # | 改动 | 文件 |
|---|------|------|
| 1 | NEEDS_REVIEW → SELF_REPORTED_FLAG | `checkforerrors_processing.R` |
| 2 | Flag Distribution Report 增加 SOL excessive / TST-TIB low 明细 | `checkforerrors_processing.R` |
| 3 | 72 条 SELF-REPORTED FLAG 分析（61 SOL + 11 ratio） | `output/flagged_records_self_reported.csv` |

### R 包 + 通用化

| # | 任务 | 状态 |
|---|------|------|
| 1 | R package 结构（DESCRIPTION, NAMESPACE, R/） | ✅ |
| 2 | `run_pipeline(config = "my_config.yaml")` 配置驱动 | ✅ |
| 3 | `load_config()` + `adapt_columns()` 列映射适配器 | ✅ |
| 4 | `validate_columns()` + `validate_column_types()` schema 校验 | ✅ |
| 5 | `cfg_get()` 安全配置读取（`get0` 兜底） | ✅ |
| 6 | renv.lock 环境锁定 | ✅ |
| 7 | 合成示例数据（`inst/extdata/` 280 条假数据） | ✅ |
| 8 | testthat 端到端测试 + 边界测试（AM/PM 翻转、跨午夜、全 NA、bed=getup、顺序错乱、冒号格式化） | ✅ |
| 9 | GitHub Actions CI | ✅ |
| 10 | README + 架构文档中英文测试覆盖说明 | ✅ |
| 11 | Vignette | ✅ |

### Agent Skill

| # | 任务 | 状态 |
|---|------|------|
| 1 | SKILL.md（170 行，管线架构 + 文件说明 + 分类 + 常见操作） | ✅ |
| 2 | 移入 repo `.opencode/skills/splsleep-pipeline/` | ✅ |
| 3 | `opencode.jsonc` 注册（triggers + agents） | ✅ |

### Claude Opus 评估后的修复

| # | 问题 | 修复 |
|---|------|------|
| 1 | `process_timestamp` 列名 bug（`ampm.varname` 未求值） | `data.frame()` → `[[` 赋值 |
| 2 | `process_timestamp` 返回 `df_timeproc` 未定义 | 改为返回 `df` |
| 3 | `00a_setup.R` 硬编码文件名 | 改为读取 `cfg$data$files` |
| 4 | `00_MAIN_entry.R` Step 1 硬编码 RDS/CSV 路径 | 改为 `cfg_get()` |
| 5 | `cross_participant_field_misentry_check.R` 硬编码 RDS 路径 | 改为 `cfg_get()` |
| 6 | `apply_second_review.R` 无文件时报错 | 改为文件不存在时跳过 |
| 7 | `00_MAIN_entry.R` manual CSV 读取 | 文件不存在时用空 data.frame |
| 8 | config YAML 含 em dash（—）导致解析失败 | 全部替换为 ASCII 双横线 |

### GitHub 清理

| # | 操作 |
|---|------|
| 1 | 仓库重命名: `EMA-Sleep-Diary-Data-Cleaning-Pipeline` → `sleepdiary-cleaner` |
| 2 | GitHub Release v1.0.0 发布 |
| 3 | 全量清理: `archive/`, `visualizations/`, `sleep_visualization_*/`, `latest_visualization/`, `output/` 共 1000+ 文件从 git 历史彻底清除 |
| 4 | orphan branch + force push → 单次 commit，零历史 |
| 5 | `.gitignore` 全面更新 → 防未来泄露 |

---

## Current State

- **Total records:** 13,990 | **Skipped NA:** 11,142
- **Clean:** 1,908 | **Error:** 7 | **Unusual:** 31 | **Equal Time:** 902
- **Manually corrected:** 82
- **SELF-REPORTED FLAG:** 72（61 SOL excessive + 11 TST/TIB very_low）
- **TIMESTAMP/DURATION/AMOUNT issues:** 0
- **Valid metric records:** 1,729 | Mean TST: 7.71h | Mean SOL: 28.8min

---

## Repo

**GitHub:** https://github.com/cyracaid/sleepdiary-cleaner
**Install:** `install.packages("splsleep_1.0.0.tar.gz", repos = NULL)`
**Run:** `library(splsleep); run_pipeline()`
**Customize:** `run_pipeline(config = "my_config.yaml")`

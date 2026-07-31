# 技术债务 — splsleep v1.3.1

记录有意延期到后续版本解决的代码质量问题。每条说明是什么债务、为什么存在、预计何时解决。

---

## 1. 根目录与 inst/scripts/ 中的重复脚本

**是什么：** 以下文件在两个位置有完全相同的副本：

| 文件 | 根目录副本 | inst/scripts/ 副本 | 重复原因 |
|------|-----------|-------------------|----------------|
| `error_unusual_sleep_time_corrections.R` | 2,082 行 | 2,082 行 | 根目录副本供旧 run_pipeline() 调用；inst/scripts/ 供 S3 链调用 |
| `checkforerrors_processing.R` | 987 行 | 987 行 | 同上 |
| `sleep_visualization.R` | 2,594 行 | 2,594 行 | 同上 |
| `generate_correction_files.R` | 807 行 | 807 行 | 同上 |
| `cross_participant_field_misentry_check.R` | — | — | 同上 |
| `cross_participant_global_check.R` | 429 行 | 429 行 | 同上 |
| `apply_second_review.R` | — | 98 行 | 同上 |
| `apply_nap_exercise_corrections.R` | — | — | 同上 |
| `apply_sleep_metric_duration_corrections.R` | — | — | 同上 |
| `apply_metric_review_acceptances.R` | — | — | 同上 |
| `report_correction_status.R` | — | — | 同上 |
| `audit_data_integrity.R` | — | — | 同上 |
| `audit_review_propagation.R` | — | — | 同上 |
| `generate_ai_review_csvs.R` | — | — | 同上 |

**为何存在：** 旧管线（`run_pipeline()`）从项目根目录 source 脚本。重构为 R 包时，这些脚本被复制到 `inst/scripts/` 中以满足 `R CMD build` 的要求，同时保留根目录副本以保证向后兼容。S3 链通过 `scripts_dir()` 从 `inst/scripts/` 读取。

**解决计划（v1.4.0）：**
1. 将 `process_timestamp()` 和 `process_interval()` 体内化到 `R/steps.R`（见第 2 条）。
2. 对其余脚本，以 `inst/scripts/` 为单一来源。根目录副本可改为薄包装器：`source(system.file("scripts/...", package="splsleep"))`。
3. 或：所有调用方迁移到 `scripts_dir()` 后删除所有根目录副本。

**最后更新：** 2026-07-28（v1.3.1）

---

## 2. process_timestamp() / process_interval() 同时在 R/steps.R 和 inst/scripts/ 中存在

**是什么：** 步骤适配器 `step_process_timestamps()` 和 `step_process_intervals()` 通过 `.load_script()` → `sys.source()` 调用原始脚本。Wrapper-first 策略（v1.3.0）的原本意图是：在 snapshot 验证通过后将函数体搬入 `R/steps.R`，消除文件系统的 `source()` 开销。

**当前状态：** 适配器仍在调用原始脚本。Snapshot 测试（v1.3.0）已证明 bit-identical 输出，体内化是安全的。

**为何存在：** Snapshot 验证与 S3 类的实现在同一工作会话中完成。为避免结构改动与逻辑迁移混合，体内化工作被推迟到后续。

**解决计划（v1.4.0）：**
1. 将 `process_timestamp()` 的代码体复制到 `R/steps.R` 的 `step_process_timestamps()` 中。
2. 将 `process_interval()` 的代码体复制到 `R/steps.R` 的 `step_process_intervals()` 中。
3. 移除这两个适配器的 `.load_script()` 调用。
4. 重新运行 `verify_v1_3_snapshot.R` 以确认输出不变。
5. `inst/scripts/` 的副本保留，供仍在使用 `source()` 的步骤 5、8、9 使用。

**最后更新：** 2026-07-28（v1.3.1）

---

## 3. cfg_get() 全局环境 fallback

**是什么：** 若干 `inst/scripts/` 文件调用 `cfg_get()` 时未传递 `cfg` 参数。它们依赖 `.GlobalEnv$pipeline_config` 的 fallback，该路径在 v1.3.1 中会发出 deprecation warning。

**涉及文件：** `sleep_visualization.R`, `checkforerrors_processing.R`, `cross_participant_field_misentry_check.R`, `apply_sleep_metric_duration_corrections.R`, `apply_nap_exercise_corrections.R`, `apply_metric_review_acceptances.R`, `apply_second_review.R`, `00_MAIN_entry.R`

**为何存在：** 这些脚本通过 `source(..., local = TRUE)` 加载到 `run_pipeline()` 的执行环境中，此时 `pipeline_config` 在调用域中可用。改为显式传 `cfg` 需要修改每个脚本的函数签名。

**解决计划（v1.4.0）：** 当这些脚本从 `source()` 迁移时（见第 1 条），其函数将接受 `cfg` 作为显式参数。

**最后更新：** 2026-07-28（v1.3.1）

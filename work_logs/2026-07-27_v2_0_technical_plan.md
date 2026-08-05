# SplSleep v2.0 — 技术升级计划（给合作者）

**日期：** 2026-07-27
**项目：** splsleep — 睡眠 EMA 日记数据清洗管线
**版本目标：** v1.1.x → v2.0.0
**核心命题：** 可信用清洗 = 代码稳定 + 结果可复现 + 效果有证据

---

## 0. 前置工作 — 已完成（2026-07-25 关闭）

~~本节原为「最高优先级，阻塞一切」的前置项：本地 `log_step.R` / `flag_standards.R` /
`figure12_step_flag_table.R` / `test-flag-standards.R` / 新版 Figure 12 未 push。~~

**已解除。** 2026-07-25 的合并把这批工作全部纳入版本控制并推送（`37cfeb6`，71 文件
+12,327 行），后续 `9751de0` / `e431f37` / `1bbc337` / `6704de2` / `9eaf21b` 修完
bug、路径泄露与 R CMD check，CI 转绿。`v1.2.0` tag 打在 `1ca9237`。

Phase 1 已于 2026-07-28 启动，工作分支 `v1.3-s3`。

---

## Phase 1：可信清洗地基（8-12 天）

### P1-1：S3 泛型架构 + 管道链（⭐⭐⭐⭐⭐，3-5 天）

**现状问题：**
- 9 个步骤各自是独立 `source()` 文件，互相没有接口契约
- 有些步骤验证输入（`calculate_sleep_time_end.R:86-104`），有些完全不验证（`normalize_sleep_time_sequence.R`）
- 部分函数返回 dataframe，部分写 CSV 到磁盘（`generate_correction_files.R`）作为副作用

**目标架构：**

```r
# 使用方式
cleaned <- raw_data |>
  parse_timestamps() |>
  parse_intervals() |>
  normalize_sequence() |>
  classify_records() |>
  apply_corrections(manual_corrections) |>
  compute_metrics() |>
  detect_anomalies()

# 每步返回的 S3 对象自带这些方法
summary(cleaned)    # 这步处理了多少行、标记了多少异常
plot(cleaned)       # 看一眼分布
print(cleaned)      # 简短状态描述
```

**具体实施：**

1. **定义核心 S3 类 `sleep_diary`**
   ```r
   # 内部结构
   list(
     data     = <data.frame>,  # 核心数据
     metadata = list(          # 步骤元信息
       step_name    = "parse_timestamps",
       step_version = "2.0.0",
       n_rows_in    = 13990,
       n_rows_out   = 13990,
       flags_added  = c("bed_hhmm_checkforerrors", "sleep_hhmm_checkforerrors", ...),
       duration_ms  = 234
     ),
     ledger  = <data.frame>    # 当前累计 flag 账本
   )
   ```

2. **重写 9 个步骤为 S3 方法**（每个改名 + 加 dispatch + 构造返回对象）
   - `parse_timestamps.sleep_diary()`
   - `parse_intervals.sleep_diary()`
   - `normalize_sequence.sleep_diary()`
   - `classify_records.sleep_diary()`
   - `apply_corrections.sleep_diary()`
   - `compute_metrics.sleep_diary()`
   - `detect_anomalies.sleep_diary()`
   - 等等

3. **实现 3 个泛型方法**
   - `summary.sleep_diary()` — 表格化步骤统计
   - `plot.sleep_diary()` — 调用现有 `sleep_visualization.R` 的 Figure 1（质量仪表板）
   - `print.sleep_diary()` — 一行摘要

4. **保留向后兼容**
   - 原有 `run_pipeline()` 函数内部改用 S3 管道链
   - `corrected_ema_data` 可从 `sleep_diary` 对象的 `$data` 提取

**验收标准：**
- 所有 17 个现有 testthat 测试仍然全绿
- `run_pipeline()` 产生的 `corrected_ema_data` 与重构前逐行一致（snapshot 对比）
- `summary(cleaned)` 输出包含每步的行数、耗时、flag 计数

---

### P1-2：testthat 扩展 + GitHub Actions CI + Snapshot Tests（⭐⭐⭐⭐⭐，2-3 天）

**现状问题：**
- 17 个测试，只覆盖 `normalize_sleep_time_sequence` 和 `process_interval` 的边角
- **核心的 2078 行 correction engine（`error_unusual_sleep_time_corrections.R`）零测试**
- **805 行分类逻辑（`generate_correction_files.R`）零测试**
- **721 行自动错误检测（`checkforerrors_processing.R`）零测试**
- GitHub Actions 存在但本地改动从未触发

**具体实施：**

(TDD: 先用 testthat 写出每个函数"应该产生什么结果"的断言 → 然后确认当前代码通过 → 后续重构时这些测试就是你改代码的安全网)

1. **Snapshot tests**（最关键的防护）
   ```r
   test_that("pipeline output is deterministic", {
     skip_on_ci()  # CI 上用更小的测试数据
     result <- run_pipeline(test_config)

     # snapshot 对比：如果输出变了，测试直接挂
     expect_snapshot_value(
       result$corrected_ema_data[, c("pid", "self_diffcalc_totalsleeptime_minutes")],
       style = "serialize"
     )
   })
   ```

2. **核心 correction engine 测试**（至少 10 个场景）
   - CASE1: 空行跳过
   - CASE2: AM/PM 转换正确
   - CASE2: ±12h 时间对齐
   - CASE2: swap 交换
   - CASE3: 显式列值替换
   - CASE4: 不可处理行
   - "reasonable unusual" 标记生效
   - 多层列层级（raw → baseline → manual → final）正确
   - 人工修正 CSV 空文件不报错

3. **分类逻辑测试**（至少 8 个场景）
   - equal_time 正确拦截
   - bed_sleep_diff > 7h → error
   - awake_getup_diff > 7h → error
   - sleep_awake > 24h → error
   - sleep < 3h → unusual
   - sleep > 15h → unusual
   - sol > 3h → unusual
   - 优先级链：error > unusual > normal

4. **自动错误检测测试**
   - SOL 负值 → NEGATIVE
   - SE > 100% → EXCEEDS
   - TST/TIB 比值异常
   - checkforerrors_summary 分类标签正确

5. **GitHub Actions CI 配置**
   ```yaml
   # .github/workflows/R-CMD-check.yaml（已有，补充 snapshot 步骤）
   # .github/workflows/test-coverage.yaml（新增，用 covr）
   ```

**验收标准：**
- `devtools::test()` 测试数从 17 → 50+
- CI 在每次 push 时自动运行全部测试
- Snapshot test 确保 pipeline 输出确定性

---

### P1-3：Bland-Altman 分析（⭐⭐⭐，1 天）

**为什么在这：** 效果证明。你的清洁管线算出来的 SOL/TST/WASO 和参与者自己报的估计值差多少？一张 Bland-Altman 图回答这个问题。

**原理（给合作者）：**
- 横轴 =（计算值 + 自报值）/ 2（"平均睡眠时长"）
- 纵轴 = 计算值 − 自报值（"算法比你自己报的多/少了几分钟"）
- 中间实线 = 偏倚（bias，系统性的高估/低估）
- 上下虚线 = 95% 一致限（Limits of Agreement，大部分误差在此范围）

**具体实施：**

```r
bland_altman <- function(data,
                         computed_col,   # 如 "self_diffcalc_totalsleeptime_minutes"
                         reported_col,   # 如 "估算的 TST 列"
                         label = "TST",
                         participant_col = "pid") {
  # 返回 list(bias, lower_loa, upper_loa, prop_bias_p, plot)
}
```

**输出：**
- TST Bland-Altman 图（管线计算 vs 参与者自报）
- SOL Bland-Altman 图
- WASO Bland-Altman 图（如数据可用）
- 数值报告：偏倚、95% 一致限、比例偏倚检验 p 值

**不做的：** BA 分析结果只作为输出报告，不用于自动修改清洗逻辑（保持管线可审计）。

**验收标准：**
- `bland_altman()` 函数独立可调用
- 输出 ggplot 对象 + 数值报告
- 加入 Figure 系列（如 Figure 28-30）

---

### P1-4：统计异常标记（IQR / z-score）（⭐，1-2 天）

**为什么不用 ML：**
- Isolation Forest 是黑箱，输出"anomaly score 0.73"没人看得懂
- 非确定性（每次训练边界不同）
- 要重新训练，dependency 重

**改用统计方法：**
- 对每个关键指标（SOL、WASO、TST、SE），按参与者分组
- 中位数 ± 1.5×IQR 为正常范围，之外的标为 STATISTICAL_OUTLIER
- 或者 modified z-score（MAD-based）> 3.5

这种方法：
- **完全透明**：阈值公式写在代码里，任何人都能复现
- **确定性**：同样的数据→同样的标记
- **和现有阈值并行**：不在正常范围 → 标为 STATISTICAL_OUTLIER，不替换原有 error/unusual 逻辑

**具体实施：**

```r
flag_statistical_outliers <- function(data,
                                      metrics = c("self_diffcalc_sol_minutes",
                                                  "avg_waso_estimate_am_minutes",
                                                  "self_diffcalc_totalsleeptime_minutes",
                                                  "self_diffcalc_sleepefficiency_percent"),
                                      group_col = "pid",
                                      method = c("iqr", "mad")) {
  # 按参与者分组，对每个 metric 计算 IQR 范围
  # 标记范围外的行 → sleep_diary$data$statistical_outlier_flag
}
```

**验收标准：**
- 标记列出现在 `checkforerrors_processed` 中
- 标记比例合理（通常 < 5%）
- 与现有 error/unusual 标记不冲突（并行标记）

---

### P1-5：轻量缺失值处理（⭐，1 天）

**现状：** NA 时间戳 → 直接 skip（`skipped_na`），该行数据丢弃。

**改进（保守策略）：**
1. **标记原因码** — 不是简单地 skip，而是打上标签：
   - `MISSING_PARTICIPANT` — 参与者某天没填
   - `MISSING_SYSTEM` — 调查系统没采集到
   - `MISSING_DERIVED` — 原始数据有，但计算不出来（如 bed 有、sleep 没）

2. **LOCF（Last Observation Carried Forward）— 仅相邻单天**
   - 只在缺失 ≤ 1 天时用前一天的值填补（相邻缺失不连锁填补）
   - 填补值标注 `imputed_locf = TRUE`
   - 只填 SOL/WASO 等指标，不填原始时间戳

3. **不做的事：** MICE 多重插补、Kalman filter —— 这些属于分析阶段，研究者自己在 cleaned data 上做

**验收标准：**
- `corrected_ema_data` 新增 `missing_reason` 列
- 填补行有 `imputed_locf = TRUE` 标记
- 原始时间戳列从不被填补

---

## Phase 2：分析能力扩展（时间待定，Phase 1 完成后启动）

### P2-1：昼夜节律分析独立模块（2-3 天）

```r
circadian_analysis <- function(sleep_diary_obj,
                                method = c("cosinor", "lomb_scargle")) {
  # 消费清洗后的 sleep_diary 对象
  # 返回 phase、amplitude、mesor、period 等参数
  # 出图：24h 极坐标图
}
```

- 使用 `cosinor` / `lomb` CRAN 包
- 不混入清洗管线，独立调用
- 配套 vignette

---

### P2-2：贝叶斯分层模型 vignette（2-3 天）

```r
# vignettes/sleep-hierarchical-model.Rmd
# 展示完整分析流程：
# 1. 加载 cleaned data
# 2. brms 建模：SOL ~ 1 + caffeine + alcohol + (1 | pid)
# 3. 后验预测检查图
# 4. 森林图（个体效应）
```

- 仅在 vignette 中演示，不进入管线
- 研究者可复制修改

---

### P2-3：`targets` 增量管线（3-5 天）

当前 `run_pipeline()` 每次全量重跑。`targets` 包：
- 检查每步输入是否变化（输入哈希）
- 只重新执行变化部分
- 并行执行独立步骤
- 自带缓存管理

这对人工修正工作流特别有用——改一行 manual 修正，只重跑步骤 6 之后。

---

### P2-4：JSON Schema 配置校验（1 天）

当 `config_default.yaml` 足够复杂（多数据集、多阈值组合）时，提供 JSON Schema 让 IDE 自动补全和校验。

---

## 明确不做的项目（及详细理由）

| 项目 | 不做原因 |
|------|----------|
| **KZ 自适应滤波** | KZ 是为连续传感器数据（加速度计 30s 采样）设计的低通滤波器。EMA 日记是每天一条的自报记录，没有连续时间序列可以滤波。这是工具用错地方。 |
| **Rcpp 重写时间解析** | 14K 行的 `lubridate::hm()` 解析毫秒级完成。加 Rcpp 意味着加 C++ 编译器依赖、平台兼容性问题、C 级调试负担。当前没有性能问题需要解决。 |
| **data.table 迁移** | 14K 行 dplyr 完美胜任。换 data.table 要重写全部 9 步的 mutate/filter/group_by 逻辑，降低可读性。dplyr 的 `|>` 管道在 R 社区是主流惯例。 |
| **Isolation Forest** | 当前硬阈值规则是**透明、可解释、确定性**的。换 ML 意味着输出不再能被"为什么要标记这一行？"解释。对一个以可信为核心卖点的清洗管线，这是致命设计选择。 |
| **brms 嵌入管线** | 分离关注点：清洗管线输出干净数据，研究者在清洗数据上做分析。把 brms 塞进 `run_pipeline()` 模糊了这个边界。作为独立 vignette 保持灵活性。 |
| **valgrind** | 当前零 C/C++/Fortran 代码，valgrind 检查纯 R 没有意义。只有未来引入编译代码时才需要。 |

---

## 验收总标准

Phase 1 完成后：

- [ ] `devtools::test()` 50+ 测试全绿
- [ ] GitHub Actions CI 在 push 时自动运行
- [ ] Snapshot 测试确认 pipeline 输出确定
- [ ] S3 管道链产生与当前 pipeline 逐行一致的 `corrected_ema_data`
- [ ] Bland-Altman 报告自动生成
- [ ] 统计异常标记与现有 error/unusual 系统并行工作
- [ ] 缺失值原因码 + LOCF 填补可审计

---

## 变更历史

| 日期 | 变更 |
|------|------|
| 2026-07-27 | 初稿：三 Agent 专业辩论后形成最终路线图 |

---

> 快速概览见项目根目录 `ROADMAP.md`

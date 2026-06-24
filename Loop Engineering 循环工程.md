# Loop Engineering 循环工程

## 定义

Loop Engineering 是千里马计划的持续改进机制。

它不是单次执行，也不是只看结果。它要求系统把每一次任务都当成一轮可复用的闭环：

```text
执行 -> 评估 -> 分析 -> 改进 -> 记录 -> 再执行
```

## 目标

- 让工作流越来越稳
- 让模板越来越准
- 让数据源越来越清楚
- 让 token 花费越来越可控
- 让用户修改越来越少

## 适用范围

Loop Engineering 适用于所有千里马任务：

- 广告日报
- 竞品对比
- Listing 优化
- 利润测算
- 关键词追踪
- 资料消化
- 数据连接器接入

## 核心步骤

### 1. 执行

按 task card、workflow、template 和 data source 完成任务。

执行时必须留下：

- 输入文件
- 输出文件
- 关键判断
- 失败点
- 估算成本

### 2. 评估

检查这次输出是否满足最低标准：

- 是否引用了数据源
- 是否说明了风险
- 是否给出了可执行结论
- 是否超出 token 预算
- 是否出现格式错误或缺字段

评估结果要写入评估记录。

### 3. 分析

把失败原因分成可处理类别：

- 数据源缺失
- 字段缺失
- 命名混乱
- 模板不清楚
- 用户不采纳
- 成本过高
- 风险提示不足

分析的目的不是批评，而是找出下一轮要改哪里。

### 4. 改进

可改的东西只限于这些层：

- `data-sources.yaml`
- `file-registry.yaml`
- `naming-rules.yaml`
- `user-preferences.yaml`
- `workflow-index.yaml`
- `templates/`
- `rules/`

高风险内容不能直接自动改：

- 外部系统写回
- 权限变更
- 成本预算变更
- 决策阈值大改

### 5. 记录

每次循环结束都要留下记录：

- 结果是否通过
- 失败原因
- 改了什么
- 影响了哪些 workflow
- token 花费多少
- 是否需要人工确认

记录位置：

```text
.qianlima/logs/
.qianlima/feedback/
.qianlima/usage-ledger/
```

文档分类和入口维护见 `docs/README.md`。

### 6. 再执行

下一次执行时，系统优先使用已经改过的规则、模板和偏好。

这就是 Loop Engineering 的价值：不是反复重来，而是每轮都更接近稳定。

## 和 AHE 的关系

千里马的 Loop Engineering 参考了 AHE 的：

- Evaluate
- Analyze
- Improve

但千里马更偏工作场景，不是代码项目。

所以千里马的闭环还要额外包含：

- 数据连接
- 文件治理
- 权限确认
- 成本记录
- 任务卡复用

## 和成本的关系

Loop Engineering 不是只优化结果，也优化成本。

每次任务至少记录：

- 模型名
- input tokens
- output tokens
- estimated cost
- 是否使用上下文压缩

记录模板：

```text
.qianlima/templates/token-usage-record_template.yaml
```

## 最小闭环

```text
任务输入
  -> 任务执行
  -> 结果评估
  -> 失败分析
  -> 规则/模板改进
  -> 使用记录
  -> 下一次任务
```

## 成功标准

一个成熟的 Loop Engineering 系统，应该能做到：

1. 同类任务越来越少出错
2. 用户越来越少手工修正
3. token 花费越来越稳定
4. 数据源越来越规范
5. 模板越来越适合大众用户

## 一句话版本

Loop Engineering = 把每次任务都变成下一次更好的起点。
